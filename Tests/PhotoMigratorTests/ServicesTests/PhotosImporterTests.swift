import XCTest
import Photos
import CoreLocation
@testable import PhotoMigrator

// Mock delegate for testing import progress and completion
class MockPhotosImportDelegate: PhotosImportDelegate {
    var progressUpdates: [ImportProgress] = []
    var importResults: [ImportResult] = []
    var lastItem: MediaItem?
    
    func importProgress(updated: ImportProgress, for item: MediaItem) {
        progressUpdates.append(updated)
        lastItem = item
    }
    
    func importCompleted(result: ImportResult) {
        importResults.append(result)
    }
    
    func reset() {
        progressUpdates = []
        importResults = []
        lastItem = nil
    }
}

final class PhotosImporterTests: XCTestCase {
    
    var importer: PhotosImporter!
    var mockDelegate: MockPhotosImportDelegate!
    
    // Temporary URL for test files
    var tempFileURL: URL!
    
    override func setUp() {
        super.setUp()
        importer = PhotosImporter()
        mockDelegate = MockPhotosImportDelegate()
        importer.delegate = mockDelegate
        
        // Create a temporary file for testing
        let tempDirectoryURL = FileManager.default.temporaryDirectory
        tempFileURL = tempDirectoryURL.appendingPathComponent("test_image.jpg")
        
        // Create an empty test file
        let testData = "test".data(using: .utf8)!
        try? testData.write(to: tempFileURL)
    }
    
    override func tearDown() {
        // Clean up temporary file
        try? FileManager.default.removeItem(at: tempFileURL)
        
        importer = nil
        mockDelegate = nil
        tempFileURL = nil
        super.tearDown()
    }
    
    // Test cancellation functionality
    func testCancelImport() {
        // Set up initial state
        importer.resetCancellation()
        
        // Cancel the import
        importer.cancelImport()
        
        // Create a test media item
        let mediaItem = MediaItem(
            id: "test_id",
            fileURL: tempFileURL,
            fileType: .photo,
            timestamp: Date(),
            isFavorite: false
        )
        
        // Try to import - this should detect cancellation
        Task {
            let result = try await importer.importSingleMedia(mediaItem)
            
            // Verify the operation was cancelled
            XCTAssertEqual(result.error as? MigrationError, MigrationError.operationCancelled)
            XCTAssertNil(result.assetId)
            XCTAssertEqual(result.originalItem.id, mediaItem.id)
        }
    }
    
    // Test handling of non-existent files
    func testImportNonExistentFile() {
        // Create a MediaItem with a non-existent file URL
        let nonExistentURL = URL(fileURLWithPath: "/path/does/not/exist.jpg")
        let mediaItem = MediaItem(
            id: "test_id",
            fileURL: nonExistentURL,
            fileType: .photo,
            timestamp: Date(),
            isFavorite: false
        )
        
        // Attempt to import the non-existent file
        Task {
            let result = try await importer.importSingleMedia(mediaItem)
            
            // Verify the operation failed with a file access error
            if case let MigrationError.fileAccessError(path) = result.error as? MigrationError {
                XCTAssertEqual(path, nonExistentURL.path)
            } else {
                XCTFail("Expected fileAccessError but got \(String(describing: result.error))")
            }
            
            XCTAssertNil(result.assetId)
            
            // Verify progress updates were sent
            XCTAssertEqual(mockDelegate.progressUpdates.count, 2)
            XCTAssertEqual(mockDelegate.progressUpdates.first?.stage, .starting)
            XCTAssertEqual(mockDelegate.progressUpdates.last?.stage, .failed)
        }
    }
    
    // Test getUTIForFile for different file types
    func testGetUTIForFile() {
        // Use reflection to access private method
        let method = unsafeBitCast(
            importer.perform(#selector(PhotosImporter.getUTIForFile(_:)), with: URL(fileURLWithPath: "test.jpg")),
            to: String?.self
        )
        
        // Verify UTI for JPEG
        XCTAssertEqual(method, "public.jpeg")
        
        // Test other file types
        let pngUTI = unsafeBitCast(
            importer.perform(#selector(PhotosImporter.getUTIForFile(_:)), with: URL(fileURLWithPath: "test.png")),
            to: String?.self
        )
        XCTAssertEqual(pngUTI, "public.png")
        
        let movUTI = unsafeBitCast(
            importer.perform(#selector(PhotosImporter.getUTIForFile(_:)), with: URL(fileURLWithPath: "test.mov")),
            to: String?.self
        )
        XCTAssertEqual(movUTI, "com.apple.quicktime-movie")
    }
    
    // Test mapping of PHPhotosError to MigrationError
    func testMapPHPhotosError() {
        // Use reflection to access private method
        let accessDeniedError = PHPhotosError(.accessUserDenied)
        let mappedError = unsafeBitCast(
            importer.perform(#selector(PhotosImporter.mapPHPhotosError(_:)), with: accessDeniedError),
            to: MigrationError.self
        )
        
        // Verify error mapping
        XCTAssertEqual(mappedError, MigrationError.photosAccessDenied)
        
        // Test other error types
        let invalidResourceError = PHPhotosError(.invalidResource)
        let mappedInvalidError = unsafeBitCast(
            importer.perform(#selector(PhotosImporter.mapPHPhotosError(_:)), with: invalidResourceError),
            to: MigrationError.self
        )
        
        if case let MigrationError.importFailed(reason) = mappedInvalidError {
            XCTAssertEqual(reason, "Invalid resource format")
        } else {
            XCTFail("Expected importFailed but got \(mappedInvalidError)")
        }
    }
    
    static var allTests = [
        ("testCancelImport", testCancelImport),
        ("testImportNonExistentFile", testImportNonExistentFile),
        ("testGetUTIForFile", testGetUTIForFile),
        ("testMapPHPhotosError", testMapPHPhotosError)
    ]
} 