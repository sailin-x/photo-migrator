import Foundation
import Combine

enum LicenseType: String, Codable {
    case trial = "trial"
    case subscription = "subscription"
    case perpetual = "perpetual"
    case none = "none"
}

enum LicenseError: Error {
    case invalidLicenseKey
    case licenseExpired
    case noRemainingActivations
    case alreadyActivated
    case networkError
    case serverError
    case trialAlreadyUsed
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .invalidLicenseKey:
            return "Invalid license key. Please check your key and try again."
        case .licenseExpired:
            return "This license has expired. Please renew your subscription."
        case .noRemainingActivations:
            return "No remaining activations for this license. Please deactivate on another device or purchase additional seats."
        case .alreadyActivated:
            return "This license is already activated on this device."
        case .networkError:
            return "Network error. Please check your internet connection and try again."
        case .serverError:
            return "Server error. Please try again later."
        case .trialAlreadyUsed:
            return "Trial period has already been used on this device."
        case .unknown:
            return "An unknown error occurred. Please try again."
        }
    }
}

struct MachineInfo: Codable {
    let id: String
    let name: String
    let model: String
    let osVersion: String
}

class LicenseService: ObservableObject {
    static let shared = LicenseService()
    
    // Maximum number of photos allowed in trial mode
    static let TRIAL_PHOTO_LIMIT = 50
    
    @Published var hasValidLicense: Bool = false
    @Published var licenseType: String = "none"
    @Published var expirationDate: Date?
    @Published var photosRemainingInTrial: Int = TRIAL_PHOTO_LIMIT
    @Published var remainingActivations: Int = 0
    @Published var canUseApp: Bool = false
    
    private var currentLicense: License?
    private var machineIdentifier: String = ""
    
    private let supabaseURL = "https://yourproject.supabase.co"
    private let supabaseKey = "your-supabase-key"
    
    private init() {
        // Generate or retrieve machine identifier
        generateMachineIdentifier()
        
        // Check for existing license
        checkExistingLicense()
    }
    
    private func generateMachineIdentifier() {
        // In a real implementation, this would generate a unique hardware identifier
        // based on system information that persists across app reinstalls
        
        if let storedId = UserDefaults.standard.string(forKey: "machineIdentifier") {
            machineIdentifier = storedId
        } else {
            // Generate a new identifier
            // In a real app, this would use system information (serial number, etc.)
            // For demo purposes, use a UUID
            machineIdentifier = UUID().uuidString
            UserDefaults.standard.set(machineIdentifier, forKey: "machineIdentifier")
        }
    }
    
    private func checkExistingLicense() {
        // In a real implementation, this would check for a stored license
        // and validate it with Supabase
        
        if let licenseData = UserDefaults.standard.data(forKey: "currentLicense"),
           let license = try? JSONDecoder().decode(License.self, from: licenseData) {
            
            // Validate license
            if license.type == .perpetual || (license.expiresAt != nil && license.expiresAt! > Date()) {
                // License is valid
                currentLicense = license
                hasValidLicense = true
                licenseType = license.type.rawValue
                expirationDate = license.expiresAt
                
                remainingActivations = license.activationsRemaining
                canUseApp = true
            } else {
                // License has expired
                hasValidLicense = false
                licenseType = "none"
                
                // Check if trial is still available
                loadTrialStatus()
            }
        } else {
            // No license found, check for trial
            loadTrialStatus()
        }
    }
    
    private func loadTrialStatus() {
        // Get photos processed count from UserDefaults
        let photosProcessed = UserDefaults.standard.integer(forKey: "trialPhotosProcessed")
        
        if photosProcessed < Self.TRIAL_PHOTO_LIMIT {
            // Trial is still available
            hasValidLicense = true
            licenseType = "trial"
            photosRemainingInTrial = Self.TRIAL_PHOTO_LIMIT - photosProcessed
            canUseApp = true
        } else {
            // Trial has been fully used
            hasValidLicense = false
            licenseType = "none"
            photosRemainingInTrial = 0
            canUseApp = false
        }
    }
    
