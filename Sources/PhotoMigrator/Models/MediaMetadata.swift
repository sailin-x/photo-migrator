import Foundation

/// Represents metadata extracted from media files
struct MediaMetadata {
    /// Original timestamp from metadata
    var timestamp: Date?
    
    /// GPS latitude
    var latitude: Double?
    
    /// GPS longitude
    var longitude: Double?
    
    /// Camera make (manufacturer)
    var cameraMake: String?
    
    /// Camera model
    var cameraModel: String?
    
    /// Exposure time
    var exposureTime: Double?
    
    /// Aperture value (f-stop)
    var aperture: Double?
    
    /// ISO value
    var iso: Int?
    
    /// Focal length in mm
    var focalLength: Double?
    
    /// Whether flash was fired
    var flashFired: Bool?
    
    /// Digital zoom ratio
    var digitalZoomRatio: Double?
    
    /// White balance mode
    var whiteBalance: String?
    
    /// Metering mode
    var meteringMode: String?
    
    /// Exposure mode
    var exposureMode: String?
    
    /// Title or caption
    var title: String?
    
    /// Description
    var description: String?
    
    /// Keywords/tags
    var keywords: [String] = []
    
    /// People tags
    var people: [String] = []
    
    /// Whether marked as favorite
    var isFavorite: Bool = false
    
    /// Original JSON data (for debugging/auditing)
    var originalJsonData: [String: Any]?
    
    /// Raw EXIF data
    var exifData: [String: Any]?
    
    /// Raw IPTC data
    var iptcData: [String: Any]?
    
    /// Software used to create/edit the media
    var software: String?
    
    /// Copyright information
    var copyright: String?
    
    /// Initialize an empty metadata object
    init() {}
    
    /// Check if location data is available
    var hasLocationData: Bool {
        return latitude != nil && longitude != nil
    }
    
    /// Check if camera technical data is available
    var hasCameraInfo: Bool {
        return cameraMake != nil || cameraModel != nil
    }
    
    /// Check if exposure data is available
    var hasExposureInfo: Bool {
        return exposureTime != nil || aperture != nil || iso != nil
    }
} 