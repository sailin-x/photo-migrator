import Foundation
import PhotoMigrator

print("Testing SecureTempFileManager...")

// Reference to the SecureTempFileManager
let tempFileManager = SecureTempFileManager.shared
let fileManager = SecureFileManager.shared

// Test 1: Create a temporary file
print("\nTest 1: Creating a temporary file...")
do {
    let testData = Data("Test data for secure temp file".utf8)
    let tempFile = try tempFileManager.createSecureTemporaryFile(containing: testData)
    print("  ✅ Created temporary file at: \(tempFile.path)")
    
    // Verify the file exists
    if try fileManager.fileExists(at: tempFile) {
        print("  ✅ File exists")
    } else {
        print("  ❌ File does not exist")
    }
    
    // Verify the content
    let readData = try fileManager.readFile(at: tempFile)
    if readData == testData {
        print("  ✅ File content matches")
    } else {
        print("  ❌ File content does not match")
    }
    
    // Clean up
    try tempFileManager.securelyDeleteTemporaryFile(tempFile)
    if try !fileManager.fileExists(at: tempFile) {
        print("  ✅ File securely deleted")
    } else {
        print("  ❌ File was not deleted")
    }
} catch {
    print("  ❌ Test failed: \(error.localizedDescription)")
}

// Test 2: Create a temporary directory
print("\nTest 2: Creating a temporary directory...")
do {
    let tempDir = try tempFileManager.createSecureTemporaryDirectory(prefix: "test-dir")
    print("  ✅ Created temporary directory at: \(tempDir.path)")
    
    // Verify the directory exists
    if try fileManager.fileExists(at: tempDir) {
        print("  ✅ Directory exists")
    } else {
        print("  ❌ Directory does not exist")
    }
    
    // Create some files in the directory
    let file1 = tempDir.appendingPathComponent("testfile1.txt")
    let file2 = tempDir.appendingPathComponent("testfile2.txt")
    
    try fileManager.writeFile(data: Data("Test file 1".utf8), to: file1)
    try fileManager.writeFile(data: Data("Test file 2".utf8), to: file2)
    
    print("  ✅ Created test files in directory")
    
    // Clean up
    try tempFileManager.securelyDeleteTemporaryDirectory(tempDir)
    if try !fileManager.fileExists(at: tempDir) {
        print("  ✅ Directory securely deleted")
    } else {
        print("  ❌ Directory was not deleted")
    }
} catch {
    print("  ❌ Test failed: \(error.localizedDescription)")
}

// Test 3: Test cleanup method
print("\nTest 3: Testing cleanup method...")
do {
    let testData = Data("Test data for cleanup".utf8)
    let tempFile1 = try tempFileManager.createSecureTemporaryFile(containing: testData)
    let tempFile2 = try tempFileManager.createSecureTemporaryFile(containing: testData)
    print("  ✅ Created temporary files for cleanup test")
    
    // Clean up
    tempFileManager.cleanupAllTemporaryFiles()
    
    // Verify files are gone
    if (try !fileManager.fileExists(at: tempFile1)) && (try !fileManager.fileExists(at: tempFile2)) {
        print("  ✅ Cleanup successfully removed all files")
    } else {
        print("  ❌ Cleanup failed to remove all files")
    }
} catch {
    print("  ❌ Test failed: \(error.localizedDescription)")
}

print("\nAll tests completed!")
