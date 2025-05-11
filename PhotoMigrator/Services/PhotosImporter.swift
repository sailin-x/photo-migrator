import Foundation
import Photos
import CoreLocation

class PhotosImporter {
    private let photoLibrary = PHPhotoLibrary.shared()
    
    func importSingleMedia(_ item: MediaItem) async throws -> ImportResult {
        return try await withCheckedThrowingContinuation { continuation in
            guard FileManager.default.fileExists(atPath: item.fileURL.path) else {
                continuation.resume(returning: ImportResult(
                    originalItem: item,
                    assetId: nil,
                    error: MigrationError.fileAccessError(path: item.fileURL.path)
                ))
                return
            }
            
            // Prepare creation request based on media type
            var creationRequest: PHAssetCreationRequest?
            
            photoLibrary.performChanges {
                creationRequest = PHAssetCreationRequest.forAsset()
                
                // Add the media file
                if item.fileType == .image || item.fileType == .unknown {
                    creationRequest?.addResource(with: .photo, fileURL: item.fileURL, options: nil)
                } else if item.fileType == .video {
                    creationRequest?.addResource(with: .video, fileURL: item.fileURL, options: nil)
                }
                
                // Set metadata
                self.applyMetadata(to: creationRequest, from: item)
                
            } completionHandler: { success, error in
                if success, let assetId = creationRequest?.placeholderForCreatedAsset?.localIdentifier {
                    continuation.resume(returning: ImportResult(
                        originalItem: item,
                        assetId: assetId,
                        error: nil
                    ))
                } else {
                    continuation.resume(returning: ImportResult(
                        originalItem: item,
                        assetId: nil,
                        error: error ?? MigrationError.importFailed(reason: "Unknown error")
                    ))
                }
            }
        }
    }
    
    func importLivePhoto(_ item: MediaItem, motionURL: URL) async throws -> ImportResult {
        return try await withCheckedThrowingContinuation { continuation in
            guard FileManager.default.fileExists(atPath: item.fileURL.path) else {
                continuation.resume(returning: ImportResult(
                    originalItem: item,
                    assetId: nil,
                    error: MigrationError.fileAccessError(path: item.fileURL.path)
                ))
                return
            }
            
            guard FileManager.default.fileExists(atPath: motionURL.path) else {
                continuation.resume(returning: ImportResult(
                    originalItem: item,
                    assetId: nil,
                    error: MigrationError.fileAccessError(path: motionURL.path)
                ))
                return
            }
            
            var creationRequest: PHAssetCreationRequest?
            
            photoLibrary.performChanges {
                creationRequest = PHAssetCreationRequest.forAsset()
                
                // For Live Photo, add the photo as the main resource
                creationRequest?.addResource(with: .photo, fileURL: item.fileURL, options: nil)
                
                // Add the video as the paired resource
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false
                creationRequest?.addResource(with: .pairedVideo, fileURL: motionURL, options: options)
                
                // Set metadata
                self.applyMetadata(to: creationRequest, from: item)
                
            } completionHandler: { success, error in
                if success, let assetId = creationRequest?.placeholderForCreatedAsset?.localIdentifier {
                    continuation.resume(returning: ImportResult(
                        originalItem: item,
                        assetId: assetId,
                        error: nil
                    ))
                } else {
                    continuation.resume(returning: ImportResult(
                        originalItem: item,
                        assetId: nil,
                        error: error ?? MigrationError.importFailed(reason: "Live Photo import failed")
                    ))
                }
            }
        }
    }
    
    private func applyMetadata(to request: PHAssetCreationRequest?, from item: MediaItem) {
        let metadata = item.metadata
        
        // Set creation date
        if let dateTaken = metadata.dateTaken {
            request?.creationDate = dateTaken
        }
        
        // Set location
        if let location = metadata.location {
            request?.location = location
        }
        
        // Set favorite status
        if metadata.isFavorite {
            let changeRequest = PHAssetChangeRequest(for: request!.placeholderForCreatedAsset!)
            changeRequest.isFavorite = true
        }
        
        // Build keywords from people tags and any existing keywords
        var allKeywords = metadata.keywords
        allKeywords.append(contentsOf: metadata.people)
        
        if !allKeywords.isEmpty {
            request?.contentEditingOutput = PHContentEditingOutput(placeholderForCreatedAsset: request!.placeholderForCreatedAsset!)
            
            // Add keywords as they can be saved immediately during import
            if let adjustmentData = PHAdjustmentData(formatIdentifier: "com.apple.Photos", formatVersion: "1.0", data: Data()) {
                request?.contentEditingOutput?.adjustmentData = adjustmentData
            }
        }
    }
}
