import SwiftUI

struct TermsAndConditionsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var hasAcceptedTerms: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Terms and Conditions")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Last Updated: \(formattedDate)")
                            .fontWeight(.semibold)
                        
                        SectionView(title: "1. AGREEMENT TO TERMS", content: termsIntroduction)
                        SectionView(title: "2. LICENSE TO USE", content: licenseTerms)
                        SectionView(title: "3. RESTRICTIONS", content: licenseRestrictions)
                        SectionView(title: "4. USER REGISTRATION", content: userRegistration)
                        SectionView(title: "5. FEES AND PAYMENT", content: feesAndPayment)
                        SectionView(title: "6. FREE TRIAL", content: freeTrial)
                        SectionView(title: "7. REFUNDS", content: refundPolicy)
                        SectionView(title: "8. SOFTWARE UPDATES", content: softwareUpdates)
                        SectionView(title: "9. INTELLECTUAL PROPERTY RIGHTS", content: intellectualProperty)
                        SectionView(title: "10. USER CONTENT", content: userContent)
                    }
                    
                    Group {
                        SectionView(title: "11. PROHIBITED ACTIVITIES", content: prohibitedActivities)
                        SectionView(title: "12. THIRD-PARTY WEBSITES AND CONTENT", content: thirdPartyContent)
                        SectionView(title: "13. SERVICES MANAGEMENT", content: servicesManagement)
                        SectionView(title: "14. TERM AND TERMINATION", content: termAndTermination)
                        SectionView(title: "15. MODIFICATIONS AND INTERRUPTIONS", content: modificationsAndInterruptions)
                        SectionView(title: "16. GOVERNING LAW", content: governingLaw)
                        SectionView(title: "17. DISPUTE RESOLUTION", content: disputeResolution)
                        SectionView(title: "18. CORRECTIONS", content: corrections)
                        SectionView(title: "19. DISCLAIMER", content: disclaimer)
                        SectionView(title: "20. LIMITATIONS OF LIABILITY", content: limitationsOfLiability)
                    }
                    
                    Group {
                        SectionView(title: "21. INDEMNIFICATION", content: indemnification)
                        SectionView(title: "22. USER DATA", content: userData)
                        SectionView(title: "23. ELECTRONIC COMMUNICATIONS", content: electronicCommunications)
                        SectionView(title: "24. MISCELLANEOUS", content: miscellaneous)
                        SectionView(title: "25. CONTACT US", content: contactUs)
                    }
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            
            HStack {
                Button("Decline") {
                    // Keep hasAcceptedTerms as false
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Button("Accept") {
                    hasAcceptedTerms = true
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
    
    // MARK: - Terms and Conditions Content
    
    private let termsIntroduction = """
    These Terms and Conditions ("Terms") govern your use of PhotoMigrator ("the Software") operated by PhotoMigrator Inc. ("Company", "we", "us", or "our"). 
    
    Please read these Terms carefully before using the Software. By using the Software, you agree to be bound by these Terms. If you disagree with any part of the Terms, you may not use the Software.
    """
    
    private let licenseTerms = """
    Subject to your compliance with these Terms, the Company grants you a limited, non-exclusive, non-transferable, revocable license to download, install, and use the Software for your personal or internal business purposes in accordance with the license type you purchased.
    
    License Types:
    • Trial License: Allows use of the Software for evaluation purposes for a limited time period.
    • Subscription License: Allows use of the Software for the duration of your active subscription.
    • Perpetual License: Allows use of the specific version of the Software indefinitely, subject to the terms of this agreement.
    
    This license is for your use only and may be used on a limited number of devices as specified in your purchase agreement.
    """
    
    private let licenseRestrictions = """
    You agree not to, and you will not permit others to:
    • License, sell, rent, lease, assign, distribute, transmit, host, outsource, disclose or otherwise commercially exploit the Software.
    • Copy or use the Software for any purpose other than as permitted under these Terms.
    • Modify, make derivative works of, disassemble, decrypt, reverse compile, or reverse engineer any part of the Software.
    • Remove, alter, or obscure any proprietary notice (including any notice of copyright or trademark) on the Software.
    • Use the Software for any unlawful purpose, to violate any applicable local, state, national, or international law, or for any promotion of illegal activities.
    • Transfer, sublicense, or provide access to the Software to any third party.
    """
    
    private let userRegistration = """
    To use certain features of the Software, you may be required to register for an account. You agree to provide accurate, current, and complete information during the registration process and to update such information to keep it accurate, current, and complete.
    
    You are responsible for safeguarding the password and access credentials that you use to access the Software. You agree not to disclose your password or access credentials to any third party and to immediately notify the Company of any unauthorized use of your account.
    
    The Company reserves the right to disable any user account at any time if, in our opinion, you have failed to comply with any provision of these Terms.
    """
    
    private let feesAndPayment = """
    The Software is provided on a paid basis. Payment for licenses or subscriptions must be made in advance. All fees are non-refundable except as expressly set forth in these Terms.
    
    For subscription-based licenses, your subscription will automatically renew at the end of each subscription period unless you cancel your subscription before the renewal date.
    
    We reserve the right to change our prices at any time. Changes to subscription fees will take effect at the beginning of the next subscription period after notice of the changes has been provided to you.
    
    You are responsible for all taxes associated with your use of the Software (except for taxes based on the Company's income).
    """
    
    private let freeTrial = """
    The Company may, at its sole discretion, offer a limited-time free trial to new users. The free trial may have limitations on functionality or usage as determined by the Company.
    
    To use the free trial, you may be required to provide payment information. At the end of the free trial period, your account will automatically convert to a paid subscription unless you cancel before the trial period ends.
    
    The Company reserves the right to modify or terminate free trials at any time without notice.
    """
    
    private let refundPolicy = """
    We offer refunds within 30 days of purchase if the Software does not function substantially as described. Refund requests must be submitted in writing to our customer support team with a detailed explanation of the issue.
    
    Refunds are not available for:
    • Subscription fees after the first 30 days of the subscription period.
    • Issues caused by your hardware, operating system, or other third-party software.
    • Issues that arise after software modifications or customizations made by you.
    • Any situation where you have violated these Terms.
    
    The Company may request remote access to verify issues before processing refunds.
    """
    
    private let softwareUpdates = """
    The Company may from time to time in its sole discretion develop and provide Software updates, which may include upgrades, bug fixes, patches, and other error corrections, or new features. Updates may also modify or delete in their entirety certain features and functionality.
    
    You agree that the Company has no obligation to provide any Updates or to continue to provide or enable any particular features or functionality.
    
    Based on your device settings, when your device is connected to the internet, the Software may automatically check for available Updates and, if available, the Update will be downloaded and installed.
    
    Your continued use of the Software after an Update constitutes acceptance of the Update.
    """
    
    private let intellectualProperty = """
    The Software, including all content, features, and functionality, is and will remain the exclusive property of the Company and its licensors. The Software is protected by copyright, trademark, and other laws of both the United States and foreign countries.
    
    Our trademarks and trade dress may not be used in connection with any product or service without the prior written consent of the Company.
    
    You acknowledge that all intellectual property rights in the Software belong to the Company, and that you have no rights in or to the Software other than the right to use it in accordance with these Terms.
    """
    
    private let userContent = """
    The Software allows you to process photos and other content ("User Content"). You retain all rights to your User Content.
    
    By using the Software, you grant the Company a limited license to access your User Content solely for the purpose of providing and improving the Software. We will not access, view, or modify your User Content except as necessary to provide the service.
    
    You are solely responsible for your User Content. You represent and warrant that:
    • You own or have the necessary rights to your User Content.
    • Your User Content does not and will not violate the rights of any third party.
    • Your User Content is not illegal and does not violate any applicable laws.
    
    The Company has no obligation to monitor User Content but may do so in connection with providing the Software.
    """
    
    private let prohibitedActivities = """
    You agree not to engage in any of the following prohibited activities:
    • Circumventing, disabling, or otherwise interfering with security features of the Software.
    • Using the Software in a manner that could damage, disable, overburden, or impair the Software or interfere with other users' use of the Software.
    • Attempting to reverse engineer any portion of the Software.
    • Using the Software to transmit any computer viruses, worms, defects, Trojan horses, or other items of a destructive nature.
    • Using the Software in any manner that could interfere with, disrupt, negatively affect, or inhibit other users from fully enjoying the Software, or that could damage, disable, overburden, or impair the functioning of the Software.
    • Using any robot, spider, crawler, scraper, or other automated means to access the Software or to extract data.
    • Using the Software to process illegal or prohibited content.
    • Attempting to circumvent any content-filtering techniques we employ.
    • Using the Software for any revenue-generating endeavor or commercial enterprise beyond the scope of the license purchased.
    """
    
    private let thirdPartyContent = """
    The Software may display, include, or make available third-party content (including data, information, applications, and other products) or provide links to third-party websites or services.
    
    You acknowledge and agree that the Company is not responsible for third-party content, including their accuracy, completeness, timeliness, validity, legality, decency, quality, or any other aspect thereof. The Company does not assume and will not have any liability to you or any other person or entity for any third-party content.
    
    Third-party content and links thereto are provided solely as a convenience to you, and you access and use them entirely at your own risk and subject to such third parties' terms and conditions.
    """
    
    private let servicesManagement = """
    The Company reserves the right, but not the obligation, to:
    • Monitor the Software for violations of these Terms.
    • Take appropriate legal action against anyone who, in our sole discretion, violates the law or these Terms.
    • Refuse, restrict access to, or terminate providing the Software to anyone for any reason, at any time.
    • Otherwise manage the Software in a manner designed to protect our rights and property and to facilitate the proper functioning of the Software.
    
    We may, without prior notice, change the Software, stop providing the Software or features of the Software, or create usage limits for the Software.
    """
    
    private let termAndTermination = """
    These Terms shall remain in full force and effect while you use the Software.
    
    The Company may terminate or suspend your license immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach these Terms. Upon termination, your right to use the Software will immediately cease.
    
    If you wish to terminate your account, you may simply discontinue using the Software and, if applicable, cancel your subscription through your account settings or by contacting the Company directly.
    
    All provisions of the Terms which by their nature should survive termination shall survive termination, including, without limitation, ownership provisions, warranty disclaimers, indemnity, and limitations of liability.
    """
    
    private let modificationsAndInterruptions = """
    We reserve the right to change, modify, or remove the contents of the Software at any time or for any reason at our sole discretion without notice. We also reserve the right to modify or discontinue all or part of the Software without notice at any time.
    
    We will not be liable to you or any third party for any modification, suspension, or discontinuance of the Software.
    
    We cannot guarantee the Software will be available at all times. We may experience hardware, software, or other problems or need to perform maintenance related to the Software, resulting in interruptions, delays, or errors. We reserve the right to change, revise, update, suspend, discontinue, or otherwise modify the Software at any time or for any reason without notice to you.
    
    You agree that we have no liability whatsoever for any loss, damage, or inconvenience caused by your inability to access or use the Software during any downtime or discontinuance of the Software.
    
    Nothing in these Terms will be construed to obligate us to maintain and support the Software or to supply any corrections, updates, or releases in connection therewith.
    """
    
    private let governingLaw = """
    These Terms and your use of the Software are governed by and construed in accordance with the laws of the State of California applicable to agreements made and to be entirely performed within the State of California, without regard to its conflict of law principles.
    """
    
    private let disputeResolution = """
    Any legal action or proceeding arising under these Terms will be brought exclusively in the federal or state courts located in San Francisco, California, and you hereby consent to personal jurisdiction and venue in those courts.
    
    If you have any issue or dispute with the Company, you agree to first contact us and make a good faith effort to resolve the dispute before resorting to more formal means of resolution.
    
    Any cause of action or claim you may have arising out of or relating to these Terms or the Software must be commenced within one (1) year after the cause of action accrues; otherwise, such cause of action or claim is permanently barred.
    """
    
    private let corrections = """
    There may be information on the Software that contains typographical errors, inaccuracies, or omissions, including descriptions, pricing, availability, and various other information. We reserve the right to correct any errors, inaccuracies, or omissions and to change or update the information at any time, without prior notice.
    """
    
    private let disclaimer = """
    THE SOFTWARE IS PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS. YOU AGREE THAT YOUR USE OF THE SOFTWARE WILL BE AT YOUR SOLE RISK. TO THE FULLEST EXTENT PERMITTED BY LAW, WE DISCLAIM ALL WARRANTIES, EXPRESS OR IMPLIED, IN CONNECTION WITH THE SOFTWARE AND YOUR USE THEREOF, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.
    
    WE MAKE NO WARRANTIES OR REPRESENTATIONS ABOUT THE ACCURACY OR COMPLETENESS OF THE SOFTWARE'S CONTENT OR THE CONTENT OF ANY THIRD-PARTY WEBSITES LINKED TO THE SOFTWARE AND WE WILL ASSUME NO LIABILITY OR RESPONSIBILITY FOR ANY:
    • ERRORS, MISTAKES, OR INACCURACIES OF CONTENT AND MATERIALS;
    • PERSONAL INJURY OR PROPERTY DAMAGE, OF ANY NATURE WHATSOEVER, RESULTING FROM YOUR ACCESS TO AND USE OF THE SOFTWARE;
    • ANY UNAUTHORIZED ACCESS TO OR USE OF OUR SECURE SERVERS AND/OR ANY AND ALL PERSONAL INFORMATION STORED THEREIN;
    • ANY INTERRUPTION OR CESSATION OF TRANSMISSION TO OR FROM THE SOFTWARE;
    • ANY BUGS, VIRUSES, TROJAN HORSES, OR THE LIKE WHICH MAY BE TRANSMITTED TO OR THROUGH THE SOFTWARE BY ANY THIRD PARTY; AND/OR
    • ANY ERRORS OR OMISSIONS IN ANY CONTENT AND MATERIALS OR FOR ANY LOSS OR DAMAGE OF ANY KIND INCURRED AS A RESULT OF THE USE OF ANY CONTENT POSTED, TRANSMITTED, OR OTHERWISE MADE AVAILABLE VIA THE SOFTWARE.
    
    WE DO NOT WARRANT, ENDORSE, GUARANTEE, OR ASSUME RESPONSIBILITY FOR ANY PRODUCT OR SERVICE ADVERTISED OR OFFERED BY A THIRD PARTY THROUGH THE SOFTWARE OR ANY HYPERLINKED WEBSITE OR FEATURED IN ANY BANNER OR OTHER ADVERTISING, AND WE WILL NOT BE A PARTY TO OR IN ANY WAY BE RESPONSIBLE FOR MONITORING ANY TRANSACTION BETWEEN YOU AND ANY THIRD-PARTY PROVIDERS OF PRODUCTS OR SERVICES.
    """
    
    private let limitationsOfLiability = """
    IN NO EVENT WILL WE OR OUR DIRECTORS, EMPLOYEES, OR AGENTS BE LIABLE TO YOU OR ANY THIRD PARTY FOR ANY DIRECT, INDIRECT, CONSEQUENTIAL, EXEMPLARY, INCIDENTAL, SPECIAL, OR PUNITIVE DAMAGES, INCLUDING LOST PROFIT, LOST REVENUE, LOSS OF DATA, OR OTHER DAMAGES ARISING FROM YOUR USE OF THE SOFTWARE, EVEN IF WE HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
    
    NOTWITHSTANDING ANYTHING TO THE CONTRARY CONTAINED HEREIN, OUR LIABILITY TO YOU FOR ANY CAUSE WHATSOEVER AND REGARDLESS OF THE FORM OF THE ACTION, WILL AT ALL TIMES BE LIMITED TO THE AMOUNT PAID, IF ANY, BY YOU TO US DURING THE SIX (6) MONTH PERIOD PRIOR TO ANY CAUSE OF ACTION ARISING.
    
    CERTAIN STATE LAWS DO NOT ALLOW LIMITATIONS ON IMPLIED WARRANTIES OR THE EXCLUSION OR LIMITATION OF CERTAIN DAMAGES. IF THESE LAWS APPLY TO YOU, SOME OR ALL OF THE ABOVE DISCLAIMERS OR LIMITATIONS MAY NOT APPLY TO YOU, AND YOU MAY HAVE ADDITIONAL RIGHTS.
    """
    
    private let indemnification = """
    You agree to defend, indemnify, and hold us harmless, including our subsidiaries, affiliates, and all of our respective officers, agents, partners, and employees, from and against any loss, damage, liability, claim, or demand, including reasonable attorneys' fees and expenses, made by any third party due to or arising out of:
    • Your use of the Software;
    • Your breach of these Terms;
    • Any breach of your representations and warranties set forth in these Terms;
    • Your violation of the rights of a third party, including but not limited to intellectual property rights; or
    • Any overt harmful act toward any other user of the Software with whom you connected via the Software.
    
    Notwithstanding the foregoing, we reserve the right, at your expense, to assume the exclusive defense and control of any matter for which you are required to indemnify us, and you agree to cooperate, at your expense, with our defense of such claims. We will use reasonable efforts to notify you of any such claim, action, or proceeding which is subject to this indemnification upon becoming aware of it.
    """
    
    private let userData = """
    We care about data privacy and security. By using the Software, you agree to our Privacy Policy, which is incorporated into these Terms. Please review our Privacy Policy, which also governs your use of the Software, to understand our practices.
    
    The Company collects certain Personal Information through the Software. This data is used, maintained, and disclosed according to our Privacy Policy.
    """
    
    private let electronicCommunications = """
    By using the Software, you consent to receiving electronic communications from us. These communications may include notices about your account and information concerning or related to the Software.
    
    You agree that any notices, agreements, disclosures, or other communications that we send to you electronically will satisfy any legal communication requirements, including that such communications be in writing.
    """
    
    private let miscellaneous = """
    These Terms and any policies or operating rules posted by us constitute the entire agreement and understanding between you and us. Our failure to exercise or enforce any right or provision of these Terms shall not operate as a waiver of such right or provision.
    
    These Terms operate to the fullest extent permissible by law. We may assign any or all of our rights and obligations to others at any time. We shall not be responsible or liable for any loss, damage, delay, or failure to act caused by any cause beyond our reasonable control.
    
    If any provision or part of a provision of these Terms is determined to be unlawful, void, or unenforceable, that provision or part of the provision is deemed severable from these Terms and does not affect the validity and enforceability of any remaining provisions.
    
    There is no joint venture, partnership, employment or agency relationship created between you and us as a result of these Terms or use of the Software. You agree that these Terms will not be construed against us by virtue of having drafted them.
    """
    
    private let contactUs = """
    For any questions about these Terms or the Software, please contact us at:
    
    PhotoMigrator Inc.
    1234 Innovation Way
    San Francisco, CA 94107
    support@photomigrator.com
    1-800-PHOTO-MIG
    """
}

struct SectionView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(content)
                .font(.body)
                .lineSpacing(5)
        }
        .padding(.bottom, 16)
    }
}