import SwiftUI

struct PreferencesView: View {
    @ObservedObject var preferences = UserPreferences.shared
    @State private var showResetConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Preferences")
                    .font(.largeTitle)
                    .padding(.bottom, 10)
                
                // Batch Processing Settings
                GroupBox(label: Text("Batch Processing").font(.headline)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Batch Processing", isOn: $preferences.batchProcessingEnabled)
                            .padding(.top, 5)
                        
                        if preferences.batchProcessingEnabled {
                            Divider()
                            
                            Text("Batch Size: \(preferences.batchSize) items")
                            Slider(
                                value: Binding(
                                    get: { Double(preferences.batchSize) },
                                    set: { preferences.batchSize = Int($0) }
                                ),
                                in: Double(BatchSettings.minimumBatchSize)...500,
                                step: 25
                            )
                            
                            Toggle("Use Adaptive Batch Sizing", isOn: $preferences.useAdaptiveBatchSizing)
                            
                            if preferences.useAdaptiveBatchSizing {
                                Text("Automatically adjusts batch size based on available memory")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                }
                
                // Import Settings
                GroupBox(label: Text("Import Settings").font(.headline)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Media Types to Import")
                            .fontWeight(.medium)
                        
                        Toggle("Import Photos", isOn: $preferences.importPhotos)
                        Toggle("Import Videos", isOn: $preferences.importVideos)
                        Toggle("Import Live Photos", isOn: $preferences.importLivePhotos)
                        
                        Divider()
                            .padding(.vertical, 5)
                        
                        Text("Metadata Preservation")
                            .fontWeight(.medium)
                        
                        Toggle("Preserve Creation Dates", isOn: $preferences.preserveCreationDates)
                        Toggle("Preserve Location Data", isOn: $preferences.preserveLocationData)
                        Toggle("Preserve Descriptions", isOn: $preferences.preserveDescriptions)
                        Toggle("Preserve Favorites", isOn: $preferences.preserveFavorites)
                        
                        Divider()
                            .padding(.vertical, 5)
                        
                        Toggle("Create Albums", isOn: $preferences.createAlbums)
                    }
                    .padding()
                }
                
                // UI Settings
                GroupBox(label: Text("User Interface").font(.headline)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Show Detailed Statistics on Completion", isOn: $preferences.showDetailedStatsOnCompletion)
                        Toggle("Auto-Export Reports After Migration", isOn: $preferences.autoExportReport)
                    }
                    .padding()
                }
                
                // Reset Button
                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        showResetConfirmation = true
                    }
                    .foregroundColor(.red)
                    Spacer()
                }
                .padding(.top, 10)
                
                // Migration History
                if !preferences.recentMigrations.isEmpty {
                    GroupBox(label: Text("Recent Migrations").font(.headline)) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(preferences.recentMigrations.enumerated()), id: \.offset) { index, summary in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Migration \(index + 1)")
                                            .fontWeight(.medium)
                                        Text("\(summary.totalItemsProcessed) items, \(summary.successfulImports) successful")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatSuccessRate(summary.successRate))
                                        .foregroundColor(getSuccessRateColor(summary.successRate))
                                }
                                .padding(.vertical, 5)
                                
                                if index < preferences.recentMigrations.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
        .alert(isPresented: $showResetConfirmation) {
            Alert(
                title: Text("Reset Preferences"),
                message: Text("Are you sure you want to reset all preferences to their default values?"),
                primaryButton: .destructive(Text("Reset")) {
                    preferences.resetToDefaults()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // Helper function to format success rate percentage
    private func formatSuccessRate(_ rate: Double) -> String {
        return String(format: "%.1f%%", rate)
    }
    
    // Helper function to get color based on success rate
    private func getSuccessRateColor(_ rate: Double) -> Color {
        if rate >= 90 {
            return .green
        } else if rate >= 75 {
            return .orange
        } else {
            return .red
        }
    }
}