import Foundation

/// File types for media items
enum MediaFileType {
    case photo
    case video
    case livePhoto
    case motionPhoto
    case unknown
}

/// Represents a media item (photo or video) with metadata
struct MediaItem {
    /// Unique identifier for the media item
    let id: String
    
    /// Title of the media item
    let title: String?
    
    /// Description or caption
    let description: String?
    
    /// Creation timestamp
    let timestamp: Date
    
    /// GPS latitude
    let latitude: Double?
    
    /// GPS longitude
    let longitude: Double?
    
    /// Local file URL
    let fileURL: URL
    
    /// Type of media file
    let fileType: MediaFileType
    
    /// Names of albums this media belongs to
    let albumNames: [String]
    
    /// Whether this is marked as a favorite
    let isFavorite: Bool
    
    /// Related media items (e.g., video component of a Live Photo)
    var relatedItems: [MediaItem]?
    
    /// Original JSON data for debugging and verification
    var originalJsonData: [String: Any]?
}

struct MigrationSummary {
    var totalItemsProcessed: Int = 0
    var successfulImports: Int = 0
    var failedImports: Int = 0
    var albumsCreated: Int = 0
    var livePhotosReconstructed: Int = 0
    var metadataIssues: Int = 0
    var errors: [String] = []
    var logPath: URL?
    
    // Batch processing information
    var batchProcessingUsed: Bool = false
    var batchesProcessed: Int = 0
    var batchSize: Int = 0
    var peakMemoryUsage: UInt64 = 0
    var processingTime: TimeInterval = 0
}