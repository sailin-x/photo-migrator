import Foundation
import Photos
import CoreLocation

struct MediaItem: Identifiable {
    let id = UUID()
    let fileURL: URL
    let originalFileName: String
    let fileType: MediaType
    let metadata: MediaMetadata
    var albumPaths: [String] = []
    var livePhotoComponentURL: URL?
    var isLivePhotoMotionComponent = false
    
    enum MediaType: String {
        case image
        case video
        case livePhoto
        case unknown
        
        static func determine(from url: URL) -> MediaType {
            let ext = url.pathExtension.lowercased()
            
            if ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp"].contains(ext) {
                return .image
            } else if ["mp4", "mov", "m4v", "3gp", "avi", "mkv", "webm"].contains(ext) {
                return .video
            } else {
                return .unknown
            }
        }
    }
}

struct MediaMetadata {
    var title: String?
    var description: String?
    var dateTaken: Date?
    var location: CLLocation?
    var isFavorite: Bool = false
    var people: [String] = []
    var keywords: [String] = []
    
    // Technical metadata
    var cameraMake: String?
    var cameraModel: String?
    var lensInfo: String?
    var iso: Int?
    var aperture: Double?
    var shutterSpeed: Double?
    var width: Int?
    var height: Int?
    
    // Original JSON data for debugging and verification
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
}
