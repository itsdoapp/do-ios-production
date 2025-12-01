import Foundation

/// Service for fetching workout data (sessions, movements, plans) from AWS
class AWSWorkoutService {
    static let shared = AWSWorkoutService()
    
    // Lambda Function URLs - can be overridden via UserDefaults
    private var getMovementsURL: String {
        return UserDefaults.standard.string(forKey: "getMovementsURL") ?? "https://fliz2ldet2vtodw56nhazyssky0sgtwp.lambda-url.us-east-1.on.aws/"
    }
    
    private var getSessionsURL: String {
        return UserDefaults.standard.string(forKey: "getSessionsURL") ?? "https://g5mvu7ybyfaysp444zrcanoiry0pihgf.lambda-url.us-east-1.on.aws/"
    }
    
    private var getPlansURL: String {
        return UserDefaults.standard.string(forKey: "getPlansURL") ?? "https://ijqijgq5567crspfqihkrg27fu0phmhw.lambda-url.us-east-1.on.aws/"
    }
    
    private var createMovementURL: String {
        return UserDefaults.standard.string(forKey: "createMovementURL") ?? "https://chthsdswaavi5epk55y23b7r2u0igvcb.lambda-url.us-east-1.on.aws/"
    }
    
    private var createSessionURL: String {
        return UserDefaults.standard.string(forKey: "createSessionURL") ?? "https://hkwhj5ke2iztyrbogphqgmjw6y0dutfs.lambda-url.us-east-1.on.aws/"
    }
    
    private var createPlanURL: String {
        return UserDefaults.standard.string(forKey: "createPlanURL") ?? "https://suvvdoloo4s36hneispcvnsbym0soyle.lambda-url.us-east-1.on.aws/"
    }
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    // MARK: - Response Models
    
    struct GetWorkoutResponse: Codable {
        let success: Bool
        let data: [WorkoutItem]?
        let count: Int?
        let error: String?
        let lastEvaluatedKey: String?
    }
    
    // MARK: - Unified WorkoutItem (Backward Compatible)
    
    /// Unified workout item that can represent a Movement, Session, or Plan
    /// This struct decodes from Lambda responses and provides type-safe wrappers
    struct WorkoutItem: Codable {
        let sessionId: String?
        let movementId: String?
        let planId: String?
        let userId: String?
        let name: String?
        let createdAt: String?
        let updatedAt: String?
        let isPublic: Bool?
        let category: String?
        let movementsInSession: [[String: Any]]?
        let movementsInPlan: [[String: Any]]?
        
        // Additional fields from DynamoDB schema
        let movement1Name: String?
        let movement2Name: String?
        let description: String?
        let difficulty: String?
        let duration: String?
        let isDayOfTheWeekPlan: Bool?
        let equipmentNeeded: Bool?
        let tags: [String]?
        let sessions: [String: String]? // For plans - map of day to sessionId
        let movements: [[String: Any]]? // For sessions - embedded movements array
        
        // Additional optional fields that may exist in DynamoDB
        let estimatedDuration: Double?
        let imageURL: String?
        let price: Double?
        let ratingValue: Double?
        let ratingCount: Int?
        let shareCount: Int?
        let useCount: Int?
        let isTemplate: Bool?
        let isSingle: Bool?
        let isTimed: Bool?
        let templateSets: [[String: Any]]?
        let firstSectionSets: [[String: Any]]?
        let secondSectionSets: [[String: Any]]?
        let weavedSets: [[String: Any]]?
        let originalSessionId: String?
        let originalPlanId: String?
        let originalCreatorId: String?
        let isShared: Bool?
        let sharedAt: String?
        let creatorType: String?
        let isPremium: Bool?
        
        enum CodingKeys: String, CodingKey {
            case sessionId, movementId, planId, userId, name, createdAt, updatedAt, isPublic, category
            case movementsInSession, movementsInPlan
            case movement1Name, movement2Name, description, difficulty, duration
            case isDayOfTheWeekPlan, equipmentNeeded, tags, sessions, movements
            case estimatedDuration, imageURL, price, ratingValue, ratingCount
            case shareCount, useCount, isTemplate, isSingle, isTimed, templateSets
            case firstSectionSets, secondSectionSets, weavedSets
            case originalSessionId, originalPlanId, originalCreatorId, isShared, sharedAt
            case creatorType, isPremium
        }
        
        // MARK: - Type Discriminator
        
        /// Determines the type of workout item based on available ID fields
        var itemType: WorkoutItemType {
            if movementId != nil { return .movement }
            if sessionId != nil { return .session }
            if planId != nil { return .plan }
            return .unknown
        }
        
        enum WorkoutItemType {
            case movement
            case session
            case plan
            case unknown
        }
        
        // MARK: - Type-Safe Accessors
        
        /// Returns a type-safe Movement wrapper if this is a movement
        var asMovement: TypedMovement? {
            guard movementId != nil else { return nil }
            return TypedMovement(item: self)
        }
        
        /// Returns a type-safe Session wrapper if this is a session
        var asSession: TypedSession? {
            guard sessionId != nil else { return nil }
            return TypedSession(item: self)
        }
        
