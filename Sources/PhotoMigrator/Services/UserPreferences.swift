import Foundation
import Combine

/// Privacy level for metadata handling
enum PrivacyLevel: String, Codable {
    case standard // Basic protection - respects individual toggle settings
    case enhanced // Higher protection - strips more metadata beyond toggle settings
    case maximum  // Maximum protection - strips all potentially sensitive metadata
}

/// Service that manages and persists user preferences
class UserPreferences: ObservableObject {
    /// Shared singleton instance
    static let shared = UserPreferences()
    
    // MARK: - Batch Processing Preferences
    
    /// Whether batch processing is enabled
    @Published var batchProcessingEnabled: Bool = true {
        didSet {
            savePreferences()
        }
    }
    
    /// Batch size for processing
    @Published var batchSize: Int = BatchSettings.defaultBatchSize {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to use adaptive batch sizing
    @Published var useAdaptiveBatchSizing: Bool = true {
        didSet {
            savePreferences()
        }
    }
    
    // MARK: - Import Preferences
    
    /// Whether to preserve original creation dates
    @Published var preserveCreationDates: Bool = true {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to preserve location data
    @Published var preserveLocationData: Bool = true {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to preserve descriptions
    @Published var preserveDescriptions: Bool = true {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to preserve favorite status
    @Published var preserveFavorites: Bool = true {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to import photos
    @Published var importPhotos: Bool = true {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to import videos
    @Published var importVideos: Bool = true {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to import live photos
    @Published var importLivePhotos: Bool = true {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to create albums
    @Published var createAlbums: Bool = true {
        didSet {
            savePreferences()
        }
    }
    
    // MARK: - Privacy Preferences
    
    /// Privacy level for metadata handling
    @Published var privacyLevel: PrivacyLevel = .standard {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to completely strip GPS data regardless of preserveLocationData setting
    @Published var stripGPSData: Bool = false {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to obfuscate location data by reducing precision instead of removing completely
    @Published var obfuscateLocationData: Bool = false {
        didSet {
            savePreferences()
        }
    }
    
    /// Precision level for obfuscated GPS data (in decimal places: 0-6)
    /// 0: ~111km, 1: ~11km, 2: ~1.1km, 3: ~110m, 4: ~11m, 5: ~1.1m, 6: ~0.11m
    @Published var locationPrecisionLevel: Int = 2 {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to strip personal identifiers from metadata
    @Published var stripPersonalIdentifiers: Bool = false {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to strip device information (camera make/model)
    @Published var stripDeviceInfo: Bool = false {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to log sensitive metadata (disabled for security)
    @Published var logSensitiveMetadata: Bool = false {
        didSet {
            savePreferences()
        }
    }
    
    // MARK: - UI Preferences
    
    /// Whether to show detailed statistics view after migration
    @Published var showDetailedStatsOnCompletion: Bool = true {
        didSet {
            savePreferences()
        }
    }
    
    /// Whether to export report automatically
    @Published var autoExportReport: Bool = false {
        didSet {
            savePreferences()
        }
    }
    
    /// Last used directory for Takeout archives
    @Published var lastUsedDirectory: URL? {
        didSet {
            savePreferences()
        }
    }
    
    /// Recent migration summaries (for history)
    @Published var recentMigrations: [MigrationSummary] = [] {
        didSet {
            savePreferences()
        }
    }
    
    // MARK: - Initialization
    
    /// Private initializer for singleton
    private init() {
        loadPreferences()
    }
    
    // MARK: - Save/Load Methods
    
    /// Save preferences to UserDefaults
    private func savePreferences() {
        let defaults = UserDefaults.standard
        
        // Batch processing preferences
        defaults.set(batchProcessingEnabled, forKey: "batchProcessingEnabled")
        defaults.set(batchSize, forKey: "batchSize")
        defaults.set(useAdaptiveBatchSizing, forKey: "useAdaptiveBatchSizing")
        
        // Import preferences
        defaults.set(preserveCreationDates, forKey: "preserveCreationDates")
        defaults.set(preserveLocationData, forKey: "preserveLocationData")
        defaults.set(preserveDescriptions, forKey: "preserveDescriptions")
        defaults.set(preserveFavorites, forKey: "preserveFavorites")
        defaults.set(importPhotos, forKey: "importPhotos")
        defaults.set(importVideos, forKey: "importVideos")
        defaults.set(importLivePhotos, forKey: "importLivePhotos")
        defaults.set(createAlbums, forKey: "createAlbums")
        
        // Privacy preferences
        defaults.set(privacyLevel.rawValue, forKey: "privacyLevel")
        defaults.set(stripGPSData, forKey: "stripGPSData")
        defaults.set(obfuscateLocationData, forKey: "obfuscateLocationData")
        defaults.set(locationPrecisionLevel, forKey: "locationPrecisionLevel")
        defaults.set(stripPersonalIdentifiers, forKey: "stripPersonalIdentifiers")
        defaults.set(stripDeviceInfo, forKey: "stripDeviceInfo")
        defaults.set(logSensitiveMetadata, forKey: "logSensitiveMetadata")
        
        // UI preferences
        defaults.set(showDetailedStatsOnCompletion, forKey: "showDetailedStatsOnCompletion")
        defaults.set(autoExportReport, forKey: "autoExportReport")
        
        // Save last used directory
        if let lastUsedDirectory = lastUsedDirectory {
            defaults.set(lastUsedDirectory.path, forKey: "lastUsedDirectory")
        }
        
        // Recent migrations (limited to last 10)
        if recentMigrations.count > 10 {
            recentMigrations = Array(recentMigrations.prefix(10))
        }
        
        // We can't directly save MigrationSummary objects to UserDefaults
        // so we'll just save minimal info for history display
        let recentMigrationsData = recentMigrations.map { summary -> [String: Any] in
            return [
                "date": Date(),
                "totalItems": summary.totalItemsProcessed,
                "successfulImports": summary.successfulImports,
                "albums": summary.albumsCreated
            ]
        }
        defaults.set(recentMigrationsData, forKey: "recentMigrations")
    }
    
    /// Load preferences from UserDefaults
    private func loadPreferences() {
        let defaults = UserDefaults.standard
        
        // Batch processing preferences
        batchProcessingEnabled = defaults.object(forKey: "batchProcessingEnabled") as? Bool ?? true
        batchSize = defaults.object(forKey: "batchSize") as? Int ?? BatchSettings.defaultBatchSize
        useAdaptiveBatchSizing = defaults.object(forKey: "useAdaptiveBatchSizing") as? Bool ?? true
        
        // Import preferences
        preserveCreationDates = defaults.object(forKey: "preserveCreationDates") as? Bool ?? true
        preserveLocationData = defaults.object(forKey: "preserveLocationData") as? Bool ?? true
        preserveDescriptions = defaults.object(forKey: "preserveDescriptions") as? Bool ?? true
        preserveFavorites = defaults.object(forKey: "preserveFavorites") as? Bool ?? true
        importPhotos = defaults.object(forKey: "importPhotos") as? Bool ?? true
        importVideos = defaults.object(forKey: "importVideos") as? Bool ?? true
        importLivePhotos = defaults.object(forKey: "importLivePhotos") as? Bool ?? true
        createAlbums = defaults.object(forKey: "createAlbums") as? Bool ?? true
        
        // Privacy preferences
        if let privacyLevelString = defaults.string(forKey: "privacyLevel"),
           let level = PrivacyLevel(rawValue: privacyLevelString) {
            privacyLevel = level
        } else {
            privacyLevel = .standard
        }
        
        stripGPSData = defaults.object(forKey: "stripGPSData") as? Bool ?? false
        obfuscateLocationData = defaults.object(forKey: "obfuscateLocationData") as? Bool ?? false
        locationPrecisionLevel = defaults.object(forKey: "locationPrecisionLevel") as? Int ?? 2
        stripPersonalIdentifiers = defaults.object(forKey: "stripPersonalIdentifiers") as? Bool ?? false
        stripDeviceInfo = defaults.object(forKey: "stripDeviceInfo") as? Bool ?? false
        logSensitiveMetadata = defaults.object(forKey: "logSensitiveMetadata") as? Bool ?? false
        
        // UI preferences
        showDetailedStatsOnCompletion = defaults.object(forKey: "showDetailedStatsOnCompletion") as? Bool ?? true
        autoExportReport = defaults.object(forKey: "autoExportReport") as? Bool ?? false
        
        // Load last used directory
        if let lastUsedDirPath = defaults.string(forKey: "lastUsedDirectory") {
            lastUsedDirectory = URL(fileURLWithPath: lastUsedDirPath)
        }
        
        // We don't restore the full migration summaries from UserDefaults
        // as they can be quite large. In a full implementation, we would
        // use a database to store these.
    }
    
    /// Get batch settings based on current preferences
    func getBatchSettings() -> BatchSettings {
        var settings = BatchSettings()
        settings.isEnabled = batchProcessingEnabled
        settings.batchSize = batchSize
        settings.useAdaptiveSizing = useAdaptiveBatchSizing
        return settings
    }
    
    /// Add a recent migration to history
    func addRecentMigration(_ summary: MigrationSummary) {
        recentMigrations.insert(summary, at: 0)
        if recentMigrations.count > 10 {
            recentMigrations = Array(recentMigrations.prefix(10))
        }
        savePreferences()
    }
    
    /// Reset preferences to defaults
    func resetToDefaults() {
        // Batch processing preferences
        batchProcessingEnabled = true
        batchSize = BatchSettings.defaultBatchSize
        useAdaptiveBatchSizing = true
        
        // Import preferences
        preserveCreationDates = true
        preserveLocationData = true
        preserveDescriptions = true
        preserveFavorites = true
        importPhotos = true
        importVideos = true
        importLivePhotos = true
        createAlbums = true
        
        // Privacy preferences
        privacyLevel = .standard
        stripGPSData = false
        obfuscateLocationData = false
        locationPrecisionLevel = 2
        stripPersonalIdentifiers = false
        stripDeviceInfo = false
        logSensitiveMetadata = false
        
        // UI preferences
        showDetailedStatsOnCompletion = true
        autoExportReport = false
        
        // Save changes
        savePreferences()
    }
}