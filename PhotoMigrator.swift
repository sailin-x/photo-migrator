import Foundation
import class Foundation.Bundle

// Enhanced command line interface with all features
print("PhotoMigrator - Google Photos to Apple Photos Migration Tool")
print("Version 1.4 - Enterprise Release")
print("")
print("This command-line version displays information about the application.")
print("The full GUI version requires macOS to run properly with PhotoKit access.")
print("")
print("Features implemented in the macOS version:")
print("- Extract and parse Google Takeout archives")
print("- Process JSON metadata files for photo information")
print("- Handle Live Photo reconstruction")
print("- Preserve original metadata (dates, locations, descriptions)")
print("- Import to Apple Photos library")
print("- Maintain album organization")
print("- Process various image formats (JPG, HEIC, PNG, etc.)")
print("- Batch processing for very large libraries")
print("- Detailed migration statistics and reports")
print("- User preference persistence")
print("- User account management & licensing")
print("- Supabase backend integration")
print("")
print("Batch Processing Features:")
print("- Memory-efficient processing of large libraries")
print("- Adaptive batch sizing based on system resources")
print("- Memory usage monitoring to prevent crashes")
print("- Configurable batch size and processing parameters")
print("- Support for libraries with 100,000+ photos")
print("")
print("Statistics and Reporting Features:")
print("- Detailed breakdown of media types and formats")
print("- Interactive charts and visualizations")
print("- Timeline analysis of each processing stage")
print("- Metadata preservation statistics")
print("- Performance metrics and processing speed")
print("- Exportable HTML and CSV reports")
print("")
print("User & Licensing Features:")
print("- User account management with Supabase")
print("- License activation and validation")
print("- Machine-specific hardware identifiers")
print("- Trial period management")
print("- Subscription handling")
print("- Onboarding for new users")
print("")
print("For a complete feature list, see the attached documentation.")

extension Bundle {
    // This extension adds programmatic access to the required usage descriptions
    // that would normally be in Info.plist
    
    /// Photo library usage description
    static var photoLibraryUsageDescription: String {
        return "PhotoMigrator requires access to your Photos library to import your Google Photos, preserving metadata like dates, locations, and descriptions. The app will also recreate your album structure."
    }
    
    /// Photo library add usage description
    static var photoLibraryAddUsageDescription: String {
        return "PhotoMigrator needs permission to add photos to your Photos library. This is required to import your Google Photos."
    }
}