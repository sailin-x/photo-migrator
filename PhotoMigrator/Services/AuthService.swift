import Foundation
import Combine
import Supabase

/// Service for handling authentication with Supabase
class AuthService: ObservableObject {
    /// Shared singleton instance
    static let shared = AuthService()
    
    /// Supabase client
    private var supabase: SupabaseClient?
    
    /// Current authenticated user
    @Published var currentUser: User?
    
    /// Authentication state
    @Published var authState: AuthState = .unknown
    
    /// Current error message, if any
    @Published var errorMessage: String?
    
    /// Subscriptions for Combine
    private var cancellables = Set<AnyCancellable>()
    
    /// Authentication states
    enum AuthState {
        case unknown
        case authenticated
        case unauthenticated
        case verifying
        case registering
        case loggingIn
    }
    
    /// Private initializer for singleton
    private init() {
        initializeSupabase()
    }
    
    /// Initialize the Supabase client
    private func initializeSupabase() {
        let config = AppConfig.shared
        
        guard !config.supabaseURL.isEmpty,
              !config.supabaseAPIKey.isEmpty else {
            // No API keys configured yet
            authState = .unauthenticated
            return
        }
        
        supabase = SupabaseClient(
            supabaseURL: URL(string: config.supabaseURL)!,
            supabaseKey: config.supabaseAPIKey
        )
        
        // Check if user is already authenticated
        Task {
            await checkAuthentication()
        }
    }
    
    /// Check if user is already authenticated
    func checkAuthentication() async {
        guard let supabase = supabase else {
            await MainActor.run {
                authState = .unauthenticated
            }
            return
        }
        
        do {
            let session = try await supabase.auth.session
            
            // If we have a session, fetch user details
            if session != nil {
                await fetchUserDetails()
            } else {
                await MainActor.run {
                    authState = .unauthenticated
                }
            }
        } catch {
            await MainActor.run {
                authState = .unauthenticated
                errorMessage = "Failed to check authentication status: \(error.localizedDescription)"
            }
        }
    }
    
    /// Fetch user details from Supabase
    func fetchUserDetails() async {
        guard let supabase = supabase,
              let authUser = try? await supabase.auth.user() else {
            await MainActor.run {
                authState = .unauthenticated
            }
            return
        }
        
        do {
            // Fetch user data from profiles table
            let response = try await supabase.from("profiles")
                .select()
                .eq("id", value: authUser.id)
                .single()
                .execute()
            
            // Parse user data
            if let data = response.data {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                
                let user = try decoder.decode(User.self, from: data)
                
                await MainActor.run {
                    self.currentUser = user
                    self.authState = .authenticated
                    self.errorMessage = nil
                }
            } else {
                await MainActor.run {
                    self.authState = .unauthenticated
                    self.errorMessage = "User profile not found"
                }
            }
        } catch {
            await MainActor.run {
                self.authState = .unauthenticated
                self.errorMessage = "Failed to fetch user details: \(error.localizedDescription)"
            }
        }
    }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async {
        guard let supabase = supabase else {
            await MainActor.run {
                authState = .unauthenticated
                errorMessage = "Supabase client not initialized"
            }
            return
        }
        
        await MainActor.run {
            authState = .loggingIn
        }
        
        do {
            let response = try await supabase.auth.signIn(email: email, password: password)
            
            if response.user != nil {
                await fetchUserDetails()
            } else {
                await MainActor.run {
                    authState = .unauthenticated
                    errorMessage = "Sign in failed"
                }
            }
        } catch {
            await MainActor.run {
                authState = .unauthenticated
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
        }
    }
    
    /// Sign up with email and password
    func signUp(email: String, password: String, name: String) async {
        guard let supabase = supabase else {
            await MainActor.run {
                authState = .unauthenticated
                errorMessage = "Supabase client not initialized"
            }
            return
        }
        
        await MainActor.run {
            authState = .registering
        }
        
        do {
            // Sign up with Supabase Auth
            let response = try await supabase.auth.signUp(email: email, password: password)
            
            if let user = response.user {
                // Create initial user profile
                let profileData: [String: Any] = [
                    "id": user.id,
                    "email": email,
                    "name": name,
                    "created_at": ISO8601DateFormatter().string(from: Date()),
                    "is_email_verified": false,
                    "subscription_status": "none",
                    "account_type": "trial",
                    "trial_ends_at": ISO8601DateFormatter().string(from: Date().addingTimeInterval(TimeInterval(AppConfig.shared.trialPeriodDays * 24 * 60 * 60)))
                ]
                
                // Insert new profile
                let _ = try? await supabase.from("profiles")
                    .insert(values: profileData)
                    .execute()
                
                await MainActor.run {
                    authState = .verifying
                    errorMessage = nil
                }
            } else {
                await MainActor.run {
                    authState = .unauthenticated
                    errorMessage = "Sign up failed"
                }
            }
        } catch {
            await MainActor.run {
                authState = .unauthenticated
                errorMessage = "Sign up failed: \(error.localizedDescription)"
            }
        }
    }
    
    /// Sign out the current user
    func signOut() async {
        guard let supabase = supabase else {
            await MainActor.run {
                authState = .unauthenticated
            }
            return
        }
        
        do {
            try await supabase.auth.signOut()
            
            await MainActor.run {
                currentUser = nil
                authState = .unauthenticated
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Sign out failed: \(error.localizedDescription)"
            }
        }
    }
    
    /// Reset password for a user
    func resetPassword(email: String) async {
        guard let supabase = supabase else {
            await MainActor.run {
                errorMessage = "Supabase client not initialized"
            }
            return
        }
        
        do {
            try await supabase.auth.resetPasswordForEmail(email)
            
            await MainActor.run {
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Password reset failed: \(error.localizedDescription)"
            }
        }
    }
    
    /// Update user profile information
    func updateUserProfile(name: String) async {
        guard let supabase = supabase,
              let currentUser = currentUser else {
            await MainActor.run {
                errorMessage = "Not authenticated"
            }
            return
        }
        
        do {
            let updateData = ["name": name]
            
            let _ = try await supabase.from("profiles")
                .update(values: updateData)
                .eq("id", value: currentUser.id)
                .execute()
            
            // Update the local user object
            await MainActor.run {
                var updatedUser = currentUser
                updatedUser.name = name
                self.currentUser = updatedUser
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update profile: \(error.localizedDescription)"
            }
        }
    }
}