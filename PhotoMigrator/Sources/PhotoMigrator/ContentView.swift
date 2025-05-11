import SwiftUI
import Photos

struct ContentView: View {
    @StateObject private var archiveProcessor = ArchiveProcessor()
    @State private var currentStep: MigrationStep = .selectArchive
    @State private var selectedArchivePath: URL?
    @State private var extractedDirectoryPath: URL?
    @State private var migrationSummary: MigrationSummary?
    @State private var isPhotosAccessGranted = false
    @State private var showingBatchSettings = false
    @State private var batchSettings = BatchSettings.createDefault()
    
    enum MigrationStep {
        case selectArchive
        case processing
        case complete
        case error
    }
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Google Photos to Apple Photos Migrator")
                    .font(.largeTitle)
                    .padding()
                Spacer()
                
                if currentStep == .selectArchive {
                    Button(action: {
                        showingBatchSettings = true
                    }) {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("Batch Settings")
                        }
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .padding()
                    .sheet(isPresented: $showingBatchSettings) {
                        BatchSettingsView(settings: $batchSettings)
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            // Main content
            ZStack {
                switch currentStep {
                case .selectArchive:
                    ArchiveSelectionView(onArchiveSelected: { url in
                        selectedArchivePath = url
                        checkPhotosAccess()
                    })
                case .processing:
                    ProgressView(progress: archiveProcessor.progress)
                case .complete:
                    if let summary = migrationSummary {
                        SummaryView(summary: summary, onReset: resetMigration)
                    }
                case .error:
                    ErrorView(error: archiveProcessor.error, onTryAgain: resetMigration)
                }
            }
            .padding()
            
            // Footer
            HStack {
                if currentStep == .processing {
                    Button("Cancel") {
                        archiveProcessor.cancelMigration()
                        resetMigration()
                    }
                    .padding()
                }
                
                Spacer()
                
                if let error = archiveProcessor.error, currentStep != .error {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private func checkPhotosAccess() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            isPhotosAccessGranted = true
            startMigration()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        isPhotosAccessGranted = true
                        startMigration()
                    } else {
                        archiveProcessor.error = MigrationError.photosAccessDenied
                        currentStep = .error
                    }
                }
            }
        case .denied, .restricted:
            archiveProcessor.error = MigrationError.photosAccessDenied
            currentStep = .error
        @unknown default:
            archiveProcessor.error = MigrationError.unknown
            currentStep = .error
        }
    }
    
    private func startMigration() {
        guard let archivePath = selectedArchivePath else { return }
        currentStep = .processing
        
        // Apply batch settings to processor
        if batchSettings.batchProcessingEnabled {
            archiveProcessor.enableBatchProcessing(with: batchSettings.toBatchConfig())
        } else {
            archiveProcessor.disableBatchProcessing()
        }
        
        Task {
            do {
                migrationSummary = try await archiveProcessor.processArchive(at: archivePath)
                DispatchQueue.main.async {
                    currentStep = .complete
                }
            } catch {
                DispatchQueue.main.async {
                    archiveProcessor.error = error as? MigrationError ?? MigrationError.unknown
                    currentStep = .error
                }
            }
        }
    }
    
    private func resetMigration() {
        selectedArchivePath = nil
        extractedDirectoryPath = nil
        migrationSummary = nil
        archiveProcessor.reset()
        currentStep = .selectArchive
        
        // Force memory cleanup after migration
        MemoryMonitor.shared.performMemoryCleanup()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
