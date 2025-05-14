import XCTest
@testable import PhotoMigrator

final class LivePhotoProcessorTests: XCTestCase {
    
    // Test instance
    var livePhotoProcessor: LivePhotoProcessor!
    
    override func setUp() {
        super.setUp()
        livePhotoProcessor = LivePhotoProcessor()
    }
    
    override func tearDown() {
        livePhotoProcessor = nil
        super.tearDown()
    }
    
    func testDetectLivePhotoPairs() {
        // Test files with potential Live Photo pairs
        let mediaFiles = [
            "/path/to/IMG_1234.jpg",
            "/path/to/IMG_1234.mov",
            "/path/to/IMG_5678.jpg",
            "/path/to/IMG_5678.MOV", // Test case insensitivity
            "/path/to/image_9876.jpg",
            "/path/to/video_9876.mov", // Not a match (different naming pattern)
            "/path/to/IMG_4321.jpg" // No matching video
        ]
        
        // Detect live photo pairs
        let pairs = livePhotoProcessor.detectLivePhotoPairs(in: mediaFiles)
        
        // Verify pairs
        XCTAssertEqual(pairs.count, 2) // Should find 2 pairs
        XCTAssertEqual(pairs["/path/to/IMG_1234.jpg"], "/path/to/IMG_1234.mov")
        XCTAssertEqual(pairs["/path/to/IMG_5678.jpg"], "/path/to/IMG_5678.MOV")
    }
    
    func testIsValidLivePhotoComponent() {
        // Test valid component paths
        XCTAssertTrue(livePhotoProcessor.isValidLivePhotoComponent("/path/to/IMG_1234.jpg"))
        XCTAssertTrue(livePhotoProcessor.isValidLivePhotoComponent("/path/to/IMG_1234.JPG"))
        XCTAssertTrue(livePhotoProcessor.isValidLivePhotoComponent("/path/to/IMG_1234.mov"))
        XCTAssertTrue(livePhotoProcessor.isValidLivePhotoComponent("/path/to/IMG_1234.MOV"))
        
        // Test invalid component paths
        XCTAssertFalse(livePhotoProcessor.isValidLivePhotoComponent("/path/to/image.txt"))
        XCTAssertFalse(livePhotoProcessor.isValidLivePhotoComponent("/path/to/video.avi"))
    }
    
    func testExtractBaseNameFromPath() {
        // Test various paths
        XCTAssertEqual(livePhotoProcessor.extractBaseNameFromPath("/path/to/IMG_1234.jpg"), "IMG_1234")
        XCTAssertEqual(livePhotoProcessor.extractBaseNameFromPath("/path/to/file with spaces.jpg"), "file with spaces")
        XCTAssertEqual(livePhotoProcessor.extractBaseNameFromPath("/path/to/image.with.dots.jpg"), "image.with.dots")
        XCTAssertEqual(livePhotoProcessor.extractBaseNameFromPath("IMG_1234.mov"), "IMG_1234")
    }
    
    func testCreateLivePhotoFromComponents() {
        // Create test media items
        let imageItem = MediaItem(
            path: "/path/to/IMG_1234.jpg",
            metadataPath: "/path/to/IMG_1234.jpg.json",
            dateTaken: Date(),
            location: "New York",
            description: "Test image",
            peopleTags: ["Person 1"],
            isFavorite: true,
            isMotionPhoto: false,
            isVideo: false
        )
        
        let videoItem = MediaItem(
            path: "/path/to/IMG_1234.mov",
            metadataPath: nil,
            dateTaken: nil,
            location: nil,
            description: nil,
            peopleTags: [],
            isFavorite: false,
            isMotionPhoto: false,
            isVideo: true
        )
        
        // Create live photo
        let livePhoto = livePhotoProcessor.createLivePhotoFromComponents(imageItem: imageItem, videoItem: videoItem)
        
        // Verify properties from both components are merged correctly
        XCTAssertEqual(livePhoto.path, imageItem.path)
        XCTAssertEqual(livePhoto.metadataPath, imageItem.metadataPath)
        XCTAssertEqual(livePhoto.dateTaken, imageItem.dateTaken)
        XCTAssertEqual(livePhoto.location, imageItem.location)
        XCTAssertEqual(livePhoto.description, imageItem.description)
        XCTAssertEqual(livePhoto.peopleTags, imageItem.peopleTags)
        XCTAssertEqual(livePhoto.isFavorite, imageItem.isFavorite)
        XCTAssertTrue(livePhoto.isMotionPhoto)
        XCTAssertEqual(livePhoto.motionVideoPath, videoItem.path)
    }
    
    func testShouldReplaceExistingPair() {
        // Test timestamps for comparison
        let olderDate = Date(timeIntervalSince1970: 1600000000)
        let newerDate = Date(timeIntervalSince1970: 1700000000)
        
        // Create test paths
        let existingVideoPath = "/path/to/IMG_1234.mov"
        let newVideoPath = "/path/to/IMG_1234_2.mov"
        
        // Get modification dates (mock since we can't easily set file modification dates in tests)
        let getModificationDate: (String) -> Date? = { path in
            if path == existingVideoPath {
                return olderDate
            } else if path == newVideoPath {
                return newerDate
            }
            return nil
        }
        
        // Test with newer video (should replace)
        XCTAssertTrue(livePhotoProcessor.shouldReplaceExistingPair(existingVideoPath: existingVideoPath, newVideoPath: newVideoPath, getModificationDate: getModificationDate))
        
        // Test with older video (should not replace)
        XCTAssertFalse(livePhotoProcessor.shouldReplaceExistingPair(existingVideoPath: newVideoPath, newVideoPath: existingVideoPath, getModificationDate: getModificationDate))
        
        // Test with missing dates (should default to false)
        let getNilDate: (String) -> Date? = { _ in return nil }
        XCTAssertFalse(livePhotoProcessor.shouldReplaceExistingPair(existingVideoPath: existingVideoPath, newVideoPath: newVideoPath, getModificationDate: getNilDate))
    }
    
    static var allTests = [
        ("testDetectLivePhotoPairs", testDetectLivePhotoPairs),
        ("testIsValidLivePhotoComponent", testIsValidLivePhotoComponent),
        ("testExtractBaseNameFromPath", testExtractBaseNameFromPath),
        ("testCreateLivePhotoFromComponents", testCreateLivePhotoFromComponents),
        ("testShouldReplaceExistingPair", testShouldReplaceExistingPair)
    ]
} 