# System Patterns - PhotoMigrator

## Architecture Overview

```
[User Interface Layer]
    |
    v
[Coordinator (ArchiveProcessor)]
    |
    +---------------+---------------+
    |               |               |
    v               v               v
[MetadataExtractor] [PhotosImporter] [AlbumManager]
    |               |               |
    +-------+-------+               |
            |                       |
            v                       v
    [LivePhotoProcessor]    [Batch Processing]
```

## Design Patterns

### MVVM Pattern
- **Models**: Media items, migration data, settings
- **Views**: SwiftUI views for archive selection, progress, summary, etc.
- **ViewModels**: Intermediaries handling presentation logic

### Service Pattern
- Core services (MetadataExtractor, PhotosImporter, etc.) encapsulate complex business logic
- Services are injected into ViewModels for testability

### Observer Pattern
- Migration progress broadcasts changes
- UI components observe and react to state changes

### Strategy Pattern
- Different strategies for metadata extraction based on file types
- Pluggable approaches for Live Photo detection

## Key Design Decisions

1. **Modular Architecture**
   - Separation of concerns with dedicated modules
   - Clear interfaces between components
   - Allows for unit testing and independent development

2. **Memory Management**
   - Batch processing to manage memory for large libraries
   - Resource cleanup between batches
   - Adaptive batch sizing based on system resources

3. **Error Handling**
   - Comprehensive error types with recovery options
   - Graceful degradation when partial failures occur
   - Detailed logging for troubleshooting

4. **PhotoKit Integration**
   - Direct use of Apple's PhotoKit for Photos library access
   - Respecting Apple's privacy and data protection model
   - Working within the constraints of PhotoKit's modification capabilities 