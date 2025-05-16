import XCTest
@testable import PhotoMigrator

final class MemoryMonitorTests: XCTestCase {
    
    var memoryMonitor: MemoryMonitor!
    
    override func setUp() {
        super.setUp()
        memoryMonitor = MemoryMonitor()
        // Reset the singleton to avoid interference between tests
        MemoryMonitor.shared.stopMonitoring()
    }
    
    override func tearDown() {
        memoryMonitor.stopMonitoring()
        memoryMonitor = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertEqual(memoryMonitor.currentUsage, 0)
        XCTAssertEqual(memoryMonitor.peakUsage, 0)
        XCTAssertNil(memoryMonitor.onMemoryWarning)
        XCTAssertNil(memoryMonitor.onPressureChange)
        XCTAssertEqual(memoryMonitor.currentPressure, .normal)
    }
    
    func testStartMonitoring() {
        // Starting monitoring should update memory usage
        memoryMonitor.startMonitoring()
        
        // Current usage should be updated (non-zero)
        XCTAssertGreaterThan(memoryMonitor.currentUsage, 0)
        
        // Peak usage should match current usage initially
        XCTAssertEqual(memoryMonitor.currentUsage, memoryMonitor.peakUsage)
    }
    
    func testStartMonitoringWithCheckInterval() {
        // Test the alternative method signature
        memoryMonitor.startMonitoring(checkInterval: 2.0)
        
        // Current usage should be updated (non-zero)
        XCTAssertGreaterThan(memoryMonitor.currentUsage, 0)
    }
    
    func testPeakUsageTracking() {
        memoryMonitor.startMonitoring()
        
        // Initial usage
        let initialUsage = memoryMonitor.currentUsage
        
        // Create some memory pressure to potentially increase memory usage
        var temporaryArray = [Data]()
        for _ in 0..<1000 {
            temporaryArray.append(Data(count: 1000))
        }
        
        // Force an update to memory usage
        memoryMonitor.startMonitoring() // Calling start again forces an update
        
        // The peak should be at least the initial usage
        XCTAssertGreaterThanOrEqual(memoryMonitor.peakUsage, initialUsage)
        
        // Clean up the temporary array
        temporaryArray = []
    }
    
    func testResetPeakUsage() {
        // Start monitoring to get initial peak
        memoryMonitor.startMonitoring()
        
        // Create some memory to ensure non-zero peak
        var temporaryArray = [Data]()
        for _ in 0..<1000 {
            temporaryArray.append(Data(count: 1000))
        }
        
        // Force update
        memoryMonitor.startMonitoring()
        
        // Verify we have a non-zero peak
        XCTAssertGreaterThan(memoryMonitor.peakUsage, 0)
        
        // Reset the peak
        memoryMonitor.resetPeakUsage()
        
        // Peak should now match current usage
        XCTAssertEqual(memoryMonitor.peakUsage, memoryMonitor.currentUsage)
        
        // Clean up
        temporaryArray = []
    }
    
    func testStopMonitoring() {
        memoryMonitor.startMonitoring()
        XCTAssertGreaterThan(memoryMonitor.currentUsage, 0)
        
        // Stop monitoring
        memoryMonitor.stopMonitoring()
        
        // Current and peak usage should remain unchanged
        let currentUsage = memoryMonitor.currentUsage
        let peakUsage = memoryMonitor.peakUsage
        
        // Create memory pressure
        var temporaryArray = [Data]()
        for _ in 0..<1000 {
            temporaryArray.append(Data(count: 1000))
        }
        
        // No automatic update should occur
        XCTAssertEqual(memoryMonitor.currentUsage, currentUsage)
        XCTAssertEqual(memoryMonitor.peakUsage, peakUsage)
        
        // Clean up
        temporaryArray = []
    }
    
    func testMemoryWarningCallback() {
        // Set up expectation for callback
        let expectation = XCTestExpectation(description: "Memory warning callback")
        
        // Testing callback trigger
        var callbackFired = false
        var callbackUsage: UInt64 = 0
        
        memoryMonitor.onMemoryWarning = { usage in
            callbackFired = true
            callbackUsage = usage
            expectation.fulfill()
        }
        
        // Directly simulate a memory warning
        NotificationCenter.default.post(
            name: NSNotification.Name.NSProcessInfoMemoryPressureStatusDidChange,
            object: nil
        )
        
        // Wait for the callback
        wait(for: [expectation], timeout: 1.0)
        
        // Verify callback executed with the current memory usage
        XCTAssertTrue(callbackFired)
        XCTAssertGreaterThan(callbackUsage, 0)
    }
    
    func testPressureChangeCallback() {
        // Set up expectation for callback
        let expectation = XCTestExpectation(description: "Pressure change callback")
        
        // Testing callback trigger
        var callbackFired = false
        var pressureLevel: MemoryMonitor.MemoryPressure = .normal
        
        memoryMonitor.onPressureChange = { pressure in
            callbackFired = true
            pressureLevel = pressure
            expectation.fulfill()
        }
        
        // Save the original thresholds
        let originalMemoryMonitor = memoryMonitor
        
        // Configure very low thresholds to ensure we hit them
        memoryMonitor.configureThresholds(
            mediumPressure: 0.0001, // Nearly 0%
            highPressure: 0.0002,   // Nearly 0%
            criticalPressure: 0.0003 // Nearly 0%
        )
        
        // Force an update which should trigger pressure change
        memoryMonitor.startMonitoring()
        
        // Wait for the callback
        wait(for: [expectation], timeout: 1.0)
        
        // Verify callback executed with a pressure level
        XCTAssertTrue(callbackFired)
        XCTAssertNotEqual(pressureLevel, .normal) // Should be higher than normal
        
        // Restore original
        memoryMonitor = originalMemoryMonitor
    }
    
