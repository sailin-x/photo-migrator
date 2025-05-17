import Foundation

/// Errors specific to temporary file operations
enum TempFileError: Error {
    case creationFailed(reason: String)
    case deletionFailed(path: String, reason: String)
    case invalidPath(path: String, reason: String)
    case recoveryFailed(reason: String)
    case cleanupFailed(reason: String)
    
    var localizedDescription: String {
        switch self {
        case .creationFailed(let reason):
            return "Failed to create temporary file: \(reason)"
        case .deletionFailed(let path, let reason):
            return "Failed to securely delete temporary file at \(path): \(reason)"
        case .invalidPath(let path, let reason):
            return "Invalid temporary file path \(path): \(reason)"
        case .recoveryFailed(let reason):
            return "Failed to recover from orphaned temporary files: \(reason)"
        case .cleanupFailed(let reason):
            return "Failed to clean up temporary files: \(reason)"
        }
    }
}

/// Service for secure management of temporary files, ensuring proper creation,
/// shredding, and cleanup even after crashes
class SecureTempFileManager {
    /// Shared singleton instance
    static let shared = SecureTempFileManager()
    
    /// Logger instance
    private let logger = Logger.shared
    
    /// Secure file manager for file operations
    private let fileManager = SecureFileManager.shared
    
    /// Current active temporary file URLs
    private var activeTemporaryFiles = Set<URL>()
    
    /// Path to the registry file that tracks temporary files
    private lazy var registryFilePath: URL = {
        do {
            return try fileManager.createSecureFileURL(
                filename: "temp_file_registry.json",
                in: fileManager.getLogsDirectory()
            )
        } catch {
            logger.log("Failed to create secure path for temp file registry: \(error.localizedDescription)", type: .error)
            // Fallback to a secure temporary directory
            let fallbackPath = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoMigrator", isDirectory: true)
                .appendingPathComponent("temp_file_registry.json")
            return fallbackPath
        }
    }()
    
    /// Session identifier (used to identify temp files created in this session)
    private let sessionId = UUID().uuidString
    
    /// Lock for thread safety when modifying the file registry
    private let registryLock = NSLock()
    
    /// Initializer
    private init() {
        // Set up exit handler for cleanup
        setupExitHandler()
        
        // Try to recover orphaned temporary files from previous sessions
        tryRecoverOrphanedFiles()
    }
    
