import Foundation
import CoreLocation
import ImageIO
import CoreImage

class MetadataExtractor {
    private let dateFormatter = ISO8601DateFormatter()
    private let privacyManager = MetadataPrivacyManager.shared
    private let logger = Logger.shared
    
    init() {
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    
    func extractMetadata(from jsonURL: URL, for mediaFileURL: URL) throws -> MediaMetadata {
        do {
            let jsonData = try Data(contentsOf: jsonURL)
            guard let jsonObj = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                throw MigrationError.metadataParsingError(details: "Invalid JSON format")
            }
            
            var metadata = MediaMetadata()
            metadata.originalJsonData = jsonObj
            
            // Extract title (often original filename)
            if let title = jsonObj["title"] as? String {
                metadata.title = title
            }
            
            // Extract description
            if let description = jsonObj["description"] as? String {
                metadata.description = description
            }
            
            // Extract timestamp
            if let photoTakenTime = jsonObj["photoTakenTime"] as? [String: Any],
               let timestamp = photoTakenTime["timestamp"] as? String,
               let timestampValue = Double(timestamp) {
                metadata.dateTaken = Date(timeIntervalSince1970: timestampValue)
            }
            
            // Extract location data
            if let geoData = extractGeoData(from: jsonObj) {
                metadata.location = geoData
            }
            
            // Extract favorite status
            if let favorited = jsonObj["favorited"] as? Bool {
                metadata.isFavorite = favorited
            }
            
            // Extract people
            if let people = jsonObj["people"] as? [[String: Any]] {
                for person in people {
                    if let name = person["name"] as? String {
                        metadata.people.append(name)
                    }
                }
            }
            
            // Extract camera info
            if let cameraDetail = jsonObj["cameraDetails"] as? [String: Any] {
                extractCameraDetails(from: cameraDetail, into: &metadata)
            }
            
            // Fallback to EXIF if certain fields are missing
            if metadata.dateTaken == nil || metadata.location == nil {
                let exifMetadata = extractExifMetadata(from: mediaFileURL)
                
                // Use EXIF date if JSON date is missing
                if metadata.dateTaken == nil {
                    metadata.dateTaken = exifMetadata.dateTaken
                }
                
                // Use EXIF location if JSON location is missing
                if metadata.location == nil {
                    metadata.location = exifMetadata.location
                }
                
                // Use EXIF camera data if JSON data is missing
                if metadata.cameraMake == nil {
                    metadata.cameraMake = exifMetadata.cameraMake
                }
                
                if metadata.cameraModel == nil {
                    metadata.cameraModel = exifMetadata.cameraModel
                }
            }
            
            // Apply privacy settings to sanitize metadata before returning
            let sanitizedMetadata = privacyManager.sanitizeMetadata(metadata)
            
            // Log metadata if allowed by privacy settings
            privacyManager.safelyLogMetadata(sanitizedMetadata, label: "Extracted metadata from JSON")
            
            return sanitizedMetadata
        } catch {
            throw MigrationError.metadataParsingError(details: "Error reading JSON file: \(error.localizedDescription)")
        }
    }
    
    func extractExifMetadata(from mediaFileURL: URL) -> MediaMetadata {
        var metadata = MediaMetadata()
        
        guard let imageSource = CGImageSourceCreateWithURL(mediaFileURL as CFURL, nil) else {
            return metadata
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return metadata
        }
        
        // Store the raw EXIF data for potential forensic/debugging purposes
        // This will be sanitized by the privacy manager
        metadata.exifData = properties
        
        // Extract EXIF data
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            // Extract date taken
            if let dateTimeOriginal = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                metadata.dateTaken = dateFormatter.date(from: dateTimeOriginal)
            }
            
            // Extract camera info
            metadata.cameraMake = exif[kCGImagePropertyExifMake as String] as? String
            metadata.cameraModel = exif[kCGImagePropertyExifModel as String] as? String
            
            // Extract other technical details
            if let isoValue = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let iso = isoValue.first {
                metadata.iso = iso
            }
            
            if let apertureValue = exif[kCGImagePropertyExifFNumber as String] as? Double {
                metadata.aperture = apertureValue
            }
            
