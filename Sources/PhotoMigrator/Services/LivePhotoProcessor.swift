import Foundation
import AVFoundation
import Photos
import UniformTypeIdentifiers

/// A service to identify and reconstruct Live Photos from various formats
class LivePhotoProcessor {
    private let fileManager = FileManager.default
    private let logger = Logger.shared
    private let builder = LivePhotoBuilder()
    
    /// Maximum allowed time difference between photo and video components (in seconds)
    var maximumTimestampDifference: TimeInterval = 60.0 // Default: 1 minute
    
    /// Identifies Live Photo pairs in a collection of media items
    /// - Parameter mediaItems: Array of MediaItem objects to process
    /// - Returns: Array of LivePhotoPair objects representing matched photo-video pairs
    func identifyLivePhotoPairs(in mediaItems: [MediaItem]) -> [LivePhotoPair] {
        logger.log("Starting Live Photo pair detection for \(mediaItems.count) media items")
        var pairs: [LivePhotoPair] = []
        
        // Group items by base filename
        var itemsByBaseName: [String: [MediaItem]] = [:]
        
        for item in mediaItems {
            let fileName = item.fileURL.deletingPathExtension().lastPathComponent
            
            if itemsByBaseName[fileName] == nil {
                itemsByBaseName[fileName] = []
            }
            itemsByBaseName[fileName]?.append(item)
        }
        
        // Find pairs with matching filenames
        for (baseName, items) in itemsByBaseName {
            if items.count >= 2 {
                // Look for photo + video combinations
                let photoItems = items.filter { $0.fileType == .photo }
                let videoItems = items.filter { $0.fileType == .video }
                
                if !photoItems.isEmpty && !videoItems.isEmpty {
                    // Find best photo and video match based on timestamps
                    if let bestPhotoItem = photoItems.first, let bestVideoItem = videoItems.first {
                        // Create a pair
                        let pair = LivePhotoPair(photoItem: bestPhotoItem, videoItem: bestVideoItem)
                        pairs.append(pair)
                        logger.log("Found Live Photo pair: \(baseName)")
                    }
                }
            }
        }
        
        // If no exact filename matches found, try timestamp-based matching for unpaired items
        if !pairs.isEmpty {
            let pairedPhotoIds = Set(pairs.map { $0.photoItem.id })
            let pairedVideoIds = Set(pairs.map { $0.videoItem.id })
            
            let unpairedPhotos = mediaItems.filter { $0.fileType == .photo && !pairedPhotoIds.contains($0.id) }
            let unpairedVideos = mediaItems.filter { $0.fileType == .video && !pairedVideoIds.contains($0.id) }
            
            // Try to match based on timestamps
            for photo in unpairedPhotos {
                for video in unpairedVideos {
                    let timeDifference = abs(photo.timestamp.timeIntervalSince(video.timestamp))
                    
                    if timeDifference <= maximumTimestampDifference {
                        // Match found - timestamps are close enough
                        let pair = LivePhotoPair(photoItem: photo, videoItem: video)
                        pairs.append(pair)
                        logger.log("Found Live Photo pair based on timestamps: \(photo.fileURL.lastPathComponent) + \(video.fileURL.lastPathComponent)")
                        break
                    }
                }
            }
        }
        
        logger.log("Identified \(pairs.count) Live Photo pairs from \(mediaItems.count) media items")
        return pairs
    }
    
