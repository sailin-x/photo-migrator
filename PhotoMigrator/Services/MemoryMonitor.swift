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
        
        /// Get description of pressure state
        var description: String {
            switch self {
            case .normal: return "Normal"
            case .medium: return "Medium"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
    }
    
    /// Delegate for memory monitor events
    protocol MemoryMonitorDelegate: AnyObject {
        /// Called when memory pressure changes
        func memoryMonitor(_ monitor: MemoryMonitor, didChangePressure pressure: MemoryPressure)
        
        /// Called when memory usage exceeds thresholds
        func memoryMonitor(_ monitor: MemoryMonitor, didExceedThreshold thresholdType: String, withValue value: Double)
        
        /// Called when a cleanup action is recommended
        func memoryMonitorRecommendsCleanup(_ monitor: MemoryMonitor, withPriority priority: MemoryPressure)
    }
    
    /// Configuration for memory monitoring
    struct Configuration {
        /// Threshold in percentage (0.0-1.0) for medium pressure
        var mediumPressureThreshold: Double = 0.7
        
        /// Threshold in percentage (0.0-1.0) for high pressure
        var highPressureThreshold: Double = 0.8
        
        /// Threshold in percentage (0.0-1.0) for critical pressure
        var criticalPressureThreshold: Double = 0.9
        
        /// Check interval for monitoring in seconds
        var checkInterval: TimeInterval = 0.5
        
        /// Whether to use system memory pressure notifications
        var useSystemNotifications: Bool = true
        
        /// Whether to warn about memory usage exceeding thresholds
        var enableWarnings: Bool = true
        
        /// Whether to automatically attempt cleanup on high pressure
        var autoCleanupEnabled: Bool = true
    }
    
    /// Detailed memory usage information
    struct MemoryUsageInfo {
        /// Total physical memory in bytes
        let totalMemory: UInt64
        
        /// Current resident memory in bytes (actual RAM usage)
        let residentMemory: UInt64
        
        /// Current virtual memory in bytes
        let virtualMemory: UInt64
        
        /// Shared memory in bytes
        let sharedMemory: UInt64
        
        /// Compressed memory in bytes
        let compressedMemory: UInt64
        
        /// Purgeable memory in bytes
        let purgeableMemory: UInt64
        
        /// Percentage of total memory being used
        var usagePercentage: Double {
            return Double(residentMemory) / Double(totalMemory)
        }
        
        /// Nicely formatted usage percentage string
        var formattedPercentage: String {
            return String(format: "%.1f%%", usagePercentage * 100)
        }
    }
    
    /// Current memory pressure level
    private(set) var currentPressure: MemoryPressure = .normal
    
    /// Peak memory usage since last reset
    private(set) var peakMemoryUsage: UInt64 = 0
    
    /// Current memory usage details
    private(set) var currentUsage: MemoryUsageInfo?
    
    /// Configuration for the memory monitor
    var configuration = Configuration()
    
    /// Timer for periodic memory checks
    private var monitoringTimer: Timer?
    
    /// Dispatch source for memory pressure notifications
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    /// Serial queue for memory monitor operations
    private let monitorQueue = DispatchQueue(label: "com.photomigrator.memorymonitor", qos: .utility)
    
    /// Callback for memory pressure changes
    var onPressureChange: ((MemoryPressure) -> Void)?
    
    /// Delegate for monitor events
    weak var delegate: MemoryMonitorDelegate?
    
    /// Registered cleanup handlers
    private var cleanupHandlers: [(MemoryPressure) -> Void] = []
    
    private init() {
        // Private initializer for singleton
        
        // Register for system notifications if available
        setupSystemNotifications()
    }
    
    /// Set up system memory pressure notifications
    private func setupSystemNotifications() {
        // Create a memory pressure dispatch source
        let memorySource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical, .normal])
        
        memorySource.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            // Get the memory pressure level
            let pressure: MemoryPressure
            switch memorySource.memoryPressureEvent {
            case .normal:
                pressure = .normal
            case .warning:
                pressure = .high
            case .critical:
                pressure = .critical
            @unknown default:
                pressure = .medium
            }
            
            // Update pressure on main queue
            DispatchQueue.main.async {
                self.updatePressure(pressure)
            }
        }
        
        // Start the source
        memorySource.resume()
        
        // Save the source
        memoryPressureSource = memorySource
        
        // Register for app-level notifications
        #if os(iOS) || os(tvOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif
    }
    
    /// Handle memory warning notification
    @objc private func handleMemoryWarning() {
        updatePressure(.high)
        performCleanup(for: .high)
    }
    
    /// Update the current pressure level
    private func updatePressure(_ pressure: MemoryPressure) {
        let oldPressure = currentPressure
        currentPressure = pressure
        
        // Notify if pressure level changed
        if oldPressure != currentPressure {
            onPressureChange?(currentPressure)
            delegate?.memoryMonitor(self, didChangePressure: currentPressure)
            
            // Attempt cleanup if enabled
            if configuration.autoCleanupEnabled && (pressure == .high || pressure == .critical) {
                performCleanup(for: pressure)
            }
        }
    }
    
    /// Start monitoring memory usage
    func startMonitoring(checkInterval: TimeInterval = 2.0) {
        stopMonitoring()
        
        configuration.checkInterval = checkInterval
        
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
    
    /// Register a cleanup handler to be called during memory pressure
    func registerCleanupHandler(_ handler: @escaping (MemoryPressure) -> Void) {
        monitorQueue.sync {
            cleanupHandlers.append(handler)
        }
    }
    
    /// Perform cleanup based on pressure level
    func performCleanup(for pressure: MemoryPressure) {
        // Notify delegate
        delegate?.memoryMonitorRecommendsCleanup(self, withPriority: pressure)
        
        // Call registered handlers
        monitorQueue.async {
            for handler in self.cleanupHandlers {
                handler(pressure)
            }
        }
        
        // Basic cleanup
        reduceMemoryUsage()
    }
    
    /// Get detailed memory usage information
    func getMemoryUsageInfo() -> MemoryUsageInfo {
        return monitorQueue.sync {
            fetchDetailedMemoryInfo()
        }
    }
    
    /// Fetch detailed memory information using task_vm_info
    private func fetchDetailedMemoryInfo() -> MemoryUsageInfo {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let kern = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        var residentMemory: UInt64 = 0
        var virtualMemory: UInt64 = 0
        var sharedMemory: UInt64 = 0
        var compressedMemory: UInt64 = 0
        var purgeableMemory: UInt64 = 0
        
        if kern == KERN_SUCCESS {
            residentMemory = UInt64(taskInfo.resident_size)
            virtualMemory = UInt64(taskInfo.virtual_size)
            sharedMemory = UInt64(taskInfo.phys_footprint - taskInfo.internal_compressed - taskInfo.internal)
            compressedMemory = UInt64(taskInfo.internal_compressed)
            purgeableMemory = UInt64(taskInfo.purgeable_size)
        } else {
            // Fallback to basic info if advanced info is not available
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
            
            let kerr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                }
            }
            
            if kerr == KERN_SUCCESS {
                residentMemory = info.resident_size
                virtualMemory = info.virtual_size
            }
        }
        
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        return MemoryUsageInfo(
            totalMemory: totalMemory,
            residentMemory: residentMemory,
            virtualMemory: virtualMemory,
            sharedMemory: sharedMemory,
            compressedMemory: compressedMemory,
            purgeableMemory: purgeableMemory
        )
    }
    
    /// Get current memory usage in bytes
    func getCurrentMemoryUsage() -> UInt64 {
        if let usage = currentUsage {
            return usage.residentMemory
        }
        
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
    
    /// Get current virtual memory usage in bytes
    func getCurrentVirtualMemory() -> UInt64 {
        return currentUsage?.virtualMemory ?? 0
    }
    
    /// Get current shared memory in bytes
    func getCurrentSharedMemory() -> UInt64 {
        return currentUsage?.sharedMemory ?? 0
    }
    
    /// Get current compressed memory in bytes
    func getCurrentCompressedMemory() -> UInt64 {
        return currentUsage?.compressedMemory ?? 0
    }
    
    /// Get total physical memory in bytes
    func getTotalMemory() -> UInt64 {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        return totalMemory
    }
    
    /// Check current memory usage and update pressure state
    private func checkMemoryUsage() {
        monitorQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Get detailed memory information
            let usageInfo = self.fetchDetailedMemoryInfo()
            self.currentUsage = usageInfo
            
            // Update peak memory usage if current usage is higher
            if usageInfo.residentMemory > self.peakMemoryUsage {
                self.peakMemoryUsage = usageInfo.residentMemory
            }
            
            let usageRatio = usageInfo.usagePercentage
            let oldPressure = self.currentPressure
            
            // Determine memory pressure level based on configuration thresholds
            let newPressure: MemoryPressure
            if usageRatio >= self.configuration.criticalPressureThreshold {
                newPressure = .critical
            } else if usageRatio >= self.configuration.highPressureThreshold {
                newPressure = .high
            } else if usageRatio >= self.configuration.mediumPressureThreshold {
                newPressure = .medium
            } else {
                newPressure = .normal
            }
            
            // Only update on main thread if pressure changed
            if oldPressure != newPressure {
                DispatchQueue.main.async {
                    self.updatePressure(newPressure)
                }
            }
            
            // Update usage on main thread
            DispatchQueue.main.async {
                // Check if any thresholds are being exceeded
                if self.configuration.enableWarnings {
                    if usageRatio >= self.configuration.criticalPressureThreshold {
                        self.delegate?.memoryMonitor(self, didExceedThreshold: "Critical", withValue: usageRatio)
                    } else if usageRatio >= self.configuration.highPressureThreshold {
                        self.delegate?.memoryMonitor(self, didExceedThreshold: "High", withValue: usageRatio)
                    } else if usageRatio >= self.configuration.mediumPressureThreshold {
                        self.delegate?.memoryMonitor(self, didExceedThreshold: "Medium", withValue: usageRatio)
                    }
                }
            }
        }
    }
    
    /// Configure thresholds for memory pressure levels
    func configureThresholds(mediumPressure: Double? = nil, highPressure: Double? = nil, criticalPressure: Double? = nil) {
        // Apply any provided values, using existing values as defaults
        if let medium = mediumPressure {
            configuration.mediumPressureThreshold = max(0.5, min(0.8, medium))
        }
        
        if let high = highPressure {
            configuration.highPressureThreshold = max(configuration.mediumPressureThreshold + 0.05, min(0.9, high))
        }
        
        if let critical = criticalPressure {
            configuration.criticalPressureThreshold = max(configuration.highPressureThreshold + 0.05, min(0.95, critical))
        }
    }
    
    /// Get formatted memory usage string
    func getFormattedMemoryUsage() -> String {
        let usage = getCurrentMemoryUsage()
        return formatMemorySize(usage)
    }
    
    /// Get formatted memory usage breakdown
    func getFormattedMemoryBreakdown() -> String {
        guard let usage = currentUsage else {
            return "Memory usage: \(getFormattedMemoryUsage())"
        }
        
        var output = "Memory usage: \(formatMemorySize(usage.residentMemory)) (\(usage.formattedPercentage))\n"
        output += "- Shared: \(formatMemorySize(usage.sharedMemory))\n"
        output += "- Compressed: \(formatMemorySize(usage.compressedMemory))\n"
        output += "- Purgeable: \(formatMemorySize(usage.purgeableMemory))\n"
        output += "- Virtual: \(formatMemorySize(usage.virtualMemory))"
        
        return output
    }
    
    /// Get formatted memory usage percentage
    func getMemoryUsagePercentage() -> String {
        if let usage = currentUsage {
            return usage.formattedPercentage
        }
        
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
        monitorQueue.async {
            // Suggest Swift runtime to collect garbage (best effort)
            #if os(macOS)
            // Request low memory cleanup
            let selector = NSSelectorFromString("performSelectorOnMainThread:withObject:waitUntilDone:")
            NSObject.perform(selector, with: nil, with: nil)
            #endif
            
            // Force autoreleasepool cleanup
            autoreleasepool {
                // Empty pool to force cleanup
            }
            
            // Try to force memory compaction
            #if swift(>=5.1)
            if #available(iOS 15.0, macOS 12.0, *) {
                Task {
                    // Attempt to reduce memory footprint
                    await Task.yield()
                    await Task.yield()
                }
            }
            #endif
        }
    }
    
    /// Get a dictionary of memory statistics for debugging
    func getMemoryStatsDictionary() -> [String: String] {
        guard let usage = currentUsage else {
            return ["Total": formatMemorySize(getTotalMemory()),
                    "Current": formatMemorySize(getCurrentMemoryUsage()),
                    "Peak": formatMemorySize(peakMemoryUsage),
                    "Percentage": getMemoryUsagePercentage(),
                    "Pressure": currentPressure.description]
        }
        
        return ["Total": formatMemorySize(usage.totalMemory),
                "Resident": formatMemorySize(usage.residentMemory),
                "Virtual": formatMemorySize(usage.virtualMemory),
                "Shared": formatMemorySize(usage.sharedMemory),
                "Compressed": formatMemorySize(usage.compressedMemory),
                "Purgeable": formatMemorySize(usage.purgeableMemory),
                "Peak": formatMemorySize(peakMemoryUsage),
                "Percentage": usage.formattedPercentage,
                "Pressure": currentPressure.description]
    }
}