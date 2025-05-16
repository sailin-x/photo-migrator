import XCTest
import Photos
import Combine
@testable import PhotoMigrator

final class LivePhotoManagerTests: XCTestCase {
    
    // Test components
    var livePhotoManager: LivePhotoManager!
    var tempDirectory: URL!
    var testMediaDirectory: URL!
    
    // Progress publisher for tracking status updates
    var progressPublisher: BatchProgressPublisher!
    var progressEvents: [BatchProgressEvent] = []
    var cancellables: Set<AnyCancellable> = []
    
    override func setUp() {
        super.setUp()
        
        // Create temp directory for testing
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LivePhotoManagerTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create test media directory
        testMediaDirectory = tempDirectory.appendingPathComponent("TestMedia")
        try? FileManager.default.createDirectory(at: testMediaDirectory, withIntermediateDirectories: true)
        
        // Setup progress publisher
        progressPublisher = BatchProgressPublisher()
        progressEvents = []
        
        // Subscribe to progress events
        progressPublisher.eventPublisher
            .sink { [weak self] event in
                self?.progressEvents.append(event)
            }
            .store(in: &cancellables)
        
        // Initialize LivePhotoManager with progress publisher
        livePhotoManager = LivePhotoManager(progressPublisher: progressPublisher)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        // Release resources
        cancellables.removeAll()
        progressEvents = []
        progressPublisher = nil
        livePhotoManager = nil
        tempDirectory = nil
        testMediaDirectory = nil
        
        super.tearDown()
    }
    
    // MARK: - Test Helpers
    
    /// Create a test media file and return a MediaItem
    private func createTestMediaItem(fileName: String, fileType: MediaFileType) -> MediaItem {
        let filePath = testMediaDirectory.appendingPathComponent(fileName)
        let dummyData = "DUMMY_TEST_DATA".data(using: .utf8)!
        try? dummyData.write(to: filePath)
        
        return MediaItem(
            id: UUID().uuidString,
            title: fileName,
            description: nil,
            timestamp: Date(),
            latitude: nil,
            longitude: nil,
            fileURL: filePath,
            fileType: fileType,
            albumNames: [],
            isFavorite: false
        )
    }
    
    /// Create a batch of test media items for Live Photos
    private func createTestBatch(count: Int) -> [MediaItem] {
        var items: [MediaItem] = []
        
        for i in 0..<count {
            // Create a photo-video pair
            let photoItem = createTestMediaItem(
                fileName: "test_photo_\(i).jpg",
                fileType: .photo
            )
            
            let videoItem = createTestMediaItem(
                fileName: "test_photo_\(i).mp4", // Same base name
                fileType: .video
            )
            
            items.append(photoItem)
            items.append(videoItem)
        }
        
        return items
    }
    
    // MARK: - Tests
    
    // Test scanning for Live Photos
    func testScanForLivePhotos() async throws {
        // Create test items
        let items = createTestBatch(count: 5) // 5 photo-video pairs
        
        // Create a directory with media files
        for item in items {
            let dummyData = "TEST_DATA".data(using: .utf8)!
            try dummyData.write(to: item.fileURL)
        }
        
        // Scan for Live Photos
        let results = try await livePhotoManager.scanForLivePhotos(in: testMediaDirectory)
        
        // Verify results
        XCTAssertFalse(results.isEmpty, "Should find Live Photos")
        XCTAssertEqual(results.count, 5, "Should identify 5 Live Photos")
        
        // Check progress events were published
        XCTAssertFalse(progressEvents.isEmpty, "Should publish progress events")
        
        // Check for scanning event
        let scanningEvents = progressEvents.filter {
            if case .livePhotoProgress(_, let stage, _) = $0, stage == .identifying {
                return true
            }
            return false
        }
        XCTAssertFalse(scanningEvents.isEmpty, "Should publish scanning events")
        
        // Verify final status
        XCTAssertEqual(livePhotoManager.stats.totalLivePhotosDetected, 5, "Should detect 5 Live Photos")
    }
    
