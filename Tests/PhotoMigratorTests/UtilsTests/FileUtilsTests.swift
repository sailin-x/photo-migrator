import XCTest
@testable import PhotoMigrator

final class FileUtilsTests: XCTestCase {
    
    func testIsImageFile() {
        // Test various image file extensions
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp"]
        
        for ext in imageExtensions {
            let url = URL(fileURLWithPath: "/path/to/image.\(ext)")
            XCTAssertTrue(FileUtils.isImageFile(url), "Should recognize .\(ext) as an image file")
        }
        
        // Test a non-image file
        let nonImageURL = URL(fileURLWithPath: "/path/to/document.pdf")
        XCTAssertFalse(FileUtils.isImageFile(nonImageURL), "Should not recognize .pdf as an image file")
    }
    
    func testIsVideoFile() {
        // Test various video file extensions
        let videoExtensions = ["mp4", "mov", "m4v", "3gp", "avi", "mkv", "webm"]
        
        for ext in videoExtensions {
            let url = URL(fileURLWithPath: "/path/to/video.\(ext)")
            XCTAssertTrue(FileUtils.isVideoFile(url), "Should recognize .\(ext) as a video file")
        }
        
        // Test a non-video file
        let nonVideoURL = URL(fileURLWithPath: "/path/to/document.pdf")
        XCTAssertFalse(FileUtils.isVideoFile(nonVideoURL), "Should not recognize .pdf as a video file")
    }
    
    func testIsJsonFile() {
        // Test JSON file extension
        let jsonURL = URL(fileURLWithPath: "/path/to/data.json")
        XCTAssertTrue(FileUtils.isJsonFile(jsonURL), "Should recognize .json as a JSON file")
        
        // Test case insensitivity
        let upperCaseURL = URL(fileURLWithPath: "/path/to/data.JSON")
        XCTAssertTrue(FileUtils.isJsonFile(upperCaseURL), "Should recognize .JSON (uppercase) as a JSON file")
        
        // Test a non-JSON file
        let nonJsonURL = URL(fileURLWithPath: "/path/to/document.txt")
        XCTAssertFalse(FileUtils.isJsonFile(nonJsonURL), "Should not recognize .txt as a JSON file")
    }
    
    func testGetMIMEType() {
        // Test common file types and their MIME types
        let testCases = [
            ("image.jpg", "image/jpeg"),
            ("image.jpeg", "image/jpeg"),
            ("image.png", "image/png"),
            ("image.heic", "image/heic"),
            ("image.gif", "image/gif"),
            ("video.mp4", "video/mp4"),
            ("video.mov", "video/quicktime"),
            ("video.mp", "video/mp4"), // Special case for Pixel Motion Photos
            ("unknown.xyz", "application/octet-stream") // Default fallback
        ]
        
        for (filename, expectedMIME) in testCases {
            let url = URL(fileURLWithPath: "/path/to/\(filename)")
            let mimeType = FileUtils.getMIMEType(from: url)
            XCTAssertEqual(mimeType, expectedMIME, "Incorrect MIME type for \(filename)")
        }
    }
    
    func testCreateAndCleanupTempDirectory() {
        // Create temp directory
        guard let tempDir = FileUtils.createTempDirectory() else {
            XCTFail("Failed to create temporary directory")
            return
        }
        
        // Verify the directory exists
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: tempDir.path, isDirectory: &isDir)
        XCTAssertTrue(exists, "Temporary directory should exist")
        XCTAssertTrue(isDir.boolValue, "Path should be a directory")
        
        // Clean up the directory
        FileUtils.cleanupTempDirectory(tempDir)
        
        // Verify it no longer exists
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.path), "Directory should be removed after cleanup")
    }
    
    static var allTests = [
        ("testIsImageFile", testIsImageFile),
        ("testIsVideoFile", testIsVideoFile),
        ("testIsJsonFile", testIsJsonFile),
        ("testGetMIMEType", testGetMIMEType),
        ("testCreateAndCleanupTempDirectory", testCreateAndCleanupTempDirectory)
    ]
} 