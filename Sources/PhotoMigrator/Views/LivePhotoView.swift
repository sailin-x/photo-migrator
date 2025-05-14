import SwiftUI

/// View for displaying and managing Live Photos
struct LivePhotoView: View {
    @StateObject private var livePhotoManager = LivePhotoManager()
    @State private var isScanning = false
    @State private var isReconstructing = false
    @State private var selectedDirectory: URL?
    @State private var selectedItem: MediaItem?
    @State private var showingDirectoryPicker = false
    @State private var showingDetail = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerView
            
            // Main content
            if livePhotoManager.livePhotoItems.isEmpty {
                emptyStateView
            } else {
                livePhotoListView
            }
            
            // Status footer
            statusView
        }
        .padding()
        .sheet(isPresented: $showingDirectoryPicker) {
            DirectoryPickerView(selectedURL: $selectedDirectory, onSelect: { url in
                selectedDirectory = url
                scanDirectory(url)
            })
        }
        .sheet(isPresented: $showingDetail) {
            if let item = selectedItem {
                LivePhotoDetailView(
                    mediaItem: item,
                    videoComponentURL: item.livePhotoComponentURL,
                    onReconstructTapped: {
                        showingDetail = false
                        Task {
                            await reconstructSingle(item)
                        }
                    }
                )
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Subviews
    
    /// Header view with title and action buttons
    private var headerView: some View {
        VStack(spacing: 12) {
            Text("Live Photo Reconstruction")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Detect and reconstruct Live Photos from your Google Takeout export")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button(action: {
                    showingDirectoryPicker = true
                }) {
                    Label("Select Directory", systemImage: "folder.badge.plus")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.bordered)
                .disabled(isScanning || isReconstructing)
                
                if !livePhotoManager.livePhotoItems.isEmpty {
                    Button(action: {
                        Task {
                            await reconstructAll()
                        }
                    }) {
                        Label("Reconstruct All", systemImage: "wand.and.stars")
                            .frame(minWidth: 150)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isScanning || isReconstructing || livePhotoManager.livePhotoItems.isEmpty)
                }
            }
            .padding(.top, 8)
        }
    }
    
    /// Empty state view when no Live Photos are found
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "livephoto")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
            
            Text("No Live Photos Found")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Select a directory containing your Google Takeout export to scan for Live Photos")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 350)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// List of discovered Live Photos
    private var livePhotoListView: some View {
        List {
            ForEach(livePhotoManager.livePhotoItems, id: \.id) { item in
                LivePhotoListItem(item: item)
                    .onTapGesture {
                        selectedItem = item
                        showingDetail = true
                    }
            }
        }
        .refreshable {
            if let dir = selectedDirectory {
                await scanDirectory(dir)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            Group {
                if isScanning {
                    ProgressView("Scanning for Live Photos...")
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                } else if isReconstructing {
                    let current = getCurrentReconstructionProgress()
                    VStack {
                        ProgressView("Reconstructing Live Photos...", value: current.0, total: current.1)
                            .progressViewStyle(.linear)
                            .padding(.bottom, 5)
                        
                        Text("\(current.0) of \(current.1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                        Button("Cancel") {
                            livePhotoManager.cancel()
                            isReconstructing = false
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                    .frame(width: 300)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        )
    }
    
    /// Status view showing statistics
    private var statusView: some View {
        VStack(spacing: 5) {
            if !livePhotoManager.livePhotoItems.isEmpty {
                HStack(spacing: 15) {
                    StatBadge(
                        icon: "livephoto",
                        label: "Found",
                        value: "\(livePhotoManager.stats.totalLivePhotosDetected)"
                    )
                    
                    StatBadge(
                        icon: "checkmark.circle",
                        label: "Reconstructed",
                        value: "\(livePhotoManager.stats.reconstructed)",
                        color: .green
                    )
                    
                    StatBadge(
                        icon: "exclamationmark.triangle",
                        label: "Failed",
                        value: "\(livePhotoManager.stats.failed)",
                        color: livePhotoManager.stats.failed > 0 ? .red : .gray
                    )
                    
                    StatBadge(
                        icon: "clock",
                        label: "Pending",
                        value: "\(livePhotoManager.stats.pending)",
                        color: .blue
                    )
                }
                .padding(.vertical, 5)
                
                if livePhotoManager.stats.reconstructed > 0 {
                    Text("Success Rate: \(String(format: "%.1f%%", livePhotoManager.stats.successRate))")
                        .foregroundColor(
                            livePhotoManager.stats.successRate > 90 ? .green :
                            livePhotoManager.stats.successRate > 70 ? .yellow : .orange
                        )
                        .font(.caption)
                        .padding(.top, 5)
                }
            }
        }
        .frame(height: 60)
    }
    
    // MARK: - Helper Methods
    
    /// Get current reconstruction progress
    private func getCurrentReconstructionProgress() -> (Double, Double) {
        switch livePhotoManager.status {
        case .reconstructing(let current, let total):
            return (Double(current), Double(total))
        default:
            return (0, 0)
        }
    }
    
    /// Scan a directory for Live Photos
    private func scanDirectory(_ url: URL) async {
        isScanning = true
        
        do {
            _ = try await livePhotoManager.scanForLivePhotos(in: url)
        } catch {
            alertTitle = "Scan Failed"
            alertMessage = "Failed to scan directory: \(error.localizedDescription)"
            showingAlert = true
        }
        
        isScanning = false
    }
    
    /// Reconstruct a single Live Photo
    private func reconstructSingle(_ item: MediaItem) async {
        isReconstructing = true
        
        do {
            let assetId = try await livePhotoManager.reconstructLivePhoto(item)
            
            if assetId != nil {
                alertTitle = "Success"
                alertMessage = "Live Photo was successfully reconstructed and added to your Photos library."
            } else {
                alertTitle = "Reconstruction Failed"
                alertMessage = "Failed to reconstruct the Live Photo. Please check the logs for details."
            }
            showingAlert = true
        } catch {
            alertTitle = "Error"
            alertMessage = "Failed to reconstruct Live Photo: \(error.localizedDescription)"
            showingAlert = true
        }
        
        isReconstructing = false
    }
    
    /// Reconstruct all discovered Live Photos
    private func reconstructAll() async {
        isReconstructing = true
        
        do {
            let results = try await livePhotoManager.reconstructLivePhotos(livePhotoManager.livePhotoItems)
            
            alertTitle = "Reconstruction Complete"
            alertMessage = "Successfully reconstructed \(results.count) of \(livePhotoManager.livePhotoItems.count) Live Photos."
            showingAlert = true
        } catch {
            alertTitle = "Reconstruction Failed"
            alertMessage = "An error occurred: \(error.localizedDescription)"
            showingAlert = true
        }
        
        isReconstructing = false
    }
}

/// List item for a Live Photo
struct LivePhotoListItem: View {
    let item: MediaItem
    
    var body: some View {
        HStack(spacing: 15) {
            // Thumbnail
            ZStack {
                Color.gray.opacity(0.1)
                
                AsyncImage(url: item.fileURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            .overlay(
                Image(systemName: "livephoto")
                    .font(.caption)
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .offset(x: -2, y: -2),
                alignment: .topTrailing
            )
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                
                if let video = item.livePhotoComponentURL {
                    Text("Motion: \(video.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Motion component not found")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                if let date = item.timestamp {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Detail chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

/// Simple badge for showing stats
struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Text(value)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

/// View for picking a directory
struct DirectoryPickerView: View {
    @Binding var selectedURL: URL?
    var onSelect: (URL) -> Void
    @State private var isShowingFilePicker = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Directory")
                .font(.title)
                .fontWeight(.bold)
            
            Button("Choose Directory") {
                isShowingFilePicker = true
            }
            .buttonStyle(.borderedProminent)
            
            if let url = selectedURL {
                VStack(alignment: .leading) {
                    Text("Selected Directory:")
                        .fontWeight(.medium)
                    
                    Text(url.path)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding()
                
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Select") {
                        onSelect(url)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .onAppear {
            // Show file picker when this view appears
            isShowingFilePicker = true
        }
        .onChange(of: selectedURL) { _ in
            // Nothing needed here, just to track changes
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedURL = url
                }
            case .failure:
                // Handle error
                selectedURL = nil
            }
        }
    }
}

/// Preview
struct LivePhotoView_Previews: PreviewProvider {
    static var previews: some View {
        LivePhotoView()
    }
} 