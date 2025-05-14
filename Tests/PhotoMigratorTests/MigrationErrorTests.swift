import XCTest
@testable import PhotoMigrator

final class MigrationErrorTests: XCTestCase {
    
    func testMigrationErrorTypes() {
        // Test various error types
        let archiveError = MigrationError.archiveError("Invalid archive format")
        let metadataError = MigrationError.metadataError("Missing metadata file")
        let importError = MigrationError.importError("Failed to import to Photos")
        let permissionError = MigrationError.permissionError("No access to Photos library")
        let unknownError = MigrationError.unknownError("Something unexpected happened")
        
        // Verify error types
        XCTAssertTrue(archiveError.isArchiveError)
        XCTAssertTrue(metadataError.isMetadataError)
        XCTAssertTrue(importError.isImportError)
        XCTAssertTrue(permissionError.isPermissionError)
        XCTAssertTrue(unknownError.isUnknownError)
    }
    
    func testMigrationErrorMessages() {
        // Test error messages
        let errorMessage = "Test error message"
        let archiveError = MigrationError.archiveError(errorMessage)
        let metadataError = MigrationError.metadataError(errorMessage)
        let importError = MigrationError.importError(errorMessage)
        let permissionError = MigrationError.permissionError(errorMessage)
        let unknownError = MigrationError.unknownError(errorMessage)
        
        // Verify error messages
        XCTAssertEqual(archiveError.message, errorMessage)
        XCTAssertEqual(metadataError.message, errorMessage)
        XCTAssertEqual(importError.message, errorMessage)
        XCTAssertEqual(permissionError.message, errorMessage)
        XCTAssertEqual(unknownError.message, errorMessage)
    }
    
    func testMigrationErrorDescriptions() {
        // Test error descriptions
        let errorMessage = "Test error message"
        let archiveError = MigrationError.archiveError(errorMessage)
        let metadataError = MigrationError.metadataError(errorMessage)
        let importError = MigrationError.importError(errorMessage)
        let permissionError = MigrationError.permissionError(errorMessage)
        let unknownError = MigrationError.unknownError(errorMessage)
        
        // Verify error descriptions contain both the type and message
        XCTAssertTrue(archiveError.description.contains("Archive Error"))
        XCTAssertTrue(archiveError.description.contains(errorMessage))
        
        XCTAssertTrue(metadataError.description.contains("Metadata Error"))
        XCTAssertTrue(metadataError.description.contains(errorMessage))
        
        XCTAssertTrue(importError.description.contains("Import Error"))
        XCTAssertTrue(importError.description.contains(errorMessage))
        
        XCTAssertTrue(permissionError.description.contains("Permission Error"))
        XCTAssertTrue(permissionError.description.contains(errorMessage))
        
        XCTAssertTrue(unknownError.description.contains("Unknown Error"))
        XCTAssertTrue(unknownError.description.contains(errorMessage))
    }
    
    func testMigrationErrorEquality() {
        // Test equality of errors
        let error1 = MigrationError.archiveError("Error message")
        let error2 = MigrationError.archiveError("Error message")
        let error3 = MigrationError.archiveError("Different message")
        let error4 = MigrationError.metadataError("Error message")
        
        // Same type and message should be equal
        XCTAssertEqual(error1, error2)
        
        // Same type but different message should not be equal
        XCTAssertNotEqual(error1, error3)
        
        // Different type but same message should not be equal
        XCTAssertNotEqual(error1, error4)
    }
    
    static var allTests = [
        ("testMigrationErrorTypes", testMigrationErrorTypes),
        ("testMigrationErrorMessages", testMigrationErrorMessages),
        ("testMigrationErrorDescriptions", testMigrationErrorDescriptions),
        ("testMigrationErrorEquality", testMigrationErrorEquality)
    ]
} 