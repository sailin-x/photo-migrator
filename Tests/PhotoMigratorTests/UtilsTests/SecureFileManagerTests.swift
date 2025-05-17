import XCTest
@testable import PhotoMigrator

final class SecureFileManagerTests: XCTestCase {
    var secureFileManager: SecureFileManager!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        secureFileManager = SecureFileManager.shared
        
        // Create a temporary directory for testing
        do {
            tempDirectory = try secureFileManager.getSecureTemporaryDirectory()
        } catch {
            XCTFail("Failed to create temporary directory: \(error)")
        }
    }
    
    override func tearDown() {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            do {
                try secureFileManager.removeItem(at: tempDirectory)
            } catch {
                print("Warning: Failed to clean up temporary directory: \(error)")
            }
        }
        
        super.tearDown()
    }
    
    // MARK: - Path Validation Tests
    
    func testValidateURL_ValidPath() {
        do {
            let validURL = tempDirectory.appendingPathComponent("test.txt")
            
            // This should not throw
            try secureFileManager.validateURL(validURL)
            
            // If we got here, the test passed
            XCTAssertTrue(true)
        } catch {
            XCTFail("Failed to validate valid URL: \(error)")
        }
    }
    
    func testValidateURL_DetectsPathTraversal() {
        let traversalURL = tempDirectory.appendingPathComponent("../../../etc/passwd")
        
        do {
            try secureFileManager.validateURL(traversalURL)
            XCTFail("Should have detected path traversal attack")
        } catch let error as FileSecurityError {
            switch error {
            case .pathTraversal(let path):
                XCTAssertTrue(path.contains("../"), "Error should indicate path traversal")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSanitizePath() {
        do {
            let unsafePath = "../../../etc/passwd"
            
            // This should throw a security error
            XCTAssertThrowsError(try secureFileManager.sanitizePath(unsafePath)) { error in
                guard let securityError = error as? FileSecurityError else {
                    XCTFail("Wrong error type")
                    return
                }
                
                if case .pathTraversal(_) = securityError {
                    // Expected error
                } else {
                    XCTFail("Wrong FileSecurityError type: \(securityError)")
                }
            }
        }
    }
    
    func testSanitizePathWithValidPath() {
        do {
            let safePath = tempDirectory.appendingPathComponent("test.txt").path
            
            // This should not throw
            let sanitizedPath = try secureFileManager.sanitizePath(safePath)
            XCTAssertEqual(URL(fileURLWithPath: sanitizedPath).standardized.path, URL(fileURLWithPath: safePath).standardized.path)
        } catch {
            XCTFail("Failed to sanitize valid path: \(error)")
        }
    }
    
    // MARK: - File Operations Tests
    
    func testCreateAndRemoveDirectory() {
        do {
            let testDirURL = tempDirectory.appendingPathComponent("testDir")
            try secureFileManager.createDirectoryIfNeeded(at: testDirURL)
            
            // Verify directory exists
            XCTAssertTrue(try secureFileManager.fileExists(at: testDirURL))
            
            // Remove the directory
            try secureFileManager.removeItem(at: testDirURL)
            
            // Verify directory no longer exists
            XCTAssertFalse(try secureFileManager.fileExists(at: testDirURL))
        } catch {
            XCTFail("Directory operations failed: \(error)")
        }
    }
    
    func testWriteAndReadFile() {
        do {
            let testFileURL = tempDirectory.appendingPathComponent("test.txt")
            let testData = "Test content".data(using: .utf8)!
            
            // Write file
            try secureFileManager.writeFile(data: testData, to: testFileURL)
            
            // Verify file exists
            XCTAssertTrue(try secureFileManager.fileExists(at: testFileURL))
            
            // Read file back
            let readData = try secureFileManager.readFile(at: testFileURL)
            
            // Verify content
            XCTAssertEqual(String(data: readData, encoding: .utf8), "Test content")
            
            // Clean up
            try secureFileManager.removeItem(at: testFileURL)
        } catch {
            XCTFail("File operations failed: \(error)")
        }
    }
    
    func testCopyAndMoveItem() {
        do {
            let sourceURL = tempDirectory.appendingPathComponent("source.txt")
            let copyDestURL = tempDirectory.appendingPathComponent("copy.txt")
            let moveDestURL = tempDirectory.appendingPathComponent("moved.txt")
            
            // Create source file
            let testData = "Test content for copy/move".data(using: .utf8)!
            try secureFileManager.writeFile(data: testData, to: sourceURL)
            
            // Test copy
            try secureFileManager.copyItem(at: sourceURL, to: copyDestURL)
            XCTAssertTrue(try secureFileManager.fileExists(at: copyDestURL))
            
            let copiedData = try secureFileManager.readFile(at: copyDestURL)
            XCTAssertEqual(String(data: copiedData, encoding: .utf8), "Test content for copy/move")
            
            // Test move
            try secureFileManager.moveItem(at: sourceURL, to: moveDestURL)
            XCTAssertFalse(try secureFileManager.fileExists(at: sourceURL)) // Source should be gone
            XCTAssertTrue(try secureFileManager.fileExists(at: moveDestURL)) // Destination should exist
            
            let movedData = try secureFileManager.readFile(at: moveDestURL)
            XCTAssertEqual(String(data: movedData, encoding: .utf8), "Test content for copy/move")
            
            // Clean up
            try secureFileManager.removeItem(at: copyDestURL)
            try secureFileManager.removeItem(at: moveDestURL)
        } catch {
            XCTFail("Copy/Move operations failed: \(error)")
        }
    }
    
    func testCreateSecureFileURL() {
        do {
            // Test with a safe filename
            let safeFilename = "test.txt"
            let safeURL = try secureFileManager.createSecureFileURL(filename: safeFilename, in: tempDirectory)
            XCTAssertEqual(safeURL.lastPathComponent, "test.txt")
            
            // Test with an unsafe filename containing path traversal
            let unsafeFilename = "../../../etc/passwd"
            let sanitizedURL = try secureFileManager.createSecureFileURL(filename: unsafeFilename, in: tempDirectory)
            
            // The path traversal should be replaced with safe characters
            XCTAssertNotEqual(sanitizedURL.lastPathComponent, "../../../etc/passwd")
            XCTAssertFalse(sanitizedURL.path.contains("../"))
        } catch {
            XCTFail("Failed to create secure file URL: \(error)")
        }
    }
    
    func testCreateSecureTemporaryFile() {
        do {
            let testData = "Temporary file content".data(using: .utf8)!
            
            // Create temporary file
            let tempFileURL = try secureFileManager.createSecureTemporaryFile(containing: testData, extension: "txt")
            
            // Verify file exists and has correct content
            XCTAssertTrue(try secureFileManager.fileExists(at: tempFileURL))
            
            let readData = try secureFileManager.readFile(at: tempFileURL)
            XCTAssertEqual(String(data: readData, encoding: .utf8), "Temporary file content")
            
            // Clean up parent directory
            if let parentDir = tempFileURL.deletingLastPathComponent().path.split(separator: "/").last {
                let tempDir = secureFileManager.getSecureTemporaryDirectory().deletingLastPathComponent().appendingPathComponent(String(parentDir))
                secureFileManager.cleanupTemporaryDirectory(tempDir)
            }
        } catch {
            XCTFail("Temporary file operations failed: \(error)")
        }
    }
    
    // MARK: - Testing file operations outside sandbox
    
    func testOutsideSandboxDetection() {
        let outsideURL = URL(fileURLWithPath: "/etc/hosts")
        
        do {
            try secureFileManager.validateURL(outsideURL)
            XCTFail("Should have detected path outside sandbox")
        } catch let error as FileSecurityError {
            switch error {
            case .outsideSandbox(let path):
                XCTAssertEqual(path, "/etc/hosts")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Directory Contents Test
    
    func testContentsOfDirectory() {
        do {
            // Create test directory with files
            let testDirURL = tempDirectory.appendingPathComponent("contentTestDir")
            try secureFileManager.createDirectoryIfNeeded(at: testDirURL)
            
            // Create a few files
            try secureFileManager.writeFile(data: Data("File 1".utf8), to: testDirURL.appendingPathComponent("file1.txt"))
            try secureFileManager.writeFile(data: Data("File 2".utf8), to: testDirURL.appendingPathComponent("file2.txt"))
            
            // Get directory contents
            let contents = try secureFileManager.contentsOfDirectory(at: testDirURL)
            
            // Verify contents
            XCTAssertEqual(contents.count, 2)
            XCTAssertTrue(contents.contains { $0.lastPathComponent == "file1.txt" })
            XCTAssertTrue(contents.contains { $0.lastPathComponent == "file2.txt" })
            
            // Clean up
            try secureFileManager.removeItem(at: testDirURL)
        } catch {
            XCTFail("Directory contents test failed: \(error)")
        }
    }
    
    // MARK: - Helper methods
    
    static var allTests = [
        ("testValidateURL_ValidPath", testValidateURL_ValidPath),
        ("testValidateURL_DetectsPathTraversal", testValidateURL_DetectsPathTraversal),
        ("testSanitizePath", testSanitizePath),
        ("testSanitizePathWithValidPath", testSanitizePathWithValidPath),
        ("testCreateAndRemoveDirectory", testCreateAndRemoveDirectory),
        ("testWriteAndReadFile", testWriteAndReadFile),
        ("testCopyAndMoveItem", testCopyAndMoveItem),
        ("testCreateSecureFileURL", testCreateSecureFileURL),
        ("testCreateSecureTemporaryFile", testCreateSecureTemporaryFile),
        ("testOutsideSandboxDetection", testOutsideSandboxDetection),
        ("testContentsOfDirectory", testContentsOfDirectory)
    ]
} 