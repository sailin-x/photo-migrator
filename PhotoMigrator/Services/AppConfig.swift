import Foundation

/// Service that manages application configuration and API keys
class AppConfig {
    /// Shared singleton instance
    static let shared = AppConfig()
    
    // MARK: - API Keys
    
    /// Supabase URL
    private(set) var supabaseURL: String = ""
    
    /// Supabase API Key
    private(set) var supabaseAPIKey: String = ""
    
    /// Stripe Public Key
    private(set) var stripePublicKey: String = ""
    
    // MARK: - App Information
    
    /// App version
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    /// App build number
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    /// Full app version string
    var fullVersion: String {
        return "v\(appVersion) (\(buildNumber))"
    }
    
    /// App name
    let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "PhotoMigrator"
    
    // MARK: - License Information
    
    /// Trial period in days
    let trialPeriodDays = 14
    
    /// Max activations per license
    let maxActivationsPerLicense = 2
    
    // MARK: - Initialization
    
    private init() {
        loadAPIKeys()
    }
    
    /// Load API keys from the environment or configuration file
    private func loadAPIKeys() {
        // First try to load from environment variables (useful for development)
        if let supabaseURLEnv = ProcessInfo.processInfo.environment["SUPABASE_URL"] {
            supabaseURL = supabaseURLEnv
        }
        
        if let supabaseKeyEnv = ProcessInfo.processInfo.environment["SUPABASE_API_KEY"] {
            supabaseAPIKey = supabaseKeyEnv
        }
        
        if let stripeKeyEnv = ProcessInfo.processInfo.environment["STRIPE_PUBLIC_KEY"] {
            stripePublicKey = stripeKeyEnv
        }
        
        // If environment variables aren't set, try to load from a configuration file
        if supabaseURL.isEmpty || supabaseAPIKey.isEmpty || stripePublicKey.isEmpty {
            loadFromConfigFile()
        }
    }
    
    /// Load API keys from a configuration file
    private func loadFromConfigFile() {
        // Look for a configuration file in the app's resources
        if let configURL = Bundle.main.url(forResource: "APIConfig", withExtension: "plist"),
           let configData = try? Data(contentsOf: configURL),
           let config = try? PropertyListDecoder().decode([String: String].self, from: configData) {
            
            supabaseURL = config["SUPABASE_URL"] ?? ""
            supabaseAPIKey = config["SUPABASE_API_KEY"] ?? ""
            stripePublicKey = config["STRIPE_PUBLIC_KEY"] ?? ""
        }
    }
    
    /// Set API keys programmatically (for testing or when received from external source)
    func setAPIKeys(supabaseURL: String, supabaseAPIKey: String, stripePublicKey: String) {
        self.supabaseURL = supabaseURL
        self.supabaseAPIKey = supabaseAPIKey
        self.stripePublicKey = stripePublicKey
    }
    
    /// Check if all required API keys are configured
    var areAPIKeysConfigured: Bool {
        return !supabaseURL.isEmpty && !supabaseAPIKey.isEmpty && !stripePublicKey.isEmpty
    }
}