            if let exposureTime = exif[kCGImagePropertyExifExposureTime as String] as? Double {
                metadata.shutterSpeed = exposureTime
            }
        }
        
        // Extract GPS data
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
               let latitude = gps[kCGImagePropertyGPSLatitude as String] as? Double,
               let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String,
               let longitude = gps[kCGImagePropertyGPSLongitude as String] as? Double {
                
                // Adjust sign based on direction reference
                let latSign: Double = (latitudeRef == "N") ? 1.0 : -1.0
                let longSign: Double = (longitudeRef == "E") ? 1.0 : -1.0
                
                let coordinate = CLLocationCoordinate2D(
                    latitude: latitude * latSign,
                    longitude: longitude * longSign
                )
                
                var altitude: Double = 0
                if let altitudeValue = gps[kCGImagePropertyGPSAltitude as String] as? Double,
                   let altitudeRef = gps[kCGImagePropertyGPSAltitudeRef as String] as? Int {
                    // If altitudeRef is 1, altitude is below sea level
                    altitude = (altitudeRef == 1) ? -altitudeValue : altitudeValue
                }
                
                metadata.location = CLLocation(
                    coordinate: coordinate,
                    altitude: altitude,
                    horizontalAccuracy: -1,
                    verticalAccuracy: -1,
                    timestamp: Date()
                )
            }
        }
        
        // Extract image dimensions
        if let width = properties[kCGImagePropertyPixelWidth as String] as? Int {
            metadata.width = width
        }
        if let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
            metadata.height = height
        }
        
        // Apply privacy settings to sanitize metadata before returning
        let sanitizedMetadata = privacyManager.sanitizeMetadata(metadata)
        
        // Log metadata if allowed by privacy settings
        privacyManager.safelyLogMetadata(sanitizedMetadata, label: "Extracted EXIF metadata")
        
        return sanitizedMetadata
    }
    
    // MARK: - Private Methods
    
    private func extractGeoData(from json: [String: Any]) -> CLLocation? {
        // First try the geoData object
        if let geoData = json["geoData"] as? [String: Any],
           let latitude = geoData["latitude"] as? Double,
           let longitude = geoData["longitude"] as? Double {
            
            // Check if the coordinates are valid (not 0,0)
            if abs(latitude) > 0.0001 || abs(longitude) > 0.0001 {
                var altitude: Double = 0
                if let altitudeValue = geoData["altitude"] as? Double {
                    altitude = altitudeValue
                }
                
                return CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    altitude: altitude,
                    horizontalAccuracy: -1,
                    verticalAccuracy: -1,
                    timestamp: Date()
                )
            }
        }
        
        // Try the geoDataExif object if available
        if let geoDataExif = json["geoDataExif"] as? [String: Any],
           let latitude = geoDataExif["latitude"] as? Double,
           let longitude = geoDataExif["longitude"] as? Double {
            
            // Check if the coordinates are valid (not 0,0)
            if abs(latitude) > 0.0001 || abs(longitude) > 0.0001 {
                var altitude: Double = 0
                if let altitudeValue = geoDataExif["altitude"] as? Double {
                    altitude = altitudeValue
                }
                
                return CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    altitude: altitude,
                    horizontalAccuracy: -1,
                    verticalAccuracy: -1,
                    timestamp: Date()
                )
            }
        }
        
        return nil
    }
    
    private func extractCameraDetails(from cameraDetail: [String: Any], into metadata: inout MediaMetadata) {
        metadata.cameraMake = cameraDetail["cameraMake"] as? String
        metadata.cameraModel = cameraDetail["cameraModel"] as? String
        
        if let lens = cameraDetail["lens"] as? String {
            metadata.lensInfo = lens
        }
        
        if let aperture = cameraDetail["aperture"] as? Double {
            metadata.aperture = aperture
        }
        
        if let iso = cameraDetail["iso"] as? Int {
            metadata.iso = iso
        }
        
        if let exposureTime = cameraDetail["exposureTime"] as? Double {
            metadata.shutterSpeed = exposureTime
        }
    }
}
