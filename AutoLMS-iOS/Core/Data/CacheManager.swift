import Foundation

class CacheManager {
    static let shared = CacheManager()
    
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        // Configure encoder/decoder
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Generic Caching Methods
    
    func cacheObject<T: Codable>(_ object: T, forKey key: String) {
        do {
            let data = try encoder.encode(object)
            userDefaults.set(data, forKey: key)
            
            // Save cache timestamp
            let timestampKey = "\(key)_timestamp"
            userDefaults.set(Date(), forKey: timestampKey)
        } catch {
            print("Failed to cache object for key \(key): \(error)")
        }
    }
    
    func getCachedObject<T: Codable>(forKey key: String, type: T.Type) -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try decoder.decode(type, from: data)
        } catch {
            print("Failed to decode cached object for key \(key): \(error)")
            // Remove corrupted cache
            removeObject(forKey: key)
            return nil
        }
    }
    
    func removeObject(forKey key: String) {
        userDefaults.removeObject(forKey: key)
        userDefaults.removeObject(forKey: "\(key)_timestamp")
    }
    
    func getCacheTimestamp(forKey key: String) -> Date? {
        let timestampKey = "\(key)_timestamp"
        return userDefaults.object(forKey: timestampKey) as? Date
    }
    
    func isCacheExpired(forKey key: String, expirationInterval: TimeInterval = 3600) -> Bool {
        guard let timestamp = getCacheTimestamp(forKey: key) else {
            return true // No cache exists
        }
        
        return Date().timeIntervalSince(timestamp) > expirationInterval
    }
    
    // MARK: - Clear All Cache
    
    func clearAllCache() {
        let keys = [
            "cached_courses",
            "cached_materials",
            "user_preferences"
        ]
        
        keys.forEach { key in
            removeObject(forKey: key)
        }
    }
}