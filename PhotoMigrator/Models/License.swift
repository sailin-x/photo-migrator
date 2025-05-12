import Foundation

/// Represents a software license
struct License: Codable, Identifiable {
    /// Unique identifier
    var id: String
    
    /// License key
    var licenseKey: String
    
    /// User ID the license is assigned to
    var userId: String
    
    /// License type
    var type: LicenseType
    
    /// When the license was purchased
    var purchasedAt: Date
    
    /// When the license expires, if applicable
    var expiresAt: Date?
    
    /// Whether the license is currently active
    var isActive: Bool
    
    /// Number of activations used
    var activationsUsed: Int
    
    /// Maximum allowed activations
    var maxActivations: Int
    
    /// Stripe payment ID, if applicable
    var paymentId: String?
    
    /// Order or invoice number
    var orderNumber: String?
    
    /// License types
    enum LicenseType: String, Codable {
        case perpetual = "perpetual"
        case subscription = "subscription"
        case trial = "trial"
    }
    
    /// Whether the license is expired
    var isExpired: Bool {
        if let expiresAt = expiresAt {
            return expiresAt < Date()
        }
        return false
    }
    
    /// Whether the license can be activated
    var canBeActivated: Bool {
        return isActive && !isExpired && activationsUsed < maxActivations
    }
    
    /// Available activations remaining
    var activationsRemaining: Int {
        return max(0, maxActivations - activationsUsed)
    }
    
    /// Time remaining until expiration, if applicable
    var timeRemaining: TimeInterval? {
        guard let expiresAt = expiresAt else { return nil }
        return expiresAt.timeIntervalSince(Date())
    }
    
    /// Format time remaining in a user-friendly way
    var formattedTimeRemaining: String? {
        guard let timeRemaining = timeRemaining, timeRemaining > 0 else { return nil }
        
        let days = Int(timeRemaining / (24 * 60 * 60))
        if days > 365 {
            let years = days / 365
            return "\(years) year\(years == 1 ? "" : "s") remaining"
        } else if days > 30 {
            let months = days / 30
            return "\(months) month\(months == 1 ? "" : "s") remaining"
        } else if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") remaining"
        }
        
        let hours = Int(timeRemaining / (60 * 60))
        return "\(hours) hour\(hours == 1 ? "" : "s") remaining"
    }
}