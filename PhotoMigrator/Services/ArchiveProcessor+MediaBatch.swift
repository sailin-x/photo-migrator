import Foundation
import Photos

// MARK: - Batch Processing Methods
extension ArchiveProcessor {
    
    /// Import a batch of media items to Apple Photos
    /// - Returns: Array of import results for the items in this batch
    func importMediaBatch(_ mediaItems: [MediaItem]) async throws -> [ImportResult] {
        logger.info("Processing batch with \(mediaItems.count) items")
        writeToLog("Processing batch with \(mediaItems.count) items")
        
        // First process and pair any Live Photo components
        let processedMediaItems: [MediaItem]
        do {
            processedMediaItems = try await livePhotoProcessor.processLivePhotoComponents(mediaItems: mediaItems)
            
            // Log Live Photo detection stats
            let livePhotoCount = processedMediaItems.filter { $0.fileType == .livePhoto }.count
            if livePhotoCount > 0 {
                writeToLog("Detected \(livePhotoCount) Live Photos in this batch")
                logger.info("Identified \(livePhotoCount) Live Photos out of \(mediaItems.count) items")
            }
        } catch {
            writeToLog("Error processing Live Photo components: \(error.localizedDescription)")
            logger.error("Live Photo processing failed: \(error.localizedDescription)")
            // Continue with original items if processing fails
            processedMediaItems = mediaItems
        }
        
        var results: [ImportResult] = []
        var batchIndex = 0
        let batchTotal = processedMediaItems.count
        
        for item in processedMediaItems {
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
                if item.fileType == .livePhoto, let videoURL = item.livePhotoComponentURL {
                    // For Live Photos, use our enhanced implementation
                    logger.debug("Importing Live Photo: \(item.fileURL.lastPathComponent) with \(videoURL.lastPathComponent)")
                    result = try await photosImporter.importLivePhoto(item, motionURL: videoURL)
                    
                    if result.assetId != nil {
                        DispatchQueue.main.async {
                            self.progress.livePhotosReconstructed += 1
                        }
                        logger.info("Successfully reconstructed Live Photo: \(item.fileURL.lastPathComponent)")
                    } else {
                        logger.warning("Failed to reconstruct Live Photo: \(item.fileURL.lastPathComponent)")
                    }
                } else if item.fileType == .motionPhoto {
                    // Motion Photos require special handling
                    logger.debug("Importing Motion Photo: \(item.fileURL.lastPathComponent)")
                    result = try await photosImporter.importSingleMedia(item)
                    
                    if result.assetId != nil {
                        DispatchQueue.main.async {
                            self.progress.photosProcessed += 1
                        }
                    }
                } else {
                    // Regular media import
                    logger.debug("Importing standard media: \(item.fileURL.lastPathComponent)")
                    result = try await photosImporter.importSingleMedia(item)
                    
                    if item.fileType == .photo {
                        DispatchQueue.main.async {
                            self.progress.photosProcessed += 1
                        }
                    } else if item.fileType == .video {
                        DispatchQueue.main.async {
                            self.progress.videosProcessed += 1
                        }
                    }
                }
                
                if result.assetId == nil {
                    DispatchQueue.main.async {
                        self.progress.failedItems += 1
                    }
                    writeToLog("Failed to import \(item.originalFileName): \(result.error?.localizedDescription ?? "Unknown error")")
                    logger.error("Import failed for \(item.originalFileName): \(result.error?.localizedDescription ?? "Unknown error")")
                }
            } catch {
                result = ImportResult(originalItem: item, assetId: nil, error: error)
                DispatchQueue.main.async {
                    self.progress.failedItems += 1
                }
                writeToLog("Error importing \(item.originalFileName): \(error.localizedDescription)")
                logger.error("Exception during import of \(item.originalFileName): \(error.localizedDescription)")
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
        
        // Log import statistics
        let successCount = results.filter { $0.assetId != nil }.count
        let failureCount = results.filter { $0.assetId == nil }.count
        
        writeToLog("Completed batch with \(results.count) results (\(successCount) successful, \(failureCount) failed)")
        logger.info("Batch complete: \(successCount)/\(results.count) successful imports")
        
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