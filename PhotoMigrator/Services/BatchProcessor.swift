import Foundation
import Combine

/// Main processor for handling batch operations with memory-efficient processing
class BatchProcessor {
    /// Current batch processing settings
    private var settings: BatchSettings
    
    /// Memory monitor for tracking resource usage
    private let memoryMonitor = MemoryMonitor.shared
    
    /// Batch size advisor for intelligent batch size adjustments
    private let batchSizeAdvisor: BatchSizeAdvisor
    
    /// Progress tracking
    private let progress: MigrationProgress
    
    /// Cancellation flag
    private var isCancelled = false
    
    /// Timer for tracking batch processing time
    private var batchTimer: Timer?
    
    /// Timestamp when the current batch started
    private var batchStartTime: Date?
    
    /// Set of cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Callback for logging events
    var onLogMessage: ((String) -> Void)?
    
    /// Initialize with settings
    init(settings: BatchSettings, progress: MigrationProgress) {
        self.settings = settings
        self.progress = progress
        
        // Configure memory monitor
        memoryMonitor.configureThresholds(
            mediumPressure: settings.highMemoryThreshold - 0.1,
            highPressure: settings.highMemoryThreshold,
            criticalPressure: settings.criticalMemoryThreshold
        )
        
        // Set up memory pressure handling
        memoryMonitor.onPressureChange = { [weak self] pressure in
            self?.handleMemoryPressureChange(pressure)
        }
        
        // Create batch size advisor
        let advisorConfig = BatchSizeAdvisor.Configuration(
            minBatchSize: BatchSettings.minimumBatchSize,
            maxBatchSize: 1000,
            defaultBatchSize: settings.batchSize,
            historyWindowSize: 10,
            smoothingFactor: 0.7,
            cooldownPeriod: 5.0,
            useMLPrediction: true
        )
        self.batchSizeAdvisor = BatchSizeAdvisor(
            configuration: advisorConfig,
            memoryMonitor: memoryMonitor
        )
        
        // Subscribe to batch size recommendations
        batchSizeAdvisor.recommendationPublisher
            .sink { [weak self] newSize in
                guard let self = self else { return }
                
                if newSize != self.settings.batchSize {
                    self.logMessage("Batch size advisor recommends changing from \(self.settings.batchSize) to \(newSize)")
                    
                    // Publish batch size adjustment event
                    BatchProgressPublisher.shared.publishBatchSizeAdjusted(
                        oldSize: self.settings.batchSize,
                        newSize: newSize,
                        reason: "Adaptive adjustment based on performance metrics"
                    )
                    
                    self.settings.batchSize = newSize
                    self.progress.batchSize = newSize
                }
            }
            .store(in: &cancellables)
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
    
    /// Process items in batches using a async/await approach
    /// - Parameters:
    ///   - items: The items to process
    ///   - processFunction: The function to process each batch
    /// - Returns: The collected results from all batches
    func processBatches<T, R>(
        items: [T],
        processFunction: ([T]) async throws -> [R]
    ) async throws -> [R] {
        guard !items.isEmpty else {
            logMessage("No items to process")
            return []
        }
        
        guard settings.isEnabled else {
            // If batch processing is disabled, process all at once
            logMessage("Batch processing disabled, processing all \(items.count) items at once")
            return try await processFunction(items)
        }
        
        var results: [R] = []
        var currentBatchSize = settings.batchSize
        
        // Start monitoring memory
        startMonitoring()
        defer { stopMonitoring() }
        
        // Apply ordering strategy if needed
        let orderedItems = applyOrderStrategy(items)
        
        // If grouping is enabled, process groups independently
        if settings.groupItemsByType, let groupableItems = orderedItems as? [GroupableItem] {
            logMessage("Processing items in groups by type")
            let groupedResults = try await processGroupedItems(groupableItems, processFunction: processFunction)
            return groupedResults
        }
        
        // Set up progress tracking
        let totalBatches = (orderedItems.count + currentBatchSize - 1) / currentBatchSize
        progress.totalBatches = totalBatches
        progress.batchSize = currentBatchSize
        progress.currentBatch = 0
        
        // Set up estimated time tracking
        let overallStartTime = Date()
        var processingTimes: [TimeInterval] = []
        
        // Process in batches
        for batchStart in stride(from: 0, to: orderedItems.count, by: currentBatchSize) {
            if isCancelled {
                logMessage("Processing cancelled")
                BatchProgressPublisher.shared.publishBatchCancelled()
                throw BatchProcessingError.cancelled
            }
            
            // Get updated batch size (may have changed due to advisor)
            currentBatchSize = settings.batchSize
            
            // Increment batch counter
            progress.currentBatch += 1
            
            // Get the current batch of items
            let batchEndIndex = min(batchStart + currentBatchSize, orderedItems.count)
            let batch = Array(orderedItems[batchStart..<batchEndIndex])
            
            // Log the current batch
            logMessage("Processing batch \(progress.currentBatch)/\(totalBatches) (\(batchStart)-\(batchEndIndex-1) of \(orderedItems.count) items)")
            
            // Publish batch started event
            BatchProgressPublisher.shared.publishBatchStarted(
                batchIndex: progress.currentBatch,
                totalBatches: totalBatches
            )
            
            // Start a timer for this batch if time limits are enabled
            if settings.useTimeLimits {
                startBatchTimer()
            }
            
            // Process this batch
            do {
                // Record batch start time for performance metrics
                let batchStartTime = Date()
                
                // Process the batch
                let batchResults = try await processFunction(batch)
                
                // Calculate processing time
                let processingTime = Date().timeIntervalSince(batchStartTime)
                processingTimes.append(processingTime)
                
                // Record metrics with the batch size advisor
                batchSizeAdvisor.recordBatchResult(
                    batchSize: currentBatchSize,
                    processingTime: processingTime,
                    items: batchResults.count
                )
                
                results.append(contentsOf: batchResults)
                
                // Stop the timer
                stopBatchTimer()
                
                // Log batch completion
                logMessage("Completed batch \(progress.currentBatch)/\(totalBatches) in \(String(format: "%.2f", processingTime)) seconds")
                
                // Publish batch completed event
                BatchProgressPublisher.shared.publishBatchCompleted(
                    batchIndex: progress.currentBatch,
                    totalBatches: totalBatches,
                    itemsProcessed: batchResults.count
                )
                
                // Publish individual item progress
                for (index, _) in batchResults.enumerated() {
                    let itemIndex = batchStart + index
                    let itemId = (batch[index] as? Identifiable)?.id.description
                    
                    // Only publish every N items to avoid flooding the system
                    if itemIndex % 5 == 0 || itemIndex == orderedItems.count - 1 {
                        BatchProgressPublisher.shared.publishItemProcessed(
                            index: itemIndex + 1,
                            total: orderedItems.count,
                            itemId: itemId
                        )
                    }
                }
                
                // Estimate remaining time if we have enough data
                if !processingTimes.isEmpty {
                    let averageTimePerBatch = processingTimes.reduce(0, +) / Double(processingTimes.count)
                    let remainingBatches = totalBatches - progress.currentBatch
                    let estimatedRemainingTime = averageTimePerBatch * Double(remainingBatches)
                    
                    // Publish estimated time remaining
                    BatchProgressPublisher.shared.publishEstimatedTimeRemaining(seconds: estimatedRemainingTime)
                }
                
                // Log memory usage if warnings enabled
                if settings.showMemoryWarnings {
                    let usagePercentage = Double(memoryMonitor.getCurrentMemoryUsage()) / Double(memoryMonitor.getTotalMemory()) * 100.0
                    logMessage("Current memory usage: \(memoryMonitor.getMemoryUsagePercentage()) (\(memoryMonitor.getFormattedMemoryUsage()))")
                    
                    // Publish memory usage
                    BatchProgressPublisher.shared.publishMemoryWarning(
                        level: memoryMonitor.currentPressure,
                        usagePercentage: usagePercentage
                    )
                }
                
                // Pause between batches for memory cleanup if needed
                if progress.currentBatch < totalBatches && settings.pauseBetweenBatches > 0 {
                    logMessage("Pausing for \(String(format: "%.1f", settings.pauseBetweenBatches)) seconds to allow memory cleanup")
                    
                    // Try to reduce memory usage
                    memoryMonitor.reduceMemoryUsage()
                    
                    // Publish pause event
                    BatchProgressPublisher.shared.publishBatchPaused(reason: "Memory cleanup between batches")
                    
                    // Pause between batches
                    try await Task.sleep(nanoseconds: UInt64(settings.pauseBetweenBatches * 1_000_000_000))
                    
                    // Publish resume event
                    BatchProgressPublisher.shared.publishBatchResumed()
                }
            } catch {
                // Stop the timer
                stopBatchTimer()
                
                // Publish batch error event
                BatchProgressPublisher.shared.publishBatchError(error: error)
                
                logMessage("Error processing batch \(progress.currentBatch): \(error.localizedDescription)")
                throw error
            }
        }
        
        // Calculate success/failure stats
        let totalProcessed = orderedItems.count
        let successful = results.count
        let failed = totalProcessed - successful
        
        // Publish processing completed event
        BatchProgressPublisher.shared.publishProcessingCompleted(
            totalProcessed: totalProcessed,
            successful: successful,
            failed: failed
        )
        
        return results
    }
    
    /// Process items grouped by type
    /// - Parameters:
    ///   - items: The items to process, which should conform to GroupableItem
    ///   - processFunction: The function to process each batch
    /// - Returns: The collected results from all batches
    private func processGroupedItems<T: GroupableItem, R>(
        _ items: [T],
        processFunction: ([T]) async throws -> [R]
    ) async throws -> [R] {
        // Group items by their type
        let groupedItems = Dictionary(grouping: items) { $0.groupType }
        var results: [R] = []
        
        // Calculate total batches across all groups
        var totalBatchCount = 0
        for (_, itemsInGroup) in groupedItems {
            totalBatchCount += (itemsInGroup.count + settings.batchSize - 1) / settings.batchSize
        }
        
        progress.totalBatches = totalBatchCount
        progress.currentBatch = 0
        
        // Process each group independently
        for (groupType, itemsInGroup) in groupedItems {
            logMessage("Processing group: \(groupType) with \(itemsInGroup.count) items")
            
            // Publish stage progress event
            BatchProgressPublisher.shared.publishStageProgress(
                stageName: "Processing \(groupType)",
                progress: 0.0
            )
            
            // Process this group in batches
            let groupResults = try await processBatches(items: itemsInGroup, processFunction: processFunction)
            results.append(contentsOf: groupResults)
            
            // Publish stage completion
            BatchProgressPublisher.shared.publishStageProgress(
                stageName: "Processing \(groupType)",
                progress: 1.0
            )
            
            // Allow memory cleanup between groups
            memoryMonitor.reduceMemoryUsage()
            try await Task.sleep(nanoseconds: UInt64(settings.pauseBetweenBatches * 1_000_000_000))
        }
        
        return results
    }
    
    /// Start a timer for the current batch
    private func startBatchTimer() {
        stopBatchTimer() // Ensure any existing timer is stopped
        
        batchStartTime = Date()
        
        batchTimer = Timer.scheduledTimer(withTimeInterval: settings.maxBatchProcessingTime, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Only consider this a timeout if we're still processing (timer wasn't cancelled properly)
            if self.batchTimer != nil {
                self.logMessage("⚠️ Batch time limit exceeded (\(self.settings.maxBatchProcessingTime) seconds)")
                
                // Publish timeout error
                BatchProgressPublisher.shared.publishBatchError(
                    error: BatchProcessingError.timeout,
                    recoverable: true
                )
            }
        }
    }
    
