import XCTest
@testable import PhotoMigrator

final class ArchiveProcessorTests: XCTestCase {
    
    // Test instance
    var archiveProcessor: ArchiveProcessor!
    
    // Mock dependencies
    var mockMetadataExtractor: MockMetadataExtractor!
    var mockPhotosImporter: MockPhotosImporter!
    var mockAlbumManager: MockAlbumManager!
    var mockLivePhotoProcessor: MockLivePhotoProcessor!
    
    // Test data paths
    let testArchivePath = "/tmp/test_archive"
    let testOutputPath = "/tmp/test_output"
    
    override func setUp() {
        super.setUp()
        
        // Initialize mock dependencies
        mockMetadataExtractor = MockMetadataExtractor()
        mockPhotosImporter = MockPhotosImporter()
        mockAlbumManager = MockAlbumManager()
        mockLivePhotoProcessor = MockLivePhotoProcessor()
        
        // Initialize ArchiveProcessor with mock dependencies
        archiveProcessor = ArchiveProcessor(
            metadataExtractor: mockMetadataExtractor,
            photosImporter: mockPhotosImporter,
            albumManager: mockAlbumManager,
            livePhotoProcessor: mockLivePhotoProcessor
        )
    }
    
    override func tearDown() {
        archiveProcessor = nil
        mockMetadataExtractor = nil
        mockPhotosImporter = nil
        mockAlbumManager = nil
        mockLivePhotoProcessor = nil
        super.tearDown()
    }
    
    func testValidateArchivePath() {
        // Test with valid archive path
        let tempDir = FileManager.default.temporaryDirectory
        let validPath = tempDir.path
        
        XCTAssertNoThrow(try archiveProcessor.validateArchivePath(validPath))
        
        // Test with non-existent path
        let invalidPath = "/path/that/does/not/exist"
        
        XCTAssertThrowsError(try archiveProcessor.validateArchivePath(invalidPath)) { error in
            XCTAssertTrue(error is MigrationError)
            if let migrationError = error as? MigrationError {
                XCTAssertTrue(migrationError.isArchiveError)
            }
        }
    }
    
    func testDetectArchiveType() {
        // Test directory type
        let directoryPath = FileManager.default.temporaryDirectory.path
        let directoryType = archiveProcessor.detectArchiveType(directoryPath)
        XCTAssertEqual(directoryType, .directory)
        
        // Test zip type (mock since we can't create a real zip file easily in tests)
        let zipPath = "/path/to/archive.zip"
        // We need to mock this functionality or test with a real zip file
    }
    
    func testIndexMediaFiles() {
        // Create a temporary directory with test files
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test_media_files", isDirectory: true)
        
        do {
            // Create test directory if it doesn't exist
            try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
            
            // Create test image files
            let imagePath1 = testDir.appendingPathComponent("image1.jpg")
            let imagePath2 = testDir.appendingPathComponent("image2.jpg")
            let videoPath = testDir.appendingPathComponent("video.mp4")
            let metadataPath = testDir.appendingPathComponent("image1.jpg.json")
            
            // Write some dummy data to files
            try "test image data".write(to: imagePath1, atomically: true, encoding: .utf8)
            try "test image data".write(to: imagePath2, atomically: true, encoding: .utf8)
            try "test video data".write(to: videoPath, atomically: true, encoding: .utf8)
            try "{\"title\": \"test\"}}".write(to: metadataPath, atomically: true, encoding: .utf8)
            
            // Test indexing
            let mediaFiles = archiveProcessor.indexMediaFiles(in: testDir.path)
            
            // Verify all media files were found
            XCTAssertGreaterThanOrEqual(mediaFiles.count, 3) // At least our 3 test files
            
            // Cleanup
            try FileManager.default.removeItem(at: testDir)
        } catch {
            XCTFail("Failed to create test files: \(error)")
        }
    }
    
    func testMatchMetadataFiles() {
        // Test files
        let mediaFiles = [
            "/path/to/image1.jpg",
            "/path/to/image2.jpg",
            "/path/to/video.mp4"
        ]
        
        let metadataFiles = [
            "/path/to/image1.jpg.json",
            "/path/to/image2.jpg.json",
            "/path/to/other.json"
        ]
        
        // Match metadata files
        let matches = archiveProcessor.matchMetadataFiles(mediaFiles: mediaFiles, metadataFiles: metadataFiles)
        
        // Verify matches
        XCTAssertEqual(matches.count, 2) // Should find 2 matches
        XCTAssertEqual(matches["/path/to/image1.jpg"], "/path/to/image1.jpg.json")
        XCTAssertEqual(matches["/path/to/image2.jpg"], "/path/to/image2.jpg.json")
    }
    
    func testDetectLivePhotoPairs() {
        // Test files
        let mediaFiles = [
            "/path/to/IMG_1234.jpg",
            "/path/to/IMG_1234.mov",
            "/path/to/IMG_5678.jpg",
            "/path/to/unrelated.mov"
        ]
        
        // Configure mock live photo processor
        mockLivePhotoProcessor.livePhotoPairsToReturn = [
            "/path/to/IMG_1234.jpg": "/path/to/IMG_1234.mov"
        ]
        
        // Detect live photo pairs
        let pairs = archiveProcessor.detectLivePhotoPairs(mediaFiles: mediaFiles)
        
        // Verify pairs
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs["/path/to/IMG_1234.jpg"], "/path/to/IMG_1234.mov")
    }
    
    // Mock implementations of dependencies
    
    class MockMetadataExtractor: MetadataExtractor {
        var metadataToReturn: MediaItem?
        
        override func extractMetadata(from metadataPath: String, for mediaPath: String) -> MediaItem? {
            return metadataToReturn ?? MediaItem(path: mediaPath, metadataPath: metadataPath)
        }
    }
    
    class MockPhotosImporter: PhotosImporter {
        var importResultToReturn: ImportResult = .success
        
        override func importMedia(_ mediaItem: MediaItem) -> ImportResult {
            return importResultToReturn
        }
    }
    
    class MockAlbumManager: AlbumManager {
        var albumCreationSuccess: Bool = true
        
        override func createAlbum(named name: String, with mediaItems: [MediaItem]) -> Bool {
            return albumCreationSuccess
        }
    }
    
    class MockLivePhotoProcessor: LivePhotoProcessor {
        var livePhotoPairsToReturn: [String: String] = [:]
        
        override func detectLivePhotoPairs(in mediaFiles: [String]) -> [String: String] {
            return livePhotoPairsToReturn
        }
    }
    
    static var allTests = [
        ("testValidateArchivePath", testValidateArchivePath),
        ("testDetectArchiveType", testDetectArchiveType),
        ("testIndexMediaFiles", testIndexMediaFiles),
        ("testMatchMetadataFiles", testMatchMetadataFiles),
        ("testDetectLivePhotoPairs", testDetectLivePhotoPairs)
    ]
} 