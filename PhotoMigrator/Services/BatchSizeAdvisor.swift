import Foundation
import Combine

/// Advanced batch size advisor implementing intelligent dynamic adjustment algorithms
class BatchSizeAdvisor {
    /// Configuration for the batch size advisor
    struct Configuration {
        /// Minimum allowed batch size
        let minBatchSize: Int
        
        /// Maximum allowed batch size
        let maxBatchSize: Int
        
        /// Default batch size
        let defaultBatchSize: Int
        
        /// Size of the historical metrics window
        let historyWindowSize: Int
        
        /// Smoothing factor for metrics (0.0-1.0)
        let smoothingFactor: Double
        
        /// Cooldown period in seconds between adjustments
        let cooldownPeriod: TimeInterval
        
        /// Whether to use the ML prediction model when available
        let useMLPrediction: Bool
        
        /// Initialize with default values
        init(
            minBatchSize: Int = 5,
            maxBatchSize: Int = 500,
            defaultBatchSize: Int = 250,
            historyWindowSize: Int = 10,
            smoothingFactor: Double = 0.7,
            cooldownPeriod: TimeInterval = 5.0,
            useMLPrediction: Bool = true
        ) {
            self.minBatchSize = minBatchSize
            self.maxBatchSize = maxBatchSize
            self.defaultBatchSize = defaultBatchSize
            self.historyWindowSize = historyWindowSize
            self.smoothingFactor = smoothingFactor
            self.cooldownPeriod = cooldownPeriod
            self.useMLPrediction = useMLPrediction
        }
    }
    
    /// Performance metrics used for batch size optimization
    struct PerformanceMetrics {
        /// Processing time in seconds for a batch
        let processingTime: TimeInterval
        
        /// Memory usage as a percentage of total (0.0-1.0)
        let memoryUsage: Double
        
        /// CPU usage as a percentage (0.0-1.0)
        let cpuUsage: Double
        
        /// Batch size used
        let batchSize: Int
        
        /// Items processed per second
        let throughput: Double
        
        /// Memory pressure level
        let memoryPressure: MemoryMonitor.MemoryPressure
        
        /// Initialize with metrics
        init(
            processingTime: TimeInterval,
            memoryUsage: Double,
            cpuUsage: Double,
            batchSize: Int,
            throughput: Double,
            memoryPressure: MemoryMonitor.MemoryPressure
        ) {
            self.processingTime = processingTime
            self.memoryUsage = memoryUsage
            self.cpuUsage = cpuUsage
            self.batchSize = batchSize
            self.throughput = throughput
            self.memoryPressure = memoryPressure
        }
    }
    
    /// The configuration for the advisor
    private let configuration: Configuration
    
    /// Reference to the memory monitor
    private let memoryMonitor: MemoryMonitor
    
    /// Historical metrics for analysis
    private var metricsHistory: [PerformanceMetrics] = []
    
    /// Timestamp of last adjustment
    private var lastAdjustmentTime: Date?
    
    /// Current batch size recommendation
    private(set) var currentRecommendation: Int
    
    /// ML prediction model for batch size optimization
    private var mlPredictor: BatchSizePredictor?
    
    /// Subject for batch size recommendation events
    private let recommendationSubject = PassthroughSubject<Int, Never>()
    
    /// Publisher for recommendation events
    var recommendationPublisher: AnyPublisher<Int, Never> {
        return recommendationSubject.eraseToAnyPublisher()
    }
    
    /// Initialize with configuration
    init(configuration: Configuration, memoryMonitor: MemoryMonitor) {
        self.configuration = configuration
        self.memoryMonitor = memoryMonitor
        self.currentRecommendation = configuration.defaultBatchSize
        
        // Try to load ML predictor if enabled
        if configuration.useMLPrediction {
            do {
                self.mlPredictor = try BatchSizePredictor()
            } catch {
                print("Warning: Failed to load ML predictor: \(error.localizedDescription)")
            }
        }
    }
    
    /// Record a batch processing result
    /// - Parameters:
    ///   - batchSize: The size of the batch processed
    ///   - processingTime: Time taken to process the batch
    ///   - items: Number of items processed
    func recordBatchResult(batchSize: Int, processingTime: TimeInterval, items: Int) {
        // Calculate throughput (items per second)
        let throughput = processingTime > 0 ? Double(items) / processingTime : 0
        
        // Get memory and CPU metrics
        let memoryUsage = Double(memoryMonitor.getCurrentMemoryUsage()) / Double(memoryMonitor.getTotalMemory())
        let cpuUsage = getCPUUsage()
        
        // Create metrics
        let metrics = PerformanceMetrics(
            processingTime: processingTime,
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            batchSize: batchSize,
            throughput: throughput,
            memoryPressure: memoryMonitor.currentPressure
        )
        
        // Add to history
        addMetricsToHistory(metrics)
        
        // Check if we should adjust batch size
        checkForBatchSizeAdjustment()
    }
    