    // MARK: - License Methods
    
    func activateLicense(licenseKey: String) async throws {
        // Simulate network request to Supabase for license activation
        // In a real implementation, this would make an API call
        
        // Simulate delay for network request
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Placeholder logic for license validation
        // In a real app, we would validate the license key with the server
        if licenseKey.count >= 10 {
            // Create a mock license
            let license = License(
                id: UUID().uuidString,
                licenseKey: licenseKey,
                userId: "user123",
                type: .perpetual,
                purchasedAt: Date(),
                expiresAt: nil,
                isActive: true,
                activationsUsed: 1,
                maxActivations: 2,
                paymentId: nil,
                orderNumber: nil
            )
            
            // Store the license locally
            let encoder = JSONEncoder()
            if let licenseData = try? encoder.encode(license) {
                UserDefaults.standard.set(licenseData, forKey: "currentLicense")
            }
            
            // Update UI on main thread
            await MainActor.run {
                self.currentLicense = license
                self.hasValidLicense = true
                self.licenseType = license.type.rawValue
                self.expirationDate = license.expiresAt
                self.remainingActivations = license.activationsRemaining
                self.canUseApp = true
            }
        } else {
            throw LicenseError.invalidLicenseKey
        }
    }
    
    func startTrial() async throws {
        // Check if trial has already been fully used
        let photosProcessed = UserDefaults.standard.integer(forKey: "trialPhotosProcessed")
        if photosProcessed >= Self.TRIAL_PHOTO_LIMIT {
            throw LicenseError.trialAlreadyUsed
        }
        
        // Simulate network request to Supabase to register trial
        // In a real implementation, this would make an API call
        
        // Simulate delay for network request
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // If this is a new trial, initialize the counter
        if photosProcessed == 0 {
            UserDefaults.standard.set(0, forKey: "trialPhotosProcessed")
        }
        
        // Update UI on main thread
        await MainActor.run {
            self.hasValidLicense = true
            self.licenseType = "trial"
            self.photosRemainingInTrial = Self.TRIAL_PHOTO_LIMIT - photosProcessed
            self.canUseApp = true
        }
    }
    
    /// Track a photo processed in trial mode
    func trackPhotoProcessed() {
        if licenseType == "trial" {
            let currentCount = UserDefaults.standard.integer(forKey: "trialPhotosProcessed")
            let newCount = currentCount + 1
            UserDefaults.standard.set(newCount, forKey: "trialPhotosProcessed")
            
            // Update the remaining count
            if newCount < Self.TRIAL_PHOTO_LIMIT {
                photosRemainingInTrial = Self.TRIAL_PHOTO_LIMIT - newCount
            } else {
                photosRemainingInTrial = 0
                // If limit reached, update license status
                hasValidLicense = false
                licenseType = "none"
                canUseApp = false
            }
        }
    }
    
    func refreshLicenseStatus() async {
        // In a real implementation, this would check the license status with the server
        // For demo purposes, just re-check the local state
        
        checkExistingLicense()
    }
    
    func deactivateLicense() async throws {
        // Simulate network request to Supabase to deactivate license
        // In a real implementation, this would make an API call
        
        // Simulate delay for network request
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Clear license data
        UserDefaults.standard.removeObject(forKey: "currentLicense")
        
        // Update UI on main thread
        await MainActor.run {
            self.currentLicense = nil
            self.hasValidLicense = false
            self.licenseType = "none"
            self.expirationDate = nil
            self.remainingActivations = 0
            
            // Check if trial is still available
            loadTrialStatus()
        }
    }
    
    // Helper properties
    
    var expirationDateString: String {
        if let date = expirationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        return "Never"
    }
    
    var activationsString: String {
        if let license = currentLicense {
            return "\(license.activationsUsed)/\(license.maxActivations)"
        }
        return "0/0"
    }
}