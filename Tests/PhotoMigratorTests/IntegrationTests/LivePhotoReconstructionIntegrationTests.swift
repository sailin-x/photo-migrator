import XCTest
import Photos
@testable import PhotoMigrator

final class LivePhotoReconstructionIntegrationTests: XCTestCase {
    
    // Test components
    var livePhotoProcessor: LivePhotoProcessor!
    var metadataExtractor: MetadataExtractor!
    var tempDirectory: URL!
    var testMediaDirectory: URL!
    
    // Test media items
    var photoItems: [MediaItem] = []
    var videoItems: [MediaItem] = []
    var allItems: [MediaItem] = []
    
    override func setUp() {
        super.setUp()
        
        // Create temp directory for testing
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LivePhotoTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create test media directory
        testMediaDirectory = tempDirectory.appendingPathComponent("TestMedia")
        try? FileManager.default.createDirectory(at: testMediaDirectory, withIntermediateDirectories: true)
        
        // Prepare test files
        setupTestFiles()
        
        // Initialize components
        metadataExtractor = MetadataExtractor()
        livePhotoProcessor = LivePhotoProcessor()
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        livePhotoProcessor = nil
        metadataExtractor = nil
        tempDirectory = nil
        testMediaDirectory = nil
        photoItems = []
        videoItems = []
        allItems = []
        
        super.tearDown()
    }
    
    // MARK: - Test Helpers
    
    // Create test files for live photo pairs
    private func setupTestFiles() {
        // Google Takeout pattern: IMG_12345.jpg + IMG_12345.mp4
        createLivePhotoPair(baseName: "IMG_12345", timestamp: Date())
        
        // Google Photos pattern: PXL_20220315_123456789.jpg + PXL_20220315_123456789.mp4
        createLivePhotoPair(baseName: "PXL_20220315_123456789", timestamp: Date().addingTimeInterval(-86400))
        
        // iOS pattern: IMG_1234.HEIC + IMG_1234.MOV
        createLivePhotoPair(baseName: "IMG_1234", timestamp: Date().addingTimeInterval(-172800), 
                            photoExt: "HEIC", videoExt: "MOV")
        
        // Different timestamps for testing edge cases
        let base = Date().addingTimeInterval(-259200)
        createLivePhotoPair(baseName: "IMG_5678", timestamp: base, 
                            photoTimestamp: base, videoTimestamp: base.addingTimeInterval(0.5))
        
        // Non-matching files to test filtering
        createSingleFile(name: "IMG_9999.jpg", timestamp: Date(), isVideo: false)
        createSingleFile(name: "VID_1111.mp4", timestamp: Date(), isVideo: true)
        
        // Gather all items
        photoItems.forEach { allItems.append($0) }
        videoItems.forEach { allItems.append($0) }
    }
    
