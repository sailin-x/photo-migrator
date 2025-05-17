import SwiftUI
import Photos

/// A view that explains permissions required by the app
struct PermissionExplanationView: View {
    /// The type of permission being explained
    let permissionType: PermissionType
    
    /// The operation requiring permission
    let operation: PermissionOperation
    
    /// The permissions manager
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    
    /// Completion handler when permission request is complete
    var onCompletion: (Bool) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.blue)
            
            Text(titleText)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(explanationText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: requestPermission) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Button(action: {
                // User skips permission request
                onCompletion(false)
            }) {
                Text("Not Now")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(16)
    }
    
    /// The icon name for the permission type
    private var iconName: String {
        switch permissionType {
        case .photoLibrary:
            return "photo.on.rectangle"
        case .fileAccess:
            return "folder"
        }
    }
    
    /// The title for the permission request
    private var titleText: String {
        switch permissionType {
        case .photoLibrary:
            return "Photos Access Required"
        case .fileAccess:
            return "File Access Required"
        }
    }
    
    /// The explanation text for the permission request
    private var explanationText: String {
        switch permissionType {
        case .photoLibrary:
            switch operation {
            case .import:
                return "PhotoMigrator needs permission to add photos to your Photos library. This allows the app to import your Google Photos while preserving metadata like creation dates, locations, and descriptions."
            case .organizingAlbums:
                return "To recreate your Google Photos albums in Apple Photos, PhotoMigrator needs permission to organize photos into albums."
            case .export:
                return "PhotoMigrator needs permission to access your Photos library to export photos."
            }
        case .fileAccess:
            return "PhotoMigrator needs access to files to process your Google Takeout archive and extract photos and metadata."
        }
    }
    
    /// Request the permission
    private func requestPermission() {
        switch permissionType {
        case .photoLibrary:
            permissionsManager.requestPhotoLibraryPermission { status in
                let granted = status == .authorized || status == .limited
                onCompletion(granted)
            }
        case .fileAccess:
            // File access permissions are typically handled by system panels
            // We would need to prompt for a specific file/folder here
            onCompletion(true)
        }
    }
} 