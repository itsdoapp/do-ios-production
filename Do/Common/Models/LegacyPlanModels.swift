import Foundation

/// Simplified legacy plan model used by Genie workout editors.
struct plan: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String = ""
    var description: String?
    var difficulty: String?
    var category: String? // Added for category classification
    var tags: [String] = []
    var sessions: [String: String]? // Dictionary mapping day keys to session IDs or "Rest Session" or activity strings
    var startDate: Date?
    var equipmentNeeded: Bool?
    var isDayOfTheWeekPlan: Bool?
    var numOfRating: Int = 0
    var ratingValue: Double = 0.0
    var isRated: Bool = false
    var duration: String? // Added for plan duration (e.g., "4 weeks", "30 days")
    var imageURL: String? // Added for plan image/thumbnail URL
    
    init() {}
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        difficulty: String? = nil,
        category: String? = nil,
        tags: [String] = [],
        sessions: [String: String]? = nil,
        startDate: Date? = nil,
        equipmentNeeded: Bool? = nil,
        isDayOfTheWeekPlan: Bool? = nil,
        duration: String? = nil,
        imageURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.difficulty = difficulty
        self.category = category
        self.tags = tags
        self.sessions = sessions
        self.startDate = startDate
        self.equipmentNeeded = equipmentNeeded
        self.isDayOfTheWeekPlan = isDayOfTheWeekPlan
        self.duration = duration
        self.imageURL = imageURL
    }
}

extension plan: Equatable {
    static func == (lhs: plan, rhs: plan) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.difficulty == rhs.difficulty &&
        lhs.tags == rhs.tags
    }
}

extension plan: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(difficulty)
        hasher.combine(tags)
    }
}

