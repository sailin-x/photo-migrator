import SwiftUI

/// View that displays batch-specific progress information
struct BatchProgressView: View {
    @ObservedObject var progress: MigrationProgress
    
    var body: some View {
        VStack(spacing: 10) {
            if progress.totalBatches > 0 {
                // Batch progress header
                HStack {
                    Text("Batch Processing")
                        .font(.headline)
                    Spacer()
                    
                    if progress.isUnderMemoryPressure {
                        Label("Memory Pressure", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                    }
                }
                
                // Current batch progress
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Batch \(progress.currentBatch) of \(progress.totalBatches)")
                        Spacer()
                        Text("\(Int(getBatchProgress() * 100))%")
                    }
                    .font(.subheadline)
                    
                    // Batch progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .foregroundColor(Color.gray.opacity(0.3))
                                .frame(width: geometry.size.width, height: 10)
                                .cornerRadius(5)
                            
                            Rectangle()
                                .foregroundColor(getBatchProgressColor())
                                .frame(width: max(0, geometry.size.width * CGFloat(getBatchProgress())), height: 10)
                                .cornerRadius(5)
                        }
                    }
                    .frame(height: 10)
                }
                
                // Items progress
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Items")
                        Spacer()
                        Text("\(progress.processedItems) of \(progress.totalItems)")
                    }
                    .font(.subheadline)
                    
                    // Items progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .foregroundColor(Color.gray.opacity(0.3))
                                .frame(width: geometry.size.width, height: 10)
                                .cornerRadius(5)
                            
                            Rectangle()
                                .foregroundColor(.blue)
                                .frame(width: max(0, geometry.size.width * CGFloat(getItemsProgress())), height: 10)
                                .cornerRadius(5)
                        }
                    }
                    .frame(height: 10)
                }
                
                // Memory usage
                if progress.peakMemoryUsage > 0 {
                    HStack {
                        Text("Memory")
                            .font(.subheadline)
                        Spacer()
                        
                        // Memory usage bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .foregroundColor(Color.gray.opacity(0.3))
                                    .frame(width: geometry.size.width, height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .foregroundColor(getMemoryColor())
                                    .frame(width: max(0, geometry.size.width * CGFloat(progress.memoryUsagePercentage / 100.0)), height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(width: 100, height: 8)
                        
                        Text("\(Int(progress.memoryUsagePercentage))%")
                            .font(.subheadline)
                            .foregroundColor(getMemoryColor())
                    }
                }
                
                // Elapsed time
                if progress.elapsedTime > 0 {
                    HStack {
                        Text("Time")
                            .font(.subheadline)
                        Spacer()
                        Text(formatTime(progress.elapsedTime))
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    // Get batch progress as percentage (0.0-1.0)
    private func getBatchProgress() -> Double {
        guard progress.totalBatches > 0 else { return 0 }
        return Double(progress.currentBatch) / Double(progress.totalBatches)
    }
    
    // Get items progress as percentage (0.0-1.0)
    private func getItemsProgress() -> Double {
        guard progress.totalItems > 0 else { return 0 }
        return Double(progress.processedItems) / Double(progress.totalItems)
    }
    
    // Get color for batch progress based on progress value
    private func getBatchProgressColor() -> Color {
        if progress.isUnderMemoryPressure {
            return .orange
        }
        
        return .green
    }
    
    // Get color for memory usage based on percentage
    private func getMemoryColor() -> Color {
        let percentage = progress.memoryUsagePercentage
        if percentage > 90 {
            return .red
        } else if percentage > 75 {
            return .orange
        } else {
            return .green
        }
    }
    
    // Format time interval to readable string
    private func formatTime(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "0s"
    }
}