import Foundation
import Photos
import Combine

/// Status of the Live Photo operations
enum LivePhotoStatus {
    case idle
    case scanning
    case reconstructing(Int, Int) // current, total
    case completed(Int)
    case failed(Error)
}

/// Service that coordinates Live Photo discovery and reconstruction
class LivePhotoManager: ObservableObject {
    /// Current status
    @Published private(set) var status: LivePhotoStatus = .idle
    
    /// Discovered Live Photo items
    @Published private(set) var livePhotoItems: [MediaItem] = []
    
    /// Statistics about Live Photos
    @Published private(set) var stats = LivePhotoStats()
    
    /// Structure to track Live Photo statistics
    struct LivePhotoStats {
        var totalLivePhotosDetected: Int = 0
        var reconstructed: Int = 0
        var failed: Int = 0
        var pending: Int = 0
        
        var successRate: Double {
            guard totalLivePhotosDetected > 0 else { return 0 }
            return Double(reconstructed) / Double(totalLivePhotosDetected) * 100.0
        }
    }
    
    /// Dependencies
    private let livePhotoProcessor = LivePhotoProcessor()
    private let livePhotoBuilder = LivePhotoBuilder()
    private let logger = Logger.shared
    
    /// Whether reconstruction is currently cancellable
    private var isCancelled = false
    
    /// Initialize the manager
    init() {
        logger.info("LivePhotoManager initialized")
    }
    
    /// Scan a directory for Live Photos
    /// - Parameter directoryURL: URL to the directory to scan
    /// - Returns: Array of potential Live Photo items
    func scanForLivePhotos(in directoryURL: URL) async throws -> [MediaItem] {
        guard !isCancelled else {
            return []
        }
        
        // Update status
        await MainActor.run {
            status = .scanning
            livePhotoItems = []
            stats = LivePhotoStats()
        }
        
        logger.info("Scanning for Live Photos in \(directoryURL.path)")
        
        do {
            // Find all media files in the directory
            let fileManager = FileManager.default
            let directoryContents = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles]
            )
            
            let mediaFiles = directoryContents.filter { isMediaFile($0) }
            logger.info("Found \(mediaFiles.count) media files in directory")
            
            // Create MediaItems for each file
            var mediaItems: [MediaItem] = []
            
            for fileURL in mediaFiles {
                let fileType = MediaFileType.determine(from: fileURL)
                
                // Create a basic MediaItem
                let mediaItem = MediaItem(
                    id: UUID().uuidString,
                    title: fileURL.deletingPathExtension().lastPathComponent,
                    description: nil,
                    timestamp: try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date(),
                    latitude: nil,
                    longitude: nil,
                    fileURL: fileURL,
                    fileType: fileType,
                    albumNames: [],
                    isFavorite: false
                )
                
                mediaItems.append(mediaItem)
            }
            
            // Process items looking for Live Photo pairs
            let processedItems = try await livePhotoProcessor.processLivePhotoComponents(mediaItems: mediaItems)
            
            // Filter to just Live Photo items
            let discoveredLivePhotos = processedItems.filter { $0.fileType == .livePhoto }
            
            // Update state on main thread
            await MainActor.run {
                self.livePhotoItems = discoveredLivePhotos
                self.stats.totalLivePhotosDetected = discoveredLivePhotos.count
                self.stats.pending = discoveredLivePhotos.count
                self.status = .completed(discoveredLivePhotos.count)
            }
            
