import SwiftUI

struct ProgressView: View {
    @ObservedObject var progress: MigrationProgress
    
    // Timer for updating elapsed time
    @State private var timer: Timer?
    @State private var startTime = Date()
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Migrating Your Photos")
                .font(.title)
            
            // Stage indicator
            Text(progress.currentStage.rawValue)
                .font(.headline)
                .foregroundColor(.blue)
            
            // Progress bar
            ProgressBar(value: progress.overallProgress)
                .frame(height: 20)
                .padding(.horizontal)
            
            // Stats
            VStack(spacing: 10) {
                HStack {
                    Text("Processing:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(progress.processedItems) of \(progress.totalItems) items")
                        .bold()
                }
                
                HStack {
                    Text("Photos:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(progress.photosProcessed)")
                        .bold()
                }
                
                HStack {
                    Text("Videos:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(progress.videosProcessed)")
                        .bold()
                }
                
                HStack {
                    Text("Live Photos:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(progress.livePhotosReconstructed)")
                        .bold()
                }
                
                HStack {
                    Text("Albums:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(progress.albumsCreated)")
                        .bold()
                }
                
                HStack {
                    Text("Failed items:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(progress.failedItems)")
                        .bold()
                        .foregroundColor(progress.failedItems > 0 ? .red : .primary)
                }
                
                Divider()
                
                HStack {
                    Text("Current file:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(progress.currentItemName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                HStack {
                    Text("Elapsed time:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formattedElapsedTime)
                        .monospacedDigit()
                }
                
                if let timeRemaining = progress.estimatedTimeRemaining {
                    HStack {
                        Text("Estimated time remaining:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTimeInterval(timeRemaining))
                            .monospacedDigit()
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Recent messages/logs
            if !progress.recentMessages.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Messages:")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    ScrollView {
                        ForEach(progress.recentMessages, id: \.timestamp) { message in
                            HStack(alignment: .top) {
                                Image(systemName: messageIcon(for: message.type))
                                    .foregroundColor(messageColor(for: message.type))
                                
                                Text(message.text)
                                    .foregroundColor(messageColor(for: message.type))
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(2)
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(maxHeight: 100)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .padding()
        .onAppear {
            startTime = Date()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private var formattedElapsedTime: String {
        return formatTimeInterval(progress.elapsedTime)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func messageIcon(for type: MigrationProgress.ProgressMessage.MessageType) -> String {
        switch type {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        }
    }
    
    private func messageColor(for type: MigrationProgress.ProgressMessage.MessageType) -> Color {
        switch type {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            progress.elapsedTime = Date().timeIntervalSince(startTime)
            
            // Calculate estimated time remaining if we have processed items
            if progress.processedItems > 0 && progress.totalItems > 0 {
                let itemsRemaining = progress.totalItems - progress.processedItems
                let avgTimePerItem = progress.elapsedTime / Double(progress.processedItems)
                progress.estimatedTimeRemaining = avgTimePerItem * Double(itemsRemaining)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct ProgressBar: View {
    var value: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(Color.gray.opacity(0.3))
                    .cornerRadius(5)
                
                Rectangle()
                    .foregroundColor(.blue)
                    .cornerRadius(5)
                    .frame(width: min(CGFloat(self.value) * geometry.size.width, geometry.size.width))
                    .animation(.linear, value: value)
            }
        }
    }
}
