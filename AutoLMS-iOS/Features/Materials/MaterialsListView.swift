import SwiftUI

struct MaterialsListView: View {
    let courseID: String
    
    @StateObject private var materialManager = MaterialManager()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var searchText = ""
    @State private var sortOption: MaterialSortOption = .dateDescending
    @State private var showImportantOnly = false
    @State private var showingSortSheet = false
    
    var filteredMaterials: [Material] {
        materialManager.getFilteredMaterials(
            for: courseID,
            searchText: searchText,
            sortBy: sortOption,
            showImportantOnly: showImportantOnly
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if filteredMaterials.isEmpty && !materialManager.isLoadingMaterials(for: courseID) {
                    emptyStateView
                } else {
                    materialsContent
                }
                
                if materialManager.isLoadingMaterials(for: courseID) {
                    ProgressView("강의자료 로딩 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.regularMaterial)
                }
            }
            .navigationTitle("강의자료")
            .navigationBarTitleDisplayMode(horizontalSizeClass == .compact ? .large : .inline)
            .searchable(text: $searchText, prompt: "강의자료 검색")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    filterButton
                    sortButton
                    refreshButton
                }
            }
            .refreshable {
                await materialManager.refreshMaterials(for: courseID)
            }
            .task {
                await materialManager.loadMaterials(for: courseID)
            }
            .sheet(isPresented: $showingSortSheet) {
                sortOptionsSheet
            }
            .alert("오류", isPresented: .constant(materialManager.getErrorMessage(for: courseID) != nil)) {
                Button("확인") {
                    materialManager.clearError(for: courseID)
                }
            } message: {
                if let errorMessage = materialManager.getErrorMessage(for: courseID) {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // MARK: - Materials Content
    
    @ViewBuilder
    private var materialsContent: some View {
        List {
            ForEach(filteredMaterials) { material in
                NavigationLink(destination: MaterialDetailView(material: material)) {
                    MaterialRowView(material: material) {
                        materialManager.selectMaterial(material)
                    }
                }
                .buttonStyle(.plain)
            }
            
            if let lastSyncTime = materialManager.getLastSyncTime(for: courseID) {
                lastSyncSection(lastSyncTime)
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                if searchText.isEmpty {
                    Text("강의자료가 없습니다")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("새로고침을 눌러 최신 강의자료를 확인하세요")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("검색 결과가 없습니다")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("'\(searchText)'에 대한 검색 결과가 없습니다")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if searchText.isEmpty {
                Button("새로고침") {
                    Task {
                        await materialManager.refreshMaterials(for: courseID)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    // MARK: - Toolbar Buttons
    
    @ViewBuilder
    private var filterButton: some View {
        Button(action: {
            showImportantOnly.toggle()
        }) {
            Image(systemName: showImportantOnly ? "star.fill" : "star")
                .foregroundColor(showImportantOnly ? .yellow : .primary)
        }
    }
    
    @ViewBuilder
    private var sortButton: some View {
        Button(action: {
            showingSortSheet = true
        }) {
            Image(systemName: "arrow.up.arrow.down")
        }
    }
    
    @ViewBuilder
    private var refreshButton: some View {
        Button(action: {
            Task {
                await materialManager.refreshMaterials(for: courseID)
            }
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(materialManager.isLoadingMaterials(for: courseID))
    }
    
    // MARK: - Sort Options Sheet
    
    @ViewBuilder
    private var sortOptionsSheet: some View {
        NavigationView {
            List {
                ForEach(MaterialSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        sortOption = option
                        showingSortSheet = false
                    }) {
                        HStack {
                            Text(option.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if sortOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("정렬 방식")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        showingSortSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Last Sync Section
    
    @ViewBuilder
    private func lastSyncSection(_ lastSync: Date) -> some View {
        Section {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                
                Text("마지막 동기화: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Material Row View

struct MaterialRowView: View {
    let material: Material
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Title with importance indicator
                HStack(spacing: 6) {
                    if material.isImportant {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    
                    Text(material.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Posted date
                Text(material.postedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Content preview
            if let content = material.content, !content.isEmpty {
                Text(content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // Author and attachments info
            HStack {
                if let author = material.author {
                    Label(author, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !material.attachments.isEmpty {
                    Label("\(material.attachments.count)개 파일", systemImage: "paperclip")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Convenience Initializer

extension MaterialsListView {
    init(course: Course) {
        self.courseID = course.id
    }
}

// MARK: - Preview

#Preview {
    MaterialsListView(courseID: "sample-course-id")
}