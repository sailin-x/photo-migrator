import Foundation

/// Service to monitor memory usage and provide memory pressure information
class MemoryMonitor {
    /// Shared singleton instance
    static let shared = MemoryMonitor()
    
    /// Memory pressure states
    enum MemoryPressure {
        case normal
        case medium
        case high
        case critical
    }
    
    /// Current memory pressure level
    private(set) var currentPressure: MemoryPressure = .normal
    
    /// Peak memory usage since last reset
    private(set) var peakMemoryUsage: UInt64 = 0
    
    /// Memory warning threshold for high pressure (80% of available memory)
    private var highPressureThreshold: Double = 0.8
    
    /// Memory warning threshold for critical pressure (90% of available memory)
    private var criticalPressureThreshold: Double = 0.9
    
    /// Timer for periodic memory checks
    private var monitoringTimer: Timer?
    
    /// Callback for memory pressure changes
    var onPressureChange: ((MemoryPressure) -> Void)?
    
    private init() {
        // Private initializer for singleton
    }
    
    /// Start monitoring memory usage
    func startMonitoring(checkInterval: TimeInterval = 2.0) {
        stopMonitoring()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkMemoryUsage()
        }
    }
    
    /// Stop monitoring memory usage
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    /// Reset peak memory usage stats
    func resetPeakUsage() {
        peakMemoryUsage = 0
    }
    
    /// Get current memory usage in bytes
    func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        
        return 0
    }
    
    /// Get total physical memory in bytes
    func getTotalMemory() -> UInt64 {
        let hostPort = mach_host_self()
        var hostSize = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var pageSize: vm_size_t = 0
        
        host_page_size(hostPort, &pageSize)
        
        var totalMemory: UInt64 = 0
        totalMemory = ProcessInfo.processInfo.physicalMemory
        
        return totalMemory
    }
    
    /// Check current memory usage and update pressure state
    private func checkMemoryUsage() {
        let currentUsage = getCurrentMemoryUsage()
        let totalMemory = getTotalMemory()
        
        // Update peak memory usage if current usage is higher
        if currentUsage > peakMemoryUsage {
            peakMemoryUsage = currentUsage
        }
        
        let usageRatio = Double(currentUsage) / Double(totalMemory)
        let oldPressure = currentPressure
        
        // Determine memory pressure level
        if usageRatio >= criticalPressureThreshold {
            currentPressure = .critical
        } else if usageRatio >= highPressureThreshold {
            currentPressure = .high
        } else if usageRatio >= 0.7 {
            currentPressure = .medium
        } else {
            currentPressure = .normal
        }
        
        // Notify if pressure level changed
        if oldPressure != currentPressure {
            onPressureChange?(currentPressure)
        }
    }
    
    /// Configure thresholds for memory pressure levels
    func configureThresholds(highPressure: Double, criticalPressure: Double) {
        highPressureThreshold = max(0.5, min(0.9, highPressure))
        criticalPressureThreshold = max(highPressureThreshold + 0.05, min(0.95, criticalPressure))
    }
    
    /// Get formatted memory usage string
    func getFormattedMemoryUsage() -> String {
        let usage = getCurrentMemoryUsage()
        return formatMemorySize(usage)
    }
    
    /// Get formatted memory usage percentage
    func getMemoryUsagePercentage() -> String {
        let usage = Double(getCurrentMemoryUsage())
        let total = Double(getTotalMemory())
        let percentage = (usage / total) * 100
        return String(format: "%.1f%%", percentage)
    }
    
    /// Format memory size to human-readable string
    private func formatMemorySize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Recommendation for batch size based on current memory pressure
    func recommendedBatchSize(currentBatchSize: Int) -> Int {
        switch currentPressure {
        case .normal:
            return currentBatchSize
        case .medium:
            return max(5, Int(Double(currentBatchSize) * 0.75))
        case .high:
            return max(5, Int(Double(currentBatchSize) * 0.5))
        case .critical:
            return max(1, Int(Double(currentBatchSize) * 0.25))
        }
    }
    
    /// Attempt to reduce memory usage by forcing garbage collection
    func reduceMemoryUsage() {
        // Suggest Swift runtime to collect garbage (best effort)
        #if os(macOS)
        sleep(1) // Give the system time to clean up
        
        // Request low memory cleanup
        let selector = NSSelectorFromString("performSelectorOnMainThread:withObject:waitUntilDone:")
        NSObject.perform(selector, with: nil, with: nil)
        #endif
        
        // Request explicit GC if available
        autoreleasepool {
            // Force autoreleasepool cleanup
        }
    }
}