import Foundation

/// Represents a user in the system
struct User: Codable, Identifiable {
    /// Unique identifier
    var id: String
    
    /// User's email address
    var email: String
    
    /// User's display name
    var name: String?
    
    /// When the user was created
    var createdAt: Date
    
    /// When the user last logged in
    var lastLoginAt: Date?
    
    /// Whether the user's email is verified
    var isEmailVerified: Bool
    
    /// User's subscription status
    var subscriptionStatus: SubscriptionStatus
    
    /// User's account type
    var accountType: AccountType
    
    /// When the user's trial ends, if applicable
    var trialEndsAt: Date?
    
    /// Account type options
    enum AccountType: String, Codable {
        case free = "free"
        case trial = "trial"
        case basic = "basic"
        case premium = "premium"
    }
    
    /// Subscription status options
    enum SubscriptionStatus: String, Codable {
        case none = "none"
        case trialing = "trialing"
        case active = "active"
        case pastDue = "past_due"
        case canceled = "canceled"
        case expired = "expired"
    }
    
    /// Whether the user has an active paid subscription
    var hasActiveSubscription: Bool {
        return subscriptionStatus == .active || 
               (subscriptionStatus == .trialing && (trialEndsAt ?? Date()) > Date())
    }
    
    /// Whether the user can use the application's full features
    var canUseApp: Bool {
        return hasActiveSubscription || accountType == .free
    }
    
    /// Time remaining in trial, if applicable
    var trialTimeRemaining: TimeInterval? {
        guard let trialEndsAt = trialEndsAt else { return nil }
        return trialEndsAt.timeIntervalSince(Date())
    }
    
    /// Format trial time remaining in a user-friendly way
    var formattedTrialTimeRemaining: String? {
        guard let timeRemaining = trialTimeRemaining, timeRemaining > 0 else { return nil }
        
        let days = Int(timeRemaining / (24 * 60 * 60))
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") remaining"
        }
        
        let hours = Int(timeRemaining / (60 * 60))
        if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") remaining"
        }
        
        let minutes = Int(timeRemaining / 60)
        return "\(minutes) minute\(minutes == 1 ? "" : "s") remaining"
    }
}