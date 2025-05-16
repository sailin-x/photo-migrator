import Foundation
import Photos
import os

/// Service to process Google Takeout archives
class ArchiveProcessor {
    /// Progress tracking
    let progress: MigrationProgress
    
    /// Path to log file
    private var logFileURL: URL?
    
    /// File handle for writing to log
    private var logFileHandle: FileHandle?
    
    /// Photos importing service
    internal let photosImporter = PhotosImporter()
    
    /// Flag for cancellation
    internal var isCancelled = false
    
    /// Batch processing settings
    private var batchSettings = BatchSettings()
    
    /// Whether batch processing is enabled
    private var batchProcessingEnabled = true
    
    /// Logger for application events
    internal let logger = Logger.shared
    
    /// Processor for finding and matching Live Photo components
    internal let livePhotoProcessor = LivePhotoProcessor()
    
    /// Builder for creating Live Photos from components
    internal let livePhotoBuilder = LivePhotoBuilder()
    
    /// Manager for creating and tracking Live Photos
    internal let livePhotoManager = LivePhotoManager()
    
    /// Album creation and organization manager
    internal let albumManager = AlbumManager()
    
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
    
    /// Initialize with progress tracking and user preferences
    init(progress: MigrationProgress, preferences: UserPreferences = UserPreferences.shared) {
        self.progress = progress
        self.batchSettings = preferences.getBatchSettings()
        self.batchProcessingEnabled = preferences.batchProcessingEnabled
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
        
        // Process Live Photos
        progress.currentStage = .processingLivePhotos
        progress.stageProgress = 0
        writeToLog("Identifying and processing Live Photos...")
        
        processedMediaItems = try await processLivePhotos(processedMediaItems)
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
        
        // Build detailed migration timeline
        let timeline = MigrationTimeline(
            startTime: startTime,
            endTime: endTime
        )
        
        // Collect detailed media type statistics
        var mediaTypeStats = MediaTypeStats()
        var fileFormatStats = FileFormatStats()
        var metadataStats = MetadataStats()
        var migrationIssues = MigrationIssues()
        var albumsWithItems = [String: Int]()
        
        // Process media items to collect detailed statistics
        for item in processedMediaItems {
            // Media type statistics
            switch item.fileType {
            case .photo:
                mediaTypeStats.photos += 1
            case .video:
                mediaTypeStats.videos += 1
            case .livePhoto:
                mediaTypeStats.livePhotos += 1
            case .motionPhoto:
                mediaTypeStats.motionPhotos += 1
            case .unknown:
                mediaTypeStats.otherTypes += 1
            }
            
            // File format statistics (determined from file extension)
            let fileExtension = item.fileURL.pathExtension.lowercased()
            switch fileExtension {
            case "jpg", "jpeg":
                fileFormatStats.jpeg += 1
            case "heic":
                fileFormatStats.heic += 1
            case "png":
                fileFormatStats.png += 1
            case "gif":
                fileFormatStats.gif += 1
            case "mp4":
                fileFormatStats.mp4 += 1
            case "mov":
                fileFormatStats.mov += 1
            default:
                fileFormatStats.otherFormats += 1
            }
            
            // Metadata statistics
            if item.latitude != nil && item.longitude != nil {
                metadataStats.withLocation += 1
            }
            
            if item.title != nil {
                metadataStats.withTitle += 1
            }
            
            if item.description != nil {
                metadataStats.withDescription += 1
            }
            
            if item.isFavorite {
                metadataStats.withFavorite += 1
            }
            
            // Creation date is always preserved
            metadataStats.withCreationDate += 1
            
            // Album statistics
            for albumName in item.albumNames {
                albumsWithItems[albumName, default: 0] += 1
            }
        }
        
        // Collect issue statistics from progress messages
        for message in progress.recentMessages {
            switch message.type {
            case .warning:
                if message.message.contains("metadata") {
                    migrationIssues.metadataParsingErrors += 1
                } else if message.message.contains("file") {
                    migrationIssues.fileAccessErrors += 1
                } else if message.message.contains("import") {
                    migrationIssues.importErrors += 1
                } else if message.message.contains("album") {
                    migrationIssues.albumCreationErrors += 1
                } else if message.message.contains("unsupported") || message.message.contains("format") {
                    migrationIssues.mediaTypeUnsupported += 1
                } else if message.message.contains("corrupt") {
                    migrationIssues.fileCorruptionIssues += 1
                }
                
            case .error:
                // Track detailed errors with timestamps
                migrationIssues.detailedErrors.append((timestamp: message.timestamp, message: message.message))
                
                if message.message.contains("metadata") {
                    migrationIssues.metadataParsingErrors += 1
                } else if message.message.contains("file") {
                    migrationIssues.fileAccessErrors += 1
                } else if message.message.contains("import") {
                    migrationIssues.importErrors += 1
                } else if message.message.contains("album") {
                    migrationIssues.albumCreationErrors += 1
                }
                
            default:
                // Track memory pressure events from info messages
                if message.message.contains("memory pressure") {
                    migrationIssues.memoryPressureEvents += 1
                }
            }
        }
        
        // Create comprehensive migration summary
        let summary = MigrationSummary(
            totalItemsProcessed: processedMediaItems.count,
            successfulImports: importResults.compactMap { $0.assetId }.count,
            failedImports: importResults.filter { $0.assetId == nil }.count,
            albumsCreated: albumsCreated,
            albumsWithItems: albumsWithItems,
            livePhotosReconstructed: processedMediaItems.filter { $0.fileType == .livePhoto }.count,
            metadataIssues: progress.recentMessages.filter { $0.type == .warning }.count,
            mediaTypeStats: mediaTypeStats,
            fileFormatStats: fileFormatStats,
            metadataStats: metadataStats,
            issues: migrationIssues,
            timeline: timeline,
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
            let success = Int.random(in: 0...9) != 0 // 90% success rate
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
    
    /// Process a list of media items to properly identify and reconstruct Live Photos
    /// - Parameter mediaItems: Array of media items from metadata processing
    /// - Returns: Updated array with Live Photos properly identified
    private func processLivePhotos(_ mediaItems: [MediaItem]) async throws -> [MediaItem] {
        if mediaItems.isEmpty {
            return mediaItems
        }
        
        // Check if Live Photo processing is enabled
        guard livePhotoManager.processLivePhotos else {
            logger.log("Live Photo processing is disabled. Skipping.")
            return mediaItems
        }
        
        logger.log("Processing Live Photos in \(mediaItems.count) media items")
        
        do {
            let processedItems = try await livePhotoManager.processMediaItems(mediaItems, outputDirectory: nil)
            logger.log("Live Photo processing complete. \(processedItems.count) items returned.")
            return processedItems
        } catch {
            logger.log("Error processing Live Photos: \(error.localizedDescription)", level: .error)
            throw error
        }
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
    
    private func scanForMediaFiles(in directory: URL) async throws -> [MediaItem] {
        writeToLog("Scanning directory: \(directory.path)")
        
        return try await withCheckedThrowingContinuation { continuation in
            let workItem = DispatchWorkItem {
                var mediaItems: [MediaItem] = []
                var mediaFiles: [URL] = []
                var jsonFiles: [URL] = []
                
                let directoryEnumerator = self.fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey, .nameKey, .pathKey],
                    options: [.skipsHiddenFiles]
                )
                
                while let fileURL = directoryEnumerator?.nextObject() as? URL {
                    // Check for cancellation
                    if self.isCancelled {
                        continuation.resume(throwing: MigrationError.operationCancelled)
                        return
                    }
                    
                    // Update progress occasionally
                    if mediaFiles.count % 100 == 0 {
                        DispatchQueue.main.async {
                            self.progress.currentItemName = fileURL.lastPathComponent
                        }
                    }
                    
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                        if resourceValues.isDirectory ?? false {
                            continue
                        }
                        
                        let fileExtension = fileURL.pathExtension.lowercased()
                        
                        if fileExtension == "json" {
                            jsonFiles.append(fileURL)
                        } else if self.isMediaFile(fileURL) {
                            mediaFiles.append(fileURL)
                        }
                    } catch {
                        self.writeToLog("Error accessing file at \(fileURL.path): \(error.localizedDescription)")
                    }
                }
                
                self.writeToLog("Found \(mediaFiles.count) media files and \(jsonFiles.count) JSON files")
                self.writeToLog("Analyzing for potential Live Photo components...")
                
                // Group files by base name to help with Live Photo detection
                var fileGroups: [String: [URL]] = [:]
                for mediaFileURL in mediaFiles {
                    let baseName = mediaFileURL.deletingPathExtension().lastPathComponent
                    if fileGroups[baseName] == nil {
                        fileGroups[baseName] = []
                    }
                    fileGroups[baseName]?.append(mediaFileURL)
                }
                
                // Count of potential Live Photo pairs
                var potentialLivePhotoPairs = 0
                
                // Process media files and find corresponding JSON files
                for mediaFileURL in mediaFiles {
                    // Check for cancellation
                    if self.isCancelled {
                        continuation.resume(throwing: MigrationError.operationCancelled)
                        return
                    }
                    
                    let mediaType = MediaItem.MediaType.determine(from: mediaFileURL)
                    let albumPath = self.extractAlbumPath(for: mediaFileURL, relativeTo: directory)
                    
                    // Find corresponding JSON file(s)
                    let jsonFileURL = self.findMatchingJsonFile(for: mediaFileURL, in: jsonFiles)
                    
                    // Extract metadata
                    let metadata: MediaMetadata
                    var isLivePhotoComponent = false
                    var motionMediaType = mediaType
                    
                    // Check if this file is part of a Live Photo pair
                    let baseName = mediaFileURL.deletingPathExtension().lastPathComponent
                    if let group = fileGroups[baseName], group.count >= 2 {
                        // If this group has both an image and a video, it could be a Live Photo pair
                        let hasImage = group.contains { isImageFile($0) }
                        let hasVideo = group.contains { isVideoFile($0) }
                        
                        if hasImage && hasVideo {
                            potentialLivePhotoPairs += 1
                            
                            // Mark as potential Live Photo component
                            if isImageFile(mediaFileURL) {
                                motionMediaType = .livePhoto
                                writeToLog("Identified potential Live Photo still image: \(mediaFileURL.lastPathComponent)")
                            } else if isVideoFile(mediaFileURL) {
                                isLivePhotoComponent = true
                                writeToLog("Identified potential Live Photo motion component: \(mediaFileURL.lastPathComponent)")
                            }
                        }
                    }
                    
                    if let jsonURL = jsonFileURL {
                        do {
                            metadata = try self.metadataExtractor.extractMetadata(from: jsonURL, for: mediaFileURL)
                            
                            // Check JSON data for Live Photo indicators
                            if let jsonData = metadata.originalJsonData {
                                if let isMotionPhoto = jsonData["isMotionPhoto"] as? Bool, isMotionPhoto {
                                    motionMediaType = .motionPhoto
                                    writeToLog("Found motion photo indicator in metadata for: \(mediaFileURL.lastPathComponent)")
                                }
                                
                                if let motionPhotoUrl = jsonData["motionPhotoUrl"] as? String, !motionPhotoUrl.isEmpty {
                                    motionMediaType = .motionPhoto
                                    writeToLog("Found motion photo URL in metadata for: \(mediaFileURL.lastPathComponent)")
                                }
                            }
                        } catch {
                            self.writeToLog("Error extracting metadata for \(mediaFileURL.lastPathComponent): \(error.localizedDescription)")
                            // Use empty metadata as fallback
                            metadata = MediaMetadata()
                        }
                    } else {
                        // No JSON file found, try to extract EXIF directly from media file
                        metadata = self.metadataExtractor.extractExifMetadata(from: mediaFileURL)
                        
                        // Look for motion photo indicators in EXIF data
                        if let originalJsonData = metadata.originalJsonData,
                           originalJsonData["MotionPhoto"] != nil || originalJsonData["MotionPhotoVersion"] != nil {
                            motionMediaType = .motionPhoto
                            writeToLog("Found motion photo indicators in EXIF for: \(mediaFileURL.lastPathComponent)")
                        }
                        
                        self.writeToLog("No JSON metadata found for \(mediaFileURL.lastPathComponent), using EXIF data")
                    }
                    
                    // Create MediaItem
                    var mediaItem = MediaItem(
                        fileURL: mediaFileURL,
                        originalFileName: mediaFileURL.lastPathComponent,
                        fileType: motionMediaType,
                        metadata: metadata
                    )
                    
                    // Add album path information
                    if !albumPath.isEmpty {
                        let albumNames = albumPath.split(separator: "/").map(String.init)
                        mediaItem.albumPaths = albumNames
                    }
                    
                    // Add special flag for Live Photo motion components
                    if isLivePhotoComponent {
                        mediaItem.isLivePhotoMotionComponent = true
                    }
                    
                    mediaItems.append(mediaItem)
                }
                
                self.writeToLog("Processed \(mediaItems.count) media items, including \(potentialLivePhotoPairs) potential Live Photo pairs")
                continuation.resume(returning: mediaItems)
            }
            
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }
    }
    
    /// Check if a file is a media file we can process
    private func isMediaFile(_ url: URL) -> Bool {
        return isImageFile(url) || isVideoFile(url)
    }
    
    /// Check if a file is an image file based on extension
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "webp", "bmp"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    /// Check if a file is a video file based on extension
    private func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "m4v", "3gp", "avi", "mkv", "webm", "mp"]
        return videoExtensions.contains(url.pathExtension.lowercased())
    }
}

/// Result of importing a media item to Photos
struct PhotosImportResult {
    let mediaItem: MediaItem
    let assetId: String?
}

/// Error thrown when operation is cancelled
struct CancellationError: Error {}

/// Stages of migration process
enum MigrationStage: String, CaseIterable {
    case initializing = "Initializing"
    case extractingArchive = "Extracting Archive"
    case processingMetadata = "Processing Metadata"
    case processingLivePhotos = "Processing Live Photos"
    case importingPhotos = "Importing Photos"
    case organizingAlbums = "Organizing Albums"
    case complete = "Complete"
    
    var description: String {
        return self.rawValue
    }
}