    /// Add metrics to history, keeping the window size limited
    private func addMetricsToHistory(_ metrics: PerformanceMetrics) {
        metricsHistory.append(metrics)
        
        // Trim history if needed
        if metricsHistory.count > configuration.historyWindowSize {
            metricsHistory.removeFirst(metricsHistory.count - configuration.historyWindowSize)
        }
    }
    
    /// Check if batch size should be adjusted
    private func checkForBatchSizeAdjustment() {
        // Only adjust if we have enough history and cooldown period has passed
        guard metricsHistory.count >= 3 else { return }
        
        // Check cooldown period
        if let lastAdjustment = lastAdjustmentTime {
            let timeSinceLastAdjustment = Date().timeIntervalSince(lastAdjustment)
            if timeSinceLastAdjustment < configuration.cooldownPeriod {
                return // Still in cooldown period
            }
        }
        
        // First check for critical memory pressure which overrides other considerations
        if memoryMonitor.currentPressure == .critical {
            decreaseBatchSize(byPercent: 0.5) // Decrease by 50% for critical pressure
            return
        }
        
        // Use ML predictor if available
        if let predictor = mlPredictor, configuration.useMLPrediction {
            let prediction = predictor.predictOptimalBatchSize(
                currentBatchSize: currentRecommendation,
                memoryUsage: metricsHistory.last?.memoryUsage ?? 0,
                cpuUsage: metricsHistory.last?.cpuUsage ?? 0,
                throughput: metricsHistory.last?.throughput ?? 0,
                memoryPressure: metricsHistory.last?.memoryPressure ?? .normal
            )
            
            if prediction.confidence > 0.7 {
                // Use ML prediction with high confidence
                updateBatchSizeRecommendation(prediction.batchSize)
                return
            }
        }
        
        // Fall back to heuristic approach
        let newSize = calculateOptimalBatchSizeHeuristic()
        updateBatchSizeRecommendation(newSize)
    }
    
    /// Calculate optimal batch size using heuristics
    private func calculateOptimalBatchSizeHeuristic() -> Int {
        // Get recent metrics
        let recentMetrics = Array(metricsHistory.suffix(5))
        
        // Calculate trends
        let throughputTrend = calculateTrend(metrics: recentMetrics, keyPath: \.throughput)
        let memoryUsageTrend = calculateTrend(metrics: recentMetrics, keyPath: \.memoryUsage)
        let processingTimeTrend = calculateTrend(metrics: recentMetrics, keyPath: \.processingTime)
        
        // Get current batch size
        let currentSize = currentRecommendation
        
        // Determine adjustment based on trends and current pressure
        let memoryPressure = memoryMonitor.currentPressure
        
        switch memoryPressure {
        case .normal:
            if throughputTrend > 0 && memoryUsageTrend < 0.1 {
                // Increasing throughput with stable memory usage - try larger batches
                return increaseBatchSizeWithDamping(currentSize, percent: 0.2)
            } else if throughputTrend < 0 && processingTimeTrend > 0.2 {
                // Decreasing throughput with increasing processing time - try smaller batches
                return decreaseBatchSizeWithDamping(currentSize, percent: 0.1)
            }
            
        case .medium:
            if throughputTrend <= 0 || memoryUsageTrend >= 0.05 {
                // Decreasing throughput or increasing memory usage - try smaller batches
                return decreaseBatchSizeWithDamping(currentSize, percent: 0.15)
            }
            
        case .high:
            // Under high pressure, reduce batch size
            return decreaseBatchSizeWithDamping(currentSize, percent: 0.3)
            
        case .critical:
            // Under critical pressure, reduce to minimum
            return configuration.minBatchSize
        }
        
        // If no adjustment needed, maintain current size
        return currentSize
    }
    
    /// Calculate trend of a metric as a normalized value between -1 and 1
    private func calculateTrend<T: Numeric>(metrics: [PerformanceMetrics], keyPath: KeyPath<PerformanceMetrics, T>) -> Double {
        guard metrics.count >= 2 else { return 0 }
        
        // Convert to Double values
        let values = metrics.map { Double("\($0[keyPath: keyPath])") ?? 0 }
        
        // Simple linear regression
        let n = Double(values.count)
        let indices = Array(0..<values.count).map(Double.init)
        
        // Calculate sums
        let sumX = indices.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(indices, values).map(*).reduce(0, +)
        let sumXX = indices.map { $0 * $0 }.reduce(0, +)
        
        // Calculate slope
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        
        // Normalize to range -1 to 1
        let maxSlope = abs(values.max() ?? 1)
        let normalizedSlope = maxSlope > 0 ? slope / maxSlope : 0
        
        return normalizedSlope
    }
    
