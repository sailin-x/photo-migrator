import Foundation
import SwiftUI
import Charts

/// Service to generate charts based on migration statistics
class ChartGenerator {
    /// Generate a media type distribution chart
    /// - Parameter summary: Migration summary data
    /// - Returns: Image of the chart
    @available(macOS 13.0, *)
    func generateMediaTypeChart(from summary: MigrationSummary) -> some View {
        let data: [(type: String, count: Int)] = [
            ("Photos", summary.mediaTypeStats.photos),
            ("Videos", summary.mediaTypeStats.videos),
            ("Live Photos", summary.mediaTypeStats.livePhotos),
            ("Motion Photos", summary.mediaTypeStats.motionPhotos),
            ("Other", summary.mediaTypeStats.otherTypes)
        ].filter { $0.count > 0 }
        
        return Chart(data, id: \.type) { item in
            SectorMark(
                angle: .value("Count", item.count),
                innerRadius: .ratio(0.2),
                angularInset: 1
            )
            .cornerRadius(5)
            .foregroundStyle(by: .value("Type", item.type))
            
            BarMark(
                x: .value("Type", item.type),
                y: .value("Count", item.count)
            )
            .foregroundStyle(by: .value("Type", item.type))
        }
        .chartTitle("Media Type Distribution")
        .frame(height: 300)
        .padding()
    }
    
    /// Generate a file format distribution chart
    /// - Parameter summary: Migration summary data
    /// - Returns: Image of the chart
    @available(macOS 13.0, *)
    func generateFileFormatChart(from summary: MigrationSummary) -> some View {
        let data: [(format: String, count: Int)] = [
            ("JPEG", summary.fileFormatStats.jpeg),
            ("HEIC", summary.fileFormatStats.heic),
            ("PNG", summary.fileFormatStats.png),
            ("GIF", summary.fileFormatStats.gif),
            ("MP4", summary.fileFormatStats.mp4),
            ("MOV", summary.fileFormatStats.mov),
            ("Other", summary.fileFormatStats.otherFormats)
        ].filter { $0.count > 0 }
        
        return Chart(data, id: \.format) { item in
            BarMark(
                x: .value("Count", item.count),
                y: .value("Format", item.format)
            )
            .foregroundStyle(by: .value("Format", item.format))
        }
        .chartTitle("File Format Distribution")
        .frame(height: 300)
        .padding()
    }
    
