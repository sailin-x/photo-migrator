import SwiftUI

struct LicenseActivationView: View {
    @ObservedObject private var licenseService = LicenseService.shared
    @ObservedObject private var authService = AuthService.shared
    
    @State private var licenseKey = ""
    @State private var isShowingLogin = false
    
    var body: some View {
        VStack(spacing: 25) {
            // App logo and title
            VStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("PhotoMigrator")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version \(AppConfig.shared.appVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 30)
            
            // Current license status
            VStack(alignment: .center, spacing: 10) {
                Text("License Status")
                    .font(.headline)
                
                Text(licenseService.licenseStatusMessage)
                    .foregroundColor(getLicenseStatusColor())
                    .fontWeight(.medium)
                
                if let license = licenseService.currentLicense, 
                   licenseService.licenseState == .valid || licenseService.licenseState == .trial {
                    VStack {
                        if license.type == .subscription,
                           let timeRemaining = license.formattedTimeRemaining {
                            Text("Time remaining: \(timeRemaining)")
                                .font(.caption)
                        }
                        
                        if license.activationsUsed > 0 {
                            Text("Activations: \(license.activationsUsed)/\(license.maxActivations)")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
                }
                
                // User information if signed in
                if let user = authService.currentUser {
                    VStack(spacing: 5) {
                        Text("Signed in as \(user.email)")
                            .font(.caption)
                        
                        if user.accountType == .trial, 
                           let trialRemaining = user.formattedTrialTimeRemaining {
                            Text("Trial ends in \(trialRemaining)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.top, 5)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // License activation section
            VStack(spacing: 15) {
                Text("Activate License")
                    .font(.headline)
                
                TextField("Enter License Key", text: $licenseKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .frame(maxWidth: 400)
                
                Button(action: {
                    Task {
                        await licenseService.activateLicense(licenseKey: licenseKey)
                    }
                }) {
                    if licenseService.isActivating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.horizontal, 10)
                    } else {
                        Text("Activate")
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(licenseKey.count < 5 || licenseService.isActivating)
                
                if let errorMessage = licenseService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Authentication options
            VStack(spacing: 15) {
                if authService.authState == .unauthenticated {
                    Button("Sign In or Register") {
                        isShowingLogin = true
                    }
                    .buttonStyle(.borderless)
                } else if authService.authState == .authenticated {
                    Button("Sign Out") {
                        Task {
                            await authService.signOut()
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }
                
                HStack(spacing: 20) {
                    Button("Purchase License") {
                        // Open the purchase website
                        if let url = URL(string: "https://photomigrator.app/purchase") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderless)
                    
                    Button("Continue in Trial Mode") {
                        // Close this view and continue in trial mode
                        NotificationCenter.default.post(name: Notification.Name("ContinueWithoutLicense"), object: nil)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            Text("© \(Calendar.current.component(.year, from: Date())) PhotoMigrator. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 500, height: 600)
        .sheet(isPresented: $isShowingLogin) {
            AuthenticationView()
        }
    }
    
    // Get color based on license status
    private func getLicenseStatusColor() -> Color {
        switch licenseService.licenseState {
        case .valid:
            return .green
        case .trial:
            return .orange
        case .expired:
            return .red
        case .invalid:
            return .red
        case .noLicense:
            if let user = authService.currentUser, user.canUseApp {
                return .orange // Trial through account
            }
            return .red
        case .notActivated, .unknown:
            return .secondary
        }
    }
}

struct LicenseActivationView_Previews: PreviewProvider {
    static var previews: some View {
        LicenseActivationView()
    }
}