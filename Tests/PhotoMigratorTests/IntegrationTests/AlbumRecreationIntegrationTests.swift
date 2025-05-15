import XCTest
import Photos
@testable import PhotoMigrator

final class AlbumRecreationIntegrationTests: XCTestCase {
    
    // Test components
    var albumProcessor: AlbumProcessor!
    var photosImporter: PhotosImporter!
    var tempDirectory: URL!
    var testArchiveURL: URL!
    
    // Test albums and mock data
    var testAlbums: [Album] = []
    var mockAssetIds: [String: String] = [:] // Maps media item IDs to PHAsset IDs
    
    override func setUp() {
        super.setUp()
        
        // Create temp directory for testing
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AlbumTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create test archive directory
        testArchiveURL = tempDirectory.appendingPathComponent("TestArchive")
        prepareTestArchive()
        
        // Initialize components
        photosImporter = PhotosImporter()
        albumProcessor = AlbumProcessor(photosImporter: photosImporter)
    }
    
    override func tearDown() {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        albumProcessor = nil
        photosImporter = nil
        tempDirectory = nil
        testArchiveURL = nil
        testAlbums = []
        mockAssetIds = [:]
        
        super.tearDown()
    }
    
    // MARK: - Test Helpers
    
    // Create a test archive with sample album data
    private func prepareTestArchive() {
        let fileManager = FileManager.default
        
        // Create archive directory structure
        let albumsDir = testArchiveURL.appendingPathComponent("Google Photos/Albums")
        try? fileManager.createDirectory(at: albumsDir, withIntermediateDirectories: true)
        
        // Create a few test albums
        createTestAlbum(name: "Vacation", itemCount: 5, directory: albumsDir)
        createTestAlbum(name: "Family", itemCount: 3, directory: albumsDir)
        createTestAlbum(name: "Pets", itemCount: 2, directory: albumsDir)
    }
    
    // Create a test album with sample data
    private func createTestAlbum(name: String, itemCount: Int, directory: URL) {
        // Create album JSON file
        let albumPath = directory.appendingPathComponent("\(name).json")
        
        // Create media items for this album
        var mediaItems: [MediaItem] = []
        var albumMediaEntries: [[String: Any]] = []
        
        for i in 1...itemCount {
            let fileName = "photo_\(name)_\(i).jpg"
            let fileURL = testArchiveURL.appendingPathComponent("Google Photos/\(fileName)")
            
            // Create dummy file
            let dummyData = "DUMMY_PHOTO_DATA".data(using: .utf8)!
            try? dummyData.write(to: fileURL)
            
            // Create MediaItem
            let mediaItem = MediaItem(
                id: "mediaitem_\(name)_\(i)",
                fileURL: fileURL,
                fileType: .photo,
                timestamp: Date().addingTimeInterval(Double(i * 3600)),
                isFavorite: (i % 2 == 0)
            )
            
            mediaItems.append(mediaItem)
            
            // Create album media entry
            let entry: [String: Any] = [
                "title": fileName,
                "description": "Photo \(i) in \(name) album",
                "imageViews": "\(i * 10)",
                "creationTime": [
                    "timestamp": "\(Int(Date().timeIntervalSince1970) + (i * 3600))",
                    "formatted": "Mar \(i + 1), 2022, 3:00:00 PM UTC"
                ],
                "geoData": [
                    "latitude": 40.7128 + (Double(i) * 0.01),
                    "longitude": -74.0060 + (Double(i) * 0.01)
                ]
            ]
            
            albumMediaEntries.append(entry)
        }
        
        // Create album data
        let albumData: [String: Any] = [
            "title": name,
            "description": "Test album for \(name)",
            "access": "private",
            "date": [
                "timestamp": "\(Int(Date().timeIntervalSince1970))",
                "formatted": "Mar 15, 2022"
            ],
            "googlePhotosOrigin": [
                "albumType": "USER_ALBUM"
            ],
            "media": albumMediaEntries
        ]
        
        // Write album JSON to file
        if let jsonData = try? JSONSerialization.data(withJSONObject: albumData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? jsonString.write(to: albumPath, atomically: true, encoding: .utf8)
        }
        
        // Create Album model
        let album = Album(
            id: "album_\(name)",
            name: name,
            description: "Test album for \(name)",
            creationDate: Date(),
            mediaItems: mediaItems
        )
        
        testAlbums.append(album)
        
        // Create mock asset IDs for testing
        for item in mediaItems {
            // In a real scenario, these would be real PHAsset IDs
            mockAssetIds[item.id] = "mock_asset_\(UUID().uuidString)"
        }
    }
    
