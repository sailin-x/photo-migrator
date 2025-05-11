import Foundation

/// Memory monitoring integration with ArchiveProcessor
extension ArchiveProcessor {
    
    /// Setup memory monitoring for the archive processing
    func setupMemoryMonitoring() {
        let monitor = MemoryMonitor.shared
        
        // Start monitoring memory usage
        monitor.startMonitoring(interval: 3.0)
        
        // Set up warning handler
        monitor.onMemoryWarning = { [weak self] usage in
            guard let self = self else { return }
            
            // Update progress with memory warning
            DispatchQueue.main.async {
                self.progress.peakMemoryUsage = usage
                self.progress.isMemoryWarningActive = true
            }
            
            // Log memory warning
            self.writeToLog("⚠️ Memory warning: Current usage \(monitor.formatMemorySize(usage))")
            
            // If we're using batch processing, potentially reduce batch size
            if let batchManager = self.batchProcessingManager, self.batchProcessingEnabled {
                // Batch size reduction happens automatically through the batch manager
                // when memory pressure is detected
            } else {
                // If not using batch processing, suggest it in the log
                self.writeToLog("Consider enabling batch processing for reduced memory usage")
            }
            
            // Attempt to free some memory
            monitor.performMemoryCleanup()
        }
    }
    
    /// Clean up memory monitoring
    func cleanupMemoryMonitoring() {
        let monitor = MemoryMonitor.shared
        monitor.stopMonitoring()
        monitor.onMemoryWarning = nil
    }
}