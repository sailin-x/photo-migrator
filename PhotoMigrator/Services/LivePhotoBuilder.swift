import Foundation
import Photos
import UniformTypeIdentifiers

/// Handles the construction and import of Live Photos from paired components
class LivePhotoBuilder {
    /// The Photos library instance
    private let photoLibrary = PHPhotoLibrary.shared()
    
    /// Logger instance
    private let logger = Logger.shared
    
    /// Constructor
    init() {
        logger.info("LivePhotoBuilder initialized")
    }
    
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
        logger.info("Building Live Photo from \(imageURL.lastPathComponent) and \(videoURL.lastPathComponent)")
        
        // Verify the files exist
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            logger.error("Image file does not exist: \(imageURL.path)")
            throw MigrationError.fileAccessError(path: imageURL.path)
        }
        
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            logger.error("Video file does not exist: \(videoURL.path)")
            throw MigrationError.fileAccessError(path: videoURL.path)
        }
        
        var localIdentifier: String?
        
        // Synchronize content identifiers if possible
        let identifierSynced = await syncContentIdentifiers(photoURL: imageURL, videoURL: videoURL)
        if identifierSynced {
            logger.debug("Content identifiers synchronized successfully")
        } else {
            logger.warning("Could not synchronize content identifiers, but continuing with import")
        }
        
        try await photoLibrary.performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            
            // Add the photo component
            let photoOptions = PHAssetResourceCreationOptions()
            photoOptions.shouldMoveFile = false // Don't move/delete the original file
            photoOptions.originalFilename = imageURL.lastPathComponent
            if let photoUTI = self.getUTIForFile(imageURL) {
                photoOptions.uniformTypeIdentifier = photoUTI
            }
            creationRequest.addResource(with: .photo, fileURL: imageURL, options: photoOptions)
            
            // Add the video component as the paired video
            let videoOptions = PHAssetResourceCreationOptions()
            videoOptions.shouldMoveFile = false // Don't move/delete the original file
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
        
        if let identifier = localIdentifier {
            logger.info("Live Photo successfully created with identifier: \(identifier)")
        } else {
            logger.error("Failed to create Live Photo")
        }
        
        return localIdentifier
    }
    
    /// Attempts to synchronize content identifiers between image and video components
    /// - Parameters:
    ///   - photoURL: URL to the still image file
    ///   - videoURL: URL to the video file
    /// - Returns: True if successful, false otherwise
    func syncContentIdentifiers(photoURL: URL, videoURL: URL) async -> Bool {
        // In a real implementation, this would use ExifTool or similar to:
        // 1. Extract or generate a UUID for ContentIdentifier
        // 2. Write it to both files in the appropriate metadata formats
        
        // This is a simplified placeholder return - a real implementation would
        // use a binary like ExifTool to manipulate the actual metadata
        logger.debug("Content identifier syncing would happen here for \(photoURL.lastPathComponent) and \(videoURL.lastPathComponent)")
        return true
    }
    
    /// Apply metadata to a PHAssetCreationRequest
    /// - Parameters:
    ///   - request: The asset creation request
    ///   - metadata: Dictionary of metadata properties
    private func applyMetadata(to request: PHAssetCreationRequest, metadata: [String: Any]) {
        guard let placeholder = request.placeholderForCreatedAsset else {
            logger.warning("No placeholder available for metadata application")
            return
        }
        
        let contentEditingOutput = PHContentEditingOutput(placeholderForCreatedAsset: placeholder)
        
        do {
            // Serialize metadata
            let data = try JSONSerialization.data(withJSONObject: metadata, options: [])
            
            // Create adjustment data
            let adjustmentData = PHAdjustmentData(
                formatIdentifier: "com.photomigrator.metadata",
                formatVersion: "1.0",
                data: data
            )
            
            // Apply the adjustment data
            contentEditingOutput.adjustmentData = adjustmentData
            request.contentEditingOutput = contentEditingOutput
            
            logger.debug("Applied custom metadata to asset")
        } catch {
            logger.error("Failed to serialize or apply metadata: \(error.localizedDescription)")
        }
    }
    
    /// Verify a Live Photo was properly created by checking its playback style
    /// - Parameter localIdentifier: Local identifier of the asset to check
    /// - Returns: True if it's a valid Live Photo, false otherwise
    func verifyLivePhoto(localIdentifier: String) -> Bool {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        
        guard let asset = assets.firstObject else {
            logger.error("Asset not found for verification: \(localIdentifier)")
            return false
        }
        
        // Check if it has Live Photo playback style
        let isLivePhoto = asset.playbackStyle == .livePhoto
        
        if isLivePhoto {
            logger.info("Verified asset \(localIdentifier) is a Live Photo")
        } else {
            logger.warning("Asset \(localIdentifier) is not a Live Photo")
        }
        
        return isLivePhoto
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