    // Create a mock function that simulates album creation without actually accessing Photos framework
    private func mockCreateAlbum(withName name: String, mediaAssetIds: [String]) async throws -> String {
        // In real integration tests, we would access Photos API here
        // This is a mock that simulates success or failure
        
        if name.isEmpty {
            throw MigrationError.invalidAlbumName(name)
        }
        
        if mediaAssetIds.isEmpty {
            throw MigrationError.noMediaItemsInAlbum(name)
        }
        
        // Return a mock album ID
        return "album_\(UUID().uuidString)"
    }
    
    // MARK: - Tests
    
    // Test extracting albums from archive
    func testExtractAlbumsFromArchive() async {
        // Create and configure a mock ArchiveProcessor
        let metadataExtractor = MetadataExtractor()
        let archiveProcessor = ArchiveProcessor(metadataExtractor: metadataExtractor)
        
        // Extract albums
        do {
            let extractedAlbums = try await archiveProcessor.extractAlbums(from: testArchiveURL)
            
            // Verify extraction
            XCTAssertFalse(extractedAlbums.isEmpty, "Should extract albums from archive")
            XCTAssertEqual(extractedAlbums.count, testAlbums.count, "Should extract all test albums")
            
            // Verify album contents
            for album in extractedAlbums {
                XCTAssertFalse(album.name.isEmpty, "Album should have a name")
                XCTAssertFalse(album.mediaItems.isEmpty, "Album should have media items")
                
                // Find the matching test album
                let matchingTestAlbum = testAlbums.first { $0.name == album.name }
                XCTAssertNotNil(matchingTestAlbum, "Should find matching test album for \(album.name)")
                
                // Verify media item count
                XCTAssertEqual(album.mediaItems.count, matchingTestAlbum?.mediaItems.count, 
                              "Should have same media item count for album \(album.name)")
            }
        } catch {
            XCTFail("Album extraction failed with error: \(error)")
        }
    }
    
    // Test album creation with mock implementation
    func testAlbumCreation() async {
        guard !testAlbums.isEmpty else {
            XCTFail("No test albums available")
            return
        }
        
        // Create a subclass with overridden creation method for testing
        class TestAlbumProcessor: AlbumProcessor {
            var createAlbumCalled = false
            var lastAlbumName: String?
            var lastAssetIds: [String]?
            
            override func createAlbum(withName name: String, mediaAssetIds: [String]) async throws -> String {
                createAlbumCalled = true
                lastAlbumName = name
                lastAssetIds = mediaAssetIds
                
                if name.isEmpty {
                    throw MigrationError.invalidAlbumName(name)
                }
                
                if mediaAssetIds.isEmpty {
                    throw MigrationError.noMediaItemsInAlbum(name)
                }
                
                return "test_album_\(UUID().uuidString)"
            }
        }
        
        // Use test subclass
        let testProcessor = TestAlbumProcessor(photosImporter: photosImporter)
        
        // Test album with valid data
        let testAlbum = testAlbums.first!
        let mockAssetIdsForAlbum = testAlbum.mediaItems.compactMap { mockAssetIds[$0.id] }
        
        // Create the album
        do {
            let albumId = try await testProcessor.recreateAlbum(testAlbum, withAssetIds: mockAssetIdsForAlbum)
            
            // Verify method calls
            XCTAssertTrue(testProcessor.createAlbumCalled, "createAlbum should be called")
            XCTAssertEqual(testProcessor.lastAlbumName, testAlbum.name, "Album name should match")
            XCTAssertEqual(testProcessor.lastAssetIds, mockAssetIdsForAlbum, "Asset IDs should match")
            
            // Verify result
            XCTAssertFalse(albumId.isEmpty, "Should return a valid album ID")
            XCTAssertTrue(albumId.hasPrefix("test_album_"), "Album ID should have expected format")
        } catch {
            XCTFail("Album creation failed with error: \(error)")
        }
    }
    
