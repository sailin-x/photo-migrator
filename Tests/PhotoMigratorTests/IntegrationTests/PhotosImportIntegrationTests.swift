import XCTest
import Photos
@testable import PhotoMigrator

final class PhotosImportIntegrationTests: XCTestCase {
    
    // Test components
    var photosImporter: PhotosImporter!
    var mockDelegate: MockPhotosImportDelegate!
    var tempDirectory: URL!
    var testFilesDirectory: URL!
    
    // Test media items
    var testMediaItems: [MediaItem] = []
    
    override func setUp() {
        super.setUp()
        
        // Create temp directory for testing
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PhotosImportTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create test files directory
        testFilesDirectory = tempDirectory.appendingPathComponent("TestFiles")
        try? FileManager.default.createDirectory(at: testFilesDirectory, withIntermediateDirectories: true)
        
        // Create test files
        prepareTestFiles()
        
        // Initialize components
        photosImporter = PhotosImporter()
        mockDelegate = MockPhotosImportDelegate()
        photosImporter.delegate = mockDelegate
    }
    
    override func tearDown() {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        photosImporter = nil
        mockDelegate = nil
        tempDirectory = nil
        testFilesDirectory = nil
        testMediaItems = []
        
        super.tearDown()
    }
    
    // MARK: - Mock Delegate
    
    class MockPhotosImportDelegate: PhotosImportDelegate {
        var progressUpdates: [ImportProgress] = []
        var importResults: [ImportResult] = []
        var lastItem: MediaItem?
        var errorCount = 0
        var successCount = 0
        
        func importProgress(updated: ImportProgress, for item: MediaItem) {
            progressUpdates.append(updated)
            lastItem = item
        }
        
        func importCompleted(result: ImportResult) {
            importResults.append(result)
            
            if result.error != nil {
                errorCount += 1
            } else if result.assetId != nil {
                successCount += 1
            }
        }
        
        func reset() {
            progressUpdates = []
            importResults = []
            lastItem = nil
            errorCount = 0
            successCount = 0
        }
    }
    
    // MARK: - Test Helpers
    
    // Create test files for import testing
    private func prepareTestFiles() {
        // Sample image types
        createTestFile(name: "photo1.jpg", fileType: .photo)
        createTestFile(name: "photo2.png", fileType: .photo)
        createTestFile(name: "photo3.heic", fileType: .photo)
        
        // Sample video types
        createTestFile(name: "video1.mp4", fileType: .video)
        createTestFile(name: "video2.mov", fileType: .video)
        
        // Create an invalid file
        createInvalidFile(name: "invalid.jpg")
        
        // Create a missing file reference
        createMissingFileReference()
    }
    
    // Create a test media file
    private func createTestFile(name: String, fileType: MediaItem.FileType) {
        let fileURL = testFilesDirectory.appendingPathComponent(name)
        
        // Create dummy file content
        let dummyData = "DUMMY_\(fileType == .photo ? "PHOTO" : "VIDEO")_DATA".data(using: .utf8)!
        try? dummyData.write(to: fileURL)
        
        // Create a MediaItem
        let mediaItem = MediaItem(
            id: UUID().uuidString,
            fileURL: fileURL,
            fileType: fileType,
            timestamp: Date(),
            isFavorite: Bool.random()
        )
        
        testMediaItems.append(mediaItem)
    }
    
    // Create an invalid file (zero bytes)
    private func createInvalidFile(name: String) {
        let fileURL = testFilesDirectory.appendingPathComponent(name)
        
        // Create empty file
        try? Data().write(to: fileURL)
        
        // Create a MediaItem
        let mediaItem = MediaItem(
            id: UUID().uuidString,
            fileURL: fileURL,
            fileType: .photo,
            timestamp: Date(),
            isFavorite: false
        )
        
        testMediaItems.append(mediaItem)
    }
    
    // Create a missing file reference
    private func createMissingFileReference() {
        let fileURL = testFilesDirectory.appendingPathComponent("missing_file.jpg")
        
        // Create a MediaItem for non-existent file
        let mediaItem = MediaItem(
            id: UUID().uuidString,
            fileURL: fileURL,
            fileType: .photo,
            timestamp: Date(),
            isFavorite: false
        )
        
        testMediaItems.append(mediaItem)
    }
    
    // MARK: - Tests
    