        /// Returns a type-safe Plan wrapper if this is a plan
        var asPlan: TypedPlan? {
            guard planId != nil else { return nil }
            return TypedPlan(item: self)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sessionId = try? container.decode(String.self, forKey: .sessionId)
            movementId = try? container.decode(String.self, forKey: .movementId)
            planId = try? container.decode(String.self, forKey: .planId)
            userId = try? container.decode(String.self, forKey: .userId)
            name = try? container.decode(String.self, forKey: .name)
            createdAt = try? container.decode(String.self, forKey: .createdAt)
            updatedAt = try? container.decode(String.self, forKey: .updatedAt)
            isPublic = try? container.decode(Bool.self, forKey: .isPublic)
            category = try? container.decode(String.self, forKey: .category)
            
            // Additional fields
            movement1Name = try? container.decode(String.self, forKey: .movement1Name)
            movement2Name = try? container.decode(String.self, forKey: .movement2Name)
            description = try? container.decode(String.self, forKey: .description)
            difficulty = try? container.decode(String.self, forKey: .difficulty)
            duration = try? container.decode(String.self, forKey: .duration)
            isDayOfTheWeekPlan = try? container.decode(Bool.self, forKey: .isDayOfTheWeekPlan)
            equipmentNeeded = try? container.decode(Bool.self, forKey: .equipmentNeeded)
            tags = try? container.decode([String].self, forKey: .tags)
            
            // Additional optional fields
            estimatedDuration = try? container.decode(Double.self, forKey: .estimatedDuration)
            imageURL = try? container.decode(String.self, forKey: .imageURL)
            price = try? container.decode(Double.self, forKey: .price)
            ratingValue = try? container.decode(Double.self, forKey: .ratingValue)
            ratingCount = try? container.decode(Int.self, forKey: .ratingCount)
            shareCount = try? container.decode(Int.self, forKey: .shareCount)
            useCount = try? container.decode(Int.self, forKey: .useCount)
            isTemplate = try? container.decode(Bool.self, forKey: .isTemplate)
            isSingle = try? container.decode(Bool.self, forKey: .isSingle)
            isTimed = try? container.decode(Bool.self, forKey: .isTimed)
            originalSessionId = try? container.decode(String.self, forKey: .originalSessionId)
            originalPlanId = try? container.decode(String.self, forKey: .originalPlanId)
            originalCreatorId = try? container.decode(String.self, forKey: .originalCreatorId)
            isShared = try? container.decode(Bool.self, forKey: .isShared)
            sharedAt = try? container.decode(String.self, forKey: .sharedAt)
            creatorType = try? container.decode(String.self, forKey: .creatorType)
            isPremium = try? container.decode(Bool.self, forKey: .isPremium)
            
            // Handle templateSets as Any
            if let setsData = try? container.decode(AnyCodable.self, forKey: .templateSets) {
                templateSets = setsData.value as? [[String: Any]]
            } else {
                templateSets = nil
            }
            
            // Handle firstSectionSets, secondSectionSets, and weavedSets as Any
            if let setsData = try? container.decode(AnyCodable.self, forKey: .firstSectionSets) {
                firstSectionSets = setsData.value as? [[String: Any]]
            } else {
                firstSectionSets = nil
            }
            
            if let setsData = try? container.decode(AnyCodable.self, forKey: .secondSectionSets) {
                secondSectionSets = setsData.value as? [[String: Any]]
            } else {
                secondSectionSets = nil
            }
            
            if let setsData = try? container.decode(AnyCodable.self, forKey: .weavedSets) {
                weavedSets = setsData.value as? [[String: Any]]
            } else {
                weavedSets = nil
            }
            
            // Handle sessions map for plans
            // DynamoDB might store it as:
            // 1. Map (M) - correct format: {"Monday": "sessionId1", "Day 1": "sessionId2"}
            // 2. List (L) - legacy/empty: [] or [{"day": "Monday", "sessionId": "xxx"}]
            // 
            // Session values can be:
            // - Session ID: "sessionId123"
            // - Rest day: "Rest Session", "rest", "rest day" (case-insensitive)
            // - Activity: "activityType: running; distance: 5.0; runType: outdoor_run; duration: 1800"
            // Try to decode as [String: String] first (Map)
            if let sessionsData = try? container.decode([String: String].self, forKey: .sessions) {
                sessions = sessionsData
                if let planId = planId {
                    print("✅ [WorkoutItem] Decoded sessions (Map) for plan \(planId): \(sessionsData.count) items")
                }
            } else if let sessionsData = try? container.decode(AnyCodable.self, forKey: .sessions) {
                // Fallback: try to decode as AnyCodable and convert
                if let dict = sessionsData.value as? [String: String] {
                    // Already a Map
                    sessions = dict
                    if let planId = planId {
                        print("✅ [WorkoutItem] Decoded sessions (AnyCodable->Map) for plan \(planId): \(dict.count) items")
                    }
                } else if let dict = sessionsData.value as? [String: Any] {
                    // Convert [String: Any] to [String: String]
                    sessions = dict.compactMapValues { value in
                        if let stringValue = value as? String {
                            return stringValue
                        } else if let stringValue = String(describing: value) as String? {
                            return stringValue
                        }
                        return nil
                    }
                    if let planId = planId {
                        print("✅ [WorkoutItem] Decoded sessions (AnyCodable->Any) for plan \(planId): \(sessions?.count ?? 0) items")
                    }
                } else if let array = sessionsData.value as? [Any] {
                    // Handle List type - convert array to map
                    // Array might be: [] (empty) or [{"day": "Monday", "sessionId": "xxx"}]
                    if array.isEmpty {
                        sessions = nil
                        if let planId = planId {
                            print("⚠️ [WorkoutItem] sessions is empty array for plan \(planId)")
                        }
                    } else {
                        // Try to convert array of objects to map
                        var sessionsMap: [String: String] = [:]
                        for (index, item) in array.enumerated() {
                            if let dict = item as? [String: Any] {
                                // Format: [{"day": "Monday", "sessionId": "xxx"}]
                                if let dayKey = dict["day"] as? String ?? dict["Day"] as? String,
                                   let sessionId = dict["sessionId"] as? String ?? dict["id"] as? String {
                                    sessionsMap[dayKey] = sessionId
                                }
                            } else if let sessionId = item as? String {
                                // Format: ["sessionId1", "sessionId2"] -> convert to {"Day 1": "sessionId1", ...}
                                sessionsMap["Day \(index + 1)"] = sessionId
                            }
                        }
                        sessions = sessionsMap.isEmpty ? nil : sessionsMap
                        if let planId = planId {
                            if let finalSessions = sessions {
                                print("✅ [WorkoutItem] Converted sessions (List->Map) for plan \(planId): \(finalSessions.count) items")
                            } else {
                                print("⚠️ [WorkoutItem] Could not convert sessions array for plan \(planId)")
                            }
                        }
                    }
            } else {
                sessions = nil
                    if let planId = planId {
                        print("⚠️ [WorkoutItem] Could not decode sessions for plan \(planId), value type: \(type(of: sessionsData.value))")
                    }
                }
            } else {
                sessions = nil
                // Only log if this is actually a plan (has planId)
                if planId != nil {
                    // Check if the key exists but failed to decode
                    if container.contains(.sessions) {
                        print("⚠️ [WorkoutItem] sessions key exists for plan \(planId ?? "unknown") but failed to decode")
                    }
                }
            }
            
            // Handle movements array for sessions (embedded movements)
            if let movementsData = try? container.decode(AnyCodable.self, forKey: .movements) {
                movements = movementsData.value as? [[String: Any]]
            } else {
                movements = nil
            }
            
            // Handle movementsInSession and movementsInPlan as Any (legacy/fallback)
            if let movementsData = try? container.decode(AnyCodable.self, forKey: .movementsInSession) {
                movementsInSession = movementsData.value as? [[String: Any]]
            } else {
                movementsInSession = nil
            }
            
            if let movementsData = try? container.decode(AnyCodable.self, forKey: .movementsInPlan) {
                movementsInPlan = movementsData.value as? [[String: Any]]
            } else {
                movementsInPlan = nil
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(sessionId, forKey: .sessionId)
            try container.encodeIfPresent(movementId, forKey: .movementId)
            try container.encodeIfPresent(planId, forKey: .planId)
            try container.encodeIfPresent(userId, forKey: .userId)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
            try container.encodeIfPresent(isPublic, forKey: .isPublic)
            try container.encodeIfPresent(category, forKey: .category)
            
            // Additional fields
            try container.encodeIfPresent(movement1Name, forKey: .movement1Name)
            try container.encodeIfPresent(movement2Name, forKey: .movement2Name)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(difficulty, forKey: .difficulty)
            try container.encodeIfPresent(duration, forKey: .duration)
            try container.encodeIfPresent(isDayOfTheWeekPlan, forKey: .isDayOfTheWeekPlan)
            try container.encodeIfPresent(equipmentNeeded, forKey: .equipmentNeeded)
            try container.encodeIfPresent(tags, forKey: .tags)
            try container.encodeIfPresent(sessions, forKey: .sessions)
            
            // Additional optional fields
            try container.encodeIfPresent(estimatedDuration, forKey: .estimatedDuration)
            try container.encodeIfPresent(imageURL, forKey: .imageURL)
            try container.encodeIfPresent(price, forKey: .price)
            try container.encodeIfPresent(ratingValue, forKey: .ratingValue)
            try container.encodeIfPresent(ratingCount, forKey: .ratingCount)
            try container.encodeIfPresent(shareCount, forKey: .shareCount)
            try container.encodeIfPresent(useCount, forKey: .useCount)
            try container.encodeIfPresent(isTemplate, forKey: .isTemplate)
            try container.encodeIfPresent(isSingle, forKey: .isSingle)
            try container.encodeIfPresent(isTimed, forKey: .isTimed)
            try container.encodeIfPresent(originalSessionId, forKey: .originalSessionId)
            try container.encodeIfPresent(originalPlanId, forKey: .originalPlanId)
            try container.encodeIfPresent(originalCreatorId, forKey: .originalCreatorId)
            try container.encodeIfPresent(isShared, forKey: .isShared)
            try container.encodeIfPresent(sharedAt, forKey: .sharedAt)
            try container.encodeIfPresent(creatorType, forKey: .creatorType)
            try container.encodeIfPresent(isPremium, forKey: .isPremium)
            
            // Encode templateSets
            if let templateSets = templateSets {
                let codableArray = templateSets.map { dict in
                    AnyCodable(value: dict)
                }
                try container.encode(codableArray, forKey: .templateSets)
            }
            
            // Encode firstSectionSets, secondSectionSets, and weavedSets
            if let firstSectionSets = firstSectionSets {
                let codableArray = firstSectionSets.map { dict in
                    AnyCodable(value: dict)
                }
                try container.encode(codableArray, forKey: .firstSectionSets)
            }
            
            if let secondSectionSets = secondSectionSets {
                let codableArray = secondSectionSets.map { dict in
                    AnyCodable(value: dict)
                }
                try container.encode(codableArray, forKey: .secondSectionSets)
            }
            
            if let weavedSets = weavedSets {
                let codableArray = weavedSets.map { dict in
                    AnyCodable(value: dict)
                }
                try container.encode(codableArray, forKey: .weavedSets)
            }
            
            // Encode movements array
            if let movements = movements {
                let codableArray = movements.map { dict in
                    AnyCodable(value: dict)
                }
                try container.encode(codableArray, forKey: .movements)
            }
            
            // Encode movementsInSession and movementsInPlan using AnyCodable (legacy/fallback)
            if let movementsInSession = movementsInSession {
                let codableArray = movementsInSession.map { dict in
                    AnyCodable(value: dict)
                }
                try container.encode(codableArray, forKey: .movementsInSession)
            }
            
            if let movementsInPlan = movementsInPlan {
                let codableArray = movementsInPlan.map { dict in
                    AnyCodable(value: dict)
                }
                try container.encode(codableArray, forKey: .movementsInPlan)
            }
        }
    }
    
