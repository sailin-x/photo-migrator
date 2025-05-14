import Foundation
import Combine
import SwiftUI

/// Detailed progress event for batch processing operations
enum BatchProgressEvent: Equatable {
    /// Batch processing has started
    case batchStarted(batchIndex: Int, totalBatches: Int)
    
    /// Batch processing is at a specific stage
    case stageProgress(stageName: String, progress: Double)
    
    /// A specific item has been processed
    case itemProcessed(index: Int, total: Int, itemId: String?)
    
    /// Estimated time remaining for batch processing
    case estimatedTimeRemaining(seconds: TimeInterval)
    
    /// Batch has completed processing
    case batchCompleted(batchIndex: Int, totalBatches: Int, itemsProcessed: Int)
    
    /// Memory warning detected
    case memoryWarning(level: MemoryMonitor.MemoryPressure, usagePercentage: Double)
    
    /// Batch size has been adjusted
    case batchSizeAdjusted(oldSize: Int, newSize: Int, reason: String)
    
    /// An error occurred during batch processing
    case batchError(error: Error, recoverable: Bool)
    
    /// Batch processing has been paused
    case batchPaused(reason: String)
    
    /// Batch processing has been resumed
    case batchResumed
    
    /// Batch processing has been cancelled
    case batchCancelled
    
    /// Overall process has completed
    case processingCompleted(totalProcessed: Int, successful: Int, failed: Int)
    
    /// Static method to compare events for Equatable conformance
    static func == (lhs: BatchProgressEvent, rhs: BatchProgressEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.batchStarted(lIndex, lTotal), .batchStarted(rIndex, rTotal)):
            return lIndex == rIndex && lTotal == rTotal
            
        case let (.stageProgress(lName, lProgress), .stageProgress(rName, rProgress)):
            return lName == rName && abs(lProgress - rProgress) < 0.001
            
        case let (.itemProcessed(lIndex, lTotal, lId), .itemProcessed(rIndex, rTotal, rId)):
            return lIndex == rIndex && lTotal == rTotal && lId == rId
            
        case let (.estimatedTimeRemaining(lSec), .estimatedTimeRemaining(rSec)):
            return abs(lSec - rSec) < 1 // Within 1 second is close enough
            
        case let (.batchCompleted(lIndex, lTotal, lItems), .batchCompleted(rIndex, rTotal, rItems)):
            return lIndex == rIndex && lTotal == rTotal && lItems == rItems
            
        case let (.memoryWarning(lLevel, _), .memoryWarning(rLevel, _)):
            return lLevel == rLevel
            
        case let (.batchSizeAdjusted(lOld, lNew, _), .batchSizeAdjusted(rOld, rNew, _)):
            return lOld == rOld && lNew == rNew
            
        case let (.batchError(lError, lRec), .batchError(rError, rRec)):
            return lRec == rRec && String(describing: lError) == String(describing: rError)
            
        case let (.batchPaused(lReason), .batchPaused(rReason)):
            return lReason == rReason
            
        case (.batchResumed, .batchResumed),
             (.batchCancelled, .batchCancelled):
            return true
            
        case let (.processingCompleted(lTotal, lSuccess, lFail), .processingCompleted(rTotal, rSuccess, rFail)):
            return lTotal == rTotal && lSuccess == rSuccess && lFail == rFail
            
        default:
            return false
        }
    }
}

/// Centralized manager for batch progress events
class BatchProgressPublisher {
    /// Shared instance
    static let shared = BatchProgressPublisher()
    
    /// Main subject for publishing all batch progress events
    private let eventSubject = PassthroughSubject<BatchProgressEvent, Never>()
    