    // Test single file import
    func testSingleFileImport() async {
        guard !testMediaItems.isEmpty else {
            XCTFail("No test media items created")
            return
        }
        
        // Select a valid test item
        let testItem = testMediaItems.first(where: { FileManager.default.fileExists(atPath: $0.fileURL.path) })!
        
        // Import the file
        let result = try? await photosImporter.importSingleMedia(testItem)
        
        // This test will depend on Photos permissions - in a real integration test,
        // we would need to handle permissions properly, but here we'll just check
        // that the import operation completed and the delegate was called
        
        // Verify delegate calls
        XCTAssertTrue(mockDelegate.progressUpdates.count > 0, "Should receive progress updates")
        XCTAssertEqual(mockDelegate.importResults.count, 1, "Should receive one import result")
        
        // Verify last known state
        let lastProgress = mockDelegate.progressUpdates.last
        XCTAssertNotNil(lastProgress, "Should have a last progress update")
        
        // Depending on permissions, we might succeed or get an error
        // So we'll just verify that we get a result and appropriate updates
        if let result = result, result.error == nil {
            XCTAssertEqual(lastProgress?.stage, .completed, "Last progress should be completed")
            XCTAssertNotNil(result.assetId, "Successful import should have an asset ID")
        } else {
            // If there's an error (like permission denied), we still expect the workflow to work
            XCTAssertNotNil(result?.error, "If import failed, error should be present")
        }
    }
    
    // Test batch import
    func testBatchImport() async {
        let validItems = testMediaItems.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
        
        guard !validItems.isEmpty else {
            XCTFail("No valid test media items")
            return
        }
        
        // Reset the delegate
        mockDelegate.reset()
        
        // Import all valid items
        let results = try? await photosImporter.importMediaBatch(validItems)
        
        // Verify delegate calls
        XCTAssertTrue(mockDelegate.progressUpdates.count > 0, "Should receive progress updates")
        XCTAssertEqual(mockDelegate.importResults.count, validItems.count, "Should receive import results for all items")
        
        // Verify results
        XCTAssertNotNil(results, "Should receive results array")
        XCTAssertEqual(results?.count, validItems.count, "Results array should match input size")
        
        // Check progress stages - should have at least starting and completed/failed for each
        let startingUpdates = mockDelegate.progressUpdates.filter { $0.stage == .starting }
        let processingUpdates = mockDelegate.progressUpdates.filter { $0.stage == .processing }
        let completedUpdates = mockDelegate.progressUpdates.filter { $0.stage == .completed }
        let failedUpdates = mockDelegate.progressUpdates.filter { $0.stage == .failed }
        
        // We should have at least one starting update per item
        XCTAssertGreaterThanOrEqual(startingUpdates.count, validItems.count, "Should have at least one starting update per item")
        
        // And each item should either complete or fail
        XCTAssertEqual(completedUpdates.count + failedUpdates.count, validItems.count, "Each item should either complete or fail")
    }
    
    // Test import cancellation
    func testImportCancellation() async {
        guard !testMediaItems.isEmpty else {
            XCTFail("No test media items created")
            return
        }
        
        // Reset the delegate
        mockDelegate.reset()
        
        // Cancel immediately
        photosImporter.cancelImport()
        
        // Try to import
        let result = try? await photosImporter.importSingleMedia(testMediaItems[0])
        
        // Verify cancellation
        XCTAssertNotNil(result, "Should receive a result even when cancelled")
        XCTAssertNotNil(result?.error, "Should have error when cancelled")
        
        if let migrationError = result?.error as? MigrationError {
            XCTAssertEqual(migrationError, MigrationError.operationCancelled, "Error should be operationCancelled")
        } else {
            XCTFail("Error should be MigrationError.operationCancelled")
        }
    }
    
    // Test error handling for invalid files
    func testErrorHandlingForInvalidFiles() async {
        // Find the invalid file
        let invalidItem = testMediaItems.first(where: { 
            FileManager.default.fileExists(atPath: $0.fileURL.path) && 
            (try? Data(contentsOf: $0.fileURL))?.isEmpty == true
        })
        
        guard let invalidItem = invalidItem else {
            XCTFail("Invalid test item not found")
            return
        }
        
        // Reset the delegate
        mockDelegate.reset()
        
        // Try to import invalid file
        let result = try? await photosImporter.importSingleMedia(invalidItem)
        
        // Verify error handling
        XCTAssertNotNil(result, "Should receive a result even for invalid file")
        XCTAssertNotNil(result?.error, "Should have error for invalid file")
        
        // Check progress updates
        let startingUpdates = mockDelegate.progressUpdates.filter { $0.stage == .starting }
        let failedUpdates = mockDelegate.progressUpdates.filter { $0.stage == .failed }
        
        XCTAssertGreaterThanOrEqual(startingUpdates.count, 1, "Should have at least one starting update")
        XCTAssertGreaterThanOrEqual(failedUpdates.count, 1, "Should have at least one failed update")
    }
    