            logger.info("Discovered \(discoveredLivePhotos.count) potential Live Photos")
            return discoveredLivePhotos
            
        } catch {
            logger.error("Failed to scan for Live Photos: \(error.localizedDescription)")
            
            await MainActor.run {
                self.status = .failed(error)
            }
            
            throw error
        }
    }
    
    /// Reconstruct a specific Live Photo
    /// - Parameter item: The MediaItem representing a Live Photo
    /// - Returns: The local identifier of the created asset
    func reconstructLivePhoto(_ item: MediaItem) async throws -> String? {
        guard !isCancelled else {
            return nil
        }
        
        guard let videoURL = item.livePhotoComponentURL else {
            throw MigrationError.invalidMediaType("Missing video component for Live Photo")
        }
        
        logger.info("Reconstructing Live Photo: \(item.fileURL.lastPathComponent) with \(videoURL.lastPathComponent)")
        
        // Prepare metadata
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
        
        // Add favorite flag if true
        if item.isFavorite {
            metadata["favorite"] = true
        }
        
        do {
            // Use the builder to create the Live Photo
            let assetId = try await livePhotoBuilder.buildAndImportLivePhoto(
                imageURL: item.fileURL,
                videoURL: videoURL,
                metadata: metadata
            )
            
            if let assetId = assetId {
                // Verify the Live Photo was properly created
                let isValid = livePhotoBuilder.verifyLivePhoto(localIdentifier: assetId)
                
                if isValid {
                    // Update stats
                    await MainActor.run {
                        self.stats.reconstructed += 1
                        self.stats.pending -= 1
                    }
                    
                    logger.info("Successfully reconstructed Live Photo with ID: \(assetId)")
                    return assetId
                } else {
                    logger.warning("Live Photo verification failed for asset ID: \(assetId)")
                    
                    // Update stats
                    await MainActor.run {
                        self.stats.failed += 1
                        self.stats.pending -= 1
                    }
                    
                    return nil
                }
            } else {
                logger.error("Failed to create Live Photo asset")
                
                // Update stats
                await MainActor.run {
                    self.stats.failed += 1
                    self.stats.pending -= 1
                }
                
                return nil
            }
        } catch {
            logger.error("Exception during Live Photo reconstruction: \(error.localizedDescription)")
            
            // Update stats
            await MainActor.run {
                self.stats.failed += 1
                self.stats.pending -= 1
            }
            
            throw error
        }
    }
    
    /// Batch reconstruct a list of Live Photos
    /// - Parameter items: Array of MediaItem objects representing Live Photos
    /// - Returns: Dictionary mapping MediaItem IDs to their asset IDs
    func reconstructLivePhotos(_ items: [MediaItem]) async throws -> [String: String] {
        guard !isCancelled else {
            return [:]
        }
        
        await MainActor.run {
            self.status = .reconstructing(0, items.count)
        }
        
        logger.info("Starting batch reconstruction of \(items.count) Live Photos")
        
        var results: [String: String] = [:]
        
        for (index, item) in items.enumerated() {
            // Check for cancellation
            if isCancelled {
                logger.info("Live Photo reconstruction cancelled after \(index) of \(items.count)")
                break
            }
            
            // Update status
            await MainActor.run {
                self.status = .reconstructing(index + 1, items.count)
            }
            
            do {
                if let assetId = try await reconstructLivePhoto(item) {
                    results[item.id] = assetId
                }
            } catch {
                logger.warning("Failed to reconstruct Live Photo: \(item.fileURL.lastPathComponent) - \(error.localizedDescription)")
                // Continue with next item even if this one fails
                continue
            }
        }
        
        // Update final status
        await MainActor.run {
            self.status = .completed(results.count)
        }
        
        logger.info("Completed Live Photo reconstruction. Success: \(results.count), Failed: \(items.count - results.count)")
        
        return results
    }
    
    /// Cancel any ongoing operations
    func cancel() {
        isCancelled = true
        logger.info("Live Photo operations cancelled")
    }
    
    /// Reset cancellation status
    func resetCancellation() {
        isCancelled = false
    }
    
    // MARK: - Helper Methods
    
    /// Check if a file is a media file that could be part of a Live Photo
    private func isMediaFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "webp", "bmp"]
        let videoExtensions = ["mp4", "mov", "m4v", "3gp", "avi", "mkv", "webm", "mp"]
        
        let ext = url.pathExtension.lowercased()
        return imageExtensions.contains(ext) || videoExtensions.contains(ext)
    }
} 