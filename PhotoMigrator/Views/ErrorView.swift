import SwiftUI

struct ErrorView: View {
    let error: Error?
    let onTryAgain: () -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.red)
            
            Text("Migration Error")
                .font(.title)
                .foregroundColor(.red)
            
            Text(errorMessage)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let recoverySuggestion = (error as? LocalizedError)?.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundColor(.secondary)
            }
            
            if hasDetailedError {
                Button("Show Technical Details") {
                    showingDetails.toggle()
                }
                .padding(.top)
                
                if showingDetails {
                    ScrollView {
                        Text(detailedErrorMessage)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            
            HStack(spacing: 20) {
                Button("Try Again") {
                    onTryAgain()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: 500)
    }
    
    private var errorMessage: String {
        if let localizedError = error as? LocalizedError, let errorDescription = localizedError.errorDescription {
            return errorDescription
        } else {
            return error?.localizedDescription ?? "An unknown error occurred."
        }
    }
    
    private var hasDetailedError: Bool {
        return (error as? MigrationError) != nil
    }
    
    private var detailedErrorMessage: String {
        switch error as? MigrationError {
        case .archiveNotFound:
            return "The application could not find the specified Google Takeout archive file. Ensure that the file exists at the location you specified and that you have permission to access it."
        case .archiveExtractionFailed:
            return "The application failed to extract the Google Takeout archive. This could be due to insufficient disk space, file corruption, or permission issues. Try using a different archive file or extracting it manually before importing."
        case .invalidArchiveStructure:
            return "The structure of the Google Takeout archive is not recognized. This application expects a specific directory structure with Google Photos data. Make sure you selected a valid Google Photos Takeout archive and not another type of export."
        case .photosAccessDenied:
            return "The application was denied permission to access Apple Photos. To proceed with migration, you must grant access in System Preferences > Security & Privacy > Privacy > Photos. After granting access, restart the application."
        case .importFailed(let reason):
            return "Failed to import media: \(reason)\n\nThis could be due to an unsupported file format, corrupt data, or issues with the Apple Photos library. Try processing fewer items or check if your Photos library has enough storage space."
        case .fileAccessError(let path):
            return "Could not access file at path: \(path)\n\nThis could be due to permission issues or the file may have been moved or deleted during processing."
        case .metadataParsingError(let details):
            return "Error parsing metadata: \(details)\n\nThe JSON metadata file may be corrupted or in an unexpected format. The application will attempt to continue with limited metadata for this item."
        case .operationCancelled:
            return "The migration operation was cancelled by the user."
        case .unknown, .none:
            return "An unspecified error occurred during the migration process. Try restarting the application or your computer."
        }
    }
}

struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        ErrorView(error: MigrationError.archiveExtractionFailed, onTryAgain: {})
    }
}
