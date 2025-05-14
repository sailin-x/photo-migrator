import XCTest
@testable import PhotoMigrator

final class BatchSizeAdvisorTests: XCTestCase {
    
    var advisor: BatchSizeAdvisor!
    var memoryMonitor: MockMemoryMonitor!
    var configuration: BatchSizeAdvisor.Configuration!
    
    // Mock memory monitor for controlled testing
    class MockMemoryMonitor: MemoryMonitor {
        var mockCurrentPressure: MemoryPressure = .normal
        var mockMemoryUsage: UInt64 = 1000 * 1024 * 1024 // 1GB
        var mockTotalMemory: UInt64 = 8000 * 1024 * 1024 // 8GB
        
        override var currentPressure: MemoryPressure {
            return mockCurrentPressure
        }
        
        override func getCurrentMemoryUsage() -> UInt64 {
            return mockMemoryUsage
        }
        
        override func getTotalMemory() -> UInt64 {
            return mockTotalMemory
        }
        
        func setMemoryPressure(_ pressure: MemoryPressure) {
            mockCurrentPressure = pressure
        }
        
        func setMemoryUsage(_ usage: UInt64) {
            mockMemoryUsage = usage
        }
    }
    
    override func setUp() {
        super.setUp()
        
        // Create a simple configuration that's easier to test
        configuration = BatchSizeAdvisor.Configuration(
            minBatchSize: 10,
            maxBatchSize: 100,
            defaultBatchSize: 50,
            historyWindowSize: 5,
            smoothingFactor: 0.5,
            cooldownPeriod: 0.1, // Short cooldown for faster testing
            useMLPrediction: false // Disable ML to make tests deterministic
        )
        
        memoryMonitor = MockMemoryMonitor()
        advisor = BatchSizeAdvisor(configuration: configuration, memoryMonitor: memoryMonitor)
    }
    
    override func tearDown() {
        advisor = nil
        memoryMonitor = nil
        configuration = nil
        super.tearDown()
    }
    
    // Test initial recommendation matches default batch size
    func testInitialRecommendation() {
        XCTAssertEqual(advisor.currentRecommendation, configuration.defaultBatchSize)
    }
    
    // Test batch size reduction under critical memory pressure
    func testCriticalMemoryPressureReducesBatchSize() {
        // Start with the default batch size
        XCTAssertEqual(advisor.currentRecommendation, 50)
        
        // Set critical memory pressure
        memoryMonitor.setMemoryPressure(.critical)
        
        // Record a batch result to trigger adjustment
        advisor.recordBatchResult(batchSize: 50, processingTime: 1.0, items: 50)
        
        // Should reduce to minimum batch size under critical pressure
        XCTAssertEqual(advisor.currentRecommendation, configuration.minBatchSize)
    }
    
    // Test batch size reduction under high memory pressure
    func testHighMemoryPressureReducesBatchSize() {
        // Record some initial metrics first to build history
        memoryMonitor.setMemoryPressure(.normal)
        for _ in 0..<3 {
            advisor.recordBatchResult(batchSize: 50, processingTime: 1.0, items: 50)
        }
        
        // Now set high memory pressure
        memoryMonitor.setMemoryPressure(.high)
        advisor.recordBatchResult(batchSize: 50, processingTime: 1.0, items: 50)
        
        // Should reduce batch size but not to minimum
        XCTAssertLessThan(advisor.currentRecommendation, 50)
        XCTAssertGreaterThan(advisor.currentRecommendation, 10)
    }
    
    // Test batch size increase under good performance conditions
    func testIncreaseBatchSizeWithGoodPerformance() {
        // Set up ideal conditions for batch size increase:
        // 1. Normal memory pressure
        // 2. Fast processing time
        // 3. Low memory usage
        memoryMonitor.setMemoryPressure(.normal)
        memoryMonitor.setMemoryUsage(500 * 1024 * 1024) // Only 500MB used
        
        // Record some initial metrics first to build history
        for _ in 0..<3 {
            advisor.recordBatchResult(batchSize: 50, processingTime: 0.5, items: 50)
        }
        
        // Now record a batch with even better performance
        advisor.recordBatchResult(batchSize: 50, processingTime: 0.4, items: 50)
        
        // Should increase batch size
        XCTAssertGreaterThan(advisor.currentRecommendation, 50)
    }
    
    // Test batch size capping at maximum
    func testBatchSizeDoesNotExceedMaximum() {
        // Set very good conditions
        memoryMonitor.setMemoryPressure(.normal)
        memoryMonitor.setMemoryUsage(100 * 1024 * 1024) // Very low memory usage
        
        // Try to push batch size up by recording excellent metrics multiple times
        for _ in 0..<10 {
            advisor.recordBatchResult(batchSize: advisor.currentRecommendation, processingTime: 0.1, items: advisor.currentRecommendation)
        }
        
        // Should not exceed maximum batch size
        XCTAssertLessThanOrEqual(advisor.currentRecommendation, configuration.maxBatchSize)
    }
    
    // Test batch size doesn't go below minimum
    func testBatchSizeDoesNotGoBelowMinimum() {
        // Set very poor conditions
        memoryMonitor.setMemoryPressure(.high)
        memoryMonitor.setMemoryUsage(7000 * 1024 * 1024) // High memory usage
        
        // Try to push batch size down by recording poor metrics multiple times
        for _ in 0..<10 {
            advisor.recordBatchResult(batchSize: advisor.currentRecommendation, processingTime: 5.0, items: advisor.currentRecommendation)
        }
        
        // Should not go below minimum batch size
        XCTAssertGreaterThanOrEqual(advisor.currentRecommendation, configuration.minBatchSize)
    }
    
    // Test history window size limitation
    func testHistoryWindowSizeLimitation() {
        // Record more metrics than the history window size
        for i in 0..<10 {
            advisor.recordBatchResult(batchSize: 50, processingTime: Double(i), items: 50)
        }
        
        // Verify the history size is limited to the configuration setting
        // This is an indirect test since we don't have direct access to the history
        // We can observe that only recent metrics affect the recommendation
        
        // Reset memory pressure to normal
        memoryMonitor.setMemoryPressure(.normal)
        advisor.recordBatchResult(batchSize: 50, processingTime: 0.1, items: 50)
        let recommendation1 = advisor.currentRecommendation
        
        // Now set critical pressure and verify it overrides old history
        memoryMonitor.setMemoryPressure(.critical)
        advisor.recordBatchResult(batchSize: 50, processingTime: 0.1, items: 50)
        let recommendation2 = advisor.currentRecommendation
        
        // The recommendation should change significantly
        XCTAssertNotEqual(recommendation1, recommendation2)
        XCTAssertEqual(recommendation2, configuration.minBatchSize)
    }
    
    static var allTests = [
        ("testInitialRecommendation", testInitialRecommendation),
        ("testCriticalMemoryPressureReducesBatchSize", testCriticalMemoryPressureReducesBatchSize),
        ("testHighMemoryPressureReducesBatchSize", testHighMemoryPressureReducesBatchSize),
        ("testIncreaseBatchSizeWithGoodPerformance", testIncreaseBatchSizeWithGoodPerformance),
        ("testBatchSizeDoesNotExceedMaximum", testBatchSizeDoesNotExceedMaximum),
        ("testBatchSizeDoesNotGoBelowMinimum", testBatchSizeDoesNotGoBelowMinimum),
        ("testHistoryWindowSizeLimitation", testHistoryWindowSizeLimitation)
    ]
} 