import SwiftUI
import Charts
import UniformTypeIdentifiers

/// View displaying detailed statistics on a completed migration
struct DetailedStatisticsView: View {
    let summary: MigrationSummary
    @State private var selectedTab = 0
    @State private var showingExportSuccess = false
    @State private var exportPath: URL?
    
    // Create a report generator instance
    private let reportGenerator = ReportGenerator()
    
    // Tab titles
    private let tabs = [
        "Overview", 
        "Media Types", 
        "File Formats", 
        "Metadata", 
        "Albums", 
        "Timeline", 
        "Issues"
    ]
    
    var body: some View {
        VStack(spacing: 15) {
            // Header with success rate
            VStack(spacing: 10) {
                Text("Migration Statistics")
                    .font(.title)
                    .bold()
                
                Text("Success Rate: \(String(format: "%.1f%%", summary.successRate))")
                    .font(.title2)
                    .foregroundColor(getSuccessRateColor(summary.successRate))
                    .padding(.bottom, 5)
                
                // Stats summary
                HStack(spacing: 20) {
                    VStack {
                        Text("\(summary.totalItemsProcessed)")
                            .font(.title3)
                            .bold()
                        Text("Total Items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 80)
                    
                    VStack {
                        Text("\(summary.successfulImports)")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.green)
                        Text("Successful")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 80)
                    
                    VStack {
                        Text("\(summary.failedImports)")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.red)
                        Text("Failed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 80)
                    
                    VStack {
                        Text("\(summary.albumsCreated)")
                            .font(.title3)
                            .bold()
                        Text("Albums")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 80)
                }
                .padding(.vertical, 5)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Tab selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(0..<tabs.count, id: \.self) { index in
                        Button(action: {
                            withAnimation {
                                selectedTab = index
                            }
                        }) {
                            Text(tabs[index])
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(selectedTab == index ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedTab == index ? .white : .primary)
                                .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
            
            // Tab content
            TabView(selection: $selectedTab) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Group {
                        switch index {
                        case 0:
                            overviewTab
                        case 1:
                            mediaTypesTab
                        case 2:
                            fileFormatsTab
                        case 3:
                            metadataTab
                        case 4:
                            albumsTab
                        case 5:
                            timelineTab
                        case 6:
                            issuesTab
                        default:
                            Text("Tab not implemented")
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)
            
            // Action buttons
            HStack {
                Button(action: {
                    // Generate and save a detailed report
                    if let reportPath = reportGenerator.generateReport(from: summary) {
                        exportPath = reportPath
                        showingExportSuccess = true
                    }
                }) {
                    Label("Export Report", systemImage: "square.and.arrow.up")
                        .padding(.vertical, 10)
                        .padding(.horizontal, 15)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                if let logPath = summary.logPath {
                    Button(action: {
                        NSWorkspace.shared.open(logPath)
                    }) {
                        Label("View Log", systemImage: "doc.text")
                            .padding(.vertical, 10)
                            .padding(.horizontal, 15)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.vertical)
        }
        .padding()
        .frame(minWidth: 700, minHeight: 600)
        .alert("Report Generated", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) { }
            if let path = exportPath {
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(path.path, inFileViewerRootedAtPath: path.deletingLastPathComponent().path)
                }
            }
        } message: {
            if let path = exportPath {
                Text("Report has been saved to:\n\(path.path)")
            } else {
                Text("Report has been generated successfully.")
            }
        }
    }
    
    // MARK: - Tab Content
    
    /// Overview tab showing general statistics
    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary statistics
                summaryCard
                
                // Success rate gauge (macOS 13+ only)
                if #available(macOS 13.0, *) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Success Rate")
                            .font(.headline)
                        
                        HStack {
                            Spacer()
                            ChartGenerator().generateSuccessGaugeChart(from: summary)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Batch processing statistics
                if summary.batchProcessingUsed {
                    batchProcessingCard
                }
                
                // Time statistics 
                timeStatisticsCard
                
                // Processing speed card
                processingSpeedCard
            }
            .padding()
        }
    }
    
    /// Media types tab showing distribution of media types
    private var mediaTypesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Media Types Distribution")
                    .font(.headline)
                
                // Media type chart (macOS 13+ only)
                if #available(macOS 13.0, *) {
                    ChartGenerator().generateMediaTypeChart(from: summary)
                        .frame(height: 300)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                
                // Media type statistics table
                VStack(alignment: .leading, spacing: 10) {
                    Text("Media Types Details")
                        .font(.headline)
                    
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("Type")
                                .fontWeight(.medium)
                                .frame(width: 150, alignment: .leading)
                            Spacer()
                            Text("Count")
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .trailing)
                            Text("Percentage")
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                        .background(Color.gray.opacity(0.2))
                        
                        // Rows
                        Group {
                            mediaTypeRow("Photos", summary.mediaTypeStats.photos, summary.totalItemsProcessed)
                            mediaTypeRow("Videos", summary.mediaTypeStats.videos, summary.totalItemsProcessed)
                            mediaTypeRow("Live Photos", summary.mediaTypeStats.livePhotos, summary.totalItemsProcessed)
                            mediaTypeRow("Motion Photos", summary.mediaTypeStats.motionPhotos, summary.totalItemsProcessed)
                            mediaTypeRow("Other Types", summary.mediaTypeStats.otherTypes, summary.totalItemsProcessed)
                        }
                        
                        // Total
                        HStack {
                            Text("Total")
                                .fontWeight(.bold)
                                .frame(width: 150, alignment: .leading)
                            Spacer()
                            Text("\(summary.totalItemsProcessed)")
                                .fontWeight(.bold)
                                .frame(width: 80, alignment: .trailing)
                            Text("100%")
                                .fontWeight(.bold)
                                .frame(width: 100, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                        .background(Color.gray.opacity(0.1))
                    }
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            .padding()
        }
    }
    
    /// File formats tab showing distribution of file formats
    private var fileFormatsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("File Format Distribution")
                    .font(.headline)
                
                // File format chart (macOS 13+ only)
                if #available(macOS 13.0, *) {
                    ChartGenerator().generateFileFormatChart(from: summary)
                        .frame(height: 350)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                
                // File format statistics table
                VStack(alignment: .leading, spacing: 10) {
                    Text("File Format Details")
                        .font(.headline)
                    
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("Format")
                                .fontWeight(.medium)
                                .frame(width: 150, alignment: .leading)
                            Spacer()
                            Text("Count")
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .trailing)
                            Text("Percentage")
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                        .background(Color.gray.opacity(0.2))
                        
                        // Rows
                        Group {
                            mediaTypeRow("JPEG", summary.fileFormatStats.jpeg, summary.totalItemsProcessed)
                            mediaTypeRow("HEIC", summary.fileFormatStats.heic, summary.totalItemsProcessed)
                            mediaTypeRow("PNG", summary.fileFormatStats.png, summary.totalItemsProcessed)
                            mediaTypeRow("GIF", summary.fileFormatStats.gif, summary.totalItemsProcessed)
                            mediaTypeRow("MP4", summary.fileFormatStats.mp4, summary.totalItemsProcessed)
                            mediaTypeRow("MOV", summary.fileFormatStats.mov, summary.totalItemsProcessed)
                            mediaTypeRow("Other Formats", summary.fileFormatStats.otherFormats, summary.totalItemsProcessed)
                        }
                        
                        // Total
                        HStack {
                            Text("Total")
                                .fontWeight(.bold)
                                .frame(width: 150, alignment: .leading)
                            Spacer()
                            Text("\(summary.totalItemsProcessed)")
                                .fontWeight(.bold)
                                .frame(width: 80, alignment: .trailing)
                            Text("100%")
                                .fontWeight(.bold)
                                .frame(width: 100, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                        .background(Color.gray.opacity(0.1))
                    }
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            .padding()
        }
    }
    
    /// Metadata tab showing information about metadata preservation
    private var metadataTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Metadata Preservation")
                    .font(.headline)
                
                // Metadata chart (macOS 13+ only)
                if #available(macOS 13.0, *) {
                    ChartGenerator().generateMetadataChart(from: summary)
                        .frame(height: 300)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                
                // Metadata statistics table
                VStack(alignment: .leading, spacing: 10) {
                    Text("Metadata Details")
                        .font(.headline)
                    
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("Metadata Type")
                                .fontWeight(.medium)
                                .frame(width: 150, alignment: .leading)
                            Spacer()
                            Text("Count")
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .trailing)
                            Text("Percentage")
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                        .background(Color.gray.opacity(0.2))
                        
                        // Rows
                        Group {
                            mediaTypeRow("Creation Date", summary.metadataStats.withCreationDate, summary.totalItemsProcessed)
                            mediaTypeRow("Location", summary.metadataStats.withLocation, summary.totalItemsProcessed)
                            mediaTypeRow("Title", summary.metadataStats.withTitle, summary.totalItemsProcessed)
                            mediaTypeRow("Description", summary.metadataStats.withDescription, summary.totalItemsProcessed)
                            mediaTypeRow("People Tags", summary.metadataStats.withPeople, summary.totalItemsProcessed)
                            mediaTypeRow("Favorites", summary.metadataStats.withFavorite, summary.totalItemsProcessed)
                            mediaTypeRow("Custom Metadata", summary.metadataStats.withCustomMetadata, summary.totalItemsProcessed)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Metadata tips
                VStack(alignment: .leading, spacing: 10) {
                    Text("Metadata Notes")
                        .font(.headline)
                    
                    Text("• Location data was preserved for \(calculatePercentageText(summary.metadataStats.withLocation, summary.totalItemsProcessed)) of your photos")
                    
                    Text("• Your favorites status was maintained for \(calculatePercentageText(summary.metadataStats.withFavorite, summary.totalItemsProcessed)) of your photos")
                    
                    Text("• Creation dates were preserved for \(calculatePercentageText(summary.metadataStats.withCreationDate, summary.totalItemsProcessed)) of your photos")
                    
                    if summary.metadataStats.withPeople > 0 {
                        Text("• People tags were migrated for \(summary.metadataStats.withPeople) photos")
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .padding()
        }
    }
    
    /// Albums tab showing information about albums created
    private var albumsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Albums Created")
                            .font(.headline)
                        Text("\(summary.albumsCreated) albums were created during migration")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("\(summary.albumsWithItems.values.reduce(0, +))")
                            .font(.title3)
                            .bold()
                        Text("Total photos in albums")
                            .foregroundColor(.secondary)
                    }
                }
                
                if summary.albumsWithItems.isEmpty {
                    Text("No album information available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else {
                    // Albums list
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack {
                            Text("Album Name")
                                .fontWeight(.medium)
                                .frame(minWidth: 200, alignment: .leading)
                            Spacer()
                            Text("Items")
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                        .background(Color.gray.opacity(0.2))
                        
                        // Album rows
                        ForEach(summary.albumsWithItems.sorted(by: { $0.value > $1.value }), id: \.key) { albumName, count in
                            HStack {
                                Text(albumName)
                                    .frame(minWidth: 200, alignment: .leading)
                                Spacer()
                                Text("\(count)")
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal)
                            .background(
                                Color.white.opacity(0.5)
                            )
                            Divider()
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    
                    // Albums visualization (if many albums)
                    if summary.albumsWithItems.count > 5 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Albums Distribution")
                                .font(.headline)
                            
                            // Show top albums visualization
                            let topAlbums = summary.albumsWithItems.sorted(by: { $0.value > $1.value }).prefix(10)
                            
                            ForEach(Array(topAlbums.enumerated()), id: \.element.key) { index, album in
                                HStack {
                                    Text(album.key)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(width: 150, alignment: .leading)
                                    
                                    GeometryReader { geometry in
                                        let maxCount = topAlbums.first?.value ?? 1
                                        let width = CGFloat(album.value) / CGFloat(maxCount) * geometry.size.width
                                        
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .foregroundColor(Color.gray.opacity(0.3))
                                                .frame(width: geometry.size.width, height: 20)
                                                .cornerRadius(4)
                                            
                                            Rectangle()
                                                .foregroundColor(Color.blue.opacity(0.7))
                                                .frame(width: width, height: 20)
                                                .cornerRadius(4)
                                        }
                                    }
                                    .frame(height: 20)
                                    
                                    Text("\(album.value)")
                                        .frame(width: 50, alignment: .trailing)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
    }
    
    /// Timeline tab showing processing times
    private var timelineTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Processing Timeline")
                    .font(.headline)
                
                if let timeline = summary.timeline {
                    // Timeline chart (macOS 13+ only)
                    if #available(macOS 13.0, *) {
                        ChartGenerator().generateTimelineChart(from: summary)
                            .frame(height: 300)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    // Timeline table
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Timeline Details")
                            .font(.headline)
                        
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                                Text("Stage")
                                    .fontWeight(.medium)
                                    .frame(minWidth: 150, alignment: .leading)
                                Text("Start Time")
                                    .fontWeight(.medium)
                                    .frame(minWidth: 160, alignment: .center)
                                Text("End Time")
                                    .fontWeight(.medium)
                                    .frame(minWidth: 160, alignment: .center)
                                Spacer()
                                Text("Duration")
                                    .fontWeight(.medium)
                                    .frame(width: 100, alignment: .trailing)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal)
                            .background(Color.gray.opacity(0.2))
                            
                            // Overall row
                            timelineRow(
                                "Total Migration",
                                timeline.startTime,
                                timeline.endTime,
                                timeline.endTime.timeIntervalSince(timeline.startTime)
                            )
                            
                            // Extraction row
                            if let startTime = timeline.extractionStartTime, let endTime = timeline.extractionEndTime {
                                timelineRow(
                                    "Archive Extraction",
                                    startTime,
                                    endTime,
                                    endTime.timeIntervalSince(startTime)
                                )
                            }
                            
                            // Metadata row
                            if let startTime = timeline.metadataProcessingStartTime, let endTime = timeline.metadataProcessingEndTime {
                                timelineRow(
                                    "Metadata Processing",
                                    startTime,
                                    endTime,
                                    endTime.timeIntervalSince(startTime)
                                )
                            }
                            
                            // Import row
                            if let startTime = timeline.importStartTime, let endTime = timeline.importEndTime {
                                timelineRow(
                                    "Photo Import",
                                    startTime,
                                    endTime,
                                    endTime.timeIntervalSince(startTime)
                                )
                            }
                            
                            // Albums row
                            if let startTime = timeline.albumCreationStartTime, let endTime = timeline.albumCreationEndTime {
                                timelineRow(
                                    "Album Organization",
                                    startTime,
                                    endTime,
                                    endTime.timeIntervalSince(startTime)
                                )
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // Timeline events
                    if !timeline.events.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Notable Events")
                                .font(.headline)
                            
                            VStack(spacing: 0) {
                                // Header
                                HStack {
                                    Text("Time")
                                        .fontWeight(.medium)
                                        .frame(width: 160, alignment: .leading)
                                    Spacer()
                                    Text("Event")
                                        .fontWeight(.medium)
                                        .frame(alignment: .leading)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                                .background(Color.gray.opacity(0.2))
                                
                                // Event rows
                                ForEach(timeline.events.sorted(by: { $0.timestamp < $1.timestamp }), id: \.timestamp) { event in
                                    HStack {
                                        Text(event.timestamp.formatted(date: .abbreviated, time: .standard))
                                            .frame(width: 160, alignment: .leading)
                                        Spacer()
                                        Text(event.event)
                                            .frame(alignment: .leading)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal)
                                    .background(
                                        Color.white.opacity(0.5)
                                    )
                                    Divider()
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                } else {
                    Text("No timeline information available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                }
            }
            .padding()
        }
    }
    
    /// Issues tab showing errors and issues encountered
    private var issuesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Issues Encountered")
                            .font(.headline)
                        
                        if summary.issues.totalIssues == 0 {
                            Text("No issues were encountered during migration")
                                .foregroundColor(.green)
                        } else {
                            Text("\(summary.issues.totalIssues) issues were encountered during migration")
                                .foregroundColor(summary.issues.totalIssues > 10 ? .red : .orange)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("\(summary.failedImports)")
                            .font(.title3)
                            .bold()
                            .foregroundColor(summary.failedImports > 0 ? .red : .primary)
                        Text("Failed Imports")
                            .foregroundColor(.secondary)
                    }
                }
                
                if summary.issues.totalIssues == 0 {
                    VStack {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                            .padding()
                        
                        Text("Migration completed without any issues!")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Issues chart (macOS 13+ only)
                    if #available(macOS 13.0, *) {
                        ChartGenerator().generateIssuesChart(from: summary)
                            .frame(height: 300)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    // Issues summary
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Issues Summary")
                            .font(.headline)
                        
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                                Text("Issue Type")
                                    .fontWeight(.medium)
                                    .frame(minWidth: 200, alignment: .leading)
                                Spacer()
                                Text("Count")
                                    .fontWeight(.medium)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal)
                            .background(Color.gray.opacity(0.2))
                            
                            // Issue rows
                            issueRow("Metadata Parsing Errors", summary.issues.metadataParsingErrors)
                            issueRow("File Access Errors", summary.issues.fileAccessErrors)
                            issueRow("Import Errors", summary.issues.importErrors)
                            issueRow("Album Creation Errors", summary.issues.albumCreationErrors)
                            issueRow("Unsupported Media Types", summary.issues.mediaTypeUnsupported)
                            issueRow("Unsupported Metadata", summary.issues.metadataUnsupported)
                            issueRow("Memory Pressure Events", summary.issues.memoryPressureEvents)
                            issueRow("File Corruption Issues", summary.issues.fileCorruptionIssues)
                            
                            // Total row
                            HStack {
                                Text("Total Issues")
                                    .fontWeight(.bold)
                                    .frame(minWidth: 200, alignment: .leading)
                                Spacer()
                                Text("\(summary.issues.totalIssues)")
                                    .fontWeight(.bold)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal)
                            .background(Color.gray.opacity(0.1))
                        }
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // Detailed error log
                    if !summary.issues.detailedErrors.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Detailed Error Log")
                                .font(.headline)
                            
                            VStack(spacing: 0) {
                                // Header
                                HStack {
                                    Text("Time")
                                        .fontWeight(.medium)
                                        .frame(width: 160, alignment: .leading)
                                    Spacer()
                                    Text("Error Message")
                                        .fontWeight(.medium)
                                        .frame(alignment: .leading)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                                .background(Color.gray.opacity(0.2))
                                
                                // Error rows
                                ScrollView {
                                    ForEach(summary.issues.detailedErrors.sorted(by: { $0.timestamp < $1.timestamp }), id: \.timestamp) { error in
                                        HStack(alignment: .top) {
                                            Text(error.timestamp.formatted(date: .abbreviated, time: .standard))
                                                .frame(width: 160, alignment: .leading)
                                            Spacer()
                                            Text(error.message)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal)
                                        .background(
                                            Color.white.opacity(0.5)
                                        )
                                        Divider()
                                    }
                                }
                                .frame(height: 200)
                            }
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Reusable Components
    
    /// Card displaying summary statistics
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Summary Statistics")
                .font(.headline)
            
            HStack(spacing: 20) {
                statBox(value: "\(summary.totalItemsProcessed)", label: "Total Items")
                statBox(value: "\(summary.successfulImports)", label: "Successful", color: .green)
                statBox(value: "\(summary.failedImports)", label: "Failed", color: summary.failedImports > 0 ? .red : .primary)
                statBox(value: "\(summary.albumsCreated)", label: "Albums")
            }
            
            HStack(spacing: 20) {
                statBox(value: "\(summary.livePhotosReconstructed)", label: "Live Photos")
                statBox(value: "\(summary.mediaTypeStats.photos)", label: "Photos")
                statBox(value: "\(summary.mediaTypeStats.videos)", label: "Videos")
                statBox(value: "\(summary.issues.totalIssues)", label: "Issues", color: summary.issues.totalIssues > 0 ? .orange : .green)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    /// Card displaying batch processing statistics
    private var batchProcessingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Batch Processing")
                .font(.headline)
            
            HStack(spacing: 20) {
                statBox(value: "\(summary.batchesProcessed)", label: "Batches")
                statBox(value: "\(summary.batchSize)", label: "Batch Size")
                statBox(value: formatMemorySize(summary.peakMemoryUsage), label: "Peak Memory")
                statBox(value: formatTimeShort(summary.processingTime), label: "Processing Time")
            }
            
            HStack {
                if summary.issues.memoryPressureEvents > 0 {
                    Label("\(summary.issues.memoryPressureEvents) memory pressure events detected", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                } else {
                    Label("No memory pressure events", systemImage: "checkmark.circle")
                        .foregroundColor(.green)
                }
            }
            .font(.subheadline)
            .padding(.top, 5)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    /// Card displaying time statistics
    private var timeStatisticsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Time Statistics")
                .font(.headline)
            
            if let timeline = summary.timeline {
                HStack(spacing: 20) {
                    statBox(value: formatTime(timeline.totalDuration), label: "Total Time")
                    
                    if let startTime = timeline.extractionStartTime, let endTime = timeline.extractionEndTime {
                        statBox(value: formatTime(endTime.timeIntervalSince(startTime)), label: "Extraction")
                    }
                    
                    if let startTime = timeline.metadataProcessingStartTime, let endTime = timeline.metadataProcessingEndTime {
                        statBox(value: formatTime(endTime.timeIntervalSince(startTime)), label: "Metadata")
                    }
                    
                    if let startTime = timeline.importStartTime, let endTime = timeline.importEndTime {
                        statBox(value: formatTime(endTime.timeIntervalSince(startTime)), label: "Import")
                    }
                }
            } else {
                HStack(spacing: 20) {
                    statBox(value: formatTime(summary.processingTime), label: "Total Time")
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    /// Card displaying processing speed statistics
    private var processingSpeedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Processing Performance")
                .font(.headline)
            
            HStack(spacing: 20) {
                let itemsPerSecond = summary.processingTime > 0 ? Double(summary.totalItemsProcessed) / summary.processingTime : 0
                statBox(value: String(format: "%.1f items/sec", itemsPerSecond), label: "Processing Rate")
                
                statBox(value: String(format: "%.2f ms", summary.averageItemProcessingTime * 1000), label: "Per Item")
                
                if summary.batchProcessingUsed {
                    let batchesPerMinute = summary.processingTime > 0 ? Double(summary.batchesProcessed) / (summary.processingTime / 60) : 0
                    statBox(value: String(format: "%.1f batches/min", batchesPerMinute), label: "Batch Rate")
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Helper Views
    
    /// Creates a media type row in a table
    private func mediaTypeRow(_ type: String, _ count: Int, _ total: Int) -> some View {
        HStack {
            Text(type)
                .frame(width: 150, alignment: .leading)
            Spacer()
            Text("\(count)")
                .frame(width: 80, alignment: .trailing)
            Text("\(calculatePercentageText(count, total))%")
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .background(
            Color.white.opacity(0.5)
        )
    }
    
    /// Creates a timeline row in a table
    private func timelineRow(_ stage: String, _ startTime: Date, _ endTime: Date, _ duration: TimeInterval) -> some View {
        HStack {
            Text(stage)
                .frame(minWidth: 150, alignment: .leading)
            Text(startTime.formatted(date: .abbreviated, time: .standard))
                .frame(minWidth: 160, alignment: .center)
            Text(endTime.formatted(date: .abbreviated, time: .standard))
                .frame(minWidth: 160, alignment: .center)
            Spacer()
            Text(formatTime(duration))
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .background(
            Color.white.opacity(0.5)
        )
    }
    
    /// Creates an issue row in a table
    private func issueRow(_ type: String, _ count: Int) -> some View {
        HStack {
            Text(type)
                .frame(minWidth: 200, alignment: .leading)
            Spacer()
            Text("\(count)")
                .foregroundColor(count > 0 ? .red : .primary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .background(
            Color.white.opacity(0.5)
        )
    }
    
    /// Creates a stat box for summary display
    private func statBox(value: String, label: String, color: Color = .primary) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.title3)
                .bold()
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 100)
        .padding(.vertical, 8)
        .padding(.horizontal, 15)
        .background(Color.white.opacity(0.5))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Functions
    
    /// Calculate percentage text from counts
    private func calculatePercentageText(_ value: Int, _ total: Int) -> String {
        guard total > 0 else { return "0.0" }
        return String(format: "%.1f", (Double(value) / Double(total)) * 100)
    }
    
    /// Get color based on success rate
    private func getSuccessRateColor(_ rate: Double) -> Color {
        if rate >= 90 {
            return .green
        } else if rate >= 75 {
            return .orange
        } else {
            return .red
        }
    }
    
    /// Format time interval to readable string
    private func formatTime(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "0s"
    }
    
    /// Format time interval to shorter readable string
    private func formatTimeShort(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.1f sec", seconds)
        } else if seconds < 3600 {
            return String(format: "%.1f min", seconds / 60)
        } else {
            return String(format: "%.1f hr", seconds / 3600)
        }
    }
    
    /// Format memory size to human-readable string
    private func formatMemorySize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}