    /// Stop the batch timer
    private func stopBatchTimer() {
        batchTimer?.invalidate()
        batchTimer = nil
        
        // Report batch processing time if we had a start time
        if let startTime = batchStartTime {
            let processingTime = Date().timeIntervalSince(startTime)
            logMessage("Batch processing time: \(String(format: "%.2f", processingTime)) seconds")
            batchStartTime = nil
        }
    }
    
    /// Apply ordering strategy to items if needed
    private func applyOrderStrategy<T>(_ items: [T]) -> [T] {
        guard !items.isEmpty else { return items }
        
        switch settings.orderStrategy {
        case .none:
            return items
            
        case .byTimestampAscending:
            if let timestampItems = items as? [TimeStampProvider] {
                return timestampItems.sorted { $0.timestamp < $1.timestamp } as! [T]
            }
            
        case .byTimestampDescending:
            if let timestampItems = items as? [TimeStampProvider] {
                return timestampItems.sorted { $0.timestamp > $1.timestamp } as! [T]
            }
            
        case .byFileSizeAscending:
            if let sizeItems = items as? [FileSizeProvider] {
                return sizeItems.sorted { $0.fileSize < $1.fileSize } as! [T]
            }
            
        case .byFileSizeDescending:
            if let sizeItems = items as? [FileSizeProvider] {
                return sizeItems.sorted { $0.fileSize > $1.fileSize } as! [T]
            }
            
        case .random:
            return items.shuffled()
        }
        
        // Default to original order if strategy can't be applied
        return items
    }
    
