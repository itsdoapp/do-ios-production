//
//  PostCellRenderer.swift
//  Do
//
//  Renders the correct post cell based on post type
//

import SwiftUI

// Data structures for exercise carousel
struct ExerciseCarouselItem: Identifiable {
    let id = UUID()
    let name: String
    let sets: [ExerciseSet]
    let isTimed: Bool
}

struct ExerciseSet: Identifiable {
    let id = UUID()
    let weight: Double
    let reps: Int?
    let time: Int?
    let isTimed: Bool
}

struct PostCellRenderer: View {
    let post: Post
    var onDelete: ((String) -> Void)? = nil // Optional delete handler
    
    // Check if current user owns this post
    private var isOwnPost: Bool {
        guard let postUserId = post.createdBy?.userID,
              let currentUserId = UserIDHelper.shared.getCurrentUserID() else {
            return false
        }
        return postUserId == currentUserId
    }
    
    @ViewBuilder
    var body: some View {
        Group {
            switch post.postType {
        case "post":
            // Standard post with image
            StandardPostCell(
                timestamp: post.formattedTimestamp,
                caption: post.postCaption,
                imageUrl: post.mediaUrl,
                interactions: InteractionSummary(
                    heartCount: post.hearts,
                    starCount: post.stars,
                    goatCount: post.goats
                ),
                isOwnPost: isOwnPost,
                userName: post.createdBy?.name,
                userUsername: post.createdBy?.userName,
                userProfileImageUrl: post.createdBy?.profilePictureUrl
            )
            
        case "captionTop", "postCaptionTop":
            // Caption at top of image
            PostCaptionTopCell(
                timestamp: post.formattedTimestamp,
                caption: post.postCaption ?? "",
                imageUrl: post.mediaUrl,
                interactions: InteractionSummary(
                    heartCount: post.hearts,
                    starCount: post.stars,
                    goatCount: post.goats
                ),
                isOwnPost: isOwnPost,
                userName: post.createdBy?.name,
                userUsername: post.createdBy?.userName,
                userProfileImageUrl: post.createdBy?.profilePictureUrl
            )
            
        case "captionCenter", "postCaptionCenter":
            // Caption centered on image
            PostCaptionCenterCell(
                timestamp: post.formattedTimestamp,
                caption: post.postCaption ?? "",
                imageUrl: post.mediaUrl,
                interactions: InteractionSummary(
                    heartCount: post.hearts,
                    starCount: post.stars,
                    goatCount: post.goats
                ),
                isOwnPost: isOwnPost,
                userName: post.createdBy?.name,
                userUsername: post.createdBy?.userName,
                userProfileImageUrl: post.createdBy?.profilePictureUrl
            )
            
        case "captionBottom", "postCaptionBottom":
            // Caption at bottom of image
            PostCaptionBottomCell(
                timestamp: post.formattedTimestamp,
                caption: post.postCaption ?? "",
                imageUrl: post.mediaUrl,
                interactions: InteractionSummary(
                    heartCount: post.hearts,
                    starCount: post.stars,
                    goatCount: post.goats
                ),
                isOwnPost: isOwnPost,
                userName: post.createdBy?.name,
                userUsername: post.createdBy?.userName,
                userProfileImageUrl: post.createdBy?.profilePictureUrl
            )
            
        case "thoughts", "postThoughts":
            // Text-only thoughts post
            PostThoughtsCell(
                timestamp: post.formattedTimestamp,
                thought: post.postCaption ?? "",
                interactions: InteractionSummary(
                    heartCount: post.hearts,
                    starCount: post.stars,
                    goatCount: post.goats
                ),
                isOwnPost: isOwnPost,
                userName: post.createdBy?.name,
                userUsername: post.createdBy?.userName,
                userProfileImageUrl: post.createdBy?.profilePictureUrl
            )
            
        case "workout":
            // Workout post with image
            let profileUrl = post.createdBy?.profilePictureUrl
            PostWorkoutCell(
                timestamp: post.formattedTimestamp,
                caption: post.postCaption,
                workoutImageUrl: post.mediaUrl,
                interactions: InteractionSummary(
                    heartCount: post.hearts,
                    starCount: post.stars,
                    goatCount: post.goats
                ),
                isOwnPost: isOwnPost,
                userName: post.createdBy?.name,
                userUsername: post.createdBy?.userName,
                userProfileImageUrl: profileUrl
            )
            
        case "workoutSession", "workoutSessionActivity":
            // Workout session with stats card
            let attachment = post.attachment
            
            // Extract workout session data from attachment
            let sessionName = attachment?["name"] as? String ?? post.workoutType ?? "Workout"
            let duration = (attachment?["totalTime"] as? String) ?? 
                          (attachment?["duration"] as? String) ?? 
                          (attachment?["durationDisplay"] as? String) ?? "00:00"
            let calories = (attachment?["calories"] as? String) ?? 
                          (attachment?["caloriesDisplay"] as? String) ?? "0"
            
            // Parse movementsInSession to build workout report and exercise data
            let workoutReport = parseWorkoutSessionReport(from: attachment)
            let exerciseData = parseExerciseDataForCarousel(from: attachment)
            
            PostWorkoutSessionCell(
                timestamp: post.formattedTimestamp,
                caption: post.postCaption,
                workoutTitle: sessionName,
                duration: duration,
                calories: calories,
                exercises: workoutReport,
                exerciseData: exerciseData,
                interactions: InteractionSummary(
                    heartCount: post.hearts,
                    starCount: post.stars,
                    goatCount: post.goats
                ),
                isOwnPost: isOwnPost,
                userName: post.createdBy?.name,
                userUsername: post.createdBy?.userName,
                userProfileImageUrl: post.createdBy?.profilePictureUrl
            )
            .onAppear {
                #if DEBUG
                print("🔍 [PostCellRenderer] WorkoutSession postId: \(post.objectId ?? "unknown")")
                if let attachment = attachment {
                    let keys = attachment.keys.joined(separator: ", ")
                    print("🔍 [PostCellRenderer] WorkoutSession attachment keys: [\(keys)]")
                    
                    // Log movementsInSession if it exists
                    if let movements = attachment["movementsInSession"] {
                        print("🔍 [PostCellRenderer] movementsInSession type: \(type(of: movements))")
                        if let movementsArray = movements as? [[String: Any]] {
                            print("🔍 [PostCellRenderer] movementsInSession count: \(movementsArray.count)")
                            if let firstMovement = movementsArray.first {
                                let movementKeys = firstMovement.keys.joined(separator: ", ")
                                print("🔍 [PostCellRenderer] First movement keys: [\(movementKeys)]")
                                // Log first movement details
                                if let movement1Name = firstMovement["movement1Name"] as? String {
                                    print("🔍 [PostCellRenderer] First movement name: \(movement1Name)")
                                }
                                if let weavedSets = firstMovement["weavedSets"] as? [[String: Any]] {
                                    print("🔍 [PostCellRenderer] First movement weavedSets count: \(weavedSets.count)")
                                }
                            }
                        } else {
                            print("⚠️ [PostCellRenderer] movementsInSession is not an array of dictionaries")
                        }
                    } else {
                        print("⚠️ [PostCellRenderer] No movementsInSession key found in attachment")
                    }
                } else {
                    print("⚠️ [PostCellRenderer] WorkoutSession post has no attachment")
                }
                print("🔍 [PostCellRenderer] Workout report result: \(workoutReport)")
                #endif
            }
            
        case "locationActivity":
            // Location-based workout with map and GPS data
            LocationWorkoutPostCell(
                timestamp: post.formattedTimestamp,
                caption: post.postCaption,
                mapImageUrl: post.mapPreviewUrl ?? post.mediaUrl,
                distance: (post.attachment?["distance"] as? String) ?? "",
                duration: (post.attachment?["duration"] as? String) ?? "",
                pace: (post.attachment?["pace"] as? String) ?? "",
                calories: (post.attachment?["calories"] as? String) ?? "",
                interactions: InteractionSummary(
                    heartCount: post.hearts,
                    starCount: post.stars,
                    goatCount: post.goats
                ),
                isOwnPost: isOwnPost,
                userName: post.createdBy?.name,
                userUsername: post.createdBy?.userName,
                userProfileImageUrl: post.createdBy?.profilePictureUrl
            )
            .task {
                // Fetch route data in background if available
                if let routeUrl = post.routeDataUrl {
                    do {
                        let _ = try await RouteDataService.shared.fetchRouteData(from: routeUrl)
                        // Route data is now cached for detail view
                    } catch {
                        print("⚠️ [PostCell] Failed to prefetch route data: \(error)")
                    }
                }
            }
            
        case "workoutActivity":
            // Simple workout post with image (not location-based)
            PostWorkoutCell(
                timestamp: post.formattedTimestamp,
                caption: post.postCaption,
                workoutImageUrl: post.mediaUrl,
                interactions: InteractionSummary(
                    heartCount: post.hearts,
                    starCount: post.stars,
                    goatCount: post.goats
                ),
                isOwnPost: isOwnPost,
                userName: post.createdBy?.name,
                userUsername: post.createdBy?.userName,
                userProfileImageUrl: post.createdBy?.profilePictureUrl
            )
            
        case "workoutClassic":
            // Classic workout with map, elevation chart, and stats
            let profileUrl = post.createdBy?.profilePictureUrl
            let attachment = post.attachment
            
            // Extract values from workoutSnapshot attachment (matches AWS structure)
            let distance = (attachment?["distanceDisplay"] as? String) ?? 
                          (attachment?["distance"] as? String) ?? "0.0 mi"
            let elevationGain = (attachment?["elevationGainDisplay"] as? String) ?? 
                               (attachment?["elevationGain"] as? String) ?? "0 ft"
            let movingTime = (attachment?["durationDisplay"] as? String) ?? 
                            (attachment?["duration"] as? String) ?? 
                            (attachment?["movingTime"] as? String) ?? "0:00"
            let avgPace = (attachment?["paceDisplay"] as? String) ?? 
                         (attachment?["avgPace"] as? String) ?? "0:00/mi"
            
            PostClassicWorkoutCell(
                timestamp: post.formattedTimestamp,
                caption: post.postCaption,
                distance: distance,
                elevationGain: elevationGain,
                movingTime: movingTime,
                avgPace: avgPace,
                routeDataUrl: post.routeDataUrl, // Pass route data URL to load from AWS
                routeDataS3Key: post.routeDataS3Key,
                routePolyline: post.routePolyline,
                mapPreviewUrl: post.mapPreviewUrl,
                fallbackMapImageUrl: post.mediaUrl,
                attachment: post.attachment,
                elevationData: parseElevationData(from: post.attachment), // Parse elevation data
                runType: post.activityType ?? "Outdoor Run",
                interactions: InteractionSummary(
                    heartCount: post.hearts,
                    starCount: post.stars,
                    goatCount: post.goats
                ),
                isOwnPost: isOwnPost,
                userName: post.createdBy?.name,
                userUsername: post.createdBy?.userName,
                userProfileImageUrl: profileUrl
            )
            
        default:
            // Fallback to standard post
            StandardPostCell(
                timestamp: post.formattedTimestamp,
                caption: post.postCaption,
                imageUrl: post.mediaUrl,
                interactions: InteractionSummary(
                    heartCount: post.hearts,
                    starCount: post.stars,
                    goatCount: post.goats
                ),
                isOwnPost: isOwnPost,
                userName: post.createdBy?.name,
                userUsername: post.createdBy?.userName,
                userProfileImageUrl: post.createdBy?.profilePictureUrl
            )
            }
        }
        .environment(\.postId, post.objectId)
    }
    
