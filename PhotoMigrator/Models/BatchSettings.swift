import Foundation

/// Settings for batch processing of large photo libraries
struct BatchSettings {
    /// Default batch size for processing
    static let defaultBatchSize = 250
    
    /// Minimum batch size (to ensure progress)
    static let minimumBatchSize = 5
    
    /// Whether batch processing is enabled
    var isEnabled: Bool = true
    
    /// Number of items to process in each batch
    var batchSize: Int = defaultBatchSize
    
    /// Whether to use adaptive batch sizing (reduces batch size under memory pressure)
    var useAdaptiveSizing: Bool = true
    
    /// High memory pressure threshold (percentage of total memory, 0.0-1.0)
    var highMemoryThreshold: Double = 0.8
    
    /// Critical memory pressure threshold (percentage of total memory, 0.0-1.0)
    var criticalMemoryThreshold: Double = 0.9
    
    /// Pause time between batches (in seconds) to allow memory cleanup
    var pauseBetweenBatches: TimeInterval = 2.0
    
    /// Whether to show memory usage warnings
    var showMemoryWarnings: Bool = true
    
    /// Initialize with default settings
    init() {}
    
    /// Initialize with custom settings
    init(isEnabled: Bool, batchSize: Int, useAdaptiveSizing: Bool = true, 
         highMemoryThreshold: Double = 0.8, criticalMemoryThreshold: Double = 0.9,
         pauseBetweenBatches: TimeInterval = 2.0, showMemoryWarnings: Bool = true) {
        self.isEnabled = isEnabled
        self.batchSize = max(BatchSettings.minimumBatchSize, batchSize)
        self.useAdaptiveSizing = useAdaptiveSizing
        self.highMemoryThreshold = highMemoryThreshold
        self.criticalMemoryThreshold = criticalMemoryThreshold
        self.pauseBetweenBatches = pauseBetweenBatches
        self.showMemoryWarnings = showMemoryWarnings
    }
    
    /// Get system-recommended settings based on available memory
    static func recommendedSettings() -> BatchSettings {
        var settings = BatchSettings()
        
        // Get total system memory
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        // Adjust batch size based on system memory
        if totalMemory >= 32 * 1024 * 1024 * 1024 { // 32 GB or more
            settings.batchSize = 500
        } else if totalMemory >= 16 * 1024 * 1024 * 1024 { // 16 GB
            settings.batchSize = 300
        } else if totalMemory >= 8 * 1024 * 1024 * 1024 { // 8 GB
            settings.batchSize = 150
        } else { // Less than 8 GB
            settings.batchSize = 75
        }
        
        return settings
    }
}