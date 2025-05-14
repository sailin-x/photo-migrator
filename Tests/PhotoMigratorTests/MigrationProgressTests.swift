import XCTest
@testable import PhotoMigrator

final class MigrationProgressTests: XCTestCase {
    
    func testMigrationProgressInitialization() {
        // Create a MigrationProgress with initial values
        let progress = MigrationProgress(
            totalItems: 100,
            processedItems: 0,
            successfulItems: 0,
            failedItems: 0,
            currentItem: nil
        )
        
        // Verify initial state
        XCTAssertEqual(progress.totalItems, 100)
        XCTAssertEqual(progress.processedItems, 0)
        XCTAssertEqual(progress.successfulItems, 0)
        XCTAssertEqual(progress.failedItems, 0)
        XCTAssertNil(progress.currentItem)
        XCTAssertEqual(progress.percentage, 0)
    }
    
    func testMigrationProgressUpdate() {
        // Create a MigrationProgress
        var progress = MigrationProgress(totalItems: 100)
        
        // Process some items successfully
        progress.processedItems = 25
        progress.successfulItems = 20
        progress.failedItems = 5
        progress.currentItem = MediaItem(path: "/path/to/current.jpg")
        
        // Verify updated state
        XCTAssertEqual(progress.totalItems, 100)
        XCTAssertEqual(progress.processedItems, 25)
        XCTAssertEqual(progress.successfulItems, 20)
        XCTAssertEqual(progress.failedItems, 5)
        XCTAssertNotNil(progress.currentItem)
        XCTAssertEqual(progress.currentItem?.path, "/path/to/current.jpg")
        XCTAssertEqual(progress.percentage, 25)
    }
    
    func testMigrationProgressPercentageCalculation() {
        // Test various percentage scenarios
        var progress = MigrationProgress(totalItems: 100)
        
        // 0%
        XCTAssertEqual(progress.percentage, 0)
        
        // 50%
        progress.processedItems = 50
        XCTAssertEqual(progress.percentage, 50)
        
        // 100%
        progress.processedItems = 100
        XCTAssertEqual(progress.percentage, 100)
        
        // Handle edge case of 0 total items
        progress = MigrationProgress(totalItems: 0)
        XCTAssertEqual(progress.percentage, 0, "Percentage should be 0 when totalItems is 0")
        
        // Handle case where processed > total (shouldn't happen, but test anyway)
        progress = MigrationProgress(totalItems: 10)
        progress.processedItems = 15
        XCTAssertEqual(progress.percentage, 100, "Percentage should max out at 100")
    }
    
    func testMigrationProgressSuccess() {
        // Test success rate calculation
        var progress = MigrationProgress(totalItems: 100)
        
        // Process 80 items: 60 success, 20 failure
        progress.processedItems = 80
        progress.successfulItems = 60
        progress.failedItems = 20
        
        // Calculate success rate
        let successRate = Double(progress.successfulItems) / Double(progress.processedItems) * 100
        XCTAssertEqual(successRate, 75.0, accuracy: 0.001)
    }
    
    static var allTests = [
        ("testMigrationProgressInitialization", testMigrationProgressInitialization),
        ("testMigrationProgressUpdate", testMigrationProgressUpdate),
        ("testMigrationProgressPercentageCalculation", testMigrationProgressPercentageCalculation),
        ("testMigrationProgressSuccess", testMigrationProgressSuccess)
    ]
} 