import Foundation

struct MigrationProgress {
    // Overall progress
    var totalItems: Int = 0
    var processedItems: Int = 0
    
    // Stage-specific details
    var currentStage: MigrationStage = .initializing
    var currentItemName: String = ""
    var stageProgress: Double = 0.0
    var elapsedTime: TimeInterval = 0
    var estimatedTimeRemaining: TimeInterval?
    
    // Detailed counts
    var photosProcessed: Int = 0
    var videosProcessed: Int = 0
    var livePhotosReconstructed: Int = 0
    var albumsCreated: Int = 0
    var failedItems: Int = 0
    
    // Recent errors or warnings
    var recentMessages: [ProgressMessage] = []
    
    var overallProgress: Double {
        totalItems > 0 ? Double(processedItems) / Double(totalItems) : 0
    }
    
    enum MigrationStage: String, CaseIterable {
        case initializing = "Initializing"
        case scanning = "Scanning archive"
        case extractingMetadata = "Extracting metadata"
        case processingMedia = "Processing media files"
        case importingToPhotos = "Importing to Apple Photos"
        case organizingAlbums = "Organizing albums"
        case cleaning = "Cleaning up"
        case complete = "Complete"
        case failed = "Failed"
    }
    
    struct ProgressMessage {
        let timestamp: Date
        let type: MessageType
        let text: String
        
        enum MessageType {
            case info, warning, error
        }
        
        static func info(_ text: String) -> ProgressMessage {
            ProgressMessage(timestamp: Date(), type: .info, text: text)
        }
        
        static func warning(_ text: String) -> ProgressMessage {
            ProgressMessage(timestamp: Date(), type: .warning, text: text)
        }
        
        static func error(_ text: String) -> ProgressMessage {
            ProgressMessage(timestamp: Date(), type: .error, text: text)
        }
    }
}
