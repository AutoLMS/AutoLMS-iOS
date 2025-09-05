import Foundation
import SwiftUI

@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0.0
    @Published var lastGlobalSyncTime: Date?
    @Published var syncStatus = "대기 중"
    @Published var errorMessage: String?
    
    // Individual course sync states
    @Published var courseSyncStates: [String: CourseSyncState] = [:]
    
    private let courseManager: CourseManager
    private let materialManager: MaterialManager
    private let cacheManager: CacheManager
    
    // Task tracking
    private var activeSyncTasks: Set<String> = []
    private let syncQueue = DispatchQueue(label: "com.autolms.sync", qos: .background)
    
    private init() {
        self.courseManager = CourseManager()
        self.materialManager = MaterialManager()
        self.cacheManager = CacheManager.shared
        
        loadLastSyncTime()
    }
    
    // MARK: - Public Methods
    
    func syncAll() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncProgress = 0.0
        syncStatus = "강의 목록 동기화 중..."
        errorMessage = nil
        
        do {
            // Step 1: Sync courses (20% of progress)
            await courseManager.refreshCourses()
            await updateProgress(0.2, status: "강의자료 동기화 중...")
            
            let courses = courseManager.courses
            if courses.isEmpty {
                throw SyncError.noCourses
            }
            
            // Step 2: Sync materials for each course (80% of progress)
            let totalCourses = courses.count
            for (index, course) in courses.enumerated() {
                let courseProgress = 0.2 + (0.8 * Double(index) / Double(totalCourses))
                await updateProgress(courseProgress, status: "\(course.name) 동기화 중...")
                
                // Update individual course sync state
                courseSyncStates[course.id] = CourseSyncState(
                    courseID: course.id,
                    courseName: course.name,
                    status: .syncing,
                    startTime: Date()
                )
                
                do {
                    await materialManager.refreshMaterials(for: course.id)
                    
                    // Update success state
                    courseSyncStates[course.id] = CourseSyncState(
                        courseID: course.id,
                        courseName: course.name,
                        status: .completed,
                        startTime: courseSyncStates[course.id]?.startTime ?? Date(),
                        completionTime: Date()
                    )
                    
                } catch {
                    // Update error state but continue with other courses
                    courseSyncStates[course.id] = CourseSyncState(
                        courseID: course.id,
                        courseName: course.name,
                        status: .failed(error.localizedDescription),
                        startTime: courseSyncStates[course.id]?.startTime ?? Date(),
                        completionTime: Date()
                    )
                }
            }
            
            // Step 3: Complete
            await updateProgress(1.0, status: "동기화 완료")
            lastGlobalSyncTime = Date()
            saveLastSyncTime()
            
            // Auto-hide success status after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.syncStatus = "대기 중"
            }
            
        } catch {
            errorMessage = handleSyncError(error)
            syncStatus = "동기화 실패"
        }
        
        isSyncing = false
    }
    
    func syncCourse(_ courseID: String, courseName: String) async {
        guard !activeSyncTasks.contains(courseID) else { return }
        
        activeSyncTasks.insert(courseID)
        
        // Update course sync state
        courseSyncStates[courseID] = CourseSyncState(
            courseID: courseID,
            courseName: courseName,
            status: .syncing,
            startTime: Date()
        )
        
        do {
            await materialManager.refreshMaterials(for: courseID)
            
            // Update success state
            courseSyncStates[courseID] = CourseSyncState(
                courseID: courseID,
                courseName: courseName,
                status: .completed,
                startTime: courseSyncStates[courseID]?.startTime ?? Date(),
                completionTime: Date()
            )
            
        } catch {
            // Update error state
            courseSyncStates[courseID] = CourseSyncState(
                courseID: courseID,
                courseName: courseName,
                status: .failed(error.localizedDescription),
                startTime: courseSyncStates[courseID]?.startTime ?? Date(),
                completionTime: Date()
            )
        }
        
        activeSyncTasks.remove(courseID)
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func getCourseSync(for courseID: String) -> CourseSyncState? {
        return courseSyncStates[courseID]
    }
    
    func isCoursesSyncing(courseID: String) -> Bool {
        return activeSyncTasks.contains(courseID)
    }
    
    // MARK: - Private Methods
    
    private func updateProgress(_ progress: Double, status: String) async {
        await MainActor.run {
            syncProgress = progress
            syncStatus = status
        }
        
        // Small delay for UI smoothness
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
    }
    
    private func handleSyncError(_ error: Error) -> String {
        switch error {
        case SyncError.noCourses:
            return "동기화할 강의가 없습니다."
        case APIError.notAuthenticated:
            return "로그인이 필요합니다."
        case APIError.serverError(let code):
            return "서버 오류 (코드: \(code))"
        default:
            return "동기화 중 오류가 발생했습니다: \(error.localizedDescription)"
        }
    }
    
    private func loadLastSyncTime() {
        lastGlobalSyncTime = UserDefaults.standard.object(forKey: "last_global_sync_time") as? Date
    }
    
    private func saveLastSyncTime() {
        if let lastSyncTime = lastGlobalSyncTime {
            UserDefaults.standard.set(lastSyncTime, forKey: "last_global_sync_time")
        }
    }
}

// MARK: - Course Sync State

struct CourseSyncState {
    let courseID: String
    let courseName: String
    var status: SyncStatus
    let startTime: Date
    var completionTime: Date?
    
    var duration: TimeInterval? {
        guard let completionTime = completionTime else { return nil }
        return completionTime.timeIntervalSince(startTime)
    }
}

enum SyncStatus {
    case pending
    case syncing
    case completed
    case failed(String)
    
    var displayName: String {
        switch self {
        case .pending:
            return "대기 중"
        case .syncing:
            return "동기화 중"
        case .completed:
            return "완료"
        case .failed(let message):
            return "실패: \(message)"
        }
    }
    
    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
    
    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

// MARK: - Sync Error

enum SyncError: Error, LocalizedError {
    case noCourses
    case networkUnavailable
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .noCourses:
            return "No courses to sync"
        case .networkUnavailable:
            return "Network unavailable"
        case .authenticationRequired:
            return "Authentication required"
        }
    }
}