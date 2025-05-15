import Foundation
import Combine

enum AuthState: Equatable {
    case initializing
    case authenticated
    case unauthenticated
    case error(Error)
    
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.initializing, .initializing):
            return true
        case (.authenticated, .authenticated):
            return true
        case (.unauthenticated, .unauthenticated):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

enum AuthError: Error {
    case invalidCredentials
    case emailAlreadyInUse
    case networkError
    case serverError
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password."
        case .emailAlreadyInUse:
            return "This email is already in use. Please try signing in instead."
        case .networkError:
            return "Network error. Please check your internet connection and try again."
        case .serverError:
            return "Server error. Please try again later."
        case .unknown:
            return "An unknown error occurred. Please try again."
        }
    }
}

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var authState: AuthState = .initializing
    @Published var currentUser: User?
    
    private let supabaseURL = "https://yourproject.supabase.co"
    private let supabaseKey = "your-supabase-key"
    
    private init() {
        // Check for existing session on init
        checkExistingSession()
    }
    
    private func checkExistingSession() {
        // In a real implementation, this would check for a stored token
        // and validate it with Supabase
        
        let hasStoredToken = UserDefaults.standard.string(forKey: "authToken") != nil
        
        if hasStoredToken {
            // Simulate token validation - in a real app, this would be a
            // network request to validate the token with Supabase
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.authState = .authenticated
                self.currentUser = User(id: "user123", email: "user@example.com")
            }
        } else {
            authState = .unauthenticated
        }
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) async throws {
        // Simulate network request to Supabase for authentication
        // In a real implementation, this would make an API call
        
        // Simulate delay for network request
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Placeholder logic - in a real app we would validate against Supabase
        if email.contains("@") && password.count >= 6 {
            let token = UUID().uuidString
            UserDefaults.standard.set(token, forKey: "authToken")
            
            // Create user object
            let user = User(id: "user123", email: email)
            
            // Update UI on main thread
            await MainActor.run {
                self.currentUser = user
                self.authState = .authenticated
            }
        } else {
            throw AuthError.invalidCredentials
        }
    }
    
    func createAccount(email: String, password: String) async throws {
        // Simulate network request to Supabase for account creation
        // In a real implementation, this would make an API call
        
        // Simulate delay for network request
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Placeholder logic - in a real app we would create an account in Supabase
        if email.contains("@") && password.count >= 6 {
            // In a real implementation, we'd check if email exists
            // For demo purposes, just simulate success
            
            // Update UI on main thread
            await MainActor.run {
                self.authState = .unauthenticated
            }
        } else {
            if !email.contains("@") {
                throw AuthError.invalidCredentials
            } else {
                throw AuthError.unknown
            }
        }
    }
    
    func signOut() async {
        // Simulate network request to sign out
        // In a real implementation, this would make an API call to invalidate the token
        
        // Clear stored token
        UserDefaults.standard.removeObject(forKey: "authToken")
        
        // Update state
        await MainActor.run {
            self.currentUser = nil
            self.authState = .unauthenticated
        }
    }
    
    func resetPassword(email: String) async throws {
        // Simulate network request to Supabase for password reset
        // In a real implementation, this would make an API call
        
        // Simulate delay for network request
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Placeholder logic - in a real app we would trigger a password reset email via Supabase
        if email.contains("@") {
            // Success - no return value needed
        } else {
            throw AuthError.invalidCredentials
        }
    }
}

// User model
struct User: Codable, Identifiable {
    let id: String
    let email: String
    var firstName: String?
    var lastName: String?
    var profileImageURL: URL?
    
    var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        
        if first.isEmpty && last.isEmpty {
            return "User"
        } else if first.isEmpty {
            return last
        } else if last.isEmpty {
            return first
        } else {
            return "\(first) \(last)"
        }
    }
}