import XCTest
@testable import PhotoMigrator

final class BatchSettingsTests: XCTestCase {
    
    func testDefaultInitialization() {
        // Create a BatchSettings instance with default initializer
        let settings = BatchSettings()
        
        // Verify default values
        XCTAssertEqual(settings.isEnabled, true)
        XCTAssertEqual(settings.batchSize, BatchSettings.defaultBatchSize)
        XCTAssertEqual(settings.maxBatchProcessingTime, BatchSettings.defaultMaxBatchTime)
        XCTAssertEqual(settings.useTimeLimits, true)
        XCTAssertEqual(settings.groupItemsByType, false)
        XCTAssertEqual(settings.usePrioritization, false)
        XCTAssertEqual(settings.useAdaptiveSizing, true)
        XCTAssertEqual(settings.highMemoryThreshold, 0.8)
        XCTAssertEqual(settings.criticalMemoryThreshold, 0.9)
        XCTAssertEqual(settings.pauseBetweenBatches, 2.0)
        XCTAssertEqual(settings.showMemoryWarnings, true)
    }
    
    func testCustomInitialization() {
        // Create a BatchSettings instance with custom values
        let settings = BatchSettings(
            isEnabled: false,
            batchSize: 100,
            useAdaptiveSizing: false,
            highMemoryThreshold: 0.75,
            criticalMemoryThreshold: 0.95,
            pauseBetweenBatches: 5.0,
            showMemoryWarnings: false,
            maxBatchProcessingTime: 45.0,
            useTimeLimits: false,
            groupItemsByType: true,
            usePrioritization: true,
            orderStrategy: .byTimestampAscending
        )
        
        // Verify custom values
        XCTAssertEqual(settings.isEnabled, false)
        XCTAssertEqual(settings.batchSize, 100)
        XCTAssertEqual(settings.useAdaptiveSizing, false)
        XCTAssertEqual(settings.highMemoryThreshold, 0.75)
        XCTAssertEqual(settings.criticalMemoryThreshold, 0.95)
        XCTAssertEqual(settings.pauseBetweenBatches, 5.0)
        XCTAssertEqual(settings.showMemoryWarnings, false)
        XCTAssertEqual(settings.maxBatchProcessingTime, 45.0)
        XCTAssertEqual(settings.useTimeLimits, false)
        XCTAssertEqual(settings.groupItemsByType, true)
        XCTAssertEqual(settings.usePrioritization, true)
        XCTAssertEqual(settings.orderStrategy, BatchSettings.OrderStrategy.byTimestampAscending)
    }
    
    func testMinimumBatchSizeEnforcement() {
        // Create settings with a batch size below the minimum
        let settings = BatchSettings(
            isEnabled: true,
            batchSize: 1 // This is below minimum batch size (5)
        )
        
        // Verify the batch size was adjusted to the minimum value
        XCTAssertEqual(settings.batchSize, BatchSettings.minimumBatchSize)
    }
    
    func testRecommendedSettings() {
        // Get recommended settings
        let settings = BatchSettings.recommendedSettings()
        
        // Verify recommended settings have reasonable values
        XCTAssertTrue(settings.isEnabled)
        XCTAssertGreaterThanOrEqual(settings.batchSize, BatchSettings.minimumBatchSize)
        XCTAssertGreaterThan(settings.maxBatchProcessingTime, 0)
        
        // The exact values will depend on the system's memory,
        // so we just test that they're within reasonable ranges
        XCTAssertGreaterThan(settings.batchSize, 0)
        XCTAssertGreaterThan(settings.maxBatchProcessingTime, 0)
    }
    
    static var allTests = [
        ("testDefaultInitialization", testDefaultInitialization),
        ("testCustomInitialization", testCustomInitialization),
        ("testMinimumBatchSizeEnforcement", testMinimumBatchSizeEnforcement),
        ("testRecommendedSettings", testRecommendedSettings)
    ]
} 