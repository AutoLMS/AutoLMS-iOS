import Foundation

protocol CourseRepositoryProtocol {
    func getCourses() async throws -> [Course]
    func getCachedCourses() -> [Course]
    func cacheCourses(_ courses: [Course])
    func clearCourseCache()
}

class CourseRepository: CourseRepositoryProtocol {
    private let apiService: APIServiceProtocol
    private let cacheManager: CacheManager
    
    private let coursesKey = "cached_courses"
    
    init(apiService: APIServiceProtocol = APIService.shared,
         cacheManager: CacheManager = CacheManager.shared) {
        self.apiService = apiService
        self.cacheManager = cacheManager
    }
    
    // MARK: - Public Methods
    
    func getCourses() async throws -> [Course] {
        let courses = try await apiService.getCourses()
        cacheCourses(courses)
        return courses
    }
    
    func getCachedCourses() -> [Course] {
        return cacheManager.getCachedObject(forKey: coursesKey, type: [Course].self) ?? []
    }
    
    func cacheCourses(_ courses: [Course]) {
        cacheManager.cacheObject(courses, forKey: coursesKey)
    }
    
    func clearCourseCache() {
        cacheManager.removeObject(forKey: coursesKey)
    }
}