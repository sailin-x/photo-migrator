import SwiftUI

/// SwiftUI dashboard for displaying batch processing progress
struct BatchProgressDashboardView: View {
    /// Progress monitor for observing batch progress
    @StateObject private var progressMonitor = BatchProgressMonitor()
    
    /// Formatter for progress numbers
    private let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header section
                HStack {
                    Text("Batch Processing Dashboard")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text(progressMonitor.status.rawValue)
                        .font(.headline)
                        .padding(8)
                        .background(statusColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                // Main progress bar
                VStack(alignment: .leading) {
                    Text("Overall Progress")
                        .font(.headline)
                    
                    SwiftUI.ProgressView(value: progressMonitor.overallProgress / 100)
                        .accentColor(.blue)
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                    
                    HStack {
                        Text("\(percentFormatter.string(from: NSNumber(value: progressMonitor.overallProgress / 100)) ?? "0%")")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        if progressMonitor.estimatedTimeRemaining > 0 {
                            Text("Remaining: \(formatTimeRemaining())")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
                
                // Batch info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Batch Information")
                        .font(.headline)
                    
                    HStack {
                        InfoCard(
                            title: "Batch",
                            value: "\(progressMonitor.currentBatchIndex)/\(progressMonitor.totalBatches)",
                            systemImage: "rectangle.stack"
                        )
                        
                        InfoCard(
                            title: "Batch Size",
                            value: "\(progressMonitor.batchSize)",
                            systemImage: "arrow.left.and.right"
                        )
                        
                        InfoCard(
                            title: "Items Processed",
                            value: "\(progressMonitor.itemsProcessed)/\(progressMonitor.totalItems)",
                            systemImage: "checkmark.circle"
                        )
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
                
                // Memory usage
                VStack(alignment: .leading, spacing: 8) {
                    Text("Memory Usage")
                        .font(.headline)
                    
                    HStack(alignment: .bottom) {
                        // Create memory usage bars
                        ForEach(0..<10, id: \.self) { i in
                            let threshold = Double(i + 1) * 10.0
                            let isActive = progressMonitor.memoryUsagePercentage >= threshold
                            
                            VStack {
                                Rectangle()
                                    .fill(isActive ? memoryUsageColor : Color.gray.opacity(0.3))
                                    .frame(width: 15, height: CGFloat(i + 1) * 5)
                                
                                if i % 3 == 0 {
                                    Text("\(Int(threshold))%")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Current: \(String(format: "%.1f%%", progressMonitor.memoryUsagePercentage))")
                                .font(.subheadline)
                            
                            Text("Pressure: \(progressMonitor.memoryPressureLevel.description)")
                                .font(.subheadline)
                                .foregroundColor(memoryPressureColor)
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
                
                // Recent log messages
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Activity")
                        .font(.headline)
                    
                    if progressMonitor.recentLogMessages.isEmpty {
                        Text("No activity yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(progressMonitor.recentLogMessages.suffix(10), id: \.self) { message in
                                    Text(message)
                                        .font(.system(.footnote, design: .monospaced))
                                        .lineLimit(1)
                                }
                            }
                        }
                        .frame(height: 150)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
                
                // Error display
                if let errorMessage = progressMonitor.lastErrorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }
    
    /// Format the remaining time
    private func formatTimeRemaining() -> String {
        BatchProgressMonitor.formatTimeInterval(progressMonitor.estimatedTimeRemaining)
    }
    
    /// Color based on status
    private var statusColor: Color {
        switch progressMonitor.status {
        case .idle: return .gray
        case .processing: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .cancelled: return .secondary
        case .error: return .red
        }
    }
    
    /// Color based on memory usage
    private var memoryUsageColor: Color {
        let usage = progressMonitor.memoryUsagePercentage
        
        if usage >= 90 {
            return .red
        } else if usage >= 70 {
            return .orange
        } else if usage >= 50 {
            return .yellow
        } else {
            return .green
        }
    }
    
    /// Color based on memory pressure
    private var memoryPressureColor: Color {
        switch progressMonitor.memoryPressureLevel {
        case .normal: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

/// Information card view
struct InfoCard: View {
    let title: String
    let value: String
    let systemImage: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            HStack {
                Image(systemName: systemImage)
                    .font(.headline)
                
                Text(title)
                    .font(.subheadline)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.2))
        .cornerRadius(8)
    }
}

struct BatchProgressDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        BatchProgressDashboardView()
    }
} 