    // Test batch reconstruction
    func testBatchReconstruction() async throws {
        // Create and configure media items directly
        let items = createTestBatch(count: 3) // 3 photo-video pairs
        
        // Convert to Live Photo items
        var livePhotoItems: [MediaItem] = []
        
        for i in 0..<3 {
            let photoIndex = i * 2
            let videoIndex = i * 2 + 1
            
            var photoItem = items[photoIndex]
            photoItem.fileType = .livePhoto
            photoItem.livePhotoComponentURL = items[videoIndex].fileURL
            
            livePhotoItems.append(photoItem)
        }
        
        // Set up the manager's state to simulate scan completion
        await MainActor.run {
            livePhotoManager.livePhotoItems = livePhotoItems
            livePhotoManager.stats.totalLivePhotosDetected = livePhotoItems.count
            livePhotoManager.stats.pending = livePhotoItems.count
        }
        
        // Reconstruct the Live Photos
        let results = try await livePhotoManager.reconstructLivePhotos(livePhotoItems)
        
        // Verify results
        XCTAssertFalse(results.isEmpty, "Should have reconstruction results")
        
        // Check for reconstruction progress events
        let reconstructionEvents = progressEvents.filter {
            if case .livePhotoProgress(_, let stage, _) = $0, stage == .processing {
                return true
            }
            return false
        }
        XCTAssertFalse(reconstructionEvents.isEmpty, "Should publish reconstruction events")
        
        // Check for completion event
        let completionEvents = progressEvents.filter {
            if case .livePhotoProgress(_, let stage, _) = $0, stage == .complete {
                return true
            }
            return false
        }
        XCTAssertFalse(completionEvents.isEmpty, "Should publish completion event")
    }
    
    // Test cancellation
    func testCancellation() async throws {
        // Create many test items to ensure operation takes some time
        let items = createTestBatch(count: 20) // 20 photo-video pairs
        
        // Convert to Live Photo items
        var livePhotoItems: [MediaItem] = []
        
        for i in 0..<20 {
            let photoIndex = i * 2
            let videoIndex = i * 2 + 1
            
            var photoItem = items[photoIndex]
            photoItem.fileType = .livePhoto
            photoItem.livePhotoComponentURL = items[videoIndex].fileURL
            
            livePhotoItems.append(photoItem)
        }
        
        // Set up the manager's state
        await MainActor.run {
            livePhotoManager.livePhotoItems = livePhotoItems
            livePhotoManager.stats.totalLivePhotosDetected = livePhotoItems.count
            livePhotoManager.stats.pending = livePhotoItems.count
        }
        
        // Start reconstruction in a task
        let task = Task {
            try await livePhotoManager.reconstructLivePhotos(livePhotoItems)
        }
        
        // Wait a bit then cancel
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        livePhotoManager.cancel()
        
        // Wait for task to complete
        let results = try await task.value
        
        // Results should be incomplete
        XCTAssertTrue(results.count < livePhotoItems.count, "Should have partial results due to cancellation")
    }
    
    // Test integration with ArchiveProcessor
    func testArchiveProcessorIntegration() async throws {
        // Create test media items
        let photoItem1 = createTestMediaItem(fileName: "photo1.jpg", fileType: .photo)
        let videoItem1 = createTestMediaItem(fileName: "photo1.mp4", fileType: .video)
        let photoItem2 = createTestMediaItem(fileName: "photo2.jpg", fileType: .photo)
        let videoItem2 = createTestMediaItem(fileName: "photo2.mov", fileType: .video)
        let regularPhoto = createTestMediaItem(fileName: "regular.jpg", fileType: .photo)
        
        let mediaItems = [photoItem1, videoItem1, photoItem2, videoItem2, regularPhoto]
        
        // Create an ArchiveProcessor
        let archiveProcessor = ArchiveProcessor()
        
        // Process the items - this internally calls LivePhotoManager's processMediaItems
        let processedItems = try await archiveProcessor.processLivePhotos(mediaItems)
        
        // Verify the result
        XCTAssertEqual(processedItems.count, mediaItems.count, "Item count should be preserved")
        
        // Check that Live Photos were detected
        let livePhotos = processedItems.filter { $0.fileType == .livePhoto }
        XCTAssertEqual(livePhotos.count, 2, "Should detect 2 Live Photos")
        
        // Check that motion components are marked
        let motionComponents = processedItems.filter { $0.isLivePhotoMotionComponent }
        XCTAssertEqual(motionComponents.count, 2, "Should mark 2 motion components")
    }
    
    static var allTests = [
        ("testScanForLivePhotos", testScanForLivePhotos),
        ("testBatchReconstruction", testBatchReconstruction),
        ("testCancellation", testCancellation),
        ("testArchiveProcessorIntegration", testArchiveProcessorIntegration)
    ]
} 