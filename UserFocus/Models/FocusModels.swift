import Foundation

enum FocusMode: String, CaseIterable, Codable {
    case work = "Work"
    case play = "Play"
    case rest = "Rest"
    case sleep = "Sleep"
}

enum BadgeType: String, CaseIterable, Codable {
    case trees = "trees"
    case leavesAndFungi = "leavesAndFungi"
    case animals = "animals"
    
    var badges: [String] {
        switch self {
        case .trees:
            return ["🌵", "🎄", "🌲", "🌳", "🌴"]
        case .leavesAndFungi:
            return ["🍂", "🍁", "🍄"]
        case .animals:
            return ["🐅", "🦅", "🐵", "🐝"]
        }
    }
}

struct Badge: Identifiable, Codable {
    let id: UUID
    let emoji: String
    let type: BadgeType
    let earnedAt: Date
    
    init(emoji: String, type: BadgeType) {
        self.id = UUID()
        self.emoji = emoji
        self.type = type
        self.earnedAt = Date()
    }
}

struct FocusSession: Identifiable, Codable {
    let id: UUID
    let mode: FocusMode
    let startTime: Date
    var endTime: Date?
    var points: Int
    var badges: [Badge]
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
}

struct UserProfile: Codable {
    var name: String
    var imageData: Data?
    var totalPoints: Int
    var badges: [Badge]
    var sessions: [FocusSession]
    
    init(name: String, imageData: Data? = nil) {
        self.name = name
        self.imageData = imageData
        self.totalPoints = 0
        self.badges = []
        self.sessions = []
    }
} 