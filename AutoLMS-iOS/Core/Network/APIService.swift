import Foundation

protocol APIServiceProtocol {
    func login(studentID: String, password: String) async throws -> AuthResponse
    func getCurrentUser() async throws -> User
    func getCourses() async throws -> [Course]
    func getCourseMaterials(courseID: String) async throws -> [Material]
    func refreshCourseMaterials(courseID: String) async throws -> RefreshResponse
    func downloadMaterialAttachment(attachmentID: String) async throws -> URL
}

class APIService: APIServiceProtocol {
    static let shared = APIService()
    private let baseURL = "https://api.autolms.com" // TODO: Replace with actual API URL
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Authentication
    
    func login(studentID: String, password: String) async throws -> AuthResponse {
        let request = try createRequest(
            endpoint: "/api/v1/auth/login",
            method: "POST",
            body: ["username": studentID, "password": password]
        )
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }
    
    func getCurrentUser() async throws -> User {
        let request = try createAuthenticatedRequest(endpoint: "/api/v1/auth/me")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        return try JSONDecoder().decode(User.self, from: data)
    }
    
    // MARK: - Courses
    
    func getCourses() async throws -> [Course] {
        let request = try createAuthenticatedRequest(endpoint: "/api/v1/courses")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        let coursesResponse = try JSONDecoder().decode(CoursesResponse.self, from: data)
        return coursesResponse.courses
    }
    
    // MARK: - Materials
    
    func getCourseMaterials(courseID: String) async throws -> [Material] {
        let request = try createAuthenticatedRequest(endpoint: "/api/v1/courses/\(courseID)/materials")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        let materialsResponse = try JSONDecoder().decode(MaterialsResponse.self, from: data)
        return materialsResponse.materials
    }
    
    func refreshCourseMaterials(courseID: String) async throws -> RefreshResponse {
        let request = try createAuthenticatedRequest(
            endpoint: "/api/v1/courses/\(courseID)/materials/refresh",
            method: "POST"
        )
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        return try JSONDecoder().decode(RefreshResponse.self, from: data)
    }
    
    // MARK: - File Downloads
    
    func downloadMaterialAttachment(attachmentID: String) async throws -> URL {
        let request = try createAuthenticatedRequest(
            endpoint: "/api/v1/attachments/\(attachmentID)/download"
        )
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        // Save to temporary directory
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try data.write(to: tempURL)
        return tempURL
    }
}

// MARK: - Helper Methods

private extension APIService {
    func createRequest(endpoint: String, method: String = "GET", body: [String: Any]? = nil) throws -> URLRequest {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        return request
    }
    
    func createAuthenticatedRequest(endpoint: String, method: String = "GET", body: [String: Any]? = nil) throws -> URLRequest {
        var request = try createRequest(endpoint: endpoint, method: method, body: body)
        
        if let token = KeychainManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw APIError.notAuthenticated
        }
        
        return request
    }
    
    func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw APIError.notAuthenticated
        case 404:
            throw APIError.notFound
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
}

// MARK: - API Error

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case notAuthenticated
    case notFound
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .notAuthenticated:
            return "Not authenticated"
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}