import XCTest
@testable import PhotoMigrator

final class SecureTempFileManagerTests: XCTestCase {
    
    var tempFileManager: SecureTempFileManager!
    var testDirectories = [URL]()
    
    override func setUp() {
        super.setUp()
        tempFileManager = SecureTempFileManager.shared
    }
    
    override func tearDown() {
        // Clean up any test directories created
        for directory in testDirectories {
            try? SecureFileManager.shared.removeItem(at: directory)
        }
        testDirectories.removeAll()
        super.tearDown()
    }
    
    // MARK: - Temporary File Creation Tests
    
    func testCreateSecureTemporaryFile() throws {
        // Test creating a temp file with data
        let testData = Data("Test data for secure temp file".utf8)
        let tempFile = try tempFileManager.createSecureTemporaryFile(containing: testData)
        
        // Verify the file exists
        XCTAssertTrue(try SecureFileManager.shared.fileExists(at: tempFile))
        
        // Verify the content matches
        let readData = try SecureFileManager.shared.readFile(at: tempFile)
        XCTAssertEqual(readData, testData)
        
        // Clean up
        try tempFileManager.securelyDeleteTemporaryFile(tempFile)
    }
    
    func testCreateSecureTemporaryFileWithPrefixAndExtension() throws {
        // Test creating a temp file with prefix and extension
        let testData = Data("Test data with prefix and extension".utf8)
        let tempFile = try tempFileManager.createSecureTemporaryFile(
            containing: testData,
            prefix: "test-prefix",
            extension: "txt"
        )
        
        // Verify the file exists
        XCTAssertTrue(try SecureFileManager.shared.fileExists(at: tempFile))
        
        // Verify the file has the correct extension
        XCTAssertEqual(tempFile.pathExtension, "txt")
        
        // Verify the file name contains the prefix
        XCTAssertTrue(tempFile.lastPathComponent.hasPrefix("test-prefix"))
        
        // Clean up
        try tempFileManager.securelyDeleteTemporaryFile(tempFile)
    }
    
    func testCreateSecureTemporaryDirectory() throws {
        // Test creating a temp directory
        let tempDir = try tempFileManager.createSecureTemporaryDirectory()
        testDirectories.append(tempDir)
        
        // Verify the directory exists
        XCTAssertTrue(try SecureFileManager.shared.fileExists(at: tempDir))
        
        // Verify it's a directory
        let attributes = try SecureFileManager.shared.attributesOfItem(at: tempDir)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeDirectory)
        
