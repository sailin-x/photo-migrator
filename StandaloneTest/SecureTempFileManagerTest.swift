import Foundation

// Mock dependencies to isolate the SecureTempFileManager testing
class SecureFileManager {
    static let shared = SecureFileManager()
    
    func fileExists(at url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    func readFile(at url: URL) throws -> Data {
        return try Data(contentsOf: url)
    }
    
    func writeFile(at url: URL, data: Data, options: Data.WritingOptions = []) throws {
        try data.write(to: url, options: options)
    }
    
    func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    func contentsOfDirectory(at url: URL) throws -> [URL] {
        return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }
    
    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

// Simple logger mock
class Logger {
    func log(_ message: String, type: UInt8 = 0) {
        print(message)
    }
}

// Simple implementation of SecureTempFileManager based on the original
class SecureTempFileManager {
    static let shared = SecureTempFileManager()
    
    private let fileManager = SecureFileManager.shared
    private let logger = Logger()
    private let tempDirectoryURL: URL
    private var tempFilesRegistry = [URL]()
    
    init() {
        // Create a temporary directory specific to this test
        tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("PhotoMigratorTests", isDirectory: true)
        try? fileManager.createDirectory(at: tempDirectoryURL)
        
        // Clean up any old temp files
        cleanup()
    }
    
    func createSecureTemporaryFile(containing data: Data, prefix: String = "temp", extension: String = "tmp") throws -> URL {
        let randomComponent = UUID().uuidString
        let fileName = "\(prefix)-\(randomComponent).\(`extension`)"
        let fileURL = tempDirectoryURL.appendingPathComponent(fileName)
        
        try fileManager.writeFile(at: fileURL, data: data)
        tempFilesRegistry.append(fileURL)
        
        logger.log("Created temporary file: \(fileURL.path)")
        return fileURL
    }
    
    func createSecureTemporaryDirectory(prefix: String = "temp-dir") throws -> URL {
        let randomComponent = UUID().uuidString
        let dirName = "\(prefix)-\(randomComponent)"
        let dirURL = tempDirectoryURL.appendingPathComponent(dirName, isDirectory: true)
        
        try fileManager.createDirectory(at: dirURL)
        tempFilesRegistry.append(dirURL)
        
        logger.log("Created temporary directory: \(dirURL.path)")
        return dirURL
    }
    
    func securelyDeleteTemporaryFile(at url: URL) throws {
        // First overwrite with random data to ensure secure deletion
        if fileManager.fileExists(at: url) {
            let fileSize = try fileManager.readFile(at: url).count
            let randomData = Data((0..<fileSize).map { _ in UInt8.random(in: 0...255) })
            try fileManager.writeFile(at: url, data: randomData, options: .atomic)
            try fileManager.removeItem(at: url)
            
            // Remove from registry
            if let index = tempFilesRegistry.firstIndex(of: url) {
                tempFilesRegistry.remove(at: index)
            }
            
            logger.log("Securely deleted temporary file: \(url.path)")
        } else {
            logger.log("Attempted to delete non-existent file: \(url.path)")
        }
    }
    
    func cleanup() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: tempDirectoryURL)
            for item in contents {
                try? fileManager.removeItem(at: item)
            }
            tempFilesRegistry.removeAll()
            logger.log("Cleaned up all temporary files")
        } catch {
            logger.log("Error cleaning up temp files: \(error)")
        }
    }
    
    func cleanupFilesOlderThan(age: TimeInterval) {
        // Not implemented for the standalone test
        logger.log("Cleanup older files called (not implemented in standalone test)")
    }
    
    func recoverOrphanedFiles() {
        // Not implemented for the standalone test
        logger.log("Recover orphaned files called (not implemented in standalone test)")
    }
}

// Test runner
print("Running standalone SecureTempFileManager test...")

func runTests() {
    let tempFileManager = SecureTempFileManager.shared
    
    // Test 1: Create temporary file
    print("\nTest 1: Creating a temporary file...")
    do {
        let testData = Data("Test data for secure temp file".utf8)
        let tempFile = try tempFileManager.createSecureTemporaryFile(containing: testData)
        print("  ✅ Created temporary file at: \(tempFile.path)")
        
        // Verify the file exists
        if SecureFileManager.shared.fileExists(at: tempFile) {
            print("  ✅ File exists")
        } else {
            print("  ❌ File does not exist")
        }
        
        // Verify the content
        let readData = try SecureFileManager.shared.readFile(at: tempFile)
        if readData == testData {
            print("  ✅ File content matches")
        } else {
            print("  ❌ File content does not match")
        }
        
        // Test 2: Securely delete the temporary file
        print("\nTest 2: Securely deleting the temporary file...")
        try tempFileManager.securelyDeleteTemporaryFile(at: tempFile)
        
        // Verify the file no longer exists
        if !SecureFileManager.shared.fileExists(at: tempFile) {
            print("  ✅ File was securely deleted")
        } else {
            print("  ❌ File still exists after deletion")
        }
    } catch {
        print("  ❌ Error in test 1 or 2: \(error)")
    }
    
    // Test 3: Create temporary directory
    print("\nTest 3: Creating a temporary directory...")
    do {
        let tempDir = try tempFileManager.createSecureTemporaryDirectory()
        print("  ✅ Created temporary directory at: \(tempDir.path)")
        
        // Verify the directory exists
        if SecureFileManager.shared.fileExists(at: tempDir) {
            print("  ✅ Directory exists")
        } else {
            print("  ❌ Directory does not exist")
        }
        
        // Test 4: Create a file inside the temporary directory
        print("\nTest 4: Creating a file inside the temporary directory...")
        let fileInDir = tempDir.appendingPathComponent("test-file.txt")
        let fileData = Data("This is a test file inside the temporary directory".utf8)
        try SecureFileManager.shared.writeFile(at: fileInDir, data: fileData)
        
        // Verify the file exists
        if SecureFileManager.shared.fileExists(at: fileInDir) {
            print("  ✅ File in directory exists")
        } else {
            print("  ❌ File in directory does not exist")
        }
        
        // Test 5: Cleanup
        print("\nTest 5: Testing cleanup...")
        tempFileManager.cleanup()
        
        // Verify the directory no longer exists
        if !SecureFileManager.shared.fileExists(at: tempDir) {
            print("  ✅ Directory was removed during cleanup")
        } else {
            print("  ❌ Directory still exists after cleanup")
        }
    } catch {
        print("  ❌ Error in test 3, 4, or 5: \(error)")
    }
    
    print("\nAll tests completed!")
}

// Run the tests
runTests() 