import Foundation

/// Errors specific to file operations
enum FileSecurityError: Error {
    case pathTraversal(path: String)
    case invalidPath(path: String, reason: String)
    case outsideSandbox(path: String)
    case operationFailed(operation: String, reason: String)
    
    var localizedDescription: String {
        switch self {
        case .pathTraversal(let path):
            return "Security error: Attempted path traversal detected for \(path)"
        case .invalidPath(let path, let reason):
            return "Invalid path: \(path), reason: \(reason)"
        case .outsideSandbox(let path):
            return "Security error: Path is outside the application sandbox: \(path)"
        case .operationFailed(let operation, let reason):
            return "File operation failed: \(operation), reason: \(reason)"
        }
    }
}

/// A secure wrapper around FileManager that provides safe file operations
/// and prevents common security vulnerabilities like path traversal attacks
class SecureFileManager {
    /// Shared singleton instance for easy access
    static let shared = SecureFileManager()
    
    /// The underlying FileManager
    private let fileManager = FileManager.default
    
    /// Logger instance
    private let logger = Logger.shared
    
    /// App's primary container directory (unique per app, created by the system)
    private lazy var applicationSupportDirectory: URL = {
        do {
            return try fileManager.url(for: .applicationSupportDirectory,
                                      in: .userDomainMask,
                                      appropriateFor: nil,
                                      create: true)
                .appendingPathComponent("PhotoMigrator", isDirectory: true)
        } catch {
            // Fallback to documents directory if application support is unavailable
            logger.log("Failed to access Application Support directory: \(error.localizedDescription)", type: .error)
            return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PhotoMigrator", isDirectory: true)
        }
    }()
    
    /// Directory for app logs
    private lazy var logsDirectory: URL = {
        let url = applicationSupportDirectory.appendingPathComponent("Logs", isDirectory: true)
        try? createDirectoryIfNeeded(at: url)
        return url
    }()
    
    /// Directory for imported media
    private lazy var mediaDirectory: URL = {
        let url = applicationSupportDirectory.appendingPathComponent("Media", isDirectory: true)
        try? createDirectoryIfNeeded(at: url)
        return url
    }()
    
    /// Directory for exported files
    private lazy var exportsDirectory: URL = {
        let url = applicationSupportDirectory.appendingPathComponent("Exports", isDirectory: true)
        try? createDirectoryIfNeeded(at: url)
        return url
    }()
    
    /// Temporary directory for the app (auto-cleaned by the system)
    private lazy var tempDirectory: URL = {
        return fileManager.temporaryDirectory.appendingPathComponent("PhotoMigrator", isDirectory: true)
    }()
    
    /// Set of allowed root directories
    private lazy var allowedRootDirectories: Set<URL> = {
        return [
            applicationSupportDirectory,
            mediaDirectory,
            exportsDirectory,
            tempDirectory,
            fileManager.temporaryDirectory,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        ]
    }()
    
    /// Private initializer for singleton
    private init() {
        // Ensure application support directory exists
        try? createDirectoryIfNeeded(at: applicationSupportDirectory)
    }
    
    // MARK: - Directory Access
    
    /// Get the logs directory URL (safe for file operations)
    func getLogsDirectory() -> URL {
        return logsDirectory
    }
    
    /// Get the media directory URL (safe for file operations)
    func getMediaDirectory() -> URL {
        return mediaDirectory
    }
    
    /// Get the exports directory URL (safe for file operations)
    func getExportsDirectory() -> URL {
        return exportsDirectory
    }
    
    /// Get a secure temporary directory
    /// - Returns: A URL to a unique temporary directory
    func getSecureTemporaryDirectory() throws -> URL {
        let tempDir = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try createDirectoryIfNeeded(at: tempDir)
        return tempDir
    }
    
    // MARK: - Path Validation and Security
    
    /// Validate if a file URL is secure and within the app's sandbox
    /// - Parameter url: The URL to validate
    /// - Throws: FileSecurityError if the path is invalid or outside sandbox
    func validateURL(_ url: URL) throws {
        // Normalize the path to resolve relative components
        let normalizedPath = url.standardized
        
        // Check for path traversal attempts using ".." components
        if url.path.contains("/../") || url.path.hasSuffix("/..") {
            logger.log("Path traversal attempt detected: \(url.path)", type: .error)
            throw FileSecurityError.pathTraversal(path: url.path)
        }
        
        // Ensure the path is within one of the allowed root directories
        guard isPathWithinAllowedDirectories(normalizedPath) else {
            logger.log("Path outside sandbox detected: \(url.path)", type: .error)
            throw FileSecurityError.outsideSandbox(path: url.path)
        }
    }
    
