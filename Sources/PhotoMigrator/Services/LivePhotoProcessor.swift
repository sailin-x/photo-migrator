import Foundation
import AVFoundation
import Photos
import UniformTypeIdentifiers

/// A service to identify and reconstruct Live Photos from various formats
class LivePhotoProcessor {
    private let fileManager = FileManager.default
    private let logger = Logger.shared
    private let builder = LivePhotoBuilder()
    
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
        
        for (baseName, components) in livePhotoComponents {
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
        for (baseName, files) in potentialPairs {
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
            do {
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
                    switch exportSession.status {
                    case .completed:
                        continuation.resume(returning: outputURL)
                    case .failed:
                        continuation.resume(throwing: exportSession.error ?? MigrationError.importFailed(reason: "Unknown export error"))
                    case .cancelled:
                        continuation.resume(throwing: MigrationError.operationCancelled)
                    default:
                        continuation.resume(throwing: MigrationError.importFailed(reason: "Unexpected export status"))
                    }
                }
            } catch {
                continuation.resume(throwing: error)
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
    
    /// Gets the base name of a file path without extension
    func extractBaseNameFromPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.deletingPathExtension().lastPathComponent
    }
}

/// A dedicated builder class for Live Photos
class LivePhotoBuilder {
    private let photoLibrary = PHPhotoLibrary.shared()
    private let logger = Logger.shared
    
    /// Construct a Live Photo from its components and import it to Photos library
    /// - Parameters:
    ///   - imageURL: URL to the still image component
    ///   - videoURL: URL to the video/motion component
    ///   - metadata: Optional metadata to apply to the Live Photo
    /// - Returns: Local identifier of the created asset, or nil if failed
    func buildAndImportLivePhoto(
        imageURL: URL,
        videoURL: URL,
        metadata: [String: Any]? = nil
    ) async throws -> String? {
        var localIdentifier: String?
        
        try await photoLibrary.performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            
            // Add the photo component
            let photoOptions = PHAssetResourceCreationOptions()
            photoOptions.shouldMoveFile = false
            photoOptions.originalFilename = imageURL.lastPathComponent
            if let photoUTI = self.getUTIForFile(imageURL) {
                photoOptions.uniformTypeIdentifier = photoUTI
            }
            creationRequest.addResource(with: .photo, fileURL: imageURL, options: photoOptions)
            
            // Add the video component as the paired video
            let videoOptions = PHAssetResourceCreationOptions()
            videoOptions.shouldMoveFile = false
            videoOptions.originalFilename = videoURL.lastPathComponent
            if let videoUTI = self.getUTIForFile(videoURL) {
                videoOptions.uniformTypeIdentifier = videoUTI
            }
            creationRequest.addResource(with: .pairedVideo, fileURL: videoURL, options: videoOptions)
            
            // Apply metadata if available
            if let metadata = metadata {
                self.applyMetadata(to: creationRequest, metadata: metadata)
            }
            
            // Get placeholder for created asset
            localIdentifier = creationRequest.placeholderForCreatedAsset?.localIdentifier
        }
        
        return localIdentifier
    }
    
    /// Apply metadata to a PHAssetCreationRequest
    /// - Parameters:
    ///   - request: The asset creation request
    ///   - metadata: Dictionary of metadata properties
    private func applyMetadata(to request: PHAssetCreationRequest, metadata: [String: Any]) {
        guard let placeholder = request.placeholderForCreatedAsset else {
            return
        }
        
        let contentEditingOutput = PHContentEditingOutput(placeholderForCreatedAsset: placeholder)
        
        // Serialize metadata
        if !metadata.isEmpty {
            guard let data = try? JSONSerialization.data(withJSONObject: metadata, options: []) else {
                return
            }
            
            let adjustmentData = PHAdjustmentData(
                formatIdentifier: "com.photomigrator.metadata",
                formatVersion: "1.0",
                data: data
            )
            contentEditingOutput.adjustmentData = adjustmentData
            request.contentEditingOutput = contentEditingOutput
        }
    }
    
    /// Get UTI for a file based on its extension
    /// - Parameter url: URL of the file
    /// - Returns: UTI string or nil if not available
    private func getUTIForFile(_ url: URL) -> String? {
        let pathExtension = url.pathExtension.lowercased()
        
        // Common image types
        switch pathExtension {
        case "jpg", "jpeg":
            return "public.jpeg"
        case "png":
            return "public.png"
        case "heic", "heif":
            return "public.heic"
        case "tiff", "tif":
            return "public.tiff"
        case "gif":
            return "com.compuserve.gif"
        case "webp":
            return "org.webmproject.webp"
            
        // Common video types
        case "mov":
            return "com.apple.quicktime-movie"
        case "mp4", "m4v":
            return "public.mpeg-4"
        case "avi":
            return "public.avi"
        case "webm":
            return "org.webmproject.webm"
            
        // Generic types if specific one not found
        default:
            return UTTypeCreatePreferredIdentifierForTag(
                kUTTagClassFilenameExtension,
                pathExtension as CFString,
                nil
            )?.takeRetainedValue() as String?
        }
    }
}
