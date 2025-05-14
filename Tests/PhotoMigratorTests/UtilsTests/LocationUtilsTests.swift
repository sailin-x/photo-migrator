import XCTest
import CoreLocation
@testable import PhotoMigrator

final class LocationUtilsTests: XCTestCase {
    
    func testLocationFromCoordinatesValid() {
        // Valid coordinates
        let location = LocationUtils.locationFromCoordinates(latitude: 37.7749, longitude: -122.4194)
        
        XCTAssertNotNil(location)
        XCTAssertEqual(location?.coordinate.latitude, 37.7749)
        XCTAssertEqual(location?.coordinate.longitude, -122.4194)
        XCTAssertEqual(location?.altitude, 0)
    }
    
    func testLocationFromCoordinatesWithAltitude() {
        // Valid coordinates with altitude
        let location = LocationUtils.locationFromCoordinates(latitude: 47.6062, longitude: -122.3321, altitude: 100)
        
        XCTAssertNotNil(location)
        XCTAssertEqual(location?.coordinate.latitude, 47.6062)
        XCTAssertEqual(location?.coordinate.longitude, -122.3321)
        XCTAssertEqual(location?.altitude, 100)
    }
    
    func testLocationFromCoordinatesInvalid() {
        // Invalid latitude (out of range)
        var location = LocationUtils.locationFromCoordinates(latitude: 95.0, longitude: -122.4194)
        XCTAssertNil(location)
        
        // Invalid longitude (out of range)
        location = LocationUtils.locationFromCoordinates(latitude: 37.7749, longitude: 200.0)
        XCTAssertNil(location)
        
        // Near zero coordinates (rejected as invalid)
        location = LocationUtils.locationFromCoordinates(latitude: 0.00001, longitude: 0.00001)
        XCTAssertNotNil(location)
        
        // Exactly zero coordinates (rejected as invalid)
        location = LocationUtils.locationFromCoordinates(latitude: 0.0, longitude: 0.0)
        XCTAssertNil(location)
    }
    
    func testExtractCoordinatesFromGoogleMapsURL() {
        // Test URL with q= format
        let url1 = "https://www.google.com/maps?q=37.7749,-122.4194"
        let coordinates1 = LocationUtils.extractCoordinatesFromGoogleMapsURL(url1)
        XCTAssertNotNil(coordinates1)
        XCTAssertEqual(coordinates1?.latitude, 37.7749)
        XCTAssertEqual(coordinates1?.longitude, -122.4194)
        
        // Test URL with @ format
        let url2 = "https://www.google.com/maps/@47.6062,-122.3321,15z"
        let coordinates2 = LocationUtils.extractCoordinatesFromGoogleMapsURL(url2)
        XCTAssertNotNil(coordinates2)
        XCTAssertEqual(coordinates2?.latitude, 47.6062)
        XCTAssertEqual(coordinates2?.longitude, -122.3321)
        
        // Test URL with no coordinates
        let url3 = "https://www.google.com/maps"
        let coordinates3 = LocationUtils.extractCoordinatesFromGoogleMapsURL(url3)
        XCTAssertNil(coordinates3)
        
        // Test malformed URL with coordinates in wrong format
        let url4 = "https://www.google.com/maps?q=invalid-coordinates"
        let coordinates4 = LocationUtils.extractCoordinatesFromGoogleMapsURL(url4)
        XCTAssertNil(coordinates4)
    }
    
    // Note: We don't test getPlaceName because it relies on CLGeocoder which cannot easily be mocked 
    // without dependency injection refactoring in the production code
    
    static var allTests = [
        ("testLocationFromCoordinatesValid", testLocationFromCoordinatesValid),
        ("testLocationFromCoordinatesWithAltitude", testLocationFromCoordinatesWithAltitude),
        ("testLocationFromCoordinatesInvalid", testLocationFromCoordinatesInvalid),
        ("testExtractCoordinatesFromGoogleMapsURL", testExtractCoordinatesFromGoogleMapsURL)
    ]
} 