import SwiftUI

@main
struct PhotoMigratorApp: App {
    @ObservedObject private var licenseService = LicenseService.shared
    @ObservedObject private var authService = AuthService.shared
    
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var isShowingOnboarding = false
    @State private var isShowingLicenseActivation = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    checkFirstLaunch()
                    checkLicenseStatus()
                }
                .sheet(isPresented: $isShowingOnboarding) {
                    OnboardingView()
                }
                .sheet(isPresented: $isShowingLicenseActivation) {
                    LicenseActivationView()
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ContinueWithoutLicense"))) { _ in
                    isShowingLicenseActivation = false
                }
        }
        .commands {
            // Add menu commands
            SidebarCommands()
            
            // Custom commands
            CommandGroup(after: .appInfo) {
                Button("License Information...") {
                    isShowingLicenseActivation = true
                }
                
                if authService.authState == .authenticated {
                    Button("Sign Out") {
                        Task {
                            await authService.signOut()
                        }
                    }
                } else {
                    Button("Sign In...") {
                        // Show auth view
                        isShowingLicenseActivation = true
                    }
                }
                
                Divider()
                
                Button("View Onboarding...") {
                    isShowingOnboarding = true
                }
            }
        }
        
        // App settings
        Settings {
            PreferencesView()
        }
    }
    
    /// Check if this is the first launch and show onboarding
    private func checkFirstLaunch() {
        if !hasCompletedOnboarding {
            // First launch, show onboarding
            isShowingOnboarding = true
        }
    }
    
    /// Check license status and show activation if needed
    private func checkLicenseStatus() {
        // Check if we have a valid license or can use the app
        if !licenseService.canUseApp {
            // No valid license, show activation window
            isShowingLicenseActivation = true
        }
    }
}