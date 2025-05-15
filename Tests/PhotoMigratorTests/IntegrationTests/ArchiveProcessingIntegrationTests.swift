import XCTest
@testable import PhotoMigrator

final class ArchiveProcessingIntegrationTests: XCTestCase {
    
    // Test components
    var archiveProcessor: ArchiveProcessor!
    var metadataExtractor: MetadataExtractor!
    var testArchiveURL: URL!
    var tempDirectory: URL!
    
    // Setup test data directory
    static let testDataPath = "Tests/PhotoMigratorTests/TestData"
    
    override func setUp() {
        super.setUp()
        
        // Create temp directory for testing
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PhotoMigratorTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Prepare test archive folder
        testArchiveURL = tempDirectory.appendingPathComponent("TestArchive")
        prepareTestArchive()
        
        // Initialize components for testing
        metadataExtractor = MetadataExtractor()
        archiveProcessor = ArchiveProcessor(metadataExtractor: metadataExtractor)
    }
    
    override func tearDown() {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        archiveProcessor = nil
        metadataExtractor = nil
        testArchiveURL = nil
        tempDirectory = nil
        
        super.tearDown()
    }
    
    // Create test archive with sample media and metadata
    private func prepareTestArchive() {
        let fileManager = FileManager.default
        
        // Create archive directory structure
        let photosDir = testArchiveURL.appendingPathComponent("Google Photos")
        let metadataDir = testArchiveURL.appendingPathComponent("Google Photos/Metadata")
        
        try? fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        
        // Create sample image files
        for i in 1...5 {
            let imageFileName = "IMG_\(i).jpg"
            let imagePath = photosDir.appendingPathComponent(imageFileName)
            let metadata = createSampleMetadata(for: imageFileName, index: i)
            
            // Create dummy image file
            let dummyImageData = "DUMMY_IMAGE_DATA".data(using: .utf8)!
            try? dummyImageData.write(to: imagePath)
            
            // Create metadata file
            let metadataPath = metadataDir.appendingPathComponent("\(imageFileName).json")
            try? metadata.write(to: metadataPath, atomically: true, encoding: .utf8)
            
            // Create some live photos (image + video pairs)
            if i % 2 == 0 {
                let videoFileName = "IMG_\(i).mp4"
                let videoPath = photosDir.appendingPathComponent(videoFileName)
                let dummyVideoData = "DUMMY_VIDEO_DATA".data(using: .utf8)!
                try? dummyVideoData.write(to: videoPath)
                
                // Create metadata for video
                let videoMetadata = createSampleMetadata(for: videoFileName, index: i, isVideo: true)
                let videoMetadataPath = metadataDir.appendingPathComponent("\(videoFileName).json")
                try? videoMetadata.write(to: videoMetadataPath, atomically: true, encoding: .utf8)
            }
        }
        
        // Create an album structure
        let albumDataPath = testArchiveURL.appendingPathComponent("Google Photos/Albums/MyAlbum.json")
        try? fileManager.createDirectory(at: albumDataPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        let albumData = """
        {
          "title": "My Test Album",
          "description": "Album for testing",
          "access": "private",
          "date": {
            "timestamp": "1647352245",
            "formatted": "Mar 15, 2022"
          },
          "googlePhotosOrigin": {
            "albumType": "USER_ALBUM"
          },
          "media": [
            {
              "title": "IMG_1.jpg",
              "description": "Photo in album",
              "imageViews": "5",
              "creationTime": {
                "timestamp": "1647352245",
                "formatted": "Mar 15, 2022, 2:30:45 PM UTC"
              },
              "geoData": {
                "latitude": 40.7128,
                "longitude": -74.0060
              }
            },
            {
              "title": "IMG_2.jpg",
              "creationTime": {
                "timestamp": "1647362245",
                "formatted": "Mar 15, 2022, 5:10:45 PM UTC"
              }
            }
          ]
        }
        """
        try? albumData.write(to: albumDataPath, atomically: true, encoding: .utf8)
    }
    
    // Create sample metadata for a file
    private func createSampleMetadata(for fileName: String, index: Int, isVideo: Bool = false) -> String {
        let timestamp = 1647352245 + (index * 3600) // Add hours for each file
        let latitude = 40.7128 + (Double(index) * 0.01)
        let longitude = -74.0060 + (Double(index) * 0.01)
        
        return """
        {
          "title": "\(fileName)",
          "description": "Sample \(isVideo ? "video" : "photo") \(index)",
          "photoTakenTime": {
            "timestamp": "\(timestamp)",
            "formatted": "Mar 15, 2022, \(index + 1):30:45 PM UTC"
          },
          "geoData": {
            "latitude": \(latitude),
            "longitude": \(longitude),
            "altitude": \(10.0 * Double(index)),
            "latitudeSpan": 0.01,
            "longitudeSpan": 0.01
          },
          "people": [
            {"name": "Person \(index)"},
            {"name": "Person \(index + 1)"}
          ],
          "favorite": \(index % 2 == 0 ? "true" : "false")
        }
        """
    }
    
    // MARK: - Integration Tests
    
    // Test archive validation and scanning
    func testArchiveValidationAndScanning() async {
        // Validate the archive
        let isValid = await archiveProcessor.validateArchive(at: testArchiveURL)
        XCTAssertTrue(isValid, "Archive should be valid")
        
        // Scan for media items
        let mediaItems = try? await archiveProcessor.scanArchiveForMedia(at: testArchiveURL)
        XCTAssertNotNil(mediaItems, "Should successfully scan for media items")
        XCTAssertFalse(mediaItems?.isEmpty ?? true, "Should find media items in the archive")
        
        // Verify item count
        XCTAssertEqual(mediaItems?.count, 7, "Should find 7 media items (5 images + 2 videos)")
        
        // Verify media types
        let photos = mediaItems?.filter { $0.fileType == .photo }
        let videos = mediaItems?.filter { $0.fileType == .video }
        XCTAssertEqual(photos?.count, 5, "Should find 5 photos")
        XCTAssertEqual(videos?.count, 2, "Should find 2 videos")
        
        // Verify metadata was extracted
        let itemWithMetadata = mediaItems?.first
        XCTAssertNotNil(itemWithMetadata?.timestamp, "Media item should have timestamp from metadata")
        XCTAssertNotNil(itemWithMetadata?.latitude, "Media item should have latitude from metadata")
        XCTAssertNotNil(itemWithMetadata?.longitude, "Media item should have longitude from metadata")
    }
    
    // Test album extraction
    func testAlbumExtraction() async {
        let albums = try? await archiveProcessor.extractAlbums(from: testArchiveURL)
        XCTAssertNotNil(albums, "Should successfully extract albums")
        XCTAssertFalse(albums?.isEmpty ?? true, "Should find at least one album")
        
        // Verify album details
        let testAlbum = albums?.first(where: { $0.name == "My Test Album" })
        XCTAssertNotNil(testAlbum, "Should find 'My Test Album'")
        XCTAssertEqual(testAlbum?.mediaItems.count, 2, "Album should have 2 media items")
    }
    
    // Test live photo detection
    func testLivePhotoDetection() async {
        let mediaItems = try? await archiveProcessor.scanArchiveForMedia(at: testArchiveURL)
        XCTAssertNotNil(mediaItems, "Should successfully scan for media items")
        
        // Process for live photos
        let livePhotoProcessor = LivePhotoProcessor()
        let pairs = livePhotoProcessor.identifyLivePhotoPairs(in: mediaItems ?? [])
        
        // We should find at least one pair
        XCTAssertFalse(pairs.isEmpty, "Should find at least one live photo pair")
        XCTAssertEqual(pairs.count, 2, "Should find 2 live photo pairs")
        
        // Verify pair contents
        let firstPair = pairs.first
        XCTAssertNotNil(firstPair?.photoItem, "Live photo pair should have a photo item")
        XCTAssertNotNil(firstPair?.videoItem, "Live photo pair should have a video item")
        XCTAssertEqual(firstPair?.photoItem.fileType, .photo, "Photo item should have photo type")
        XCTAssertEqual(firstPair?.videoItem.fileType, .video, "Video item should have video type")
    }
    
    // Test error handling with invalid archive
    func testErrorHandlingWithInvalidArchive() async {
        // Create an empty invalid archive
        let invalidArchiveURL = tempDirectory.appendingPathComponent("InvalidArchive")
        try? FileManager.default.createDirectory(at: invalidArchiveURL, withIntermediateDirectories: true)
        
        // Try to validate the invalid archive
        let isValid = await archiveProcessor.validateArchive(at: invalidArchiveURL)
        XCTAssertFalse(isValid, "Empty archive should be invalid")
        
        // Try to scan the invalid archive (should throw or return empty result)
        do {
            let items = try await archiveProcessor.scanArchiveForMedia(at: invalidArchiveURL)
            XCTAssertTrue(items.isEmpty, "Invalid archive should return empty items array")
        } catch {
            // Expected error case is also acceptable
            XCTAssertNotNil(error, "Should throw error for invalid archive")
        }
    }
    
    // Test end-to-end archive processing workflow
    func testEndToEndArchiveProcessing() async {
        let batchProcessor = BatchProcessor()
        let monitor = MemoryMonitor()
        
        // Set up batch processor
        let settings = BatchSettings()
        let progressPublisher = BatchProgressPublisher()
        
        // Initialize batch processing workflow
        let result = await batchProcessor.processArchive(
            at: testArchiveURL,
            settings: settings,
            progressPublisher: progressPublisher,
            memoryMonitor: monitor
        )
        
        // Verify processing results
        XCTAssertNotNil(result, "Should produce processing result")
        XCTAssertGreaterThan(result.totalProcessed, 0, "Should process some items")
        XCTAssertEqual(result.errors.count, 0, "Should not have processing errors")
        
        // Verify batch creation
        XCTAssertGreaterThan(result.batchesProcessed, 0, "Should process at least one batch")
        
        // Verify media type counts
        XCTAssertGreaterThan(result.photosProcessed, 0, "Should process photos")
        XCTAssertGreaterThan(result.videosProcessed, 0, "Should process videos")
    }
    
    static var allTests = [
        ("testArchiveValidationAndScanning", testArchiveValidationAndScanning),
        ("testAlbumExtraction", testAlbumExtraction),
        ("testLivePhotoDetection", testLivePhotoDetection),
        ("testErrorHandlingWithInvalidArchive", testErrorHandlingWithInvalidArchive),
        ("testEndToEndArchiveProcessing", testEndToEndArchiveProcessing)
    ]
} 