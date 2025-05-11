import SwiftUI

struct BatchSettingsView: View {
    @Binding var settings: BatchSettings
    @Environment(\.presentationMode) var presentationMode
    
    @State private var tempSettings: BatchSettings
    
    init(settings: Binding<BatchSettings>) {
        self._settings = settings
        self._tempSettings = State(initialValue: settings.wrappedValue)
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Batch Processing")) {
                    Toggle("Enable Batch Processing", isOn: $tempSettings.batchProcessingEnabled)
                        .toggleStyle(SwitchToggleStyle())
                        .padding(.vertical, 4)
                    
                    if tempSettings.batchProcessingEnabled {
                        HStack {
                            Text("Batch Size:")
                            Spacer()
                            Slider(value: Binding(
                                get: { Double(tempSettings.batchSize) },
                                set: { tempSettings.batchSize = Int($0) }
                            ), in: 100...10000, step: 100)
                            .frame(width: 200)
                            Text("\(tempSettings.batchSize)")
                                .frame(width: 60, alignment: .trailing)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 4)
                        
                        Toggle("Adaptive Batch Sizing", isOn: $tempSettings.adaptiveBatchSizing)
                            .toggleStyle(SwitchToggleStyle())
                            .padding(.vertical, 4)
                        
                        if tempSettings.adaptiveBatchSizing {
                            HStack {
                                Text("Memory Threshold (GB):")
                                Spacer()
                                Slider(value: $tempSettings.memoryThresholdGB, in: 0.5...8.0, step: 0.5)
                                    .frame(width: 200)
                                Text(String(format: "%.1f", tempSettings.memoryThresholdGB))
                                    .frame(width: 40, alignment: .trailing)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 4)
                            
                            HStack {
                                Text("Minimum Batch Size:")
                                Spacer()
                                Slider(value: Binding(
                                    get: { Double(tempSettings.minimumBatchSize) },
                                    set: { tempSettings.minimumBatchSize = Int($0) }
                                ), in: 50...1000, step: 50)
                                .frame(width: 200)
                                Text("\(tempSettings.minimumBatchSize)")
                                    .frame(width: 60, alignment: .trailing)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Toggle("Pause Between Batches", isOn: $tempSettings.pauseBetweenBatches)
                            .toggleStyle(SwitchToggleStyle())
                            .padding(.vertical, 4)
                        
                        if tempSettings.pauseBetweenBatches {
                            HStack {
                                Text("Pause Duration (sec):")
                                Spacer()
                                Slider(value: $tempSettings.pauseDurationSeconds, in: 0.5...10.0, step: 0.5)
                                    .frame(width: 200)
                                Text(String(format: "%.1f", tempSettings.pauseDurationSeconds))
                                    .frame(width: 40, alignment: .trailing)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 4)
                        }
                        
                        HStack {
                            Text("Concurrent Operations:")
                            Spacer()
                            Slider(value: Binding(
                                get: { Double(tempSettings.maxConcurrentOperations) },
                                set: { tempSettings.maxConcurrentOperations = Int($0) }
                            ), in: 1...12, step: 1)
                            .frame(width: 200)
                            Text("\(tempSettings.maxConcurrentOperations)")
                                .frame(width: 30, alignment: .trailing)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Recommendations")) {
                    Text("For very large libraries (100,000+ photos), batch processing is recommended to avoid memory issues. Smaller batches use less memory but take longer to process.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Button("Reset to Defaults") {
                    tempSettings = BatchSettings.createDefault()
                }
                .padding()
                
                Spacer()
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                
                Button("Save") {
                    settings = tempSettings
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(BorderedButtonStyle())
                .padding()
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .padding()
    }
}

struct BatchSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        BatchSettingsView(settings: .constant(BatchSettings()))
    }
}