import Foundation
import CoreLocation
import CoreImage

/// Service for securely handling and sanitizing metadata to protect user privacy
class MetadataPrivacyManager {
    /// Shared singleton instance
    static let shared = MetadataPrivacyManager()
    
    /// The current user preferences
    private let preferences = UserPreferences.shared
    
    /// Logger instance
    private let logger = Logger.shared
    
    /// Private initializer for singleton pattern
    private init() {}
    
    /// Sanitize metadata according to privacy preferences
    /// - Parameter metadata: The original metadata object
    /// - Returns: A sanitized copy of the metadata
    func sanitizeMetadata(_ metadata: MediaMetadata) -> MediaMetadata {
        // Create a copy to avoid modifying the original
        var sanitizedMetadata = metadata
        
        // Apply privacy settings based on privacy level
        switch preferences.privacyLevel {
        case .standard:
            // In standard mode, we apply only the explicit privacy settings
            applyStandardPrivacySettings(to: &sanitizedMetadata)
            
        case .enhanced:
            // In enhanced mode, we apply stricter settings automatically
            applyEnhancedPrivacySettings(to: &sanitizedMetadata)
            
        case .maximum:
            // In maximum mode, we strip most metadata
            applyMaximumPrivacySettings(to: &sanitizedMetadata)
        }
        
        return sanitizedMetadata
    }
    
    /// Apply standard privacy settings based on explicit user preferences
    /// - Parameter metadata: The metadata to sanitize
    private func applyStandardPrivacySettings(to metadata: inout MediaMetadata) {
        // Handle location data
        if preferences.stripGPSData || !preferences.preserveLocationData {
            removeLocationData(from: &metadata)
        } else if preferences.obfuscateLocationData, let location = metadata.location {
            metadata.location = obfuscateLocation(location)
        }
        
        // Handle device info
        if preferences.stripDeviceInfo {
            removeDeviceInfo(from: &metadata)
        }
        
        // Handle personal identifiers
        if preferences.stripPersonalIdentifiers {
            removePersonalIdentifiers(from: &metadata)
        }
        
        // Handle original raw data (for security, never keep raw data containing sensitive info)
        sanitizeRawData(in: &metadata)
    }
    
    /// Apply enhanced privacy settings with stricter defaults
    /// - Parameter metadata: The metadata to sanitize
    private func applyEnhancedPrivacySettings(to metadata: inout MediaMetadata) {
        // Location data is always at least obfuscated in enhanced mode
        if preferences.stripGPSData || !preferences.preserveLocationData {
            removeLocationData(from: &metadata)
        } else {
            metadata.location = obfuscateLocation(metadata.location)
        }
        
        // Device info is removed unless explicitly preserved
        removeDeviceInfo(from: &metadata)
        
        // Personal identifiers are removed
        removePersonalIdentifiers(from: &metadata)
        
        // Raw data is definitely sanitized
        sanitizeRawData(in: &metadata)
    }
    
    /// Apply maximum privacy settings by removing most metadata
    /// - Parameter metadata: The metadata to sanitize
    private func applyMaximumPrivacySettings(to metadata: inout MediaMetadata) {
        // Remove all location data
        removeLocationData(from: &metadata)
        
        // Remove all device info
        removeDeviceInfo(from: &metadata)
        
        // Remove all personal identifiers
        removePersonalIdentifiers(from: &metadata)
        
        // Keep only essential metadata
        keepOnlyEssentialMetadata(in: &metadata)
        
        // Make sure raw data is definitely removed
        metadata.originalJsonData = nil
        metadata.exifData = nil
        metadata.iptcData = nil
    }
    
    /// Remove location data from metadata
    /// - Parameter metadata: The metadata to modify
    private func removeLocationData(from metadata: inout MediaMetadata) {
        metadata.location = nil
    }
    
