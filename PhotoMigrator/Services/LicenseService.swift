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

struct License: Codable {
    let id: String
    let userId: String
    let key: String
    let type: LicenseType
    let activationsCount: Int
    let maxActivations: Int
    let createdAt: Date
    let expiresAt: Date?
    
    var isExpired: Bool {
        if let expiryDate = expiresAt {
            return Date() > expiryDate
        }
        return false
    }
    
    var hasRemainingActivations: Bool {
        return activationsCount < maxActivations
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
    
    @Published var hasValidLicense: Bool = false
    @Published var licenseType: String = "none"
    @Published var expirationDate: Date?
    @Published var daysRemainingInTrial: Int = 0
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
                
                if let expDate = license.expiresAt {
                    daysRemainingInTrial = Calendar.current.dateComponents([.day], from: Date(), to: expDate).day ?? 0
                }
                
                remainingActivations = license.maxActivations - license.activationsCount
                canUseApp = true
            } else {
                // License has expired
                hasValidLicense = false
                licenseType = "none"
                
                // Check if trial is still valid
                if let trialExpiry = UserDefaults.standard.object(forKey: "trialExpirationDate") as? Date,
                   trialExpiry > Date() {
                    // Trial is still valid
                    licenseType = "trial"
                    expirationDate = trialExpiry
                    daysRemainingInTrial = Calendar.current.dateComponents([.day], from: Date(), to: trialExpiry).day ?? 0
                    canUseApp = true
                } else {
                    canUseApp = false
                }
            }
        } else {
            // No license found, check for trial
            if let trialExpiry = UserDefaults.standard.object(forKey: "trialExpirationDate") as? Date {
                if trialExpiry > Date() {
                    // Trial is still valid
                    hasValidLicense = true
                    licenseType = "trial"
                    expirationDate = trialExpiry
                    daysRemainingInTrial = Calendar.current.dateComponents([.day], from: Date(), to: trialExpiry).day ?? 0
                    canUseApp = true
                } else {
                    // Trial has expired
                    hasValidLicense = false
                    licenseType = "none"
                    canUseApp = false
                }
            } else {
                // No trial or license
                hasValidLicense = false
                licenseType = "none"
                canUseApp = false
            }
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
                userId: "user123",
                key: licenseKey,
                type: .perpetual,
                activationsCount: 1,
                maxActivations: 2,
                createdAt: Date(),
                expiresAt: nil
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
                self.remainingActivations = license.maxActivations - license.activationsCount
                self.canUseApp = true
            }
        } else {
            throw LicenseError.invalidLicenseKey
        }
    }
    
    func startTrial() async throws {
        // Check if trial has already been used
        if UserDefaults.standard.object(forKey: "trialExpirationDate") != nil {
            throw LicenseError.trialAlreadyUsed
        }
        
        // Simulate network request to Supabase to register trial
        // In a real implementation, this would make an API call
        
        // Simulate delay for network request
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Set trial expiration to 14 days from now
        let trialExpirationDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        UserDefaults.standard.set(trialExpirationDate, forKey: "trialExpirationDate")
        
        // Update UI on main thread
        await MainActor.run {
            self.hasValidLicense = true
            self.licenseType = "trial"
            self.expirationDate = trialExpirationDate
            self.daysRemainingInTrial = 14
            self.canUseApp = true
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
            
            // Check if trial is still valid
            if let trialExpiry = UserDefaults.standard.object(forKey: "trialExpirationDate") as? Date,
               trialExpiry > Date() {
                self.licenseType = "trial"
                self.expirationDate = trialExpiry
                self.daysRemainingInTrial = Calendar.current.dateComponents([.day], from: Date(), to: trialExpiry).day ?? 0
                self.canUseApp = true
            } else {
                self.canUseApp = false
            }
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
            return "\(license.activationsCount)/\(license.maxActivations)"
        }
        return "0/0"
    }
}