    /// Handle memory pressure change
    private func handleMemoryPressureChange(_ pressure: MemoryMonitor.MemoryPressure) {
        // Update progress with current memory usage
        let memoryUsagePercentage = Double(memoryMonitor.getCurrentMemoryUsage()) / Double(memoryMonitor.getTotalMemory()) * 100.0
        
        DispatchQueue.main.async {
            self.progress.updateMemoryUsage(
                percentage: memoryUsagePercentage,
                isUnderPressure: pressure != .normal
            )
        }
        
        // Publish memory warning event
        BatchProgressPublisher.shared.publishMemoryWarning(
            level: pressure,
            usagePercentage: memoryUsagePercentage
        )
        
        // Log memory pressure change
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
            
        case .critical:
            logMessage("⚠️ CRITICAL memory pressure detected (\(memoryMonitor.getMemoryUsagePercentage()))")
            
            // Force GC more aggressively
            memoryMonitor.reduceMemoryUsage()
            
            // Batch advisor will auto-reduce the batch size, but ensure it happens immediately
            // for critical pressure situations
            if settings.batchSize > BatchSettings.minimumBatchSize * 2 {
                BatchProgressPublisher.shared.publishBatchSizeAdjusted(
                    oldSize: settings.batchSize,
                    newSize: BatchSettings.minimumBatchSize,
                    reason: "Critical memory pressure detected"
                )
                
                settings.batchSize = BatchSettings.minimumBatchSize
                progress.batchSize = settings.batchSize
                logMessage("Reducing batch size to minimum (\(settings.batchSize)) due to critical memory pressure")
            }
        }
    }
    
    /// Log a message
    private func logMessage(_ message: String) {
        onLogMessage?(message)
    }
    
    /// Cancel batch processing
    func cancel() {
        isCancelled = true
        stopBatchTimer()
        BatchProgressPublisher.shared.publishBatchCancelled()
    }
    
    /// Reset the processor state
    func reset() {
        isCancelled = false
        batchSizeAdvisor.reset()
    }
}

// MARK: - Supporting Types

/// Progress updates for batch processing
enum BatchProgressUpdate {
    case batchStarted(currentBatch: Int, totalBatches: Int)
    case batchCompleted(currentBatch: Int, totalBatches: Int, itemsProcessed: Int)
    case batchError(error: Error)
    case batchTimeExceeded(timeLimit: TimeInterval)
    case pauseBetweenBatches(duration: TimeInterval)
    case memoryWarning(pressure: MemoryMonitor.MemoryPressure, usagePercentage: String)
    case batchSizeChanged(newSize: Int)
    case processingCompleted(totalItemsProcessed: Int)
    case processingCancelled
}

/// Errors that can occur during batch processing
enum BatchProcessingError: Error {
    case cancelled
    case memoryPressure
    case timeout
}

/// Protocol for items that have a timestamp
protocol TimeStampProvider {
    var timestamp: Date { get }
}

/// Protocol for items that have a file size
protocol FileSizeProvider {
    var fileSize: Int64 { get }
}

/// Protocol for items that can be grouped by type
protocol GroupableItem {
    var groupType: String { get }
} 