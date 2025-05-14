import Foundation

/// Settings for batch processing of large photo libraries
struct BatchSettings {
    /// Default batch size for processing
    static let defaultBatchSize = 250
    
    /// Minimum batch size (to ensure progress)
    static let minimumBatchSize = 5
    
    /// Default maximum time for a batch to process (in seconds)
    static let defaultMaxBatchTime: TimeInterval = 60.0
    
    /// Whether batch processing is enabled
    var isEnabled: Bool = true
    
    /// Number of items to process in each batch
    var batchSize: Int = defaultBatchSize
    
    /// Maximum time to spend processing a single batch (in seconds)
    /// If this time is exceeded, the batch is considered complete and the next batch starts
    var maxBatchProcessingTime: TimeInterval = defaultMaxBatchTime
    
    /// Whether to use time-based batch limits
    var useTimeLimits: Bool = true
    
    /// Whether to group items by type in batches
    var groupItemsByType: Bool = false
    
    /// Whether to prioritize items based on importance
    var usePrioritization: Bool = false
    
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
    
    /// Order strategy for items within a batch
    enum OrderStrategy {
        case none
        case byTimestampAscending
        case byTimestampDescending
        case byFileSizeAscending // Process smaller files first
        case byFileSizeDescending // Process larger files first
        case random // Randomize for diverse resource utilization
    }
    
    /// Strategy for ordering items within batches
    var orderStrategy: OrderStrategy = .none
    
    /// Initialize with default settings
    init() {}
    
    /// Initialize with custom settings
    init(isEnabled: Bool, 
         batchSize: Int, 
         useAdaptiveSizing: Bool = true, 
         highMemoryThreshold: Double = 0.8, 
         criticalMemoryThreshold: Double = 0.9,
         pauseBetweenBatches: TimeInterval = 2.0, 
         showMemoryWarnings: Bool = true,
         maxBatchProcessingTime: TimeInterval = defaultMaxBatchTime,
         useTimeLimits: Bool = true,
         groupItemsByType: Bool = false,
         usePrioritization: Bool = false,
         orderStrategy: OrderStrategy = .none) {
        
        self.isEnabled = isEnabled
        self.batchSize = max(BatchSettings.minimumBatchSize, batchSize)
        self.useAdaptiveSizing = useAdaptiveSizing
        self.highMemoryThreshold = highMemoryThreshold
        self.criticalMemoryThreshold = criticalMemoryThreshold
        self.pauseBetweenBatches = pauseBetweenBatches
        self.showMemoryWarnings = showMemoryWarnings
        self.maxBatchProcessingTime = maxBatchProcessingTime
        self.useTimeLimits = useTimeLimits
        self.groupItemsByType = groupItemsByType
        self.usePrioritization = usePrioritization
        self.orderStrategy = orderStrategy
    }
    
    /// Get system-recommended settings based on available memory
    static func recommendedSettings() -> BatchSettings {
        var settings = BatchSettings()
        
        // Get total system memory
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        // Adjust batch size based on system memory
        if totalMemory >= 32 * 1024 * 1024 * 1024 { // 32 GB or more
            settings.batchSize = 500
            settings.maxBatchProcessingTime = 120.0
        } else if totalMemory >= 16 * 1024 * 1024 * 1024 { // 16 GB
            settings.batchSize = 300
            settings.maxBatchProcessingTime = 90.0
        } else if totalMemory >= 8 * 1024 * 1024 * 1024 { // 8 GB
            settings.batchSize = 150
            settings.maxBatchProcessingTime = 60.0
        } else { // Less than 8 GB
            settings.batchSize = 75
            settings.maxBatchProcessingTime = 45.0
            settings.groupItemsByType = true // Group by type to optimize memory usage
        }
        
        return settings
    }
}