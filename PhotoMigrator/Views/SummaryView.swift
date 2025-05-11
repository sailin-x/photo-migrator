import SwiftUI

struct SummaryView: View {
    let summary: MigrationSummary
    let onReset: () -> Void
    
    @State private var isShowingLogFile = false
    
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
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.green)
            
            Text("Migration Complete")
                .font(.title)
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
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Errors section if any
            if !summary.errors.isEmpty {
                VStack(alignment: .leading) {
                    Text("Issues encountered:")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(summary.errors, id: \.self) { error in
                                Text("• \(error)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 100)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            // View log button
            if let logPath = summary.logPath {
                Button("View Detailed Log") {
                    isShowingLogFile = true
                    NSWorkspace.shared.open(logPath)
                }
                .padding()
            }
            
            // Next steps
            VStack(alignment: .leading, spacing: 8) {
                Text("Next Steps:")
                    .font(.headline)
                
                Text("• Open Apple Photos to view your imported media")
                Text("• Check that albums and metadata were imported correctly")
                Text("• Any missing items can be found in the detailed log")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Button("Start New Migration") {
                onReset()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: 500)
    }
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryView(
            summary: MigrationSummary(
                totalItemsProcessed: 1250,
                successfulImports: 1200,
                failedImports: 50,
                albumsCreated: 15,
                livePhotosReconstructed: 100,
                metadataIssues: 25,
                errors: ["Failed to process some Live Photos", "Some albums could not be created"]
            ),
            onReset: {}
        )
    }
}
