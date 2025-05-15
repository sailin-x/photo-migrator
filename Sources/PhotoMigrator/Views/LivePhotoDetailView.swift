import SwiftUI
import AVKit

/// A view that displays details about a Live Photo and provides reconstruction options
struct LivePhotoDetailView: View {
    /// The media item representing a Live Photo
    let mediaItem: MediaItem
    
    /// The video component URL if available
    let videoComponentURL: URL?
    
    /// Callback when user decides to reconstruct the Live Photo
    var onReconstructTapped: (() -> Void)?
    
    /// State for video player
    @State private var player: AVPlayer?
    @State private var isPreviewPlaying = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Live Photo Details")
                .font(.title2)
                .fontWeight(.bold)
            
            // Image Preview
            if let imageURL = mediaItem.fileURL {
                ZStack {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            SwiftUI.ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    
                    // Live Photo badge
                    Image(systemName: "livephoto")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .position(x: 30, y: 30)
                }
            }
            
            // Component details
            Group {
                DetailRow(label: "File Name", value: mediaItem.fileURL.lastPathComponent)
                
                DetailRow(label: "Type", value: "Live Photo")
                
                if let creationDate = mediaItem.timestamp {
                    DetailRow(label: "Creation Date", value: formatDate(creationDate))
                }
                
                if let location = getLocationString() {
                    DetailRow(label: "Location", value: location)
                }
                
                if let videoURL = videoComponentURL {
                    DetailRow(label: "Motion Component", value: videoURL.lastPathComponent)
                    
                    // Video preview
                    if player == nil {
                        Button("Preview Motion Component") {
                            player = AVPlayer(url: videoURL)
                            isPreviewPlaying = true
                        }
                        .buttonStyle(.bordered)
                        .padding(.vertical, 6)
                    } else {
                        VideoPlayer(player: player)
                            .frame(height: 200)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            )
                            .padding(.vertical, 8)
                        
                        // Play/Pause/Close controls
                        HStack {
                            Button(action: {
                                if isPreviewPlaying {
                                    player?.pause()
                                } else {
                                    player?.play()
                                }
                                isPreviewPlaying.toggle()
                            }) {
                                Image(systemName: isPreviewPlaying ? "pause.fill" : "play.fill")
                                Text(isPreviewPlaying ? "Pause" : "Play")
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Button("Close Preview") {
                                player?.pause()
                                player = nil
                                isPreviewPlaying = false
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    DetailRow(label: "Motion Component", value: "Not found")
                        .foregroundColor(.red)
                }
            }
            
            Divider()
            
            // Reconstruction options
            VStack(alignment: .leading, spacing: 12) {
                Text("Reconstruction Options")
                    .font(.headline)
                
                if videoComponentURL != nil {
                    Button(action: {
                        onReconstructTapped?()
                    }) {
                        Label("Reconstruct Live Photo", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.vertical, 4)
                } else {
                    Text("Cannot reconstruct Live Photo: Missing motion component")
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .padding(.vertical, 4)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: 500, maxHeight: 700)
        .onDisappear {
            // Clean up player when view disappears
            player?.pause()
            player = nil
        }
    }
    
    /// Format a Date object to readable string
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Create a formatted location string
    private func getLocationString() -> String? {
        guard let latitude = mediaItem.latitude, let longitude = mediaItem.longitude else {
            return nil
        }
        return "\(String(format: "%.5f", latitude)), \(String(format: "%.5f", longitude))"
    }
}

/// A simple row showing a detail label and value
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(label):")
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

struct LivePhotoDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let url = URL(fileURLWithPath: "/path/to/sample.jpg")
        let videoURL = URL(fileURLWithPath: "/path/to/sample.mov")
        
        // Create a sample media item
        let mediaItem = MediaItem(
            id: "123",
            title: "Sample Photo",
            description: "This is a sample photo",
            timestamp: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            fileURL: url,
            fileType: .livePhoto,
            albumNames: ["Vacation"],
            isFavorite: true
        )
        
        return LivePhotoDetailView(
            mediaItem: mediaItem,
            videoComponentURL: videoURL
        )
    }
} 