import Foundation

protocol MaterialRepositoryProtocol {
    func getMaterials(for courseID: String) async throws -> [Material]
    func refreshMaterials(for courseID: String) async throws -> RefreshResponse
    func getCachedMaterials(for courseID: String) -> [Material]
    func cacheMaterials(_ materials: [Material], for courseID: String)
    func clearMaterialsCache(for courseID: String)
    func clearAllMaterialsCache()
}

class MaterialRepository: MaterialRepositoryProtocol {
    private let apiService: APIServiceProtocol
    private let cacheManager: CacheManager
    
    init(apiService: APIServiceProtocol = APIService.shared,
         cacheManager: CacheManager = CacheManager.shared) {
        self.apiService = apiService
        self.cacheManager = cacheManager
    }
    
    // MARK: - Public Methods
    
    func getMaterials(for courseID: String) async throws -> [Material] {
        let materials = try await apiService.getCourseMaterials(courseID: courseID)
        cacheMaterials(materials, for: courseID)
        return materials
    }
    
    func refreshMaterials(for courseID: String) async throws -> RefreshResponse {
        let refreshResponse = try await apiService.refreshCourseMaterials(courseID: courseID)
        
        // Cache the refreshed materials
        cacheMaterials(refreshResponse.materials, for: courseID)
        
        return refreshResponse
    }
    
    func getCachedMaterials(for courseID: String) -> [Material] {
        let cacheKey = materialsKey(for: courseID)
        return cacheManager.getCachedObject(forKey: cacheKey, type: [Material].self) ?? []
    }
    
    func cacheMaterials(_ materials: [Material], for courseID: String) {
        let cacheKey = materialsKey(for: courseID)
        cacheManager.cacheObject(materials, forKey: cacheKey)
    }
    
    func clearMaterialsCache(for courseID: String) {
        let cacheKey = materialsKey(for: courseID)
        cacheManager.removeObject(forKey: cacheKey)
    }
    
    func clearAllMaterialsCache() {
        // This would require tracking all cached course IDs
        // For now, we'll implement a simple approach
        cacheManager.clearAllCache()
    }
    
    // MARK: - Private Methods
    
    private func materialsKey(for courseID: String) -> String {
        return "materials_\(courseID)"
    }
}