    /// Creates a Live Photo from a photo-video pair
    /// - Parameters:
    ///   - pair: The LivePhotoPair to process
    ///   - outputDirectory: Directory to store the processed Live Photo
    /// - Returns: Processing result with the Live Photo URL
    func createLivePhoto(from pair: LivePhotoPair, outputDirectory: URL? = nil) async throws -> LivePhotoPair.ProcessingResult {
        logger.log("Creating Live Photo from \(pair.photoItem.fileURL.lastPathComponent) and \(pair.videoItem.fileURL.lastPathComponent)")
        
        // Validate files exist
        guard fileManager.fileExists(atPath: pair.photoItem.fileURL.path) else {
            let error = MigrationError.fileAccessError(path: pair.photoItem.fileURL.path)
            logger.log("Photo component not found: \(pair.photoItem.fileURL.path)", level: .error)
            return LivePhotoPair.ProcessingResult(
                originalPair: pair,
                livePhotoURL: nil,
                success: false,
                error: error
            )
        }
        
        guard fileManager.fileExists(atPath: pair.videoItem.fileURL.path) else {
            let error = MigrationError.fileAccessError(path: pair.videoItem.fileURL.path)
            logger.log("Video component not found: \(pair.videoItem.fileURL.path)", level: .error)
            return LivePhotoPair.ProcessingResult(
                originalPair: pair,
                livePhotoURL: nil,
                success: false,
                error: error
            )
        }
        
        // Create output directory if needed and specified
        let outputDir: URL
        if let specifiedOutputDir = outputDirectory {
            outputDir = specifiedOutputDir
            if !fileManager.fileExists(atPath: outputDir.path) {
                try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
                logger.log("Created output directory: \(outputDir.path)")
            }
        } else {
            outputDir = fileManager.temporaryDirectory.appendingPathComponent("LivePhotos", isDirectory: true)
            if !fileManager.fileExists(atPath: outputDir.path) {
                try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
                logger.log("Created temporary directory: \(outputDir.path)")
            }
        }
        
        // Prepare metadata
        var metadata: [String: Any] = [
            "creationDate": pair.timestamp,
            "favorite": pair.isFavorite
        ]
        
        // Extract additional metadata from original items
        if let latitude = pair.photoItem.latitude, let longitude = pair.photoItem.longitude {
            metadata["location"] = [
                "latitude": latitude,
                "longitude": longitude
            ]
        }
        
        if let description = pair.photoItem.description {
            metadata["description"] = description
        }
        
        if let title = pair.photoItem.title {
            metadata["title"] = title
        }
        
        do {
            // Sync the content identifiers between photo and video components
            let synced = await syncLivePhotoComponents(photoURL: pair.photoItem.fileURL, videoURL: pair.videoItem.fileURL)
            if !synced {
                logger.log("Warning: Failed to sync content identifiers between components", level: .warning)
            }
            
            // Create the Live Photo
            let outputURL = outputDir.appendingPathComponent("\(pair.baseName)_livephoto.jpg")
            
            // Attempt to import the live photo
            let assetId = try await importLivePhoto(
                imageURL: pair.photoItem.fileURL,
                videoURL: pair.videoItem.fileURL,
                metadata: metadata
            )
            
            if let assetId = assetId {
                logger.log("Successfully created Live Photo with asset ID: \(assetId)")
                
                return LivePhotoPair.ProcessingResult(
                    originalPair: pair,
                    livePhotoURL: outputURL,
                    success: true,
                    error: nil
                )
            } else {
                let error = MigrationError.importFailed(reason: "Failed to create Live Photo asset")
                logger.log("Failed to create Live Photo asset", level: .error)
                return LivePhotoPair.ProcessingResult(
                    originalPair: pair,
                    livePhotoURL: nil,
                    success: false,
                    error: error
                )
            }
        } catch {
            logger.log("Error creating Live Photo: \(error.localizedDescription)", level: .error)
            return LivePhotoPair.ProcessingResult(
                originalPair: pair,
                livePhotoURL: nil,
                success: false,
                error: error
            )
        }
    }
    