        // Clean up
        try tempFileManager.securelyDeleteTemporaryDirectory(tempDir)
    }
    
    func testCreateSecureTemporaryDirectoryWithPrefix() throws {
        // Test creating a temp directory with prefix
        let tempDir = try tempFileManager.createSecureTemporaryDirectory(prefix: "test-dir")
        testDirectories.append(tempDir)
        
        // Verify the directory exists
        XCTAssertTrue(try SecureFileManager.shared.fileExists(at: tempDir))
        
        // Verify the directory name contains the prefix
        XCTAssertTrue(tempDir.lastPathComponent.hasPrefix("test-dir"))
        
        // Clean up
        try tempFileManager.securelyDeleteTemporaryDirectory(tempDir)
    }
    
    // MARK: - Secure Deletion Tests
    
    func testSecurelyDeleteTemporaryFile() throws {
        // Create a test file
        let testData = Data("Test data for secure deletion".utf8)
        let tempFile = try tempFileManager.createSecureTemporaryFile(containing: testData)
        
        // Verify it exists
        XCTAssertTrue(try SecureFileManager.shared.fileExists(at: tempFile))
        
        // Delete it securely
        try tempFileManager.securelyDeleteTemporaryFile(tempFile)
        
        // Verify it no longer exists
        XCTAssertFalse(try SecureFileManager.shared.fileExists(at: tempFile))
    }
    
    func testSecurelyDeleteTemporaryDirectory() throws {
        // Create a test directory
        let tempDir = try tempFileManager.createSecureTemporaryDirectory()
        testDirectories.append(tempDir)
        
        // Create some test files in the directory
        let fileURL1 = tempDir.appendingPathComponent("test1.txt")
        let fileURL2 = tempDir.appendingPathComponent("test2.txt")
        
        try SecureFileManager.shared.writeFile(data: Data("Test file 1".utf8), to: fileURL1)
        try SecureFileManager.shared.writeFile(data: Data("Test file 2".utf8), to: fileURL2)
        
        // Verify files exist
        XCTAssertTrue(try SecureFileManager.shared.fileExists(at: fileURL1))
        XCTAssertTrue(try SecureFileManager.shared.fileExists(at: fileURL2))
        
        // Delete the directory securely
        try tempFileManager.securelyDeleteTemporaryDirectory(tempDir)
        
        // Verify the directory and its contents no longer exist
        XCTAssertFalse(try SecureFileManager.shared.fileExists(at: tempDir))
    }
    
    func testSecurelyDeleteNestedTemporaryDirectory() throws {
        // Create a test directory
        let tempDir = try tempFileManager.createSecureTemporaryDirectory()
        testDirectories.append(tempDir)
        
        // Create a nested directory
        let nestedDir = tempDir.appendingPathComponent("nested", isDirectory: true)
        try SecureFileManager.shared.createDirectoryIfNeeded(at: nestedDir)
        
        // Create some test files in both directories
        let fileURL1 = tempDir.appendingPathComponent("test1.txt")
        let fileURL2 = nestedDir.appendingPathComponent("test2.txt")
        
        try SecureFileManager.shared.writeFile(data: Data("Test file 1".utf8), to: fileURL1)
        try SecureFileManager.shared.writeFile(data: Data("Test file 2".utf8), to: fileURL2)
        
        // Verify files exist
        XCTAssertTrue(try SecureFileManager.shared.fileExists(at: fileURL1))
        XCTAssertTrue(try SecureFileManager.shared.fileExists(at: fileURL2))
        
        // Delete the directory securely
        try tempFileManager.securelyDeleteTemporaryDirectory(tempDir)
        
        // Verify the directory and its contents no longer exist
        XCTAssertFalse(try SecureFileManager.shared.fileExists(at: tempDir))
    }
    
    // MARK: - Registry and Cleanup Tests
    
    func testCleanupAllTemporaryFiles() throws {
        // Create multiple test files
        let testData = Data("Test data for cleanup".utf8)
        let tempFile1 = try tempFileManager.createSecureTemporaryFile(containing: testData)
        let tempFile2 = try tempFileManager.createSecureTemporaryFile(containing: testData)
        let tempDir = try tempFileManager.createSecureTemporaryDirectory()
        testDirectories.append(tempDir)
        
        // Verify all exist
        XCTAssertTrue(try SecureFileManager.shared.fileExists(at: tempFile1))
        XCTAssertTrue(try SecureFileManager.shared.fileExists(at: tempFile2))
        XCTAssertTrue(try SecureFileManager.shared.fileExists(at: tempDir))
        
        // Run cleanup
        tempFileManager.cleanupAllTemporaryFiles()
        
        // Verify all files are gone
        XCTAssertFalse(try SecureFileManager.shared.fileExists(at: tempFile1))
        XCTAssertFalse(try SecureFileManager.shared.fileExists(at: tempFile2))
        XCTAssertFalse(try SecureFileManager.shared.fileExists(at: tempDir))
    }
    
    func testTryRecoverOrphanedFiles() throws {
        // This is difficult to test directly since it's called in init
        // We'll verify it doesn't throw exceptions when called manually
        
        // Create an orphaned file for next run
        let testData = Data("Test data for orphaned recovery".utf8)
        let tempFile = try tempFileManager.createSecureTemporaryFile(containing: testData)
        
        // Don't explicitly delete it - should be cleaned up on next run
        // (for testing purposes, we won't worry about actual verification)
        XCTAssertTrue(try SecureFileManager.shared.fileExists(at: tempFile))
        
        // Just check that this doesn't throw
        XCTAssertNoThrow(try tempFileManager.perform(#selector(SecureTempFileManager.tryRecoverOrphanedFiles)))
    }
    
    // MARK: - Age-based Cleanup Tests
    
    func testCleanupAgedTemporaryFiles() throws {
        // Create a test file
        let testData = Data("Test data for aged cleanup".utf8)
        let tempFile = try tempFileManager.createSecureTemporaryFile(containing: testData)
        
        // Set a very short max age (1 second)
        let maxAge: TimeInterval = 1
        
        // Wait for the file to age
        Thread.sleep(forTimeInterval: maxAge + 0.5)
        
        // Call the private cleanupAgedTemporaryFiles method
        tempFileManager.perform(#selector(SecureTempFileManager.cleanupAgedTemporaryFiles), with: maxAge)
        
        // Verify the file is deleted
        XCTAssertFalse(try SecureFileManager.shared.fileExists(at: tempFile))
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidPathErrorHandling() {
        // Try to delete a non-existent file
        let nonExistentURL = URL(fileURLWithPath: "/tmp/non-existent-file-\(UUID().uuidString)")
        
        XCTAssertThrowsError(try tempFileManager.securelyDeleteTemporaryFile(nonExistentURL)) { error in
            guard let tempError = error as? TempFileError else {
                XCTFail("Expected TempFileError but got \(error)")
                return
            }
            
            switch tempError {
            case .invalidPath(let path, _):
                XCTAssertEqual(path, nonExistentURL.path)
            default:
                XCTFail("Expected invalidPath error but got \(tempError)")
            }
        }
    }
    
    func testSchedulePeriodicCleanup() {
        // Verify this method doesn't throw (can't test the timer execution in a unit test)
        XCTAssertNoThrow(tempFileManager.schedulePeriodicCleanup(interval: 1000))
    }
} 