import SwiftUI

struct ArchiveSelectionView: View {
    let onArchiveSelected: (URL) -> Void
    
    @State private var isDragging = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text("Google Photos to Apple Photos Migration")
                .font(.title)
                .multilineTextAlignment(.center)
            
            Text("Drag and drop your Google Takeout archive file or folder here, or click to select")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isDragging ? Color.blue : Color.gray, lineWidth: 2)
                            .animation(.default, value: isDragging)
                    )
                
                VStack(spacing: 16) {
                    Image(systemName: isDragging ? "arrow.down.doc.fill" : "arrow.down.doc")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(isDragging ? .blue : .gray)
                        .animation(.default, value: isDragging)
                    
                    Text(isDragging ? "Release to drop" : "Drop Google Takeout file here")
                        .font(.title3)
                        .foregroundColor(isDragging ? .blue : .primary)
                    
                    Button("Select File") {
                        selectFile()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            }
            .frame(height: 250)
            .padding()
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers -> Bool
                providers.first?.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                    guard let data = data,
                          let path = String(data: data, encoding: .utf8),
                          let url = URL(string: path) else {
                        self.errorMessage = "Unable to read the dropped file"
                        return
                    }
                    
                    // Remove file:// prefix
                    let filePath = url.absoluteString.hasPrefix("file://") ? URL(fileURLWithPath: url.path) : url
                    
                    self.onArchiveSelected(filePath)
                }
                return true
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Instructions:")
                    .font(.headline)
                
                Text("1. Download your Google Photos archive from Google Takeout")
                Text("2. Select either the downloaded zip file or the extracted folder")
                Text("3. The app will process the archive and import your photos to Apple Photos")
                Text("4. Albums and metadata will be preserved when possible")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding()
        }
        .padding()
    }
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.folder, .archive, .zip]
        panel.message = "Select your Google Takeout archive file or extracted folder"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.onArchiveSelected(url)
            }
        }
    }
}

struct ArchiveSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveSelectionView(onArchiveSelected: { _ in })
    }
}
