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
                
                // Privacy Settings
                GroupBox(label: Text("Privacy Settings").font(.headline)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy Protection Level")
                            .fontWeight(.medium)
                        
                        Picker("Privacy Level", selection: $preferences.privacyLevel) {
                            Text("Standard").tag(PrivacyLevel.standard)
                            Text("Enhanced").tag(PrivacyLevel.enhanced)
                            Text("Maximum").tag(PrivacyLevel.maximum)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.bottom, 5)
                        
                        Group {
                            switch preferences.privacyLevel {
                            case .standard:
                                Text("Standard privacy protects your data based on the settings below.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            case .enhanced:
                                Text("Enhanced privacy automatically applies stronger protection beyond basic settings.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            case .maximum:
                                Text("Maximum privacy strips most metadata to ensure maximum protection.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 5)
                        
                        Divider()
                            .padding(.vertical, 5)
                        
                        Text("Location Privacy")
                            .fontWeight(.medium)
                        
                        Toggle("Strip GPS Data Completely", isOn: $preferences.stripGPSData)
                            .disabled(preferences.privacyLevel == .maximum)
                        
                        if !preferences.stripGPSData && preferences.privacyLevel != .maximum {
                            Toggle("Obfuscate Location (Reduce Precision)", isOn: $preferences.obfuscateLocationData)
                                .padding(.leading)
                                .disabled(!preferences.preserveLocationData)
                            
                            if preferences.obfuscateLocationData && preferences.preserveLocationData {
                                Text("Location Precision Level: \(preferences.locationPrecisionLevel)")
                                    .padding(.leading)
                                
                                Slider(
                                    value: Binding(
                                        get: { Double(preferences.locationPrecisionLevel) },
                                        set: { preferences.locationPrecisionLevel = Int($0) }
                                    ),
                                    in: 0...6,
                                    step: 1
                                )
                                .padding(.leading)
                                
                                Text("Lower values provide better privacy (0: ~111km, 3: ~110m, 6: ~0.11m)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 5)
                        
                        Text("Other Privacy Settings")
                            .fontWeight(.medium)
                        
                        Toggle("Strip Personal Identifiers", isOn: $preferences.stripPersonalIdentifiers)
                            .disabled(preferences.privacyLevel == .maximum)
                        
                        Toggle("Strip Device Information", isOn: $preferences.stripDeviceInfo)
                            .disabled(preferences.privacyLevel == .maximum)
                        
                        Divider()
                            .padding(.vertical, 5)
                        
                        Text("Logging & Debugging")
                            .fontWeight(.medium)
                        
                        Toggle("Allow Logging Sensitive Metadata", isOn: $preferences.logSensitiveMetadata)
                            .disabled(preferences.privacyLevel == .maximum)
                        
                        if preferences.logSensitiveMetadata && preferences.privacyLevel != .maximum {
                            Text("Warning: Enabling this option may record sensitive information in logs")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.leading)
                        }
                    }
                    .padding()
                }
                
                // Permissions Settings
                PermissionsPreferenceView()
                
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
                    .buttonStyle(.bordered)
                    .controlSize(.large)
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
            .padding()
        }
    }
}