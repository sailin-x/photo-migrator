import Foundation
import SwiftUI

/// Overall progress tracking for the migration process
class MigrationProgress: ObservableObject {
    /// Migration stages
    enum Stage {
        case notStarted
        case initializing
        case extractingArchive
        case processingMetadata
        case processingLivePhotos
        case importingPhotos
        case organizingAlbums
        case complete
        case error
    }
    
    /// Progress message or error type
    enum MessageType {
        case info
        case warning
        case error
        
        /// Create an information message
        static func info(_ message: String) -> ProgressMessage {
            return ProgressMessage(message: message, type: .info)
        }
        
        /// Create a warning message
        static func warning(_ message: String) -> ProgressMessage {
            return ProgressMessage(message: message, type: .warning)
        }
        
        /// Create an error message
        static func error(_ message: String) -> ProgressMessage {
            return ProgressMessage(message: message, type: .error)
        }
    }
    
    /// A message with a type (info, warning, error)
    struct ProgressMessage: Identifiable {
        let id = UUID()
        let message: String
        let type: MessageType
        let timestamp = Date()
    }
    
    /// The current stage of migration
    @Published var currentStage: Stage = .notStarted
    
    /// Overall progress percentage (0-100)
    @Published var overallProgress: Double = 0
    
    /// Stage-specific progress percentage (0-100)
    @Published var stageProgress: Double = 0
    
    /// Total number of items to process
    @Published var totalItems: Int = 0
    
    /// Number of items processed so far
    @Published var processedItems: Int = 0
    
    /// Most recent progress message
    @Published var currentMessage: String = ""
    
    /// Name of the current item being processed
    @Published var currentItemName: String = ""
    
    /// Number of photos processed
    @Published var photosProcessed: Int = 0
    
    /// Number of videos processed
    @Published var videosProcessed: Int = 0
    
    /// Number of Live Photos reconstructed successfully
    @Published var livePhotosReconstructed: Int = 0
    
    /// Number of items that failed to process
    @Published var failedItems: Int = 0
    
    /// Number of albums created
    @Published var albumsCreated: Int = 0
    
    /// Recent progress or error messages
    @Published var recentMessages: [ProgressMessage] = []
    
    /// Total elapsed time in seconds
    @Published var elapsedTime: TimeInterval = 0
    
    /// Whether the operation has been cancelled
    @Published var isCancelled: Bool = false
    
    // MARK: - Batch Processing Properties
    
    /// Total number of batches to process
    @Published var totalBatches: Int = 0
    
    /// Current batch being processed
    @Published var currentBatch: Int = 0
    
    /// Size of each batch (number of items)
    @Published var batchSize: Int = 0
    
    /// Peak memory usage during processing
    @Published var peakMemoryUsage: UInt64 = 0
    
    /// Whether the process is in a memory pressure state
    @Published var isUnderMemoryPressure: Bool = false
    
    /// Memory usage percentage (0-100)
    @Published var memoryUsagePercentage: Double = 0
    
    /// Add a progress message
    func addMessage(_ message: String, type: MessageType = .info) {
        let progressMessage = ProgressMessage(message: message, type: type)
        recentMessages.append(progressMessage)
        currentMessage = message
        
        // Limit number of recent messages
        if recentMessages.count > 100 {
            recentMessages.removeFirst(recentMessages.count - 100)
        }
    }
    
    /// Reset progress for a new migration operation
    func reset() {
        currentStage = .notStarted
        overallProgress = 0
        stageProgress = 0
        totalItems = 0
        processedItems = 0
        currentMessage = ""
        currentItemName = ""
        photosProcessed = 0
        videosProcessed = 0
        livePhotosReconstructed = 0
        failedItems = 0
        albumsCreated = 0
        recentMessages = []
        elapsedTime = 0
        isCancelled = false
        
        // Reset batch processing properties
        totalBatches = 0
        currentBatch = 0
        batchSize = 0
        peakMemoryUsage = 0
        isUnderMemoryPressure = false
        memoryUsagePercentage = 0
    }
    
    /// Update memory usage information
    func updateMemoryUsage(percentage: Double, isUnderPressure: Bool) {
        memoryUsagePercentage = percentage
        isUnderMemoryPressure = isUnderPressure
    }
}