    /// Process multiple Live Photo pairs
    /// - Parameters:
    ///   - pairs: Array of LivePhotoPair objects to process
    ///   - outputDirectory: Directory to store processed Live Photos
    /// - Returns: Array of processing results
    func processLivePhotos(pairs: [LivePhotoPair], outputDirectory: URL) async throws -> [LivePhotoPair.ProcessingResult] {
        logger.log("Beginning batch processing of \(pairs.count) Live Photo pairs")
        
        var results: [LivePhotoPair.ProcessingResult] = []
        
        // Process each pair
        for (index, pair) in pairs.enumerated() {
            logger.log("Processing Live Photo pair \(index + 1) of \(pairs.count): \(pair.baseName)")
            
            do {
                let result = try await createLivePhoto(from: pair, outputDirectory: outputDirectory)
                results.append(result)
                
                if result.success {
                    logger.log("Successfully processed pair \(index + 1): \(pair.baseName)")
                } else {
                    logger.log("Failed to process pair \(index + 1): \(pair.baseName)", level: .warning)
                }
            } catch {
                logger.log("Error processing pair \(index + 1): \(error.localizedDescription)", level: .error)
                
                let result = LivePhotoPair.ProcessingResult(
                    originalPair: pair,
                    livePhotoURL: nil,
                    success: false,
                    error: error
                )
                results.append(result)
            }
        }
        
        let successCount = results.filter { $0.success }.count
        logger.log("Completed batch processing. Successfully processed \(successCount) of \(pairs.count) Live Photo pairs")
        
        return results
    }
    
    /// Processes a list of media items to identify and group Live Photo components
    /// - Parameter mediaItems: Array of MediaItem objects to process
    /// - Returns: Array of processed MediaItem objects with Live Photos properly identified
    func processLivePhotoComponents(mediaItems: [MediaItem]) async throws -> [MediaItem] {
        logger.log("Starting Live Photo component detection for \(mediaItems.count) media items")
        var processedItems = mediaItems
        var livePhotoComponents: [String: [MediaItem]] = [:]
        
        // First pass: identify potential Live Photo components and group them by base name
        for (index, item) in mediaItems.enumerated() {
            let fileName = item.fileURL.deletingPathExtension().lastPathComponent
            
            // Group items by their base filename
            if livePhotoComponents[fileName] == nil {
                livePhotoComponents[fileName] = []
            }
            livePhotoComponents[fileName]?.append(processedItems[index])
            
            // Mark Pixel Motion Photo MP files as special components
            if item.fileURL.pathExtension.lowercased() == "mp" {
                processedItems[index].isLivePhotoMotionComponent = true
            }
        }
        
        // Second pass: process groups to create Live Photos where possible
        var finalItems: [MediaItem] = []
        var processedIndexes = Set<Int>()
        var livePhotosDetected = 0
        
        for (_, components) in livePhotoComponents {
            if components.count >= 2 {
                // Identify still image and video components
                let stillComponents = components.filter { isStillImageFile($0.fileURL) }
                let videoComponents = components.filter { isVideoFile($0.fileURL) || isMotionPhotoComponent($0.fileURL) }
                
                if let stillComponent = stillComponents.first, !videoComponents.isEmpty {
                    // Create a Live Photo by pairing the components
                    let livePhotoItem = try await createLivePhotoItem(
                        stillComponent: stillComponent, 
                        videoComponent: videoComponents.first!,
                        components: components,
                        processedItems: &processedItems, 
                        processedIndexes: &processedIndexes
                    )
                    
                    finalItems.append(livePhotoItem)
                    livePhotosDetected += 1
                    continue
                }
            }
            
            // If not identified as a Live Photo, add components individually
            for component in components {
                if let index = processedItems.firstIndex(where: { $0.id == component.id }), 
                   !processedIndexes.contains(index) {
                    // Skip components already marked as part of a Live Photo
                    if !component.isLivePhotoMotionComponent {
                        finalItems.append(component)
                    }
                    processedIndexes.insert(index)
                }
            }
        }
        
        // Add any remaining items not processed as Live Photo components
        for (index, item) in processedItems.enumerated() {
            if !processedIndexes.contains(index) {
                finalItems.append(item)
            }
        }
        
        logger.log("Live Photo detection complete. Found \(livePhotosDetected) Live Photos from \(mediaItems.count) items")
        return finalItems
    }
    
