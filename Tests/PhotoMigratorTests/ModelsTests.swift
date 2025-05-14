import XCTest
@testable import PhotoMigrator

final class MediaItemTests: XCTestCase {
    
    // Sample test data
    let samplePath = "/path/to/image.jpg"
    let sampleMetadataPath = "/path/to/metadata.json"
    let sampleDate = Date()
    let sampleLocation = "New York, USA"
    let sampleDescription = "Test photo description"
    let samplePeopleTags = ["Person 1", "Person 2"]
    
    func testMediaItemInitialization() {
        // Create a MediaItem
        let mediaItem = MediaItem(
            path: samplePath,
            metadataPath: sampleMetadataPath,
            dateTaken: sampleDate,
            location: sampleLocation,
            description: sampleDescription,
            peopleTags: samplePeopleTags,
            isFavorite: true,
            isMotionPhoto: false,
            isVideo: false
        )
        
        // Verify the properties
        XCTAssertEqual(mediaItem.path, samplePath)
        XCTAssertEqual(mediaItem.metadataPath, sampleMetadataPath)
        XCTAssertEqual(mediaItem.dateTaken, sampleDate)
        XCTAssertEqual(mediaItem.location, sampleLocation)
        XCTAssertEqual(mediaItem.description, sampleDescription)
        XCTAssertEqual(mediaItem.peopleTags, samplePeopleTags)
        XCTAssertTrue(mediaItem.isFavorite)
        XCTAssertFalse(mediaItem.isMotionPhoto)
        XCTAssertFalse(mediaItem.isVideo)
    }
    
    func testMediaItemDefaultValues() {
        // Create a MediaItem with minimal required properties
        let mediaItem = MediaItem(path: samplePath)
        
        // Verify default values
        XCTAssertEqual(mediaItem.path, samplePath)
        XCTAssertNil(mediaItem.metadataPath)
        XCTAssertNil(mediaItem.dateTaken)
        XCTAssertNil(mediaItem.location)
        XCTAssertNil(mediaItem.description)
        XCTAssertEqual(mediaItem.peopleTags, [])
        XCTAssertFalse(mediaItem.isFavorite)
        XCTAssertFalse(mediaItem.isMotionPhoto)
        XCTAssertFalse(mediaItem.isVideo)
    }
    
    func testMediaItemEquality() {
        // Create two MediaItems with same path
        let mediaItem1 = MediaItem(path: samplePath)
        let mediaItem2 = MediaItem(path: samplePath)
        
        // Create a MediaItem with different path
        let mediaItem3 = MediaItem(path: "/different/path.jpg")
        
        // Verify equality based on path
        XCTAssertEqual(mediaItem1, mediaItem2)
        XCTAssertNotEqual(mediaItem1, mediaItem3)
    }
    
    func testMediaItemHashValue() {
        // Create two MediaItems with same path
        let mediaItem1 = MediaItem(path: samplePath)
        let mediaItem2 = MediaItem(path: samplePath)
        
        // Verify hash values are the same
        XCTAssertEqual(mediaItem1.hashValue, mediaItem2.hashValue)
    }
    
    static var allTests = [
        ("testMediaItemInitialization", testMediaItemInitialization),
        ("testMediaItemDefaultValues", testMediaItemDefaultValues),
        ("testMediaItemEquality", testMediaItemEquality),
        ("testMediaItemHashValue", testMediaItemHashValue)
    ]
} 