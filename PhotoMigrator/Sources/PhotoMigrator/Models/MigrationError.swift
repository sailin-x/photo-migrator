import Foundation

enum MigrationError: Error, LocalizedError {
    case archiveNotFound
    case archiveExtractionFailed
    case invalidArchiveStructure
    case photosAccessDenied
    case importFailed(reason: String)
    case fileAccessError(path: String)
    case metadataParsingError(details: String)
    case operationCancelled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .archiveNotFound:
            return "The Google Takeout archive file could not be found."
        case .archiveExtractionFailed:
            return "Failed to extract the Google Takeout archive."
        case .invalidArchiveStructure:
            return "The archive structure is invalid or not recognized as a Google Takeout export."
        case .photosAccessDenied:
            return "Access to Apple Photos is required but was denied. Please update permissions in System Preferences."
        case .importFailed(let reason):
            return "Failed to import media: \(reason)"
        case .fileAccessError(let path):
            return "Unable to access file: \(path)"
        case .metadataParsingError(let details):
            return "Error parsing metadata: \(details)"
        case .operationCancelled:
            return "The migration operation was cancelled."
        case .unknown:
            return "An unknown error occurred."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .archiveNotFound:
            return "Make sure the archive file exists and try again."
        case .archiveExtractionFailed:
            return "Check that you have sufficient disk space and appropriate permissions."
        case .invalidArchiveStructure:
            return "Make sure you've selected a valid Google Photos Takeout archive."
        case .photosAccessDenied:
            return "Go to System Preferences > Security & Privacy > Privacy > Photos and enable access for this application."
        case .importFailed:
            return "Check if Apple Photos is running properly and try again."
        case .fileAccessError:
            return "Ensure the file exists and you have appropriate permissions to access it."
        case .metadataParsingError:
            return "The JSON metadata file may be corrupt. Check the logs for more details."
        case .operationCancelled:
            return "You can start a new migration when ready."
        case .unknown:
            return "Try restarting the application and your computer."
        }
    }
}
