import Foundation

/// Manages batch processing for large photo libraries
class BatchProcessingManager {
    /// Current batch processing settings
    private var settings: BatchSettings
    
    /// Current memory monitor instance
    private let memoryMonitor = MemoryMonitor.shared
    
    /// Migration progress tracking
    private let progress: MigrationProgress
    
    /// Flag for cancellation
    private var isCancelled = false
    
    /// Callback for logging events
    var onLogMessage: ((String) -> Void)?
    
    /// Initialize with settings
    init(settings: BatchSettings, progress: MigrationProgress) {
        self.settings = settings
        self.progress = progress
        
        // Configure memory monitor
        memoryMonitor.configureThresholds(
            highPressure: settings.highMemoryThreshold,
            criticalPressure: settings.criticalMemoryThreshold
        )
        
        // Set up memory pressure handling
        memoryMonitor.onPressureChange = { [weak self] pressure in
            self?.handleMemoryPressureChange(pressure)
        }
    }
    
    /// Start memory monitoring
    func startMonitoring() {
        memoryMonitor.resetPeakUsage()
        memoryMonitor.startMonitoring(checkInterval: 1.0)
    }
    
    /// Stop memory monitoring
    func stopMonitoring() {
        memoryMonitor.stopMonitoring()
        
        // Update progress with peak memory usage
        progress.peakMemoryUsage = memoryMonitor.peakMemoryUsage
    }
    
    /// Process an array of items in batches
    /// - Parameters:
    ///   - items: All items to process
    ///   - processFunction: The function to process each batch
    /// - Returns: A tuple containing the success count and any errors
    func processBatches<T, R>(
        items: [T],
        processFunction: ([T]) async throws -> [R]
    ) async throws -> [R] {
        
        guard settings.isEnabled else {
            // If batch processing is disabled, process all at once
            return try await processFunction(items)
        }
        
        var results: [R] = []
        var currentBatchSize = settings.batchSize
        
        // Start monitoring memory
        startMonitoring()
        defer { stopMonitoring() }
        
        // Set up progress tracking
        let totalBatches = (items.count + currentBatchSize - 1) / currentBatchSize
        progress.totalBatches = totalBatches
        progress.batchSize = currentBatchSize
        progress.currentBatch = 0
        
        // Process in batches
        for batchStart in stride(from: 0, to: items.count, by: currentBatchSize) {
            if isCancelled {
                break
            }
            
            // Increment batch counter
            progress.currentBatch += 1
            
            // Log the current batch
            let endIndex = min(batchStart + currentBatchSize, items.count)
            logMessage("Processing batch \(progress.currentBatch)/\(totalBatches) (\(batchStart)-\(endIndex-1) of \(items.count) items)")
            
            // Get the current batch of items
            let batchEndIndex = min(batchStart + currentBatchSize, items.count)
            let batch = Array(items[batchStart..<batchEndIndex])
            
            // Process this batch
            do {
                let batchResults = try await processFunction(batch)
                results.append(contentsOf: batchResults)
                
                // Log batch completion
                logMessage("Completed batch \(progress.currentBatch)/\(totalBatches)")
                
                // Log memory usage if warnings enabled
                if settings.showMemoryWarnings {
                    logMessage("Current memory usage: \(memoryMonitor.getMemoryUsagePercentage()) (\(memoryMonitor.getFormattedMemoryUsage()))")
                }
                
                // If adaptive sizing is enabled, adjust batch size based on memory pressure
                if settings.useAdaptiveSizing {
                    let recommendedSize = memoryMonitor.recommendedBatchSize(currentBatchSize: currentBatchSize)
                    if recommendedSize < currentBatchSize {
                        logMessage("Adjusting batch size from \(currentBatchSize) to \(recommendedSize) due to memory pressure")
                        currentBatchSize = recommendedSize
                        progress.batchSize = currentBatchSize
                    }
                }
                
                // Pause between batches for memory cleanup if needed
                if progress.currentBatch < totalBatches && settings.pauseBetweenBatches > 0 {
                    logMessage("Pausing for \(String(format: "%.1f", settings.pauseBetweenBatches)) seconds to allow memory cleanup")
                    
                    // Try to reduce memory usage
                    memoryMonitor.reduceMemoryUsage()
                    
                    // Pause between batches
                    try await Task.sleep(nanoseconds: UInt64(settings.pauseBetweenBatches * 1_000_000_000))
                }
            } catch {
                logMessage("Error processing batch \(progress.currentBatch): \(error.localizedDescription)")
                throw error
            }
        }
        
        return results
    }
    
    /// Handle memory pressure change
    private func handleMemoryPressureChange(_ pressure: MemoryMonitor.MemoryPressure) {
        switch pressure {
        case .normal:
            // No action needed
            break
        case .medium:
            if settings.showMemoryWarnings {
                logMessage("Medium memory pressure detected (\(memoryMonitor.getMemoryUsagePercentage()))")
            }
        case .high:
            logMessage("⚠️ High memory pressure detected (\(memoryMonitor.getMemoryUsagePercentage()))")
            
            // Force GC
            memoryMonitor.reduceMemoryUsage()
            
            // If adaptive sizing is enabled, reduce batch size
            if settings.useAdaptiveSizing {
                settings.batchSize = memoryMonitor.recommendedBatchSize(currentBatchSize: settings.batchSize)
                progress.batchSize = settings.batchSize
                logMessage("Reducing batch size to \(settings.batchSize) due to memory pressure")
            }
        case .critical:
            logMessage("⚠️ CRITICAL memory pressure detected (\(memoryMonitor.getMemoryUsagePercentage()))")
            
            // Force GC more aggressively
            memoryMonitor.reduceMemoryUsage()
            
            // Reduce batch size to minimum regardless of settings
            settings.batchSize = BatchSettings.minimumBatchSize
            progress.batchSize = settings.batchSize
            logMessage("Reducing batch size to minimum (\(settings.batchSize)) due to critical memory pressure")
        }
    }
    
    /// Log a message
    private func logMessage(_ message: String) {
        onLogMessage?(message)
    }
    
    /// Cancel batch processing
    func cancel() {
        isCancelled = true
    }
}