import Foundation
import Photos

struct ImportResult {
    let originalItem: MediaItem
    let assetId: String?
    let error: Error?
}