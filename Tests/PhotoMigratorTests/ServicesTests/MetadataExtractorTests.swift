import XCTest
@testable import PhotoMigrator

final class MetadataExtractorTests: XCTestCase {
    
    // Test instance
    var metadataExtractor: MetadataExtractor!
    
    // Test data
    let testMediaPath = "/path/to/photo.jpg"
    let testMetadataPath = "/path/to/photo.jpg.json"
    
    // Sample JSON metadata
    let sampleJSON = """
    {
        "title": "Test Photo",
        "description": "A test photo description",
        "photoTakenTime": {
            "timestamp": "1647352245",
            "formatted": "Mar 15, 2022, 2:30:45 PM UTC"
        },
        "geoData": {
            "latitude": 40.7128,
            "longitude": -74.0060,
            "altitude": 10.0,
            "latitudeSpan": 0.01,
            "longitudeSpan": 0.01
        },
        "people": [
            {"name": "Person 1"},
            {"name": "Person 2"}
        ],
        "favorite": true
    }
    """
    
    override func setUp() {
        super.setUp()
        metadataExtractor = MetadataExtractor()
    }
    
    override func tearDown() {
        metadataExtractor = nil
        super.tearDown()
    }
    
    func testExtractMetadataFromJSON() {
        // Create test data
        let jsonData = sampleJSON.data(using: .utf8)!
        
        // Extract metadata
        let metadata = metadataExtractor.extractMetadataFromJSON(jsonData, for: testMediaPath)
        
        // Verify metadata was extracted correctly
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata?.description, "A test photo description")
        XCTAssertNotNil(metadata?.dateTaken)
        XCTAssertEqual(metadata?.location, "40.7128, -74.0060")
        XCTAssertEqual(metadata?.peopleTags, ["Person 1", "Person 2"])
        XCTAssertTrue(metadata?.isFavorite ?? false)
    }
    
    func testExtractMetadataFromMalformedJSON() {
        // Create malformed JSON data
        let malformedJSON = """
        {
            "title": "Test Photo",
            "description": "Malformed JSON
        }
        """
        let jsonData = malformedJSON.data(using: .utf8)!
        
        // Extract metadata (should fail gracefully)
        let metadata = metadataExtractor.extractMetadataFromJSON(jsonData, for: testMediaPath)
        
        // Verify nil is returned for malformed JSON
        XCTAssertNil(metadata)
    }
    
    func testExtractMetadataWithMissingFields() {
        // Create JSON with missing fields
        let incompleteJSON = """
        {
            "title": "Test Photo"
        }
        """
        let jsonData = incompleteJSON.data(using: .utf8)!
        
        // Extract metadata (should handle missing fields)
        let metadata = metadataExtractor.extractMetadataFromJSON(jsonData, for: testMediaPath)
        
        // Verify metadata was extracted with default values for missing fields
        XCTAssertNotNil(metadata)
        XCTAssertNil(metadata?.description)
        XCTAssertNil(metadata?.dateTaken)
        XCTAssertNil(metadata?.location)
        XCTAssertEqual(metadata?.peopleTags, [])
        XCTAssertFalse(metadata?.isFavorite ?? true)
    }
    
    func testExtractPeopleTags() {
        // Create people data
        let peopleJSON = """
        [
            {"name": "Person 1"},
            {"name": "Person 2"},
            {"name": "Person 3"}
        ]
        """
        let jsonData = peopleJSON.data(using: .utf8)!
        
        // Extract people tags
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]]
            let peopleTags = metadataExtractor.extractPeopleTags(from: jsonArray)
            
            // Verify people tags were extracted correctly
            XCTAssertEqual(peopleTags.count, 3)
            XCTAssertEqual(peopleTags, ["Person 1", "Person 2", "Person 3"])
        } catch {
            XCTFail("Failed to parse test JSON: \(error)")
        }
    }
    
    static var allTests = [
        ("testExtractMetadataFromJSON", testExtractMetadataFromJSON),
        ("testExtractMetadataFromMalformedJSON", testExtractMetadataFromMalformedJSON),
        ("testExtractMetadataWithMissingFields", testExtractMetadataWithMissingFields),
        ("testExtractPeopleTags", testExtractPeopleTags)
    ]
} 