import Foundation
import Photos
import CoreLocation
import CoreServices

/// Represents the progress of a media import operation
struct ImportProgress {
    var progress: Double // 0.0 to 1.0
    var assetId: String?
    var stage: ImportStage
    
    enum ImportStage {
        case starting
        case importing
        case verifying
        case applyingMetadata
        case complete
        case failed
    }
}

/// Protocol for receiving import progress updates
protocol PhotosImportDelegate: AnyObject {
    func importProgress(updated: ImportProgress, for item: MediaItem)
    func importCompleted(result: ImportResult)
}

class PhotosImporter {
    private let photoLibrary = PHPhotoLibrary.shared()
    weak var delegate: PhotosImportDelegate?
    
    // For internal cancellation tracking
    private var isCancelled = false
    
    /// Request permission to access the user's photo library
    /// - Returns: A boolean indicating whether access was granted, and an optional error
    func requestPhotoLibraryPermission() async -> (granted: Bool, error: Error?) {
        // First check the current authorization status
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        // Return immediately if already authorized
        if status == .authorized {
            return (true, nil)
        }
        
        // Return immediately if already denied or restricted - can't prompt again programmatically
        if status == .denied || status == .restricted {
            return (false, MigrationError.photosAccessDenied)
        }
        
        // For not determined or limited, request authorization
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                switch newStatus {
                case .authorized:
                    continuation.resume(returning: (true, nil))
                case .limited:
                    // Limited access is still usable, but we should indicate this to the user
                    continuation.resume(returning: (true, nil))
                case .denied, .restricted:
                    continuation.resume(returning: (false, MigrationError.photosAccessDenied))
                case .notDetermined:
                    // This shouldn't happen after requesting authorization
                    continuation.resume(returning: (false, MigrationError.unknown))
                @unknown default:
                    continuation.resume(returning: (false, MigrationError.unknown))
                }
            }
        }
    }
    
    /// Cancel any in-progress import operations
    func cancelImport() {
        isCancelled = true
    }
    
    /// Reset cancellation flag
    func resetCancellation() {
        isCancelled = false
    }
    
    /// Import a single media item into Photos library
    /// - Parameter item: The media item to import
    /// - Returns: Result of the import operation
    func importSingleMedia(_ item: MediaItem) async throws -> ImportResult {
        // First check permissions
        let (granted, error) = await requestPhotoLibraryPermission()
        guard granted else {
            return ImportResult(
                originalItem: item,
                assetId: nil,
                error: error ?? MigrationError.photosAccessDenied
            )
        }
        
        if isCancelled {
            return ImportResult(
                originalItem: item,
                assetId: nil,
                error: MigrationError.operationCancelled
            )
        }
        
        // Report initial progress
        delegate?.importProgress(updated: ImportProgress(
            progress: 0.0, 
            assetId: nil, 
            stage: .starting
        ), for: item)
        
        return try await withCheckedThrowingContinuation { continuation in
            guard FileManager.default.fileExists(atPath: item.fileURL.path) else {
                let error = MigrationError.fileAccessError(path: item.fileURL.path)
                delegate?.importProgress(updated: ImportProgress(
                    progress: 0.0, 
                    assetId: nil, 
                    stage: .failed
                ), for: item)
                continuation.resume(returning: ImportResult(
                    originalItem: item,
                    assetId: nil,
                    error: error
                ))
                return
            }
            
            // Prepare creation request based on media type
            var creationRequest: PHAssetCreationRequest?
            
            // Update progress
            delegate?.importProgress(updated: ImportProgress(
                progress: 0.2, 
                assetId: nil, 
                stage: .importing
            ), for: item)
            
            photoLibrary.performChanges {
                creationRequest = PHAssetCreationRequest.forAsset()
                
                // Set up appropriate options
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false
                options.originalFilename = item.fileURL.lastPathComponent
                
                // Add resource based on media type with progress tracking
                switch item.fileType {
                case .photo, .unknown:
                    if let uniformTypeIdentifier = self.getUTIForFile(item.fileURL) {
                        options.uniformTypeIdentifier = uniformTypeIdentifier
                    }
                    creationRequest?.addResource(with: .photo, fileURL: item.fileURL, options: options)
                    
                case .video:
                    if let uniformTypeIdentifier = self.getUTIForFile(item.fileURL) {
                        options.uniformTypeIdentifier = uniformTypeIdentifier
                    }
                    // For videos, indicate we need to keep resources alive during import
                    options.shouldMoveFile = false
                    creationRequest?.addResource(with: .video, fileURL: item.fileURL, options: options)
                    
                case .livePhoto, .motionPhoto:
                    // Live/Motion photos should be handled by importLivePhoto, but fallback to regular photo import
                    if let uniformTypeIdentifier = self.getUTIForFile(item.fileURL) {
                        options.uniformTypeIdentifier = uniformTypeIdentifier
                    }
                    creationRequest?.addResource(with: .photo, fileURL: item.fileURL, options: options)
                }
                
                // Update progress for resource addition
                if !self.isCancelled, let placeholder = creationRequest?.placeholderForCreatedAsset {
                    DispatchQueue.main.async {
                        self.delegate?.importProgress(updated: ImportProgress(
                            progress: 0.5, 
                            assetId: placeholder.localIdentifier, 
                            stage: .applyingMetadata
                        ), for: item)
                    }
                }
                
                // Set metadata
                self.applyMetadata(to: creationRequest, from: item)
                
            } completionHandler: { success, error in
                if self.isCancelled {
                    // Handle cancellation
                    self.delegate?.importProgress(updated: ImportProgress(
                        progress: 0.0, 
                        assetId: nil, 
                        stage: .failed
                    ), for: item)
                    continuation.resume(returning: ImportResult(
                        originalItem: item,
                        assetId: nil,
                        error: MigrationError.operationCancelled
                    ))
                    return
                }
                
                if success, let assetId = creationRequest?.placeholderForCreatedAsset?.localIdentifier {
                    // Verify the asset was properly imported
                    self.delegate?.importProgress(updated: ImportProgress(
                        progress: 0.8, 
                        assetId: assetId, 
                        stage: .verifying
                    ), for: item)
                    
                    self.verifyImportedAsset(localIdentifier: assetId) { verified, verifyError in
                        if verified {
                            // Successfully verified
                            self.delegate?.importProgress(updated: ImportProgress(
                                progress: 1.0, 
                                assetId: assetId, 
                                stage: .complete
                            ), for: item)
                            
                            let result = ImportResult(
                                originalItem: item,
                                assetId: assetId,
                                error: nil
                            )
                            self.delegate?.importCompleted(result: result)
                            continuation.resume(returning: result)
                        } else {
                            // Verification failed
                            self.delegate?.importProgress(updated: ImportProgress(
                                progress: 0.0, 
                                assetId: assetId, 
                                stage: .failed
                            ), for: item)
                            
                            let result = ImportResult(
                                originalItem: item,
                                assetId: assetId,
                                error: verifyError ?? MigrationError.importFailed(reason: "Verification failed")
                            )
                            self.delegate?.importCompleted(result: result)
                            continuation.resume(returning: result)
                        }
                    }
                } else {
                    // Import failed
                    self.delegate?.importProgress(updated: ImportProgress(
                        progress: 0.0, 
                        assetId: nil, 
                        stage: .failed
                    ), for: item)
                    
                    // Map PHPhotosError to more specific error messages if possible
                    var specificError = error
                    if let photosError = error as? PHPhotosError {
                        specificError = self.mapPHPhotosError(photosError)
                    }
                    
                    let result = ImportResult(
                        originalItem: item,
                        assetId: nil,
                        error: specificError ?? MigrationError.importFailed(reason: "Unknown error")
                    )
                    self.delegate?.importCompleted(result: result)
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    /// Import a Live Photo by combining a still image with a motion video
    /// - Parameters:
    ///   - item: The main photo item
    ///   - motionURL: URL to the motion/video component
    /// - Returns: Result of the import operation
    func importLivePhoto(_ item: MediaItem, motionURL: URL) async throws -> ImportResult {
        // First check permissions
        let (granted, error) = await requestPhotoLibraryPermission()
        guard granted else {
            return ImportResult(
                originalItem: item,
                assetId: nil,
                error: error ?? MigrationError.photosAccessDenied
            )
        }
        
        if isCancelled {
            return ImportResult(
                originalItem: item,
                assetId: nil,
                error: MigrationError.operationCancelled
            )
        }
        
        // Report initial progress
        delegate?.importProgress(updated: ImportProgress(
            progress: 0.0, 
            assetId: nil, 
            stage: .starting
        ), for: item)
        
        // Verify files exist
        guard FileManager.default.fileExists(atPath: item.fileURL.path) else {
            delegate?.importProgress(updated: ImportProgress(
                progress: 0.0, 
                assetId: nil, 
                stage: .failed
            ), for: item)
            return ImportResult(
                originalItem: item,
                assetId: nil,
                error: MigrationError.fileAccessError(path: item.fileURL.path)
            )
        }
        
        guard FileManager.default.fileExists(atPath: motionURL.path) else {
            delegate?.importProgress(updated: ImportProgress(
                progress: 0.0, 
                assetId: nil, 
                stage: .failed
            ), for: item)
            return ImportResult(
                originalItem: item,
                assetId: nil,
                error: MigrationError.fileAccessError(path: motionURL.path)
            )
        }
        
        // Update progress
        delegate?.importProgress(updated: ImportProgress(
            progress: 0.2, 
            assetId: nil, 
            stage: .importing
        ), for: item)
        
        // Prepare metadata for the Live Photo
        var metadata: [String: Any] = [:]
        
        // Add location if available
        if let latitude = item.latitude, let longitude = item.longitude {
            metadata["latitude"] = latitude
            metadata["longitude"] = longitude
        }
        
        // Add title and description if available
        if let title = item.title {
            metadata["title"] = title
        }
        
        if let description = item.description {
            metadata["description"] = description
        }
        
        // Add album information
        if !item.albumNames.isEmpty {
            metadata["albums"] = item.albumNames
        }
        
        // Add favorite flag if true
        if item.isFavorite {
            metadata["favorite"] = true
        }
        
        // Use LivePhotoProcessor to build and import the Live Photo
        let livePhotoProcessor = LivePhotoProcessor()
        
        do {
            // Build and import the Live Photo
            let assetId = try await livePhotoProcessor.importLivePhoto(
                imageURL: item.fileURL,
                videoURL: motionURL,
                metadata: metadata
            )
            
            if let assetId = assetId {
                // Successfully created Live Photo
                delegate?.importProgress(updated: ImportProgress(
                    progress: 0.8, 
                    assetId: assetId, 
                    stage: .verifying
                ), for: item)
                
                // Verify the Live Photo was properly created
                let isValid = livePhotoProcessor.verifyLivePhoto(localIdentifier: assetId)
                
                if isValid {
                    // Successfully verified
                    delegate?.importProgress(updated: ImportProgress(
                        progress: 1.0, 
                        assetId: assetId, 
                        stage: .complete
                    ), for: item)
                    
                    let result = ImportResult(
                        originalItem: item,
                        assetId: assetId,
                        error: nil
                    )
                    delegate?.importCompleted(result: result)
                    return result
                } else {
                    // Verification failed - it was imported but not as a valid Live Photo
                    delegate?.importProgress(updated: ImportProgress(
                        progress: 0.0, 
                        assetId: assetId, 
                        stage: .failed
                    ), for: item)
                    
                    return ImportResult(
                        originalItem: item,
                        assetId: assetId, 
                        error: MigrationError.importFailed(reason: "Live Photo verification failed")
                    )
                }
            } else {
                // Import failed
                delegate?.importProgress(updated: ImportProgress(
                    progress: 0.0, 
                    assetId: nil, 
                    stage: .failed
                ), for: item)
                
                return ImportResult(
                    originalItem: item,
                    assetId: nil,
                    error: MigrationError.importFailed(reason: "Failed to create Live Photo")
                )
            }
        } catch {
            // Handle errors during import
            delegate?.importProgress(updated: ImportProgress(
                progress: 0.0, 
                assetId: nil, 
                stage: .failed
            ), for: item)
            
            return ImportResult(
                originalItem: item,
                assetId: nil,
                error: error
            )
        }
    }
    
    /// Apply metadata to the asset creation request
    /// - Parameters:
    ///   - request: The PHAssetCreationRequest instance
    ///   - item: The MediaItem containing metadata
    private func applyMetadata(to request: PHAssetCreationRequest?, from item: MediaItem) {
        // Set creation date
        request?.creationDate = item.timestamp
        
        // Set location if available
        if let latitude = item.latitude, let longitude = item.longitude {
            request?.location = CLLocation(
                latitude: latitude,
                longitude: longitude
            )
        }
        
        // Handle favorite status
        if item.isFavorite, let placeholder = request?.placeholderForCreatedAsset {
            // Handle favorites in a different way since PHAssetChangeRequest cannot be used with a placeholder
            Task {
                try? await PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetChangeRequest(for: PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil).firstObject!)
                    request.isFavorite = true
                }
            }
        }
        
        // Apply title and description in the content editing output
        if !item.albumNames.isEmpty || item.title != nil || item.description != nil {
            // Create content editing output
            if let placeholder = request?.placeholderForCreatedAsset {
                let contentEditingOutput = PHContentEditingOutput(placeholderForCreatedAsset: placeholder)
                
                // Build metadata dictionary
                var metadata: [String: Any] = [:]
                
                // Add title and description if available
                if let title = item.title {
                    metadata["title"] = title
                }
                
                if let description = item.description {
                    metadata["description"] = description
                }
                
                // Add album information as keywords
                if !item.albumNames.isEmpty {
                    metadata["albums"] = item.albumNames
                }
                
                // Serialize metadata
                if !metadata.isEmpty {
                    let data = try? JSONSerialization.data(withJSONObject: metadata, options: [])
                    if let data = data {
                        let adjustmentData = PHAdjustmentData(
                            formatIdentifier: "com.photomigrator.metadata",
                            formatVersion: "1.0",
                            data: data
                        )
                        contentEditingOutput.adjustmentData = adjustmentData
                        request?.contentEditingOutput = contentEditingOutput
                    }
                }
            }
        }
    }
    
    /// Get the UTI (Uniform Type Identifier) for a file
    /// - Parameter url: The file URL
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
    
    /// Verify that an asset was successfully imported by checking the Photos library
    /// - Parameters:
    ///   - localIdentifier: The local identifier of the asset
    ///   - completion: Completion handler with verification result and error
    private func verifyImportedAsset(localIdentifier: String, completion: @escaping (Bool, Error?) -> Void) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        
        if assets.count == 1 {
            // Asset exists
            completion(true, nil)
        } else {
            // Asset doesn't exist
            completion(false, MigrationError.importFailed(reason: "Asset not found after import"))
        }
    }
    
    /// Map PHPhotosError to a more specific MigrationError
    /// - Parameter error: The PHPhotosError
    /// - Returns: A MigrationError with specific details
    private func mapPHPhotosError(_ error: PHPhotosError) -> MigrationError {
        switch error.code {
        case .accessUserDenied, .accessRestricted:
            return MigrationError.photosAccessDenied
        case .invalidResource:
            return MigrationError.importFailed(reason: "Invalid resource format")
        case .libraryVolumeOffline:
            return MigrationError.importFailed(reason: "Photos library volume is offline")
        case .userCancelled:
            return MigrationError.operationCancelled
        case .libraryInFileProviderSyncMode:
            return MigrationError.importFailed(reason: "Photos library is in sync mode")
        case .notEnoughSpace:
            return MigrationError.importFailed(reason: "Not enough storage space")
        case .networkAccessRequired:
            return MigrationError.importFailed(reason: "Network access required but not available")
        default:
            return MigrationError.importFailed(reason: "Photos error: \(error.localizedDescription)")
        }
    }
}
