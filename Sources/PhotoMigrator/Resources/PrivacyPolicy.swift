import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var hasAcknowledgedPrivacyPolicy: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Privacy Policy")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Last Updated: \(formattedDate)")
                        .fontWeight(.semibold)
                    
                    SectionView(title: "INTRODUCTION", content: introductionText)
                    SectionView(title: "INFORMATION WE COLLECT", content: informationCollectedText)
                    SectionView(title: "HOW WE USE YOUR INFORMATION", content: informationUseText)
                    SectionView(title: "DISCLOSURE OF YOUR INFORMATION", content: informationDisclosureText)
                    SectionView(title: "THIRD-PARTY SERVICES", content: thirdPartyServicesText)
                    SectionView(title: "DATA RETENTION", content: dataRetentionText)
                    SectionView(title: "DATA SECURITY", content: dataSecurityText)
                    SectionView(title: "YOUR PRIVACY RIGHTS", content: privacyRightsText)
                    SectionView(title: "CHILDREN'S PRIVACY", content: childrensPrivacyText)
                    SectionView(title: "CHANGES TO THIS PRIVACY POLICY", content: policyChangesText)
                    SectionView(title: "CONTACT US", content: contactUsText)
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            
            HStack {
                Button("Back") {
                    presentationMode.wrappedValue.dismiss()
                }
                
                Spacer()
                
                Button("I Acknowledge") {
                    hasAcknowledgedPrivacyPolicy = true
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 800, height: 600)
    }
    
    private var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        return dateFormatter.string(from: Date())
    }
    
    // MARK: - Privacy Policy Content
    
    private let introductionText = """
    PhotoMigrator Inc. ("Company", "we", "us", or "our") respects your privacy and is committed to protecting your personal data. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our PhotoMigrator software application ("Software").
    
    Please read this Privacy Policy carefully. By using the Software, you consent to the practices described in this policy. If you do not agree with the terms of this Privacy Policy, please do not access or use the Software.
    
    This Privacy Policy applies to information we collect when you use our Software, including any desktop applications, related websites, and other products and services that reference this Privacy Policy.
    """
    
    private let informationCollectedText = """
    We may collect several types of information from and about users of our Software, including:
    
    1. Personal Information:
       • Account information: When you register for an account, we collect your email address, name, and account credentials.
       • License information: When you purchase or activate a license, we collect information necessary to verify your license, including machine identifiers tied to your activation.
       • Payment information: When you make a purchase, payment information is processed by our third-party payment processor. We do not directly collect or store your payment card details.
    
    2. Non-Personal Information:
       • Usage data: We collect information about how you use the Software, including features used, processing statistics, and performance metrics.
       • Device information: We collect information about your computer hardware and software, including your operating system version, device identifiers, and system specifications.
    
    3. Photo Metadata:
       • The Software processes photo metadata from your Google Takeout archives, such as timestamps, location data, and descriptions. This information is processed locally on your device during the migration process.
       • We do not collect, transmit, or store the actual photos or videos you process with our Software, nor do we collect the metadata from these photos or videos.
    
    4. Automatically Collected Information:
       • Diagnostic data: With your permission, we may collect diagnostic data when the Software encounters errors or crashes to help us improve the Software.
       • Analytics data: We collect anonymized usage statistics to help us improve the Software and user experience.
    """
    
    private let informationUseText = """
    We use the information we collect about you for various purposes, including to:
    
    • Provide, maintain, and improve our Software and services
    • Process and fulfill your license purchases and activations
    • Manage your account and provide customer support
    • Send you technical notices, updates, security alerts, and administrative messages
    • Respond to your comments, questions, and requests
    • Monitor and analyze usage trends and preferences to improve the Software and user experience
    • Detect, investigate, and prevent fraudulent transactions and other illegal activities
    • Protect the rights, property, and safety of our users and others
    • Comply with legal obligations
    • Verify compliance with our license agreements
    
    We will never use your photos, videos, or their metadata for any purpose other than processing your migration request on your local device. This data stays on your computer and is not transmitted to our servers.
    """
    
    private let informationDisclosureText = """
    We may disclose aggregated, anonymized information about our users without restriction. However, we do not share, sell, rent, or trade your personal information with third parties for their commercial purposes.
    
    We may disclose your personal information in the following circumstances:
    
    • To our subsidiaries and affiliates
    • To contractors, service providers, and other third parties we use to support our business
    • To a buyer or other successor in the event of a merger, divestiture, restructuring, reorganization, dissolution, or other sale or transfer of some or all of the Company's assets
    • To comply with any court order, law, or legal process, including to respond to any government or regulatory request
    • To enforce our Terms and Conditions and other agreements
    • To protect the rights, property, or safety of the Company, our customers, or others
    
    We may also disclose your personal information with your consent or at your direction.
    """
    
    private let thirdPartyServicesText = """
    Our Software uses the following third-party services:
    
    • Supabase: For user authentication and license management
    • Stripe: For payment processing (when purchasing through our website)
    
    These third-party services have their own privacy policies addressing how they use your information. We encourage you to read their privacy policies.
    
    We do not control and are not responsible for the privacy practices of these third parties. This Privacy Policy applies only to information collected by us.
    """
    
    private let dataRetentionText = """
    We retain your personal information for as long as necessary to fulfill the purposes for which we collected it, including for the purposes of satisfying any legal, accounting, or reporting requirements.
    
    Account information is retained as long as your account is active. If you close your account, we will delete or anonymize your account information, except for information that we need to retain for legal purposes or legitimate business interests.
    
    License information, including machine identifiers, is retained for the duration of your license validity to ensure proper license enforcement.
    
    Diagnostic and analytics data is typically retained for no more than 24 months.
    
    Photos, videos, and their metadata are never stored by us and remain exclusively on your local device.
    """
    
    private let dataSecurityText = """
    We have implemented appropriate technical and organizational measures to protect the security of your personal information. However, please be aware that no method of transmission over the internet or method of electronic storage is 100% secure.
    
    Our security measures include:
    
    • Encryption of sensitive data in transit and at rest
    • Secure authentication mechanisms
    • Regular security assessments
    • Access controls and authorization protocols
    • Regular monitoring for potential vulnerabilities
    
    While we strive to use commercially acceptable means to protect your personal information, we cannot guarantee its absolute security. It is your responsibility to maintain the security of your account credentials.
    """
    
    private let privacyRightsText = """
    Depending on your location, you may have certain rights regarding your personal information, including:
    
    • Access: You may request access to your personal information.
    • Correction: You may request that we correct inaccurate or incomplete information.
    • Deletion: You may request that we delete your personal information in certain circumstances.
    • Restriction: You may request that we restrict the processing of your information in certain circumstances.
    • Data Portability: You may request a copy of the information you provided to us in a structured, commonly used, and machine-readable format.
    • Objection: You may object to our processing of your personal information in certain circumstances.
    
    If you wish to exercise any of these rights, please contact us using the information provided in the "Contact Us" section.
    
    For residents of California, the California Consumer Privacy Act (CCPA) may provide you with additional rights regarding your personal information. To learn more about your California privacy rights, visit our CCPA privacy notice.
    
    For residents of the European Economic Area (EEA), we process your personal data in accordance with the General Data Protection Regulation (GDPR).
    """
    
    private let childrensPrivacyText = """
    Our Software is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and you believe your child has provided us with personal information, please contact us.
    
    If we discover that a child under 13 has provided us with personal information, we will promptly delete such information from our servers.
    """
    
    private let policyChangesText = """
    We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last Updated" date at the top.
    
    For significant changes, we will provide additional notice, such as an in-app notification or an email notification if we have your email address.
    
    Your continued use of the Software after we post changes to the Privacy Policy means you accept and agree to the changes. We encourage you to periodically review this Privacy Policy for the latest information on our privacy practices.
    """
    
    private let contactUsText = """
    If you have any questions, concerns, or requests regarding this Privacy Policy or our privacy practices, please contact us at:
    
    PhotoMigrator Inc.
    1234 Innovation Way
    San Francisco, CA 94107
    
    Email: privacy@photomigrator.com
    Phone: 1-800-PHOTO-MIG
    
    We will respond to your request within a reasonable timeframe.
    """
}