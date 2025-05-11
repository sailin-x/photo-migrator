import Foundation
import AVFoundation

class LivePhotoProcessor {
    private let fileManager = FileManager.default
    
    func processLivePhotoComponents(mediaItems: [MediaItem]) async throws -> [MediaItem] {
        var processedItems = mediaItems
        var livePhotoComponents: [String: [MediaItem]] = [:]
        
        // First pass: identify potential Live Photo components and group them by base name
        for (index, item) in mediaItems.enumerated() {
            let fileName = item.fileURL.deletingPathExtension().lastPathComponent
            
            // Check for Pixel Motion Photos (JPG + MP)
            if item.fileURL.pathExtension.lowercased() == "mp" {
                // Mark as a motion component
                processedItems[index].isLivePhotoMotionComponent = true
                
                // Find the matching JPG file
                let jpgBaseName = fileName
                if livePhotoComponents[jpgBaseName] == nil {
                    livePhotoComponents[jpgBaseName] = []
                }
                livePhotoComponents[jpgBaseName]?.append(processedItems[index])
            } 
            // Check for Live Photos components (matching still + video with same base name)
            else {
                if livePhotoComponents[fileName] == nil {
                    livePhotoComponents[fileName] = []
                }
                livePhotoComponents[fileName]?.append(processedItems[index])
            }
        }
        
        // Second pass: process groups to create Live Photos where possible
        var finalItems: [MediaItem] = []
        var processedIndexes = Set<Int>()
        
        for (baseName, components) in livePhotoComponents {
            if components.count >= 2 {
                // Find still image and video components
                let stillComponents = components.filter { FileUtils.isImageFile($0.fileURL) }
                let videoComponents = components.filter { 
                    FileUtils.isVideoFile($0.fileURL) || $0.fileURL.pathExtension.lowercased() == "mp" 
                }
                
                if let stillComponent = stillComponents.first, !videoComponents.isEmpty {
                    // Convert MP to MP4 if necessary
                    var videoComponent = videoComponents.first!
                    var convertedVideoURL: URL?
                    
                    if videoComponent.fileURL.pathExtension.lowercased() == "mp" {
                        // Convert Pixel Motion Photo MP file to MP4
                        do {
                            convertedVideoURL = try await convertMPtoMP4(videoComponent.fileURL)
                        } catch {
                            print("Failed to convert MP to MP4: \(error)")
                        }
                    }
                    
                    // Create a Live Photo item
                    var livePhotoItem = stillComponent
                    livePhotoItem.fileType = .livePhoto
                    livePhotoItem.livePhotoComponentURL = convertedVideoURL ?? videoComponent.fileURL
                    
                    // Mark all components as processed
                    for component in components {
                        if let index = processedItems.firstIndex(where: { $0.id == component.id }) {
                            processedIndexes.insert(index)
                        }
                    }
                    
                    finalItems.append(livePhotoItem)
                    continue
                }
            }
            
            // If not a Live Photo, add each component individually
            for component in components {
                if let index = processedItems.firstIndex(where: { $0.id == component.id }), 
                   !processedIndexes.contains(index) {
                    // Skip components already marked as part of a Live Photo
                    if !component.isLivePhotoMotionComponent {
                        finalItems.append(component)
                    }
                    processedIndexes.insert(index)
                }
            }
        }
        
        // Add any remaining items not processed as Live Photo components
        for (index, item) in processedItems.enumerated() {
            if !processedIndexes.contains(index) {
                finalItems.append(item)
            }
        }
        
        return finalItems
    }
    
    private func convertMPtoMP4(_ mpURL: URL) async throws -> URL {
        let tempDir = fileManager.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                // Create AVAsset from the MP file
                let asset = AVAsset(url: mpURL)
                
                // Setup export session
                guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                    continuation.resume(throwing: MigrationError.importFailed(reason: "Could not create export session"))
                    return
                }
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mp4
                
                // Perform the export
                exportSession.exportAsynchronously {
                    switch exportSession.status {
                    case .completed:
                        continuation.resume(returning: outputURL)
                    case .failed:
                        continuation.resume(throwing: exportSession.error ?? MigrationError.importFailed(reason: "Unknown export error"))
                    case .cancelled:
                        continuation.resume(throwing: MigrationError.operationCancelled)
                    default:
                        continuation.resume(throwing: MigrationError.importFailed(reason: "Unexpected export status"))
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