    /// Check if a path is within the allowed application directories
    /// - Parameter url: The URL to check
    /// - Returns: Boolean indicating if the path is within allowed directories
    private func isPathWithinAllowedDirectories(_ url: URL) -> Bool {
        return allowedRootDirectories.contains { rootDir in
            url.path.starts(with: rootDir.path)
        }
    }
    
    /// Sanitize a file path to ensure it's safe
    /// - Parameter path: The path to sanitize
    /// - Returns: A sanitized path
    /// - Throws: FileSecurityError if the path cannot be sanitized
    func sanitizePath(_ path: String) throws -> String {
        // Convert to URL for proper handling
        guard let url = URL(string: path) ?? URL(fileURLWithPath: path) else {
            throw FileSecurityError.invalidPath(path: path, reason: "Cannot convert to URL")
        }
        
        // Normalize the path
        let standardizedURL = url.standardized
        
        // Check for suspicious patterns
        if standardizedURL.path.contains("/../") || standardizedURL.path.hasSuffix("/..") {
            throw FileSecurityError.pathTraversal(path: path)
        }
        
        return standardizedURL.path
    }
    
    /// Create a safe file URL within an allowed directory
    /// - Parameters:
    ///   - filename: The filename to use
    ///   - directory: The base directory (must be one of the allowed directories)
    /// - Returns: A secure URL for the file
    /// - Throws: FileSecurityError if the resulting path would be insecure
    func createSecureFileURL(filename: String, in directory: URL) throws -> URL {
        // Sanitize the filename (remove path separators and potentially dangerous characters)
        let sanitizedFilename = filename
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "..", with: "_")
        
        // Create the URL
        let fileURL = directory.appendingPathComponent(sanitizedFilename)
        
        // Validate the resulting URL
        try validateURL(fileURL)
        
