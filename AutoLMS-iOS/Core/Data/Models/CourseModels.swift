import Foundation

// MARK: - Course Models

struct Course: Codable, Identifiable, Hashable {
    let id: String
    let courseCode: String
    let name: String
    let professor: String?
    let semester: String?
    let classroom: String?
    let schedule: Schedule?
    let color: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case courseCode = "course_code"
        case name, professor, semester, classroom, schedule, color
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CoursesResponse: Codable {
    let courses: [Course]
    let total: Int
}

// MARK: - Schedule Model

struct Schedule: Codable, Hashable {
    let dayOfWeek: Int // 0: 일요일, 1: 월요일, ..., 6: 토요일
    let startTime: String // "09:00"
    let endTime: String // "10:30"
    let weeks: [Int]? // 몇 주차에 수업이 있는지
    
    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "day_of_week"
        case startTime = "start_time"
        case endTime = "end_time"
        case weeks
    }
}