# Tech Context - PhotoMigrator

## Tech Stack
- **Swift**: Core programming language
- **SwiftUI**: UI framework
- **PhotoKit**: Apple Photos integration
- **Combine**: Reactive programming for state management

## Dependencies
- **Swift System**: Low-level system interface package
- **SwiftUI Charts**: For visualization of migration statistics
- No third-party dependencies to ensure long-term maintainability

## Setup Instructions
1. Ensure macOS 11.0 (Big Sur) or later
2. Clone the repository
3. Open Package.swift in Xcode
4. Build for development or release

## Development Environment
- Xcode 13+ 
- Swift 5.5+
- Target OS: macOS 11.0+

## Constraints

### Technical Constraints
- Limited by PhotoKit API capabilities
  - Some metadata can only be written during import
  - Face recognition tags limited to keywords
  - Album hierarchy limitations
- Memory management for large libraries
  - Batch processing requirements
  - Resource monitoring needed

### Platform Constraints
- macOS only application (not iOS/iPadOS compatible)
- Requires Photos app access permissions
- Cannot modify Google Takeout archives

### Security & Privacy
- Must respect Photos library privacy
- No network access required or implemented
- All processing done locally
- No user data collection 