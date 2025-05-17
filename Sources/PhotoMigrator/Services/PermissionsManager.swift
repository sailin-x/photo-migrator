import Foundation
import Photos
import Combine

/// Types of operations that require permissions
enum PermissionOperation {
    case `import`
    case organizingAlbums
    case export
}

/// Types of permissions
enum PermissionType {
    case photoLibrary
    case fileAccess
}

/// Centralized service for managing app permissions
class PermissionsManager: ObservableObject {
    /// Shared singleton instance
    static let shared = PermissionsManager()
    
    /// Logger instance
    private let logger = Logger.shared
    
    /// Published permission statuses for UI binding
    @Published var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    
    /// Observable publisher for photo library status changes
    var photoLibraryStatusPublisher: AnyPublisher<PHAuthorizationStatus, Never> {
        $photoLibraryStatus.eraseToAnyPublisher()
    }
    
    /// User-friendly explanations for permissions
    let photoLibraryPermissionExplanation = "PhotoMigrator needs access to your Photos library to import and organize your Google Photos. Without this permission, the app cannot migrate your photos."
    
    /// Private initializer for singleton
    private init() {
        // Initialize current permission statuses
        updatePhotoLibraryStatus()
    }
    
    /// Update the current photo library permission status
    func updatePhotoLibraryStatus() {
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    /// Request permission to access the Photos library
    /// - Parameters:
    ///   - level: The access level needed (.readWrite or .addOnly)
    ///   - explanation: Optional custom explanation to show
    ///   - completion: Completion handler called with the result
    func requestPhotoLibraryPermission(
        level: PHAccessLevel = .readWrite,
        explanation: String? = nil,
        completion: @escaping (PHAuthorizationStatus) -> Void
    ) {
        // Log the attempt to request permission
        logger.log("Requesting photo library permission with access level: \(level == .readWrite ? "readWrite" : "addOnly")")
        
        // Show custom explanation dialog before system prompt if this is the first request
        if photoLibraryStatus == .notDetermined {
            // In a real implementation, we would show a custom alert first
            // For now, we log the explanation
            logger.log("Permission explanation: \(explanation ?? photoLibraryPermissionExplanation)")
        }
        
        // Request permission using PhotoKit
        PHPhotoLibrary.requestAuthorization(for: level) { [weak self] status in
            DispatchQueue.main.async {
                self?.photoLibraryStatus = status
                completion(status)
                
                // Log the result
                self?.logger.log("Photo library permission status: \(self?.statusDescription(for: status) ?? "unknown")")
                
                // Show recovery guidance if denied
                if status == .denied || status == .restricted {
                    // In a real implementation, we would show recovery instructions
                    self?.logger.log("Permission denied or restricted. Would show recovery instructions.", type: .warning)
                }
            }
        }
    }
    
    /// Get a human-readable description of a PHAuthorizationStatus
    /// - Parameter status: The PHAuthorizationStatus to describe
    /// - Returns: A human-readable description
    private func statusDescription(for status: PHAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .limited:
            return "Limited"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Check if the app has sufficient photo library permissions for the given operation
    /// - Parameter operation: The operation that requires permissions (.import, .export, etc.)
    /// - Returns: A tuple with a boolean indicating if permission is granted and a recovery suggestion
    func hasPhotoLibraryPermission(for operation: PermissionOperation) -> (hasPermission: Bool, recoverySuggestion: String?) {
        switch operation {
        case .import:
            // For importing, we need at least addOnly permission
            let hasPermission = photoLibraryStatus == .authorized || photoLibraryStatus == .limited
            let suggestion = hasPermission ? nil : "To import photos, go to Settings > Privacy > Photos and enable access for PhotoMigrator."
            return (hasPermission, suggestion)
            
        case .organizingAlbums:
            // For organizing albums, we need full readWrite access
            let hasPermission = photoLibraryStatus == .authorized
            let suggestion = hasPermission ? nil : "To organize photos into albums, go to Settings > Privacy > Photos and select 'All Photos' for PhotoMigrator."
            return (hasPermission, suggestion)
            
        case .export:
            // For export, we need read access
            let hasPermission = photoLibraryStatus == .authorized
            let suggestion = hasPermission ? nil : "To export photos, go to Settings > Privacy > Photos and select 'All Photos' for PhotoMigrator."
            return (hasPermission, suggestion)
        }
    }
    
    /// Present recovery instructions for when permissions are denied
    /// - Parameters:
    ///   - permissionType: The type of permission
    ///   - operation: The operation that was attempted
    func showRecoveryInstructions(for permissionType: PermissionType, operation: PermissionOperation) {
        // In a real implementation, this would present a UI dialog
        // For now, we just log the instructions
        
        switch permissionType {
        case .photoLibrary:
            let (_, suggestion) = hasPhotoLibraryPermission(for: operation)
            if let suggestion = suggestion {
                logger.log("Recovery suggestion: \(suggestion)", type: .warning)
            }
        case .fileAccess:
            logger.log("Recovery suggestion: Please allow access to files in the system dialog when prompted.", type: .warning)
        }
    }
    
    /// Request permission asynchronously (Swift concurrency version)
    /// - Parameters:
    ///   - level: The access level needed
    ///   - explanation: Optional custom explanation
    /// - Returns: A tuple with permission granted flag and error
    func requestPhotoLibraryPermissionAsync(
        level: PHAccessLevel = .readWrite,
        explanation: String? = nil
    ) async -> (Bool, Error?) {
        await withCheckedContinuation { continuation in
            requestPhotoLibraryPermission(level: level, explanation: explanation) { status in
                switch status {
                case .authorized:
                    continuation.resume(returning: (true, nil))
                case .limited:
                    // Limited access is still usable, but we should indicate this to the user
                    continuation.resume(returning: (true, nil))
                case .denied, .restricted:
                    continuation.resume(returning: (false, MigrationError.photosAccessDenied))
                case .notDetermined:
                    // This shouldn't happen after requesting authorization
                    continuation.resume(returning: (false, MigrationError.unknown))
                @unknown default:
                    continuation.resume(returning: (false, MigrationError.unknown))
                }
            }
        }
    }
} 