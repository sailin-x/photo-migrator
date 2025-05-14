import SwiftUI

struct LicenseActivationView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var licenseService = LicenseService.shared
    @ObservedObject private var authService = AuthService.shared
    
    @State private var activationKey = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isCreatingAccount = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isActivating = false
    @State private var showSuccess = false
    
    private var isSignedIn: Bool {
        authService.authState == .authenticated
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text(isCreatingAccount ? "Create Account" : (isSignedIn ? "License Activation" : "Sign In"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom)
            
            if showSuccess {
                successView
            } else if isCreatingAccount {
                createAccountView
            } else if isSignedIn {
                licenseActivationView
            } else {
                signInView
            }
            
            Spacer()
            
            // Footer
            VStack {
                if showError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                if !isSignedIn && !isCreatingAccount {
                    Button("Continue Without License") {
                        NotificationCenter.default.post(name: Notification.Name("ContinueWithoutLicense"), object: nil)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.secondary)
                    .padding(.top)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 550)
    }
    
    // MARK: - Subviews
    
    private var signInView: some View {
        VStack(spacing: 20) {
            Text("Sign in to your PhotoMigrator account to activate your license or manage your subscription.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Group {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.password)
            }
            .padding(.vertical, 5)
            
            Button("Sign In") {
                signIn()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
            
            Divider().padding(.vertical)
            
            Text("Don't have an account?")
                .foregroundColor(.secondary)
            
            Button("Create Account") {
                isCreatingAccount = true
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var createAccountView: some View {
        VStack(spacing: 20) {
            Text("Create a PhotoMigrator account to manage your licenses and subscriptions.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Group {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.newPassword)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.newPassword)
            }
            .padding(.vertical, 5)
            
            Button("Create Account") {
                createAccount()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
            .disabled(email.isEmpty || password.isEmpty || password != confirmPassword)
            
            Divider().padding(.vertical)
            
            Text("Already have an account?")
                .foregroundColor(.secondary)
            
            Button("Sign In") {
                isCreatingAccount = false
                email = ""
                password = ""
                confirmPassword = ""
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var licenseActivationView: some View {
        VStack(spacing: 20) {
            if licenseService.hasValidLicense {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.green)
                    
                    Text("License Active")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("You have an active \(licenseService.licenseType) license.")
                        .multilineTextAlignment(.center)
                    
                    if licenseService.licenseType == "subscription" || licenseService.licenseType == "trial" {
                        Text("Expires: \(licenseService.expirationDateString)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Button("Manage Subscription") {
                    // Open subscription management
                }
                .buttonStyle(.bordered)
                .padding(.top)
                
                Divider().padding(.vertical)
                
                Text("Want to activate on another device?")
                    .foregroundColor(.secondary)
                
                Text("Remaining activations: \(licenseService.remainingActivations)")
                    .foregroundColor(.blue)
                
            } else {
                Text("Enter your license key to activate PhotoMigrator.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                TextField("License Key", text: $activationKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .padding(.vertical)
                
                Button(isActivating ? "Activating..." : "Activate License") {
                    activateLicense()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isActivating || activationKey.isEmpty)
                
                Divider().padding(.vertical)
                
                VStack(spacing: 10) {
                    Text("Don't have a license yet?")
                        .foregroundColor(.secondary)
                    
                    Button("Purchase License") {
                        // Open purchase URL
                        if let url = URL(string: "https://www.photomigrator.com/purchase") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Start Free Trial") {
                        startTrial()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    private var successView: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.green)
            
            Text("License Activated!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Thank you for activating PhotoMigrator. You now have full access to all features.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Continue") {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func signIn() {
        if email.isEmpty || password.isEmpty {
            showError = true
            errorMessage = "Please enter both email and password."
            return
        }
        
        showError = false
        Task {
            do {
                try await authService.signIn(email: email, password: password)
                // Refresh license status
                await licenseService.refreshLicenseStatus()
            } catch {
                showError = true
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func createAccount() {
        if email.isEmpty || password.isEmpty {
            showError = true
            errorMessage = "Please enter both email and password."
            return
        }
        
        if password != confirmPassword {
            showError = true
            errorMessage = "Passwords do not match."
            return
        }
        
        showError = false
        Task {
            do {
                try await authService.createAccount(email: email, password: password)
                isCreatingAccount = false
                // Automatically sign in
                try await authService.signIn(email: email, password: password)
            } catch {
                showError = true
                errorMessage = "Account creation failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func activateLicense() {
        isActivating = true
        showError = false
        
        Task {
            do {
                try await licenseService.activateLicense(licenseKey: activationKey)
                isActivating = false
                showSuccess = true
            } catch {
                isActivating = false
                showError = true
                errorMessage = "License activation failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func startTrial() {
        showError = false
        
        Task {
            do {
                try await licenseService.startTrial()
                showSuccess = true
            } catch {
                showError = true
                errorMessage = "Could not start trial: \(error.localizedDescription)"
            }
        }
    }
}

// Preview
#if DEBUG
struct LicenseActivationView_Previews: PreviewProvider {
    static var previews: some View {
        LicenseActivationView()
    }
}
#endif