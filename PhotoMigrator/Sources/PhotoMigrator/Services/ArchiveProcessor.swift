import Foundation
import Combine
import Photos
import UniformTypeIdentifiers

class ArchiveProcessor: ObservableObject {
    @Published var progress = MigrationProgress()
    @Published var error: MigrationError?
    
    private var cancellables = Set<AnyCancellable>()
    private var isCancelled = false
    private let fileManager = FileManager.default
    private let metadataExtractor = MetadataExtractor()
    private let photosImporter = PhotosImporter()
    private let livePhotoProcessor = LivePhotoProcessor()
    private let albumManager = AlbumManager()
    private let logFileURL: URL
    private var logFileHandle: FileHandle?
    
    init() {
        // Setup logging
        let logDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PhotoMigrator", isDirectory: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        logFileURL = logDirectory.appendingPathComponent("migration_log_\(timestamp).txt")
        
        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        fileManager.createFile(atPath: logFileURL.path, contents: nil)
        
        do {
            logFileHandle = try FileHandle(forWritingTo: logFileURL)
        } catch {
            print("Failed to open log file: \(error)")
        }
        
        writeToLog("PhotoMigrator started at \(Date())")
    }
    
    deinit {
        try? logFileHandle?.close()
    }
    
    func processArchive(at archiveURL: URL) async throws -> MigrationSummary {
        progress.currentStage = .initializing
        isCancelled = false
        writeToLog("Starting migration process with archive: \(archiveURL.path)")
        
        let startTime = Date()
        progress.elapsedTime = 0
        
        // Create temp directory for extraction
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        defer {
            // Clean up temp directory when done
            try? fileManager.removeItem(at: tempDirectory)
        }
        
        // 1. Extract archive if needed
        progress.currentStage = .scanning
        let extractedPath: URL
        
        if isArchiveFile(archiveURL) {
            writeToLog("Extracting archive...")
            extractedPath = try await extractArchive(archiveURL, to: tempDirectory)
        } else if isDirectory(archiveURL) {
            // User provided already extracted directory
            extractedPath = archiveURL
            writeToLog("Using pre-extracted directory: \(extractedPath.path)")
        } else {
            throw MigrationError.invalidArchiveStructure
        }
        
        // 2. Scan for media files and their metadata
        writeToLog("Scanning for media files...")
        let mediaItems = try await scanForMediaFiles(in: extractedPath)
        
        // 3. Process and import files to Photos library
        progress.totalItems = mediaItems.count
        progress.currentStage = .processingMedia
        writeToLog("Found \(mediaItems.count) media items to process")
        
        // Group Live Photo components
        let processedMediaItems = try await livePhotoProcessor.processLivePhotoComponents(mediaItems: mediaItems)
        writeToLog("Processed Live Photo components, identified \(processedMediaItems.filter { $0.fileType == .livePhoto }.count) Live Photos")
        
        // Import to Photos
        progress.currentStage = .importingToPhotos
        let importResults = try await importMediaToPhotos(processedMediaItems)
        
        // 4. Organize into albums
        progress.currentStage = .organizingAlbums
        let albumsCreated = try await createAlbums(for: importResults)
        
        // 5. Generate summary
        progress.currentStage = .complete
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        let summary = MigrationSummary(
            totalItemsProcessed: processedMediaItems.count,
            successfulImports: importResults.compactMap { $0.assetId }.count,
            failedImports: importResults.filter { $0.assetId == nil }.count,
            albumsCreated: albumsCreated,
            livePhotosReconstructed: processedMediaItems.filter { $0.fileType == .livePhoto }.count,
            metadataIssues: progress.recentMessages.filter { $0.type == .warning }.count,
            logPath: logFileURL
        )
        
        writeToLog("Migration completed in \(String(format: "%.1f", totalTime)) seconds")
        writeToLog("Summary: Processed \(summary.totalItemsProcessed) items, \(summary.successfulImports) successful, \(summary.failedImports) failed")
        
        return summary
    }
    
    func cancelMigration() {
        isCancelled = true
        writeToLog("Migration cancelled by user")
    }
    
    func reset() {
        progress = MigrationProgress()
        error = nil
        isCancelled = false
    }
    
    // MARK: - Private Methods
    
