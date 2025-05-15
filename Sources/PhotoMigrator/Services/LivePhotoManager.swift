import Foundation
import Photos
import SwiftUI
import Combine
import AVFoundation
import UniformTypeIdentifiers

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
    
    /// File manager instance
    private let fileManager = FileManager.default
    
    /// Dependencies
    private let livePhotoProcessor = LivePhotoProcessor()
    private let livePhotoBuilder = LivePhotoBuilder()
    private let logger = Logger.shared
    
    /// Whether reconstruction is currently cancellable
    private var isCancelled = false
    
    /// Photos access manager
    private let photosManager = PHPhotoLibrary.shared()
    
    /// Progress tracking publisher for batch operations
    private var progressPublisher: BatchProgressPublisher?
    
    /// Whether to process Live Photos during import
    var processLivePhotos: Bool = true
    
    /// Maximum timestamp difference for pairing photo and video components
    var maximumTimestampDifference: TimeInterval {
        get { livePhotoProcessor.maximumTimestampDifference }
        set { livePhotoProcessor.maximumTimestampDifference = newValue }
    }
    
    /// Reference to the output directory for processed Live Photos
    private var outputDirectory: URL?
    
    /// Creates a new LivePhotoManager
    /// - Parameter progressPublisher: Optional publisher for tracking progress
    init(progressPublisher: BatchProgressPublisher? = nil) {
        self.progressPublisher = progressPublisher
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
                    timestamp: (try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date(),
                    latitude: nil,
                    longitude: nil,
                    fileURL: fileURL,
                    fileType: .photo,
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
        let resultCount = results.count
        await MainActor.run {
            self.status = .completed(resultCount)
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
    
    /// Process media items to identify and reconstruct Live Photos
    /// - Parameters:
    ///   - mediaItems: Array of MediaItem objects to process
    ///   - outputDirectory: Directory to store processed Live Photos
    /// - Returns: Array of processed MediaItem objects with LivePhotos properly grouped
    func processMediaItems(_ mediaItems: [MediaItem], outputDirectory: URL? = nil) async throws -> [MediaItem] {
        guard processLivePhotos else {
            logger.log("Live Photo processing is disabled. Skipping.")
            return mediaItems
        }
        
        logger.log("Starting Live Photo identification for \(mediaItems.count) media items")
        self.outputDirectory = outputDirectory
        
        // Phase 1: Identify Live Photo pairs
        updateProgress(stage: .identifying, progress: 0.0)
        let livePhotoPairs = livePhotoProcessor.identifyLivePhotoPairs(in: mediaItems)
        logger.log("Identified \(livePhotoPairs.count) Live Photo pairs")
        
        if livePhotoPairs.isEmpty {
            logger.log("No Live Photo pairs found. Returning original items.")
            updateProgress(stage: .complete, progress: 1.0)
            return mediaItems
        }
        
        // Phase 2: Create live photos from the identified pairs
        updateProgress(stage: .processing, progress: 0.2)
        
        // Ensure we have a valid output directory
        let finalOutputDir: URL
        if let specifiedDir = outputDirectory {
            finalOutputDir = specifiedDir
        } else {
            finalOutputDir = FileManager.default.temporaryDirectory.appendingPathComponent("LivePhotos", isDirectory: true)
            if !FileManager.default.fileExists(atPath: finalOutputDir.path) {
                try FileManager.default.createDirectory(at: finalOutputDir, withIntermediateDirectories: true)
            }
        }
        
        // Process each pair
        let totalPairs = livePhotoPairs.count
        var processedItems = mediaItems
        var processedPairs: [LivePhotoPair.ProcessingResult] = []
        
        for (index, pair) in livePhotoPairs.enumerated() {
            // Update progress
            let progress = 0.2 + (0.7 * Double(index) / Double(totalPairs))
            updateProgress(stage: .processing, progress: progress, detail: "Processing \(index + 1) of \(totalPairs)")
            
            do {
                let result = try await livePhotoProcessor.createLivePhoto(from: pair, outputDirectory: finalOutputDir)
                processedPairs.append(result)
                
                // Update the media items array to reflect the processed Live Photo
                if result.success, let _ = result.livePhotoURL {
                    // Update the items to reflect that these are now part of a Live Photo
                    if let photoIndex = processedItems.firstIndex(where: { $0.id == pair.photoItem.id }),
                       let videoIndex = processedItems.firstIndex(where: { $0.id == pair.videoItem.id }) {
                        // Mark the photo as a Live Photo
                        processedItems[photoIndex].fileType = .livePhoto
                        processedItems[photoIndex].livePhotoComponentURL = pair.videoItem.fileURL
                        
                        // Mark the video as a Live Photo component
                        processedItems[videoIndex].isLivePhotoMotionComponent = true
                    }
                }
            } catch {
                logger.log("Error processing Live Photo pair \(index + 1): \(error.localizedDescription)", level: .error)
            }
        }
        
        updateProgress(stage: .finalizing, progress: 0.9, detail: "Finalizing Live Photos")
        
        // Phase 3: Post-process the media items to properly reflect Live Photo status
        let successCount = processedPairs.filter { $0.success }.count
        logger.log("Successfully processed \(successCount) of \(totalPairs) Live Photos")
        
        updateProgress(stage: .complete, progress: 1.0)
        return processedItems
    }
    
    /// Process a directory of media files to identify and reconstruct Live Photos
    /// - Parameters:
    ///   - directory: Directory containing media files
    ///   - outputDirectory: Directory to store processed Live Photos
    /// - Returns: Dictionary mapping original photo paths to their Live Photo results
    func processDirectory(_ directory: URL, outputDirectory: URL) async throws -> [String: URL] {
        guard processLivePhotos else {
            logger.log("Live Photo processing is disabled. Skipping directory processing.")
            return [:]
        }
        
        logger.log("Processing directory for Live Photos: \(directory.path)")
        
        // Scan directory for media files - use Task to avoid async context warning with enumerator
        let mediaFiles = try await Task {
            var foundFiles: [String] = []
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) else {
                throw MigrationError.fileAccessError(path: directory.path)
            }
            
            // Use nextObject() instead of for-in loop to avoid @Sendable warning
            while let fileURL = enumerator.nextObject() as? URL {
                if livePhotoProcessor.isValidLivePhotoComponent(fileURL.path) {
                    foundFiles.append(fileURL.path)
                }
            }
            
            return foundFiles
        }.value
        
        // Identify Live Photo pairs
        updateProgress(stage: .identifying, progress: 0.1)
        let livePairs = livePhotoProcessor.detectLivePhotoPairs(in: mediaFiles)
        logger.log("Identified \(livePairs.count) potential Live Photo pairs in directory")
        
        if livePairs.isEmpty {
            updateProgress(stage: .complete, progress: 1.0)
            return [:]
        }
        
        // Process pairs
        var results: [String: URL] = [:]
        let totalPairs = livePairs.count
        var pairIndex = 0
        
        updateProgress(stage: .processing, progress: 0.2)
        
        for (photoPath, videoPath) in livePairs {
            pairIndex += 1
            let progress = 0.2 + (0.7 * Double(pairIndex) / Double(totalPairs))
            updateProgress(stage: .processing, progress: progress, detail: "Processing \(pairIndex) of \(totalPairs)")
            
            // Create MediaItems for the pair
            let photoURL = URL(fileURLWithPath: photoPath)
            let videoURL = URL(fileURLWithPath: videoPath)
            
            // Get creation dates safely
            let photoCreationDate: Date
            let videoCreationDate: Date
            do {
                if let date = try FileManager.default.attributesOfItem(atPath: photoPath)[.creationDate] as? Date {
                    photoCreationDate = date
                } else {
                    photoCreationDate = Date()
                }
                
                if let date = try FileManager.default.attributesOfItem(atPath: videoPath)[.creationDate] as? Date {
                    videoCreationDate = date
                } else {
                    videoCreationDate = Date()
                }
            } catch {
                // Use current date as fallback
                photoCreationDate = Date()
                videoCreationDate = Date()
            }
            
            let photoBaseName = photoURL.deletingPathExtension().lastPathComponent
            let videoBaseName = videoURL.deletingPathExtension().lastPathComponent
            
            let photoItem = MediaItem(
                id: UUID().uuidString,
                title: photoBaseName,
                description: nil,
                timestamp: photoCreationDate,
                latitude: nil,
                longitude: nil,
                fileURL: photoURL,
                fileType: .photo,
                albumNames: [],
                isFavorite: false,
                livePhotoComponentURL: nil,
                isLivePhotoMotionComponent: false,
                albumPaths: [],
                relatedItems: nil,
                originalJsonData: nil
            )
            
            let videoItem = MediaItem(
                id: UUID().uuidString,
                title: videoBaseName,
                description: nil,
                timestamp: videoCreationDate,
                latitude: nil,
                longitude: nil,
                fileURL: videoURL,
                fileType: .video,
                albumNames: [],
                isFavorite: false,
                livePhotoComponentURL: nil,
                isLivePhotoMotionComponent: false,
                albumPaths: [],
                relatedItems: nil,
                originalJsonData: nil
            )
            
            let pair = LivePhotoPair(photoItem: photoItem, videoItem: videoItem)
            
            do {
                let result = try await livePhotoProcessor.createLivePhoto(from: pair, outputDirectory: outputDirectory)
                if result.success, let livePhotoURL = result.livePhotoURL {
                    results[photoPath] = livePhotoURL
                    logger.log("Successfully created Live Photo for \(photoPath)")
                }
            } catch {
                logger.log("Failed to create Live Photo for pair \(photoPath): \(error.localizedDescription)", level: .error)
            }
        }
        
        updateProgress(stage: .complete, progress: 1.0)
        logger.log("Completed Live Photo directory processing. Created \(results.count) Live Photos")
        return results
    }
    
    /// Update the batch progress publisher with current processing state
    /// - Parameters:
    ///   - stage: Current processing stage
    ///   - progress: Progress value (0.0 to 1.0)
    ///   - detail: Optional detail message
    private func updateProgress(stage: LivePhotoProcessingStage, progress: Double, detail: String? = nil) {
        guard let publisher = progressPublisher else { return }
        
        let message: String
        switch stage {
        case .identifying:
            message = "Identifying Live Photo pairs"
        case .processing:
            message = "Processing Live Photos"
        case .finalizing:
            message = "Finalizing Live Photo processing"
        case .complete:
            message = "Live Photo processing complete"
        }
        
        publisher.updateLivePhotoProgress(
            progress: progress,
            stage: stage,
            message: detail ?? message
        )
    }
}

/// Stages of Live Photo processing
enum LivePhotoProcessingStage {
    case identifying
    case processing
    case finalizing
    case complete
    
    /// String description of the stage
    var description: String {
        switch self {
        case .identifying:
            return "Identifying Live Photo pairs"
        case .processing:
            return "Processing Live Photos"
        case .finalizing:
            return "Finalizing Live Photos"
        case .complete:
            return "Completed"
        }
    }
} 