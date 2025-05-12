import SwiftUI

struct OnboardingView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var currentPage = 0
    
    // Pages of onboarding content
    private let pages = [
        OnboardingPage(
            title: "Welcome to PhotoMigrator",
            description: "Easily migrate your photos and videos from Google Photos to Apple Photos while preserving metadata and organization.",
            image: "photo.on.rectangle.angled",
            tip: "PhotoMigrator preserves dates, locations, descriptions, and album structure."
        ),
        OnboardingPage(
            title: "Get Your Google Photos",
            description: "First, download your photos from Google Takeout. We'll help you with the process.",
            image: "arrow.down.circle",
            tip: "Tip: Choose the 'Google Photos' option only when exporting from Google Takeout to minimize download size."
        ),
        OnboardingPage(
            title: "Select and Import",
            description: "Select your Google Takeout archive and PhotoMigrator will handle the rest, preserving metadata and organization.",
            image: "square.and.arrow.down",
            tip: "Larger libraries can take longer to process. You can use batch processing for better performance."
        ),
        OnboardingPage(
            title: "Advanced Features",
            description: "PhotoMigrator offers batch processing for large libraries and detailed statistics about your migration.",
            image: "chart.bar.doc.horizontal",
            tip: "You can customize batch processing parameters in Preferences to optimize for your system."
        ),
        OnboardingPage(
            title: "Ready to Start",
            description: "You're all set! Start your migration by selecting your Google Takeout archive.",
            image: "checkmark.circle",
            tip: "Need help? Check the in-app documentation or visit photomigrator.app/support"
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicators
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                
                Spacer()
                
                // Skip button
                Button("Skip") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Navigation buttons
            HStack {
                // Back button
                Button(action: {
                    withAnimation {
                        currentPage = max(0, currentPage - 1)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundColor(currentPage > 0 ? .blue : .gray)
                }
                .disabled(currentPage == 0)
                .padding()
                
                Spacer()
                
                // Next/Finish button
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        // Last page, finish onboarding
                        presentationMode.wrappedValue.dismiss()
                        
                        // Save that we've completed onboarding
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
            }
        }
        .frame(width: 700, height: 500)
    }
}

// Structure for onboarding page data
struct OnboardingPage {
    let title: String
    let description: String
    let image: String
    let tip: String
}

// View for a single onboarding page
struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            // Icon
            Image(systemName: page.image)
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding()
            
            // Title
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Tip
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text(page.tip)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.top, 40)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}