    // MARK: - Type-Safe Wrappers
    
    /// Type-safe wrapper for Movement items
    struct TypedMovement {
        let item: WorkoutItem
        
        var movementId: String { item.movementId ?? "" }
        var name: String { item.movement1Name ?? item.name ?? "" }
        var movement1Name: String { item.movement1Name ?? item.name ?? "" }
        var movement2Name: String? { item.movement2Name }
        var description: String? { item.description }
        var category: String? { item.category }
        var difficulty: String? { item.difficulty }
        var isSingle: Bool? { item.isSingle }
        var isTimed: Bool? { item.isTimed }
        var equipmentNeeded: Bool? { item.equipmentNeeded }
        var tags: [String]? { item.tags }
        var templateSets: [[String: Any]]? { item.templateSets }
        var userId: String? { item.userId }
        var createdAt: String? { item.createdAt }
        var updatedAt: String? { item.updatedAt }
        var isPublic: Bool? { item.isPublic }
        var isTemplate: Bool? { item.isTemplate }
        var price: Double? { item.price }
        var ratingValue: Double? { item.ratingValue }
        var ratingCount: Int? { item.ratingCount }
    }
    
    /// Type-safe wrapper for Session items
    struct TypedSession {
        let item: WorkoutItem
        
        var sessionId: String { item.sessionId ?? "" }
        var name: String { item.name ?? "" }
        var description: String? { item.description }
        var difficulty: String? { item.difficulty }
        var equipmentNeeded: Bool? { item.equipmentNeeded }
        var estimatedDuration: Double? { item.estimatedDuration }
        var tags: [String]? { item.tags }
        var movements: [[String: Any]]? { item.movements ?? item.movementsInSession }
        var originalSessionId: String? { item.originalSessionId }
        var originalCreatorId: String? { item.originalCreatorId }
        var isShared: Bool? { item.isShared }
        var sharedAt: String? { item.sharedAt }
        var userId: String? { item.userId }
        var createdAt: String? { item.createdAt }
        var updatedAt: String? { item.updatedAt }
        var isPublic: Bool? { item.isPublic }
        var category: String? { item.category }
        var price: Double? { item.price }
        var ratingValue: Double? { item.ratingValue }
        var ratingCount: Int? { item.ratingCount }
    }
    