    /// Publisher for all batch progress events
    var eventPublisher: AnyPublisher<BatchProgressEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for batch started events
    var batchStartedPublisher: AnyPublisher<(batchIndex: Int, totalBatches: Int), Never> {
        eventSubject
            .compactMap { event -> (batchIndex: Int, totalBatches: Int)? in
                if case let .batchStarted(batchIndex, totalBatches) = event {
                    return (batchIndex, totalBatches)
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for stage progress events
    var stageProgressPublisher: AnyPublisher<(stageName: String, progress: Double), Never> {
        eventSubject
            .compactMap { event -> (stageName: String, progress: Double)? in
                if case let .stageProgress(stageName, progress) = event {
                    return (stageName, progress)
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for item processed events
    var itemProcessedPublisher: AnyPublisher<(index: Int, total: Int, itemId: String?), Never> {
        eventSubject
            .compactMap { event -> (index: Int, total: Int, itemId: String?)? in
                if case let .itemProcessed(index, total, itemId) = event {
                    return (index, total, itemId)
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for estimated time remaining events
    var timeRemainingPublisher: AnyPublisher<TimeInterval, Never> {
        eventSubject
            .compactMap { event -> TimeInterval? in
                if case let .estimatedTimeRemaining(seconds) = event {
                    return seconds
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for batch completed events
    var batchCompletedPublisher: AnyPublisher<(batchIndex: Int, totalBatches: Int, itemsProcessed: Int), Never> {
        eventSubject
            .compactMap { event -> (batchIndex: Int, totalBatches: Int, itemsProcessed: Int)? in
                if case let .batchCompleted(batchIndex, totalBatches, itemsProcessed) = event {
                    return (batchIndex, totalBatches, itemsProcessed)
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for memory warning events
    var memoryWarningPublisher: AnyPublisher<(level: MemoryMonitor.MemoryPressure, usagePercentage: Double), Never> {
        eventSubject
            .compactMap { event -> (level: MemoryMonitor.MemoryPressure, usagePercentage: Double)? in
                if case let .memoryWarning(level, usagePercentage) = event {
                    return (level, usagePercentage)
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for batch size adjusted events
    var batchSizeAdjustedPublisher: AnyPublisher<(oldSize: Int, newSize: Int, reason: String), Never> {
        eventSubject
            .compactMap { event -> (oldSize: Int, newSize: Int, reason: String)? in
                if case let .batchSizeAdjusted(oldSize, newSize, reason) = event {
                    return (oldSize, newSize, reason)
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for batch error events
    var batchErrorPublisher: AnyPublisher<(error: Error, recoverable: Bool), Never> {
        eventSubject
            .compactMap { event -> (error: Error, recoverable: Bool)? in
                if case let .batchError(error, recoverable) = event {
                    return (error, recoverable)
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for processing completed events
    var processingCompletedPublisher: AnyPublisher<(totalProcessed: Int, successful: Int, failed: Int), Never> {
        eventSubject
            .compactMap { event -> (totalProcessed: Int, successful: Int, failed: Int)? in
                if case let .processingCompleted(totalProcessed, successful, failed) = event {
                    return (totalProcessed, successful, failed)
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for all status events (started, paused, resumed, cancelled, completed)
    var statusPublisher: AnyPublisher<BatchProcessingStatus, Never> {
        eventSubject
            .compactMap { event -> BatchProcessingStatus? in
                switch event {
                case .batchStarted:
                    return .processing
                case .batchPaused:
                    return .paused
                case .batchResumed:
                    return .processing
                case .batchCancelled:
                    return .cancelled
                case .processingCompleted:
                    return .completed
                case .batchError(_, let recoverable):
                    return recoverable ? .paused : .error
                default:
                    return nil
                }
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher for overall progress percentage (0-100)
    var overallProgressPublisher: AnyPublisher<Double, Never> {
        let itemProgress = itemProcessedPublisher
            .map { Double($0.index) / Double($0.total) * 100.0 }
        
        let batchProgress = batchCompletedPublisher
            .map { Double($0.batchIndex) / Double($0.totalBatches) * 100.0 }
        
        return Publishers.Merge(itemProgress, batchProgress)
            .scan(0.0) { (currentValue, newValue) -> Double in
                // Use the max value to ensure progress doesn't go backwards
                return max(currentValue, newValue)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Private initialization for singleton
    private init() {}
    
    /// Publish a batch progress event
    /// - Parameter event: The event to publish
    func publish(_ event: BatchProgressEvent) {
        DispatchQueue.main.async {
            self.eventSubject.send(event)
        }
    }
    
    /// Publish a batch started event
    func publishBatchStarted(batchIndex: Int, totalBatches: Int) {
        publish(.batchStarted(batchIndex: batchIndex, totalBatches: totalBatches))
    }
    
    /// Publish a stage progress event
    func publishStageProgress(stageName: String, progress: Double) {
        publish(.stageProgress(stageName: stageName, progress: progress))
    }
    
    /// Publish an item processed event
    func publishItemProcessed(index: Int, total: Int, itemId: String? = nil) {
        publish(.itemProcessed(index: index, total: total, itemId: itemId))
    }
    
    /// Publish an estimated time remaining event
    func publishEstimatedTimeRemaining(seconds: TimeInterval) {
        publish(.estimatedTimeRemaining(seconds: seconds))
    }
    
    /// Publish a batch completed event
    func publishBatchCompleted(batchIndex: Int, totalBatches: Int, itemsProcessed: Int) {
        publish(.batchCompleted(batchIndex: batchIndex, totalBatches: totalBatches, itemsProcessed: itemsProcessed))
    }
    
    /// Publish a memory warning event
    func publishMemoryWarning(level: MemoryMonitor.MemoryPressure, usagePercentage: Double) {
        publish(.memoryWarning(level: level, usagePercentage: usagePercentage))
    }
    
    /// Publish a batch size adjusted event
    func publishBatchSizeAdjusted(oldSize: Int, newSize: Int, reason: String) {
        publish(.batchSizeAdjusted(oldSize: oldSize, newSize: newSize, reason: reason))
    }
    
    /// Publish a batch error event
    func publishBatchError(error: Error, recoverable: Bool = false) {
        publish(.batchError(error: error, recoverable: recoverable))
    }
    
    /// Publish a batch paused event
    func publishBatchPaused(reason: String) {
        publish(.batchPaused(reason: reason))
    }
    
    /// Publish a batch resumed event
    func publishBatchResumed() {
        publish(.batchResumed)
    }
    
    /// Publish a batch cancelled event
    func publishBatchCancelled() {
        publish(.batchCancelled)
    }
    
    /// Publish a processing completed event
    func publishProcessingCompleted(totalProcessed: Int, successful: Int, failed: Int) {
        publish(.processingCompleted(totalProcessed: totalProcessed, successful: successful, failed: failed))
    }
}

/// Status of batch processing
enum BatchProcessingStatus: String {
    case idle = "Idle"
    case processing = "Processing"
    case paused = "Paused"
    case completed = "Completed"
    case cancelled = "Cancelled"
    case error = "Error"
}

/// Observable object for batch progress in SwiftUI
class BatchProgressMonitor: ObservableObject {
    /// Current batch processing status
    @Published var status: BatchProcessingStatus = .idle
    
    /// Overall progress percentage (0-100)
    @Published var overallProgress: Double = 0
    
    /// Current stage name
    @Published var currentStage: String = ""
    
    /// Progress of current stage (0-1)
    @Published var stageProgress: Double = 0
    
    /// Current batch index
    @Published var currentBatchIndex: Int = 0
    
    /// Total number of batches
    @Published var totalBatches: Int = 0
    
    /// Current item index
    @Published var currentItemIndex: Int = 0
    
    /// Total number of items
    @Published var totalItems: Int = 0
    
    /// Items processed so far
    @Published var itemsProcessed: Int = 0
    
    /// Estimated time remaining in seconds
    @Published var estimatedTimeRemaining: TimeInterval = 0
    
    /// Current memory usage percentage
    @Published var memoryUsagePercentage: Double = 0
    
    /// Current memory pressure level
    @Published var memoryPressureLevel: MemoryMonitor.MemoryPressure = .normal
    
    /// Current batch size
    @Published var batchSize: Int = 0
    
    /// Most recent error message
    @Published var lastErrorMessage: String?
    
    /// Recent log messages
    @Published var recentLogMessages: [String] = []
    
    /// Set of cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Initialize and set up subscriptions
    init() {
        setupSubscriptions()
    }
    
    /// Set up all subscriptions to the batch progress publisher
    private func setupSubscriptions() {
        // Status subscription
        BatchProgressPublisher.shared.statusPublisher
            .sink { [weak self] status in
                self?.status = status
            }
            .store(in: &cancellables)
        
        // Overall progress subscription
        BatchProgressPublisher.shared.overallProgressPublisher
            .sink { [weak self] progress in
                self?.overallProgress = progress
            }
            .store(in: &cancellables)
        
        // Stage progress subscription
        BatchProgressPublisher.shared.stageProgressPublisher
            .sink { [weak self] stage, progress in
                self?.currentStage = stage
                self?.stageProgress = progress
            }
            .store(in: &cancellables)
        
        // Batch started subscription
        BatchProgressPublisher.shared.batchStartedPublisher
            .sink { [weak self] batchIndex, totalBatches in
                self?.currentBatchIndex = batchIndex
                self?.totalBatches = totalBatches
            }
            .store(in: &cancellables)
        
        // Item processed subscription
        BatchProgressPublisher.shared.itemProcessedPublisher
            .sink { [weak self] index, total, _ in
                self?.currentItemIndex = index
                self?.totalItems = total
                self?.itemsProcessed = index
            }
            .store(in: &cancellables)
        
        // Time remaining subscription
        BatchProgressPublisher.shared.timeRemainingPublisher
            .sink { [weak self] timeRemaining in
                self?.estimatedTimeRemaining = timeRemaining
            }
            .store(in: &cancellables)
        
        // Memory warning subscription
        BatchProgressPublisher.shared.memoryWarningPublisher
            .sink { [weak self] level, percentage in
                self?.memoryPressureLevel = level
                self?.memoryUsagePercentage = percentage
            }
            .store(in: &cancellables)
        
        // Batch size adjusted subscription
        BatchProgressPublisher.shared.batchSizeAdjustedPublisher
            .sink { [weak self] _, newSize, reason in
                self?.batchSize = newSize
                self?.addLogMessage("Batch size adjusted to \(newSize): \(reason)")
            }
            .store(in: &cancellables)
        
        // Error subscription
        BatchProgressPublisher.shared.batchErrorPublisher
            .sink { [weak self] error, recoverable in
                let prefix = recoverable ? "Recoverable error" : "Error"
                let message = "\(prefix): \(error.localizedDescription)"
                self?.lastErrorMessage = message
                self?.addLogMessage(message)
            }
            .store(in: &cancellables)
        
        // Subscribe to all events for logging
        BatchProgressPublisher.shared.eventPublisher
            .sink { [weak self] event in
                self?.logEvent(event)
            }
            .store(in: &cancellables)
    }
    
    /// Add a log message
    /// - Parameter message: The message to add
    private func addLogMessage(_ message: String) {
        let timestamp = BatchProgressMonitor.formattedTimestamp()
        let timestampedMessage = "[\(timestamp)] \(message)"
        recentLogMessages.append(timestampedMessage)
        
        // Limit to the most recent 100 log messages
        if recentLogMessages.count > 100 {
            recentLogMessages.removeFirst(recentLogMessages.count - 100)
        }
    }
    
    /// Log an event to recent log messages
    /// - Parameter event: The event to log
    private func logEvent(_ event: BatchProgressEvent) {
        switch event {
        case let .batchStarted(batchIndex, totalBatches):
            addLogMessage("Batch \(batchIndex)/\(totalBatches) started")
            
        case let .stageProgress(stageName, progress):
            let percent = Int(progress * 100)
            if percent % 10 == 0 { // Only log at 10% increments to avoid too many messages
                addLogMessage("Stage '\(stageName)' at \(percent)%")
            }
            
        case let .itemProcessed(index, total, itemId):
            if index % 10 == 0 || index == total { // Only log every 10 items
                let itemInfo = itemId != nil ? " (Item: \(itemId!))" : ""
                addLogMessage("Processed item \(index)/\(total)\(itemInfo)")
            }
            
        case let .estimatedTimeRemaining(seconds):
            if Int(seconds) % 30 == 0 { // Only log every 30 seconds
                let timeString = BatchProgressMonitor.formatTimeInterval(seconds)
                addLogMessage("Estimated time remaining: \(timeString)")
            }
            
        case let .batchCompleted(batchIndex, totalBatches, itemsProcessed):
            addLogMessage("Batch \(batchIndex)/\(totalBatches) completed (\(itemsProcessed) items)")
            
        case let .memoryWarning(level, percentage):
            addLogMessage("Memory warning: \(level.description) (\(String(format: "%.1f", percentage))%)")
            
        case let .batchSizeAdjusted(oldSize, newSize, reason):
            addLogMessage("Batch size adjusted from \(oldSize) to \(newSize): \(reason)")
            
        case let .batchError(error, recoverable):
            let prefix = recoverable ? "Recoverable error" : "Error"
            addLogMessage("\(prefix): \(error.localizedDescription)")
            
        case let .batchPaused(reason):
            addLogMessage("Processing paused: \(reason)")
            
        case .batchResumed:
            addLogMessage("Processing resumed")
            
        case .batchCancelled:
            addLogMessage("Processing cancelled")
            
        case let .processingCompleted(total, successful, failed):
            addLogMessage("Processing completed: \(total) total, \(successful) successful, \(failed) failed")
        }
    }
    
    /// Format a timestamp for logging
    static func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    /// Format a time interval for display
    /// - Parameter seconds: The time interval in seconds
    /// - Returns: A formatted string (e.g., "2h 30m 15s")
    static func formatTimeInterval(_ seconds: TimeInterval) -> String {
        if seconds < 0 {
            return "0s"
        }
        
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let seconds = Int(seconds) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Reset the monitor to its initial state
    func reset() {
        status = .idle
        overallProgress = 0
        currentStage = ""
        stageProgress = 0
        currentBatchIndex = 0
        totalBatches = 0
        currentItemIndex = 0
        totalItems = 0
        itemsProcessed = 0
        estimatedTimeRemaining = 0
        memoryUsagePercentage = 0
        memoryPressureLevel = .normal
        batchSize = 0
        lastErrorMessage = nil
        recentLogMessages.removeAll()
    }
} 