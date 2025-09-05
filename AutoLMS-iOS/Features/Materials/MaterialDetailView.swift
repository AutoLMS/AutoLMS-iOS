import SwiftUI
import UIKit
import QuickLook

struct MaterialDetailView: View {
    let material: Material
    @StateObject private var downloadManager = DownloadManager()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingQuickLook = false
    @State private var quickLookURL: URL?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Section
                    materialHeader
                    
                    // Content Section
                    if let content = material.content, !content.isEmpty {
                        contentSection(content)
                    }
                    
                    // Attachments Section
                    if !material.attachments.isEmpty {
                        attachmentsSection
                    }
                    
                    // Metadata Section
                    metadataSection
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 16)
                .padding(.vertical, 20)
            }
            .navigationTitle(material.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    shareButton
                }
            }
        }
        .sheet(isPresented: $showingQuickLook) {
            if let url = quickLookURL {
                QuickLookPreview(url: url)
            }
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var materialHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title with importance indicator
            HStack(alignment: .top, spacing: 8) {
                if material.isImportant {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                }
                
                Text(material.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
            }
            
            // Author and date info
            HStack {
                if let author = material.author {
                    Label(author, systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(material.postedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Content Section
    
    @ViewBuilder
    private func contentSection(_ content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("내용", systemImage: "doc.text")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Attachments Section
    
    @ViewBuilder
    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("첨부파일 (\(material.attachments.count)개)", systemImage: "paperclip")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(material.attachments) { attachment in
                    AttachmentRowView(
                        attachment: attachment, 
                        downloadManager: downloadManager,
                        showingQuickLook: $showingQuickLook,
                        quickLookURL: $quickLookURL
                    )
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Metadata Section
    
    @ViewBuilder
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("정보", systemImage: "info.circle")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                metadataRow("작성일", material.postedAt.formatted(date: .complete, time: .shortened))
                metadataRow("버전", "\(material.version)")
                
                if let replacedBy = material.replacedBy {
                    metadataRow("대체됨", "새 버전으로 교체됨")
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func metadataRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Share Button
    
    @ViewBuilder
    private var shareButton: some View {
        Button(action: {
            // TODO: Implement sharing functionality
        }) {
            Image(systemName: "square.and.arrow.up")
        }
    }
}

// MARK: - Attachment Row View

struct AttachmentRowView: View {
    let attachment: Attachment
    @ObservedObject var downloadManager: DownloadManager
    @Binding var showingQuickLook: Bool
    @Binding var quickLookURL: URL?
    
    var body: some View {
        HStack(spacing: 12) {
            // File icon
            Image(systemName: fileIcon)
                .font(.title2)
                .foregroundColor(fileIconColor)
                .frame(width: 32, height: 32)
            
            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.filename)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Text(formatFileSize(attachment.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let mimeType = attachment.mimeType {
                        Text("• \(mimeType)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Download button
            downloadButton
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var downloadButton: some View {
        if downloadManager.isDownloading(attachment.id) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(0.8)
        } else if downloadManager.downloadedFiles[attachment.id] != nil {
            HStack(spacing: 8) {
                // Preview button (for PDFs)
                if attachment.mimeType?.contains("pdf") == true {
                    Button(action: {
                        quickLookURL = downloadManager.downloadedFiles[attachment.id]
                        showingQuickLook = true
                    }) {
                        Image(systemName: "eye.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                // Open in other apps button
                Button(action: {
                    downloadManager.openFile(attachment)
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
            }
        } else {
            Button(action: {
                Task {
                    await downloadManager.downloadAttachment(attachment)
                }
            }) {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var fileIcon: String {
        guard let mimeType = attachment.mimeType else {
            return "doc"
        }
        
        if mimeType.hasPrefix("application/pdf") {
            return "doc.richtext"
        } else if mimeType.hasPrefix("image/") {
            return "photo"
        } else if mimeType.hasPrefix("video/") {
            return "video"
        } else if mimeType.hasPrefix("audio/") {
            return "music.note"
        } else if mimeType.contains("zip") || mimeType.contains("archive") {
            return "archivebox"
        } else if mimeType.contains("presentation") {
            return "doc.richtext"
        } else if mimeType.contains("spreadsheet") {
            return "tablecells"
        } else {
            return "doc"
        }
    }
    
    private var fileIconColor: Color {
        guard let mimeType = attachment.mimeType else {
            return .gray
        }
        
        if mimeType.hasPrefix("application/pdf") {
            return .red
        } else if mimeType.hasPrefix("image/") {
            return .green
        } else if mimeType.hasPrefix("video/") {
            return .blue
        } else if mimeType.hasPrefix("audio/") {
            return .purple
        } else {
            return .gray
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Download Manager

@MainActor
class DownloadManager: NSObject, ObservableObject, UIDocumentInteractionControllerDelegate {
    @Published var downloadingFiles: Set<String> = []
    @Published var downloadedFiles: [String: URL] = [:]
    
    func isDownloading(_ attachmentID: String) -> Bool {
        downloadingFiles.contains(attachmentID)
    }
    
    func downloadAttachment(_ attachment: Attachment) async {
        downloadingFiles.insert(attachment.id)
        
        do {
            // Download using actual API service
            let downloadedURL = try await APIService.shared.downloadMaterialAttachment(attachmentID: attachment.id)
            
            // Move to a permanent location with proper filename
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let targetURL = documentsURL.appendingPathComponent(attachment.filename)
            
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            
            // Move the downloaded file to the target location
            try FileManager.default.moveItem(at: downloadedURL, to: targetURL)
            
            downloadedFiles[attachment.id] = targetURL
            downloadingFiles.remove(attachment.id)
            
        } catch {
            downloadingFiles.remove(attachment.id)
            print("Download failed: \(error)")
            
            // Show user-friendly error handling could be added here
            // For now, we'll just log the error
        }
    }
    
    func openFile(_ attachment: Attachment) {
        guard let fileURL = downloadedFiles[attachment.id] else {
            print("File not found for attachment: \(attachment.filename)")
            return
        }
        
        // Use UIApplication to open the file with system default apps
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let documentInteractionController = UIDocumentInteractionController(url: fileURL)
            documentInteractionController.delegate = self
            
            // Get the root view controller to present from
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                // Try to open in place first (for apps like GoodNotes, Notability)
                if documentInteractionController.presentOpenInMenu(from: .zero, in: rootViewController.view, animated: true) {
                    // Successfully presented open-in menu
                } else {
                    // Fallback: present preview
                    documentInteractionController.presentPreview(animated: true)
                }
            }
        } else {
            print("File does not exist at path: \(fileURL.path)")
        }
    }
    
    // MARK: - UIDocumentInteractionControllerDelegate
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        // Return the current root view controller for preview presentation
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            return rootViewController
        }
        return UIViewController() // Fallback
    }
}

// MARK: - QuickLook Preview

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // No update needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: QLPreviewControllerDataSource {
        let parent: QuickLookPreview
        
        init(_ parent: QuickLookPreview) {
            self.parent = parent
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
    }
}

// MARK: - Preview

#Preview {
    MaterialDetailView(
        material: Material(
            id: "1",
            courseId: "course1",
            title: "강의자료 제목 예시",
            content: "이것은 강의자료의 내용입니다. 여러 줄에 걸쳐서 작성될 수 있으며, 학습에 필요한 중요한 정보들을 포함합니다.",
            author: "김교수",
            postedAt: Date(),
            isImportant: true,
            version: 1,
            replacedBy: nil,
            metadata: nil,
            attachments: [
                Attachment(
                    id: "1",
                    contentId: "1",
                    filename: "lecture_notes.pdf",
                    fileSize: 1024000,
                    mimeType: "application/pdf",
                    storagePath: "/path/to/file",
                    checksum: "abc123",
                    createdAt: Date()
                )
            ],
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}