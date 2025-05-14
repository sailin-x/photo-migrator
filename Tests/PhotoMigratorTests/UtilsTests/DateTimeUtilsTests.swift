import XCTest
@testable import PhotoMigrator

final class DateTimeUtilsTests: XCTestCase {
    
    func testParseISO8601Date() {
        // Test valid ISO 8601 date strings
        let isoString1 = "2022-03-15T14:30:45Z"
        let isoString2 = "2022-03-15T14:30:45+00:00"
        let isoString3 = "2022-03-15T14:30:45.123Z"
        
        // Parse dates
        let date1 = DateTimeUtils.parseISO8601Date(isoString1)
        let date2 = DateTimeUtils.parseISO8601Date(isoString2)
        let date3 = DateTimeUtils.parseISO8601Date(isoString3)
        
        // Verify parsing succeeded
        XCTAssertNotNil(date1)
        XCTAssertNotNil(date2)
        XCTAssertNotNil(date3)
        
        // Test invalid date string
        let invalidString = "not-a-date"
        let invalidDate = DateTimeUtils.parseISO8601Date(invalidString)
        XCTAssertNil(invalidDate)
    }
    
    func testParseGoogleTakeoutDate() {
        // Test Google Takeout date formats
        let takeoutString1 = "Mar 15, 2022, 2:30:45 PM UTC"
        let takeoutString2 = "Mar 15, 2022, 2:30 PM UTC"
        
        // Parse dates
        let date1 = DateTimeUtils.parseGoogleTakeoutDate(takeoutString1)
        let date2 = DateTimeUtils.parseGoogleTakeoutDate(takeoutString2)
        
        // Verify parsing succeeded
        XCTAssertNotNil(date1)
        XCTAssertNotNil(date2)
        
        // Test invalid date string
        let invalidString = "not-a-date"
        let invalidDate = DateTimeUtils.parseGoogleTakeoutDate(invalidString)
        XCTAssertNil(invalidDate)
    }
    
    func testFormatDateForDisplay() {
        // Create a fixed date for testing
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = 2022
        dateComponents.month = 3
        dateComponents.day = 15
        dateComponents.hour = 14
        dateComponents.minute = 30
        dateComponents.second = 45
        
        guard let testDate = calendar.date(from: dateComponents) else {
            XCTFail("Failed to create test date")
            return
        }
        
        // Format date
        let formattedDate = DateTimeUtils.formatDateForDisplay(testDate)
        
        // Verify format contains expected parts (exact format depends on locale)
        XCTAssertTrue(formattedDate.contains("2022"))
        XCTAssertTrue(formattedDate.contains("3") || formattedDate.contains("03") || formattedDate.contains("Mar"))
        XCTAssertTrue(formattedDate.contains("15"))
    }
    
    func testExtractDateFromFilePath() {
        // Test file paths with date patterns
        let path1 = "/Photos/2022/03/IMG_20220315_143045.jpg"
        let path2 = "/Photos/IMG_20220315143045.jpg"
        let path3 = "/Photos/Photo-2022-03-15-14-30-45.jpg"
        
        // Extract dates
        let date1 = DateTimeUtils.extractDateFromFilePath(path1)
        let date2 = DateTimeUtils.extractDateFromFilePath(path2)
        let date3 = DateTimeUtils.extractDateFromFilePath(path3)
        
        // Verify extraction succeeded
        XCTAssertNotNil(date1)
        XCTAssertNotNil(date2)
        XCTAssertNotNil(date3)
        
        // Test path without date pattern
        let invalidPath = "/Photos/image.jpg"
        let invalidDate = DateTimeUtils.extractDateFromFilePath(invalidPath)
        XCTAssertNil(invalidDate)
    }
    
    static var allTests = [
        ("testParseISO8601Date", testParseISO8601Date),
        ("testParseGoogleTakeoutDate", testParseGoogleTakeoutDate),
        ("testFormatDateForDisplay", testFormatDateForDisplay),
        ("testExtractDateFromFilePath", testExtractDateFromFilePath)
    ]
} 