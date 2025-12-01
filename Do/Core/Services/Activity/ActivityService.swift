import Foundation
import UIKit

/// Service for saving and retrieving activity logs from AWS
class ActivityService {
    static let shared = ActivityService()
    
    // Lambda Function URLs - Activity Logs (GPS-based)
    private let saveRunURL = "https://jhnf24qivfn74xv6korlm27nry0ebqlj.lambda-url.us-east-1.on.aws/"
    private let getRunsURL = "https://fpetptummhocdjxaq5aveo63va0kagld.lambda-url.us-east-1.on.aws/"
    
    private let saveBikeURL = "https://psmz5y36teqe4bfbakjg552f3m0dupmw.lambda-url.us-east-1.on.aws/"
    private let getBikesURL = "https://zpyj7vndgrteshzwcyp3ll5qq40wmhfd.lambda-url.us-east-1.on.aws/"
    
    private let saveHikeURL = "https://suomfl347m2yxqk7xj26dys5x40tqnmm.lambda-url.us-east-1.on.aws/"
    private let getHikesURL = "https://zbwd2trl3cqfz42h7egprmqkly0iczce.lambda-url.us-east-1.on.aws/"
    
    // Walking Lambda Function URLs
    // Default URLs (can be overridden via UserDefaults)
    private var saveWalkURL: String {
        return UserDefaults.standard.string(forKey: "saveWalkURL") ?? "https://i7rglvcnikkqbgd7bpbqprdrmu0ualhp.lambda-url.us-east-1.on.aws/"
    }
    private var getWalksURL: String {
        return UserDefaults.standard.string(forKey: "getWalksURL") ?? "https://2xdutbwfzxzwkwqgf3eak3qazq0uophi.lambda-url.us-east-1.on.aws/"
    }
    
    // Sports Lambda URLs - will be set after deployment
    // Placeholder URLs - these should be updated with actual Lambda Function URLs after deployment
    // Deployed Sports Function URLs
    // Can be overridden via: UserDefaults.standard.set("https://...", forKey: "saveSportsURL")
    private var saveSportsURL: String {
        // Try to get from UserDefaults first (allows runtime override)
        if let url = UserDefaults.standard.string(forKey: "saveSportsURL"), !url.isEmpty {
            return url
        }
        // Default: Deployed production URL
        return "https://6wdgugu2ve52fr5pta2ntvblzu0emelv.lambda-url.us-east-1.on.aws/"
    }
    private var getSportsURL: String {
        // Try to get from UserDefaults first (allows runtime override)
        if let url = UserDefaults.standard.string(forKey: "getSportsURL"), !url.isEmpty {
            return url
        }
        // Default: Deployed production URL
        return "https://zn2cqidtn77yqxaflrj36kh3di0panyt.lambda-url.us-east-1.on.aws/"
    }
    
    // Swimming Lambda URLs (can be overridden via UserDefaults)
    private var saveSwimURL: String {
        return UserDefaults.standard.string(forKey: "saveSwimURL") ?? "https://jhnf24qivfn74xv6korlm27nry0ebqlj.lambda-url.us-east-1.on.aws/"
    }
    private var getSwimsURL: String {
        return UserDefaults.standard.string(forKey: "getSwimsURL") ?? "https://fpetptummhocdjxaq5aveo63va0kagld.lambda-url.us-east-1.on.aws/"
    }
    
    // Lambda Function URLs - Workout Logs (Gym/Exercise-based)
    private let saveMovementLogURL = "https://hejmy66dumue7einkoa47madhu0hyxqo.lambda-url.us-east-1.on.aws/"
    private let getMovementLogsURL = "https://lvta5dkxdpixjuvt2fshj4krci0uvjum.lambda-url.us-east-1.on.aws/"
    
    private let saveSessionLogURL = "https://atrk42y54uifntfadvmha3636m0qicni.lambda-url.us-east-1.on.aws/"
    private let getSessionLogsURL = "https://w3nrdcqzvl2ejowctodzxgmgxm0gnwji.lambda-url.us-east-1.on.aws/"
    
    private let savePlanLogURL = "https://xgsv775yyyvya7yz3cazljgixi0usnuv.lambda-url.us-east-1.on.aws/"
    private let getPlanLogsURL = "https://w6vjyiwziejeoqpr3su2f2z6li0zcwdn.lambda-url.us-east-1.on.aws/"
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300 // 5 minutes for large uploads
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    // MARK: - Save Activity
    
