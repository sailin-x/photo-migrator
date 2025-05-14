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
    }
    
    func testStartMonitoring() {
        // Starting monitoring should update memory usage
        memoryMonitor.startMonitoring()
        
        // Current usage should be updated (non-zero)
        XCTAssertGreaterThan(memoryMonitor.currentUsage, 0)
        
        // Peak usage should match current usage initially
        XCTAssertEqual(memoryMonitor.currentUsage, memoryMonitor.peakUsage)
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
    
    static var allTests = [
        ("testInitialization", testInitialization),
        ("testStartMonitoring", testStartMonitoring),
        ("testPeakUsageTracking", testPeakUsageTracking),
        ("testStopMonitoring", testStopMonitoring),
        ("testMemoryWarningCallback", testMemoryWarningCallback),
        ("testFormatMemorySize", testFormatMemorySize)
    ]
} 