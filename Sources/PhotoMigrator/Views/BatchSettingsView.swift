import SwiftUI

/// View for configuring batch processing settings
struct BatchSettingsView: View {
    @Binding var settings: BatchSettings
    @State private var showAdvancedSettings: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Batch processing toggle
            Toggle("Enable Batch Processing", isOn: $settings.isEnabled)
                .font(.headline)
            
            if settings.isEnabled {
                // Batch size slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Batch Size:")
                        Spacer()
                        Text("\(settings.batchSize) items")
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(settings.batchSize) },
                            set: { settings.batchSize = Int($0) }
                        ),
                        in: Double(BatchSettings.minimumBatchSize)...500,
                        step: 25
                    )
                }
                
                // Adaptive sizing toggle
                Toggle("Adaptive Batch Sizing", isOn: $settings.useAdaptiveSizing)
                    .font(.subheadline)
                
                if settings.useAdaptiveSizing {
                    Text("Automatically reduces batch size when memory pressure is detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Advanced settings disclosure
                DisclosureGroup("Advanced Settings", isExpanded: $showAdvancedSettings) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Memory thresholds
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("High Memory Threshold:")
                                Spacer()
                                Text("\(Int(settings.highMemoryThreshold * 100))%")
                            }
                            .font(.subheadline)
                            
                            Slider(value: $settings.highMemoryThreshold, in: 0.5...0.9, step: 0.05)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Critical Memory Threshold:")
                                Spacer()
                                Text("\(Int(settings.criticalMemoryThreshold * 100))%")
                            }
                            .font(.subheadline)
                            
                            Slider(value: $settings.criticalMemoryThreshold, in: 0.7...0.95, step: 0.05)
                        }
                        
                        // Pause between batches
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Pause Between Batches:")
                                Spacer()
                                Text("\(String(format: "%.1f", settings.pauseBetweenBatches)) seconds")
                            }
                            .font(.subheadline)
                            
                            Slider(value: $settings.pauseBetweenBatches, in: 0...5, step: 0.5)
                        }
                        
                        // Memory warnings toggle
                        Toggle("Show Memory Warnings", isOn: $settings.showMemoryWarnings)
                            .font(.subheadline)
                    }
                    .padding(.top, 8)
                }
                
                // Reset to recommended button
                Button(action: {
                    settings = BatchSettings.recommendedSettings()
                }) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("Use Recommended Settings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
                
                // Information about system recommendations
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended Settings:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Batch size is automatically recommended based on your system's available memory.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("For very large libraries (100,000+ photos), smaller batch sizes are recommended.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .animation(.default, value: settings.isEnabled)
        .animation(.default, value: showAdvancedSettings)
    }
}