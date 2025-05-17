import Foundation
import UniformTypeIdentifiers

struct FileUtils {
    /// Security-enhanced file manager
    private static let secureFileManager = SecureFileManager.shared
    
    /// Logger instance for reporting issues
    private static let logger = Logger.shared
    
    static func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    static func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "m4v", "3gp", "avi", "mkv", "webm"]
        return videoExtensions.contains(url.pathExtension.lowercased())
    }
    
    static func isJsonFile(_ url: URL) -> Bool {
        return url.pathExtension.lowercased() == "json"
    }
    
    /// Create a temporary directory with secure paths
    /// - Returns: URL to the secure temporary directory or nil if creation fails
    static func createTempDirectory() -> URL? {
        do {
            return try secureFileManager.getSecureTemporaryDirectory()
        } catch {
            logger.log("Failed to create secure temp directory: \(error.localizedDescription)", type: .error)
            return nil
        }
    }
    
    /// Safely cleanup a temporary directory
    /// - Parameter url: The URL of the temporary directory to remove
    static func cleanupTempDirectory(_ url: URL) {
        secureFileManager.cleanupTemporaryDirectory(url)
    }
    
    /// Get the MIME type for a file URL
    /// - Parameter url: The URL of the file
    /// - Returns: MIME type string
    static func getMIMEType(from url: URL) -> String {
        if #available(macOS 11.0, *) {
            if let uti = UTType(filenameExtension: url.pathExtension) {
                if let mimeType = uti.preferredMIMEType {
                    return mimeType
                }
            }
        }
        
        // Fallback for older macOS versions
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        case "gif":
            return "image/gif"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "mp":
            return "video/mp4" // Treating .mp as MP4 for Pixel Motion Photos
        default:
            return "application/octet-stream"
        }
    }
    
    /// Create a secure file URL in the application's media directory
    /// - Parameter filename: The filename (will be sanitized)
    /// - Returns: A secure URL or nil if creation fails
    static func secureMediaFileURL(for filename: String) -> URL? {
        do {
            return try secureFileManager.createSecureFileURL(
                filename: filename,
                in: secureFileManager.getMediaDirectory()
            )
        } catch {
            logger.log("Failed to create secure media file URL: \(error.localizedDescription)", type: .error)
            return nil
        }
    }
    
    /// Create a secure file URL in the application's exports directory
    /// - Parameter filename: The filename (will be sanitized)
    /// - Returns: A secure URL or nil if creation fails
    static func secureExportFileURL(for filename: String) -> URL? {
        do {
            return try secureFileManager.createSecureFileURL(
                filename: filename,
                in: secureFileManager.getExportsDirectory()
            )
        } catch {
            logger.log("Failed to create secure export file URL: \(error.localizedDescription)", type: .error)
            return nil
        }
    }
    
    /// Securely validate a file path
    /// - Parameter path: The path to validate
    /// - Returns: A boolean indicating if the path is valid and secure
    static func isSecurePath(_ path: String) -> Bool {
        do {
            _ = try secureFileManager.sanitizePath(path)
            return true
        } catch {
            logger.log("Insecure file path detected: \(error.localizedDescription)", type: .error)
            return false
        }
    }
}