    /// Set up an exit handler to clean up temporary files when app exits
    private func setupExitHandler() {
        // Register at-exit handler with atexit()
        atexit {
            // This code will be executed when the app terminates
            SecureTempFileManager.shared.cleanupAllTemporaryFiles()
        }
        
        // Also register a notification observer for app termination
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    /// Handle app termination notification
    @objc private func appWillTerminate() {
        cleanupAllTemporaryFiles()
    }
    
    /// Create a secure temporary file
    /// - Parameters:
    ///   - data: Data to write to the file
    ///   - prefix: Optional prefix for the filename
    ///   - extension: Optional file extension
    /// - Returns: URL to the temporary file
    func createSecureTemporaryFile(containing data: Data, prefix: String? = nil, extension: String? = nil) throws -> URL {
        do {
            // Create a secure temporary directory if needed
            let tempDir = try fileManager.getSecureTemporaryDirectory()
            
            // Generate a secure filename
            let fileName = [prefix, sessionId, UUID().uuidString]
                .compactMap { $0 }
                .joined(separator: "-")
            
            // Create the file URL
            let fileURL: URL
            if let fileExtension = `extension` {
                fileURL = tempDir.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
            } else {
                fileURL = tempDir.appendingPathComponent(fileName)
            }
            
            // Write the data to the file
            try fileManager.writeFile(data: data, to: fileURL)
            
            // Register the temporary file
            registerTemporaryFile(fileURL)
            
            return fileURL
        } catch {
            logger.log("Failed to create secure temporary file: \(error.localizedDescription)", type: .error)
            throw TempFileError.creationFailed(reason: error.localizedDescription)
        }
    }
    
    /// Create a secure temporary directory
    /// - Parameter prefix: Optional prefix for the directory name
    /// - Returns: URL to the temporary directory
    func createSecureTemporaryDirectory(prefix: String? = nil) throws -> URL {
        do {
            // Create a base temporary directory
            let baseDir = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoMigrator", isDirectory: true)
            
            // Generate a secure directory name
            let dirName = [prefix, sessionId, UUID().uuidString]
                .compactMap { $0 }
                .joined(separator: "-")
            
            let dirURL = baseDir.appendingPathComponent(dirName, isDirectory: true)
            
            // Create the directory securely
            try fileManager.createDirectoryIfNeeded(at: dirURL)
            
            // Register the temporary directory
            registerTemporaryFile(dirURL)
            
            return dirURL
        } catch {
            logger.log("Failed to create secure temporary directory: \(error.localizedDescription)", type: .error)
            throw TempFileError.creationFailed(reason: error.localizedDescription)
        }
    }
    
    /// Securely delete a temporary file by overwriting its contents before removal
    /// - Parameter url: URL of the temporary file to delete
    func securelyDeleteTemporaryFile(_ url: URL) throws {
        do {
            // Check if the path is valid
            guard try fileManager.fileExists(at: url) else {
                throw TempFileError.invalidPath(path: url.path, reason: "File does not exist")
            }
            
            // Get file attributes to determine size
            let attributes = try fileManager.attributesOfItem(at: url)
            let fileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
            
            // If file size is 0 or we couldn't determine size, use a default small size
            let sizeToOverwrite = fileSize > 0 ? fileSize : 4096
            
            // Create random data for secure overwrite
            var secureData = Data(count: Int(sizeToOverwrite))
            
            // Fill the data with random bytes
            _ = secureData.withUnsafeMutableBytes { bytes in
                if let baseAddress = bytes.baseAddress {
                    arc4random_buf(baseAddress, bytes.count)
                    return bytes.count
                }
                return 0
            }
            
            // Overwrite file with random data multiple times (DoD 5220.22-M standard requires 3 passes)
            for pass in 1...3 {
                try fileManager.writeFile(data: secureData, to: url)
                logger.log("Completed secure overwrite pass \(pass) for \(url.lastPathComponent)")
                
                // Use different random data for each pass
                _ = secureData.withUnsafeMutableBytes { bytes in
                    if let baseAddress = bytes.baseAddress {
                        arc4random_buf(baseAddress, bytes.count)
                        return bytes.count
                    }
                    return 0
                }
            }
            
            // Finally, delete the file
            try fileManager.removeItem(at: url)
            
            // Unregister the temporary file
            unregisterTemporaryFile(url)
            
            logger.log("Securely deleted temporary file: \(url.lastPathComponent)")
        } catch let error as TempFileError {
            throw error
        } catch {
            logger.log("Failed to securely delete temporary file: \(error.localizedDescription)", type: .error)
            throw TempFileError.deletionFailed(path: url.path, reason: error.localizedDescription)
        }
    }
    
    /// Securely delete a temporary directory by overwriting all files in it before removal
    /// - Parameter directoryURL: URL of the directory to delete
    func securelyDeleteTemporaryDirectory(_ directoryURL: URL) throws {
        do {
            // Check if the directory exists
            guard try fileManager.fileExists(at: directoryURL) else {
                throw TempFileError.invalidPath(path: directoryURL.path, reason: "Directory does not exist")
            }
            
            // Get all files in the directory
            let contents = try fileManager.contentsOfDirectory(at: directoryURL)
            
            // Securely delete each file in the directory
            for fileURL in contents {
                do {
                    let attributes = try fileManager.attributesOfItem(at: fileURL)
                    let isDirectory = (attributes[.type] as? FileAttributeType) == .typeDirectory
                    
                    if isDirectory {
                        // Recursively delete subdirectories
                        try securelyDeleteTemporaryDirectory(fileURL)
                    } else {
                        // Securely delete individual files
                        try securelyDeleteTemporaryFile(fileURL)
                    }
                } catch {
                    logger.log("Error deleting item in temporary directory: \(error.localizedDescription)", type: .warning)
                    // Continue with other files even if one fails
                }
            }
            
            // Finally delete the empty directory
            try fileManager.removeItem(at: directoryURL)
            
            // Unregister the temporary directory
            unregisterTemporaryFile(directoryURL)
            
            logger.log("Securely deleted temporary directory: \(directoryURL.lastPathComponent)")
        } catch let error as TempFileError {
            throw error
        } catch {
            logger.log("Failed to securely delete temporary directory: \(error.localizedDescription)", type: .error)
            throw TempFileError.deletionFailed(path: directoryURL.path, reason: error.localizedDescription)
        }
    }
    
    /// Clean up all registered temporary files
    func cleanupAllTemporaryFiles() {
        registryLock.lock()
        defer { registryLock.unlock() }
        
        logger.log("Cleaning up all temporary files...")
        
        // Get a copy of active temporary files to avoid modification during iteration
        let filesToDelete = activeTemporaryFiles
        
        for fileURL in filesToDelete {
            do {
                let isDirectory = (try? fileManager.attributesOfItem(at: fileURL)[.type] as? FileAttributeType) == .typeDirectory
                
                if isDirectory {
                    try securelyDeleteTemporaryDirectory(fileURL)
                } else {
                    try securelyDeleteTemporaryFile(fileURL)
                }
            } catch {
                logger.log("Failed to clean up temporary file \(fileURL.path): \(error.localizedDescription)", type: .warning)
            }
        }
        
        // Clear the registry
        activeTemporaryFiles.removeAll()
        
        // Update the registry file
        updateRegistryFile()
        
        logger.log("Temporary file cleanup completed")
    }
    
    /// Register a temporary file in the tracking registry
    /// - Parameter fileURL: URL of the temporary file
    private func registerTemporaryFile(_ fileURL: URL) {
        registryLock.lock()
        defer { registryLock.unlock() }
        
        activeTemporaryFiles.insert(fileURL)
        updateRegistryFile()
    }
    
    /// Unregister a temporary file from the tracking registry
    /// - Parameter fileURL: URL of the temporary file
    private func unregisterTemporaryFile(_ fileURL: URL) {
        registryLock.lock()
        defer { registryLock.unlock() }
        
        activeTemporaryFiles.remove(fileURL)
        updateRegistryFile()
    }
    
    /// Update the registry file with the current set of active temporary files
    private func updateRegistryFile() {
        do {
            // Convert the set of URLs to an array of path strings
            let paths = Array(activeTemporaryFiles).map { $0.path }
            
            // Create the registry data structure
            let registry: [String: Any] = [
                "sessionId": sessionId,
                "timestamp": Date().timeIntervalSince1970,
                "tempFiles": paths
            ]
            
            // Convert to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: registry, options: .prettyPrinted)
            
            // Write to the registry file
            try fileManager.writeFile(data: jsonData, to: registryFilePath)
        } catch {
            logger.log("Failed to update temporary file registry: \(error.localizedDescription)", type: .error)
        }
    }
    
    /// Try to recover orphaned temporary files from previous sessions
    private func tryRecoverOrphanedFiles() {
        do {
            // Check if the registry file exists
            guard try fileManager.fileExists(at: registryFilePath) else {
                // No registry file means no orphaned files to recover
                return
            }
            
            // Read the registry file
            let jsonData = try fileManager.readFile(at: registryFilePath)
            
            // Parse the JSON
            guard let registry = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let orphanedPaths = registry["tempFiles"] as? [String] else {
                throw TempFileError.recoveryFailed(reason: "Invalid registry file format")
            }
            
            logger.log("Found \(orphanedPaths.count) orphaned temporary files from previous session")
            
            // Try to delete each orphaned file
            var deletedCount = 0
            for path in orphanedPaths {
                let fileURL = URL(fileURLWithPath: path)
                do {
                    if try fileManager.fileExists(at: fileURL) {
                        let isDirectory = (try? fileManager.attributesOfItem(at: fileURL)[.type] as? FileAttributeType) == .typeDirectory
                        
                        if isDirectory {
                            try securelyDeleteTemporaryDirectory(fileURL)
                        } else {
                            try securelyDeleteTemporaryFile(fileURL)
                        }
                        deletedCount += 1
                    }
                } catch {
                    logger.log("Failed to clean up orphaned file \(path): \(error.localizedDescription)", type: .warning)
                }
            }
            
            logger.log("Cleaned up \(deletedCount) orphaned temporary files")
            
            // Start with a fresh registry
            activeTemporaryFiles.removeAll()
            updateRegistryFile()
            
        } catch {
            logger.log("Failed to recover orphaned temporary files: \(error.localizedDescription)", type: .warning)
        }
    }
    
    /// Scheduled cleanup to periodically check for leftover temporary files
    func schedulePeriodicCleanup(interval: TimeInterval = 3600) {
        // Create a timer that fires every 'interval' seconds (default: 1 hour)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performScheduledCleanup()
        }
        
        // Make sure the timer continues to fire even when scrolling
        RunLoop.current.add(timer, forMode: .common)
        
        logger.log("Scheduled periodic temporary file cleanup every \(interval) seconds")
    }
    