    /// Creates a Live Photo item by combining a still image with a motion video component
    /// - Parameters:
    ///   - stillComponent: The still image component
    ///   - videoComponent: The video component
    ///   - components: All components in the same group
    ///   - processedItems: Reference to the full list of processed items
    ///   - processedIndexes: Set of indexes that have been processed
    /// - Returns: A new MediaItem configured as a Live Photo
    private func createLivePhotoItem(
        stillComponent: MediaItem,
        videoComponent: MediaItem,
        components: [MediaItem],
        processedItems: inout [MediaItem],
        processedIndexes: inout Set<Int>
    ) async throws -> MediaItem {
        // Convert Pixel Motion Photo MP to MP4 if necessary
        var videoURL = videoComponent.fileURL
        
        if isMotionPhotoComponent(videoComponent.fileURL) {
            do {
                videoURL = try await convertMPtoMP4(videoComponent.fileURL)
                logger.log("Converted motion photo component \(videoComponent.fileURL.lastPathComponent) to MP4")
            } catch {
                logger.log("Failed to convert MP to MP4: \(error.localizedDescription)", level: .error)
                throw error
            }
        }
        
        // Create a new Live Photo item with properties from the still component
        var livePhotoItem = stillComponent
        livePhotoItem.fileType = .livePhoto
        livePhotoItem.livePhotoComponentURL = videoURL
        
        // Mark all components as processed
        for component in components {
            if let index = processedItems.firstIndex(where: { $0.id == component.id }) {
                processedIndexes.insert(index)
            }
        }
        
        logger.log("Created Live Photo item pairing \(stillComponent.fileURL.lastPathComponent) with \(videoComponent.fileURL.lastPathComponent)")
        return livePhotoItem
    }
    
    /// Detects Live Photo pairs in a list of file paths
    /// - Parameter mediaFiles: Array of file paths to search
    /// - Returns: Dictionary mapping still image paths to their corresponding motion video paths
    func detectLivePhotoPairs(in mediaFiles: [String]) -> [String: String] {
        var pairs: [String: String] = [:]
        var potentialPairs: [String: [String]] = [:]
        
        // Group files by base name
        for filePath in mediaFiles {
            let url = URL(fileURLWithPath: filePath)
            let fileName = url.deletingPathExtension().lastPathComponent
            
            if potentialPairs[fileName] == nil {
                potentialPairs[fileName] = []
            }
            potentialPairs[fileName]?.append(filePath)
        }
        
        // Find pairs with image and video components
        for (_, files) in potentialPairs {
            if files.count >= 2 {
                let imageFiles = files.filter { isStillImageFile(URL(fileURLWithPath: $0)) }
                let videoFiles = files.filter { isVideoFile(URL(fileURLWithPath: $0)) || isMotionPhotoComponent(URL(fileURLWithPath: $0)) }
                
                if let imageFile = imageFiles.first, let videoFile = videoFiles.first {
                    pairs[imageFile] = videoFile
                }
            }
        }
        
        return pairs
    }
    
    /// Checks if a file is a valid Live Photo component based on its extension
    /// - Parameter path: String path to the file
    /// - Returns: Whether the file is a valid Live Photo component
    func isValidLivePhotoComponent(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return isStillImageFile(url) || isVideoFile(url) || isMotionPhotoComponent(url)
    }
    