        return fileURL
    }
    
    // MARK: - File Operations
    
    /// Check if a file exists at the specified URL
    /// - Parameter url: The URL to check
    /// - Returns: Boolean indicating if the file exists
    /// - Throws: FileSecurityError if the path is invalid
    func fileExists(at url: URL) throws -> Bool {
        try validateURL(url)
        return fileManager.fileExists(atPath: url.path)
    }
    
    /// Check if a file exists at the specified path
    /// - Parameter path: The path to check
    /// - Returns: Boolean indicating if the file exists
    /// - Throws: FileSecurityError if the path is invalid
    func fileExists(atPath path: String) throws -> Bool {
        let sanitizedPath = try sanitizePath(path)
        return fileManager.fileExists(atPath: sanitizedPath)
    }
    
    /// Create a directory if it doesn't already exist
    /// - Parameter url: The URL where the directory should be created
    /// - Throws: FileSecurityError if the path is invalid or operation fails
    func createDirectoryIfNeeded(at url: URL) throws {
        try validateURL(url)
        
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                logger.log("Created directory at: \(url.path)")
            } catch {
                logger.log("Failed to create directory at \(url.path): \(error.localizedDescription)", type: .error)
                throw FileSecurityError.operationFailed(operation: "create directory", reason: error.localizedDescription)
            }
        }
    }
    
    /// Delete a file or directory
    /// - Parameter url: The URL to delete
    /// - Throws: FileSecurityError if the path is invalid or operation fails
    func removeItem(at url: URL) throws {
        try validateURL(url)
        
        do {
            try fileManager.removeItem(at: url)
            logger.log("Removed item at: \(url.path)")
        } catch {
            logger.log("Failed to remove item at \(url.path): \(error.localizedDescription)", type: .error)
            throw FileSecurityError.operationFailed(operation: "remove item", reason: error.localizedDescription)
        }
    }
    
    /// Read the contents of a file
    /// - Parameter url: The URL to read from
    /// - Returns: The data from the file
    /// - Throws: FileSecurityError if the path is invalid or read fails
    func readFile(at url: URL) throws -> Data {
        try validateURL(url)
        
        do {
            return try Data(contentsOf: url)
        } catch {
            logger.log("Failed to read file at \(url.path): \(error.localizedDescription)", type: .error)
            throw FileSecurityError.operationFailed(operation: "read file", reason: error.localizedDescription)
        }
    }
    
    /// Write data to a file
    /// - Parameters:
    ///   - data: The data to write
    ///   - url: The URL to write to
    /// - Throws: FileSecurityError if the path is invalid or write fails
    func writeFile(data: Data, to url: URL) throws {
        try validateURL(url)
        
        do {
            try data.write(to: url)
            logger.log("Wrote data to file at: \(url.path)")
        } catch {
            logger.log("Failed to write file at \(url.path): \(error.localizedDescription)", type: .error)
            throw FileSecurityError.operationFailed(operation: "write file", reason: error.localizedDescription)
        }
    }
    
    /// Get the contents of a directory
    /// - Parameter url: The URL of the directory
    /// - Returns: Array of URLs for the directory contents
    /// - Throws: FileSecurityError if the path is invalid or operation fails
    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try validateURL(url)
        
        do {
            return try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        } catch {
            logger.log("Failed to get contents of directory at \(url.path): \(error.localizedDescription)", type: .error)
            throw FileSecurityError.operationFailed(operation: "list directory", reason: error.localizedDescription)
        }
    }
    
    /// Copy a file securely
    /// - Parameters:
    ///   - sourceURL: The source URL
    ///   - destinationURL: The destination URL
    /// - Throws: FileSecurityError if either path is invalid or copy fails
    func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        try validateURL(sourceURL)
        try validateURL(destinationURL)
        
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            logger.log("Copied item from \(sourceURL.path) to \(destinationURL.path)")
        } catch {
            logger.log("Failed to copy item: \(error.localizedDescription)", type: .error)
            throw FileSecurityError.operationFailed(operation: "copy item", reason: error.localizedDescription)
        }
    }
    
    /// Move a file securely
    /// - Parameters:
    ///   - sourceURL: The source URL
    ///   - destinationURL: The destination URL
    /// - Throws: FileSecurityError if either path is invalid or move fails
    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        try validateURL(sourceURL)
        try validateURL(destinationURL)
        
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            logger.log("Moved item from \(sourceURL.path) to \(destinationURL.path)")
        } catch {
            logger.log("Failed to move item: \(error.localizedDescription)", type: .error)
            throw FileSecurityError.operationFailed(operation: "move item", reason: error.localizedDescription)
        }
    }
    
    /// Get file attributes securely
    /// - Parameter url: The URL of the file
    /// - Returns: Dictionary of file attributes
    /// - Throws: FileSecurityError if the path is invalid or operation fails
    func attributesOfItem(at url: URL) throws -> [FileAttributeKey: Any] {
        try validateURL(url)
        
        do {
            return try fileManager.attributesOfItem(atPath: url.path)
        } catch {
            logger.log("Failed to get attributes for \(url.path): \(error.localizedDescription)", type: .error)
            throw FileSecurityError.operationFailed(operation: "get attributes", reason: error.localizedDescription)
        }
    }
    
    /// Create a file enumerator securely
    /// - Parameter url: The URL of the directory to enumerate
    /// - Returns: A file enumerator
    /// - Throws: FileSecurityError if the path is invalid
    func enumerator(at url: URL) throws -> FileManager.DirectoryEnumerator? {
        try validateURL(url)
        return fileManager.enumerator(at: url, includingPropertiesForKeys: nil)
    }
    
    /// Create a secure temporary file
    /// - Parameters:
    ///   - data: The data to write to the temporary file
    ///   - extension: Optional file extension
    /// - Returns: URL to the temporary file
    /// - Throws: FileSecurityError if creation fails
    func createSecureTemporaryFile(containing data: Data, extension: String? = nil) throws -> URL {
        let tempDir = try getSecureTemporaryDirectory()
        let fileName = UUID().uuidString
        let fileURL: URL
        
        if let fileExtension = `extension` {
            fileURL = tempDir.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
        } else {
            fileURL = tempDir.appendingPathComponent(fileName)
        }
        
        try writeFile(data: data, to: fileURL)
        return fileURL
    }
    
    /// Cleanup temporary directory
    /// - Parameter url: The URL of the temporary directory to remove
    func cleanupTemporaryDirectory(_ url: URL) {
        do {
            try removeItem(at: url)
        } catch {
            logger.log("Failed to clean up temporary directory: \(error.localizedDescription)", type: .warning)
        }
    }
} 