    func testFormatMemorySize() {
        // Test formatting different memory sizes
        let smallSize: UInt64 = 1024
        let mediumSize: UInt64 = 1024 * 1024
        let largeSize: UInt64 = 1024 * 1024 * 1024
        
        // Small size should format to KB
        let smallFormatted = memoryMonitor.formatMemorySize(smallSize)
        XCTAssertTrue(smallFormatted.contains("KB"))
        
        // Medium size should format to MB
        let mediumFormatted = memoryMonitor.formatMemorySize(mediumSize)
        XCTAssertTrue(mediumFormatted.contains("MB"))
        
        // Large size should format to GB
        let largeFormatted = memoryMonitor.formatMemorySize(largeSize)
        XCTAssertTrue(largeFormatted.contains("GB"))
    }
    
    func testGetMemoryUsagePercentage() {
        // Start monitoring to get current values
        memoryMonitor.startMonitoring()
        
        // Get the percentage
        let percentage = memoryMonitor.getMemoryUsagePercentage()
        
        // Should be between 0-100
        XCTAssertGreaterThanOrEqual(percentage, 0.0)
        XCTAssertLessThanOrEqual(percentage, 100.0)
        
        // It should be proportional to current usage
        let totalMemory = memoryMonitor.getTotalMemory()
        let expectedPercentage = (Double(memoryMonitor.currentUsage) / Double(totalMemory)) * 100.0
        XCTAssertEqual(percentage, expectedPercentage, accuracy: 0.001)
    }
    
    func testGetFormattedMemoryUsage() {
        // Start monitoring to get current values
        memoryMonitor.startMonitoring()
        
        // Get the formatted usage
        let formatted = memoryMonitor.getFormattedMemoryUsage()
        
        // It should be non-empty
        XCTAssertFalse(formatted.isEmpty)
        
        // It should match what we'd get from formatMemorySize
        let expected = memoryMonitor.formatMemorySize(memoryMonitor.currentUsage)
        XCTAssertEqual(formatted, expected)
    }
    
    func testReduceMemoryUsage() {
        // Start monitoring
        memoryMonitor.startMonitoring()
        
        // Create some memory pressure
        var temporaryArray = [Data]()
        for _ in 0..<1000 {
            temporaryArray.append(Data(count: 1000))
        }
        
        // Capture usage before reduction
        let usageBefore = memoryMonitor.currentUsage
        
        // Reduce memory usage
        memoryMonitor.reduceMemoryUsage()
        
        // Usage after should be updated (new measurement)
        XCTAssertNotEqual(memoryMonitor.currentUsage, 0)
        
        // Clean up
        temporaryArray = []
    }
    
    func testConfigureThresholds() {
        // Configure thresholds 
        memoryMonitor.configureThresholds(
            mediumPressure: 0.5,  // 50%
            highPressure: 0.75,   // 75%
            criticalPressure: 0.9  // 90%
        )
        
        // Start monitoring
        memoryMonitor.startMonitoring()
        
        // Current pressure should be normal or reflect real system state
        XCTAssertNotNil(memoryMonitor.currentPressure)
    }
    
    func testRecommendedBatchSize() {
        // Test normal pressure
        memoryMonitor.currentPressure = .normal
        let normalSize = memoryMonitor.recommendedBatchSize(currentBatchSize: 100)
        XCTAssertGreaterThanOrEqual(normalSize, 100) // Normal should maintain or increase
        
        // Test medium pressure
        memoryMonitor.currentPressure = .medium
        let mediumSize = memoryMonitor.recommendedBatchSize(currentBatchSize: 100)
        XCTAssertLessThan(mediumSize, 100) // Medium should reduce
        XCTAssertGreaterThanOrEqual(mediumSize, 20) // But not below minimum
        
        // Test high pressure
        memoryMonitor.currentPressure = .high
        let highSize = memoryMonitor.recommendedBatchSize(currentBatchSize: 100)
        XCTAssertLessThan(highSize, mediumSize) // High should reduce more than medium
        XCTAssertGreaterThanOrEqual(highSize, 10) // But not below minimum
        
        // Test critical pressure
        memoryMonitor.currentPressure = .critical
        let criticalSize = memoryMonitor.recommendedBatchSize(currentBatchSize: 100)
        XCTAssertLessThan(criticalSize, highSize) // Critical should reduce more than high
        XCTAssertGreaterThanOrEqual(criticalSize, 5) // But not below minimum
    }
    
    static var allTests = [
        ("testInitialization", testInitialization),
        ("testStartMonitoring", testStartMonitoring),
        ("testStartMonitoringWithCheckInterval", testStartMonitoringWithCheckInterval),
        ("testPeakUsageTracking", testPeakUsageTracking),
        ("testResetPeakUsage", testResetPeakUsage),
        ("testStopMonitoring", testStopMonitoring),
        ("testMemoryWarningCallback", testMemoryWarningCallback),
        ("testPressureChangeCallback", testPressureChangeCallback),
        ("testFormatMemorySize", testFormatMemorySize),
        ("testGetMemoryUsagePercentage", testGetMemoryUsagePercentage),
        ("testGetFormattedMemoryUsage", testGetFormattedMemoryUsage),
        ("testReduceMemoryUsage", testReduceMemoryUsage),
        ("testConfigureThresholds", testConfigureThresholds),
        ("testRecommendedBatchSize", testRecommendedBatchSize)
    ]
} 