    // Test error handling for invalid albums
    func testErrorHandlingForInvalidAlbums() async {
        // Create a subclass with overridden creation method for testing
        class TestAlbumProcessor: AlbumProcessor {
            override func createAlbum(withName name: String, mediaAssetIds: [String]) async throws -> String {
                if name.isEmpty {
                    throw MigrationError.invalidAlbumName(name)
                }
                
                if mediaAssetIds.isEmpty {
                    throw MigrationError.noMediaItemsInAlbum(name)
                }
                
                return "test_album_\(UUID().uuidString)"
            }
        }
        
        // Use test subclass
        let testProcessor = TestAlbumProcessor(photosImporter: photosImporter)
        
        // Test album with invalid name
        let invalidNameAlbum = Album(
            id: "invalid_album",
            name: "",
            description: "Album with invalid name",
            creationDate: Date(),
            mediaItems: []
        )
        
        // Test album with no items
        let emptyAlbum = Album(
            id: "empty_album",
            name: "Empty Album",
            description: "Album with no items",
            creationDate: Date(),
            mediaItems: []
        )
        
        // Test invalid name
        do {
            _ = try await testProcessor.recreateAlbum(invalidNameAlbum, withAssetIds: [])
            XCTFail("Should throw error for invalid album name")
        } catch {
            if let migrationError = error as? MigrationError, case .invalidAlbumName = migrationError {
                // Expected error
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
        
        // Test empty album
        do {
            _ = try await testProcessor.recreateAlbum(emptyAlbum, withAssetIds: [])
            XCTFail("Should throw error for empty album")
        } catch {
            if let migrationError = error as? MigrationError, case .noMediaItemsInAlbum = migrationError {
                // Expected error
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
    
    // Test batch album creation
    func testBatchAlbumCreation() async {
        guard testAlbums.count >= 2 else {
            XCTFail("Not enough test albums available")
            return
        }
        
        // Create a subclass with overridden creation method for testing
        class TestAlbumProcessor: AlbumProcessor {
            var albumsCreated: [String] = []
            
            override func createAlbum(withName name: String, mediaAssetIds: [String]) async throws -> String {
                if name.isEmpty {
                    throw MigrationError.invalidAlbumName(name)
                }
                
                if mediaAssetIds.isEmpty {
                    throw MigrationError.noMediaItemsInAlbum(name)
                }
                
                let albumId = "test_album_\(UUID().uuidString)"
                albumsCreated.append(name)
                return albumId
            }
        }
        
        // Use test subclass
        let testProcessor = TestAlbumProcessor(photosImporter: photosImporter)
        
        // Prepare asset ID mapping
        var mediaItemToAssetMap: [String: String] = [:]
        for album in testAlbums {
            for item in album.mediaItems {
                mediaItemToAssetMap[item.id] = mockAssetIds[item.id] ?? "mock_asset_\(UUID().uuidString)"
            }
        }
        
        // Process all albums
        let results = await testProcessor.recreateAlbums(testAlbums, mediaItemToAssetIdMap: mediaItemToAssetMap)
        
        // Verify results
        XCTAssertEqual(results.count, testAlbums.count, "Should process all albums")
        
        // Verify all albums were created
        XCTAssertEqual(testProcessor.albumsCreated.count, testAlbums.count, "Should create all albums")
        
        // Verify album names
        let expectedAlbumNames = Set(testAlbums.map { $0.name })
        let createdAlbumNames = Set(testProcessor.albumsCreated)
        XCTAssertEqual(createdAlbumNames, expectedAlbumNames, "Created album names should match test albums")
        
        // Verify successful results
        let successfulResults = results.filter { $0.success }
        XCTAssertEqual(successfulResults.count, testAlbums.count, "All albums should be created successfully")
        
        for result in successfulResults {
            XCTAssertNotNil(result.albumId, "Successful result should have album ID")
            XCTAssertNil(result.error, "Successful result should not have error")
        }
    }
    
    // Test handling of empty or invalid albums in batch
    func testBatchErrorHandling() async {
        // Create some invalid albums to mix with valid ones
        let invalidAlbums = [
            Album(
                id: "invalid_album_1",
                name: "",
                description: "Album with invalid name",
                creationDate: Date(),
                mediaItems: []
            ),
            Album(
                id: "invalid_album_2", 
                name: "Empty Album",
                description: "Album with no items",
                creationDate: Date(), 
                mediaItems: []
            )
        ]
        
        // Combine valid and invalid albums
        let mixedAlbums = testAlbums + invalidAlbums
        
        // Create a subclass with overridden creation method for testing
        class TestAlbumProcessor: AlbumProcessor {
            override func createAlbum(withName name: String, mediaAssetIds: [String]) async throws -> String {
                if name.isEmpty {
                    throw MigrationError.invalidAlbumName(name)
                }
                
                if mediaAssetIds.isEmpty {
                    throw MigrationError.noMediaItemsInAlbum(name)
                }
                
                return "test_album_\(UUID().uuidString)"
            }
        }
        
        // Use test subclass
        let testProcessor = TestAlbumProcessor(photosImporter: photosImporter)
        
        // Prepare asset ID mapping (only for valid albums)
        var mediaItemToAssetMap: [String: String] = [:]
        for album in testAlbums {
            for item in album.mediaItems {
                mediaItemToAssetMap[item.id] = mockAssetIds[item.id] ?? "mock_asset_\(UUID().uuidString)"
            }
        }
        
        // Process all albums
        let results = await testProcessor.recreateAlbums(mixedAlbums, mediaItemToAssetIdMap: mediaItemToAssetMap)
        
        // Verify results
        XCTAssertEqual(results.count, mixedAlbums.count, "Should process all albums")
        
        // Verify successful and failed results
        let successfulResults = results.filter { $0.success }
        let failedResults = results.filter { !$0.success }
        
        XCTAssertEqual(successfulResults.count, testAlbums.count, "Valid albums should succeed")
        XCTAssertEqual(failedResults.count, invalidAlbums.count, "Invalid albums should fail")
        
        // Verify error types
        let emptyNameError = failedResults.first { $0.album.name.isEmpty }?.error
        XCTAssertNotNil(emptyNameError, "Should have error for empty name")
        
        if let migrationError = emptyNameError as? MigrationError {
            switch migrationError {
            case .invalidAlbumName:
                // Expected error type
                break
            default:
                XCTFail("Unexpected error type: \(migrationError)")
            }
        }
        
        let emptyAlbumError = failedResults.first { !$0.album.name.isEmpty && $0.album.mediaItems.isEmpty }?.error
        XCTAssertNotNil(emptyAlbumError, "Should have error for empty album")
        
        if let migrationError = emptyAlbumError as? MigrationError {
            switch migrationError {
            case .noMediaItemsInAlbum:
                // Expected error type
                break
            default:
                XCTFail("Unexpected error type: \(migrationError)")
            }
        }
    }
    
    static var allTests = [
        ("testExtractAlbumsFromArchive", testExtractAlbumsFromArchive),
        ("testAlbumCreation", testAlbumCreation),
        ("testErrorHandlingForInvalidAlbums", testErrorHandlingForInvalidAlbums),
        ("testBatchAlbumCreation", testBatchAlbumCreation),
        ("testBatchErrorHandling", testBatchErrorHandling)
    ]
} 