    /// Perform a scheduled cleanup of temporary files
    private func performScheduledCleanup() {
        logger.log("Performing scheduled temporary file cleanup")
        
        // Cleanup current session's temporary files that are no longer needed
        cleanupAgedTemporaryFiles()
        
        // Also check for orphaned files from crashed sessions
        tryRecoverOrphanedFiles()
    }
    
    /// Clean up temporary files that are older than a certain age
    /// - Parameter maxAge: Maximum age in seconds (default: 24 hours)
    private func cleanupAgedTemporaryFiles(maxAge: TimeInterval = 86400) {
        let currentTime = Date().timeIntervalSince1970
        var filesToRemove = Set<URL>()
        
        registryLock.lock()
        defer { 
            registryLock.unlock()
            
            // After identifying old files, delete them
            for fileURL in filesToRemove {
                do {
                    let isDirectory = (try? fileManager.attributesOfItem(at: fileURL)[.type] as? FileAttributeType) == .typeDirectory
                    
                    if isDirectory {
                        try securelyDeleteTemporaryDirectory(fileURL)
                    } else {
                        try securelyDeleteTemporaryFile(fileURL)
                    }
                } catch {
                    logger.log("Failed to clean up aged temporary file \(fileURL.path): \(error.localizedDescription)", type: .warning)
                }
            }
        }
        
        // Check each file's creation date
        for fileURL in activeTemporaryFiles {
            do {
                // Get file attributes
                let attributes = try fileManager.attributesOfItem(at: fileURL)
                
                // Check creation date
                if let creationDate = attributes[.creationDate] as? Date {
                    let fileAge = currentTime - creationDate.timeIntervalSince1970
                    
                    // If file is older than maxAge, mark it for removal
                    if fileAge > maxAge {
                        filesToRemove.insert(fileURL)
                        logger.log("Marking aged temporary file for cleanup: \(fileURL.lastPathComponent) (age: \(Int(fileAge/3600)) hours)")
                    }
                }
            } catch {
                // If we can't get attributes, the file might be gone already
                filesToRemove.insert(fileURL)
                logger.log("Couldn't get attributes for temp file, marking for removal: \(fileURL.path)")
            }
        }
        
        if !filesToRemove.isEmpty {
            logger.log("Found \(filesToRemove.count) aged temporary files to clean up")
        }
    }
} 