    /// Update batch size recommendation with smoothing
    private func updateBatchSizeRecommendation(_ newSize: Int) {
        let oldSize = currentRecommendation
        
        // Apply smoothing
        let smoothedSize = Int(
            Double(oldSize) * (1 - configuration.smoothingFactor) +
            Double(newSize) * configuration.smoothingFactor
        )
        
        // Ensure size is within bounds
        let boundedSize = min(configuration.maxBatchSize, max(configuration.minBatchSize, smoothedSize))
        
        // Only update if there's a meaningful change
        if abs(boundedSize - oldSize) >= 5 {
            currentRecommendation = boundedSize
            lastAdjustmentTime = Date()
            
            // Publish the recommendation
            recommendationSubject.send(boundedSize)
        }
    }
    
    /// Increase batch size with damping to prevent oscillations
    private func increaseBatchSizeWithDamping(_ currentSize: Int, percent: Double) -> Int {
        // Apply smaller increases at larger sizes (damping)
        let dampingFactor = max(0.5, 1.0 - Double(currentSize) / Double(configuration.maxBatchSize))
        let increase = max(5, Int(Double(currentSize) * percent * dampingFactor))
        
        return min(configuration.maxBatchSize, currentSize + increase)
    }
    
    /// Decrease batch size with minimum limit
    private func decreaseBatchSizeWithDamping(_ currentSize: Int, percent: Double) -> Int {
        let decrease = max(5, Int(Double(currentSize) * percent))
        return max(configuration.minBatchSize, currentSize - decrease)
    }
    
    /// Directly decrease batch size by a percentage
    private func decreaseBatchSize(byPercent percent: Double) {
        let newSize = max(configuration.minBatchSize, 
                           Int(Double(currentRecommendation) * (1.0 - percent)))
        
        updateBatchSizeRecommendation(newSize)
    }
    
    /// Get CPU usage as a value between 0 and 1
    private func getCPUUsage() -> Double {
        // This is a simplified implementation - in a real app you would
        // use host_processor_info or similar APIs to get accurate CPU usage
        
        // For now, use a placeholder
        return 0.5 // Placeholder value
    }
    
    /// Reset advisor state
    func reset() {
        metricsHistory.removeAll()
        currentRecommendation = configuration.defaultBatchSize
        lastAdjustmentTime = nil
    }
}

/// Simple predictor for batch sizes using ML
class BatchSizePredictor {
    /// Prediction result with confidence
    struct Prediction {
        let batchSize: Int
        let confidence: Double
    }
    
    /// Initialize and load model
    init() throws {
        // In a real implementation, this would load an ML model
        // For now, we'll use a placeholder implementation
    }
    
    /// Predict optimal batch size based on current metrics
    func predictOptimalBatchSize(
        currentBatchSize: Int,
        memoryUsage: Double,
        cpuUsage: Double,
        throughput: Double,
        memoryPressure: MemoryMonitor.MemoryPressure
    ) -> Prediction {
        // This is a placeholder implementation that would normally use an ML model
        
        // Convert memory pressure to a numeric value
        let pressureValue: Double
        switch memoryPressure {
        case .normal: pressureValue = 0.0
        case .medium: pressureValue = 0.33
        case .high: pressureValue = 0.67
        case .critical: pressureValue = 1.0
        }
        
        // Simple heuristic as a placeholder for ML prediction
        var predictedSize = currentBatchSize
        var confidence = 0.5 // Default medium confidence
        
        if memoryUsage > 0.85 || pressureValue > 0.67 {
            // High memory usage or pressure - decrease size
            predictedSize = Int(Double(currentBatchSize) * 0.7)
            confidence = 0.8
        } else if memoryUsage < 0.6 && throughput > 10 && pressureValue < 0.33 {
            // Low memory usage, good throughput, low pressure - increase size
            predictedSize = Int(Double(currentBatchSize) * 1.2)
            confidence = 0.75
        } else if cpuUsage > 0.9 {
            // Very high CPU usage - try smaller batches
            predictedSize = Int(Double(currentBatchSize) * 0.8)
            confidence = 0.7
        }
        
        // Ensure prediction is not too far from current size
        let maxChange = Int(Double(currentBatchSize) * 0.3) // Max 30% change
        predictedSize = min(currentBatchSize + maxChange, 
                            max(currentBatchSize - maxChange, predictedSize))
        
        return Prediction(batchSize: predictedSize, confidence: confidence)
    }
} 