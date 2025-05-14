import XCTest
@testable import PhotoMigrator

final class LicenseTests: XCTestCase {
    
    // Create a sample license for testing
    func createSampleLicense(expiresAt: Date? = nil, isActive: Bool = true, activationsUsed: Int = 0, maxActivations: Int = 2) -> License {
        return License(
            id: "test-license-123",
            licenseKey: "LICENSE-KEY-789",
            userId: "user-456",
            type: .perpetual,
            purchasedAt: Date(),
            expiresAt: expiresAt,
            isActive: isActive,
            activationsUsed: activationsUsed,
            maxActivations: maxActivations,
            paymentId: "payment-789",
            orderNumber: "order-123"
        )
    }
    
    func testLicenseInitialization() {
        // Create a sample license
        let license = createSampleLicense()
        
        // Verify properties
        XCTAssertEqual(license.id, "test-license-123")
        XCTAssertEqual(license.licenseKey, "LICENSE-KEY-789")
        XCTAssertEqual(license.userId, "user-456")
        XCTAssertEqual(license.type, License.LicenseType.perpetual)
        XCTAssertTrue(license.isActive)
        XCTAssertEqual(license.activationsUsed, 0)
        XCTAssertEqual(license.maxActivations, 2)
        XCTAssertEqual(license.paymentId, "payment-789")
        XCTAssertEqual(license.orderNumber, "order-123")
    }
    
    func testPerpetualLicenseExpiration() {
        // Create a perpetual license with no expiration date
        let license = createSampleLicense(expiresAt: nil)
        
        // Verify it's not expired
        XCTAssertFalse(license.isExpired)
        XCTAssertNil(license.timeRemaining)
        XCTAssertNil(license.formattedTimeRemaining)
    }
    
    func testExpiredLicense() {
        // Create a license that expired yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let license = createSampleLicense(expiresAt: yesterday)
        
        // Verify it's expired
        XCTAssertTrue(license.isExpired)
        XCTAssertLessThan(license.timeRemaining ?? 0, 0)
        XCTAssertNil(license.formattedTimeRemaining)
        XCTAssertFalse(license.canBeActivated)
    }
    
    func testActiveLicense() {
        // Create a license that expires in the future
        let nextYear = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        let license = createSampleLicense(expiresAt: nextYear)
        
        // Verify it's not expired and can be activated
        XCTAssertFalse(license.isExpired)
        XCTAssertGreaterThan(license.timeRemaining ?? 0, 0)
        XCTAssertNotNil(license.formattedTimeRemaining)
        XCTAssertTrue(license.canBeActivated)
    }
    
    func testActivationsRemaining() {
        // Test a license with no activations used
        let license1 = createSampleLicense(activationsUsed: 0, maxActivations: 5)
        XCTAssertEqual(license1.activationsRemaining, 5)
        
        // Test a license with some activations used
        let license2 = createSampleLicense(activationsUsed: 3, maxActivations: 5)
        XCTAssertEqual(license2.activationsRemaining, 2)
        
        // Test a license with all activations used
        let license3 = createSampleLicense(activationsUsed: 5, maxActivations: 5)
        XCTAssertEqual(license3.activationsRemaining, 0)
        XCTAssertFalse(license3.canBeActivated)
        
        // Test a license with more activations used than allowed (shouldn't happen, but handle it gracefully)
        let license4 = createSampleLicense(activationsUsed: 7, maxActivations: 5)
        XCTAssertEqual(license4.activationsRemaining, 0)
        XCTAssertFalse(license4.canBeActivated)
    }
    
    func testTimeRemainingFormatting() {
        // Create licenses with different expiration times
        let inYears = Calendar.current.date(byAdding: .year, value: 2, to: Date())!
        let inMonths = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        let inDays = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let inHours = Calendar.current.date(byAdding: .hour, value: 12, to: Date())!
        
        let yearLicense = createSampleLicense(expiresAt: inYears)
        let monthLicense = createSampleLicense(expiresAt: inMonths)
        let dayLicense = createSampleLicense(expiresAt: inDays)
        let hourLicense = createSampleLicense(expiresAt: inHours)
        
        // Verify the formatted time remaining for different durations
        XCTAssertTrue(yearLicense.formattedTimeRemaining?.contains("year") ?? false)
        XCTAssertTrue(monthLicense.formattedTimeRemaining?.contains("month") ?? false)
        XCTAssertTrue(dayLicense.formattedTimeRemaining?.contains("day") ?? false)
        XCTAssertTrue(hourLicense.formattedTimeRemaining?.contains("hour") ?? false)
    }
    
    func testInactiveLicense() {
        // Create a license that's marked as inactive
        let license = createSampleLicense(isActive: false)
        
        // Verify it can't be activated
        XCTAssertFalse(license.canBeActivated)
    }
    
    static var allTests = [
        ("testLicenseInitialization", testLicenseInitialization),
        ("testPerpetualLicenseExpiration", testPerpetualLicenseExpiration),
        ("testExpiredLicense", testExpiredLicense),
        ("testActiveLicense", testActiveLicense),
        ("testActivationsRemaining", testActivationsRemaining),
        ("testTimeRemainingFormatting", testTimeRemainingFormatting),
        ("testInactiveLicense", testInactiveLicense)
    ]
} 