    /// Obfuscate location data by reducing precision
    /// - Parameter location: The original location
    /// - Returns: An obfuscated location
    private func obfuscateLocation(_ location: CLLocation?) -> CLLocation? {
        guard let location = location else { return nil }
        
        // Get the precision level from preferences
        let precision = preferences.locationPrecisionLevel
        
        // Calculate the multiplier based on precision level
        let multiplier = pow(10, Double(precision))
        
        // Round coordinates to reduced precision
        let roundedLatitude = round(location.coordinate.latitude * multiplier) / multiplier
        let roundedLongitude = round(location.coordinate.longitude * multiplier) / multiplier
        
        // Create a new location with obfuscated coordinates but without altitude
        // Altitude is removed for enhanced privacy
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: roundedLatitude, longitude: roundedLongitude),
            altitude: 0, // Remove altitude information
            horizontalAccuracy: -1, // Unknown accuracy
            verticalAccuracy: -1,   // Unknown accuracy
            timestamp: location.timestamp
        )
    }
    
    /// Remove device information from metadata
    /// - Parameter metadata: The metadata to modify
    private func removeDeviceInfo(from metadata: inout MediaMetadata) {
        metadata.cameraMake = nil
        metadata.cameraModel = nil
        metadata.software = nil
    }
    
    /// Remove personal identifiers from metadata
    /// - Parameter metadata: The metadata to modify
    private func removePersonalIdentifiers(from metadata: inout MediaMetadata) {
        metadata.copyright = nil
        metadata.people = []
        
        // Optionally clear description and title if they might contain personal info
        if preferences.privacyLevel == .maximum {
            metadata.title = nil
            metadata.description = nil
        }
    }
    
    /// Keep only essential metadata and remove everything else
    /// - Parameter metadata: The metadata to modify
    private func keepOnlyEssentialMetadata(in metadata: inout MediaMetadata) {
        // Create a new metadata object with only essential fields
        let essentialMetadata = MediaMetadata()
        
        // Only preserve specified fields
        if preferences.preserveCreationDates {
            essentialMetadata.timestamp = metadata.timestamp
        }
        
        if preferences.preserveFavorites {
            essentialMetadata.isFavorite = metadata.isFavorite
        }
        
        if preferences.preserveDescriptions {
            essentialMetadata.title = metadata.title
            essentialMetadata.description = metadata.description
        }
        
        // Replace the metadata with the minimal version
        metadata = essentialMetadata
    }
    
    /// Sanitize raw metadata dictionaries to remove sensitive information
    /// - Parameter metadata: The metadata to sanitize
    private func sanitizeRawData(in metadata: inout MediaMetadata) {
        // If we're keeping the original JSON data, sanitize it
        if var originalJsonData = metadata.originalJsonData {
            // Remove any GPS data
            originalJsonData.removeValue(forKey: "geoData")
            originalJsonData.removeValue(forKey: "geoDataExif")
            
            // Remove device information
            if preferences.stripDeviceInfo {
                originalJsonData.removeValue(forKey: "cameraDetails")
                originalJsonData.removeValue(forKey: "cameraMake")
                originalJsonData.removeValue(forKey: "cameraModel")
            }
            
            // Remove personal identifiers
            if preferences.stripPersonalIdentifiers {
                originalJsonData.removeValue(forKey: "people")
                originalJsonData.removeValue(forKey: "copyright")
            }
            
            metadata.originalJsonData = originalJsonData
        }
        
        // If we're keeping EXIF data, sanitize it
        if var exifData = metadata.exifData {
            // Remove GPS data
            exifData.removeValue(forKey: "GPS")
            exifData.removeValue(forKey: "{GPS}")
            
            // Remove device information if needed
            if preferences.stripDeviceInfo {
                exifData.removeValue(forKey: "Make")
                exifData.removeValue(forKey: "Model")
                exifData.removeValue(forKey: "Software")
                exifData.removeValue(forKey: "{TIFF}")
            }
            
            // Remove creator information if needed
            if preferences.stripPersonalIdentifiers {
                exifData.removeValue(forKey: "Artist")
                exifData.removeValue(forKey: "Copyright")
                exifData.removeValue(forKey: "XMP")
            }
            
            metadata.exifData = exifData
        }
        
        // If we're keeping IPTC data, sanitize it
        if var iptcData = metadata.iptcData {
            // Remove personal identifiers if needed
            if preferences.stripPersonalIdentifiers {
                iptcData.removeValue(forKey: "Keywords")
                iptcData.removeValue(forKey: "Caption")
                iptcData.removeValue(forKey: "By-line")
                iptcData.removeValue(forKey: "Copyright Notice")
            }
            
            metadata.iptcData = iptcData
        }
    }
    
    /// Safely log metadata without exposing sensitive information
    /// - Parameters:
    ///   - metadata: The metadata to log
    ///   - label: Optional label for the log entry
    func safelyLogMetadata(_ metadata: MediaMetadata, label: String = "Metadata") {
        // Don't log anything if logging of sensitive data is disabled
        guard preferences.logSensitiveMetadata else {
            logger.log("\(label): [Logging suppressed due to privacy settings]")
            return
        }
        
        // Create a safe copy of the metadata for logging
        var logSafeMetadata = metadata
        
        // Always remove potentially sensitive information from logs
        if logSafeMetadata.location != nil {
            logSafeMetadata.location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                altitude: 0,
                horizontalAccuracy: -1,
                verticalAccuracy: -1,
                timestamp: Date()
            )
        }
        
        // Remove raw data dictionaries
        logSafeMetadata.originalJsonData = nil
        logSafeMetadata.exifData = nil
        logSafeMetadata.iptcData = nil
        
        // Log only the presence of personal identifiers, not their values
        if !logSafeMetadata.people.isEmpty {
            logger.log("\(label): Contains \(logSafeMetadata.people.count) people tags")
            logSafeMetadata.people = []
        }
        
        // Log only basic properties that don't contain sensitive information
        logger.log("\(label): hasLocationData=\(metadata.location != nil), " +
                  "hasTimestamp=\(metadata.timestamp != nil), " +
                  "hasDescription=\(metadata.description != nil), " +
                  "hasCameraInfo=\(metadata.hasCameraInfo)")
    }
} 