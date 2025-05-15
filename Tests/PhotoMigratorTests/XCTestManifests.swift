import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(MediaItemTests.allTests),
        testCase(MigrationProgressTests.allTests),
        testCase(MigrationErrorTests.allTests),
        testCase(DateTimeUtilsTests.allTests),
        testCase(MetadataExtractorTests.allTests),
        testCase(ArchiveProcessorTests.allTests),
        testCase(LivePhotoProcessorTests.allTests),
        testCase(BatchSettingsTests.allTests),
        testCase(LicenseTests.allTests),
        testCase(ImportResultTests.allTests),
        testCase(FileUtilsTests.allTests),
        testCase(UserTests.allTests),
        testCase(LocationUtilsTests.allTests),
        testCase(MemoryMonitorTests.allTests),
        testCase(PhotosImporterTests.allTests),
        testCase(UserPreferencesTests.allTests),
        testCase(BatchSizeAdvisorTests.allTests),
        
        // Integration Tests
        testCase(ArchiveProcessingIntegrationTests.allTests),
        testCase(LivePhotoReconstructionIntegrationTests.allTests),
        testCase(PhotosImportIntegrationTests.allTests),
        testCase(AlbumRecreationIntegrationTests.allTests),
    ]
}
#endif 