import XCTest
@testable import PhotoMigrator

final class UserPreferencesTests: XCTestCase {
    
    var userPreferences: UserPreferences!
    
    override func setUp() {
        super.setUp()
        
        // Clear all preference values before each test
        clearUserDefaults()
        
        // Create a new instance for testing
        userPreferences = UserPreferences()
    }
    
    override func tearDown() {
        // Clean up after tests
        clearUserDefaults()
        
        userPreferences = nil
        super.tearDown()
    }
    
    // Helper to clear UserDefaults
    private func clearUserDefaults() {
        let defaults = UserDefaults.standard
        let keys = [
            "batchProcessingEnabled", "batchSize", "useAdaptiveBatchSizing",
            "preserveCreationDates", "preserveLocationData", "preserveDescriptions", "preserveFavorites",
            "importPhotos", "importVideos", "importLivePhotos", "createAlbums",
            "showDetailedStatsOnCompletion", "autoExportReport", "lastUsedDirectory", "recentMigrations"
        ]
        
        keys.forEach { defaults.removeObject(forKey: $0) }
    }
    
    // Test initial values
    func testInitialValues() {
        // Check initial values against expected defaults
        XCTAssertTrue(userPreferences.batchProcessingEnabled)
        XCTAssertEqual(userPreferences.batchSize, BatchSettings.defaultBatchSize)
        XCTAssertTrue(userPreferences.useAdaptiveBatchSizing)
        
        XCTAssertTrue(userPreferences.preserveCreationDates)
        XCTAssertTrue(userPreferences.preserveLocationData)
        XCTAssertTrue(userPreferences.preserveDescriptions)
        XCTAssertTrue(userPreferences.preserveFavorites)
        XCTAssertTrue(userPreferences.importPhotos)
        XCTAssertTrue(userPreferences.importVideos)
        XCTAssertTrue(userPreferences.importLivePhotos)
        XCTAssertTrue(userPreferences.createAlbums)
        
        XCTAssertTrue(userPreferences.showDetailedStatsOnCompletion)
        XCTAssertFalse(userPreferences.autoExportReport)
        XCTAssertNil(userPreferences.lastUsedDirectory)
        XCTAssertTrue(userPreferences.recentMigrations.isEmpty)
    }
    
    // Test saving and loading preferences
    func testSaveAndLoadPreferences() {
        // Modify preferences
        userPreferences.batchProcessingEnabled = false
        userPreferences.batchSize = 50
        userPreferences.useAdaptiveBatchSizing = false
        userPreferences.preserveCreationDates = false
        userPreferences.importVideos = false
        userPreferences.lastUsedDirectory = URL(fileURLWithPath: "/test/path")
        
        // Create a new instance, which should load the saved preferences
        let newPreferences = UserPreferences()
        
        // Verify loaded values match the modified values
        XCTAssertFalse(newPreferences.batchProcessingEnabled)
        XCTAssertEqual(newPreferences.batchSize, 50)
        XCTAssertFalse(newPreferences.useAdaptiveBatchSizing)
        XCTAssertFalse(newPreferences.preserveCreationDates)
        XCTAssertFalse(newPreferences.importVideos)
        XCTAssertEqual(newPreferences.lastUsedDirectory?.path, "/test/path")
    }
    
    // Test getBatchSettings
    func testGetBatchSettings() {
        // Set specific batch settings
        userPreferences.batchProcessingEnabled = false
        userPreferences.batchSize = 25
        userPreferences.useAdaptiveBatchSizing = false
        
        // Get settings object
        let settings = userPreferences.getBatchSettings()
        
        // Verify settings match
        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.batchSize, 25)
        XCTAssertFalse(settings.useAdaptiveSizing)
    }
    
    // Test addRecentMigration
    func testAddRecentMigration() {
        // Create sample migration summaries
        let summary1 = MigrationSummary(
            totalItemsProcessed: 100,
            successfulImports: 90,
            failedImports: 10,
            photoCount: 80,
            videoCount: 20,
            livePhotoCount: 5,
            albumsCreated: 3,
            totalDuration: 120.5
        )
        
        let summary2 = MigrationSummary(
            totalItemsProcessed: 50,
            successfulImports: 45,
            failedImports: 5,
            photoCount: 40,
            videoCount: 10,
            livePhotoCount: 2,
            albumsCreated: 2,
            totalDuration: 60.0
        )
        
        // Add summaries
        userPreferences.addRecentMigration(summary1)
        userPreferences.addRecentMigration(summary2)
        
        // Verify they were added in the correct order (most recent first)
        XCTAssertEqual(userPreferences.recentMigrations.count, 2)
        XCTAssertEqual(userPreferences.recentMigrations[0].totalItemsProcessed, 50)
        XCTAssertEqual(userPreferences.recentMigrations[1].totalItemsProcessed, 100)
    }
    
    // Test limit of recent migrations (should cap at 10)
    func testRecentMigrationsLimit() {
        // Add 15 migrations
        for i in 1...15 {
            let summary = MigrationSummary(
                totalItemsProcessed: i * 10,
                successfulImports: i * 9,
                failedImports: i,
                photoCount: i * 8,
                videoCount: i * 2,
                livePhotoCount: i,
                albumsCreated: i,
                totalDuration: Double(i * 10)
            )
            userPreferences.addRecentMigration(summary)
        }
        
        // Verify only 10 were kept
        XCTAssertEqual(userPreferences.recentMigrations.count, 10)
        
        // Verify the most recent ones were kept (in reverse order)
        XCTAssertEqual(userPreferences.recentMigrations[0].totalItemsProcessed, 150)
        XCTAssertEqual(userPreferences.recentMigrations[9].totalItemsProcessed, 60)
    }
    
    // Test reset to defaults
    func testResetToDefaults() {
        // Change settings from defaults
        userPreferences.batchProcessingEnabled = false
        userPreferences.preserveCreationDates = false
        userPreferences.importVideos = false
        userPreferences.showDetailedStatsOnCompletion = false
        userPreferences.autoExportReport = true
        
        // Reset to defaults
        userPreferences.resetToDefaults()
        
        // Verify all settings are back to defaults
        XCTAssertTrue(userPreferences.batchProcessingEnabled)
        XCTAssertTrue(userPreferences.preserveCreationDates)
        XCTAssertTrue(userPreferences.importVideos)
        XCTAssertTrue(userPreferences.showDetailedStatsOnCompletion)
        XCTAssertFalse(userPreferences.autoExportReport)
    }
    
    static var allTests = [
        ("testInitialValues", testInitialValues),
        ("testSaveAndLoadPreferences", testSaveAndLoadPreferences),
        ("testGetBatchSettings", testGetBatchSettings),
        ("testAddRecentMigration", testAddRecentMigration),
        ("testRecentMigrationsLimit", testRecentMigrationsLimit),
        ("testResetToDefaults", testResetToDefaults)
    ]
} 