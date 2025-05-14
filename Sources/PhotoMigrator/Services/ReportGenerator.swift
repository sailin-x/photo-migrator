import Foundation
import SwiftUI
import Charts

/// Service that generates detailed reports based on migration statistics
class ReportGenerator {
    /// Generate a detailed report from migration summary
    /// - Parameter summary: The completed migration summary
    /// - Returns: URL to the generated report file
    func generateReport(from summary: MigrationSummary) -> URL? {
        do {
            // Create report directory if it doesn't exist
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let reportsDirectory = documentsDirectory.appendingPathComponent("PhotoMigratorReports")
            
            if !FileManager.default.fileExists(atPath: reportsDirectory.path) {
                try FileManager.default.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
            }
            
            // Create report file with timestamp
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
            let dateString = dateFormatter.string(from: Date())
            
            let reportURL = reportsDirectory.appendingPathComponent("MigrationReport_\(dateString).html")
            
            // Generate HTML report
            let htmlContent = generateHTMLReport(from: summary)
            try htmlContent.write(to: reportURL, atomically: true, encoding: .utf8)
            
            // Also generate a CSV version for data analysis
            let csvURL = reportsDirectory.appendingPathComponent("MigrationReport_\(dateString).csv")
            let csvContent = generateCSVReport(from: summary)
            try csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
            
            return reportURL
        } catch {
            print("Failed to generate report: \(error)")
            return nil
        }
    }
    
