import Foundation

/// File types for media items
enum MediaFileType {
    case photo
    case video
    case livePhoto
    case motionPhoto
    case unknown
    
    /// Determine file type from file extension
    static func determine(from url: URL) -> MediaFileType {
        let ext = url.pathExtension.lowercased()
        
        if ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp"].contains(ext) {
            return .photo
        } else if ["mp4", "mov", "m4v", "3gp", "avi", "mkv", "webm"].contains(ext) {
            return .video
        } else if ext == "mp" || ext == "mvimg" {
            // Special Google Pixel motion photo formats
            return .motionPhoto
        } else {
            return .unknown
        }
    }
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
    var fileType: MediaFileType
    
    /// Names of albums this media belongs to
    let albumNames: [String]
    
    /// Whether this is marked as a favorite
    let isFavorite: Bool
    
    /// URL to the motion component for Live Photos
    var livePhotoComponentURL: URL?
    
    /// Flag indicating this is a motion component of a Live Photo
    var isLivePhotoMotionComponent: Bool = false
    
    /// Paths to albums (may include hierarchy)
    var albumPaths: [String] = []
    
    /// Related media items (e.g., video component of a Live Photo)
    var relatedItems: [MediaItem]?
    
    /// Original JSON data for debugging and verification
    var originalJsonData: [String: Any]?
}

/// Detailed category stats for media types
struct MediaTypeStats {
    var photos: Int = 0
    var videos: Int = 0
    var livePhotos: Int = 0
    var motionPhotos: Int = 0
    var otherTypes: Int = 0
    
    var total: Int {
        return photos + videos + livePhotos + motionPhotos + otherTypes
    }
}

/// Detailed category stats for file formats
struct FileFormatStats {
    var jpeg: Int = 0
    var heic: Int = 0
    var png: Int = 0
    var gif: Int = 0
    var mp4: Int = 0
    var mov: Int = 0
    var otherFormats: Int = 0
    
    var total: Int {
        return jpeg + heic + png + gif + mp4 + mov + otherFormats
    }
}

/// Detailed stats for metadata types preserved
struct MetadataStats {
    var withLocation: Int = 0
    var withDescription: Int = 0
    var withTitle: Int = 0
    var withFavorite: Int = 0
    var withPeople: Int = 0
    var withCustomMetadata: Int = 0
    var withCreationDate: Int = 0
}

/// Comprehensive error and issue tracking
struct MigrationIssues {
    var metadataParsingErrors: Int = 0
    var fileAccessErrors: Int = 0
    var importErrors: Int = 0
    var albumCreationErrors: Int = 0
    var mediaTypeUnsupported: Int = 0
    var metadataUnsupported: Int = 0
    var memoryPressureEvents: Int = 0
    var fileCorruptionIssues: Int = 0
    
    var totalIssues: Int {
        return metadataParsingErrors + fileAccessErrors + importErrors + 
               albumCreationErrors + mediaTypeUnsupported + metadataUnsupported +
               memoryPressureEvents + fileCorruptionIssues
    }
    
    // Detailed error messages with timestamps
    var detailedErrors: [(timestamp: Date, message: String)] = []
}

/// Timeline of notable events during migration
struct MigrationTimeline {
    var startTime: Date
    var endTime: Date
    var extractionStartTime: Date?
    var extractionEndTime: Date?
    var metadataProcessingStartTime: Date?
    var metadataProcessingEndTime: Date?
    var importStartTime: Date?
    var importEndTime: Date?
    var albumCreationStartTime: Date?
    var albumCreationEndTime: Date?
    
    var totalDuration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    var events: [(timestamp: Date, event: String)] = []
}

/// Comprehensive migration summary with detailed statistics
struct MigrationSummary {
    // Basic stats
    var totalItemsProcessed: Int = 0
    var successfulImports: Int = 0
    var failedImports: Int = 0
    var albumsCreated: Int = 0
    var albumsWithItems: [String: Int] = [:]  // Album name -> item count
    var livePhotosReconstructed: Int = 0
    var metadataIssues: Int = 0
    
    // Detailed statistics by category
    var mediaTypeStats = MediaTypeStats()
    var fileFormatStats = FileFormatStats()
    var metadataStats = MetadataStats()
    var issues = MigrationIssues()
    
    // Timeline info
    var timeline: MigrationTimeline?
    
    // Overall success rate (percentage)
    var successRate: Double {
        guard totalItemsProcessed > 0 else { return 0 }
        return (Double(successfulImports) / Double(totalItemsProcessed)) * 100.0
    }
    
    // Path to detailed log file
    var logPath: URL?
    
    // Path to exported report
    var reportPath: URL?
    
    // Batch processing information
    var batchProcessingUsed: Bool = false
    var batchesProcessed: Int = 0
    var batchSize: Int = 0
    var peakMemoryUsage: UInt64 = 0
    var processingTime: TimeInterval = 0
    var averageItemProcessingTime: TimeInterval {
        guard totalItemsProcessed > 0 else { return 0 }
        return processingTime / Double(totalItemsProcessed)
    }
}