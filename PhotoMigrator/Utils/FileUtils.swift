import Foundation
import UniformTypeIdentifiers

struct FileUtils {
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
    
    static func createTempDirectory() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            return tempDir
        } catch {
            print("Failed to create temp directory: \(error)")
            return nil
        }
    }
    
    static func cleanupTempDirectory(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Failed to clean up temp directory: \(error)")
        }
    }
    
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
}
