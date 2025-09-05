import Foundation
import SwiftUI

@MainActor
class CourseManager: ObservableObject {
    @Published var courses: [Course] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastSyncTime: Date?
    
    private let repository: CourseRepositoryProtocol
    private let cacheManager: CacheManager
    
    init(repository: CourseRepositoryProtocol = CourseRepository(),
         cacheManager: CacheManager = CacheManager.shared) {
        self.repository = repository
        self.cacheManager = cacheManager
        
        loadCachedCourses()
    }
    
    // MARK: - Public Methods
    
    func loadCourses(forceRefresh: Bool = false) async {
        // Use cached data if available and not forcing refresh
        if !forceRefresh && !courses.isEmpty {
            return
        }
        
        await refreshCourses()
    }
    
    func refreshCourses() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedCourses = try await repository.getCourses()
            courses = fetchedCourses
            lastSyncTime = Date()
            
            // Clear any previous error
            errorMessage = nil
            
        } catch {
            errorMessage = handleError(error)
            
            // Fallback to cached data if available
            if courses.isEmpty {
                courses = repository.getCachedCourses()
            }
        }
        
        isLoading = false
    }
    
    func getCourse(by id: String) -> Course? {
        return courses.first { $0.id == id }
    }
    
    // MARK: - Private Methods
    
    private func loadCachedCourses() {
        courses = repository.getCachedCourses()
        lastSyncTime = cacheManager.getCacheTimestamp(forKey: "cached_courses")
    }
    
    private func handleError(_ error: Error) -> String {
        switch error {
        case APIError.notAuthenticated:
            return "로그인이 필요합니다."
        case APIError.serverError(let code):
            return "서버 오류 (코드: \(code))"
        case APIError.invalidResponse:
            return "서버 응답을 처리할 수 없습니다."
        default:
            return "강의 목록을 불러올 수 없습니다: \(error.localizedDescription)"
        }
    }
}

// MARK: - Course Selection Extension

extension CourseManager {
    func selectCourse(_ course: Course) {
        // Handle course selection logic here
        // This could trigger navigation or update selected state
        print("Selected course: \(course.name)")
    }
}