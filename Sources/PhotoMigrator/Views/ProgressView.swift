import SwiftUI

/// View that displays overall migration progress
struct MigrationProgressView: View {
    @ObservedObject var progress: MigrationProgress
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Stage indicator
            HStack {
                Text(getStageName(progress.currentStage))
                    .font(.headline)
                Spacer()
                Text(getStageDescription(progress.currentStage))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Main progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Overall Progress")
                    Spacer()
                    Text("\(Int(progress.overallProgress))%")
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .foregroundColor(Color.gray.opacity(0.3))
                            .frame(width: geometry.size.width, height: 12)
                            .cornerRadius(6)
                        
                        Rectangle()
                            .foregroundColor(.blue)
                            .frame(width: max(0, geometry.size.width * CGFloat(progress.overallProgress / 100.0)), height: 12)
                            .cornerRadius(6)
                    }
                }
                .frame(height: 12)
            }
            
            // Current stage progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Current Stage")
                    Spacer()
                    Text("\(Int(progress.stageProgress))%")
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .foregroundColor(Color.gray.opacity(0.3))
                            .frame(width: geometry.size.width, height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .foregroundColor(.green)
                            .frame(width: max(0, geometry.size.width * CGFloat(progress.stageProgress / 100.0)), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }
            
            // Show batch progress view if batch processing is active
            if progress.totalBatches > 0 {
                BatchProgressView(progress: progress)
            }
            
            // Recent messages
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.headline)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(progress.recentMessages.suffix(5).reversed()) { message in
                            HStack(alignment: .top) {
                                Image(systemName: getIconForMessage(message))
                                    .foregroundColor(getColorForMessage(message))
                                
                                Text(message.message)
                                    .font(.subheadline)
                                    .foregroundColor(getColorForMessage(message))
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer()
                            }
                        }
                    }
                }
                .frame(height: 120)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Cancel button
            Button(action: onCancel) {
                Text("Cancel")
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.top, 10)
        }
        .padding()
    }
    
    // Get icon for message based on type
    private func getIconForMessage(_ message: MigrationProgress.ProgressMessage) -> String {
        switch message.type {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        }
    }
    
    // Get color for message based on type
    private func getColorForMessage(_ message: MigrationProgress.ProgressMessage) -> Color {
        switch message.type {
        case .info:
            return .primary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
    
    // Get the name of the current stage
    private func getStageName(_ stage: MigrationProgress.Stage) -> String {
        switch stage {
        case .notStarted:
            return "Ready"
        case .initializing:
            return "Initializing"
        case .extractingArchive:
            return "Extracting Archive"
        case .processingMetadata:
            return "Processing Metadata"
        case .importingPhotos:
            return "Importing Photos"
        case .organizingAlbums:
            return "Organizing Albums"
        case .complete:
            return "Complete"
        case .error:
            return "Error"
        }
    }
    
    // Get description of the current stage
    private func getStageDescription(_ stage: MigrationProgress.Stage) -> String {
        switch stage {
        case .notStarted:
            return "Waiting to start"
        case .initializing:
            return "Setting up migration"
        case .extractingArchive:
            return "Extracting files from archive"
        case .processingMetadata:
            return "Reading metadata and preparing files"
        case .importingPhotos:
            return "Importing photos to Apple Photos"
        case .organizingAlbums:
            return "Creating and organizing albums"
        case .complete:
            return "Migration completed"
        case .error:
            return "Migration failed"
        }
    }
}