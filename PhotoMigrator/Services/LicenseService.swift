import Foundation
import Combine
import Supabase

/// Service for managing and validating software licenses
class LicenseService: ObservableObject {
    /// Shared singleton instance
    static let shared = LicenseService()
    
    /// License state
    @Published var licenseState: LicenseState = .unknown
    
    /// Current license, if any
    @Published var currentLicense: License?
    
    /// Current error message, if any
    @Published var errorMessage: String?
    
    /// Whether a license activation is in progress
    @Published var isActivating = false
    
    /// Machine identification for activation
    private let machineId = MachineIdentifier.shared.getHardwareIdentifier()
    
    /// Local storage key for license
    private let licenseStorageKey = "PhotoMigrator.License"
    
    /// Authentication service
    private let authService = AuthService.shared
    
    /// License states
    enum LicenseState {
        case unknown
        case valid
        case expired
        case invalid
        case notActivated
        case trial
        case noLicense
    }
    
    /// Private initializer for singleton
    private init() {
        // Load license from local storage
        loadSavedLicense()
        
        // Listen for authentication state changes
        setupAuthStateListener()
    }
    
    /// Set up listener for authentication state changes
    private func setupAuthStateListener() {
        // When auth state changes, check if we need to fetch license info
        authService.$authState
            .sink { [weak self] state in
                if state == .authenticated {
                    Task {
                        await self?.fetchLicenseForCurrentUser()
                    }
                } else if state == .unauthenticated {
                    // Clear license if user logs out
                    self?.clearLicense()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Subscriptions for Combine
    private var cancellables = Set<AnyCancellable>()
    
    /// Load license from local storage
    private func loadSavedLicense() {
        guard let data = UserDefaults.standard.data(forKey: licenseStorageKey) else {
            licenseState = .noLicense
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let license = try decoder.decode(License.self, from: data)
            currentLicense = license
            
            // Validate the loaded license
            validateLicense(license)
        } catch {
            licenseState = .noLicense
            errorMessage = "Failed to load license: \(error.localizedDescription)"
        }
    }
    
    /// Save license to local storage
    private func saveLicense(_ license: License) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(license)
            UserDefaults.standard.set(data, forKey: licenseStorageKey)
        } catch {
            errorMessage = "Failed to save license: \(error.localizedDescription)"
        }
    }
    
    /// Clear the current license
    private func clearLicense() {
        currentLicense = nil
        licenseState = .noLicense
        UserDefaults.standard.removeObject(forKey: licenseStorageKey)
    }
    
    /// Validate a license
    private func validateLicense(_ license: License) {
        // Check if license is active
        if !license.isActive {
            licenseState = .invalid
            return
        }
        
        // Check for expiration
        if license.isExpired {
            licenseState = .expired
            return
        }
        
        // Check type
        if license.type == .trial {
            licenseState = .trial
            return
        }
        
        // If all checks pass
        licenseState = .valid
    }
    
    /// Fetch license for the current authenticated user
    func fetchLicenseForCurrentUser() async {
        guard let supabase = AuthService.shared.supabase,
              let currentUser = authService.currentUser else {
            await MainActor.run {
                licenseState = .noLicense
            }
            return
        }
        
        do {
            // Query licenses table for this user
            let response = try await supabase.from("licenses")
                .select()
                .eq("user_id", value: currentUser.id)
                .order("purchased_at", ascending: false)
                .limit(1)
                .execute()
            
            if let data = response.data,
               let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               !jsonArray.isEmpty {
                
                // Parse the license
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                
                if let licenseData = try? JSONSerialization.data(withJSONObject: jsonArray[0]),
                   let license = try? decoder.decode(License.self, from: licenseData) {
                    
                    await MainActor.run {
                        self.currentLicense = license
                        self.validateLicense(license)
                        self.saveLicense(license)
                    }
                    return
                }
            }
            
            // If no license found or parsing failed
            await MainActor.run {
                self.licenseState = .noLicense
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch license: \(error.localizedDescription)"
                self.licenseState = .unknown
            }
        }
    }
    
    /// Activate a license key
    func activateLicense(licenseKey: String) async {
        guard let supabase = AuthService.shared.supabase else {
            await MainActor.run {
                errorMessage = "Not connected to license server"
                licenseState = .unknown
            }
            return
        }
        
        await MainActor.run {
            isActivating = true
        }
        
        do {
            // 1. Validate the license key exists and is available
            let licenseResponse = try await supabase.from("licenses")
                .select()
                .eq("license_key", value: licenseKey)
                .single()
                .execute()
            
            guard let licenseData = licenseResponse.data,
                  let license = try? JSONDecoder().decode(License.self, from: licenseData) else {
                await MainActor.run {
                    errorMessage = "Invalid license key"
                    licenseState = .invalid
                    isActivating = false
                }
                return
            }
            
            // 2. Verify license can be activated
            if !license.canBeActivated {
                if license.isExpired {
                    await MainActor.run {
                        errorMessage = "License has expired"
                        licenseState = .expired
                        isActivating = false
                    }
                } else if !license.isActive {
                    await MainActor.run {
                        errorMessage = "License is inactive"
                        licenseState = .invalid
                        isActivating = false
                    }
                } else if license.activationsUsed >= license.maxActivations {
                    await MainActor.run {
                        errorMessage = "Maximum activations reached"
                        licenseState = .invalid
                        isActivating = false
                    }
                }
                return
            }
            
            // 3. Register the activation
            let activationData: [String: Any] = [
                "license_id": license.id,
                "machine_id": machineId,
                "activated_at": ISO8601DateFormatter().string(from: Date()),
                "is_active": true
            ]
            
            let _ = try await supabase.from("license_activations")
                .insert(values: activationData)
                .execute()
            
            // 4. Update the license activations count
            let newActivationsCount = license.activationsUsed + 1
            let updateData = ["activations_used": newActivationsCount]
            
            let _ = try await supabase.from("licenses")
                .update(values: updateData)
                .eq("id", value: license.id)
                .execute()
            
            // 5. Update local license state
            var updatedLicense = license
            updatedLicense.activationsUsed = newActivationsCount
            
            await MainActor.run {
                currentLicense = updatedLicense
                validateLicense(updatedLicense)
                saveLicense(updatedLicense)
                errorMessage = nil
                isActivating = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "License activation failed: \(error.localizedDescription)"
                licenseState = .unknown
                isActivating = false
            }
        }
    }
    
    /// Deactivate the current license on this machine
    func deactivateLicense() async {
        guard let supabase = AuthService.shared.supabase,
              let license = currentLicense else {
            await MainActor.run {
                errorMessage = "No active license to deactivate"
            }
            return
        }
        
        do {
            // Find and deactivate this machine's activation
            let _ = try await supabase.from("license_activations")
                .update(values: ["is_active": false])
                .eq("license_id", value: license.id)
                .eq("machine_id", value: machineId)
                .execute()
            
            // Clear local license
            await MainActor.run {
                clearLicense()
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "License deactivation failed: \(error.localizedDescription)"
            }
        }
    }
    
    /// Check if the app has a valid license and can be used
    var canUseApp: Bool {
        // Always allow use when:
        // 1. License is valid
        // 2. License is in trial period
        // 3. User has an active subscription
        return licenseState == .valid || 
               licenseState == .trial || 
               (authService.currentUser?.canUseApp ?? false)
    }
    
    /// Get a human-readable license status message
    var licenseStatusMessage: String {
        switch licenseState {
        case .unknown:
            return "License status unknown"
        case .valid:
            if let license = currentLicense {
                if license.type == .subscription {
                    if let timeRemaining = license.formattedTimeRemaining {
                        return "Licensed (Subscription, \(timeRemaining))"
                    }
                    return "Licensed (Subscription)"
                }
                return "Licensed (Perpetual)"
            }
            return "Licensed"
        case .expired:
            return "License expired"
        case .invalid:
            return "Invalid license"
        case .notActivated:
            return "License not activated"
        case .trial:
            if let license = currentLicense, let timeRemaining = license.formattedTimeRemaining {
                return "Trial (\(timeRemaining))"
            }
            return "Trial"
        case .noLicense:
            if let user = authService.currentUser, user.canUseApp {
                if user.accountType == .trial, let timeRemaining = user.formattedTrialTimeRemaining {
                    return "Trial (\(timeRemaining))"
                }
                return "Active via subscription"
            }
            return "No license"
        }
    }
}