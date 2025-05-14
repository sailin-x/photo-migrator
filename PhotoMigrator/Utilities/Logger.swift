import Foundation

/// Logging level for messages
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

/// Simple logging utility for the application
class Logger {
    /// Shared instance for singleton access
    static let shared = Logger()
    
    /// File handle for writing to the log file
    private var fileHandle: FileHandle?
    
    /// URL to the log file
    private var logFileURL: URL?
    
    /// Whether to also print logs to the console
    private let printToConsole: Bool
    
    /// Minimum log level to record
    private let minimumLevel: LogLevel
    
    /// Initialize with default settings
    private init() {
        self.printToConsole = true
        self.minimumLevel = .debug
        setupLogFile()
    }
    
    /// Initialize with custom settings
    init(printToConsole: Bool = true, minimumLevel: LogLevel = .debug) {
        self.printToConsole = printToConsole
        self.minimumLevel = minimumLevel
        setupLogFile()
    }
    
    /// Log a message with a specified level
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level (default is .info)
    ///   - file: Source file (automatically captured)
    ///   - function: Function name (automatically captured)
    ///   - line: Line number (automatically captured)
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        // Skip messages below the minimum log level
        guard level.rawValue >= minimumLevel.rawValue else { return }
        
        let timestamp = formattedDate()
        let filename = URL(fileURLWithPath: file).lastPathComponent
        
        let logMessage = "[\(timestamp)] [\(level.emoji) \(level.rawValue)] [\(filename):\(line)] \(message)"
        
        // Write to log file
        if let fileHandle = fileHandle {
            if let data = (logMessage + "\n").data(using: .utf8) {
                fileHandle.write(data)
            }
        }
        
        // Print to console if enabled
        if printToConsole {
            print(logMessage)
        }
    }
    
    /// Create and set up the log file
    private func setupLogFile() {
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
            let dateString = dateFormatter.string(from: Date())
            
            let logsDirectory = documentsDirectory.appendingPathComponent("PhotoMigrator/Logs", isDirectory: true)
            try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
            
            logFileURL = logsDirectory.appendingPathComponent("PhotoMigrator_\(dateString).log")
            
            if let url = logFileURL {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                FileManager.default.createFile(atPath: url.path, contents: nil)
                fileHandle = try FileHandle(forWritingTo: url)
            }
        } catch {
            print("Failed to set up log file: \(error)")
        }
    }
    
    /// Get a formatted timestamp for logging
    private func formattedDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return dateFormatter.string(from: Date())
    }
    
    /// Close the log file handle
    deinit {
        try? fileHandle?.close()
    }
}

// MARK: - Convenience methods

extension Logger {
    /// Log a debug message
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    /// Log an info message
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    /// Log an error message
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
} 