    /// Gets the base name of a file path without extension
    func extractBaseNameFromPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.deletingPathExtension().lastPathComponent
    }
    
    /// Creates a LivePhoto media item from separate image and video items
    /// - Parameters:
    ///   - imageItem: Still image MediaItem
    ///   - videoItem: Video MediaItem
    /// - Returns: A new MediaItem with live photo properties
    func createLivePhotoFromComponents(imageItem: MediaItem, videoItem: MediaItem) -> MediaItem {
        var livePhotoItem = imageItem
        livePhotoItem.fileType = .livePhoto
        livePhotoItem.isLivePhotoMotionComponent = true
        livePhotoItem.livePhotoComponentURL = videoItem.fileURL
        
        return livePhotoItem
    }
    
    /// Determines if a new video component should replace an existing pair match
    /// - Parameters:
    ///   - existingVideoPath: Path to the current video component
    ///   - newVideoPath: Path to the potential replacement video
    ///   - getModificationDate: Function to get file modification date
    /// - Returns: Whether to replace the existing component
    func shouldReplaceExistingPair(
        existingVideoPath: String,
        newVideoPath: String,
        getModificationDate: (String) -> Date? = { path in
            return try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
        }
    ) -> Bool {
        // Compare modification dates to choose newer component
        guard let existingDate = getModificationDate(existingVideoPath),
              let newDate = getModificationDate(newVideoPath) else {
            // If dates can't be determined, don't replace
            return false
        }
        
        // Return true if new component is newer
        return newDate > existingDate
    }
    
    /// Import a Live Photo using the builder
    /// - Parameters:
    ///   - imageURL: URL to the still image component
    ///   - videoURL: URL to the video component
    ///   - metadata: Optional metadata to apply
    /// - Returns: Asset identifier if successful
    func importLivePhoto(imageURL: URL, videoURL: URL, metadata: [String: Any]? = nil) async throws -> String? {
        return try await builder.buildAndImportLivePhoto(
            imageURL: imageURL,
            videoURL: videoURL,
            metadata: metadata
        )
    }
    
    /// Verify a Live Photo was properly created
    /// - Parameter localIdentifier: Asset identifier to check
    /// - Returns: Whether the asset is a valid Live Photo
    func verifyLivePhoto(localIdentifier: String) -> Bool {
        return builder.verifyLivePhoto(localIdentifier: localIdentifier)
    }
    
    /// Converts a Pixel Motion Photo MP file to MP4 format
    /// - Parameter mpURL: URL of the MP file to convert
    /// - Returns: URL of the converted MP4 file
    private func convertMPtoMP4(_ mpURL: URL) async throws -> URL {
        let tempDir = fileManager.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")
        
        return try await withCheckedThrowingContinuation { continuation in
            // Create AVAsset from the MP file
            let asset = AVAsset(url: mpURL)
            
            // Setup export session
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                continuation.resume(throwing: MigrationError.importFailed(reason: "Could not create export session"))
                return
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            
            // Perform the export
            exportSession.exportAsynchronously {
                // Capture status locally to avoid @Sendable warning
                let status = exportSession.status
                let error = exportSession.error
                
                switch status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    continuation.resume(throwing: error ?? MigrationError.importFailed(reason: "Unknown export error"))
                case .cancelled:
                    continuation.resume(throwing: MigrationError.operationCancelled)
                default:
                    continuation.resume(throwing: MigrationError.importFailed(reason: "Unexpected export status"))
                }
            }
        }
    }
    
    /// Sync a Live Photo's components by ensuring they have matching metadata
    /// - Parameters:
    ///   - photoURL: URL of the still photo component
    ///   - videoURL: URL of the video component
    /// - Returns: Whether the sync was successful
    func syncLivePhotoComponents(photoURL: URL, videoURL: URL) async -> Bool {
        // Delegate to the builder for sync operations
        return await builder.syncContentIdentifiers(photoURL: photoURL, videoURL: videoURL)
    }
    
    // MARK: - Helper Methods
    
    /// Determines if a file is a still image based on its extension
    private func isStillImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp"].contains(ext)
    }
    
    /// Determines if a file is a video based on its extension
    private func isVideoFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp4", "mov", "m4v", "3gp", "avi", "mkv", "webm"].contains(ext)
    }
    
    /// Determines if a file is a special motion photo component
    private func isMotionPhotoComponent(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "mp" || ext == "mvimg"
    }
}
