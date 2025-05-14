import Foundation
import Photos
import Combine

/// Service status for photo import operations
enum PhotoImportServiceStatus {
    case idle
    case preparingImport
    case importing(progress: Double, totalItems: Int, completedItems: Int)
    case paused
    case completed(successful: Int, failed: Int)
    case failed(Error)
}

/// Service for importing photos and videos into Photos library
class PhotosImportService: ObservableObject {
    /// Published status for UI updates
    @Published private(set) var status: PhotoImportServiceStatus = .idle
    
    /// Published import statistics
    @Published private(set) var importStats: ImportStats = ImportStats()
    
    /// Structure to track import statistics
    struct ImportStats {
        var totalItems: Int = 0
        var completedItems: Int = 0
        var failedItems: Int = 0
        var photosImported: Int = 0
        var videosImported: Int = 0
        var livePhotosImported: Int = 0
        var albumsCreated: Int = 0
        
        var successRate: Double {
            guard totalItems > 0 else { return 0 }
            return Double(completedItems) / Double(totalItems) * 100.0
        }
    }
    
    private let photosImporter = PhotosImporter()
    private var importQueue: [MediaItem] = []
    private var currentBatchSize: Int = 10
    private var cancellables = Set<AnyCancellable>()
    private var isPaused = false
    private var importResults: [String: ImportResult] = [:]
    
    /// Initialize the service
    init() {
        // Set up importer delegate
        photosImporter.delegate = self
    }
    
    /// Check for Photos access permissions
    /// - Returns: Boolean indicating if we have permission, and optional error
    func checkPhotoLibraryPermission() async -> (granted: Bool, error: Error?) {
        return await photosImporter.requestPhotoLibraryPermission()
    }
    
    /// Prepare for import by adding items to the queue
    /// - Parameter items: Array of media items to import
    func prepareImport(items: [MediaItem]) {
        self.status = .preparingImport
        self.importQueue = items
        self.importStats.totalItems = items.count
        self.importStats.completedItems = 0
        self.importStats.failedItems = 0
        self.importResults = [:]
    }
    
    /// Start or resume the import process
    func startImport() async {
        guard !importQueue.isEmpty else {
            status = .completed(successful: importStats.completedItems, failed: importStats.failedItems)
            return
        }
        
        // Check permissions first
        let (granted, error) = await checkPhotoLibraryPermission()
        guard granted else {
            status = .failed(error ?? MigrationError.photosAccessDenied)
            return
        }
        
        isPaused = false
        
        // Process items in batches to avoid memory issues
        await processNextBatch()
    }
    
    /// Process the next batch of items
    private func processNextBatch() async {
        guard !importQueue.isEmpty, !isPaused else {
            if importQueue.isEmpty {
                status = .completed(successful: importStats.completedItems, failed: importStats.failedItems)
            } else {
                status = .paused
            }
            return
        }
        
        // Take the next batch of items to process
        let batchSize = min(currentBatchSize, importQueue.count)
        let batch = Array(importQueue.prefix(batchSize))
        importQueue.removeFirst(batchSize)
        
        updateStatus()
        
        // Process each item in the batch
        for item in batch {
            guard !isPaused else {
                status = .paused
                return
            }
            
            do {
                let result: ImportResult
                
                // Check if this is a live photo with a paired motion component
                if item.fileType == .livePhoto, let relatedItems = item.relatedItems, !relatedItems.isEmpty {
                    // Assuming the first related item is the motion component
                    let motionItem = relatedItems[0]
                    result = try await photosImporter.importLivePhoto(item, motionURL: motionItem.fileURL)
                } else {
                    result = try await photosImporter.importSingleMedia(item)
                }
                
                // Store the result
                if let id = item.id {
                    importResults[id] = result
                }
                
                // Update statistics
                updateStats(for: result)
            } catch {
                // Handle errors
                importStats.failedItems += 1
                if let id = item.id {
                    importResults[id] = ImportResult(originalItem: item, assetId: nil, error: error)
                }
            }
            
            // Update status after each item
            updateStatus()
        }
        
        // Process next batch if we have more items
        if !importQueue.isEmpty && !isPaused {
            await processNextBatch()
        } else if importQueue.isEmpty {
            status = .completed(successful: importStats.completedItems, failed: importStats.failedItems)
        }
    }
    
    /// Pause the import process
    func pauseImport() {
        isPaused = true
        status = .paused
    }
    
    /// Cancel the current import process
    func cancelImport() {
        photosImporter.cancelImport()
        importQueue.removeAll()
        status = .idle
    }
    
    /// Get the result for a specific item
    /// - Parameter itemId: The ID of the media item
    /// - Returns: ImportResult or nil if not found
    func getImportResult(for itemId: String) -> ImportResult? {
        return importResults[itemId]
    }
    
    /// Reset the service to its initial state
    func reset() {
        cancelImport()
        importStats = ImportStats()
        importResults = [:]
        photosImporter.resetCancellation()
    }
    
    /// Update the import statistics based on a result
    /// - Parameter result: The import result
    private func updateStats(for result: ImportResult) {
        if result.error == nil && result.assetId != nil {
            importStats.completedItems += 1
            
            // Update type-specific counters
            switch result.originalItem.fileType {
            case .photo:
                importStats.photosImported += 1
            case .video:
                importStats.videosImported += 1
            case .livePhoto:
                importStats.livePhotosImported += 1
            default:
                break
            }
        } else {
            importStats.failedItems += 1
        }
    }
    
    /// Update the current status
    private func updateStatus() {
        let progress = calculateProgress()
        status = .importing(
            progress: progress,
            totalItems: importStats.totalItems,
            completedItems: importStats.completedItems
        )
    }
    
    /// Calculate the current progress
    /// - Returns: Progress as a Double between 0 and 1
    private func calculateProgress() -> Double {
        guard importStats.totalItems > 0 else { return 0 }
        let completed = Double(importStats.completedItems + importStats.failedItems)
        return completed / Double(importStats.totalItems)
    }
}

// MARK: - PhotosImportDelegate implementation
extension PhotosImportService: PhotosImportDelegate {
    func importProgress(updated progress: ImportProgress, for item: MediaItem) {
        // We're using our own progress tracking above, but could integrate this for more granular updates
    }
    
    func importCompleted(result: ImportResult) {
        // This is handled in the processNextBatch method
    }
} 