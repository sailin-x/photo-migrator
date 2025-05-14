import XCTest
@testable import PhotoMigrator

final class UserTests: XCTestCase {
    
    // Helper function to create a sample user
    func createSampleUser(subscriptionStatus: User.SubscriptionStatus = .active,
                         accountType: User.AccountType = .premium,
                         trialEndsAt: Date? = nil,
                         isEmailVerified: Bool = true) -> User {
        return User(
            id: "user-123",
            email: "test@example.com",
            name: "Test User",
            createdAt: Date(),
            lastLoginAt: Date(),
            isEmailVerified: isEmailVerified,
            subscriptionStatus: subscriptionStatus,
            accountType: accountType,
            trialEndsAt: trialEndsAt
        )
    }
    
    func testUserInitialization() {
        // Create a sample user
        let user = createSampleUser()
        
        // Verify properties
        XCTAssertEqual(user.id, "user-123")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.name, "Test User")
        XCTAssertTrue(user.isEmailVerified)
        XCTAssertEqual(user.subscriptionStatus, .active)
        XCTAssertEqual(user.accountType, .premium)
        XCTAssertNil(user.trialEndsAt)
    }
    
    func testActiveSubscription() {
        // Test active premium subscription
        let activeUser = createSampleUser(subscriptionStatus: .active)
        XCTAssertTrue(activeUser.hasActiveSubscription)
        XCTAssertTrue(activeUser.canUseApp)
        
        // Test trialing subscription (not expired)
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let trialingUser = createSampleUser(subscriptionStatus: .trialing, trialEndsAt: futureDate)
        XCTAssertTrue(trialingUser.hasActiveSubscription)
        XCTAssertTrue(trialingUser.canUseApp)
        
        // Test trialing subscription (expired)
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let expiredTrialUser = createSampleUser(subscriptionStatus: .trialing, trialEndsAt: pastDate)
        XCTAssertFalse(expiredTrialUser.hasActiveSubscription)
        
        // Test canceled subscription
        let canceledUser = createSampleUser(subscriptionStatus: .canceled)
        XCTAssertFalse(canceledUser.hasActiveSubscription)
        
        // Test expired subscription
        let expiredUser = createSampleUser(subscriptionStatus: .expired)
        XCTAssertFalse(expiredUser.hasActiveSubscription)
    }
    
    func testCanUseApp() {
        // Test free account (can use app even without active subscription)
        let freeUser = createSampleUser(subscriptionStatus: .none, accountType: .free)
        XCTAssertFalse(freeUser.hasActiveSubscription)
        XCTAssertTrue(freeUser.canUseApp)
        
        // Test basic account with expired subscription (cannot use app)
        let expiredBasicUser = createSampleUser(subscriptionStatus: .expired, accountType: .basic)
        XCTAssertFalse(expiredBasicUser.hasActiveSubscription)
        XCTAssertFalse(expiredBasicUser.canUseApp)
        
        // Test premium account with past_due subscription (cannot use app)
        let pastDueUser = createSampleUser(subscriptionStatus: .pastDue, accountType: .premium)
        XCTAssertFalse(pastDueUser.hasActiveSubscription)
        XCTAssertFalse(pastDueUser.canUseApp)
    }
    
    func testTrialTimeRemaining() {
        // Test user with future trial end date
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let trialUser = createSampleUser(subscriptionStatus: .trialing, accountType: .trial, trialEndsAt: futureDate)
        
        // Verify trial time is positive and formatted correctly
        XCTAssertGreaterThan(trialUser.trialTimeRemaining ?? 0, 0)
        XCTAssertNotNil(trialUser.formattedTrialTimeRemaining)
        XCTAssertTrue(trialUser.formattedTrialTimeRemaining?.contains("day") ?? false)
        
        // Test user with expired trial
        let pastDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let expiredTrialUser = createSampleUser(subscriptionStatus: .trialing, accountType: .trial, trialEndsAt: pastDate)
        
        // Verify trial time is negative and not formatted
        XCTAssertLessThan(expiredTrialUser.trialTimeRemaining ?? 0, 0)
        XCTAssertNil(expiredTrialUser.formattedTrialTimeRemaining)
        
        // Test user with no trial end date
        let noTrialUser = createSampleUser(trialEndsAt: nil)
        XCTAssertNil(noTrialUser.trialTimeRemaining)
        XCTAssertNil(noTrialUser.formattedTrialTimeRemaining)
    }
    
    func testTrialTimeRemainingFormat() {
        // Test trial with days remaining
        let daysDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let daysUser = createSampleUser(trialEndsAt: daysDate)
        XCTAssertTrue(daysUser.formattedTrialTimeRemaining?.contains("day") ?? false)
        
        // Test trial with hours remaining
        let hoursDate = Calendar.current.date(byAdding: .hour, value: 12, to: Date())!
        let hoursUser = createSampleUser(trialEndsAt: hoursDate)
        XCTAssertTrue(hoursUser.formattedTrialTimeRemaining?.contains("hour") ?? false)
        
        // Test trial with minutes remaining
        let minutesDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let minutesUser = createSampleUser(trialEndsAt: minutesDate)
        XCTAssertTrue(minutesUser.formattedTrialTimeRemaining?.contains("minute") ?? false)
    }
    
    static var allTests = [
        ("testUserInitialization", testUserInitialization),
        ("testActiveSubscription", testActiveSubscription),
        ("testCanUseApp", testCanUseApp),
        ("testTrialTimeRemaining", testTrialTimeRemaining),
        ("testTrialTimeRemainingFormat", testTrialTimeRemainingFormat)
    ]
} 