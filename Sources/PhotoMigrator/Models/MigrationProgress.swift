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