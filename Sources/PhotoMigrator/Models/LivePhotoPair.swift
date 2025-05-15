import Foundation

/// A struct representing a pair of media items that form a Live Photo
struct LivePhotoPair {
    /// The still image component
    let photoItem: MediaItem
    
    /// The video/motion component
    let videoItem: MediaItem
    
    /// Creation timestamp to use for the Live Photo (defaults to photoItem's timestamp)
    var timestamp: Date {
        return photoItem.timestamp
    }
    
    /// Whether this is marked as a favorite (inherited from photoItem)
    var isFavorite: Bool {
        return photoItem.isFavorite
    }
    
    /// The base name (without extension) that both items share
    var baseName: String {
        return photoItem.fileURL.deletingPathExtension().lastPathComponent
    }
    
    /// Result of Live Photo processing
    struct ProcessingResult {
        /// Original pair that was processed
        let originalPair: LivePhotoPair
        
        /// URL to the created Live Photo, if successful
        let livePhotoURL: URL?
        
        /// Whether processing was successful
        let success: Bool
        
        /// Error encountered during processing, if any
        let error: Error?
    }
} 