    /// Type-safe wrapper for Plan items
    struct TypedPlan {
        let item: WorkoutItem
        
        var planId: String { item.planId ?? "" }
        var name: String { item.name ?? "" }
        var description: String? { item.description }
        var category: String? { item.category }
        var difficulty: String? { item.difficulty }
        var equipmentNeeded: Bool? { item.equipmentNeeded }
        var tags: [String]? { item.tags }
        var duration: String? { item.duration }
        var isDayOfTheWeekPlan: Bool? { item.isDayOfTheWeekPlan }
        var imageURL: String? { item.imageURL }
        var sessions: [String: String]? { item.sessions }
        var originalPlanId: String? { item.originalPlanId }
        var originalCreatorId: String? { item.originalCreatorId }
        var isShared: Bool? { item.isShared }
        var sharedAt: String? { item.sharedAt }
        var userId: String? { item.userId }
        var createdAt: String? { item.createdAt }
        var updatedAt: String? { item.updatedAt }
        var isPublic: Bool? { item.isPublic }
        var price: Double? { item.price }
        var creatorType: String? { item.creatorType }
        var isPremium: Bool? { item.isPremium }
        var ratingValue: Double? { item.ratingValue }
        var ratingCount: Int? { item.ratingCount }
    }
    
    // Helper for decoding Any type
    private struct AnyCodable: Codable {
        let value: Any
        
