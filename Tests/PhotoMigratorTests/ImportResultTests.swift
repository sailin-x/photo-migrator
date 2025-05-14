import XCTest
@testable import PhotoMigrator

final class ImportResultTests: XCTestCase {
    
    // Sample errors for testing
    enum TestError: Error {
        case fileNotFound
        case permissionDenied
    }
    
    func testSuccessfulImport() {
        // Create a sample media item
        let mediaItem = MediaItem(path: "/path/to/image.jpg")
        
        // Create a successful import result
        let result = ImportResult(
            originalItem: mediaItem,
            assetId: "asset-123-456",
            error: nil
        )
        
        // Verify properties
        XCTAssertEqual(result.originalItem.path, mediaItem.path)
        XCTAssertEqual(result.assetId, "asset-123-456")
        XCTAssertNil(result.error)
    }
    
    func testFailedImport() {
        // Create a sample media item
        let mediaItem = MediaItem(path: "/path/to/missing-image.jpg")
        
        // Create a failed import result
        let result = ImportResult(
            originalItem: mediaItem,
            assetId: nil,
            error: TestError.fileNotFound
        )
        
        // Verify properties
        XCTAssertEqual(result.originalItem.path, mediaItem.path)
        XCTAssertNil(result.assetId)
        XCTAssertNotNil(result.error)
        
        // Verify error type
        XCTAssertTrue(result.error is TestError)
        if let error = result.error as? TestError {
            XCTAssertEqual(error, TestError.fileNotFound)
        } else {
            XCTFail("Error should be of type TestError")
        }
    }
    
    func testPermissionDeniedImport() {
        // Create a sample media item
        let mediaItem = MediaItem(path: "/path/to/protected-image.jpg")
        
        // Create a permission denied import result
        let result = ImportResult(
            originalItem: mediaItem,
            assetId: nil,
            error: TestError.permissionDenied
        )
        
        // Verify properties
        XCTAssertEqual(result.originalItem.path, mediaItem.path)
        XCTAssertNil(result.assetId)
        XCTAssertNotNil(result.error)
        
        // Verify error type
        if let error = result.error as? TestError {
            XCTAssertEqual(error, TestError.permissionDenied)
        } else {
            XCTFail("Error should be of type TestError")
        }
    }
    
    static var allTests = [
        ("testSuccessfulImport", testSuccessfulImport),
        ("testFailedImport", testFailedImport),
        ("testPermissionDeniedImport", testPermissionDeniedImport)
    ]
} 