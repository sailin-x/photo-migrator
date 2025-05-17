import Foundation
import os.log

/// A secure logging system that respects privacy settings
class Logger {
    /// Shared singleton instance
    static let shared = Logger()
    
    /// System logger for secure logging
    private let osLog = OSLog(subsystem: "com.photomigrator.app", category: "Migration")
    
    /// File URL for log file
    private var logFileURL: URL?
    
    /// Preferences reference
    private let preferences = UserPreferences.shared
    
    /// Secure file manager
    private let secureFileManager = SecureFileManager.shared
    
    /// Private initializer for singleton
    private init() {
        setupLogFile()
    }
    
    /// Set up log file in app's secure logs directory
    private func setupLogFile() {
        do {
            // Get the logs directory from secure file manager
            let logsDirectoryURL = secureFileManager.getLogsDirectory()
            
            // Create log file with timestamp
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = dateFormatter.string(from: Date())
            
            // Create secure file URL
            logFileURL = try secureFileManager.createSecureFileURL(
                filename: "photomigrator_\(timestamp).log",
                in: logsDirectoryURL
            )
            
            // Write initial log header
            let header = "PhotoMigrator Log - Started at \(timestamp)\n" +
                        "----------------------------------------\n"
            try secureFileManager.writeFile(
                data: Data(header.utf8),
                to: logFileURL!
            )
            
            log("Logging system initialized")
        } catch {
            // If we can't create a log file, just use system logging
            os_log("Failed to create secure log file: %{public}@", log: osLog, type: .error, error.localizedDescription)
        }
    }
    
    /// Log a message
    /// - Parameters:
    ///   - message: The message to log
    ///   - type: Log type (default: .info)
    ///   - privacy: Whether to treat the message as sensitive (default: false)
    func log(_ message: String, type: OSLogType = .info, privacy: Bool = false) {
        let timestamp = getCurrentTimestamp()
        let logMessage = "[\(timestamp)] \(message)"
        
        // Check if this is sensitive information and respect privacy settings
        if privacy && !preferences.logSensitiveMetadata {
            // Log a sanitized message instead
            let sanitizedMessage = "[\(timestamp)] [REDACTED_SENSITIVE_INFO]"
            writeToLogFile(sanitizedMessage, type: type)
            os_log("[REDACTED_SENSITIVE_INFO]", log: osLog, type: type)
            return
        }
        
        // Log to file
        writeToLogFile(logMessage, type: type)
        
        // Log to system
        os_log("%{public}@", log: osLog, type: type, message)
    }
    
    /// Log sensitive information with privacy controls
    /// - Parameters:
    ///   - message: The sensitive message to log
    ///   - type: Log type (default: .info)
    func logSensitive(_ message: String, type: OSLogType = .info) {
        // Always consider this sensitive
        log(message, type: type, privacy: true)
    }
    
    /// Get the current timestamp for logging
    /// - Returns: Formatted timestamp string
    private func getCurrentTimestamp() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return dateFormatter.string(from: Date())
    }
    
    /// Write a message to the log file
    /// - Parameters:
    ///   - message: The message to write
    ///   - type: Log type
    private func writeToLogFile(_ message: String, type: OSLogType) {
        guard let logFileURL = logFileURL else { return }
        
        do {
            // Format with log level
            var levelString: String
            switch type {
            case .error:
                levelString = "ERROR"
            case .fault:
                levelString = "FAULT"
            case .debug:
                levelString = "DEBUG"
            case .info:
                levelString = "INFO"
            default:
                levelString = "TRACE"
            }
            
            let formattedMessage = "\(message) [\(levelString)]\n"
            
            // Read existing log data
            var logData: Data
            do {
                logData = try secureFileManager.readFile(at: logFileURL)
            } catch {
                // If file doesn't exist yet, start with empty data
                logData = Data()
            }
            
            // Append new log message
            if let messageData = formattedMessage.data(using: .utf8) {
                logData.append(messageData)
            }
            
            // Write updated log data
            try secureFileManager.writeFile(data: logData, to: logFileURL)
        } catch {
            // Just use system logging if file operations fail
            os_log("Failed to write to log file: %{public}@", log: osLog, type: .error, error.localizedDescription)
        }
    }
    
    /// Get the path to the current log file
    /// - Returns: URL of the log file, or nil if not available
    func getLogFilePath() -> URL? {
        return logFileURL
    }
    
    /// Securely clear all logs
    func clearLogs() {
        guard let logFileURL = logFileURL else { return }
        
        do {
            // Securely overwrite the file before deleting
            let secureData = Data(repeating: 0, count: 1024 * 1024) // 1MB of zeros
            try secureFileManager.writeFile(data: secureData, to: logFileURL)
            
            // Delete the file
            try secureFileManager.removeItem(at: logFileURL)
            
            // Create a new log file
            setupLogFile()
        } catch {
            os_log("Failed to clear logs: %{public}@", log: osLog, type: .error, error.localizedDescription)
        }
    }
    
    /// Log file system security warnings
    /// - Parameter warning: The security warning message
    func logSecurityWarning(_ warning: String) {
        log("⚠️ SECURITY WARNING: \(warning)", type: .error)
        os_log("SECURITY WARNING: %{public}@", log: osLog, type: .fault, warning)
    }
} 