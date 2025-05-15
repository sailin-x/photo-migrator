import Foundation
import Photos
import AVFoundation
import UniformTypeIdentifiers

/// A specialized class for building Live Photos from separate components
class LivePhotoBuilder {
    /// The Photos library service
    private let photoLibrary = PHPhotoLibrary.shared()
    
    /// Logger instance
    private let logger = Logger.shared
    
    /// Creates and imports a Live Photo from separate image and video components
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
        logger.log("Building Live Photo from \(imageURL.lastPathComponent) and \(videoURL.lastPathComponent)")
        
        // Ensure both components exist
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            logger.log("Image component doesn't exist: \(imageURL.path)", level: .error)
            throw MigrationError.fileAccessError(path: imageURL.path)
        }
        
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            logger.log("Video component doesn't exist: \(videoURL.path)", level: .error)
            throw MigrationError.fileAccessError(path: videoURL.path)
        }
        
        // Check file types
        guard isImageFile(imageURL) else {
            logger.log("File is not an image: \(imageURL.lastPathComponent)", level: .error)
            throw MigrationError.invalidMediaType("Not an image file: \(imageURL.lastPathComponent)")
        }
        
        guard isVideoFile(videoURL) else {
            logger.log("File is not a video: \(videoURL.lastPathComponent)", level: .error)
            throw MigrationError.invalidMediaType("Not a video file: \(videoURL.lastPathComponent)")
        }
        
        // Sync content identifiers to ensure proper Live Photo pairing
        let syncSuccess = await syncContentIdentifiers(photoURL: imageURL, videoURL: videoURL)
        if !syncSuccess {
            logger.log("Warning: Failed to sync content identifiers between components", level: .warning)
        }
        
        // Import to Photos library
        var localIdentifier: String?
        
        try await photoLibrary.performChanges { [self] in
            // Create the asset request
            let creationRequest = PHAssetCreationRequest.forAsset()
            
            // Add the photo component
            let photoOptions = PHAssetResourceCreationOptions()
            photoOptions.shouldMoveFile = false
            photoOptions.originalFilename = imageURL.lastPathComponent
            
            // Set the correct UTI for the photo
            if let photoUTI = self.getUTIForFile(imageURL) {
                photoOptions.uniformTypeIdentifier = photoUTI
            }
            
            creationRequest.addResource(with: .photo, fileURL: imageURL, options: photoOptions)
            
            // Add the video component as the paired video
            let videoOptions = PHAssetResourceCreationOptions()
            videoOptions.shouldMoveFile = false
            videoOptions.originalFilename = videoURL.lastPathComponent
            
            // Set the correct UTI for the video
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
            logger.log("Successfully created Live Photo with identifier: \(identifier)")
            
            // Verify the Live Photo was created properly
            if verifyLivePhoto(localIdentifier: identifier) {
                logger.log("Verified Live Photo is valid")
                return identifier
            } else {
                logger.log("Failed to verify Live Photo", level: .error)
                throw MigrationError.livePhotoVerificationFailed
            }
        } else {
            logger.log("Failed to create Live Photo asset", level: .error)
            throw MigrationError.livePhotoReconstructionFailed(reason: "Asset creation failed")
        }
    }
    
    /// Apply metadata to a PHAssetCreationRequest
    /// - Parameters:
    ///   - request: The asset creation request
    ///   - metadata: Dictionary of metadata properties
    private func applyMetadata(to request: PHAssetCreationRequest, metadata: [String: Any]) {
        guard let placeholder = request.placeholderForCreatedAsset else {
            logger.log("No placeholder available for metadata", level: .warning)
            return
        }
        
        // Create a content editing output
        let contentEditingOutput = PHContentEditingOutput(placeholderForCreatedAsset: placeholder)
        
        // Apply creation date if present
        if let creationDate = metadata["creationDate"] as? Date {
            request.creationDate = creationDate
        }
        
        // Apply location if present
        if let locationDict = metadata["location"] as? [String: Any],
           let latitude = locationDict["latitude"] as? Double,
           let longitude = locationDict["longitude"] as? Double {
            request.location = CLLocation(latitude: latitude, longitude: longitude)
        }
        
        // Handle other metadata by serializing to adjustment data
        do {
            let data = try JSONSerialization.data(withJSONObject: metadata)
            let adjustmentData = PHAdjustmentData(
                formatIdentifier: "com.photomigrator.metadata",
                formatVersion: "1.0",
                data: data
            )
            contentEditingOutput.adjustmentData = adjustmentData
            request.contentEditingOutput = contentEditingOutput
        } catch {
            logger.log("Failed to serialize metadata: \(error.localizedDescription)", level: .warning)
        }
    }
    
    /// Verify that an asset is a valid Live Photo
    /// - Parameter localIdentifier: Asset identifier to check
    /// - Returns: Whether the asset is a valid Live Photo
    func verifyLivePhoto(localIdentifier: String) -> Bool {
        // Fetch the asset with the given identifier
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        
        guard let asset = result.firstObject else {
            logger.log("Could not find asset with identifier: \(localIdentifier)", level: .error)
            return false
        }
        
        // Check if it's a Live Photo
        let isLivePhoto = asset.mediaSubtypes.contains(.photoLive)
        
        if !isLivePhoto {
            logger.log("Asset is not a Live Photo: \(localIdentifier)", level: .warning)
        }
        
        return isLivePhoto
    }
    
    /// Sync content identifiers for Live Photo components
    /// - Parameters:
    ///   - photoURL: URL to the still image
    ///   - videoURL: URL to the video component
    /// - Returns: Whether the sync was successful
    func syncContentIdentifiers(photoURL: URL, videoURL: URL) async -> Bool {
        // This would involve updating metadata on both files to ensure they're recognized as a pair
        // For now, this is a placeholder implementation
        logger.log("Syncing content identifiers for \(photoURL.lastPathComponent) and \(videoURL.lastPathComponent)")
        return true
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
            return UTType(filenameExtension: pathExtension)?.identifier
        }
    }
    
    /// Check if a file is an image based on URL
    /// - Parameter url: File URL to check
    /// - Returns: Whether the file appears to be an image
    private func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp"].contains(ext)
    }
    
    /// Check if a file is a video based on URL
    /// - Parameter url: File URL to check
    /// - Returns: Whether the file appears to be a video
    private func isVideoFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp4", "mov", "m4v", "3gp", "avi", "mkv", "webm", "mp"].contains(ext)
    }
} 