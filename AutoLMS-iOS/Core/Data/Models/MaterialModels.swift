import Foundation

// MARK: - Material Models

struct Material: Codable, Identifiable, Hashable {
    let id: String
    let courseId: String
    let title: String
    let content: String?
    let author: String?
    let postedAt: Date
    let isImportant: Bool
    let version: Int
    let replacedBy: String? // 새 버전으로 대체된 경우
    let metadata: [String: AnyCodable]?
    let attachments: [Attachment]
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "course_id"
        case title, content, author
        case postedAt = "posted_at"
        case isImportant = "is_important"
        case version
        case replacedBy = "replaced_by"
        case metadata, attachments
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MaterialsResponse: Codable {
    let materials: [Material]
    let total: Int
}

// MARK: - Attachment Model

struct Attachment: Codable, Identifiable, Hashable {
    let id: String
    let contentId: String
    let filename: String
    let fileSize: Int64
    let mimeType: String?
    let storagePath: String
    let checksum: String?
    let createdAt: Date
    
    // Local properties (not from API)
    var localPath: String?
    var isDownloaded: Bool {
        localPath != nil && FileManager.default.fileExists(atPath: localPath!)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case contentId = "content_id"
        case filename
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case storagePath = "storage_path"
        case checksum
        case createdAt = "created_at"
    }
}

// MARK: - Refresh Response

struct RefreshResponse: Codable {
    let materials: [Material]
    let total: Int
    let message: String
    let crawlResult: CrawlResult?
    
    enum CodingKeys: String, CodingKey {
        case materials, total, message
        case crawlResult = "crawl_result"
    }
}

struct CrawlResult: Codable {
    let materialsAdded: Int
    let attachmentsProcessed: Int
    let processingTime: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case materialsAdded = "materials_added"
        case attachmentsProcessed = "attachments_processed"
        case processingTime = "processing_time"
    }
}

// MARK: - Helper for Dynamic JSON

struct AnyCodable: Codable, Hashable {
    let value: Any
    
    init<T: Codable>(_ value: T) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [AnyCodable]:
            try container.encode(arrayValue)
        case let dictValue as [String: AnyCodable]:
            try container.encode(dictValue)
        default:
            throw EncodingError.invalidValue(value, 
                EncodingError.Context(codingPath: [], debugDescription: "Cannot encode value"))
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch value {
        case let intValue as Int:
            hasher.combine(intValue)
        case let doubleValue as Double:
            hasher.combine(doubleValue)
        case let boolValue as Bool:
            hasher.combine(boolValue)
        case let stringValue as String:
            hasher.combine(stringValue)
        default:
            hasher.combine(0) // Fallback
        }
    }
    
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (let lInt as Int, let rInt as Int):
            return lInt == rInt
        case (let lDouble as Double, let rDouble as Double):
            return lDouble == rDouble
        case (let lBool as Bool, let rBool as Bool):
            return lBool == rBool
        case (let lString as String, let rString as String):
            return lString == rString
        default:
            return false
        }
    }
}