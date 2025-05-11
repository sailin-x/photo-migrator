import SwiftUI

struct SummaryView: View {
    let summary: MigrationSummary
    let onReset: () -> Void
    
    @State private var isShowingLogFile = false
    @State private var isShowingDetailedStats = false
    
    /// Format memory size to human-readable string
    private func formatMemorySize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Format time interval to human-readable string
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        let remainingSeconds = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d h %d min %d sec", hours, minutes, remainingSeconds)
        } else if minutes > 0 {
            return String(format: "%d min %d sec", minutes, remainingSeconds)
        } else {
            return String(format: "%.1f seconds", seconds)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Your Google Photos have been migrated to Apple Photos.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Summary stats
            VStack(spacing: 12) {
                HStack {
                    Text("Total items processed:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(summary.totalItemsProcessed)")
                        .bold()
                }
                
                HStack {
                    Text("Successfully imported:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(summary.successfulImports)")
                        .bold()
                        .foregroundColor(.green)
                }
                
                if summary.failedImports > 0 {
                    HStack {
                        Text("Failed to import:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(summary.failedImports)")
                            .bold()
                            .foregroundColor(.red)
                    }
                }
                
                HStack {
                    Text("Albums created:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(summary.albumsCreated)")
                        .bold()
                }
                
                HStack {
                    Text("Live Photos reconstructed:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(summary.livePhotosReconstructed)")
                        .bold()
                }
                
                if summary.metadataIssues > 0 {
                    HStack {
                        Text("Metadata issues:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(summary.metadataIssues)")
                            .bold()
                            .foregroundColor(.orange)
                    }
                }
                
                if summary.batchProcessingUsed {
                    Divider()
                    
                    Text("Batch Processing Stats")
                        .font(.headline)
                        .padding(.top, 4)
                    
                    HStack {
                        Text("Batches processed:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(summary.batchesProcessed)")
                            .bold()
                    }
                    
                    HStack {
                        Text("Batch size:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(summary.batchSize) items")
                            .bold()
                    }
                    
                    if summary.peakMemoryUsage > 0 {
                        HStack {
                            Text("Peak memory usage:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatMemorySize(summary.peakMemoryUsage))
                                .bold()
                        }
                    }
                    
                    HStack {
                        Text("Processing time:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(summary.processingTime))
                            .bold()
                    }
                    
                    if let successRate = summary.successRate {
                        HStack {
                            Text("Success rate:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f%%", successRate))
                                .bold()
                                .foregroundColor(successRate > 90 ? .green : (successRate > 70 ? .orange : .red))
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Action buttons
            HStack(spacing: 20) {
                Button(action: onReset) {
                    Text("Start New Migration")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    isShowingDetailedStats = true
                }) {
                    Label("View Detailed Statistics", systemImage: "chart.bar.doc.horizontal")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                if let logPath = summary.logPath {
                    Button(action: {
                        isShowingLogFile = true
                    }) {
                        Text("View Log")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: 600)
        .sheet(isPresented: $isShowingLogFile) {
            if let logPath = summary.logPath {
                LogViewer(logURL: logPath)
            }
        }
        .sheet(isPresented: $isShowingDetailedStats) {
            DetailedStatisticsView(summary: summary)
        }
    }
}

struct LogViewer: View {
    let logURL: URL
    @State private var logContent: String = "Loading log file..."
    
    var body: some View {
        VStack {
            HStack {
                Text("Migration Log")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    NSApp.keyWindow?.endSheet(NSApp.keyWindow?.sheets.first ?? NSWindow())
                }
            }
            .padding()
            
            ScrollView {
                Text(logContent)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack {
                Button(action: {
                    NSWorkspace.shared.selectFile(logURL.path, inFileViewerRootedAtPath: logURL.deletingLastPathComponent().path)
                }) {
                    Text("Show in Finder")
                }
                
                Spacer()
                
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(logContent, forType: .string)
                }) {
                    Text("Copy to Clipboard")
                }
            }
            .padding()
        }
        .frame(width: 800, height: 600)
        .onAppear {
            loadLogFile()
        }
    }
    
    private func loadLogFile() {
        do {
            logContent = try String(contentsOf: logURL, encoding: .utf8)
        } catch {
            logContent = "Error loading log file: \(error.localizedDescription)"
        }
    }
}