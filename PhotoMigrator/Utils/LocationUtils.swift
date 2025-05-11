import Foundation
import CoreLocation
import MapKit

struct LocationUtils {
    /// Converts latitude/longitude from Google JSON to CLLocation
    static func locationFromCoordinates(latitude: Double, longitude: Double, altitude: Double = 0) -> CLLocation? {
        // Validate coordinates
        guard abs(latitude) <= 90, abs(longitude) <= 180 else {
            return nil
        }
        
        // Reject obvious invalid coordinates (0,0 is in the ocean)
        if abs(latitude) < 0.0001 && abs(longitude) < 0.0001 {
            return nil
        }
        
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: -1,
            verticalAccuracy: -1,
            timestamp: Date()
        )
    }
    
    /// Attempts to reverse geocode a location to get place name
    static func getPlaceName(for location: CLLocation) async -> String? {
        return await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                guard error == nil, let placemark = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Build a location name based on available components
                var components: [String] = []
                
                if let name = placemark.name, !name.isEmpty {
                    components.append(name)
                }
                
                if let locality = placemark.locality, !locality.isEmpty {
                    components.append(locality)
                }
                
                if let country = placemark.country, !country.isEmpty {
                    if components.isEmpty || !components.contains(country) {
                        components.append(country)
                    }
                }
                
                if components.isEmpty {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: components.joined(separator: ", "))
                }
            }
        }
    }
    
    /// Takes a Google Maps URL and extracts coordinates
    static func extractCoordinatesFromGoogleMapsURL(_ urlString: String) -> CLLocationCoordinate2D? {
        // Example URL: https://www.google.com/maps?q=37.7749,-122.4194
        // or https://www.google.com/maps/@37.7749,-122.4194,15z
        
        // Extract lat,lng pattern
        let patterns = [
            "q=(-?\\d+\\.\\d+),(-?\\d+\\.\\d+)",
            "@(-?\\d+\\.\\d+),(-?\\d+\\.\\d+)"
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            
            let nsString = urlString as NSString
            let matches = regex.matches(in: urlString, range: NSRange(location: 0, length: nsString.length))
            
            if let match = matches.first, match.numberOfRanges == 3 {
                let latRange = match.range(at: 1)
                let lngRange = match.range(at: 2)
                
                let latString = nsString.substring(with: latRange)
                let lngString = nsString.substring(with: lngRange)
                
                if let lat = Double(latString), let lng = Double(lngString) {
                    return CLLocationCoordinate2D(latitude: lat, longitude: lng)
                }
            }
        }
        
        return nil
    }
}