        init(value: Any) {
            self.value = value
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let bool = try? container.decode(Bool.self) {
                value = bool
            } else if let int = try? container.decode(Int.self) {
                value = int
            } else if let double = try? container.decode(Double.self) {
                value = double
            } else if let string = try? container.decode(String.self) {
                value = string
            } else if let array = try? container.decode([AnyCodable].self) {
                value = array.map { $0.value }
            } else if let dict = try? container.decode([String: AnyCodable].self) {
                value = dict.mapValues { $0.value }
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            if let bool = value as? Bool {
                try container.encode(bool)
            } else if let int = value as? Int {
                try container.encode(int)
            } else if let double = value as? Double {
                try container.encode(double)
            } else if let string = value as? String {
                try container.encode(string)
            } else if let array = value as? [AnyCodable] {
                try container.encode(array)
            } else if let array = value as? [Any] {
                try container.encode(array.map { AnyCodable(value: $0) })
            } else if let dict = value as? [String: AnyCodable] {
                try container.encode(dict)
            } else if let dict = value as? [String: Any] {
                // Convert dictionary values to AnyCodable recursively
                let codableDict = dict.mapValues { AnyCodable(value: $0) }
                try container.encode(codableDict)
            } else {
                // For complex unsupported types, encode as null
                // This service is read-only, so encoding is not critical
                try container.encodeNil()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Get movements for a user
    func getMovements(
        userId: String? = nil,
        isPublic: Bool? = nil,
        isTemplate: Bool? = nil,
        category: String? = nil,
        limit: Int = 100,
        lastEvaluatedKey: String? = nil,
        completion: @escaping (Result<GetWorkoutResponse, Error>) -> Void
    ) {
        guard let url = URL(string: getMovementsURL) else {
            completion(.failure(WorkoutError.invalidURL))
            return
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = []
        
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "userId", value: userId))
        }
        if let isPublic = isPublic {
            queryItems.append(URLQueryItem(name: "isPublic", value: isPublic ? "true" : "false"))
        }
        if let isTemplate = isTemplate {
            queryItems.append(URLQueryItem(name: "isTemplate", value: isTemplate ? "true" : "false"))
        }
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let lastEvaluatedKey = lastEvaluatedKey {
            queryItems.append(URLQueryItem(name: "lastEvaluatedKey", value: lastEvaluatedKey))
        }
        
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let finalURL = components?.url else {
            completion(.failure(WorkoutError.invalidURL))
            return
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        
        // Check cache first
        if let userId = userId, let cached = WorkoutCacheManager.shared.getCachedMovements(userId: userId) {
            print("📦 [AWSWorkoutService] Returning cached movements for userId: \(userId)")
            let cachedResponse = GetWorkoutResponse(
                success: true,
                data: cached,
                count: cached.count,
                error: nil,
                lastEvaluatedKey: nil
            )
            completion(.success(cachedResponse))
            
            // Still fetch in background to update cache
            Task {
                await self.fetchMovementsFromNetwork(userId: userId, isPublic: isPublic, category: category, limit: limit, url: finalURL)
            }
            return
        }
        
        print("📥 [AWSWorkoutService] Fetching movements for userId: \(userId ?? "public")")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [AWSWorkoutService] Error getting movements: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(WorkoutError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [AWSWorkoutService] HTTP error getting movements: \(httpResponse.statusCode)")
                completion(.failure(WorkoutError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(WorkoutError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(GetWorkoutResponse.self, from: data)
                
                if response.success {
                    print("✅ [AWSWorkoutService] Retrieved \(response.data?.count ?? 0) movements")
                    if let lastKey = response.lastEvaluatedKey {
                        print("   Has more: lastEvaluatedKey = \(lastKey)")
                    }
                    
                    // Cache the results (only if no pagination token, meaning first page)
                    if let userId = userId, lastEvaluatedKey == nil, let items = response.data {
                        WorkoutCacheManager.shared.cacheMovements(items, userId: userId)
                    }
                    
                    completion(.success(response))
                } else {
                    completion(.failure(WorkoutError.apiError(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ [AWSWorkoutService] Error decoding movements response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Get sessions for a user
    func getSessions(
        userId: String? = nil,
        isPublic: Bool? = nil,
        category: String? = nil,
        limit: Int = 100,
        lastEvaluatedKey: String? = nil,
        completion: @escaping (Result<GetWorkoutResponse, Error>) -> Void
    ) {
        guard let url = URL(string: getSessionsURL) else {
            completion(.failure(WorkoutError.invalidURL))
            return
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = []
        
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "userId", value: userId))
        }
        if let isPublic = isPublic {
            queryItems.append(URLQueryItem(name: "isPublic", value: isPublic ? "true" : "false"))
        }
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let lastEvaluatedKey = lastEvaluatedKey {
            queryItems.append(URLQueryItem(name: "lastEvaluatedKey", value: lastEvaluatedKey))
        }
        
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let finalURL = components?.url else {
            completion(.failure(WorkoutError.invalidURL))
            return
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        
        // Check cache first
        if let userId = userId, let cached = WorkoutCacheManager.shared.getCachedSessions(userId: userId) {
            print("📦 [AWSWorkoutService] Returning cached sessions for userId: \(userId)")
            let cachedResponse = GetWorkoutResponse(
                success: true,
                data: cached,
                count: cached.count,
                error: nil,
                lastEvaluatedKey: nil
            )
            completion(.success(cachedResponse))
            
            // Still fetch in background to update cache
            Task {
                await self.fetchSessionsFromNetwork(userId: userId, isPublic: isPublic, category: category, limit: limit, url: finalURL)
            }
            return
        }
        
        print("📥 [AWSWorkoutService] Fetching sessions for userId: \(userId ?? "public")")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [AWSWorkoutService] Error getting sessions: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(WorkoutError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [AWSWorkoutService] HTTP error getting sessions: \(httpResponse.statusCode)")
                completion(.failure(WorkoutError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(WorkoutError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(GetWorkoutResponse.self, from: data)
                
                if response.success {
                    print("✅ [AWSWorkoutService] Retrieved \(response.data?.count ?? 0) sessions")
                    if let lastKey = response.lastEvaluatedKey {
                        print("   Has more: lastEvaluatedKey = \(lastKey)")
                    }
                    
                    // Cache the results (only if no pagination token, meaning first page)
                    if let userId = userId, lastEvaluatedKey == nil, let items = response.data {
                        WorkoutCacheManager.shared.cacheSessions(items, userId: userId)
                    }
                    
                    completion(.success(response))
                } else {
                    completion(.failure(WorkoutError.apiError(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ [AWSWorkoutService] Error decoding sessions response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Get plans for a user
    func getPlans(
        userId: String? = nil,
        isPublic: Bool? = nil,
        limit: Int = 100,
        lastEvaluatedKey: String? = nil,
        completion: @escaping (Result<GetWorkoutResponse, Error>) -> Void
    ) {
        guard let url = URL(string: getPlansURL) else {
            completion(.failure(WorkoutError.invalidURL))
            return
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = []
        
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "userId", value: userId))
        }
        if let isPublic = isPublic {
            queryItems.append(URLQueryItem(name: "isPublic", value: isPublic ? "true" : "false"))
        }
        if let lastEvaluatedKey = lastEvaluatedKey {
            queryItems.append(URLQueryItem(name: "lastEvaluatedKey", value: lastEvaluatedKey))
        }
        
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let finalURL = components?.url else {
            completion(.failure(WorkoutError.invalidURL))
            return
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        
        // Check cache first
        if let userId = userId, let cached = WorkoutCacheManager.shared.getCachedPlans(userId: userId) {
            print("📦 [AWSWorkoutService] Returning cached plans for userId: \(userId)")
            let cachedResponse = GetWorkoutResponse(
                success: true,
                data: cached,
                count: cached.count,
                error: nil,
                lastEvaluatedKey: nil
            )
            completion(.success(cachedResponse))
            
            // Still fetch in background to update cache
            Task {
                await self.fetchPlansFromNetwork(userId: userId, isPublic: isPublic, limit: limit, url: finalURL)
            }
            return
        }
        
        print("📥 [AWSWorkoutService] Fetching plans for userId: \(userId ?? "public")")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [AWSWorkoutService] Error getting plans: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(WorkoutError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [AWSWorkoutService] HTTP error getting plans: \(httpResponse.statusCode)")
                completion(.failure(WorkoutError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(WorkoutError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(GetWorkoutResponse.self, from: data)
                
                if response.success {
                    print("✅ [AWSWorkoutService] Retrieved \(response.data?.count ?? 0) plans")
                    if let lastKey = response.lastEvaluatedKey {
                        print("   Has more: lastEvaluatedKey = \(lastKey)")
                    }
                    
                    // Cache the results (only if no pagination token, meaning first page)
                    if let userId = userId, lastEvaluatedKey == nil, let items = response.data {
                        WorkoutCacheManager.shared.cachePlans(items, userId: userId)
                    }
                    
                    completion(.success(response))
                } else {
                    completion(.failure(WorkoutError.apiError(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ [AWSWorkoutService] Error decoding plans response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Background Fetch Methods (for cache updates)
    
    private func fetchMovementsFromNetwork(
        userId: String,
        isPublic: Bool?,
        category: String?,
        limit: Int,
        url: URL
    ) async {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return
            }
            
            let decoder = JSONDecoder()
            let workoutResponse = try decoder.decode(GetWorkoutResponse.self, from: data)
            
            if workoutResponse.success, let items = workoutResponse.data {
                WorkoutCacheManager.shared.cacheMovements(items, userId: userId)
                print("🔄 [AWSWorkoutService] Background cache update: \(items.count) movements")
            }
        } catch {
            print("❌ [AWSWorkoutService] Background fetch error: \(error.localizedDescription)")
        }
    }
    
    private func fetchSessionsFromNetwork(
        userId: String,
        isPublic: Bool?,
        category: String?,
        limit: Int,
        url: URL
    ) async {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return
            }
            
            let decoder = JSONDecoder()
            let workoutResponse = try decoder.decode(GetWorkoutResponse.self, from: data)
            
            if workoutResponse.success, let items = workoutResponse.data {
                WorkoutCacheManager.shared.cacheSessions(items, userId: userId)
                print("🔄 [AWSWorkoutService] Background cache update: \(items.count) sessions")
            }
        } catch {
            print("❌ [AWSWorkoutService] Background fetch error: \(error.localizedDescription)")
        }
    }
    
    private func fetchPlansFromNetwork(
        userId: String,
        isPublic: Bool?,
        limit: Int,
        url: URL
    ) async {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return
            }
            
            let decoder = JSONDecoder()
            let workoutResponse = try decoder.decode(GetWorkoutResponse.self, from: data)
            
            if workoutResponse.success, let items = workoutResponse.data {
                WorkoutCacheManager.shared.cachePlans(items, userId: userId)
                print("🔄 [AWSWorkoutService] Background cache update: \(items.count) plans")
            }
        } catch {
            print("❌ [AWSWorkoutService] Background fetch error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Create & Update Methods
    
    struct CreateMovementResponse: Codable {
        let success: Bool
        let data: WorkoutItem?
        let error: String?
    }
    
    /// Create a new movement via AWS
    func createMovement(
        userId: String,
        movementId: String? = nil,
        movement1Name: String,
        movement2Name: String? = nil,
        isSingle: Bool = true,
        isTimed: Bool = false,
        category: String? = nil,
        difficulty: String? = nil,
        equipmentsNeeded: Bool = false,
        description: String? = nil,
        tags: [String] = [],
        templateSets: [[String: Any]] = [],
        firstSectionSets: [[String: Any]] = [],
        secondSectionSets: [[String: Any]] = [],
        weavedSets: [[String: Any]] = [],
        completion: @escaping (Result<WorkoutItem, Error>) -> Void
    ) {
        guard let url = URL(string: createMovementURL) else {
            completion(.failure(WorkoutError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let finalMovementId = movementId ?? UUID().uuidString
        var body: [String: Any] = [
            "userId": userId,
            "movementId": finalMovementId,
            "movement1Name": movement1Name,
            "isSingle": isSingle,
            "isTimed": isTimed,
            "equipmentsNeeded": equipmentsNeeded,
            "templateSets": templateSets,
            "firstSectionSets": firstSectionSets,
            "secondSectionSets": secondSectionSets,
            "weavedSets": weavedSets
        ]
        
        if let movement2Name = movement2Name {
            body["movement2Name"] = movement2Name
        }
        if let category = category {
            body["category"] = category
        }
        if let difficulty = difficulty {
            body["difficulty"] = difficulty
        }
        if let description = description {
            body["description"] = description
        }
        if !tags.isEmpty {
            body["tags"] = tags
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 [AWSWorkoutService] Creating movement: \(movement1Name)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [AWSWorkoutService] Error creating movement: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(WorkoutError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [AWSWorkoutService] HTTP error creating movement: \(httpResponse.statusCode)")
                completion(.failure(WorkoutError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(WorkoutError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(CreateMovementResponse.self, from: data)
                
                if response.success, let movement = response.data {
                    print("✅ [AWSWorkoutService] Created movement: \(movement.movement1Name ?? "unknown")")
                    completion(.success(movement))
                } else {
                    completion(.failure(WorkoutError.apiError(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ [AWSWorkoutService] Error decoding create movement response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Update an existing movement via AWS (uses same endpoint as create with existing movementId)
    func updateMovement(
        userId: String,
        movementId: String,
        movement1Name: String? = nil,
        movement2Name: String? = nil,
        isSingle: Bool? = nil,
        isTimed: Bool? = nil,
        category: String? = nil,
        difficulty: String? = nil,
        equipmentsNeeded: Bool? = nil,
        description: String? = nil,
        tags: [String]? = nil,
        templateSets: [[String: Any]]? = nil,
        firstSectionSets: [[String: Any]]? = nil,
        secondSectionSets: [[String: Any]]? = nil,
        weavedSets: [[String: Any]]? = nil,
        completion: @escaping (Result<WorkoutItem, Error>) -> Void
    ) {
        // For now, use the same create endpoint (it handles updates if movementId exists)
        // In the future, this could be a PUT/PATCH endpoint
        guard let url = URL(string: createMovementURL) else {
            completion(.failure(WorkoutError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "userId": userId,
            "movementId": movementId
        ]
        
        if let movement1Name = movement1Name {
            body["movement1Name"] = movement1Name
        }
        if let movement2Name = movement2Name {
            body["movement2Name"] = movement2Name
        }
        if let isSingle = isSingle {
            body["isSingle"] = isSingle
        }
        if let isTimed = isTimed {
            body["isTimed"] = isTimed
        }
        if let category = category {
            body["category"] = category
        }
        if let difficulty = difficulty {
            body["difficulty"] = difficulty
        }
        if let equipmentsNeeded = equipmentsNeeded {
            body["equipmentsNeeded"] = equipmentsNeeded
        }
        if let description = description {
            body["description"] = description
        }
        if let tags = tags {
            body["tags"] = tags
        }
        if let templateSets = templateSets {
            body["templateSets"] = templateSets
        }
        if let firstSectionSets = firstSectionSets {
            body["firstSectionSets"] = firstSectionSets
        }
        if let secondSectionSets = secondSectionSets {
            body["secondSectionSets"] = secondSectionSets
        }
        if let weavedSets = weavedSets {
            body["weavedSets"] = weavedSets
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 [AWSWorkoutService] Updating movement: \(movementId)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [AWSWorkoutService] Error updating movement: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(WorkoutError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [AWSWorkoutService] HTTP error updating movement: \(httpResponse.statusCode)")
                completion(.failure(WorkoutError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(WorkoutError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(CreateMovementResponse.self, from: data)
                
                if response.success, let movement = response.data {
                    print("✅ [AWSWorkoutService] Updated movement: \(movement.movement1Name ?? "unknown")")
                    completion(.success(movement))
                } else {
                    completion(.failure(WorkoutError.apiError(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ [AWSWorkoutService] Error decoding update movement response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    struct CreateSessionResponse: Codable {
        let success: Bool
        let data: WorkoutItem?
        let error: String?
    }
    
    /// Create a new session via AWS
    func createSession(
        userId: String,
        sessionId: String? = nil,
        name: String,
        description: String? = nil,
        movements: [[String: Any]] = [],
        difficulty: String? = nil,
        equipmentNeeded: Bool = false,
        tags: [String] = [],
        estimatedDuration: Double? = nil,
        completion: @escaping (Result<WorkoutItem, Error>) -> Void
    ) {
        guard let url = URL(string: createSessionURL) else {
            completion(.failure(WorkoutError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let finalSessionId = sessionId ?? UUID().uuidString
        var body: [String: Any] = [
            "userId": userId,
            "sessionId": finalSessionId,
            "name": name,
            "movements": movements,
            "equipmentNeeded": equipmentNeeded
        ]
        
        if let description = description {
            body["description"] = description
        }
        if let difficulty = difficulty {
            body["difficulty"] = difficulty
        }
        if !tags.isEmpty {
            body["tags"] = tags
        }
        if let estimatedDuration = estimatedDuration {
            body["estimatedDuration"] = estimatedDuration
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 [AWSWorkoutService] Creating session: \(name)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [AWSWorkoutService] Error creating session: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(WorkoutError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [AWSWorkoutService] HTTP error creating session: \(httpResponse.statusCode)")
                completion(.failure(WorkoutError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(WorkoutError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(CreateSessionResponse.self, from: data)
                
                if response.success, let session = response.data {
                    print("✅ [AWSWorkoutService] Created session: \(session.name ?? "unknown")")
                    completion(.success(session))
                } else {
                    completion(.failure(WorkoutError.apiError(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ [AWSWorkoutService] Error decoding create session response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Update an existing session via AWS (uses same endpoint as create with existing sessionId)
    func updateSession(
        userId: String,
        sessionId: String,
        name: String? = nil,
        description: String? = nil,
        movements: [[String: Any]]? = nil,
        difficulty: String? = nil,
        equipmentNeeded: Bool? = nil,
        tags: [String]? = nil,
        estimatedDuration: Double? = nil,
        completion: @escaping (Result<WorkoutItem, Error>) -> Void
    ) {
        guard let url = URL(string: createSessionURL) else {
            completion(.failure(WorkoutError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "userId": userId,
            "sessionId": sessionId
        ]
        
        if let name = name {
            body["name"] = name
        }
        if let description = description {
            body["description"] = description
        }
        if let movements = movements {
            body["movements"] = movements
        }
        if let difficulty = difficulty {
            body["difficulty"] = difficulty
        }
        if let equipmentNeeded = equipmentNeeded {
            body["equipmentNeeded"] = equipmentNeeded
        }
        if let tags = tags {
            body["tags"] = tags
        }
        if let estimatedDuration = estimatedDuration {
            body["estimatedDuration"] = estimatedDuration
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 [AWSWorkoutService] Updating session: \(sessionId)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [AWSWorkoutService] Error updating session: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(WorkoutError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [AWSWorkoutService] HTTP error updating session: \(httpResponse.statusCode)")
                completion(.failure(WorkoutError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(WorkoutError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(CreateSessionResponse.self, from: data)
                
                if response.success, let session = response.data {
                    print("✅ [AWSWorkoutService] Updated session: \(session.name ?? "unknown")")
                    completion(.success(session))
                } else {
                    completion(.failure(WorkoutError.apiError(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ [AWSWorkoutService] Error decoding update session response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    struct CreatePlanResponse: Codable {
        let success: Bool
        let data: WorkoutItem?
        let error: String?
    }
    
    /// Create a new plan via AWS
    func createPlan(
        userId: String,
        planId: String? = nil,
        name: String,
        description: String? = nil,
        sessions: [String: String] = [:],
        isDayOfTheWeekPlan: Bool = false,
        difficulty: String? = nil,
        equipmentNeeded: Bool = false,
        tags: [String] = [],
        duration: String? = nil,
        completion: @escaping (Result<WorkoutItem, Error>) -> Void
    ) {
        guard let url = URL(string: createPlanURL) else {
            completion(.failure(WorkoutError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let finalPlanId = planId ?? UUID().uuidString
        var body: [String: Any] = [
            "userId": userId,
            "planId": finalPlanId,
            "name": name,
            "sessions": sessions,
            "isDayOfTheWeekPlan": isDayOfTheWeekPlan,
            "equipmentNeeded": equipmentNeeded
        ]
        
        if let description = description {
            body["description"] = description
        }
        if let difficulty = difficulty {
            body["difficulty"] = difficulty
        }
        if !tags.isEmpty {
            body["tags"] = tags
        }
        if let duration = duration {
            body["duration"] = duration
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 [AWSWorkoutService] Creating plan: \(name)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [AWSWorkoutService] Error creating plan: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(WorkoutError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [AWSWorkoutService] HTTP error creating plan: \(httpResponse.statusCode)")
                completion(.failure(WorkoutError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(WorkoutError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(CreatePlanResponse.self, from: data)
                
                if response.success, let plan = response.data {
                    print("✅ [AWSWorkoutService] Created plan: \(plan.name ?? "unknown")")
                    completion(.success(plan))
                } else {
                    completion(.failure(WorkoutError.apiError(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ [AWSWorkoutService] Error decoding create plan response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Update an existing plan via AWS (uses same endpoint as create with existing planId)
    func updatePlan(
        userId: String,
        planId: String,
        name: String? = nil,
        description: String? = nil,
        sessions: [String: String]? = nil,
        isDayOfTheWeekPlan: Bool? = nil,
        difficulty: String? = nil,
        equipmentNeeded: Bool? = nil,
        tags: [String]? = nil,
        duration: String? = nil,
        completion: @escaping (Result<WorkoutItem, Error>) -> Void
    ) {
        guard let url = URL(string: createPlanURL) else {
            completion(.failure(WorkoutError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "userId": userId,
            "planId": planId
        ]
        
        if let name = name {
            body["name"] = name
        }
        if let description = description {
            body["description"] = description
        }
        if let sessions = sessions {
            body["sessions"] = sessions
        }
        if let isDayOfTheWeekPlan = isDayOfTheWeekPlan {
            body["isDayOfTheWeekPlan"] = isDayOfTheWeekPlan
        }
        if let difficulty = difficulty {
            body["difficulty"] = difficulty
        }
        if let equipmentNeeded = equipmentNeeded {
            body["equipmentNeeded"] = equipmentNeeded
        }
        if let tags = tags {
            body["tags"] = tags
        }
        if let duration = duration {
            body["duration"] = duration
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 [AWSWorkoutService] Updating plan: \(planId)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [AWSWorkoutService] Error updating plan: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(WorkoutError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [AWSWorkoutService] HTTP error updating plan: \(httpResponse.statusCode)")
                completion(.failure(WorkoutError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(WorkoutError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(CreatePlanResponse.self, from: data)
                
                if response.success, let plan = response.data {
                    print("✅ [AWSWorkoutService] Updated plan: \(plan.name ?? "unknown")")
                    completion(.success(plan))
                } else {
                    completion(.failure(WorkoutError.apiError(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ [AWSWorkoutService] Error decoding update plan response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}

// MARK: - Error Types

enum WorkoutError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case httpError(Int)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .noData:
            return "No data received"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

