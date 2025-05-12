import SwiftUI

struct OnboardingView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentPage = 0
    @State private var hasAcceptedTerms = false
    @State private var hasAcknowledgedPrivacyPolicy = false
    @State private var shouldShowTerms = false
    @State private var shouldShowPrivacyPolicy = false
    
    let totalPages = 4
    
    var body: some View {
        VStack {
            // Header with progress indicator
            HStack {
                Text("Welcome to PhotoMigrator")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 5) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(currentPage >= index ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding()
            
            // Content pages
            TabView(selection: $currentPage) {
                // Page 1: Welcome
                welcomeView
                    .tag(0)
                
                // Page 2: Features
                featuresView
                    .tag(1)
                
                // Page 3: Terms and Privacy
                legalView
                    .tag(2)
                
                // Page 4: Get Started
                getStartedView
                    .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentPage < totalPages - 1 {
                    Button(currentPage == 2 && (!hasAcceptedTerms || !hasAcknowledgedPrivacyPolicy) ? "Accept to Continue" : "Next") {
                        if currentPage == 2 && (!hasAcceptedTerms || !hasAcknowledgedPrivacyPolicy) {
                            // If on legal page and not accepted terms, stay on this page
                        } else {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentPage == 2 && (!hasAcceptedTerms || !hasAcknowledgedPrivacyPolicy))
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 800, height: 600)
        .sheet(isPresented: $shouldShowTerms) {
            TermsAndConditionsView(hasAcceptedTerms: $hasAcceptedTerms)
        }
        .sheet(isPresented: $shouldShowPrivacyPolicy) {
            PrivacyPolicyView(hasAcknowledgedPrivacyPolicy: $hasAcknowledgedPrivacyPolicy)
        }
    }
    
    // MARK: - Page Views
    
    private var welcomeView: some View {
        VStack(spacing: 30) {
            Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("Welcome to PhotoMigrator")
                .font(.title)
                .fontWeight(.bold)
            
            Text("The seamless way to migrate from Google Photos to Apple Photos")
                .font(.title3)
                .multilineTextAlignment(.center)
            
            Text("This application helps you move your entire photo library from Google Photos to Apple Photos, preserving all your metadata, albums, and original image quality.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var featuresView: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Key Features")
                .font(.title)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
            
            VStack(alignment: .leading, spacing: 15) {
                featureRow(icon: "rectangle.stack", title: "Google Takeout Support", description: "Import photos directly from Google Takeout archives")
                featureRow(icon: "text.badge.checkmark", title: "Metadata Preservation", description: "Keep dates, locations, descriptions and more")
                featureRow(icon: "photo.on.rectangle", title: "Live Photo Reconstruction", description: "Reconnect motion photos and live photos")
                featureRow(icon: "folder", title: "Album Organization", description: "Maintain your original album structure")
                featureRow(icon: "chart.bar", title: "Migration Statistics", description: "Get detailed reports on your migration")
                featureRow(icon: "gearshape", title: "Advanced Settings", description: "Customize the migration process to your needs")
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private var legalView: some View {
        VStack(spacing: 30) {
            Text("Terms & Privacy")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Please review and accept our Terms and Conditions and Privacy Policy to continue.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            VStack(spacing: 20) {
                VStack {
                    Button("View Terms and Conditions") {
                        shouldShowTerms = true
                    }
                    .buttonStyle(.bordered)
                    
                    HStack {
                        Image(systemName: hasAcceptedTerms ? "checkmark.square.fill" : "square")
                            .foregroundColor(hasAcceptedTerms ? .green : .gray)
                        
                        Text("I accept the Terms and Conditions")
                            .foregroundColor(hasAcceptedTerms ? .primary : .secondary)
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hasAcceptedTerms.toggle()
                    }
                }
                
                VStack {
                    Button("View Privacy Policy") {
                        shouldShowPrivacyPolicy = true
                    }
                    .buttonStyle(.bordered)
                    
                    HStack {
                        Image(systemName: hasAcknowledgedPrivacyPolicy ? "checkmark.square.fill" : "square")
                            .foregroundColor(hasAcknowledgedPrivacyPolicy ? .green : .gray)
                        
                        Text("I acknowledge the Privacy Policy")
                            .foregroundColor(hasAcknowledgedPrivacyPolicy ? .primary : .secondary)
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hasAcknowledgedPrivacyPolicy.toggle()
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .padding()
    }
    
    private var getStartedView: some View {
        VStack(spacing: 30) {
            Image(systemName: "sparkles")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text("You're All Set!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Thank you for choosing PhotoMigrator. You're now ready to start migrating your photos.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Next Steps:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 10) {
                    stepRow(number: 1, text: "Download your Google Takeout archive")
                    stepRow(number: 2, text: "Open the archive with PhotoMigrator")
                    stepRow(number: 3, text: "Review migration settings")
                    stepRow(number: 4, text: "Start the migration process")
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .padding()
    }
    
    // MARK: - Helper Views
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Text("\(number).")
                .font(.headline)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.body)
        }
    }
    
    // MARK: - Actions
    
    private func completeOnboarding() {
        // Save that user has completed onboarding
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Dismiss the onboarding view
        presentationMode.wrappedValue.dismiss()
    }
}