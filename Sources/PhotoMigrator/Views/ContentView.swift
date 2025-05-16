import SwiftUI

struct ContentView: View {
    @ObservedObject private var licenseService = LicenseService.shared
    @State private var selectedSidebarItem: SidebarItem = .importPhotos
    @State private var isShowingSettings = false
    
    enum SidebarItem: String, CaseIterable, Identifiable {
        case importPhotos = "Import Photos"
        case livePhotos = "Live Photos"
        case albums = "Albums"
        case statistics = "Statistics"
        case settings = "Settings"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .importPhotos: return "square.and.arrow.down"
            case .livePhotos: return "livephoto"
            case .albums: return "rectangle.stack"
            case .statistics: return "chart.bar"
            case .settings: return "gearshape"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            // Sidebar
            List(SidebarItem.allCases) { item in
                HStack {
                    Image(systemName: item.icon)
                        .frame(width: 24, height: 24)
                    Text(item.rawValue)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSidebarItem = item
                }
                .background(selectedSidebarItem == item ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(6)
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 220)
            
            // Main content area
            ZStack {
                mainContentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Trial badge overlay
                if licenseService.licenseType == "trial" {
                    VStack {
                        HStack {
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("TRIAL MODE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("\(licenseService.photosRemainingInTrial) of \(LicenseService.TRIAL_PHOTO_LIMIT) photos remaining")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                            .background(Color.orange)
                            .cornerRadius(6)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            PreferencesTabView()
        }
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        switch selectedSidebarItem {
        case .importPhotos:
            ImportPhotosView()
        case .livePhotos:
            LivePhotoView()
        case .albums:
            AlbumsView()
        case .statistics:
            StatisticsView()
        case .settings:
            SettingsView()
        }
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

// Placeholder views for main content sections - these would be implemented with full functionality
struct ImportPhotosView: View {
    @ObservedObject private var licenseService = LicenseService.shared
    @State private var takeoutArchivePath: String = ""
    @State private var isProcessing = false
    @State private var progress: Float = 0.0
    @State private var photosProcessed: Int = 0
    @State private var totalPhotos: Int = 0
    @State private var showTrialLimitReached = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            Text("Import Photos from Google Takeout")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Select File UI
            VStack(spacing: 20) {
                Text("Select your Google Takeout archive to begin the migration process")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("Path to Google Takeout archive", text: $takeoutArchivePath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Browse...") {
                        // Open file picker dialog
                        selectTakeoutArchive()
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Start Migration") {
                    startMigration()
                }
                // Use buttonStyle that's available on macOS 11
.buttonStyle(.bordered)
.foregroundColor(.white)
.background(Color.blue)
.cornerRadius(5)
.disabled(takeoutArchivePath.isEmpty || isProcessing)
            }
            .padding()
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(12)
            
            // Progress display
            if isProcessing {
                VStack(spacing: 15) {
                    Text("Migration in Progress")
                        .font(.headline)
                    
                    SwiftUI.ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(height: 10)
                    
                    Text("\(photosProcessed) of \(totalPhotos) photos migrated (\(Int(progress * 100))% complete)")
                        .foregroundColor(.secondary)
                    
                    Button("Cancel") {
                        cancelMigration()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(12)
            }
            
            // Show trial limit in UI if in trial mode
            if licenseService.licenseType == "trial" && !isProcessing {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    
                    Text("Trial mode: \(licenseService.photosRemainingInTrial) of \(LicenseService.TRIAL_PHOTO_LIMIT) photos remaining")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Get License") {
                        // Show license activation view
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
        .alert(isPresented: $showTrialLimitReached) {
            Alert(
                title: Text("Trial Limit Reached"),
                message: Text("You've reached the limit of \(LicenseService.TRIAL_PHOTO_LIMIT) photos for the trial version. Purchase a license to migrate your entire library."),
                primaryButton: .default(Text("Purchase License")) {
                    // Show license activation view
                },
                secondaryButton: .cancel(Text("Later"))
            )
        }
    }
    
    private func selectTakeoutArchive() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["zip"]
        
        if panel.runModal() == .OK {
            takeoutArchivePath = panel.url?.path ?? ""
        }
    }
    
    private func startMigration() {
        // Check trial status first
        if licenseService.licenseType == "trial" && licenseService.photosRemainingInTrial <= 0 {
            showTrialLimitReached = true
            return
        }
        
        isProcessing = true
        progress = 0.0
        photosProcessed = 0
        
        // In a real implementation, we'd parse the archive to get the total photo count
        // For the demo, we'll just use a random number between 50-200
        totalPhotos = Int.random(in: 50...200)
        
        // If in trial mode, limit the total number of photos to process
        if licenseService.licenseType == "trial" {
            totalPhotos = min(totalPhotos, licenseService.photosRemainingInTrial)
        }
        
        // Simulate a migration process with progress updates
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            if progress < 1.0 {
                progress += 0.01
                
                // Update processed photos count based on progress
                let newProcessedCount = Int(Float(totalPhotos) * progress)
                let photosDelta = newProcessedCount - photosProcessed
                
                // If we processed more photos, update the count and track in trial
                if photosDelta > 0 {
                    photosProcessed = newProcessedCount
                    
                    // If in trial mode, track the photos processed
                    if licenseService.licenseType == "trial" {
                        for _ in 0..<photosDelta {
                            licenseService.trackPhotoProcessed()
                        }
                        
                        // Check if trial limit was reached during processing
                        if licenseService.photosRemainingInTrial <= 0 {
                            timer.invalidate()
                            isProcessing = false
                            showTrialLimitReached = true
                        }
                    }
                }
            } else {
                timer.invalidate()
                isProcessing = false
            }
        }
        timer.tolerance = 0.1
    }
    
    private func cancelMigration() {
        isProcessing = false
        progress = 0.0
    }
}

struct AlbumsView: View {
    var body: some View {
        VStack {
            Text("Albums")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("View and organize your imported albums")
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            // Placeholder for album grid
            Text("Album management interface would appear here")
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(12)
        }
        .padding()
    }
}

struct StatisticsView: View {
    var body: some View {
        VStack {
            Text("Migration Statistics")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Analysis of your photo migration")
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            // Placeholder for statistics
            Text("Detailed statistics and charts would appear here")
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(12)
        }
        .padding()
    }
}

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Configure PhotoMigrator preferences")
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            // Placeholder for settings
            Text("Settings interface would appear here")
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(12)
        }
        .padding()
    }
}

struct PreferencesTabView: View {
    var body: some View {
        TabView {
            GeneralPreferencesView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            ImportPreferencesView()
                .tabItem {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            
            ProcessingPreferencesView()
                .tabItem {
                    Label("Processing", systemImage: "gearshape.2")
                }
            
            AdvancedPreferencesView()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 600, height: 400)
        .padding()
    }
}

struct GeneralPreferencesView: View {
    var body: some View {
        Form {
            Text("General Preferences")
                .font(.title)
                .padding(.bottom)
            
            Text("General application preferences would appear here")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct ImportPreferencesView: View {
    var body: some View {
        Form {
            Text("Import Preferences")
                .font(.title)
                .padding(.bottom)
            
            Text("Import and archive handling preferences would appear here")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct ProcessingPreferencesView: View {
    var body: some View {
        Form {
            Text("Processing Preferences")
                .font(.title)
                .padding(.bottom)
            
            Text("Photo and metadata processing preferences would appear here")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct AdvancedPreferencesView: View {
    var body: some View {
        Form {
            Text("Advanced Preferences")
                .font(.title)
                .padding(.bottom)
            
            Text("Advanced technical preferences would appear here")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// Preview provider
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif