import Foundation

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
    
    /// Current memory usage in bytes
    private(set) var currentUsage: UInt64 = 0
    
    /// Peak memory usage observed
    private(set) var peakUsage: UInt64 = 0
    
    /// Warning thresholds (in bytes)
    private let mediumPressureThreshold: UInt64 = 500_000_000  // 500MB
    private let highPressureThreshold: UInt64 = 1_000_000_000  // 1GB
    
    /// Timer for periodic updates
    private var monitorTimer: Timer?
    
    private init() {
        // Register for memory pressure notifications from the system
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: NSNotification.Name.NSProcessInfoMemoryPressureStatusDidChange,
            object: nil
        )
    }
    
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Start periodic memory usage monitoring
    func startMonitoring(interval: TimeInterval = 5.0) {
        stopMonitoring()
        
        monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
        
        // Run immediately for initial reading
        updateMemoryUsage()
    }
    
    /// Stop periodic monitoring
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    /// Update the current memory usage reading
    @objc private func updateMemoryUsage() {
        currentUsage = getMemoryUsage()
        
        // Update peak
        if currentUsage > peakUsage {
            peakUsage = currentUsage
        }
        
        // Check thresholds
        if currentUsage >= highPressureThreshold {
            onMemoryWarning?(currentUsage)
        }
    }
    
    /// Handle system memory warning
    @objc private func didReceiveMemoryWarning(notification: Notification) {
        updateMemoryUsage()
        onMemoryWarning?(currentUsage)
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
        // This is a stub implementation
        return 1024 * 1024 * 1024 // 1GB
    }
    
    /// Get total system memory in bytes
    func getTotalMemory() -> UInt64 {
        // This is a stub implementation
        return 16 * 1024 * 1024 * 1024 // 16GB
    }
}