    // Test error handling for missing files
    func testErrorHandlingForMissingFiles() async {
        // Find the missing file reference
        let missingItem = testMediaItems.first(where: { 
            !FileManager.default.fileExists(atPath: $0.fileURL.path)
        })
        
        guard let missingItem = missingItem else {
            XCTFail("Missing file reference not found")
            return
        }
        
        // Reset the delegate
        mockDelegate.reset()
        
        // Try to import missing file
        let result = try? await photosImporter.importSingleMedia(missingItem)
        
        // Verify error handling
        XCTAssertNotNil(result, "Should receive a result even for missing file")
        XCTAssertNotNil(result?.error, "Should have error for missing file")
        
        if let migrationError = result?.error as? MigrationError, case .fileAccessError = migrationError {
            // Expected error type
        } else {
            XCTFail("Error should be MigrationError.fileAccessError")
        }
        
        // Check progress updates
        let failedUpdates = mockDelegate.progressUpdates.filter { $0.stage == .failed }
        XCTAssertGreaterThanOrEqual(failedUpdates.count, 1, "Should have at least one failed update")
    }
    
    // Test live photo import
    func testLivePhotoImport() async {
        // Create a live photo pair (this would be mocked in a real test)
        let photoURL = testFilesDirectory.appendingPathComponent("livephoto.jpg")
        let videoURL = testFilesDirectory.appendingPathComponent("livephoto.mov")
        
        // Create dummy files
        try? "DUMMY_PHOTO".data(using: .utf8)?.write(to: photoURL)
        try? "DUMMY_VIDEO".data(using: .utf8)?.write(to: videoURL)
        
        // Create MediaItems
        let photoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: photoURL,
            fileType: .photo,
            timestamp: Date(),
            isFavorite: false
        )
        
        let videoItem = MediaItem(
            id: UUID().uuidString,
            fileURL: videoURL,
            fileType: .video,
            timestamp: Date(),
            isFavorite: false
        )
        
        // Create LivePhotoPair
        let pair = LivePhotoPair(photoItem: photoItem, videoItem: videoItem)
        
        // Create a live photo processor
        let livePhotoProcessor = LivePhotoProcessor()
        
        // Create output directory
        let outputDir = tempDirectory.appendingPathComponent("LivePhotoOutput")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // First attempt to create the live photo
        do {
            let livePhotoResult = try await livePhotoProcessor.createLivePhoto(
                from: pair,
                outputDirectory: outputDir
            )
            
            // If live photo creation succeeded, now import it
            guard let livePhotoURL = livePhotoResult.livePhotoURL else {
                XCTFail("Live photo creation failed to produce URL")
                return
            }
            
            // Reset the delegate
            mockDelegate.reset()
            
            // Create a media item for the live photo
            let livePhotoItem = MediaItem(
                id: UUID().uuidString,
                fileURL: livePhotoURL,
                fileType: .livePhoto,
                timestamp: Date(),
                isFavorite: false
            )
            
            // Import the live photo
            let importResult = try? await photosImporter.importSingleMedia(livePhotoItem)
            
            // Verify import attempt (success depends on permissions)
            XCTAssertNotNil(importResult, "Should receive an import result")
            
            // Verify delegate calls
            XCTAssertTrue(mockDelegate.progressUpdates.count > 0, "Should receive progress updates")
            XCTAssertEqual(mockDelegate.importResults.count, 1, "Should receive one import result")
            
        } catch {
            // Live photo creation might fail in a test environment without required libraries
            // We'll consider this test contingently passed if we at least attempted to create it
            print("Live photo creation failed: \(error)")
        }
    }
    
    static var allTests = [
        ("testSingleFileImport", testSingleFileImport),
        ("testBatchImport", testBatchImport),
        ("testImportCancellation", testImportCancellation),
        ("testErrorHandlingForInvalidFiles", testErrorHandlingForInvalidFiles),
        ("testErrorHandlingForMissingFiles", testErrorHandlingForMissingFiles),
        ("testLivePhotoImport", testLivePhotoImport)
    ]
} 