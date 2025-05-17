import SwiftUI
import Photos

/// A view that displays and manages permissions in the preferences
struct PermissionsPreferenceView: View {
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    
    var body: some View {
        GroupBox(label: Text("Permissions").font(.headline)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Photos Library:")
                    Spacer()
                    Text(statusText(for: permissionsManager.photoLibraryStatus))
                        .foregroundColor(statusColor(for: permissionsManager.photoLibraryStatus))
                    Button("Request Access") {
                        permissionsManager.requestPhotoLibraryPermission { _ in }
                    }
                    .disabled(permissionsManager.photoLibraryStatus != .notDetermined)
                }
                
                Text("PhotoMigrator uses Photos library access to import your Google Photos and organize them into albums.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if permissionsManager.photoLibraryStatus == .denied || 
                   permissionsManager.photoLibraryStatus == .restricted {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Photos access is currently denied. Open System Settings to enable access.")
                            .foregroundColor(.orange)
                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos")!)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }
    
    /// Get the status text for a given permission status
    private func statusText(for status: PHAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Granted"
        case .limited:
            return "Limited"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Get the status color for a given permission status
    private func statusColor(for status: PHAuthorizationStatus) -> Color {
        switch status {
        case .notDetermined:
            return .orange
        case .restricted, .denied:
            return .red
        case .authorized:
            return .green
        case .limited:
            return .yellow
        @unknown default:
            return .gray
        }
    }
} 