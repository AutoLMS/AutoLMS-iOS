import SwiftUI

struct CourseListView: View {
    @StateObject private var courseManager = CourseManager()
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        NavigationStack {
            ZStack {
                if courseManager.courses.isEmpty && !courseManager.isLoading {
                    emptyStateView
                } else {
                    courseListContent
                }
                
                if courseManager.isLoading {
                    ProgressView("강의 목록 로딩 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.regularMaterial)
                }
            }
            .navigationTitle("강의 목록")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    refreshButton
                    settingsButton
                }
            }
            .refreshable {
                await courseManager.refreshCourses()
            }
            .task {
                await courseManager.loadCourses()
            }
            .alert("오류", isPresented: .constant(courseManager.errorMessage != nil)) {
                Button("확인") {
                    courseManager.errorMessage = nil
                }
            } message: {
                if let errorMessage = courseManager.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // MARK: - Course List Content
    
    @ViewBuilder
    private var courseListContent: some View {
        List {
            if horizontalSizeClass == .compact {
                // iPhone: Grid layout
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(courseManager.courses) { course in
                        NavigationLink(destination: MaterialsListView(courseID: course.id)) {
                            CourseCardView(course: course) {
                                // Navigation handled by NavigationLink
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            } else {
                // iPad: List layout
                ForEach(courseManager.courses) { course in
                    NavigationLink(destination: MaterialsListView(courseID: course.id)) {
                        CourseRowView(course: course) {
                            // Navigation handled by NavigationLink
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if let lastSyncTime = courseManager.lastSyncTime {
                lastSyncSection(lastSyncTime)
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("강의가 없습니다")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("새로고침을 눌러 강의 목록을 불러오세요")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("새로고침") {
                Task {
                    await courseManager.refreshCourses()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Toolbar Buttons
    
    @ViewBuilder
    private var refreshButton: some View {
        Button(action: {
            Task {
                await courseManager.refreshCourses()
            }
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(courseManager.isLoading)
    }
    
    @ViewBuilder
    private var settingsButton: some View {
        Button(action: {
            // TODO: Navigate to settings
        }) {
            Image(systemName: "gear")
        }
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

// MARK: - Course Card View (iPhone)

struct CourseCardView: View {
    let course: Course
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Course Code and Color
            HStack {
                Text(course.courseCode)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(courseColor.opacity(0.2))
                    .foregroundColor(courseColor)
                    .cornerRadius(4)
                
                Spacer()
            }
            
            // Course Name
            Text(course.name)
                .font(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            
            // Professor Info
            if let professor = course.professor {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(professor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 2)
        .onTapGesture {
            onTap()
        }
    }
    
    private var courseColor: Color {
        if let colorHex = course.color {
            return Color(hex: colorHex) ?? .blue
        }
        return .blue
    }
}

// MARK: - Course Row View (iPad)

struct CourseRowView: View {
    let course: Course
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(courseColor)
                .frame(width: 4, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(course.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(course.courseCode)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                
                if let professor = course.professor {
                    Text(professor)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var courseColor: Color {
        if let colorHex = course.color {
            return Color(hex: colorHex) ?? .blue
        }
        return .blue
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview("iPhone") {
    CourseListView()
        .environmentObject(AuthenticationManager())
}

#Preview("iPad") {
    CourseListView()
        .environmentObject(AuthenticationManager())
        .previewDevice("iPad Pro (12.9-inch)")
}