import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.autolms.ios"
    private let authTokenKey = "auth_token"
    private let userIDKey = "user_id"
    
    private init() {}
    
    // MARK: - Auth Token Management
    
    func saveAuthToken(_ token: String) -> Bool {
        return save(key: authTokenKey, data: token.data(using: .utf8)!)
    }
    
    func getAuthToken() -> String? {
        guard let data = load(key: authTokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func deleteAuthToken() -> Bool {
        return delete(key: authTokenKey)
    }
    
    // MARK: - User ID Management
    
    func saveUserID(_ userID: String) -> Bool {
        return save(key: userIDKey, data: userID.data(using: .utf8)!)
    }
    
    func getUserID() -> String? {
        guard let data = load(key: userIDKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func deleteUserID() -> Bool {
        return delete(key: userIDKey)
    }
    
    // MARK: - Clear All
    
    func clearAll() -> Bool {
        let tokenDeleted = deleteAuthToken()
        let userDeleted = deleteUserID()
        return tokenDeleted && userDeleted
    }
}

// MARK: - Private Keychain Operations

private extension KeychainManager {
    func save(key: String, data: Data) -> Bool {
        // First, delete any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }
        
        return data
    }
    
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}