    /// Save a run activity to AWS
    /// - Parameters:
    ///   - userId: User ID
    ///   - duration: Duration in seconds
    ///   - distance: Distance in meters
    ///   - calories: Calories burned
    ///   - routePoints: Array of location points
    ///   - activityData: Activity-specific data
    ///   - startLocation: Start location
    ///   - endLocation: End location
    ///   - completion: Completion handler with result
    func saveRun(
        userId: String,
        duration: Double,
        distance: Double,
        calories: Double,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        elevationGain: Double? = nil,
        elevationLoss: Double? = nil,
        routePoints: [[String: Any]],
        activityData: [String: Any] = [:],
        startLocation: [String: Any]? = nil,
        endLocation: [String: Any]? = nil,
        isPublic: Bool = true,
        caption: String? = nil,
        completion: @escaping (Result<SaveActivityResponse, Error>) -> Void
    ) {
        guard let url = URL(string: saveRunURL) else {
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "duration": duration,
            "distance": distance,
            "calories": calories,
            "avgHeartRate": avgHeartRate as Any,
            "maxHeartRate": maxHeartRate as Any,
            "elevationGain": elevationGain as Any,
            "elevationLoss": elevationLoss as Any,
            "routePoints": routePoints,
            "activityData": activityData,
            "startLocation": startLocation as Any,
            "endLocation": endLocation as Any,
            "isPublic": isPublic,
            "caption": caption as Any,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "device": "iOS",
            "osVersion": UIDevice.current.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 Saving run activity to AWS...")
        print("   User: \(userId)")
        print("   Distance: \(distance)m")
        print("   Duration: \(duration)s")
        print("   Route Points: \(routePoints.count)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error saving run: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ActivityError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ HTTP error saving run: \(httpResponse.statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("   Response: \(errorString)")
                }
                completion(.failure(ActivityError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(ActivityError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SaveActivityResponse.self, from: data)
                
                if response.success {
                    print("✅ Run saved successfully")
                    print("   Activity ID: \(response.data?.activityId ?? "unknown")")
                    print("   S3 Key: \(response.data?.routeDataS3Key ?? "none")")
                    
                    // Log to challenges
                    if let activityId = response.data?.activityId {
                        ChallengeActivityIntegration.shared.logActivityToChallenges(
                            activityId: activityId,
                            activityType: "run",
                            distance: distance,
                            duration: duration,
                            calories: calories,
                            elevationGain: elevationGain
                        )
                    }
                    
                    completion(.success(response))
                } else {
                    print("❌ Save failed: \(response.error ?? "unknown error")")
                    completion(.failure(ActivityError.saveFailed(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ Error decoding response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Save a bike ride activity to AWS
    func saveBike(
        userId: String,
        duration: Double,
        distance: Double,
        calories: Double,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        elevationGain: Double? = nil,
        elevationLoss: Double? = nil,
        routePoints: [[String: Any]],
        activityData: [String: Any] = [:],
        startLocation: [String: Any]? = nil,
        endLocation: [String: Any]? = nil,
        bikeType: String? = nil,
        avgSpeed: Double? = nil,
        maxSpeed: Double? = nil,
        avgPower: Double? = nil,
        avgCadence: Double? = nil,
        isPublic: Bool = true,
        caption: String? = nil,
        completion: @escaping (Result<SaveActivityResponse, Error>) -> Void
    ) {
        guard let url = URL(string: saveBikeURL) else {
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build body with bike-specific fields
        var body: [String: Any] = [
            "userId": userId,
            "duration": duration,
            "distance": distance,
            "calories": calories,
            "avgHeartRate": avgHeartRate as Any,
            "maxHeartRate": maxHeartRate as Any,
            "elevationGain": elevationGain as Any,
            "elevationLoss": elevationLoss as Any,
            "routePoints": routePoints,
            "activityData": activityData,
            "startLocation": startLocation as Any,
            "endLocation": endLocation as Any,
            "isPublic": isPublic,
            "caption": caption as Any,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "device": "iOS",
            "osVersion": UIDevice.current.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        // Add bike-specific fields
        if let bikeType = bikeType {
            body["bikeType"] = bikeType
        }
        if let avgSpeed = avgSpeed {
            body["avgSpeed"] = avgSpeed
        }
        if let maxSpeed = maxSpeed {
            body["maxSpeed"] = maxSpeed
        }
        if let avgPower = avgPower {
            body["avgPower"] = avgPower
        }
        if let avgCadence = avgCadence {
            body["avgCadence"] = avgCadence
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 Saving bike activity to AWS...")
        print("   User: \(userId)")
        print("   Distance: \(distance)m")
        print("   Duration: \(duration)s")
        print("   Bike Type: \(bikeType ?? "outdoor")")
        print("   Route Points: \(routePoints.count)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error saving bike: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ActivityError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ HTTP error saving bike: \(httpResponse.statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("   Response: \(errorString)")
                }
                completion(.failure(ActivityError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(ActivityError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SaveActivityResponse.self, from: data)
                
                if response.success {
                    print("✅ Bike saved successfully")
                    print("   Activity ID: \(response.data?.activityId ?? "unknown")")
                    print("   S3 Key: \(response.data?.routeDataS3Key ?? "none")")
                    
                    // Log to challenges
                    if let activityId = response.data?.activityId {
                        ChallengeActivityIntegration.shared.logActivityToChallenges(
                            activityId: activityId,
                            activityType: "bike",
                            distance: distance,
                            duration: duration,
                            calories: calories,
                            elevationGain: elevationGain
                        )
                    }
                    
                    completion(.success(response))
                } else {
                    print("❌ Save failed: \(response.error ?? "unknown error")")
                    completion(.failure(ActivityError.saveFailed(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ Error decoding response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Save a sports activity to AWS
    func saveSports(
        userId: String,
        sportType: String,
        duration: Double,
        distance: Double,
        calories: Double,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        elevationGain: Double? = nil,
        elevationLoss: Double? = nil,
        routePoints: [[String: Any]],
        activityData: [String: Any] = [:],
        startLocation: [String: Any]? = nil,
        endLocation: [String: Any]? = nil,
        isPublic: Bool = true,
        caption: String? = nil,
        createdAt: Date? = nil,
        completion: @escaping (Result<SaveActivityResponse, Error>) -> Void
    ) {
        let url = saveSportsURL
        guard !url.isEmpty, let requestURL = URL(string: url) else {
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "sportType": sportType,
            "duration": duration,
            "distance": distance,
            "calories": calories,
            "avgHeartRate": avgHeartRate as Any,
            "maxHeartRate": maxHeartRate as Any,
            "elevationGain": elevationGain as Any,
            "elevationLoss": elevationLoss as Any,
            "routePoints": routePoints,
            "activityData": activityData,
            "startLocation": startLocation as Any,
            "endLocation": endLocation as Any,
            "isPublic": isPublic,
            "caption": caption as Any,
            "createdAt": ISO8601DateFormatter().string(from: createdAt ?? Date()),
            "startDate": ISO8601DateFormatter().string(from: createdAt ?? Date()),
            "device": "iOS",
            "osVersion": UIDevice.current.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 Saving sports activity to AWS...")
        print("   User: \(userId)")
        print("   Sport: \(sportType)")
        print("   Distance: \(distance)m")
        print("   Duration: \(duration)s")
        print("   Route Points: \(routePoints.count)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error saving sports: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ActivityError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ HTTP error saving sports: \(httpResponse.statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("   Response: \(errorString)")
                }
                completion(.failure(ActivityError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(ActivityError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SaveActivityResponse.self, from: data)
                
                if response.success {
                    print("✅ Sports activity saved successfully")
                    print("   Activity ID: \(response.data?.activityId ?? "unknown")")
                    print("   S3 Key: \(response.data?.routeDataS3Key ?? "none")")
                    
                    // Log to challenges
                    if let activityId = response.data?.activityId {
                        ChallengeActivityIntegration.shared.logActivityToChallenges(
                            activityId: activityId,
                            activityType: "sports",
                            distance: distance,
                            duration: duration,
                            calories: calories,
                            elevationGain: elevationGain
                        )
                    }
                    
                    completion(.success(response))
                } else {
                    print("❌ Save failed: \(response.error ?? "unknown error")")
                    completion(.failure(ActivityError.saveFailed(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ Error decoding response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Get sports activities for a user
    func getSports(
        userId: String,
        limit: Int = 20,
        nextToken: String? = nil,
        includeRouteUrls: Bool = true,
        completion: @escaping (Result<GetActivitiesResponse, Error>) -> Void
    ) {
        // Wrapper to match the expected signature - sportType is not used in getAllActivities
        getSportsWithSportType(userId: userId, limit: limit, nextToken: nextToken, sportType: nil, includeRouteUrls: includeRouteUrls, completion: completion)
    }
    
    /// Get sports activities for a user (with sportType parameter)
    func getSports(
        userId: String,
        limit: Int = 20,
        nextToken: String? = nil,
        sportType: String? = nil,
        completion: @escaping (Result<GetActivitiesResponse, Error>) -> Void
    ) {
        // Overload that accepts sportType for backward compatibility
        getSportsWithSportType(userId: userId, limit: limit, nextToken: nextToken, sportType: sportType, includeRouteUrls: true, completion: completion)
    }
    
    /// Get sports activities for a user (internal method with sportType parameter)
    private func getSportsWithSportType(
        userId: String,
        limit: Int = 20,
        nextToken: String? = nil,
        sportType: String? = nil,
        includeRouteUrls: Bool = true,
        completion: @escaping (Result<GetActivitiesResponse, Error>) -> Void
    ) {
        let url = getSportsURL
        guard !url.isEmpty else {
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        var components = URLComponents(string: url)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        if let nextToken = nextToken {
            queryItems.append(URLQueryItem(name: "nextToken", value: nextToken))
        }
        
        if let sportType = sportType {
            queryItems.append(URLQueryItem(name: "sportType", value: sportType))
        }
        
        components?.queryItems = queryItems
        
        guard let finalURL = components?.url else {
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        
        print("📥 Fetching sports activities for user: \(userId)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error getting sports: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ActivityError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ HTTP error getting sports: \(httpResponse.statusCode)")
                completion(.failure(ActivityError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(ActivityError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(GetActivitiesResponse.self, from: data)
                
                if response.success {
                    print("✅ Retrieved \(response.data?.activities.count ?? 0) sports activities")
                    completion(.success(response))
                } else {
                    completion(.failure(ActivityError.saveFailed(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ Error decoding response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Save a hike activity to AWS
    func saveHike(
        userId: String,
        duration: Double,
        distance: Double,
        calories: Double,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        elevationGain: Double? = nil,
        elevationLoss: Double? = nil,
        routePoints: [[String: Any]],
        activityData: [String: Any] = [:],
        startLocation: [String: Any]? = nil,
        endLocation: [String: Any]? = nil,
        isPublic: Bool = true,
        caption: String? = nil,
        completion: @escaping (Result<SaveActivityResponse, Error>) -> Void
    ) {
        saveActivity(
            url: saveHikeURL,
            userId: userId,
            duration: duration,
            distance: distance,
            calories: calories,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            routePoints: routePoints,
            activityData: activityData,
            startLocation: startLocation,
            endLocation: endLocation,
            isPublic: isPublic,
            caption: caption,
            activityType: "hike",
            completion: completion
        )
    }
    
    /// Save a walk activity to AWS
    func saveWalk(
        userId: String,
        duration: Double,
        distance: Double,
        calories: Double,
        steps: Int? = nil,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        elevationGain: Double? = nil,
        elevationLoss: Double? = nil,
        routePoints: [[String: Any]],
        activityData: [String: Any] = [:],
        startLocation: [String: Any]? = nil,
        endLocation: [String: Any]? = nil,
        walkType: String? = nil,
        isPublic: Bool = true,
        caption: String? = nil,
        completion: @escaping (Result<SaveActivityResponse, Error>) -> Void
    ) {
        guard let url = URL(string: saveWalkURL), !saveWalkURL.isEmpty else {
            print("⚠️ SaveWalk URL not configured - update UserDefaults with Lambda Function URL")
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Include steps in activityData if provided
        var finalActivityData = activityData
        if let steps = steps {
            finalActivityData["steps"] = steps
        }
        
        let body: [String: Any] = [
            "userId": userId,
            "duration": duration,
            "distance": distance,
            "calories": calories,
            "steps": steps as Any,
            "avgHeartRate": avgHeartRate as Any,
            "maxHeartRate": maxHeartRate as Any,
            "elevationGain": elevationGain as Any,
            "elevationLoss": elevationLoss as Any,
            "routePoints": routePoints,
            "activityData": finalActivityData,
            "startLocation": startLocation as Any,
            "endLocation": endLocation as Any,
            "walkType": walkType as Any,
            "isPublic": isPublic,
            "caption": caption as Any,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "device": "iOS",
            "osVersion": UIDevice.current.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 Saving walk activity to AWS...")
        print("   User: \(userId)")
        print("   Distance: \(distance)m")
        print("   Duration: \(duration)s")
        print("   Steps: \(steps ?? 0)")
        print("   Route Points: \(routePoints.count)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error saving walk: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ActivityError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ HTTP error saving walk: \(httpResponse.statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("   Response: \(errorString)")
                }
                completion(.failure(ActivityError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(ActivityError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SaveActivityResponse.self, from: data)
                
                if response.success {
                    print("✅ Walk saved successfully")
                    print("   Activity ID: \(response.data?.activityId ?? "unknown")")
                    print("   Steps: \(steps ?? 0)")
                    
                    // Log to challenges
                    if let activityId = response.data?.activityId {
                        ChallengeActivityIntegration.shared.logActivityToChallenges(
                            activityId: activityId,
                            activityType: "walk",
                            distance: distance,
                            duration: duration,
                            calories: calories,
                            elevationGain: elevationGain
                        )
                    }
                    
                    completion(.success(response))
                } else {
                    print("❌ Save failed: \(response.error ?? "unknown error")")
                    completion(.failure(ActivityError.saveFailed(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ Error decoding response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Generic save activity method
    private func saveActivity(
        url: String,
        userId: String,
        duration: Double,
        distance: Double,
        calories: Double,
        avgHeartRate: Double?,
        maxHeartRate: Double?,
        elevationGain: Double?,
        elevationLoss: Double?,
        routePoints: [[String: Any]],
        activityData: [String: Any],
        startLocation: [String: Any]?,
        endLocation: [String: Any]?,
        isPublic: Bool,
        caption: String?,
        activityType: String,
        completion: @escaping (Result<SaveActivityResponse, Error>) -> Void
    ) {
        guard let url = URL(string: url) else {
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "duration": duration,
            "distance": distance,
            "calories": calories,
            "avgHeartRate": avgHeartRate as Any,
            "maxHeartRate": maxHeartRate as Any,
            "elevationGain": elevationGain as Any,
            "elevationLoss": elevationLoss as Any,
            "routePoints": routePoints,
            "activityData": activityData,
            "startLocation": startLocation as Any,
            "endLocation": endLocation as Any,
            "isPublic": isPublic,
            "caption": caption as Any,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "device": "iOS",
            "osVersion": UIDevice.current.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 Saving \(activityType) activity to AWS...")
        print("   User: \(userId)")
        print("   Distance: \(distance)m")
        print("   Duration: \(duration)s")
        print("   Route Points: \(routePoints.count)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error saving \(activityType): \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ActivityError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ HTTP error saving \(activityType): \(httpResponse.statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("   Response: \(errorString)")
                }
                completion(.failure(ActivityError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(ActivityError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SaveActivityResponse.self, from: data)
                
                if response.success {
                    print("✅ \(activityType) saved successfully")
                    print("   Activity ID: \(response.data?.activityId ?? "unknown")")
                    
                    // Log to challenges
                    if let activityId = response.data?.activityId {
                        ChallengeActivityIntegration.shared.logActivityToChallenges(
                            activityId: activityId,
                            activityType: activityType,
                            distance: distance,
                            duration: duration,
                            calories: calories,
                            elevationGain: elevationGain
                        )
                    }
                    
                    completion(.success(response))
                } else {
                    print("❌ Save failed: \(response.error ?? "unknown error")")
                    completion(.failure(ActivityError.saveFailed(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ Error decoding response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Fetch Activities
    
    /// Fetch user's run activities from AWS
    /// - Parameters:
    ///   - userId: User ID
    ///   - limit: Number of activities to fetch (default: 20)
    ///   - nextToken: Pagination token (optional)
    ///   - includeRouteUrls: Whether to include S3 signed URLs for route data
    ///   - completion: Completion handler with result
    func getRuns(
        userId: String,
        limit: Int = 20,
        nextToken: String? = nil,
        includeRouteUrls: Bool = true,
        completion: @escaping (Result<GetActivitiesResponse, Error>) -> Void
    ) {
        // Validate userId is not empty
        guard !userId.isEmpty else {
            print("❌ [ActivityService.getRuns] userId is empty")
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        var components = URLComponents(string: getRunsURL)!
        var queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "includeRouteUrls", value: includeRouteUrls ? "true" : "false")
        ]
        
        if let nextToken = nextToken {
            queryItems.append(URLQueryItem(name: "nextToken", value: nextToken))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            print("❌ [ActivityService.getRuns] Failed to create URL from components")
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        // Verify userId is in the URL
        if let urlString = url.absoluteString.removingPercentEncoding,
           !urlString.contains("userId=\(userId)") && !url.absoluteString.contains("userId=") {
            print("⚠️ [ActivityService.getRuns] WARNING: userId may not be in URL properly")
            print("   URL string: \(url.absoluteString)")
            print("   Expected userId: \(userId)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("📥 [ActivityService.getRuns] Fetching runs from AWS...")
        print("   Base URL: \(getRunsURL)")
        print("   Final URL: \(url.absoluteString)")
        print("   User ID: \(userId) (length: \(userId.count))")
        print("   Limit: \(limit)")
        print("   NextToken: \(nextToken ?? "nil")")
        print("   IncludeRouteUrls: \(includeRouteUrls)")
        
        // Log query parameters for debugging
        if let queryItems = components.queryItems {
            print("   Query parameters:")
            for item in queryItems {
                print("     - \(item.name): \(item.value ?? "nil")")
            }
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [ActivityService.getRuns] Network error fetching runs")
                print("   Error: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   Domain: \(nsError.domain)")
                    print("   Code: \(nsError.code)")
                    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] {
                        print("   Underlying error: \(underlyingError)")
                    }
                }
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [ActivityService.getRuns] Invalid response type")
                completion(.failure(ActivityError.invalidResponse))
                return
            }
            
            print("📊 [ActivityService.getRuns] HTTP Response:")
            print("   Status Code: \(httpResponse.statusCode)")
            print("   Headers: \(httpResponse.allHeaderFields)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [ActivityService.getRuns] HTTP error fetching runs: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("   Response body: \(responseString)")
                } else {
                    print("   No response body available")
                }
                completion(.failure(ActivityError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                print("❌ [ActivityService.getRuns] No data in response")
                completion(.failure(ActivityError.noData))
                return
            }
            
            print("📊 [ActivityService.getRuns] Response data received: \(data.count) bytes")
            
            // Debug: Log raw response
            if let responseString = String(data: data, encoding: .utf8) {
                let preview = String(responseString.prefix(500))
                print("📥 [ActivityService.getRuns] Raw Lambda response (first 500 chars): \(preview)")
                if responseString.count > 500 {
                    print("   ... (truncated, total length: \(responseString.count) chars)")
                }
            } else {
                print("⚠️ [ActivityService.getRuns] Could not decode response as UTF-8 string")
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(GetActivitiesResponse.self, from: data)
                
                print("✅ [ActivityService.getRuns] Successfully decoded response")
                print("   Response success: \(response.success)")
                print("   Activities count: \(response.data?.activities.count ?? 0)")
                print("   Has more: \(response.data?.hasMore ?? false)")
                print("   Next token: \(response.data?.nextToken ?? "nil")")
                
                if response.success {
                    print("✅ [ActivityService.getRuns] Fetched \(response.data?.activities.count ?? 0) runs successfully")
                    completion(.success(response))
                } else {
                    print("❌ [ActivityService.getRuns] Fetch failed: \(response.error ?? "unknown error")")
                    completion(.failure(ActivityError.fetchFailed(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ [ActivityService.getRuns] Error decoding response")
                print("   Decoding error: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        print("   Type mismatch: expected \(type), at path: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("   Value not found: \(type), at path: \(context.codingPath)")
                    case .keyNotFound(let key, let context):
                        print("   Key not found: \(key.stringValue), at path: \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("   Data corrupted at path: \(context.codingPath)")
                        print("   Debug description: \(context.debugDescription)")
                    @unknown default:
                        print("   Unknown decoding error")
                    }
                }
                // Try to log the problematic JSON if possible
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   Problematic JSON (first 1000 chars): \(String(responseString.prefix(1000)))")
                }
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Fetch user's bike activities from AWS
    func getBikes(
        userId: String,
        limit: Int = 20,
        nextToken: String? = nil,
        includeRouteUrls: Bool = true,
        completion: @escaping (Result<GetActivitiesResponse, Error>) -> Void
    ) {
        getActivities(
            url: getBikesURL,
            userId: userId,
            limit: limit,
            nextToken: nextToken,
            includeRouteUrls: includeRouteUrls,
            activityType: "bike",
            completion: completion
        )
    }
    
    /// Fetch user's hike activities from AWS
    func getHikes(
        userId: String,
        limit: Int = 20,
        nextToken: String? = nil,
        includeRouteUrls: Bool = true,
        completion: @escaping (Result<GetActivitiesResponse, Error>) -> Void
    ) {
        getActivities(
            url: getHikesURL,
            userId: userId,
            limit: limit,
            nextToken: nextToken,
            includeRouteUrls: includeRouteUrls,
            activityType: "hike",
            completion: completion
        )
    }
    
    /// Fetch user's walk activities from AWS
    func getWalks(
        userId: String,
        limit: Int = 20,
        nextToken: String? = nil,
        includeRouteUrls: Bool = true,
        completion: @escaping (Result<GetActivitiesResponse, Error>) -> Void
    ) {
        guard !getWalksURL.isEmpty else {
            print("⚠️ GetWalks URL not configured - update UserDefaults with Lambda Function URL")
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        getActivities(
            url: getWalksURL,
            userId: userId,
            limit: limit,
            nextToken: nextToken,
            includeRouteUrls: includeRouteUrls,
            activityType: "walk",
            completion: completion
        )
    }
    
    /// Fetch user's swimming activities from AWS
    func getSwims(
        userId: String,
        limit: Int = 20,
        nextToken: String? = nil,
        includeRouteUrls: Bool = true,
        completion: @escaping (Result<GetActivitiesResponse, Error>) -> Void
    ) {
        guard !getSwimsURL.isEmpty else {
            print("⚠️ GetSwims URL not configured - update UserDefaults with Lambda Function URL")
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        getActivities(
            url: getSwimsURL,
            userId: userId,
            limit: limit,
            nextToken: nextToken,
            includeRouteUrls: includeRouteUrls,
            activityType: "swimming",
            completion: completion
        )
    }
    
    /// Generic fetch activities method
    private func getActivities(
        url: String,
        userId: String,
        limit: Int,
        nextToken: String?,
        includeRouteUrls: Bool,
        activityType: String,
        completion: @escaping (Result<GetActivitiesResponse, Error>) -> Void
    ) {
        var components = URLComponents(string: url)!
        var queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "includeRouteUrls", value: includeRouteUrls ? "true" : "false")
        ]
        
        if let nextToken = nextToken {
            queryItems.append(URLQueryItem(name: "nextToken", value: nextToken))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("📥 Fetching \(activityType) activities from AWS...")
        print("   User: \(userId)")
        print("   Limit: \(limit)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error fetching \(activityType): \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ActivityError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ HTTP error fetching \(activityType): \(httpResponse.statusCode)")
                completion(.failure(ActivityError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(ActivityError.noData))
                return
            }
            
            // Debug: Log raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Raw Lambda response for \(activityType) (first 500 chars): \(String(responseString.prefix(500)))")
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(GetActivitiesResponse.self, from: data)
                
                if response.success {
                    print("✅ Fetched \(response.data?.allActivities.count ?? 0) \(activityType) activities")
                    print("   Has more: \(response.data?.hasMore ?? false)")
                    completion(.success(response))
                } else {
                    print("❌ Fetch failed: \(response.error ?? "unknown error")")
                    completion(.failure(ActivityError.fetchFailed(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ Error decoding response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Fetch full route data from S3 signed URL
    /// - Parameters:
    ///   - signedURL: Signed URL from AWS Lambda
    ///   - completion: Completion handler with decompressed route data
    func fetchRouteData(
        from signedURL: String,
        completion: @escaping (Result<AWSRouteData, Error>) -> Void
    ) {
        guard let url = URL(string: signedURL) else {
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        print("📥 Fetching route data from S3...")
        
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Error fetching route data: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(ActivityError.noData))
                return
            }
            
            do {
                // URLSession automatically decompresses when Content-Encoding: gzip header is present
                // Try to parse directly first
                let decoder = JSONDecoder()
                var routeData: AWSRouteData?
                
                // First try: Direct parse (URLSession auto-decompressed)
                if let parsed = try? decoder.decode(AWSRouteData.self, from: data) {
                    routeData = parsed
                }
                // Second try: Manual decompression (in case auto-decompression didn't work)
                else if let decompressed = try? (data as NSData).decompressed(using: .zlib) as Data,
                        let parsed = try? decoder.decode(AWSRouteData.self, from: decompressed) {
                    routeData = parsed
                }
                
                guard let routeData = routeData else {
                    throw NSError(domain: "RouteDataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse route data"])
                }
                
                print("✅ Fetched route data: \(routeData.points.count) points")
                completion(.success(routeData))
            } catch {
                print("❌ Error decompressing/decoding route data: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Workout Logs (Movement/Session/Plan)
    
    /// Save a movement log (individual exercise completion)
    func saveMovementLog(
        userId: String,
        movementId: String,
        sessionLogId: String? = nil,
        planLogId: String? = nil,
        weavedSets: [[String: Any]],
        firstSectionSets: [[String: Any]],
        secondSectionSets: [[String: Any]],
        sets: [[String: Any]] = [],
        reps: Int? = nil,
        weight: Double? = nil,
        weightUnit: String = "lbs",
        duration: Double? = nil,
        distance: Double? = nil,
        maxWeight: Double? = nil,
        totalVolume: Double? = nil,
        oneRepMax: Double? = nil,
        notes: String? = nil,
        completed: Bool = true,
        skipped: Bool = false,
        isSessionLog: Bool = false,
        completion: @escaping (Result<SaveWorkoutLogResponse, Error>) -> Void
    ) {
        saveWorkoutLog(
            url: saveMovementLogURL,
            userId: userId,
            logType: "movement",
            body: [
                "userId": userId,
                "movementId": movementId,
                "sessionLogId": sessionLogId as Any,
                "planLogId": planLogId as Any,
                "weavedSets": weavedSets,
                "firstSectionSets": firstSectionSets,
                "secondSectionSets": secondSectionSets,
                "sets": sets,
                "reps": reps as Any,
                "weight": weight as Any,
                "weightUnit": weightUnit,
                "duration": duration as Any,
                "distance": distance as Any,
                "maxWeight": maxWeight as Any,
                "totalVolume": totalVolume as Any,
                "oneRepMax": oneRepMax as Any,
                "notes": notes as Any,
                "completed": completed,
                "skipped": skipped,
                "isSessionLog": isSessionLog,
                "createdAt": ISO8601DateFormatter().string(from: Date())
            ],
            completion: completion
        )
    }
    
    /// Get movement logs for a user
    func getMovementLogs(
        userId: String,
        limit: Int = 20,
        nextToken: String? = nil,
        movementId: String? = nil,
        sessionLogId: String? = nil,
        completion: @escaping (Result<GetWorkoutLogsResponse, Error>) -> Void
    ) {
        getWorkoutLogs(
            url: getMovementLogsURL,
            userId: userId,
            limit: limit,
            nextToken: nextToken,
            filters: [
                "movementId": movementId as Any,
                "sessionLogId": sessionLogId as Any
            ],
            completion: completion
        )
    }
    
    /// Save a session log (completed workout session)
    func saveSessionLog(
        userId: String,
        originalSessionId: String,
        planLogId: String? = nil,
        duration: Double? = nil,
        totalVolume: Double? = nil,
        totalSets: Int? = nil,
        totalReps: Int? = nil,
        totalWeight: Double? = nil,
        completed: Bool = true,
        completedAt: Date? = nil,
        skipped: Bool = false,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        calories: Double? = nil,
        notes: String? = nil,
        mood: String? = nil,
        rating: Double? = nil,
        completion: @escaping (Result<SaveWorkoutLogResponse, Error>) -> Void
    ) {
        saveWorkoutLog(
            url: saveSessionLogURL,
            userId: userId,
            logType: "session",
            body: [
                "userId": userId,
                "originalSessionId": originalSessionId,
                "planLogId": planLogId as Any,
                "duration": duration as Any,
                "totalVolume": totalVolume as Any,
                "totalSets": totalSets as Any,
                "totalReps": totalReps as Any,
                "totalWeight": totalWeight as Any,
                "completed": completed,
                "completedAt": completedAt.map { ISO8601DateFormatter().string(from: $0) } as Any,
                "skipped": skipped,
                "avgHeartRate": avgHeartRate as Any,
                "maxHeartRate": maxHeartRate as Any,
                "calories": calories as Any,
                "notes": notes as Any,
                "mood": mood as Any,
                "rating": rating as Any,
                "createdAt": ISO8601DateFormatter().string(from: Date())
            ],
            completion: completion
        )
    }
    
    /// Get session logs for a user
    /// - Parameters:
    ///   - userId: User ID
    ///   - limit: Maximum number of logs to return
    ///   - nextToken: Pagination token
    ///   - originalSessionId: Filter by original session ID
    ///   - activityType: Filter by activity type (e.g., "gym", "swimming", "meditation")
    ///   - completion: Completion handler with result
    func getSessionLogs(
        userId: String,
        limit: Int = 20,
        nextToken: String? = nil,
        originalSessionId: String? = nil,
        activityType: String? = nil,
        completion: @escaping (Result<GetWorkoutLogsResponse, Error>) -> Void
    ) {
        var filters: [String: Any] = [:]
        if let originalSessionId = originalSessionId {
            filters["originalSessionId"] = originalSessionId
        }
        if let activityType = activityType {
            filters["activityType"] = activityType
        }
        
        getWorkoutLogs(
            url: getSessionLogsURL,
            userId: userId,
            limit: limit,
            nextToken: nextToken,
            filters: filters,
            completion: completion
        )
    }
    
    /// Get meditation sessions for a user
    /// Meditation sessions are stored via GenieAPIService, but we can also check session logs
    /// - Parameters:
    ///   - userId: User ID
    ///   - limit: Maximum number of sessions to return
    ///   - nextToken: Pagination token
    ///   - completion: Completion handler with result
    func getMeditations(
        userId: String,
        limit: Int = 20,
        nextToken: String? = nil,
        completion: @escaping (Result<GetWorkoutLogsResponse, Error>) -> Void
    ) {
        // Try to get from session logs first (if meditation sessions are stored there)
        getSessionLogs(
            userId: userId,
            limit: limit,
            nextToken: nextToken,
            activityType: "meditation",
            completion: completion
        )
    }
    
    /// Get all activities for a user (runs, bikes, hikes, walks, sports, swims)
    /// This is a convenience method that fetches all activity types
    func getAllActivities(
        userId: String,
        limit: Int = 20,
        nextToken: String? = nil,
        includeRouteUrls: Bool = true,
        completion: @escaping (Result<[AWSActivity], Error>) -> Void
    ) {
        var allActivities: [AWSActivity] = []
        var errors: [Error] = []
        let dispatchGroup = DispatchGroup()
        
        // Fetch all activity types in parallel
        let activityTypes: [(String, (String, Int, String?, Bool, @escaping (Result<GetActivitiesResponse, Error>) -> Void) -> Void)] = [
            ("run", getRuns),
            ("bike", getBikes),
            ("hike", getHikes),
            ("walk", getWalks),
            ("sports", getSports),
            ("swimming", getSwims)
        ]
        
        for (type, fetchMethod) in activityTypes {
            dispatchGroup.enter()
            fetchMethod(userId, limit, nextToken, includeRouteUrls) { result in
                switch result {
                case .success(let response):
                    if let activities = response.data?.activities {
                        allActivities.append(contentsOf: activities)
                    }
                case .failure(let error):
                    errors.append(error)
                    print("⚠️ [ActivityService] Error fetching \(type): \(error.localizedDescription)")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if errors.isEmpty || !allActivities.isEmpty {
                // Sort by creation date (newest first)
                allActivities.sort { activity1, activity2 in
                    let date1 = ISO8601DateFormatter().date(from: activity1.createdAt) ?? Date.distantPast
                    let date2 = ISO8601DateFormatter().date(from: activity2.createdAt) ?? Date.distantPast
                    return date1 > date2
                }
                
                // Limit to requested limit
                let limitedActivities = Array(allActivities.prefix(limit))
                completion(.success(limitedActivities))
            } else {
                // If all failed, return the first error
                completion(.failure(errors.first ?? ActivityError.fetchFailed("Failed to fetch activities")))
            }
        }
    }
    
    /// Save a plan log (user's progress on a workout plan)
    func savePlanLog(
        userId: String,
        planId: String,
        active: Bool = true,
        startDate: Date? = nil,
        endDate: Date? = nil,
        completedAt: Date? = nil,
        status: String = "active",
        currentWeek: Int = 1,
        currentDay: Int = 1,
        totalWeeks: Int? = nil,
        completedSessions: Int = 0,
        totalSessions: Int = 0,
        completionPercentage: Double = 0,
        notes: String? = nil,
        rating: Double? = nil,
        completion: @escaping (Result<SaveWorkoutLogResponse, Error>) -> Void
    ) {
        saveWorkoutLog(
            url: savePlanLogURL,
            userId: userId,
            logType: "plan",
            body: [
                "userId": userId,
                "planId": planId,
                "active": active,
                "startDate": startDate.map { ISO8601DateFormatter().string(from: $0) } as Any,
                "endDate": endDate.map { ISO8601DateFormatter().string(from: $0) } as Any,
                "completedAt": completedAt.map { ISO8601DateFormatter().string(from: $0) } as Any,
                "status": status,
                "currentWeek": currentWeek,
                "currentDay": currentDay,
                "totalWeeks": totalWeeks as Any,
                "completedSessions": completedSessions,
                "totalSessions": totalSessions,
                "completionPercentage": completionPercentage,
                "notes": notes as Any,
                "rating": rating as Any,
                "createdAt": ISO8601DateFormatter().string(from: Date())
            ],
            completion: completion
        )
    }
    
    /// Get plan logs for a user
    func getPlanLogs(
        userId: String,
        limit: Int = 20,
        nextToken: String? = nil,
        planId: String? = nil,
        active: Bool? = nil,
        completion: @escaping (Result<GetWorkoutLogsResponse, Error>) -> Void
    ) {
        var filters: [String: Any] = [:]
        if let planId = planId { filters["planId"] = planId }
        if let active = active { filters["active"] = active ? "true" : "false" }
        
        getWorkoutLogs(
            url: getPlanLogsURL,
            userId: userId,
            limit: limit,
            nextToken: nextToken,
            filters: filters,
            completion: completion
        )
    }
    
    // Helper methods for workout logs
    private func saveWorkoutLog(
        url: String,
        userId: String,
        logType: String,
        body: [String: Any],
        completion: @escaping (Result<SaveWorkoutLogResponse, Error>) -> Void
    ) {
        guard let url = URL(string: url) else {
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 Saving \(logType) log to AWS...")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error saving \(logType): \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ActivityError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ HTTP error saving \(logType): \(httpResponse.statusCode)")
                completion(.failure(ActivityError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(ActivityError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SaveWorkoutLogResponse.self, from: data)
                
                if response.success {
                    print("✅ \(logType) log saved successfully")
                    
                    // Log to challenges for workouts
                    if logType == "session" || logType == "movement" || logType == "plan" {
                        // Extract activity ID from response
                        let activityId = response.data?.logId ?? UUID().uuidString
                        
                        // Extract duration and calories from body if available
                        var duration: TimeInterval? = nil
                        var calories: Double? = nil
                        
                        if let durationValue = body["duration"] as? Double {
                            duration = durationValue
                        } else if let durationValue = body["duration"] as? Int {
                            duration = TimeInterval(durationValue)
                        }
                        
                        if let caloriesValue = body["calories"] as? Double {
                            calories = caloriesValue
                        }
                        
                        // Only log to challenges if we have a valid duration
                        if let duration = duration {
                            ChallengeActivityIntegration.shared.logActivityToChallenges(
                                activityId: activityId,
                                activityType: "workout",
                                distance: nil,
                                duration: duration,
                                calories: calories,
                                elevationGain: nil
                            )
                        }
                    }
                    
                    completion(.success(response))
                } else {
                    completion(.failure(ActivityError.saveFailed(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ Error decoding response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    private func getWorkoutLogs(
        url: String,
        userId: String,
        limit: Int,
        nextToken: String?,
        filters: [String: Any],
        completion: @escaping (Result<GetWorkoutLogsResponse, Error>) -> Void
    ) {
        var components = URLComponents(string: url)!
        var queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let nextToken = nextToken {
            queryItems.append(URLQueryItem(name: "nextToken", value: nextToken))
        }
        
        for (key, value) in filters {
            if let stringValue = value as? String {
                queryItems.append(URLQueryItem(name: key, value: stringValue))
            }
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            completion(.failure(ActivityError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("📥 Fetching workout logs from AWS...")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error fetching workout logs: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ActivityError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(ActivityError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(ActivityError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(GetWorkoutLogsResponse.self, from: data)
                
                if response.success {
                    print("✅ Fetched \(response.data?.logs.count ?? 0) workout logs")
                    completion(.success(response))
                } else {
                    completion(.failure(ActivityError.fetchFailed(response.error ?? "Unknown error")))
                }
            } catch {
                print("❌ Error decoding response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}

// MARK: - Response Models

struct SaveActivityResponse: Codable {
    let success: Bool
    let data: SaveActivityData?
    let error: String?
    
    struct SaveActivityData: Codable {
        let activityId: String
        let userId: String
        let activityType: String
        let createdAt: String
        let duration: Double
        let distance: Double
        let calories: Double
        let routeDataS3Key: String?
        let totalPoints: Int
    }
}

struct GetActivitiesResponse: Codable {
    let success: Bool
    let data: GetActivitiesData?
    let error: String?
    
    struct GetActivitiesData: Codable {
        let activities: [AWSActivity]
        let nextToken: String?
        let hasMore: Bool
        
        // All endpoints now return consistent "activities" key
        // No need for complex fallback logic
        var allActivities: [AWSActivity] {
            return activities
        }
    }
}

struct AWSActivity: Codable {
    let userId: String
    let activityId: String?
    let activityType: String?  // Made optional - may be missing in migrated data
    let runType: String?       // "outdoor_run" or "treadmill_run" for runs
    let walkType: String?      // "outdoorWalk", "treadmillWalk", etc. for walks
    let createdAt: String
    let updatedAt: String
    
    // Alternative primary key names for different activities
    let runId: String?
    let bikeId: String?
    let hikeId: String?
    let walkId: String?
    
    // Computed property to get the correct activity ID
    var id: String {
        return activityId ?? runId ?? bikeId ?? hikeId ?? walkId ?? ""
    }
    
    // Helper to determine if this is an indoor/treadmill run
    var isIndoorRun: Bool {
        return runType == "treadmill_run" || 
               runType == "indoor" || 
               activityType == "treadmill_run" ||
               activityType == "indoor"
    }
    
    // Helper to determine if this is an indoor/treadmill walk
    var isIndoorWalk: Bool {
        return walkType == "treadmillWalk" ||
               walkType == "indoorWalk" ||
               activityType == "treadmillWalk" ||
               activityType == "indoorWalk"
    }
    
    // Steps count for walks
    let steps: Int?
    
    // Core metadata
    let duration: Double
    let distance: Double
    let calories: Double
    
    // Sports-specific
    let sportType: String?
    
    // Optional metrics
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let elevationGain: Double?
    let elevationLoss: Double?
    
    // Route summary
    let routeDataS3Key: String?
    let routeDataUrl: String?
    let routeDataSize: Int?
    let totalPoints: Int?
    
    // Locations
    let startLocation: Location?
    let endLocation: Location?
    
    // Activity-specific data (stored as JSON string, decoded on demand)
    let activityData: String?
    
    // Treadmill-specific data
    let avgIncline: Double?
    let maxIncline: Double?
    let avgSpeed: Double?
    let maxSpeed: Double?
    let avgCadence: Double?
    
    // Social
    let isPublic: Bool?
    let caption: String?
    
    // Migration
    let parseObjectId: String?
    let migrated: Bool?
    
    struct Location: Codable {
        let lat: Double
        let lon: Double
        let name: String?
    }
    
    // MARK: - Helper Methods
    
    /// Parse activityData JSON string into a dictionary
    var parsedActivityData: [String: Any]? {
        guard let activityDataString = activityData,
              let data = activityDataString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}

struct AWSRouteData: Codable {
    let activityId: String
    let userId: String
    let activityType: String
    let recordedAt: String
    let points: [RoutePoint]
    let metadata: RouteMetadata
    
    struct RoutePoint: Codable {
        let timestamp: String
        let latitude: Double
        let longitude: Double
        let altitude: Double?
        let horizontalAccuracy: Double?
        let verticalAccuracy: Double?
        let speed: Double?
        let course: Double?
        let heartRate: Double?
        let cadence: Double?
    }
    
    struct RouteMetadata: Codable {
        let device: String?
        let osVersion: String?
        let appVersion: String?
        let recordingInterval: Double?
        let migratedFrom: String?
        let parseObjectId: String?
    }
}

// MARK: - Workout Log Response Models

struct SaveWorkoutLogResponse: Codable {
    let success: Bool
    let data: SaveWorkoutLogData?
    let error: String?
    
    struct SaveWorkoutLogData: Codable {
        let logId: String
        let userId: String
        let logType: String
        let createdAt: String
    }
}

struct GetWorkoutLogsResponse: Codable {
    let success: Bool
    let data: GetWorkoutLogsData?
    let error: String?
    
    struct GetWorkoutLogsData: Codable {
        let logs: [WorkoutLog]
        let nextToken: String?
        let hasMore: Bool
    }
}

struct WorkoutLog: Codable {
    let userId: String
    let createdAt: String
    let updatedAt: String?
    
    // Log ID fields - different log types use different field names
    // Movement logs use: logId
    // Session logs use: sessionLogId (but may also have logId)
    // Plan logs use: planLogId (but may also have logId)
    let logId: String? // For movement logs
    let sessionLogId: String? // For session logs (this is the PK for session logs)
    let planLogId: String? // For plan logs (this is the PK for plan logs)
    
    // Computed property to get the appropriate log ID regardless of type
    var id: String {
        return logId ?? sessionLogId ?? planLogId ?? ""
    }
    
    // Movement logs
    let movementId: String?
    
    // Session logs
    let originalSessionId: String?
    let sessionId: String? // Reference to original session template
    
    // Plan logs
    let planId: String?
    let active: Bool?
    
    // Common fields stored as JSON strings - parse on demand
    let weavedSets: String?
    let firstSectionSets: String?
    let secondSectionSets: String?
    let sets: String?
    let notes: String?
    
    // Common metrics
    let duration: Double?
    let calories: Double?
    let completed: Bool?
    let skipped: Bool?
    let totalVolume: Double?
    let totalSets: Int?
    let totalReps: Int?
    let totalWeight: Double?
    
    // Additional session log fields
    let title: String?
    let description: String?
    let startTime: String?
    let endTime: String?
    let movementLogIds: [String]?
    let rating: Double?
    let fatigueLevel: Int?
    let metadata: [String: Any]?
    
    // Additional plan log fields
    let startDate: String?
    let endDate: String?
    let currentWeek: Int?
    let currentDay: String?
    let totalSessions: Int?
    let completedSessions: Int?
    let sessionLogIds: [String]?
    let progress: Double?
    
    // Migration
    let parseObjectId: String?
    let migrated: Bool?
    
    enum CodingKeys: String, CodingKey {
        case userId, createdAt, updatedAt
        case logId, sessionLogId, planLogId
        case movementId, sessionId, originalSessionId, planId, active
        case weavedSets, firstSectionSets, secondSectionSets, sets, notes
        case duration, calories, completed, skipped
        case totalVolume, totalSets, totalReps, totalWeight
        case title, description, startTime, endTime
        case movementLogIds, rating, fatigueLevel, metadata
        case startDate, endDate, currentWeek, currentDay
        case totalSessions, completedSessions, sessionLogIds, progress
        case parseObjectId, migrated
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try? container.decode(String.self, forKey: .updatedAt)
        
        // Handle different log ID field names
        logId = try? container.decode(String.self, forKey: .logId)
        sessionLogId = try? container.decode(String.self, forKey: .sessionLogId)
        planLogId = try? container.decode(String.self, forKey: .planLogId)
        
        // Movement log fields
        movementId = try? container.decode(String.self, forKey: .movementId)
        
        // Session log fields
        sessionId = try? container.decode(String.self, forKey: .sessionId)
        originalSessionId = try? container.decode(String.self, forKey: .originalSessionId)
        
        // Plan log fields
        planId = try? container.decode(String.self, forKey: .planId)
        // Handle active as both Bool and String (Lambda converts string to bool)
        if let activeBool = try? container.decode(Bool.self, forKey: .active) {
            active = activeBool
        } else if let activeString = try? container.decode(String.self, forKey: .active) {
            active = activeString == "true"
        } else {
            active = nil
        }
        
        // Common JSON string fields
        weavedSets = try? container.decode(String.self, forKey: .weavedSets)
        firstSectionSets = try? container.decode(String.self, forKey: .firstSectionSets)
        secondSectionSets = try? container.decode(String.self, forKey: .secondSectionSets)
        sets = try? container.decode(String.self, forKey: .sets)
        notes = try? container.decode(String.self, forKey: .notes)
        
        // Common metrics
        duration = try? container.decode(Double.self, forKey: .duration)
        calories = try? container.decode(Double.self, forKey: .calories)
        completed = try? container.decode(Bool.self, forKey: .completed)
        skipped = try? container.decode(Bool.self, forKey: .skipped)
        totalVolume = try? container.decode(Double.self, forKey: .totalVolume)
        totalSets = try? container.decode(Int.self, forKey: .totalSets)
        totalReps = try? container.decode(Int.self, forKey: .totalReps)
        totalWeight = try? container.decode(Double.self, forKey: .totalWeight)
        
        // Session log specific fields
        title = try? container.decode(String.self, forKey: .title)
        description = try? container.decode(String.self, forKey: .description)
        startTime = try? container.decode(String.self, forKey: .startTime)
        endTime = try? container.decode(String.self, forKey: .endTime)
        movementLogIds = try? container.decode([String].self, forKey: .movementLogIds)
        rating = try? container.decode(Double.self, forKey: .rating)
        fatigueLevel = try? container.decode(Int.self, forKey: .fatigueLevel)
        
        // Handle metadata as Any
        if let metadataData = try? container.decode(ActivityAnyCodable.self, forKey: .metadata) {
            metadata = metadataData.value as? [String: Any]
        } else {
            metadata = nil
        }
        
        // Plan log specific fields
        startDate = try? container.decode(String.self, forKey: .startDate)
        endDate = try? container.decode(String.self, forKey: .endDate)
        currentWeek = try? container.decode(Int.self, forKey: .currentWeek)
        currentDay = try? container.decode(String.self, forKey: .currentDay)
        totalSessions = try? container.decode(Int.self, forKey: .totalSessions)
        completedSessions = try? container.decode(Int.self, forKey: .completedSessions)
        sessionLogIds = try? container.decode([String].self, forKey: .sessionLogIds)
        progress = try? container.decode(Double.self, forKey: .progress)
        
        // Migration
        parseObjectId = try? container.decode(String.self, forKey: .parseObjectId)
        migrated = try? container.decode(Bool.self, forKey: .migrated)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(logId, forKey: .logId)
        try container.encodeIfPresent(sessionLogId, forKey: .sessionLogId)
        try container.encodeIfPresent(planLogId, forKey: .planLogId)
        try container.encodeIfPresent(movementId, forKey: .movementId)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(originalSessionId, forKey: .originalSessionId)
        try container.encodeIfPresent(planId, forKey: .planId)
        try container.encodeIfPresent(active, forKey: .active)
        try container.encodeIfPresent(weavedSets, forKey: .weavedSets)
        try container.encodeIfPresent(firstSectionSets, forKey: .firstSectionSets)
        try container.encodeIfPresent(secondSectionSets, forKey: .secondSectionSets)
        try container.encodeIfPresent(sets, forKey: .sets)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(calories, forKey: .calories)
        try container.encodeIfPresent(completed, forKey: .completed)
        try container.encodeIfPresent(skipped, forKey: .skipped)
        try container.encodeIfPresent(totalVolume, forKey: .totalVolume)
        try container.encodeIfPresent(totalSets, forKey: .totalSets)
        try container.encodeIfPresent(totalReps, forKey: .totalReps)
        try container.encodeIfPresent(totalWeight, forKey: .totalWeight)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encodeIfPresent(movementLogIds, forKey: .movementLogIds)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(fatigueLevel, forKey: .fatigueLevel)
        if let metadata = metadata {
            let codableMetadata = metadata.mapValues { ActivityAnyCodable(value: $0) }
            try container.encode(codableMetadata, forKey: .metadata)
        }
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encodeIfPresent(currentWeek, forKey: .currentWeek)
        try container.encodeIfPresent(currentDay, forKey: .currentDay)
        try container.encodeIfPresent(totalSessions, forKey: .totalSessions)
        try container.encodeIfPresent(completedSessions, forKey: .completedSessions)
        try container.encodeIfPresent(sessionLogIds, forKey: .sessionLogIds)
        try container.encodeIfPresent(progress, forKey: .progress)
        try container.encodeIfPresent(parseObjectId, forKey: .parseObjectId)
        try container.encodeIfPresent(migrated, forKey: .migrated)
    }
}

// MARK: - Helper Types

// Helper for decoding Any type (used for metadata and other dynamic fields)
private struct ActivityAnyCodable: Codable {
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
        } else if let array = try? container.decode([ActivityAnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: ActivityAnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "ActivityAnyCodable value cannot be decoded")
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
        } else if let array = value as? [ActivityAnyCodable] {
            try container.encode(array)
        } else if let array = value as? [Any] {
            try container.encode(array.map { ActivityAnyCodable(value: $0) })
        } else if let dict = value as? [String: ActivityAnyCodable] {
            try container.encode(dict)
        } else if let dict = value as? [String: Any] {
            // Convert dictionary values to ActivityAnyCodable recursively
            let codableDict = dict.mapValues { ActivityAnyCodable(value: $0) }
            try container.encode(codableDict)
        }
    }
}

// MARK: - Errors

enum ActivityError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case httpError(Int)
    case saveFailed(String)
    case fetchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .noData:
            return "No data received"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .saveFailed(let message):
            return "Save failed: \(message)"
        case .fetchFailed(let message):
            return "Fetch failed: \(message)"
        }
    }
}

