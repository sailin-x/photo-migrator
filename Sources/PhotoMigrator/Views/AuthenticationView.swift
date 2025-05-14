import SwiftUI

struct AuthenticationView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var authService = AuthService.shared
    
    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isResetPassword = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text(isRegistering ? "Create Account" : (isResetPassword ? "Reset Password" : "Sign In"))
                .font(.title2)
                .fontWeight(.bold)
            
            if isResetPassword {
                // Reset password form
                VStack(spacing: 15) {
                    Text("Enter your email address and we'll send you instructions to reset your password.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 10)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.horizontal)
                    
                    Button("Send Reset Link") {
                        Task {
                            await authService.resetPassword(email: email)
                            // Show a success message
                            password = ""
                            isResetPassword = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || !isValidEmail(email))
                }
            } else if isRegistering {
                // Registration form
                VStack(spacing: 15) {
                    TextField("Full Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.horizontal)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button("Create Account") {
                        Task {
                            if isValidRegistration() {
                                await authService.signUp(email: email, password: password, name: name)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidRegistration() || authService.authState == .registering)
                    
                    if authService.authState == .verifying {
                        Text("Registration successful! Please check your email to verify your account.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.green)
                            .padding()
                    }
                }
            } else {
                // Login form
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.horizontal)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button("Sign In") {
                        Task {
                            await authService.signIn(email: email, password: password)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty || authService.authState == .loggingIn)
                    
                    Button("Forgot Password?") {
                        isResetPassword = true
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
            
            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            }
            
            // Toggle between login and registration
            HStack {
                if !isResetPassword {
                    Button(isRegistering ? "Already have an account? Sign In" : "Need an account? Register") {
                        isRegistering.toggle()
                        // Clear fields
                        password = ""
                        confirmPassword = ""
                        authService.errorMessage = nil
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                } else {
                    Button("Back to Sign In") {
                        isResetPassword = false
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
            .padding(.top, 10)
            
            Spacer()
            
            // Cancel button
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 400, height: 500)
        .onChange(of: authService.authState) { newState in
            // Close sheet if authenticated
            if newState == .authenticated {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    // Validation functions
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func isValidRegistration() -> Bool {
        return !name.isEmpty &&
               isValidEmail(email) &&
               password.count >= 8 &&
               password == confirmPassword
    }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
    }
}