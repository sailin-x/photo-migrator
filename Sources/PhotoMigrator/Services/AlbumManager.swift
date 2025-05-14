import Foundation
import Photos

class AlbumManager {
    private let photoLibrary = PHPhotoLibrary.shared()
    
    func createAlbumIfNeeded(named albumPath: String, with assets: [PHAsset]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            // Check if album already exists
            let albumFetchOptions = PHFetchOptions()
            albumFetchOptions.predicate = NSPredicate(format: "title = %@", albumPath)
            let albumFetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: albumFetchOptions)
            
            // If album exists, add the assets to it
            if let album = albumFetchResult.firstObject {
                photoLibrary.performChanges {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                    albumChangeRequest?.addAssets(PHAsset.fetchAssets(withLocalIdentifiers: assets.map { $0.localIdentifier }, options: nil) as NSFastEnumeration)
                } completionHandler: { success, error in
                    if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: error ?? MigrationError.importFailed(reason: "Failed to add assets to album"))
                    }
                }
            } else {
                // Create a new album and add the assets
                photoLibrary.performChanges {
                    let albumChangeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumPath)
                    albumChangeRequest.addAssets(PHAsset.fetchAssets(withLocalIdentifiers: assets.map { $0.localIdentifier }, options: nil) as NSFastEnumeration)
                } completionHandler: { success, error in
                    if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: error ?? MigrationError.importFailed(reason: "Failed to create album"))
                    }
                }
            }
        }
    }
    
    func getAllAlbums() async throws -> [PHAssetCollection] {
        return try await withCheckedThrowingContinuation { continuation in
            let albumFetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
            var albums: [PHAssetCollection] = []
            
            albumFetchResult.enumerateObjects { album, _, _ in
                albums.append(album)
            }
            
            continuation.resume(returning: albums)
        }
    }
}