    // Helper to parse workout session report from attachment
    private func parseWorkoutSessionReport(from attachment: [String: Any]?) -> String {
        guard let attachment = attachment else {
            // No attachment data available - this can happen if the post was created
            // before the attachment field was populated, or if the data wasn't included
            // during migration from Parse to AWS
            return "Workout session data not available"
        }
        
        // Try to get movementsInSession array (could be direct or nested)
        var movementsArray: [[String: Any]]? = attachment["movementsInSession"] as? [[String: Any]]
        
        // If not found, try checking if attachment itself is a nested structure
        if movementsArray == nil || movementsArray?.isEmpty == true {
            // Try alternative keys
            movementsArray = attachment["movements"] as? [[String: Any]] ?? 
                            attachment["loggedMovements"] as? [[String: Any]]
        }
        
        // If still not found, check if we need to parse from a JSON string
        if movementsArray == nil || movementsArray?.isEmpty == true {
            // Check if there's a sessionLog or similar nested structure
            if let sessionLog = attachment["sessionLog"] as? [String: Any],
               let movements = sessionLog["movementsInSession"] as? [[String: Any]] {
                movementsArray = movements
            }
        }
        
        guard let movements = movementsArray, !movements.isEmpty else {
            // Fallback to simple exercises count if available
            if let exercises = attachment["exercises"] as? String {
                return exercises
            }
            // Try to get exercise count
            if let exerciseCount = attachment["exerciseCount"] as? Int {
                return "\(exerciseCount) exercises"
            }
            // Log for debugging
            #if DEBUG
            let keys = attachment.keys.joined(separator: ", ")
            print("⚠️ [PostCellRenderer] No movementsInSession found in attachment. Keys: [\(keys)]")
            #endif
            return "No exercises logged"
        }
        
        // Parse movements and create a social media-friendly summary
        struct MovementSummary {
            let name: String
            let bestSet: String
            let totalSets: Int
            let maxWeight: Double
            let maxReps: Int
        }
        
        let movementSummaries = movements.compactMap { movementDict -> MovementSummary? in
            // Get movement names
            let movement1Name = movementDict["movement1Name"] as? String ?? ""
            let movement2Name = movementDict["movement2Name"] as? String ?? ""
            let movementNames = movement1Name.isEmpty ? movement2Name : (movement2Name.isEmpty ? movement1Name : "\(movement1Name) \(movement2Name)")
            
            guard !movementNames.isEmpty else { return nil }
            
            // Check if movement is timed
            let isTimed = movementDict["isTimed"] as? Bool ?? false
            
            var maxWeight: Double = 0
            var maxReps: Int = 0
            var bestSetString: String? = nil
            var validSetsCount = 0
            
            if let weavedSets = movementDict["weavedSets"] as? [[String: Any]], !weavedSets.isEmpty {
                for set in weavedSets {
                    var weight: Double = 0
                    var reps: Int = 0
                    var time: Int = 0
                    
                    // Parse weight
                    if let weightString = set["weight"] as? String, !weightString.isEmpty, weightString != "0" {
                        weight = Double(weightString) ?? 0
                    } else if let weightNum = set["weight"] as? NSNumber {
                        weight = weightNum.doubleValue
                    }
                    
                    // Parse reps or time
                    if isTimed {
                        if let secString = set["sec"] as? String, !secString.isEmpty, secString != "0" {
                            time = Int(secString) ?? 0
                        } else if let secNum = set["sec"] as? NSNumber {
                            time = secNum.intValue
                        }
                        if time > 0 {
                            validSetsCount += 1
                            if time > maxReps { maxReps = time }
                            
                            // Format time for best set
                            let timeStr: String
                            if time >= 60 {
                                let minutes = time / 60
                                let seconds = time % 60
                                if seconds == 0 {
                                    timeStr = "\(minutes)min"
                                } else {
                                    timeStr = "\(minutes):\(String(format: "%02d", seconds))"
                                }
                            } else {
                                timeStr = "\(time)s"
                            }
                            
                            if weight > 0 {
                                let weightStr = weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(weight))" : String(format: "%.1f", weight)
                                bestSetString = "\(weightStr) lbs × \(timeStr)"
                            } else {
                                bestSetString = timeStr
                            }
                        }
                    } else {
                        if let repsString = set["reps"] as? String, !repsString.isEmpty, repsString != "0" {
                            reps = Int(repsString) ?? 0
                        } else if let repsNum = set["reps"] as? NSNumber {
                            reps = repsNum.intValue
                        }
                        if reps > 0 {
                            validSetsCount += 1
                            if reps > maxReps { maxReps = reps }
                            if weight > maxWeight { maxWeight = weight }
                            
                            // Format best set
                            if weight > 0 {
                                let weightStr = weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(weight))" : String(format: "%.1f", weight)
                                bestSetString = "\(weightStr) lbs × \(reps) reps"
                            } else {
                                bestSetString = "\(reps) reps"
                            }
                        }
                    }
                }
            }
            
