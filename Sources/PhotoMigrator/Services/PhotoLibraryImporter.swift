import Foundation
import Photos
import PhotosUI

/// Service for importing media to the Photos library
class PhotoLibraryImporter {
    /// Shared singleton instance
    static let shared = PhotoLibraryImporter()
    
    /// User preferences reference
    private let preferences = UserPreferences.shared
    
    /// Metadata privacy manager reference
    private let privacyManager = MetadataPrivacyManager.shared
    
    /// Permissions manager reference
    private let permissionsManager = PermissionsManager.shared
    
    /// Logger instance
    private let logger = Logger.shared
    
    /// Private initializer for singleton
    private init() {}
    
    /// Import a media item to the Photos library
    /// - Parameters:
    ///   - mediaItem: The media item to import
    ///   - completion: Completion handler with success flag and error
    func importToPhotosLibrary(mediaItem: MediaItem, completion: @escaping (Bool, Error?) -> Void) {
        // First apply privacy settings to the media item
        let sanitizedMediaItem = sanitizeForPrivacy(mediaItem)
        
        // Get the file URL for the media item
        guard let fileURL = sanitizedMediaItem.fileURL else {
            completion(false, MigrationError.fileNotFound(details: "Media file URL is nil"))
            return
        }
        
        // Check if we have permission to access the Photos library using PermissionsManager
        permissionsManager.requestPhotoLibraryPermission(
            level: .readWrite,
            explanation: "PhotoMigrator needs access to your Photos library to import your Google Photos and preserve their metadata."
        ) { [weak self] status in
            guard let self = self else { return }
            
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    // Show recovery instructions
                    self.permissionsManager.showRecoveryInstructions(
                        for: .photoLibrary,
                        operation: .import
                    )
                    completion(false, MigrationError.permissionDenied(details: "Photos library access denied"))
                }
                return
            }
            
            // Perform the import operation
            PHPhotoLibrary.shared().performChanges {
                // Create asset creation request based on file type
                let creationRequest: PHAssetCreationRequest?
                
                if sanitizedMediaItem.mediaType == .video {
                    creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest?.addResource(with: .video, fileURL: fileURL, options: nil)
                } else {
                    // Default to photo
                    creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest?.addResource(with: .photo, fileURL: fileURL, options: nil)
                }
                
                // Apply metadata to the creation request
                if let request = creationRequest {
                    self.applyMetadata(to: request, from: sanitizedMediaItem)
                }
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.logger.log("Successfully imported \(fileURL.lastPathComponent)")
                    } else {
                        self.logger.log("Failed to import \(fileURL.lastPathComponent): \(error?.localizedDescription ?? "Unknown error")", type: .error)
                    }
                    completion(success, error)
                }
            }
        }
    }
    
    /// Add media to a specific album in the Photos library
    /// - Parameters:
    ///   - mediaItem: The media item to add
    ///   - albumName: The name of the album
    ///   - completion: Completion handler with success flag and error
    func addToAlbum(mediaItem: MediaItem, albumName: String, completion: @escaping (Bool, Error?) -> Void) {
        guard preferences.createAlbums else {
            // Skip if album creation is disabled
            completion(false, nil)
            return
        }
        
        // First ensure the media is imported
        importToPhotosLibrary(mediaItem: mediaItem) { [weak self] success, error in
            guard let self = self else { return }
            
            if !success {
                completion(false, error)
                return
            }
            
            // Get the file URL for the media item to identify the asset later
            guard let fileURL = mediaItem.fileURL else {
                completion(false, MigrationError.fileNotFound(details: "Media file URL is nil"))
                return
            }
            
            // Find or create the album
            self.findOrCreateAlbum(named: albumName) { album, error in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                guard let album = album else {
                    completion(false, MigrationError.albumCreationFailed(details: "Failed to create album \(albumName)"))
                    return
                }
                
                // Find the recently imported asset
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                fetchOptions.fetchLimit = 1
                
                // We'll find the most recently added asset that matches our media type
                // This is not 100% reliable but works in most cases when importing one at a time
                let assetFetchResult = mediaItem.mediaType == .video ?
                    PHAsset.fetchAssets(with: .video, options: fetchOptions) :
                    PHAsset.fetchAssets(with: .image, options: fetchOptions)
                
                guard let asset = assetFetchResult.firstObject else {
                    completion(false, MigrationError.assetNotFound(details: "Recently imported asset not found"))
                    return
                }
                
                // Add the asset to the album
                PHPhotoLibrary.shared().performChanges {
                    let addAssetRequest = PHAssetCollectionChangeRequest(for: album)
                    addAssetRequest?.addAssets([asset] as NSFastEnumeration)
                } completionHandler: { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.logger.log("Added \(fileURL.lastPathComponent) to album \(albumName)")
                        } else {
                            self.logger.log("Failed to add to album \(albumName): \(error?.localizedDescription ?? "Unknown error")", type: .error)
                        }
                        completion(success, error)
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Apply metadata to a PHAssetCreationRequest
    /// - Parameters:
    ///   - request: The creation request
    ///   - mediaItem: The media item containing metadata
    private func applyMetadata(to request: PHAssetCreationRequest, from mediaItem: MediaItem) {
        // Set creation date if available and preference is enabled
        if preferences.preserveCreationDates, let creationDate = mediaItem.metadata.dateTaken {
            request.creationDate = creationDate
        }
        
        // Set location if available and preference is enabled
        if preferences.preserveLocationData, let location = mediaItem.metadata.location {
            request.location = location
        }
        
        // We can't easily set other metadata like descriptions, they are handled by Photos app itself
    }
    
    /// Find or create an album with the given name
    /// - Parameters:
    ///   - albumName: The name of the album
    ///   - completion: Completion handler with the album and any error
    private func findOrCreateAlbum(named albumName: String, completion: @escaping (PHAssetCollection?, Error?) -> Void) {
        // Look for existing album
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let album = collections.firstObject {
            // Album exists, use it
            completion(album, nil)
            return
        }
        
        // Album doesn't exist, create it
        var albumPlaceholder: PHObjectPlaceholder?
        
        PHPhotoLibrary.shared().performChanges {
            let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            albumPlaceholder = createRequest.placeholderForCreatedAssetCollection
        } completionHandler: { [weak self] success, error in
            guard let self = self else { return }
            
            if success, let placeholder = albumPlaceholder {
                // Fetch the newly created album
                let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                if let album = collection.firstObject {
                    self.logger.log("Created album: \(albumName)")
                    completion(album, nil)
                } else {
                    completion(nil, MigrationError.albumCreationFailed(details: "Album was created but couldn't be fetched"))
                }
            } else {
                self.logger.log("Failed to create album \(albumName): \(error?.localizedDescription ?? "Unknown error")", type: .error)
                completion(nil, error)
            }
        }
    }
    
    /// Sanitize a media item according to privacy settings
    /// - Parameter mediaItem: The original media item
    /// - Returns: A sanitized copy of the media item
    private func sanitizeForPrivacy(_ mediaItem: MediaItem) -> MediaItem {
        // Create a copy of the media item
        var sanitizedItem = mediaItem
        
        // Apply privacy settings to metadata
        sanitizedItem.metadata = privacyManager.sanitizeMetadata(mediaItem.metadata)
        
        return sanitizedItem
    }
} 