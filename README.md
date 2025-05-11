# PhotoMigrator

A macOS application for migrating Google Photos to Apple Photos while preserving metadata and organization.

## Overview

PhotoMigrator is designed to process Google Takeout archives and import them into Apple Photos, maintaining as much metadata and organizational structure as possible. The application handles the complexities of Google Takeout's inconsistent file formats and structure to provide a seamless migration experience.

## Features

- **Takeout Archive Processing**: Extract and navigate Google Takeout archives
- **Metadata Preservation**: Extract and preserve metadata from JSON sidecar files
  - Photo dates and times (with timezone adjustment)
  - Geolocation data
  - Descriptions and titles
  - People tags
  - Favorite status
- **Live Photo Reconstruction**: Reconnect still images with their video components
- **Album Organization**: Recreate your Google Photos album structure in Apple Photos
- **Format Support**: Process various image and video formats
  - Images: JPG, HEIC, PNG, WebP, GIF, etc.
  - Videos: MP4, MOV, etc.
  - Google Pixel Motion Photos (MP+JPG)
- **Batch Processing**: Efficiently handle very large libraries
  - Memory-efficient processing of 100,000+ photos
  - Adaptive batch sizing based on system resources
  - Memory usage monitoring to prevent crashes
  - Configurable processing parameters
- **Detailed Statistics and Reporting**: Comprehensive data on migration results
  - Interactive charts and visualizations
  - Detailed breakdown by media types and file formats
  - Timeline analysis of processing stages
  - Exportable HTML and CSV reports
  - Metadata preservation statistics
- **Error Handling**: Comprehensive error reporting and recovery options

## System Requirements

- macOS 11.0 (Big Sur) or later
- Access permissions to Apple Photos
- Sufficient disk space for processing Google Takeout archives

## Migration Process

1. **Select Archive**: Choose your Google Takeout archive file or pre-extracted folder
2. **Process Files**: The app scans for media and associated metadata
3. **Import to Photos**: Media files are imported to Apple Photos with their metadata
4. **Create Albums**: Original album structure is recreated
5. **View Summary**: Review migration statistics and any issues encountered

## Development Details

The application is built using:
- Swift and SwiftUI for the user interface
- PhotoKit for Apple Photos integration
- Native macOS archive handling capabilities

## Important Notes

- The migration process requires permission to access your Apple Photos library
- The original Google Takeout archive is not modified
- Live Photos can only be reconstructed if both components are present in the archive
- Some advanced Google Photos features (like creations or shared albums) may not transfer fully