            guard validSetsCount > 0, let bestSet = bestSetString else { return nil }
            
            return MovementSummary(
                name: movementNames,
                bestSet: bestSet,
                totalSets: validSetsCount,
                maxWeight: maxWeight,
                maxReps: maxReps
            )
        }
        
        guard !movementSummaries.isEmpty else {
            return "No exercises logged"
        }
        
        // Calculate total stats for summary
        let totalExercises = movementSummaries.count
        let totalSets = movementSummaries.reduce(0) { $0 + $1.totalSets }
        let heaviestWeight = movementSummaries.map { $0.maxWeight }.max() ?? 0
        
        // Sort by weight (heaviest first), then by reps, then limit to top 3
        let sortedMovements = movementSummaries
            .sorted { ($0.maxWeight, Double($0.maxReps)) > ($1.maxWeight, Double($1.maxReps)) }
            .prefix(3)
        
        // Create compact, achievement-focused display
        var lines: [String] = []
        
        // Add summary header
        if totalExercises > 0 {
            lines.append("\(totalExercises) exercise\(totalExercises == 1 ? "" : "s") • \(totalSets) sets")
            if heaviestWeight > 0 {
                let weightStr = heaviestWeight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(heaviestWeight))" : String(format: "%.1f", heaviestWeight)
                lines.append("🔥 Top: \(weightStr) lbs")
            }
            lines.append("") // Spacer
        }
        
        // Show top 3 exercises with highlights
        for (index, movement) in sortedMovements.enumerated() {
            let isTop = index == 0 && movement.maxWeight > 0
            let prefix = isTop ? "🏆" : "•"
            let display = "\(prefix) \(movement.name) — \(movement.bestSet)"
            lines.append(display)
        }
        
        // Add summary if there are more exercises
        if movementSummaries.count > 3 {
            let remaining = movementSummaries.count - 3
            lines.append("")
            lines.append("+ \(remaining) more exercise\(remaining == 1 ? "" : "s")")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // Helper to parse full workout details with all sets
    private func parseFullWorkoutDetails(from attachment: [String: Any]?) -> String {
        guard let attachment = attachment else {
            return "Workout session data not available"
        }
        
        // Try to get movementsInSession array
        var movementsArray: [[String: Any]]? = attachment["movementsInSession"] as? [[String: Any]]
        
        if movementsArray == nil || movementsArray?.isEmpty == true {
            movementsArray = attachment["movements"] as? [[String: Any]] ?? 
                            attachment["loggedMovements"] as? [[String: Any]]
        }
        
        if movementsArray == nil || movementsArray?.isEmpty == true {
            if let sessionLog = attachment["sessionLog"] as? [String: Any],
               let movements = sessionLog["movementsInSession"] as? [[String: Any]] {
                movementsArray = movements
            }
        }
        
        guard let movements = movementsArray, !movements.isEmpty else {
            return "No exercises logged"
        }
        
        // Parse each movement with all sets
        let loggedContent = movements.compactMap { movementDict -> String? in
            let movement1Name = movementDict["movement1Name"] as? String ?? ""
            let movement2Name = movementDict["movement2Name"] as? String ?? ""
            let movementNames = movement1Name.isEmpty ? movement2Name : (movement2Name.isEmpty ? movement1Name : "\(movement1Name) \(movement2Name)")
            
            guard !movementNames.isEmpty else { return nil }
            
            let isTimed = movementDict["isTimed"] as? Bool ?? false
            var setsStrings: [String] = []
            
            if let weavedSets = movementDict["weavedSets"] as? [[String: Any]], !weavedSets.isEmpty {
                for set in weavedSets {
                    var weight: Double = 0
                    var reps: Int = 0
                    var time: Int = 0
                    
                    // Parse weight
                    if let weightString = set["weight"] as? String, !weightString.isEmpty, weightString != "0" {
                        weight = Double(weightString) ?? 0
                    } else if let weightNum = set["weight"] as? NSNumber {
                        weight = weightNum.doubleValue
                    }
                    
                    // Parse reps or time
                    if isTimed {
                        if let secString = set["sec"] as? String, !secString.isEmpty, secString != "0" {
                            time = Int(secString) ?? 0
                        } else if let secNum = set["sec"] as? NSNumber {
                            time = secNum.intValue
                        }
                        if time > 0 {
                            let timeStr: String
                            if time >= 60 {
                                let minutes = time / 60
                                let seconds = time % 60
                                if seconds == 0 {
                                    timeStr = "\(minutes)min"
                                } else {
                                    timeStr = "\(minutes):\(String(format: "%02d", seconds))"
                                }
                            } else {
                                timeStr = "\(time)s"
                            }
                            
                            if weight > 0 {
                                let weightStr = weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(weight))" : String(format: "%.1f", weight)
                                setsStrings.append("\(weightStr) lbs × \(timeStr)")
                            } else {
                                setsStrings.append(timeStr)
                            }
                        }
                    } else {
                        if let repsString = set["reps"] as? String, !repsString.isEmpty, repsString != "0" {
                            reps = Int(repsString) ?? 0
                        } else if let repsNum = set["reps"] as? NSNumber {
                            reps = repsNum.intValue
                        }
                        if reps > 0 {
                            if weight > 0 {
                                let weightStr = weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(weight))" : String(format: "%.1f", weight)
                                setsStrings.append("\(weightStr) lbs × \(reps) reps")
                            } else {
                                setsStrings.append("\(reps) reps")
                            }
                        }
                    }
                }
            }
            
            guard !setsStrings.isEmpty else { return nil }
            
            let setsDisplay = setsStrings.enumerated().map { index, set in
                "Set \(index + 1): \(set)"
            }.joined(separator: "\n  ")
            
            return "• \(movementNames)\n  \(setsDisplay)"
        }
        
        if loggedContent.isEmpty {
            return "No exercises logged"
        }
        
        return loggedContent.joined(separator: "\n\n")
    }
    
    // Helper to parse exercise data for carousel view
    private func parseExerciseDataForCarousel(from attachment: [String: Any]?) -> [ExerciseCarouselItem] {
        guard let attachment = attachment else {
            return []
        }
        
        // Try to get movementsInSession array
        var movementsArray: [[String: Any]]? = attachment["movementsInSession"] as? [[String: Any]]
        
        if movementsArray == nil || movementsArray?.isEmpty == true {
            movementsArray = attachment["movements"] as? [[String: Any]] ?? 
                            attachment["loggedMovements"] as? [[String: Any]]
        }
        
        if movementsArray == nil || movementsArray?.isEmpty == true {
            if let sessionLog = attachment["sessionLog"] as? [String: Any],
               let movements = sessionLog["movementsInSession"] as? [[String: Any]] {
                movementsArray = movements
            }
        }
        
        guard let movements = movementsArray, !movements.isEmpty else {
            return []
        }
        
        return movements.compactMap { movementDict -> ExerciseCarouselItem? in
            let movement1Name = movementDict["movement1Name"] as? String ?? ""
            let movement2Name = movementDict["movement2Name"] as? String ?? ""
            let movementNames = movement1Name.isEmpty ? movement2Name : (movement2Name.isEmpty ? movement1Name : "\(movement1Name) \(movement2Name)")
            
            guard !movementNames.isEmpty else { return nil }
            
            let isTimed = movementDict["isTimed"] as? Bool ?? false
            var sets: [ExerciseSet] = []
            
            if let weavedSets = movementDict["weavedSets"] as? [[String: Any]], !weavedSets.isEmpty {
                for set in weavedSets {
                    var weight: Double = 0
                    var reps: Int = 0
                    var time: Int = 0
                    
                    // Parse weight
                    if let weightString = set["weight"] as? String, !weightString.isEmpty, weightString != "0" {
                        weight = Double(weightString) ?? 0
                    } else if let weightNum = set["weight"] as? NSNumber {
                        weight = weightNum.doubleValue
                    }
                    
                    // Parse reps or time
                    if isTimed {
                        if let secString = set["sec"] as? String, !secString.isEmpty, secString != "0" {
                            time = Int(secString) ?? 0
                        } else if let secNum = set["sec"] as? NSNumber {
                            time = secNum.intValue
                        }
                        if time > 0 {
                            sets.append(ExerciseSet(weight: weight, reps: nil, time: time, isTimed: true))
                        }
                    } else {
                        if let repsString = set["reps"] as? String, !repsString.isEmpty, repsString != "0" {
                            reps = Int(repsString) ?? 0
                        } else if let repsNum = set["reps"] as? NSNumber {
                            reps = repsNum.intValue
                        }
                        if reps > 0 {
                            sets.append(ExerciseSet(weight: weight, reps: reps, time: nil, isTimed: false))
                        }
                    }
                }
            }
            
            guard !sets.isEmpty else { return nil }
            
            return ExerciseCarouselItem(name: movementNames, sets: sets, isTimed: isTimed)
        }
    }
    
    // Helper to parse elevation data from attachment
    private func parseElevationData(from attachment: [String: Any]?) -> [Double]? {
        guard let attachment = attachment else { return nil }
        
        // Try elevationProfile array (from workoutSnapshot - array of objects with "elevation" key)
        if let elevationProfile = attachment["elevationProfile"] as? [[String: Any]] {
            let elevations = elevationProfile.compactMap { dict -> Double? in
                if let elevation = dict["elevation"] as? Double {
                    return elevation
                } else if let elevation = dict["elevation"] as? NSNumber {
                    return elevation.doubleValue
                }
                return nil
            }
            if !elevations.isEmpty {
                return elevations
            }
        }
        
        // Try direct array of doubles
        if let elevationArray = attachment["elevationData"] as? [Double] {
            return elevationArray
        }
        
        if let elevationArray = attachment["elevation"] as? [Double] {
            return elevationArray
        }
        
        // Try array of numbers
        if let elevationNumbers = attachment["elevationData"] as? [NSNumber] {
            return elevationNumbers.map { $0.doubleValue }
        }
        
        // Try string-encoded JSON array
        if let elevationString = attachment["elevationData"] as? String,
           let data = elevationString.data(using: .utf8),
           let elevationArray = try? JSONDecoder().decode([Double].self, from: data) {
            return elevationArray
        }
        
        return nil
    }
}
