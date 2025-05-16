import Foundation
import SwiftUI

// Memory pressure notification compatibility
extension NSNotification.Name {
    static let memoryPressureStatusDidChange = NSNotification.Name(rawValue: "NSProcessInfoMemoryPressureStatusDidChange")
}

/// Utility for monitoring application memory usage
class MemoryMonitor {
    /// Singleton instance
    static let shared = MemoryMonitor()
    
    /// Memory pressure levels
    enum MemoryPressure {
        /// Normal memory usage
        case normal
        
        /// Medium memory pressure
        case medium
        
        /// High memory pressure
        case high
        
        /// Critical memory pressure
        case critical
        
        /// String description of the pressure level
        var description: String {
            switch self {
            case .normal:
                return "Normal"
            case .medium:
                return "Medium"
            case .high:
                return "High"
            case .critical:
                return "Critical"
            }
        }
    }
    
    /// Current memory pressure level
    var currentPressure: MemoryPressure = .normal
    
    /// Callback for memory pressure notifications
    var onMemoryWarning: ((UInt64) -> Void)?
    
    /// Callback for memory pressure level change
    var onPressureChange: ((MemoryPressure) -> Void)?
    
    /// Current memory usage in bytes
    private(set) var currentUsage: UInt64 = 0
    
    /// Peak memory usage observed
    private(set) var peakUsage: UInt64 = 0
    
    /// Warning thresholds (as percentage, 0.0-1.0)
    private var mediumPressureThreshold: Double = 0.65  // 65% of available memory
    private var highPressureThreshold: Double = 0.80    // 80% of available memory
    private var criticalPressureThreshold: Double = 0.90 // 90% of available memory
    
    /// Timer for periodic updates
    private var monitorTimer: Timer?
    
    private init() {
        // Register for memory pressure notifications from the system
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: .memoryPressureStatusDidChange,
            object: nil
        )
    }
    
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Configure memory pressure thresholds
    /// - Parameters:
    ///   - mediumPressure: Threshold for medium pressure (0.0-1.0)
    ///   - highPressure: Threshold for high pressure (0.0-1.0)
    ///   - criticalPressure: Threshold for critical pressure (0.0-1.0)
    func configureThresholds(mediumPressure: Double = 0.65, highPressure: Double = 0.80, criticalPressure: Double = 0.90) {
        self.mediumPressureThreshold = max(0.0, min(1.0, mediumPressure))
        self.highPressureThreshold = max(0.0, min(1.0, highPressure))
        self.criticalPressureThreshold = max(0.0, min(1.0, criticalPressure))
    }
    
    /// Start periodic memory usage monitoring
    /// - Parameter interval: Time interval between checks in seconds
    func startMonitoring(interval: TimeInterval = 5.0) {
        stopMonitoring()
        
        monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
        
        // Run immediately for initial reading
        updateMemoryUsage()
    }
    
    /// Alternative start monitoring with checkInterval parameter for compatibility
    func startMonitoring(checkInterval: TimeInterval = 5.0) {
        startMonitoring(interval: checkInterval)
    }
    
    /// Stop periodic monitoring
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    /// Reset peak memory usage tracking
    func resetPeakUsage() {
        peakUsage = 0
        updateMemoryUsage() // Get current reading
    }
    
    /// Update the current memory usage reading and check pressure levels
    @objc private func updateMemoryUsage() {
        currentUsage = getMemoryUsage()
        
        // Update peak
        if currentUsage > peakUsage {
            peakUsage = currentUsage
        }
        
        // Calculate current percentage of memory used
        let percentage = getMemoryUsagePercentage() / 100.0
        
        // Check thresholds and update pressure level
        let oldPressure = currentPressure
        
        if percentage >= criticalPressureThreshold {
            currentPressure = .critical
        } else if percentage >= highPressureThreshold {
            currentPressure = .high
        } else if percentage >= mediumPressureThreshold {
            currentPressure = .medium
        } else {
            currentPressure = .normal
        }
        
        // Notify about memory pressure changes
        if currentPressure != oldPressure {
            onPressureChange?(currentPressure)
        }
        
        // Always notify about memory usage
        if percentage >= highPressureThreshold {
            onMemoryWarning?(currentUsage)
        }
    }
    
    /// Handle system memory warning
    @objc private func didReceiveMemoryWarning(notification: Notification) {
        updateMemoryUsage()
        onMemoryWarning?(currentUsage)
        
        // Automatically try to reduce memory usage
        reduceMemoryUsage()
    }
    
    /// Get current memory usage of the process
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        
        return 0
    }
    
    /// Force memory cleanup
    func performMemoryCleanup() {
        // Suggestion to garbage collector to clean up
        autoreleasepool {
            // Empty autorelease pool encourages memory reclamation
        }
    }
    
    /// Format memory size to human-readable string
    func formatMemorySize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Get current memory usage in bytes
    func getCurrentMemoryUsage() -> UInt64 {
        return currentUsage
    }
    
    /// Get total system memory in bytes
    func getTotalMemory() -> UInt64 {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        return physicalMemory
    }
    
    /// Get memory usage as a percentage
    func getMemoryUsagePercentage() -> Double {
        let totalMemory = getTotalMemory()
        guard totalMemory > 0 else { return 0 }
        return (Double(currentUsage) / Double(totalMemory)) * 100.0
    }
    
    /// Get formatted memory usage
    func getFormattedMemoryUsage() -> String {
        return formatMemorySize(currentUsage)
    }
    
    /// Attempt to reduce memory usage
    func reduceMemoryUsage() {
        // Perform multiple cleanup passes
        for _ in 0..<3 {
            performMemoryCleanup()
        }
        
        // Explicitly suggest garbage collection
        #if os(macOS)
        // On macOS, try to force a memory cleanup
        // The old objc_collectingTryCollect is no longer available
        // Just rely on autorelease pools instead
        autoreleasepool { }
        #endif
        
        // Update memory usage after cleanup
        updateMemoryUsage()
    }
    
    /// Get recommended batch size based on current memory pressure
    /// - Parameter currentBatchSize: Current batch size
    /// - Returns: Recommended batch size
    func recommendedBatchSize(currentBatchSize: Int) -> Int {
        switch currentPressure {
        case .normal:
            // Potentially increase batch size if memory usage is low
            if getMemoryUsagePercentage() < 30 {
                return min(currentBatchSize * 2, 200) // Cap at 200
            }
            return currentBatchSize
            
        case .medium:
            // Slightly reduce batch size
            return max(currentBatchSize / 2, 20) // Minimum 20
            
        case .high:
            // Significantly reduce batch size
            return max(currentBatchSize / 4, 10) // Minimum 10
            
        case .critical:
            // Dramatically reduce batch size
            return max(currentBatchSize / 8, 5) // Minimum 5
        }
    }
}