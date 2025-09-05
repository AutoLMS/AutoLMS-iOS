import Foundation
import SwiftUI

@MainActor
class MaterialManager: ObservableObject {
    @Published var materials: [String: [Material]] = [:] // courseID -> materials
    @Published var isLoading: [String: Bool] = [:] // courseID -> loading state
    @Published var errorMessages: [String: String] = [:] // courseID -> error message
    @Published var lastSyncTimes: [String: Date] = [:] // courseID -> last sync time
    @Published var selectedMaterial: Material?
    
    private let repository: MaterialRepositoryProtocol
    private let cacheManager: CacheManager
    
    init(repository: MaterialRepositoryProtocol = MaterialRepository(),
         cacheManager: CacheManager = CacheManager.shared) {
        self.repository = repository
        self.cacheManager = cacheManager
    }
    
    // MARK: - Public Methods
    
    func loadMaterials(for courseID: String, forceRefresh: Bool = false) async {
        // Use cached data if available and not forcing refresh
        if !forceRefresh, let cachedMaterials = materials[courseID], !cachedMaterials.isEmpty {
            return
        }
        
        // Load cached materials first
        loadCachedMaterials(for: courseID)
        
        // Then fetch from API
        await refreshMaterials(for: courseID)
    }
    
    func refreshMaterials(for courseID: String) async {
        isLoading[courseID] = true
        errorMessages[courseID] = nil
        
        do {
            let fetchedMaterials = try await repository.getMaterials(for: courseID)
            materials[courseID] = fetchedMaterials
            lastSyncTimes[courseID] = Date()
            
            // Clear any previous error
            errorMessages[courseID] = nil
            
        } catch {
            errorMessages[courseID] = handleError(error)
            
            // Fallback to cached data if available
            if materials[courseID]?.isEmpty ?? true {
                materials[courseID] = repository.getCachedMaterials(for: courseID)
            }
        }
        
        isLoading[courseID] = false
    }
    
    func refreshMaterialsWithStatus(for courseID: String) async -> RefreshResponse? {
        isLoading[courseID] = true
        errorMessages[courseID] = nil
        
        do {
            let refreshResponse = try await repository.refreshMaterials(for: courseID)
            materials[courseID] = refreshResponse.materials
            lastSyncTimes[courseID] = Date()
            
            // Clear any previous error
            errorMessages[courseID] = nil
            
            isLoading[courseID] = false
            return refreshResponse
            
        } catch {
            errorMessages[courseID] = handleError(error)
            isLoading[courseID] = false
            return nil
        }
    }
    
    func getMaterials(for courseID: String) -> [Material] {
        return materials[courseID] ?? []
    }
    
    func getMaterial(by id: String, in courseID: String) -> Material? {
        return materials[courseID]?.first { $0.id == id }
    }
    
    func selectMaterial(_ material: Material) {
        selectedMaterial = material
    }
    
    func isLoadingMaterials(for courseID: String) -> Bool {
        return isLoading[courseID] ?? false
    }
    
    func getErrorMessage(for courseID: String) -> String? {
        return errorMessages[courseID]
    }
    
    func getLastSyncTime(for courseID: String) -> Date? {
        return lastSyncTimes[courseID]
    }
    
    func clearError(for courseID: String) {
        errorMessages[courseID] = nil
    }
    
    // MARK: - Private Methods
    
    private func loadCachedMaterials(for courseID: String) {
        let cachedMaterials = repository.getCachedMaterials(for: courseID)
        if !cachedMaterials.isEmpty {
            materials[courseID] = cachedMaterials
            
            // Load cache timestamp
            let cacheKey = "materials_\(courseID)"
            lastSyncTimes[courseID] = cacheManager.getCacheTimestamp(forKey: cacheKey)
        }
    }
    
    private func handleError(_ error: Error) -> String {
        switch error {
        case APIError.notAuthenticated:
            return "로그인이 필요합니다."
        case APIError.serverError(let code):
            return "서버 오류 (코드: \(code))"
        case APIError.invalidResponse:
            return "서버 응답을 처리할 수 없습니다."
        case APIError.notFound:
            return "강의자료를 찾을 수 없습니다."
        default:
            return "강의자료를 불러올 수 없습니다: \(error.localizedDescription)"
        }
    }
}

// MARK: - Material Filtering and Sorting

extension MaterialManager {
    func getFilteredMaterials(
        for courseID: String,
        searchText: String = "",
        sortBy: MaterialSortOption = .dateDescending,
        showImportantOnly: Bool = false
    ) -> [Material] {
        var filteredMaterials = getMaterials(for: courseID)
        
        // Apply search filter
        if !searchText.isEmpty {
            filteredMaterials = filteredMaterials.filter { material in
                material.title.localizedCaseInsensitiveContains(searchText) ||
                material.content?.localizedCaseInsensitiveContains(searchText) == true ||
                material.author?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Apply importance filter
        if showImportantOnly {
            filteredMaterials = filteredMaterials.filter { $0.isImportant }
        }
        
        // Apply sorting
        switch sortBy {
        case .dateDescending:
            filteredMaterials.sort { $0.postedAt > $1.postedAt }
        case .dateAscending:
            filteredMaterials.sort { $0.postedAt < $1.postedAt }
        case .titleAscending:
            filteredMaterials.sort { $0.title < $1.title }
        case .titleDescending:
            filteredMaterials.sort { $0.title > $1.title }
        case .importantFirst:
            filteredMaterials.sort { lhs, rhs in
                if lhs.isImportant != rhs.isImportant {
                    return lhs.isImportant
                }
                return lhs.postedAt > rhs.postedAt
            }
        }
        
        return filteredMaterials
    }
}

// MARK: - Material Sort Options

enum MaterialSortOption: String, CaseIterable {
    case dateDescending = "date_desc"
    case dateAscending = "date_asc"
    case titleAscending = "title_asc"
    case titleDescending = "title_desc"
    case importantFirst = "important_first"
    
    var displayName: String {
        switch self {
        case .dateDescending:
            return "최신순"
        case .dateAscending:
            return "오래된순"
        case .titleAscending:
            return "제목 ㄱ-ㅎ"
        case .titleDescending:
            return "제목 ㅎ-ㄱ"
        case .importantFirst:
            return "중요한 것부터"
        }
    }
}