    /// Generate a metadata preservation chart
    /// - Parameter summary: Migration summary data
    /// - Returns: Image of the chart
    @available(macOS 13.0, *)
    func generateMetadataChart(from summary: MigrationSummary) -> some View {
        let data: [(type: String, count: Int, percentage: Double)] = [
            ("Creation Date", 
             summary.metadataStats.withCreationDate,
             calculatePercentage(summary.metadataStats.withCreationDate, summary.totalItemsProcessed)),
            ("Location", 
             summary.metadataStats.withLocation,
             calculatePercentage(summary.metadataStats.withLocation, summary.totalItemsProcessed)),
            ("Title", 
             summary.metadataStats.withTitle,
             calculatePercentage(summary.metadataStats.withTitle, summary.totalItemsProcessed)),
            ("Description", 
             summary.metadataStats.withDescription,
             calculatePercentage(summary.metadataStats.withDescription, summary.totalItemsProcessed)),
            ("People Tags", 
             summary.metadataStats.withPeople,
             calculatePercentage(summary.metadataStats.withPeople, summary.totalItemsProcessed)),
            ("Favorites", 
             summary.metadataStats.withFavorite,
             calculatePercentage(summary.metadataStats.withFavorite, summary.totalItemsProcessed))
        ]
        
        return Chart(data, id: \.type) { item in
            BarMark(
                x: .value("Type", item.type),
                y: .value("Percentage", item.percentage)
            )
            .foregroundStyle(by: .value("Type", item.type))
            
            // Show the actual numbers at the top of each bar
            RuleMark(
                x: .value("Type", item.type),
                y: .value("Value", item.percentage)
            )
            .annotation(position: .top) {
                Text("\(item.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisValueLabel(format: .percent)
            }
        }
        .chartXAxis {
            AxisMarks {
                AxisValueLabel()
                    .font(.caption)
            }
        }
        .chartTitle("Metadata Preservation")
        .frame(height: 300)
        .padding()
    }
    
    /// Generate a timeline chart showing processing durations
    /// - Parameter summary: Migration summary data
    /// - Returns: Image of the chart
    @available(macOS 13.0, *)
    func generateTimelineChart(from summary: MigrationSummary) -> some View {
        guard let timeline = summary.timeline else {
            return AnyView(Text("Timeline data not available").foregroundColor(.secondary))
        }
        
        var timelineData: [(stage: String, duration: TimeInterval)] = []
        
        if let startTime = timeline.extractionStartTime, let endTime = timeline.extractionEndTime {
            timelineData.append(("Extraction", endTime.timeIntervalSince(startTime)))
        }
        
        if let startTime = timeline.metadataProcessingStartTime, let endTime = timeline.metadataProcessingEndTime {
            timelineData.append(("Metadata", endTime.timeIntervalSince(startTime)))
        }
        
        if let startTime = timeline.importStartTime, let endTime = timeline.importEndTime {
            timelineData.append(("Import", endTime.timeIntervalSince(startTime)))
        }
        
        if let startTime = timeline.albumCreationStartTime, let endTime = timeline.albumCreationEndTime {
            timelineData.append(("Albums", endTime.timeIntervalSince(startTime)))
        }
        
        return Chart(timelineData, id: \.stage) { item in
            BarMark(
                x: .value("Stage", item.stage),
                y: .value("Duration", item.duration)
            )
            .foregroundStyle(by: .value("Stage", item.stage))
            
            // Annotate the bars with formatted time
            RuleMark(
                x: .value("Stage", item.stage),
                y: .value("Duration", item.duration)
            )
            .annotation(position: .top) {
                Text(formatTime(item.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .chartTitle("Processing Time by Stage (seconds)")
        .frame(height: 300)
        .padding()
    }
    
    /// Generate an issues summary chart
    /// - Parameter summary: Migration summary data
    /// - Returns: Image of the chart
    @available(macOS 13.0, *)
    func generateIssuesChart(from summary: MigrationSummary) -> some View {
        if summary.issues.totalIssues == 0 {
            return AnyView(
                Text("No issues encountered during migration")
                    .foregroundColor(.green)
                    .padding()
            )
        }
        
        let data: [(type: String, count: Int)] = [
            ("Metadata Parsing", summary.issues.metadataParsingErrors),
            ("File Access", summary.issues.fileAccessErrors),
            ("Import", summary.issues.importErrors),
            ("Album Creation", summary.issues.albumCreationErrors),
            ("Unsupported Media", summary.issues.mediaTypeUnsupported),
            ("Unsupported Metadata", summary.issues.metadataUnsupported),
            ("Memory Pressure", summary.issues.memoryPressureEvents),
            ("File Corruption", summary.issues.fileCorruptionIssues)
        ].filter { $0.count > 0 }
        
        return Chart(data, id: \.type) { item in
            BarMark(
                x: .value("Issue Type", item.type),
                y: .value("Count", item.count)
            )
            .foregroundStyle(by: .value("Issue Type", item.type))
        }
        .chartTitle("Issues Encountered")
        .frame(height: 300)
        .padding()
    }
    
    /// Generate a success rate gauge chart
    /// - Parameter summary: Migration summary data
    /// - Returns: Image of the chart
    @available(macOS 13.0, *)
    func generateSuccessGaugeChart(from summary: MigrationSummary) -> some View {
        let successRate = summary.successRate
        
        return Gauge(value: successRate, in: 0...100) {
            Text("Success Rate")
        } currentValueLabel: {
            Text("\(Int(successRate))%")
        } minimumValueLabel: {
            Text("0%")
        } maximumValueLabel: {
            Text("100%")
        }
        .gaugeStyle(.accessoryCircular)
        .tint(getSuccessRateGradient(successRate))
        .frame(width: 150, height: 150)
        .padding()
    }
    
    // Helper functions
    
    private func calculatePercentage(_ value: Int, _ total: Int) -> Double {
        guard total > 0 else { return 0 }
        return (Double(value) / Double(total)) * 100
    }
    
    private func getSuccessRateGradient(_ rate: Double) -> Gradient {
        if rate >= 90 {
            return Gradient(colors: [.green, .green.opacity(0.8)])
        } else if rate >= 75 {
            return Gradient(colors: [.yellow, .green.opacity(0.6)])
        } else {
            return Gradient(colors: [.red, .orange])
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "0s"
    }
}