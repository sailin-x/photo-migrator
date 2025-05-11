# PhotoMigrator Development Notes

## Architecture Overview

The application follows a modular architecture:

1. **User Interface (SwiftUI)**: 
   - ContentView: Main coordinator view
   - ArchiveSelectionView: Initial interface for selecting Google Takeout archives
   - ProgressView: Shows migration progress
   - SummaryView: Displays results of the migration
   - ErrorView: Presents errors with recovery options

2. **Core Services**:
   - ArchiveProcessor: Primary coordinator for the migration process
   - MetadataExtractor: Extracts and parses metadata from JSON files
   - PhotosImporter: Handles importing to Apple Photos using PhotoKit
   - LivePhotoProcessor: Detects and reconstructs Live Photos
   - AlbumManager: Creates and manages albums in the Photos library

3. **Models**:
   - MediaItem: Represents a media file with its metadata
   - MigrationProgress: Tracks the migration state and statistics
   - MigrationError: Custom error types with localized messages
   - ImportResult: Results of importing an item to Photos

4. **Utilities**:
   - FileUtils: Helper functions for file operations
   - DateTimeUtils: Date and time parsing and formatting
   - LocationUtils: Location data handling

## Implementation Considerations

### Metadata Extraction

The metadata extraction process is particularly complex due to the inconsistent nature of Google Takeout data:

1. **JSON Matching**: The app uses multiple strategies to match JSON files with their media:
   - Direct filename matching (image.jpg → image.jpg.json)
   - Supplemental metadata matching (image.jpg → image.jpg.supplemental-metadata.json)
   - Base name matching for truncated filenames

2. **Priority Systems**: When metadata is available from multiple sources, we use a priority system:
   - JSON metadata takes precedence over embedded EXIF data
   - For JSON fields, we have fallback chains (e.g., photoTakenTime → creationTime → modificationTime)
   - EXIF is used as a fallback for missing JSON data

### Live Photo Reconstruction

Reconstructing Live Photos requires:

1. Detecting related components (still image and video) by:
   - Name pattern matching
   - Content analysis
   - Timestamp proximity

2. Processing components:
   - Converting formats when needed (e.g., MP to MP4)
   - Properly setting relationship markers
   - Ensuring timestamps match

3. Importing as paired resources in PhotoKit

### Error Handling

The app implements comprehensive error handling:

1. Each error type includes:
   - User-friendly description
   - Technical details (for debug logs)
   - Recovery suggestions

2. Error recovery strategies:
   - Automatic retries for transient errors
   - Fallback pathways for missing data
   - Partial success handling (e.g., continuing after individual file errors)

## Known Limitations

1. **PhotoKit Constraints**:
   - Limited ability to write certain metadata (Apple Photos API restrictions)
   - Face recognition tags can only be added as keywords
   - Some edits cannot be recreated due to Apple's editing model

2. **Google Takeout Issues**:
   - Incomplete exports from Google (beyond our control)
   - Inconsistent metadata formatting
   - Timezone handling challenges

3. **Performance Considerations**:
   - Large libraries require significant memory and processing time
   - PhotoKit batch operations have inherent limits

## Batch Processing Implementation

The batch processing system is designed to handle very large photo libraries (100,000+ photos) efficiently:

1. **Architecture**:
   - `BatchProcessingManager`: Core service that handles dividing work into manageable chunks
   - `BatchSettings`: User-configurable settings for batch size and processing
   - Integrated memory monitoring system that adapts to available resources

2. **Memory Optimization**:
   - Adaptive batch sizing that reduces batch size under memory pressure
   - Memory usage monitoring with configurable thresholds
   - Automatic memory cleanup between batches
   - Pauses between batches to allow for memory reclamation

3. **User Configuration**:
   - GUI interface for adjusting batch processing parameters
   - System-adaptive default settings based on available RAM
   - Options to enable/disable adaptive sizing

4. **Performance Reporting**:
   - Detailed progress tracking during batch processing
   - Memory usage statistics and warnings
   - Summary statistics showing batch performance

## Future Enhancements

1. **Improved Live Photo Handling**:
   - Better detection of components using content analysis
   - Support for newer motion photo formats

2. **Advanced Metadata Support**:
   - Custom metadata fields preservation
   - Better handling of edited photo versions

3. **User Experience**:
   - Preview capabilities before import
   - More granular selection of content to import
   - Incremental migration support

4. **Enhanced Batch Processing**:
   - Multi-threaded batch processing for even faster imports
   - Database-backed state persistence for resumable migrations
   - Per-album batch optimization