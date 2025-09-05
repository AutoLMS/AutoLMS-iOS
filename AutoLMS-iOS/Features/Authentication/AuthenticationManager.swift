import Foundation
import SwiftUI

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService: APIServiceProtocol
    private let keychainManager: KeychainManager
    
    init(apiService: APIServiceProtocol = APIService.shared, 
         keychainManager: KeychainManager = KeychainManager.shared) {
        self.apiService = apiService
        self.keychainManager = keychainManager
        
        checkAuthenticationStatus()
    }
    
    // MARK: - Public Methods
    
    func login(studentID: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let authResponse = try await apiService.login(studentID: studentID, password: password)
            
            // Save token and user ID to keychain
            let tokenSaved = keychainManager.saveAuthToken(authResponse.accessToken)
            let userSaved = keychainManager.saveUserID(authResponse.user.id)
            
            guard tokenSaved && userSaved else {
                throw AuthenticationError.keychainError
            }
            
            // Update state
            currentUser = authResponse.user
            isAuthenticated = true
            
        } catch {
            errorMessage = handleAuthError(error)
        }
        
        isLoading = false
    }
    
    func logout() {
        isLoading = true
        
        // Clear keychain
        _ = keychainManager.clearAll()
        
        // Update state
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
        
        isLoading = false
    }
    
    func refreshUserInfo() async {
        guard isAuthenticated else { return }
        
        do {
            let user = try await apiService.getCurrentUser()
            currentUser = user
        } catch {
            // If refresh fails, user might need to re-login
            handleAuthError(error)
            if case APIError.notAuthenticated = error {
                logout()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkAuthenticationStatus() {
        // Check if we have a valid token
        guard keychainManager.getAuthToken() != nil,
              keychainManager.getUserID() != nil else {
            isAuthenticated = false
            return
        }
        
        // Verify token validity by fetching user info
        Task {
            await refreshUserInfo()
        }
    }
    
    private func handleAuthError(_ error: Error) -> String {
        switch error {
        case APIError.notAuthenticated:
            return "로그인 정보가 올바르지 않습니다."
        case APIError.serverError(let code):
            return "서버 오류가 발생했습니다. (코드: \(code))"
        case APIError.invalidURL:
            return "서버 연결에 문제가 있습니다."
        case APIError.invalidResponse:
            return "서버 응답을 처리할 수 없습니다."
        case AuthenticationError.keychainError:
            return "보안 저장소에 접근할 수 없습니다."
        default:
            return "알 수 없는 오류가 발생했습니다: \(error.localizedDescription)"
        }
    }
}

// MARK: - Authentication Error

enum AuthenticationError: Error, LocalizedError {
    case keychainError
    case invalidCredentials
    
    var errorDescription: String? {
        switch self {
        case .keychainError:
            return "Keychain access error"
        case .invalidCredentials:
            return "Invalid credentials"
        }
    }
}