    private func isArchiveFile(_ url: URL) -> Bool {
        let archiveExtensions = ["zip", "tar", "gz", "tgz"]
        return archiveExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
    
    private func extractArchive(_ archiveURL: URL, to destinationURL: URL) async throws -> URL {
        writeToLog("Extracting \(archiveURL.lastPathComponent) to \(destinationURL.path)")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Use the built-in Archive Utility to extract the files
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                    process.arguments = ["-xk", archiveURL.path, destinationURL.path]
                    
                    try process.run()
                    process.waitUntilExit()
                    
                    if process.terminationStatus != 0 {
                        self.writeToLog("Extraction failed with status: \(process.terminationStatus)")
                        continuation.resume(throwing: MigrationError.archiveExtractionFailed)
                        return
                    }
                    
                    // Look for the Google Photos directory structure
                    let contents = try self.fileManager.contentsOfDirectory(atPath: destinationURL.path)
                    
                    // Check if we can find "Google Photos" or "Takeout" in the extracted contents
                    var photosDir = destinationURL
                    
                    if contents.contains("Takeout") {
                        photosDir = destinationURL.appendingPathComponent("Takeout")
                        let takeoutContents = try self.fileManager.contentsOfDirectory(atPath: photosDir.path)
                        
                        if takeoutContents.contains("Google Photos") {
                            photosDir = photosDir.appendingPathComponent("Google Photos")
                        }
                    } else if contents.contains("Google Photos") {
                        photosDir = destinationURL.appendingPathComponent("Google Photos")
                    }
                    
                    if !self.fileManager.fileExists(atPath: photosDir.path) {
                        self.writeToLog("Could not find Google Photos directory in the archive")
                        continuation.resume(throwing: MigrationError.invalidArchiveStructure)
                        return
                    }
                    
                    self.writeToLog("Extraction completed successfully")
                    continuation.resume(returning: photosDir)
                } catch {
                    self.writeToLog("Extraction error: \(error.localizedDescription)")
                    continuation.resume(throwing: MigrationError.archiveExtractionFailed)
                }
            }
        }
    }
    
    private func scanForMediaFiles(in directory: URL) async throws -> [MediaItem] {
        writeToLog("Scanning directory: \(directory.path)")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
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
                    if let jsonURL = jsonFileURL {
                        do {
                            metadata = try self.metadataExtractor.extractMetadata(from: jsonURL, for: mediaFileURL)
                        } catch {
                            self.writeToLog("Error extracting metadata for \(mediaFileURL.lastPathComponent): \(error.localizedDescription)")
                            // Use empty metadata as fallback
                            metadata = MediaMetadata()
                        }
                    } else {
                        // No JSON file found, try to extract EXIF directly from media file
                        metadata = self.metadataExtractor.extractExifMetadata(from: mediaFileURL)
                        self.writeToLog("No JSON metadata found for \(mediaFileURL.lastPathComponent), using EXIF data")
                    }
                    
                    // Create MediaItem
                    var mediaItem = MediaItem(
                        fileURL: mediaFileURL,
                        originalFileName: mediaFileURL.lastPathComponent,
                        fileType: mediaType,
                        metadata: metadata
                    )
                    
                    if !albumPath.isEmpty {
                        mediaItem.albumPaths = [albumPath]
                    }
                    
                    mediaItems.append(mediaItem)
                }
                
                self.writeToLog("Successfully processed \(mediaItems.count) media items")
                continuation.resume(returning: mediaItems)
            }
        }
    }
    
    private func importMediaToPhotos(_ mediaItems: [MediaItem]) async throws -> [ImportResult] {
        writeToLog("Starting import to Apple Photos")
        
        var results: [ImportResult] = []
        
        for (index, item) in mediaItems.enumerated() {
            // Check for cancellation
            if isCancelled {
                throw MigrationError.operationCancelled
            }
            
            // Update progress
            DispatchQueue.main.async {
                self.progress.processedItems = index
                self.progress.currentItemName = item.originalFileName
                self.progress.stageProgress = Double(index) / Double(mediaItems.count)
            }
            
            // Import based on media type
            let result: ImportResult
            do {
                if item.fileType == .livePhoto {
                    result = try await photosImporter.importLivePhoto(item, motionURL: item.livePhotoComponentURL!)
                    
                    if result.assetId != nil {
                        DispatchQueue.main.async {
                            self.progress.livePhotosReconstructed += 1
                        }
                    }
                } else {
                    result = try await photosImporter.importSingleMedia(item)
                }
                
                if item.fileType == .image {
                    DispatchQueue.main.async {
                        self.progress.photosProcessed += 1
                    }
                } else if item.fileType == .video {
                    DispatchQueue.main.async {
                        self.progress.videosProcessed += 1
                    }
                }
                
                if result.assetId == nil {
                    DispatchQueue.main.async {
                        self.progress.failedItems += 1
                    }
                    writeToLog("Failed to import \(item.originalFileName): \(result.error?.localizedDescription ?? "Unknown error")")
                }
            } catch {
                result = ImportResult(originalItem: item, assetId: nil, error: error)
                DispatchQueue.main.async {
                    self.progress.failedItems += 1
                }
                writeToLog("Error importing \(item.originalFileName): \(error.localizedDescription)")
            }
            
            results.append(result)
            
            // Add any warnings or errors to recent messages
            if let error = result.error {
                DispatchQueue.main.async {
                    self.progress.recentMessages.append(.error("Failed to import \(item.originalFileName): \(error.localizedDescription)"))
                    // Keep only the 10 most recent messages
                    if self.progress.recentMessages.count > 10 {
                        self.progress.recentMessages.removeFirst()
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.progress.processedItems = mediaItems.count
            self.progress.stageProgress = 1.0
        }
        
        writeToLog("Completed import to Apple Photos: \(results.compactMap { $0.assetId }.count) successful, \(results.filter { $0.assetId == nil }.count) failed")
        
        return results
    }
    
    private func createAlbums(for importResults: [ImportResult]) async throws -> Int {
        writeToLog("Creating albums in Apple Photos")
        
        // Group imported assets by album path
        var albumsToCreate: [String: [PHAsset]] = [:]
        
        for result in importResults {
            guard let assetId = result.assetId, let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject else {
                continue
            }
            
            for albumPath in result.originalItem.albumPaths {
                if !albumPath.isEmpty {
                    if albumsToCreate[albumPath] == nil {
                        albumsToCreate[albumPath] = []
                    }
                    albumsToCreate[albumPath]?.append(asset)
                }
            }
        }
        
        // Create albums and add assets
        var createdAlbums = 0
        
        for (albumPath, assets) in albumsToCreate {
            // Check for cancellation
            if isCancelled {
                throw MigrationError.operationCancelled
            }
            
            DispatchQueue.main.async {
                self.progress.currentItemName = "Creating album: \(albumPath)"
                self.progress.stageProgress = Double(createdAlbums) / Double(albumsToCreate.count)
            }
            
            do {
                try await albumManager.createAlbumIfNeeded(named: albumPath, with: assets)
                createdAlbums += 1
                
                DispatchQueue.main.async {
                    self.progress.albumsCreated = createdAlbums
                }
                
                writeToLog("Created album: \(albumPath) with \(assets.count) items")
            } catch {
                writeToLog("Failed to create album \(albumPath): \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.progress.recentMessages.append(.error("Failed to create album \(albumPath): \(error.localizedDescription)"))
                    // Keep only the 10 most recent messages
                    if self.progress.recentMessages.count > 10 {
                        self.progress.recentMessages.removeFirst()
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.progress.stageProgress = 1.0
        }
        
        writeToLog("Album creation completed: created \(createdAlbums) albums")
        return createdAlbums
    }
    
    private func isMediaFile(_ url: URL) -> Bool {
        let mediaExtensions = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp", 
                               "mp4", "mov", "m4v", "3gp", "avi", "mkv", "webm", "mp"]
        return mediaExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func findMatchingJsonFile(for mediaFile: URL, in jsonFiles: [URL]) -> URL? {
        let fileName = mediaFile.lastPathComponent
        
        // Try various JSON naming patterns
        let possibleJsonNames = [
            "\(fileName).json",
            "\(fileName).supplemental-metadata.json",
            "\(fileName).sup-meta.json",
            // For edited photos
            "\(mediaFile.deletingPathExtension().lastPathComponent)-edited.\(mediaFile.pathExtension).json"
        ]
        
        // First try exact matches
        for jsonName in possibleJsonNames {
            let potentialJsonPath = mediaFile.deletingLastPathComponent().appendingPathComponent(jsonName)
            if let matchingJson = jsonFiles.first(where: { $0.path == potentialJsonPath.path }) {
                return matchingJson
            }
        }
        
        // If no exact match, try to find JSON files that start with the media file name
        // This handles cases where long filenames might be truncated in the JSON file name
        let directory = mediaFile.deletingLastPathComponent()
        let jsonFilesInSameDir = jsonFiles.filter { $0.deletingLastPathComponent().path == directory.path }
        
        let baseFileName = mediaFile.deletingPathExtension().lastPathComponent
        for jsonFile in jsonFilesInSameDir {
            let jsonFileName = jsonFile.lastPathComponent
            if jsonFileName.hasPrefix(baseFileName) {
                return jsonFile
            }
        }
        
        return nil
    }
    
    private func extractAlbumPath(for fileURL: URL, relativeTo baseURL: URL) -> String {
        // Get the relative path from the base directory to the file's directory
        let fileDirectory = fileURL.deletingLastPathComponent()
        let relativePath = fileDirectory.path.replacingOccurrences(of: baseURL.path, with: "")
        
        if relativePath.isEmpty {
            return ""
        }
        
        // Clean up the path
        var albumPath = relativePath
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .replacingOccurrences(of: "/", with: " - ")
        
        // Skip top-level directories that are likely not albums
        let topLevelDirsToSkip = ["Google Photos", "Takeout"]
        for dirToSkip in topLevelDirsToSkip {
            if albumPath == dirToSkip || albumPath.hasPrefix("\(dirToSkip) - ") {
                albumPath = albumPath.replacingOccurrences(of: "\(dirToSkip) - ", with: "")
                albumPath = albumPath.replacingOccurrences(of: dirToSkip, with: "")
                albumPath = albumPath.trimmingCharacters(in: CharacterSet(charactersIn: " -"))
            }
        }
        
        return albumPath
    }
    
    private func writeToLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        print(logMessage, terminator: "")
        
        // Write to log file
        if let data = logMessage.data(using: .utf8) {
            try? logFileHandle?.write(contentsOf: data)
        }
    }
}

struct ImportResult {
    let originalItem: MediaItem
    let assetId: String?
    let error: Error?
}