    /// Generate human-readable HTML report
    private func generateHTMLReport(from summary: MigrationSummary) -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>PhotoMigrator - Migration Report</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    max-width: 1000px;
                    margin: 0 auto;
                    padding: 20px;
                }
                h1, h2, h3 {
                    color: #2c3e50;
                }
                h1 {
                    border-bottom: 2px solid #3498db;
                    padding-bottom: 10px;
                }
                h2 {
                    border-bottom: 1px solid #ddd;
                    padding-bottom: 5px;
                    margin-top: 30px;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 20px 0;
                }
                th, td {
                    padding: 12px 15px;
                    text-align: left;
                    border-bottom: 1px solid #ddd;
                }
                th {
                    background-color: #f8f9fa;
                    font-weight: 600;
                }
                tr:hover {
                    background-color: #f1f1f1;
                }
                .success-rate {
                    font-size: 24px;
                    font-weight: bold;
                    padding: 10px;
                    border-radius: 4px;
                    margin: 20px 0;
                }
                .success-high {
                    color: #27ae60;
                    background-color: #e8f8f5;
                }
                .success-medium {
                    color: #f39c12;
                    background-color: #fef9e7;
                }
                .success-low {
                    color: #e74c3c;
                    background-color: #fdedec;
                }
                .stat-box {
                    background-color: #f8f9fa;
                    border-radius: 8px;
                    padding: 15px;
                    margin-bottom: 20px;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                }
                .stat-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
                    gap: 15px;
                    margin: 20px 0;
                }
                .stat-item {
                    background-color: #fff;
                    padding: 15px;
                    border-radius: 5px;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                }
                .stat-number {
                    font-size: 24px;
                    font-weight: 700;
                    display: block;
                    margin-bottom: 5px;
                }
                .stat-label {
                    color: #7f8c8d;
                    font-size: 14px;
                }
                .chart-container {
                    margin: 30px 0;
                    height: 300px;
                }
                footer {
                    margin-top: 50px;
                    padding-top: 20px;
                    border-top: 1px solid #ddd;
                    color: #7f8c8d;
                    font-size: 14px;
                }
            </style>
        </head>
        <body>
            <h1>PhotoMigrator - Migration Report</h1>
            <p><strong>Generated:</strong> \(Date().formatted(date: .long, time: .standard))</p>
        """
        
        // Overall summary
        html += """
            <div class="stat-box">
                <h2>Overall Summary</h2>
                <div class="stat-grid">
                    <div class="stat-item">
                        <span class="stat-number">\(summary.totalItemsProcessed)</span>
                        <span class="stat-label">Total Items Processed</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-number">\(summary.successfulImports)</span>
                        <span class="stat-label">Successfully Imported</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-number">\(summary.failedImports)</span>
                        <span class="stat-label">Failed Imports</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-number">\(summary.albumsCreated)</span>
                        <span class="stat-label">Albums Created</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-number">\(summary.livePhotosReconstructed)</span>
                        <span class="stat-label">Live Photos Reconstructed</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-number">\(formatTime(summary.processingTime))</span>
                        <span class="stat-label">Total Processing Time</span>
                    </div>
                </div>
                
                <div class="success-rate \(getSuccessRateClass(summary.successRate))">
                    Success Rate: \(String(format: "%.1f%%", summary.successRate))
                </div>
            </div>
        """
        
        // Media Type Statistics
        html += """
            <div class="stat-box">
                <h2>Media Type Statistics</h2>
                <table>
                    <tr>
                        <th>Media Type</th>
                        <th>Count</th>
                        <th>Percentage</th>
                    </tr>
                    <tr>
                        <td>Photos</td>
                        <td>\(summary.mediaTypeStats.photos)</td>
                        <td>\(calculatePercentage(summary.mediaTypeStats.photos, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>Videos</td>
                        <td>\(summary.mediaTypeStats.videos)</td>
                        <td>\(calculatePercentage(summary.mediaTypeStats.videos, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>Live Photos</td>
                        <td>\(summary.mediaTypeStats.livePhotos)</td>
                        <td>\(calculatePercentage(summary.mediaTypeStats.livePhotos, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>Motion Photos</td>
                        <td>\(summary.mediaTypeStats.motionPhotos)</td>
                        <td>\(calculatePercentage(summary.mediaTypeStats.motionPhotos, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>Other Types</td>
                        <td>\(summary.mediaTypeStats.otherTypes)</td>
                        <td>\(calculatePercentage(summary.mediaTypeStats.otherTypes, summary.totalItemsProcessed))%</td>
                    </tr>
                </table>
            </div>
        """
        
        // File Format Statistics
        html += """
            <div class="stat-box">
                <h2>File Format Statistics</h2>
                <table>
                    <tr>
                        <th>File Format</th>
                        <th>Count</th>
                        <th>Percentage</th>
                    </tr>
                    <tr>
                        <td>JPEG</td>
                        <td>\(summary.fileFormatStats.jpeg)</td>
                        <td>\(calculatePercentage(summary.fileFormatStats.jpeg, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>HEIC</td>
                        <td>\(summary.fileFormatStats.heic)</td>
                        <td>\(calculatePercentage(summary.fileFormatStats.heic, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>PNG</td>
                        <td>\(summary.fileFormatStats.png)</td>
                        <td>\(calculatePercentage(summary.fileFormatStats.png, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>GIF</td>
                        <td>\(summary.fileFormatStats.gif)</td>
                        <td>\(calculatePercentage(summary.fileFormatStats.gif, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>MP4</td>
                        <td>\(summary.fileFormatStats.mp4)</td>
                        <td>\(calculatePercentage(summary.fileFormatStats.mp4, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>MOV</td>
                        <td>\(summary.fileFormatStats.mov)</td>
                        <td>\(calculatePercentage(summary.fileFormatStats.mov, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>Other Formats</td>
                        <td>\(summary.fileFormatStats.otherFormats)</td>
                        <td>\(calculatePercentage(summary.fileFormatStats.otherFormats, summary.totalItemsProcessed))%</td>
                    </tr>
                </table>
            </div>
        """
        
        // Metadata Statistics
        html += """
            <div class="stat-box">
                <h2>Metadata Preservation</h2>
                <table>
                    <tr>
                        <th>Metadata Type</th>
                        <th>Count</th>
                        <th>Percentage</th>
                    </tr>
                    <tr>
                        <td>With Creation Date</td>
                        <td>\(summary.metadataStats.withCreationDate)</td>
                        <td>\(calculatePercentage(summary.metadataStats.withCreationDate, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>With Location</td>
                        <td>\(summary.metadataStats.withLocation)</td>
                        <td>\(calculatePercentage(summary.metadataStats.withLocation, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>With Title</td>
                        <td>\(summary.metadataStats.withTitle)</td>
                        <td>\(calculatePercentage(summary.metadataStats.withTitle, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>With Description</td>
                        <td>\(summary.metadataStats.withDescription)</td>
                        <td>\(calculatePercentage(summary.metadataStats.withDescription, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>With People Tags</td>
                        <td>\(summary.metadataStats.withPeople)</td>
                        <td>\(calculatePercentage(summary.metadataStats.withPeople, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>Marked as Favorite</td>
                        <td>\(summary.metadataStats.withFavorite)</td>
                        <td>\(calculatePercentage(summary.metadataStats.withFavorite, summary.totalItemsProcessed))%</td>
                    </tr>
                    <tr>
                        <td>With Custom Metadata</td>
                        <td>\(summary.metadataStats.withCustomMetadata)</td>
                        <td>\(calculatePercentage(summary.metadataStats.withCustomMetadata, summary.totalItemsProcessed))%</td>
                    </tr>
                </table>
            </div>
        """
        
        // Album Statistics
        if !summary.albumsWithItems.isEmpty {
            html += """
                <div class="stat-box">
                    <h2>Album Statistics</h2>
                    <table>
                        <tr>
                            <th>Album Name</th>
                            <th>Items</th>
                        </tr>
            """
            
            for (album, count) in summary.albumsWithItems.sorted(by: { $0.value > $1.value }) {
                html += """
                        <tr>
                            <td>\(album)</td>
                            <td>\(count)</td>
                        </tr>
                """
            }
            
            html += """
                    </table>
                </div>
            """
        }
        
        // Issue Statistics
        if summary.issues.totalIssues > 0 {
            html += """
                <div class="stat-box">
                    <h2>Issues Encountered</h2>
                    <table>
                        <tr>
                            <th>Issue Type</th>
                            <th>Count</th>
                        </tr>
                        <tr>
                            <td>Metadata Parsing Errors</td>
                            <td>\(summary.issues.metadataParsingErrors)</td>
                        </tr>
                        <tr>
                            <td>File Access Errors</td>
                            <td>\(summary.issues.fileAccessErrors)</td>
                        </tr>
                        <tr>
                            <td>Import Errors</td>
                            <td>\(summary.issues.importErrors)</td>
                        </tr>
                        <tr>
                            <td>Album Creation Errors</td>
                            <td>\(summary.issues.albumCreationErrors)</td>
                        </tr>
                        <tr>
                            <td>Unsupported Media Types</td>
                            <td>\(summary.issues.mediaTypeUnsupported)</td>
                        </tr>
                        <tr>
                            <td>Unsupported Metadata</td>
                            <td>\(summary.issues.metadataUnsupported)</td>
                        </tr>
                        <tr>
                            <td>Memory Pressure Events</td>
                            <td>\(summary.issues.memoryPressureEvents)</td>
                        </tr>
                        <tr>
                            <td>File Corruption Issues</td>
                            <td>\(summary.issues.fileCorruptionIssues)</td>
                        </tr>
                    </table>
            """
            
            if !summary.issues.detailedErrors.isEmpty {
                html += """
                    <h3>Detailed Error Log</h3>
                    <table>
                        <tr>
                            <th>Time</th>
                            <th>Error Message</th>
                        </tr>
                """
                
                for (timestamp, message) in summary.issues.detailedErrors {
                    html += """
                        <tr>
                            <td>\(timestamp.formatted(date: .abbreviated, time: .standard))</td>
                            <td>\(message)</td>
                        </tr>
                    """
                }
                
                html += "</table>"
            }
            
            html += "</div>"
        }
        
        // Batch Processing Statistics
        if summary.batchProcessingUsed {
            html += """
                <div class="stat-box">
                    <h2>Batch Processing Statistics</h2>
                    <div class="stat-grid">
                        <div class="stat-item">
                            <span class="stat-number">\(summary.batchesProcessed)</span>
                            <span class="stat-label">Batches Processed</span>
                        </div>
                        <div class="stat-item">
                            <span class="stat-number">\(summary.batchSize)</span>
                            <span class="stat-label">Batch Size</span>
                        </div>
                        <div class="stat-item">
                            <span class="stat-number">\(formatMemorySize(summary.peakMemoryUsage))</span>
                            <span class="stat-label">Peak Memory Usage</span>
                        </div>
                        <div class="stat-item">
                            <span class="stat-number">\(String(format: "%.2f ms", summary.averageItemProcessingTime * 1000))</span>
                            <span class="stat-label">Avg. Processing Time Per Item</span>
                        </div>
                    </div>
                </div>
            """
        }
        
        // Timeline
        if let timeline = summary.timeline {
            html += """
                <div class="stat-box">
                    <h2>Processing Timeline</h2>
                    <table>
                        <tr>
                            <th>Stage</th>
                            <th>Start Time</th>
                            <th>End Time</th>
                            <th>Duration</th>
                        </tr>
                        <tr>
                            <td>Total Migration</td>
                            <td>\(timeline.startTime.formatted(date: .abbreviated, time: .standard))</td>
                            <td>\(timeline.endTime.formatted(date: .abbreviated, time: .standard))</td>
                            <td>\(formatTime(timeline.totalDuration))</td>
                        </tr>
            """
            
            if let startTime = timeline.extractionStartTime, let endTime = timeline.extractionEndTime {
                let duration = endTime.timeIntervalSince(startTime)
                html += """
                        <tr>
                            <td>Archive Extraction</td>
                            <td>\(startTime.formatted(date: .abbreviated, time: .standard))</td>
                            <td>\(endTime.formatted(date: .abbreviated, time: .standard))</td>
                            <td>\(formatTime(duration))</td>
                        </tr>
                """
            }
            
            if let startTime = timeline.metadataProcessingStartTime, let endTime = timeline.metadataProcessingEndTime {
                let duration = endTime.timeIntervalSince(startTime)
                html += """
                        <tr>
                            <td>Metadata Processing</td>
                            <td>\(startTime.formatted(date: .abbreviated, time: .standard))</td>
                            <td>\(endTime.formatted(date: .abbreviated, time: .standard))</td>
                            <td>\(formatTime(duration))</td>
                        </tr>
                """
            }
            
            if let startTime = timeline.importStartTime, let endTime = timeline.importEndTime {
                let duration = endTime.timeIntervalSince(startTime)
                html += """
                        <tr>
                            <td>Photo Import</td>
                            <td>\(startTime.formatted(date: .abbreviated, time: .standard))</td>
                            <td>\(endTime.formatted(date: .abbreviated, time: .standard))</td>
                            <td>\(formatTime(duration))</td>
                        </tr>
                """
            }
            
            if let startTime = timeline.albumCreationStartTime, let endTime = timeline.albumCreationEndTime {
                let duration = endTime.timeIntervalSince(startTime)
                html += """
                        <tr>
                            <td>Album Organization</td>
                            <td>\(startTime.formatted(date: .abbreviated, time: .standard))</td>
                            <td>\(endTime.formatted(date: .abbreviated, time: .standard))</td>
                            <td>\(formatTime(duration))</td>
                        </tr>
                """
            }
            
            html += """
                    </table>
                </div>
            """
        }
        
        // Footer
        html += """
            <footer>
                Generated by PhotoMigrator v1.1<br>
                © \(Calendar.current.component(.year, from: Date())) PhotoMigrator
            </footer>
        </body>
        </html>
        """
        
        return html
    }
    
    /// Generate CSV report for data analysis
    private func generateCSVReport(from summary: MigrationSummary) -> String {
        var csv = "PhotoMigrator Migration Report,Generated \(Date().formatted(date: .abbreviated, time: .standard))\n\n"
        
        // Basic stats
        csv += "Basic Statistics\n"
        csv += "Total Items Processed,\(summary.totalItemsProcessed)\n"
        csv += "Successfully Imported,\(summary.successfulImports)\n"
        csv += "Failed Imports,\(summary.failedImports)\n"
        csv += "Albums Created,\(summary.albumsCreated)\n"
        csv += "Live Photos Reconstructed,\(summary.livePhotosReconstructed)\n"
        csv += "Success Rate (%),\(String(format: "%.1f", summary.successRate))\n\n"
        
        // Media Types
        csv += "Media Types,Count,Percentage\n"
        csv += "Photos,\(summary.mediaTypeStats.photos),\(calculatePercentage(summary.mediaTypeStats.photos, summary.totalItemsProcessed))\n"
        csv += "Videos,\(summary.mediaTypeStats.videos),\(calculatePercentage(summary.mediaTypeStats.videos, summary.totalItemsProcessed))\n"
        csv += "Live Photos,\(summary.mediaTypeStats.livePhotos),\(calculatePercentage(summary.mediaTypeStats.livePhotos, summary.totalItemsProcessed))\n"
        csv += "Motion Photos,\(summary.mediaTypeStats.motionPhotos),\(calculatePercentage(summary.mediaTypeStats.motionPhotos, summary.totalItemsProcessed))\n"
        csv += "Other Types,\(summary.mediaTypeStats.otherTypes),\(calculatePercentage(summary.mediaTypeStats.otherTypes, summary.totalItemsProcessed))\n\n"
        
        // File Formats
        csv += "File Formats,Count,Percentage\n"
        csv += "JPEG,\(summary.fileFormatStats.jpeg),\(calculatePercentage(summary.fileFormatStats.jpeg, summary.totalItemsProcessed))\n"
        csv += "HEIC,\(summary.fileFormatStats.heic),\(calculatePercentage(summary.fileFormatStats.heic, summary.totalItemsProcessed))\n"
        csv += "PNG,\(summary.fileFormatStats.png),\(calculatePercentage(summary.fileFormatStats.png, summary.totalItemsProcessed))\n"
        csv += "GIF,\(summary.fileFormatStats.gif),\(calculatePercentage(summary.fileFormatStats.gif, summary.totalItemsProcessed))\n"
        csv += "MP4,\(summary.fileFormatStats.mp4),\(calculatePercentage(summary.fileFormatStats.mp4, summary.totalItemsProcessed))\n"
        csv += "MOV,\(summary.fileFormatStats.mov),\(calculatePercentage(summary.fileFormatStats.mov, summary.totalItemsProcessed))\n"
        csv += "Other Formats,\(summary.fileFormatStats.otherFormats),\(calculatePercentage(summary.fileFormatStats.otherFormats, summary.totalItemsProcessed))\n\n"
        
        // Metadata
        csv += "Metadata Preservation,Count,Percentage\n"
        csv += "With Location,\(summary.metadataStats.withLocation),\(calculatePercentage(summary.metadataStats.withLocation, summary.totalItemsProcessed))\n"
        csv += "With Title,\(summary.metadataStats.withTitle),\(calculatePercentage(summary.metadataStats.withTitle, summary.totalItemsProcessed))\n"
        csv += "With Description,\(summary.metadataStats.withDescription),\(calculatePercentage(summary.metadataStats.withDescription, summary.totalItemsProcessed))\n"
        csv += "With People Tags,\(summary.metadataStats.withPeople),\(calculatePercentage(summary.metadataStats.withPeople, summary.totalItemsProcessed))\n"
        csv += "Marked as Favorite,\(summary.metadataStats.withFavorite),\(calculatePercentage(summary.metadataStats.withFavorite, summary.totalItemsProcessed))\n"
        csv += "With Custom Metadata,\(summary.metadataStats.withCustomMetadata),\(calculatePercentage(summary.metadataStats.withCustomMetadata, summary.totalItemsProcessed))\n"
        csv += "With Creation Date,\(summary.metadataStats.withCreationDate),\(calculatePercentage(summary.metadataStats.withCreationDate, summary.totalItemsProcessed))\n\n"
        
        // Albums
        if !summary.albumsWithItems.isEmpty {
            csv += "Albums,Items\n"
            for (album, count) in summary.albumsWithItems.sorted(by: { $0.value > $1.value }) {
                csv += "\"\(album)\",\(count)\n"
            }
            csv += "\n"
        }
        
        // Issues
        csv += "Issues,Count\n"
        csv += "Metadata Parsing Errors,\(summary.issues.metadataParsingErrors)\n"
        csv += "File Access Errors,\(summary.issues.fileAccessErrors)\n"
        csv += "Import Errors,\(summary.issues.importErrors)\n"
        csv += "Album Creation Errors,\(summary.issues.albumCreationErrors)\n"
        csv += "Unsupported Media Types,\(summary.issues.mediaTypeUnsupported)\n"
        csv += "Unsupported Metadata,\(summary.issues.metadataUnsupported)\n"
        csv += "Memory Pressure Events,\(summary.issues.memoryPressureEvents)\n"
        csv += "File Corruption Issues,\(summary.issues.fileCorruptionIssues)\n\n"
        
        // Timeline
        if let timeline = summary.timeline {
            csv += "Stage,Start Time,End Time,Duration (seconds)\n"
            csv += "Total Migration,\(formatDateForCSV(timeline.startTime)),\(formatDateForCSV(timeline.endTime)),\(timeline.totalDuration)\n"
            
            if let startTime = timeline.extractionStartTime, let endTime = timeline.extractionEndTime {
                let duration = endTime.timeIntervalSince(startTime)
                csv += "Archive Extraction,\(formatDateForCSV(startTime)),\(formatDateForCSV(endTime)),\(duration)\n"
            }
            
            if let startTime = timeline.metadataProcessingStartTime, let endTime = timeline.metadataProcessingEndTime {
                let duration = endTime.timeIntervalSince(startTime)
                csv += "Metadata Processing,\(formatDateForCSV(startTime)),\(formatDateForCSV(endTime)),\(duration)\n"
            }
            
            if let startTime = timeline.importStartTime, let endTime = timeline.importEndTime {
                let duration = endTime.timeIntervalSince(startTime)
                csv += "Photo Import,\(formatDateForCSV(startTime)),\(formatDateForCSV(endTime)),\(duration)\n"
            }
            
            if let startTime = timeline.albumCreationStartTime, let endTime = timeline.albumCreationEndTime {
                let duration = endTime.timeIntervalSince(startTime)
                csv += "Album Organization,\(formatDateForCSV(startTime)),\(formatDateForCSV(endTime)),\(duration)\n"
            }
            
            csv += "\n"
        }
        
        // Batch Processing
        if summary.batchProcessingUsed {
            csv += "Batch Processing Statistics,Value\n"
            csv += "Batches Processed,\(summary.batchesProcessed)\n"
            csv += "Batch Size,\(summary.batchSize)\n"
            csv += "Peak Memory Usage (bytes),\(summary.peakMemoryUsage)\n"
            csv += "Processing Time (seconds),\(summary.processingTime)\n"
            csv += "Average Processing Time Per Item (seconds),\(summary.averageItemProcessingTime)\n"
        }
        
        return csv
    }
    
    // Helper function to format dates for CSV output
    private func formatDateForCSV(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // Helper function to calculate percentage
    private func calculatePercentage(_ value: Int, _ total: Int) -> String {
        guard total > 0 else { return "0.0" }
        return String(format: "%.1f", (Double(value) / Double(total)) * 100)
    }
    
    // Helper function to determine success rate CSS class
    private func getSuccessRateClass(_ rate: Double) -> String {
        if rate >= 90 {
            return "success-high"
        } else if rate >= 75 {
            return "success-medium"
        } else {
            return "success-low"
        }
    }
    
    // Helper function to format time intervals
    private func formatTime(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "0s"
    }
    
    // Helper function to format memory size
    private func formatMemorySize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}