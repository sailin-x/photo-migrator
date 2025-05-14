import Foundation

struct DateTimeUtils {
    /// Converts a Unix timestamp string to a Date
    static func dateFromUnixTimestamp(_ timestamp: String) -> Date? {
        guard let timestampValue = Double(timestamp) else {
            return nil
        }
        
        return Date(timeIntervalSince1970: timestampValue)
    }
    
    /// Adjusts a UTC date to the local timezone
    static func adjustToLocalTimezone(_ date: Date) -> Date {
        let timeZone = TimeZone.current
        let seconds = timeZone.secondsFromGMT(for: date)
        return date.addingTimeInterval(TimeInterval(seconds))
    }
    
    /// Parses a date string from various Google Takeout formats
    static func parseGoogleTakeoutDate(_ dateString: String) -> Date? {
        // Try various date formats used by Google
        let formatters: [DateFormatter] = [
            // ISO8601 format
            ISO8601DateFormatter(),
            
            // Common Google format: "2023-01-15T14:30:45.123Z"
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                return formatter
            }(),
            
            // Alternative format: "2023-01-15 14:30:45"
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return formatter
            }(),
            
            // Another format: "Jan 15, 2023, 2:30:45 PM"
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM dd, yyyy, h:mm:ss a"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let date = (formatter as? ISO8601DateFormatter)?.date(from: dateString) ?? 
                          (formatter as? DateFormatter)?.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    /// Attempts to extract a date from a filename (if it follows common patterns)
    static func extractDateFromFilename(_ filename: String) -> Date? {
        // Try to match common date patterns in filenames
        
        // Pixel format: PXL_20230115_143045123.jpg
        let pixelPattern = "PXL_(\\d{8})_(\\d{9})"
        if let range = filename.range(of: pixelPattern, options: .regularExpression) {
            let match = String(filename[range])
            let components = match.components(separatedBy: "_")
            if components.count >= 3 {
                let dateString = components[1]
                let timeString = components[2]
                
                if dateString.count == 8 && timeString.count >= 6 {
                    let year = String(dateString.prefix(4))
                    let month = String(dateString.dropFirst(4).prefix(2))
                    let day = String(dateString.dropFirst(6).prefix(2))
                    
                    let hour = String(timeString.prefix(2))
                    let minute = String(timeString.dropFirst(2).prefix(2))
                    let second = String(timeString.dropFirst(4).prefix(2))
                    
                    let fullDateString = "\(year)-\(month)-\(day) \(hour):\(minute):\(second)"
                    
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    return formatter.date(from: fullDateString)
                }
            }
        }
        
        // IMG_20230115_143045.jpg
        let imgPattern = "IMG_(\\d{8})_(\\d{6})"
        if let range = filename.range(of: imgPattern, options: .regularExpression) {
            let match = String(filename[range])
            let components = match.components(separatedBy: "_")
            if components.count >= 3 {
                let dateString = components[1]
                let timeString = components[2]
                
                if dateString.count == 8 && timeString.count >= 6 {
                    let year = String(dateString.prefix(4))
                    let month = String(dateString.dropFirst(4).prefix(2))
                    let day = String(dateString.dropFirst(6).prefix(2))
                    
                    let hour = String(timeString.prefix(2))
                    let minute = String(timeString.dropFirst(2).prefix(2))
                    let second = String(timeString.dropFirst(4).prefix(2))
                    
                    let fullDateString = "\(year)-\(month)-\(day) \(hour):\(minute):\(second)"
                    
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    return formatter.date(from: fullDateString)
                }
            }
        }
        
        // YYYY-MM-DD_HH-MM-SS pattern
        let dashPattern = "(\\d{4})-(\\d{2})-(\\d{2})_(\\d{2})-(\\d{2})-(\\d{2})"
        if let range = filename.range(of: dashPattern, options: .regularExpression) {
            let match = String(filename[range])
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            return formatter.date(from: match)
        }
        
        return nil
    }
}
