import Foundation
import Photos

// MARK: - Batch Processing Methods
extension ArchiveProcessor {
    
    /// Import a batch of media items to Apple Photos
    /// - Returns: Array of import results for the items in this batch
    func importMediaBatch(_ mediaItems: [MediaItem]) async throws -> [ImportResult] {
        writeToLog("Processing batch with \(mediaItems.count) items")
        
        var results: [ImportResult] = []
        var batchIndex = 0
        let batchTotal = mediaItems.count
        
        for item in mediaItems {
            // Check for cancellation
            if isCancelled {
                throw MigrationError.operationCancelled
            }
            
            // Update progress within this batch
            batchIndex += 1
            DispatchQueue.main.async {
                self.progress.processedItems += 1
                self.progress.currentItemName = item.originalFileName
                self.progress.stageProgress = Double(batchIndex) / Double(batchTotal)
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
            
            // Add warnings or errors to recent messages
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
        
        writeToLog("Completed batch with \(results.count) results (\(results.filter { $0.assetId != nil }.count) successful)")
        return results
    }
    
    /// Create albums for a set of import results
    func createAlbums(for importResults: [ImportResult]) async throws -> Int {
        writeToLog("Creating albums for imported media")
        
        // Group items by album paths
        var albumsToCreate: [String: [PHAsset]] = [:]
        
        // Collect assets by album path
        for result in importResults {
            // Skip failed imports
            guard let assetId = result.assetId,
                  let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject else {
                continue
            }
            
            for albumPath in result.originalItem.albumPaths {
                if albumsToCreate[albumPath] == nil {
                    albumsToCreate[albumPath] = []
                }
                albumsToCreate[albumPath]?.append(asset)
            }
        }
        
        // Check if we're cancelled
        if isCancelled {
            throw MigrationError.operationCancelled
        }
        
        writeToLog("Found \(albumsToCreate.count) albums to create")
        var albumsCreated = 0
        
        // Create albums with their assets
        for (albumPath, assets) in albumsToCreate {
            // Skip empty albums
            if assets.isEmpty {
                continue
            }
            
            // Check cancellation
            if isCancelled {
                throw MigrationError.operationCancelled
            }
            
            do {
                try await albumManager.createAlbumIfNeeded(named: albumPath, with: assets)
                albumsCreated += 1
                
                DispatchQueue.main.async {
                    self.progress.albumsCreated += 1
                    self.progress.currentItemName = "Album: \(albumPath)"
                }
                
                writeToLog("Created album: \(albumPath) with \(assets.count) assets")
            } catch {
                writeToLog("Failed to create album \(albumPath): \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.progress.recentMessages.append(.warning("Failed to create album: \(albumPath)"))
                }
            }
        }
        
        return albumsCreated
    }
}