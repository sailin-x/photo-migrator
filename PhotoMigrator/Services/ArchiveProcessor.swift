import Foundation
import Photos

/// Service to process Google Takeout archives
class ArchiveProcessor {
    /// Progress tracking
    let progress: MigrationProgress
    
    /// Path to log file
    private var logFileURL: URL?
    
    /// File handle for writing to log
    private var logFileHandle: FileHandle?
    
    /// Photos importing service
    private let photosImporter = PhotosImporter()
    
    /// Flag for cancellation
    private var isCancelled = false
    
    /// Batch processing settings
    private var batchSettings = BatchSettings()
    
    /// Whether batch processing is enabled
    private var batchProcessingEnabled = true
    
    /// Initialize with progress tracking
    init(progress: MigrationProgress) {
        self.progress = progress
        setupLogFile()
    }
    
    /// Initialize with progress tracking and batch settings
    init(progress: MigrationProgress, batchSettings: BatchSettings) {
        self.progress = progress
        self.batchSettings = batchSettings
        self.batchProcessingEnabled = batchSettings.isEnabled
        setupLogFile()
    }
    
    /// Set up log file
    private func setupLogFile() {
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
            let dateString = dateFormatter.string(from: Date())
            
            logFileURL = documentsDirectory.appendingPathComponent("PhotoMigrator_\(dateString).log")
            
            if let url = logFileURL {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                FileManager.default.createFile(atPath: url.path, contents: nil)
                logFileHandle = try FileHandle(forWritingTo: url)
            }
        } catch {
            print("Failed to set up log file: \(error)")
        }
    }
    
    /// Write a message to the log file
    func writeToLog(_ message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        if let data = logMessage.data(using: .utf8) {
            logFileHandle?.write(data)
        }
        
        // Also update progress
        progress.addMessage(message)
    }
    
    /// Clean up resources
    deinit {
        try? logFileHandle?.close()
    }
    
    func processArchive(at archiveURL: URL) async throws -> MigrationSummary {
        progress.currentStage = .initializing
        isCancelled = false
        writeToLog("Starting migration process with archive: \(archiveURL.path)")
        
        // Setup memory monitoring
        setupMemoryMonitoring()
        
        // Initialize batch processing if enabled
        let batchProcessor = BatchProcessingManager(
            settings: batchSettings,
            progress: progress
        )
        
        // Set up logging from batch processor
        batchProcessor.onLogMessage = { [weak self] message in
            self?.writeToLog(message)
        }
        
        let startTime = Date()
        progress.elapsedTime = 0
        
        // Start timer to update elapsed time
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.progress.elapsedTime = Date().timeIntervalSince(startTime)
        }
        
        defer {
            timer.invalidate()
        }
        
        // Extract archive
        progress.currentStage = .extractingArchive
        progress.stageProgress = 0
        writeToLog("Extracting archive...")
        
        let extractedFolderURL = try await extractArchive(archiveURL)
        if isCancelled { throw CancellationError() }
        
        // Find JSON metadata files
        progress.currentStage = .processingMetadata
        progress.stageProgress = 0
        writeToLog("Searching for metadata files...")
        
        let jsonFiles = try await findJsonMetadataFiles(in: extractedFolderURL)
        if jsonFiles.isEmpty {
            writeToLog("Warning: No metadata JSON files found in archive")
            progress.addMessage("No metadata JSON files found in archive", type: .warning)
        }
        writeToLog("Found \(jsonFiles.count) metadata files")
        
        // Process JSON metadata
        progress.totalItems = jsonFiles.count
        progress.processedItems = 0
        writeToLog("Processing metadata files...")
        
        var processedMediaItems: [MediaItem] = []
        
        // Process media files in batches if batch processing is enabled
        if batchProcessingEnabled {
            do {
                processedMediaItems = try await batchProcessor.processBatches(
                    items: jsonFiles,
                    processFunction: { batch in
                        return try await self.processMetadataFiles(batch)
                    }
                )
            } catch {
                writeToLog("Error during batch processing: \(error.localizedDescription)")
                throw error
            }
        } else {
            // Process all at once if batch processing is disabled
            processedMediaItems = try await processMetadataFiles(jsonFiles)
        }
        
        if isCancelled { throw CancellationError() }
        
        // Import photos
        progress.currentStage = .importingPhotos
        progress.stageProgress = 0
        progress.totalItems = processedMediaItems.count
        progress.processedItems = 0
        writeToLog("Importing \(processedMediaItems.count) media items to Photos library...")
        
        var importResults: [PhotosImportResult] = []
        if batchProcessingEnabled {
            do {
                importResults = try await batchProcessor.processBatches(
                    items: processedMediaItems,
                    processFunction: { batch in
                        return try await self.importMediaItems(batch)
                    }
                )
            } catch {
                writeToLog("Error during batch import: \(error.localizedDescription)")
                throw error
            }
        } else {
            // Import all at once if batch processing is disabled
            importResults = try await importMediaItems(processedMediaItems)
        }
        
        if isCancelled { throw CancellationError() }
        
        // Organize into albums
        progress.currentStage = .organizingAlbums
        progress.stageProgress = 0
        writeToLog("Organizing media into albums...")
        
        let albumsCreated = try await organizeAlbums(processedMediaItems, importResults: importResults)
        if isCancelled { throw CancellationError() }
        
        // Complete the process
        progress.currentStage = .complete
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        // Clean up memory monitoring
        cleanupMemoryMonitoring()
        
        let summary = MigrationSummary(
            totalItemsProcessed: processedMediaItems.count,
            successfulImports: importResults.compactMap { $0.assetId }.count,
            failedImports: importResults.filter { $0.assetId == nil }.count,
            albumsCreated: albumsCreated,
            livePhotosReconstructed: processedMediaItems.filter { $0.fileType == .livePhoto }.count,
            metadataIssues: progress.recentMessages.filter { $0.type == .warning }.count,
            logPath: logFileURL,
            batchProcessingUsed: batchProcessingEnabled,
            batchesProcessed: progress.currentBatch,
            batchSize: progress.batchSize,
            peakMemoryUsage: progress.peakMemoryUsage,
            processingTime: totalTime
        )
        
        writeToLog("Migration completed in \(String(format: "%.1f", totalTime)) seconds")
        writeToLog("Summary: Processed \(summary.totalItemsProcessed) items, \(summary.successfulImports) successful, \(summary.failedImports) failed")
        
        if batchProcessingEnabled {
            writeToLog("Batch processing: \(progress.currentBatch) batches of \(progress.batchSize) items")
            writeToLog("Peak memory usage: \(formatMemorySize(progress.peakMemoryUsage))")
        }
        
        return summary
    }
    
    /// Cancel ongoing processing
    func cancel() {
        isCancelled = true
        progress.isCancelled = true
        writeToLog("Migration process cancelled by user")
    }
    
    // MARK: - Private Processing Methods
    
    /// Extract the archive
    private func extractArchive(_ archiveURL: URL) async throws -> URL {
        // Simulated extraction - in a real implementation, this would actually extract the ZIP file
        // For now, just assume the archive is already extracted at the same location
        let extractedFolderURL = archiveURL.deletingLastPathComponent()
        
        // Simulate extraction progress
        for i in 1...10 {
            if isCancelled { throw CancellationError() }
            progress.stageProgress = Double(i) * 10.0
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        writeToLog("Archive extracted to: \(extractedFolderURL.path)")
        return extractedFolderURL
    }
    
    /// Find JSON metadata files in the extracted archive
    private func findJsonMetadataFiles(in folderURL: URL) async throws -> [URL] {
        // Simulated file discovery - in a real implementation, this would recursively search the folder
        var jsonFiles: [URL] = []
        
        // Simulate file discovery progress
        for i in 1...5 {
            if isCancelled { throw CancellationError() }
            progress.stageProgress = Double(i) * 20.0
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Add some simulated files
            let count = Int.random(in: 10...20)
            for j in 1...count {
                let filename = "photo_\(i)_\(j).json"
                jsonFiles.append(folderURL.appendingPathComponent(filename))
            }
        }
        
        return jsonFiles
    }
    
    /// Process metadata files and create MediaItem objects
    private func processMetadataFiles(_ jsonFiles: [URL]) async throws -> [MediaItem] {
        var mediaItems: [MediaItem] = []
        
        for (index, jsonURL) in jsonFiles.enumerated() {
            if isCancelled { throw CancellationError() }
            
            // Create a MediaItem from the metadata (simulated)
            let mediaItem = MediaItem(
                id: "item_\(index)",
                title: "Photo \(index)",
                description: "Description for photo \(index)",
                timestamp: Date().addingTimeInterval(-Double(index * 86400)), // 1 day earlier per item
                latitude: Double.random(in: -90...90),
                longitude: Double.random(in: -180...180),
                fileURL: jsonURL.deletingPathExtension().appendingPathExtension("jpg"),
                fileType: .photo,
                albumNames: ["Vacation", "Family"].randomElement().map { [$0] } ?? [],
                isFavorite: Bool.random(),
                originalJsonData: ["title": "Photo \(index)"]
            )
            
            mediaItems.append(mediaItem)
            
            // Update progress
            progress.processedItems = index + 1
            progress.stageProgress = Double(index + 1) / Double(jsonFiles.count) * 100.0
            
            if (index + 1) % 10 == 0 {
                writeToLog("Processed \(index + 1) of \(jsonFiles.count) metadata files")
            }
            
            // Simulate processing time
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        writeToLog("Processed \(jsonFiles.count) metadata files, found \(mediaItems.count) media items")
        return mediaItems
    }
    
    /// Import media items to the Photos library
    private func importMediaItems(_ mediaItems: [MediaItem]) async throws -> [PhotosImportResult] {
        var results: [PhotosImportResult] = []
        
        for (index, item) in mediaItems.enumerated() {
            if isCancelled { throw CancellationError() }
            
            // Simulate importing to Photos (in real implementation, this would use PhotoKit)
            let success = Bool.random(in: 0...9) != 0 // 90% success rate
            let assetId = success ? "asset_\(UUID().uuidString)" : nil
            let result = PhotosImportResult(mediaItem: item, assetId: assetId)
            results.append(result)
            
            // Update progress
            progress.processedItems = index + 1
            progress.stageProgress = Double(index + 1) / Double(mediaItems.count) * 100.0
            
            if (index + 1) % 10 == 0 {
                writeToLog("Imported \(index + 1) of \(mediaItems.count) media items")
            }
            
            // Simulate import time
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        let successCount = results.compactMap { $0.assetId }.count
        writeToLog("Imported \(successCount) of \(mediaItems.count) media items successfully")
        return results
    }
    
    /// Organize imported media into albums
    private func organizeAlbums(_ mediaItems: [MediaItem], importResults: [PhotosImportResult]) async throws -> Int {
        // Collect all unique album names
        var allAlbumNames = Set<String>()
        for item in mediaItems {
            allAlbumNames.formUnion(item.albumNames)
        }
        
        let albumCount = allAlbumNames.count
        writeToLog("Creating \(albumCount) albums")
        
        // Simulate album creation progress
        for (index, albumName) in allAlbumNames.enumerated() {
            if isCancelled { throw CancellationError() }
            
            // Simulate creating album and adding photos
            writeToLog("Creating album: \(albumName)")
            
            // Find all successfully imported items for this album
            let itemsForAlbum = mediaItems.filter { $0.albumNames.contains(albumName) }
            let assetIdsForAlbum = itemsForAlbum.compactMap { item in
                importResults.first { $0.mediaItem.id == item.id }?.assetId
            }
            
            writeToLog("Added \(assetIdsForAlbum.count) photos to album '\(albumName)'")
            
            // Update progress
            progress.stageProgress = Double(index + 1) / Double(albumCount) * 100.0
            
            // Simulate album creation time
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
        
        writeToLog("Finished creating \(albumCount) albums")
        return albumCount
    }
    
    // MARK: - Memory Monitoring
    
    /// Set up memory monitoring
    private func setupMemoryMonitoring() {
        // In a real implementation, this would register for memory pressure notifications
        writeToLog("Memory monitoring enabled")
    }
    
    /// Clean up memory monitoring
    private func cleanupMemoryMonitoring() {
        // In a real implementation, this would unregister from memory pressure notifications
        writeToLog("Memory monitoring disabled")
    }
    
    /// Format memory size to human-readable string
    private func formatMemorySize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

/// Result of importing a media item to Photos
struct PhotosImportResult {
    let mediaItem: MediaItem
    let assetId: String?
}

/// Error thrown when operation is cancelled
struct CancellationError: Error {}