import Foundation

// MARK: - Authentication Response Models

struct AuthResponse: Codable {
    let accessToken: String
    let tokenType: String
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case user
    }
}

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let eclassUsername: String
    let token: String
    
    enum CodingKeys: String, CodingKey {
        case id, email, token
        case eclassUsername = "eclass_username"
    }
}