    // Create a live photo pair (photo + video with matching names)
    private func createLivePhotoPair(baseName: String, timestamp: Date, 
                                     photoExt: String = "jpg", videoExt: String = "mp4",
                                     photoTimestamp: Date? = nil, videoTimestamp: Date? = nil) {
        
        // Create photo file
        let photoFileName = "\(baseName).\(photoExt)"
        let photoPath = testMediaDirectory.appendingPathComponent(photoFileName)
        let dummyPhotoData = "DUMMY_PHOTO_DATA".data(using: .utf8)!
        try? dummyPhotoData.write(to: photoPath)
        
        // Create video file
        let videoFileName = "\(baseName).\(videoExt)"
        let videoPath = testMediaDirectory.appendingPathComponent(videoFileName)
        let dummyVideoData = "DUMMY_VIDEO_DATA".data(using: .utf8)!
        try? dummyVideoData.write(to: videoPath)
        
        // Create MediaItems
        let photoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: photoPath,
            fileType: .photo,
            timestamp: photoTimestamp ?? timestamp,
            isFavorite: false
        )
        let videoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: videoPath,
            fileType: .video,
            timestamp: videoTimestamp ?? timestamp,
            isFavorite: false
        )
        
        // Add to arrays
        photoItems.append(photoItem)
        videoItems.append(videoItem)
    }
    
    // Create a single file (not part of a live photo pair)
    private func createSingleFile(name: String, timestamp: Date, isVideo: Bool) {
        let path = testMediaDirectory.appendingPathComponent(name)
        let dummyData = "DUMMY_DATA".data(using: .utf8)!
        try? dummyData.write(to: path)
        
        let mediaItem = MediaItem(
            id: UUID().uuidString,
            fileURL: path,
            fileType: isVideo ? .video : .photo,
            timestamp: timestamp,
            isFavorite: false
        )
        
        if isVideo {
            videoItems.append(mediaItem)
        } else {
            photoItems.append(mediaItem)
        }
    }
    
    // MARK: - Tests
    
    // Test live photo pair detection
    func testLivePhotoPairDetection() {
        // Run pairing algorithm
        let pairs = livePhotoProcessor.identifyLivePhotoPairs(in: allItems)
        
        // We should have 4 pairs
        XCTAssertEqual(pairs.count, 4, "Should detect 4 live photo pairs")
        
        // Verify the matching is correct
        for pair in pairs {
            XCTAssertNotNil(pair.photoItem, "Each pair should have a photo item")
            XCTAssertNotNil(pair.videoItem, "Each pair should have a video item")
            
            // Filenames should match (excluding extension)
            let photoBaseName = pair.photoItem.fileURL.deletingPathExtension().lastPathComponent
            let videoBaseName = pair.videoItem.fileURL.deletingPathExtension().lastPathComponent
            XCTAssertEqual(photoBaseName, videoBaseName, "Base filename should match for photo and video")
            
            // File types should be correct
            XCTAssertEqual(pair.photoItem.fileType, .photo, "Photo item should be a photo")
            XCTAssertEqual(pair.videoItem.fileType, .video, "Video item should be a video")
        }
    }
    
    // Test pair detection for different naming patterns
    func testDifferentNamingPatterns() {
        // Run pairing algorithm
        let pairs = livePhotoProcessor.identifyLivePhotoPairs(in: allItems)
        
        // Check specific naming patterns
        let googleTakeoutPair = pairs.first(where: { 
            $0.photoItem.fileURL.lastPathComponent.hasPrefix("IMG_12345") 
        })
        XCTAssertNotNil(googleTakeoutPair, "Should detect Google Takeout pattern (IMG_12345)")
        
        let googlePhotosPair = pairs.first(where: { 
            $0.photoItem.fileURL.lastPathComponent.hasPrefix("PXL_") 
        })
        XCTAssertNotNil(googlePhotosPair, "Should detect Google Photos pattern (PXL_)")
        
        let iOSPair = pairs.first(where: { 
            $0.photoItem.fileURL.lastPathComponent.hasSuffix(".HEIC") 
        })
        XCTAssertNotNil(iOSPair, "Should detect iOS pattern (HEIC+MOV)")
    }
    
    // Test timestamp-based matching for edge cases
    func testTimestampBasedMatching() {
        // Create items with same base name but different timestamps
        let baseTime = Date()
        let photoTime = baseTime
        let videoTime = baseTime.addingTimeInterval(3600) // 1 hour difference
        
        let photoPath = testMediaDirectory.appendingPathComponent("TIMESTAMP_TEST.jpg")
        let videoPath = testMediaDirectory.appendingPathComponent("TIMESTAMP_TEST.mp4")
        
        try? "DUMMY_PHOTO".data(using: .utf8)?.write(to: photoPath)
        try? "DUMMY_VIDEO".data(using: .utf8)?.write(to: videoPath)
        
        let photoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: photoPath,
            fileType: .photo,
            timestamp: photoTime,
            isFavorite: false
        )
        
        let videoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: videoPath,
            fileType: .video,
            timestamp: videoTime,
            isFavorite: false
        )
        
        // Add test items
        var testItems = allItems
        testItems.append(photoItem)
        testItems.append(videoItem)
        
        // Configure for more permissive timestamp matching
        livePhotoProcessor.maximumTimestampDifference = 7200 // 2 hours
        
        // Run pairing algorithm
        let pairs = livePhotoProcessor.identifyLivePhotoPairs(in: testItems)
        
        // Check if our test pair was detected
        let timestampPair = pairs.first(where: { 
            $0.photoItem.fileURL.lastPathComponent == "TIMESTAMP_TEST.jpg" 
        })
        XCTAssertNotNil(timestampPair, "Should detect pair with 1 hour timestamp difference")
        
        // Now make the timestamp window too small
        livePhotoProcessor.maximumTimestampDifference = 60 // 1 minute
        
        // Run pairing algorithm again
        let strictPairs = livePhotoProcessor.identifyLivePhotoPairs(in: testItems)
        
        // Check if our test pair was NOT detected with stricter settings
        let missingPair = strictPairs.first(where: { 
            $0.photoItem.fileURL.lastPathComponent == "TIMESTAMP_TEST.jpg" 
        })
        XCTAssertNil(missingPair, "Should not detect pair with 1 hour difference when max is 1 minute")
    }
    
    // Test error handling for invalid or missing files
    func testErrorHandlingForInvalidFiles() {
        // Create an invalid photo path
        let invalidPhotoPath = testMediaDirectory.appendingPathComponent("missing.jpg")
        
        // Create a valid video path
        let validVideoPath = testMediaDirectory.appendingPathComponent("valid.mp4")
        try? "DUMMY_VIDEO".data(using: .utf8)?.write(to: validVideoPath)
        
        // Create items
        let invalidPhotoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: invalidPhotoPath,
            fileType: .photo,
            timestamp: Date(),
            isFavorite: false
        )
        
        let validVideoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: validVideoPath,
            fileType: .video,
            timestamp: Date(),
            isFavorite: false
        )
        
        // Create a forced pair (even though photo doesn't exist)
        let invalidPair = LivePhotoPair(photoItem: invalidPhotoItem, videoItem: validVideoItem)
        
        // Attempt to reconstruct the live photo
        Task {
            do {
                let _ = try await livePhotoProcessor.createLivePhoto(from: invalidPair)
                XCTFail("Should throw an error for missing file")
            } catch {
                // Expecting an error, test passes
                XCTAssertNotNil(error, "Should throw error for missing file")
                if let migrationError = error as? MigrationError {
                    switch migrationError {
                    case .fileAccessError:
                        // Expected error type
                        break
                    default:
                        XCTFail("Expected fileAccessError but got \(migrationError)")
                    }
                }
            }
        }
    }
    
    // Test end-to-end Live Photo reconstruction
    func testEndToEndReconstruction() async {
        // Get pairs
        let pairs = livePhotoProcessor.identifyLivePhotoPairs(in: allItems)
        XCTAssertFalse(pairs.isEmpty, "Should find live photo pairs")
        
        let testPair = pairs.first!
        
        // Create output directory
        let outputDir = tempDirectory.appendingPathComponent("OutputLivePhotos")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        do {
            // Attempt to create live photo
            let result = try await livePhotoProcessor.createLivePhoto(
                from: testPair,
                outputDirectory: outputDir
            )
            
            // Verify result
            XCTAssertNotNil(result.livePhotoURL, "Should produce a live photo URL")
            XCTAssertTrue(FileManager.default.fileExists(atPath: result.livePhotoURL.path), 
                         "Live photo file should exist")
            XCTAssertNotNil(result.originalPair, "Should include original pair reference")
            XCTAssertEqual(result.originalPair.photoItem.id, testPair.photoItem.id,
                          "Should reference original photo item")
            XCTAssertEqual(result.originalPair.videoItem.id, testPair.videoItem.id,
                          "Should reference original video item")
        } catch {
            XCTFail("Live photo reconstruction failed with error: \(error)")
        }
    }
    
    // Test batch processing of multiple live photos
    func testBatchLivePhotoProcessing() async {
        // Get pairs
        let pairs = livePhotoProcessor.identifyLivePhotoPairs(in: allItems)
        
        // Create output directory
        let outputDir = tempDirectory.appendingPathComponent("BatchOutput")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        do {
            // Process all pairs
            let results = try await livePhotoProcessor.processLivePhotos(
                pairs: pairs,
                outputDirectory: outputDir
            )
            
            // Verify results
            XCTAssertEqual(results.count, pairs.count, "Should process all pairs")
            XCTAssertEqual(results.filter { $0.success }.count, pairs.count, 
                          "All pairs should be processed successfully")
            
            // Verify files were created
            for result in results where result.success {
                XCTAssertTrue(FileManager.default.fileExists(atPath: result.livePhotoURL?.path ?? ""),
                             "Live photo file should exist")
            }
        } catch {
            XCTFail("Batch processing failed with error: \(error)")
        }
    }
    
    // Test Samsung Motion Photos format
    func testSamsungMotionPhotos() {
        // Create Samsung-style motion photo pair
        let baseTime = Date()
        let photoPath = testMediaDirectory.appendingPathComponent("SAMSUNG_20220315_123456.jpg")
        let videoPath = testMediaDirectory.appendingPathComponent("SAMSUNG_20220315_123456.mp4")
        
        try? "DUMMY_SAMSUNG_PHOTO".data(using: .utf8)?.write(to: photoPath)
        try? "DUMMY_SAMSUNG_VIDEO".data(using: .utf8)?.write(to: videoPath)
        
        let photoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: photoPath,
            fileType: .photo,
            timestamp: baseTime,
            isFavorite: false
        )
        
        let videoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: videoPath,
            fileType: .video,
            timestamp: baseTime,
            isFavorite: false
        )
        
        // Add test items
        var testItems = allItems
        testItems.append(photoItem)
        testItems.append(videoItem)
        
        // Run pairing algorithm
        let pairs = livePhotoProcessor.identifyLivePhotoPairs(in: testItems)
        
        // Check if our Samsung test pair was detected
        let samsungPair = pairs.first(where: { 
            $0.photoItem.fileURL.lastPathComponent.hasPrefix("SAMSUNG_") 
        })
        XCTAssertNotNil(samsungPair, "Should detect Samsung-style motion photo pair")
    }
    
    // Test Google Motion Photos format (.MP files)
    func testGoogleMotionPhotos() async {
        // Create Google-style motion photo pair
        let baseTime = Date()
        let photoPath = testMediaDirectory.appendingPathComponent("PXL_20220601_123456.jpg")
        let mpPath = testMediaDirectory.appendingPathComponent("PXL_20220601_123456.mp")
        
        try? "DUMMY_GOOGLE_PHOTO".data(using: .utf8)?.write(to: photoPath)
        try? "DUMMY_GOOGLE_MP".data(using: .utf8)?.write(to: mpPath)
        
        let photoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: photoPath,
            fileType: .photo,
            timestamp: baseTime,
            isFavorite: false
        )
        
        let videoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: mpPath,
            fileType: .video,
            timestamp: baseTime,
            isFavorite: false
        )
        
        // Add test items
        var testItems = allItems
        testItems.append(photoItem)
        testItems.append(videoItem)
        
        // Process the items to identify Live Photos
        let processedItems = try? await livePhotoProcessor.processLivePhotoComponents(mediaItems: testItems)
        
        XCTAssertNotNil(processedItems, "Should process items without errors")
        
        // Check that the MP file was recognized as a motion component
        let mpItem = processedItems?.first(where: { $0.fileURL.lastPathComponent.hasSuffix(".mp") })
        XCTAssertNotNil(mpItem, "Should find the MP item in processed results")
        XCTAssertTrue(mpItem?.isLivePhotoMotionComponent ?? false, "MP file should be marked as a Live Photo motion component")
        
        // Check that a Live Photo was created
        let livePhotoItem = processedItems?.first(where: { $0.fileType == .livePhoto })
        XCTAssertNotNil(livePhotoItem, "Should create a Live Photo item from Google motion photo components")
    }
    
    // Test metadata preservation during Live Photo reconstruction
    func testMetadataPreservation() async {
        // Create a pair with rich metadata
        let baseTime = Date()
        let latitude = 37.7749
        let longitude = -122.4194
        let photoPath = testMediaDirectory.appendingPathComponent("META_TEST.jpg")
        let videoPath = testMediaDirectory.appendingPathComponent("META_TEST.mp4")
        
        try? "DUMMY_PHOTO_WITH_META".data(using: .utf8)?.write(to: photoPath)
        try? "DUMMY_VIDEO_WITH_META".data(using: .utf8)?.write(to: videoPath)
        
        let photoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: photoPath,
            fileType: .photo,
            timestamp: baseTime,
            latitude: latitude,
            longitude: longitude,
            isFavorite: true
        )
        
        let videoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: videoPath,
            fileType: .video,
            timestamp: baseTime,
            isFavorite: false
        )
        
        // Create a pair
        let pair = LivePhotoPair(photoItem: photoItem, videoItem: videoItem)
        
        // Create output directory
        let outputDir = tempDirectory.appendingPathComponent("MetadataTest")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        do {
            // Create the Live Photo
            let result = try await livePhotoProcessor.createLivePhoto(from: pair, outputDirectory: outputDir)
            
            // Verify result
            XCTAssertTrue(result.success, "Should successfully create Live Photo")
            XCTAssertNotNil(result.livePhotoURL, "Should have a valid output URL")
            
            // Verify original metadata was preserved in the result
            XCTAssertEqual(result.originalPair.photoItem.latitude, latitude, "Latitude should be preserved")
            XCTAssertEqual(result.originalPair.photoItem.longitude, longitude, "Longitude should be preserved")
            XCTAssertEqual(result.originalPair.isFavorite, true, "Favorite status should be preserved")
            
            // Note: Full verification of metadata in the actual asset would require accessing PHAsset
            // But that's beyond the scope of an integration test without PhotoKit mocking
        } catch {
            XCTFail("Failed to create Live Photo: \(error)")
        }
    }
    
    // Test error recovery when some Live Photos fail
    func testErrorRecovery() async {
        // Create a mix of valid and invalid pairs
        let validPhotoPath = testMediaDirectory.appendingPathComponent("valid1.jpg")
        let validVideoPath = testMediaDirectory.appendingPathComponent("valid1.mp4")
        let invalidPhotoPath = testMediaDirectory.appendingPathComponent("invalid1.jpg") // Won't be created
        let validVideo2Path = testMediaDirectory.appendingPathComponent("invalid1.mp4")
        
        // Create only the valid files
        try? "VALID_PHOTO".data(using: .utf8)?.write(to: validPhotoPath)
        try? "VALID_VIDEO".data(using: .utf8)?.write(to: validVideoPath)
        try? "VALID_VIDEO_2".data(using: .utf8)?.write(to: validVideo2Path)
        
        // Create media items
        let validPhotoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: validPhotoPath,
            fileType: .photo,
            timestamp: Date(),
            isFavorite: false
        )
        
        let validVideoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: validVideoPath,
            fileType: .video,
            timestamp: Date(),
            isFavorite: false
        )
        
        let invalidPhotoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: invalidPhotoPath,
            fileType: .photo,
            timestamp: Date(),
            isFavorite: false
        )
        
        let validVideo2Item = MediaItem(
            id: UUID().uuidString,
            fileURL: validVideo2Path,
            fileType: .video,
            timestamp: Date(),
            isFavorite: false
        )
        
        // Create pairs - one valid, one invalid
        let validPair = LivePhotoPair(photoItem: validPhotoItem, videoItem: validVideoItem)
        let invalidPair = LivePhotoPair(photoItem: invalidPhotoItem, videoItem: validVideo2Item)
        let pairs = [validPair, invalidPair]
        
        // Create output directory
        let outputDir = tempDirectory.appendingPathComponent("ErrorRecoveryTest")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        do {
            // Process all pairs
            let results = try await livePhotoProcessor.processLivePhotos(pairs: pairs, outputDirectory: outputDir)
            
            // Verify results - should have processed both pairs but only one succeeds
            XCTAssertEqual(results.count, 2, "Should have processed both pairs")
            XCTAssertEqual(results.filter { $0.success }.count, 1, "Only one pair should succeed")
            XCTAssertEqual(results.filter { !$0.success }.count, 1, "One pair should fail")
            
            // The valid pair should have succeeded
            let validResult = results.first { $0.originalPair.photoItem.id == validPhotoItem.id }
            XCTAssertNotNil(validResult, "Should find the valid pair's result")
            XCTAssertTrue(validResult?.success ?? false, "Valid pair should be processed successfully")
            
            // The invalid pair should have failed
            let invalidResult = results.first { $0.originalPair.photoItem.id == invalidPhotoItem.id }
            XCTAssertNotNil(invalidResult, "Should find the invalid pair's result")
            XCTAssertFalse(invalidResult?.success ?? true, "Invalid pair should fail processing")
            XCTAssertNotNil(invalidResult?.error, "Invalid pair should have an error")
        } catch {
            XCTFail("Processing should not throw even with invalid pairs: \(error)")
        }
    }
    
    // Test handling large files (simulation)
    func testLargeFileHandling() async {
        // We'll simulate large files by creating metadata that indicates a large file
        let photoPath = testMediaDirectory.appendingPathComponent("large_photo.jpg")
        let videoPath = testMediaDirectory.appendingPathComponent("large_video.mp4")
        
        // Create the files
        try? "LARGE_PHOTO_CONTENT".data(using: .utf8)?.write(to: photoPath)
        try? "LARGE_VIDEO_CONTENT".data(using: .utf8)?.write(to: videoPath)
        
        // Pretend these are large files by giving them specific properties we can check
        let photoItem = MediaItem(
            id: "large-photo-test",
            fileURL: photoPath,
            fileType: .photo,
            timestamp: Date(),
            isFavorite: false
        )
        
        let videoItem = MediaItem(
            id: "large-video-test",
            fileURL: videoPath,
            fileType: .video,
            timestamp: Date(),
            isFavorite: false
        )
        
        // Create a pair
        let pair = LivePhotoPair(photoItem: photoItem, videoItem: videoItem)
        
        // Create output directory
        let outputDir = tempDirectory.appendingPathComponent("LargeFileTest")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        do {
            // Process the pair
            let result = try await livePhotoProcessor.createLivePhoto(from: pair, outputDirectory: outputDir)
            
            // Verify result
            XCTAssertTrue(result.success, "Should successfully process large file pair")
            XCTAssertNotNil(result.livePhotoURL, "Should have a valid output URL")
        } catch {
            XCTFail("Failed to process large files: \(error)")
        }
    }
    
    static var allTests = [
        ("testLivePhotoPairDetection", testLivePhotoPairDetection),
        ("testDifferentNamingPatterns", testDifferentNamingPatterns),
        ("testTimestampBasedMatching", testTimestampBasedMatching),
        ("testErrorHandlingForInvalidFiles", testErrorHandlingForInvalidFiles),
        ("testEndToEndReconstruction", testEndToEndReconstruction),
        ("testBatchLivePhotoProcessing", testBatchLivePhotoProcessing),
        ("testSamsungMotionPhotos", testSamsungMotionPhotos),
        ("testGoogleMotionPhotos", testGoogleMotionPhotos),
        ("testMetadataPreservation", testMetadataPreservation),
        ("testErrorRecovery", testErrorRecovery),
        ("testLargeFileHandling", testLargeFileHandling)
    ]
} 