import Foundation
import os.log

/// Logging levels used by the application
enum LogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

/// Application-wide logging service
class Logger {
    /// Shared singleton instance
    static let shared = Logger()
    
    /// OS Log instance for system logging
    private let osLog = OSLog(subsystem: "com.photomigrator", category: "Application")
    
    /// Current minimum log level (defaults to info)
    var minimumLogLevel: LogLevel = .debug
    
    /// File URL for the log file if file logging is enabled
    private(set) var logFileURL: URL?
    
    /// File handle for writing to log file
    private var logFileHandle: FileHandle?
    
    /// Date formatter for log entries
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    /// Private initializer for singleton
    private init() {
        // Initialize log file if needed
        setupLogFile()
    }
    
    /// Sets up the log file in the application support directory
    private func setupLogFile() {
        do {
            let fileManager = FileManager.default
            let appSupportDir = try fileManager.url(for: .applicationSupportDirectory, 
                                                  in: .userDomainMask, 
                                                  appropriateFor: nil, 
                                                  create: true)
                .appendingPathComponent("PhotoMigrator", isDirectory: true)
            
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: appSupportDir.path) {
                try fileManager.createDirectory(at: appSupportDir, 
                                              withIntermediateDirectories: true)
            }
            
            // Create log file
            let timestamp = ISO8601DateFormatter().string(from: Date())
            logFileURL = appSupportDir.appendingPathComponent("photomigrator_\(timestamp).log")
            
            if let logFileURL = logFileURL {
                if !fileManager.fileExists(atPath: logFileURL.path) {
                    fileManager.createFile(atPath: logFileURL.path, contents: nil)
                }
                
                logFileHandle = try FileHandle(forWritingTo: logFileURL)
            }
        } catch {
            // If logging setup fails, just print to console
            print("Failed to set up log file: \(error.localizedDescription)")
        }
    }
    
    /// Log a message with the specified log level
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: Log level (defaults to .info)
    func log(_ message: String, level: LogLevel = .info) {
        // Log to system log
        os_log("%{public}@", log: osLog, type: level.osLogType, message)
        
        // Print to console if level meets threshold
        if level.rawValue >= minimumLogLevel.rawValue {
            let timestamp = dateFormatter.string(from: Date())
            print("[\(timestamp)] [\(level.description)] \(message)")
        }
    }
    
    /// Close the log file
    func closeLogFile() {
        logFileHandle?.closeFile()
        logFileHandle = nil
    }
    
    /// Get the contents of the log file
    /// - Returns: String contents of the log file or nil if not available
    func getLogContents() -> String? {
        guard let logFileURL = logFileURL else { return nil }
        
        do {
            return try String(contentsOf: logFileURL, encoding: .utf8)
        } catch {
            log("Failed to read log file: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
    
    /// Log a debug message
    func debug(_ message: String) {
        log(message, level: .debug)
    }
    
    /// Log an info message
    func info(_ message: String) {
        log(message, level: .info)
    }
    
    /// Log a warning message
    func warning(_ message: String) {
        log(message, level: .warning)
    }
    
    /// Log an error message
    func error(_ message: String) {
        log(message, level: .error)
    }
} 