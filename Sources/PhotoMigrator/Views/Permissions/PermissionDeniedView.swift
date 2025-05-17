import SwiftUI
import Photos

/// A view shown when permission is denied, with recovery instructions
struct PermissionDeniedView: View {
    /// The type of permission that was denied
    let permissionType: PermissionType
    
    /// The operation that requires permission
    let operation: PermissionOperation
    
    /// Action to perform when the user wants to try again
    var onTryAgain: () -> Void
    
    /// Action to perform when the user wants to continue without permission
    var onContinueAnyway: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.orange)
            
            Text("Permission Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(recoverySuggestion)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                // Open system settings
                openSystemSettings()
            }) {
                Text("Open Settings")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Button(action: onTryAgain) {
                Text("Try Again")
                    .foregroundColor(.blue)
            }
            
            Button(action: onContinueAnyway) {
                Text("Continue Without Permission")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(16)
    }
    
    /// The recovery suggestion text
    private var recoverySuggestion: String {
        switch permissionType {
        case .photoLibrary:
            let (_, suggestion) = PermissionsManager.shared.hasPhotoLibraryPermission(for: operation)
            return suggestion ?? "To continue, PhotoMigrator needs access to your Photos library. Please open Settings and grant permission."
        case .fileAccess:
            return "PhotoMigrator needs access to files to function properly. Please allow access when prompted."
        }
    }
    
    /// Open system settings for this permission type
    private func openSystemSettings() {
        switch permissionType {
        case .photoLibrary:
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos")!)
        case .fileAccess:
            // There's no direct way to open file access settings on macOS
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
        }
    }
} 