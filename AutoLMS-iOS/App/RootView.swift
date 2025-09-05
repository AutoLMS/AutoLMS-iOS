import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainContentView()
            } else {
                LoginView()
            }
        }
        .environmentObject(authManager)
    }
}

struct MainContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var syncManager = SyncManager.shared
    
    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: NavigationSplitView
            NavigationSplitView {
                CourseListSidebar()
            } content: {
                Text("강의를 선택하세요")
                    .font(.title2)
                    .foregroundColor(.secondary)
            } detail: {
                Text("강의자료를 선택하세요")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .overlay(alignment: .bottom) {
                SyncStatusView(syncManager: syncManager)
                    .padding()
            }
        } else {
            // iPhone: NavigationStack
            VStack {
                CourseListView()
                
                SyncStatusView(syncManager: syncManager)
                    .padding()
            }
        }
    }
}

// iPad Sidebar - simplified version of CourseListView
struct CourseListSidebar: View {
    @StateObject private var courseManager = CourseManager()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(courseManager.courses) { course in
                    Button(action: {
                        courseManager.selectCourse(course)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(course.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            
                            if let professor = course.professor {
                                Text(professor)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
                
                if courseManager.courses.isEmpty {
                    Text("강의가 없습니다")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .navigationTitle("강의")
            .task {
                await courseManager.loadCourses()
            }
        }
    }
}

#Preview {
    RootView()
}
