//
//  GenieActionHandler.swift
//  Do
//
//  Handles actions from Genie API responses (meditation, videos, equipment, etc.)
//
//  Protocol Documentation: See GENIE_AGENT_IOS_PROTOCOL.md
//  This handler interprets and executes actions sent by the Genie backend agent.
//  The agent autonomously decides what actions to take for the best user experience.
//

import SwiftUI
import AVFoundation
import Foundation

@MainActor
class GenieActionHandler: ObservableObject {
    static let shared = GenieActionHandler()
    
    @Published var showingMeditation = false
    @Published var showingVideoResults = false
    @Published var showingMovementCreator = false
    @Published var showingNutritionLog = false
    @Published var showingMealPlan = false
    @Published var showingMealSuggestions = false
    @Published var showingRestaurantSearch = false
    @Published var showingVisionBoard = false
    @Published var showingManifestation = false
    @Published var showingAffirmation = false
    @Published var showingBedtimeStory = false
    @Published var showingMotivation = false
    @Published var showingGroceryList = false
    @Published var showingCookbook = false
    
    @Published var showingMovementPreview = false
    @Published var showingSessionPreview = false
    @Published var showingPlanPreview = false
    
    @Published var currentMeditation: MeditationAction?
    @Published var currentVideos: VideoResultsAction?
    @Published var currentEquipment: EquipmentAction?
    @Published var currentNutrition: NutritionAction?
    @Published var currentMealPlan: MealPlanAction?
    @Published var currentMealSuggestions: MealSuggestionsAction?
    @Published var currentRestaurantSearch: RestaurantSearchAction?
    @Published var currentVisionBoard: VisionBoardAction?
    @Published var currentManifestation: ManifestationAction?
    @Published var currentAffirmation: AffirmationAction?
    @Published var currentBedtimeStory: BedtimeStoryAction?
    @Published var currentMotivation: MotivationAction?
    
    @Published var currentMovement: WorkoutCreationAction?
    @Published var currentSession: WorkoutCreationAction?
    @Published var currentPlan: WorkoutCreationAction?
    
    private init() {}
    
    // MARK: - Handle Actions
    
    func handleAction(_ action: GenieAction) {
        print("🎯 [ActionHandler] ========================================")
        print("🎯 [ActionHandler] Handling action: \(action.type)")
        print("🎯 [ActionHandler] Action data keys: \(action.data.keys.joined(separator: ", "))")
        print("🎯 [ActionHandler] Full action data: \(action.data)")
        
        // Validate action structure
        guard !action.type.isEmpty else {
            print("❌ [ActionHandler] Invalid action: type is empty")
            return
        }
        
        switch action.type {
        case "meditation":
            handleMeditationAction(action)
        case "equipment_identified":
            handleEquipmentAction(action)
        case "video_results":
            handleVideoResultsAction(action)
        case "nutrition_data":
            handleNutritionAction(action)
        case "form_feedback":
            handleFormFeedbackAction(action)
        case "create_movement":
            handleMovementCreationAction(action)
        case "create_session":
            handleSessionCreationAction(action)
        case "create_plan":
            handlePlanCreationAction(action)
        case "meal_plan":
            handleMealPlanAction(action)
        case "meal_suggestions":
            handleMealSuggestionsAction(action)
        case "restaurant_search":
            handleRestaurantSearchAction(action)
        case "preferences_updated":
            handlePreferencesUpdatedAction(action)
        case "vision_board":
            handleVisionBoardAction(action)
        case "manifestation":
            handleManifestationAction(action)
        case "affirmation":
            handleAffirmationAction(action)
        case "bedtime_story":
            handleBedtimeStoryAction(action)
        case "motivation":
            handleMotivationAction(action)
        case "grocery_list":
            handleGroceryListAction(action)
        case "cookbook":
            handleCookbookAction(action)
        default:
            print("⚠️ [ActionHandler] Unknown action type: '\(action.type)'")
            print("⚠️ [ActionHandler] Available action types: meditation, equipment_identified, video_results, nutrition_data, form_feedback, create_movement, create_session, create_plan, meal_plan, meal_suggestions, restaurant_search, preferences_updated, vision_board, manifestation, affirmation, bedtime_story")
            // Don't crash - gracefully handle unknown actions
            handleUnknownAction(action)
        }
        
        print("🎯 [ActionHandler] Action handling complete")
        print("🎯 [ActionHandler] ========================================")
    }
    
    private func handleUnknownAction(_ action: GenieAction) {
        // Log unknown action for debugging but don't crash
        print("⚠️ [ActionHandler] Skipping unknown action type '\(action.type)'")
        // Could optionally show a user-friendly message
    }
    
    // MARK: - Meditation Action
    
    private func handleMeditationAction(_ action: GenieAction) {
        print("🧘 [ActionHandler] Processing meditation action...")
        print("🧘 [ActionHandler] Action data: \(action.data)")
        
        // Validate required fields according to protocol
        guard let durationValue = action.data["duration"]?.intValue ?? action.data["duration"]?.doubleValue.map({ Int($0) }),
              durationValue >= 3 && durationValue <= 30 else {
            print("❌ [ActionHandler] Invalid meditation action: duration missing or out of range (3-30 min)")
            print("❌ [ActionHandler] Duration value: \(action.data["duration"]?.intValue ?? action.data["duration"]?.doubleValue ?? -1)")
            logActionValidationError(action, missingFields: ["duration (3-30 min)"])
            return
        }
        
        guard let script = action.data["script"]?.stringValue, !script.isEmpty else {
            print("❌ [ActionHandler] Invalid meditation action: script missing or empty")
            print("❌ [ActionHandler] Script: \(action.data["script"]?.stringValue ?? "nil")")
            logActionValidationError(action, missingFields: ["script"])
            return
        }
        
        let duration = durationValue
        
        let focus = action.data["focus"]?.stringValue ?? "stress"
        let focusCategory = action.data["focusCategory"]?.stringValue ?? focus.capitalized
        let isMotivation = action.data["isMotivation"]?.boolValue ?? false
        let playAudio = action.data["playAudio"]?.boolValue ?? true // Default to true if not specified
        let audioUrl = action.data["audioUrl"]?.stringValue
        let audioDuration = action.data["audioDuration"]?.intValue
        
        // Get ambient sound type from agent (if specified), otherwise fall back to focus-based selection
        let ambientSoundTypeString = action.data["ambientSoundType"]?.stringValue
        let ambientType: AmbientSoundType = {
            if let soundType = ambientSoundTypeString {
                // Use agent-specified ambient sound type
                switch soundType.lowercased() {
                case "ocean":
                    return .ocean
                case "rain":
                    return .rain
                case "forest":
                    return .forest
                case "zen":
                    return .zen
                case "white_noise", "whitenoise", "white noise":
                    return .whiteNoise
                default:
                    // Fall back to focus-based selection if unknown type
                    return selectAmbientTypeFromFocus(focus: focus, isMotivation: isMotivation)
                }
            } else {
                // Fall back to focus-based selection if agent didn't specify
                return selectAmbientTypeFromFocus(focus: focus, isMotivation: isMotivation)
            }
        }()
        
        print("✅ [ActionHandler] Meditation action validated successfully")
        print("✅ [ActionHandler] Duration: \(duration) min")
        print("✅ [ActionHandler] Focus: \(focus)")
        print("✅ [ActionHandler] Is Motivation: \(isMotivation)")
        print("✅ [ActionHandler] Play Audio: \(playAudio)")
        print("✅ [ActionHandler] Script length: \(script.count) characters")
        print("✅ [ActionHandler] Script preview: \(script.prefix(100))...")
        print("✅ [ActionHandler] Ambient Sound: \(ambientType.description) (\(ambientSoundTypeString ?? "auto-selected from focus"))")
        
        if let audioUrl = audioUrl {
            print("✅ [ActionHandler] Polly audio URL available: \(audioUrl)")
            if let audioDuration = audioDuration {
                print("✅ [ActionHandler] Audio duration: \(audioDuration) seconds")
            }
        } else {
            print("⚠️ [ActionHandler] No Polly audio URL - will use iOS TTS fallback")
        }
        
        currentMeditation = MeditationAction(
            duration: duration,
            focus: focus,
            isMotivation: isMotivation,
            script: script,
            playAudio: playAudio,
            audioUrl: audioUrl,
            audioDuration: audioDuration,
            ambientSoundType: ambientType
        )
        
        // Prepare meditation audio (but don't start playing yet)
        // Audio will start when showingMeditation becomes true
        if playAudio {
            print("🔊 [ActionHandler] Meditation prepared with \(ambientType.description) ambient sound")
            print("🔊 [ActionHandler] Script length: \(script.count) characters")
            print("🔊 [ActionHandler] Audio will start when user clicks 'Get Started'")
        } else {
            print("⚠️ [ActionHandler] Meditation audio playback disabled")
        }
        
        // Show meditation UI (this will display the meditation interface)
        showingMeditation = true
        
        // Setup lock screen FIRST, before audio starts
        // This ensures the audio session is configured correctly from the start
        let meditationTitle = focusCategory + " Meditation"
        let meditationDuration = TimeInterval(duration * 60)
        MeditationTrackingService.shared.setupLockScreenForActiveMeditation(
            title: meditationTitle,
            duration: meditationDuration,
            notes: "\(focusCategory) • \(duration) min",
            focus: focus
        )
        
        // Start audio playback now that UI is shown
        // Lock screen is already set up, so MeditationAudioService will use .default mode
        if playAudio {
            print("🔊 [ActionHandler] Starting meditation audio playback...")
            MeditationAudioService.shared.playMeditationAudio(
                audioUrl: audioUrl,
                script: script,
                voiceType: .female,
                ambientType: ambientType
            )
            print("🔊 [ActionHandler] Meditation audio playback started")
        }
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .meditationStarted, object: currentMeditation)
        
        print("✅ [ActionHandler] Meditation action complete")
        print("✅ [ActionHandler] - Meditation UI shown (showingMeditation = true)")
        print("✅ [ActionHandler] - Audio playback started")
        print("✅ [ActionHandler] - Notification posted: meditationStarted")
    }
    
    // MARK: - Helper Functions
    
    /// Select ambient sound type based on focus (fallback when agent doesn't specify)
    private func selectAmbientTypeFromFocus(focus: String, isMotivation: Bool) -> AmbientSoundType {
        if isMotivation {
            return .forest
        }
        
        switch focus.lowercased() {
        case "stress", "anxiety":
            return .ocean
        case "sleep", "rest":
            return .rain
        case "focus", "concentration":
            return .zen
        case "motivation", "energy":
            return .forest
        default:
            return .ocean
        }
    }
    
    // MARK: - Validation Helpers
    
    private func logActionValidationError(_ action: GenieAction, missingFields: [String]) {
        print("❌ [ActionHandler] Action validation failed!")
        print("❌ [ActionHandler] Action type: \(action.type)")
        print("❌ [ActionHandler] Missing/invalid fields: \(missingFields.joined(separator: ", "))")
        print("❌ [ActionHandler] Received data keys: \(action.data.keys.joined(separator: ", "))")
        print("❌ [ActionHandler] This action will be skipped. Agent should include all required fields.")
        print("❌ [ActionHandler] See GENIE_AGENT_IOS_PROTOCOL.md for required fields.")
    }
    
    // MARK: - Equipment Action
    
    private func handleEquipmentAction(_ action: GenieAction) {
        guard let name = action.data["name"]?.stringValue,
              let description = action.data["description"]?.stringValue else {
            print("❌ [ActionHandler] Invalid equipment action data")
            return
        }
        
        let category = action.data["category"]?.stringValue ?? "other"
        
        currentEquipment = EquipmentAction(
            name: name,
            description: description,
            category: category
        )
        
        print("✅ [ActionHandler] Equipment identified: \(name) (\(category))")
        
        // Post notification
        NotificationCenter.default.post(name: .equipmentIdentified, object: currentEquipment)
    }
    
    // MARK: - Video Results Action
    
    private func handleVideoResultsAction(_ action: GenieAction) {
        guard let query = action.data["query"]?.stringValue,
              let videosData = action.data["videos"]?.arrayValue else {
            print("❌ [ActionHandler] Invalid video results action data")
            return
        }
        
        // Parse video results
        let videos: [VideoResult] = videosData.compactMap { (videoData: Any) -> VideoResult? in
            guard let dict = videoData as? [String: Any],
                  let videoId = dict["videoId"] as? String,
                  let title = dict["title"] as? String else {
                return nil
            }
            
            return VideoResult(
                videoId: videoId,
                title: title,
                thumbnail: dict["thumbnail"] as? String,
                channel: dict["channel"] as? String ?? "YouTube",
                url: dict["url"] as? String ?? "https://www.youtube.com/watch?v=\(videoId)"
            )
        }
        
        currentVideos = VideoResultsAction(query: query, videos: videos)
        showingVideoResults = true
        
        print("✅ [ActionHandler] Video results: \(videos.count) videos for '\(query)'")
    }
    
    // MARK: - Nutrition Action
    
    private func handleNutritionAction(_ action: GenieAction) {
        guard let calories = action.data["calories"]?.intValue,
              let macrosData = action.data["macros"]?.dictValue else {
            print("❌ [ActionHandler] Invalid nutrition action data")
            return
        }
        
        let protein = macrosData["protein"] as? Double ?? 0
        let carbs = macrosData["carbs"] as? Double ?? 0
        let fat = macrosData["fat"] as? Double ?? 0
        
        let foods = action.data["foods"]?.arrayValue?.compactMap { $0 as? String } ?? []
        let analysis = action.data["analysis"]?.stringValue ?? ""
        
        currentNutrition = NutritionAction(
            calories: calories,
            macros: Macros(protein: protein, carbs: carbs, fat: fat),
            foods: foods,
            analysis: analysis
        )
        
        showingNutritionLog = true
        
        print("✅ [ActionHandler] Nutrition data: \(calories) cal, \(Int(protein))g pro, \(Int(carbs))g carbs, \(Int(fat))g fat")
    }
    
    // MARK: - Form Feedback Action
    
    private func handleFormFeedbackAction(_ action: GenieAction) {
        // Handle form analysis feedback
        let analysis = action.data["analysis"]?.stringValue ?? ""
        let recommendations = action.data["recommendations"]?.arrayValue?.compactMap { $0 as? String } ?? []
        
        print("✅ [ActionHandler] Form feedback: \(recommendations.count) recommendations")
        // Could show a detailed form feedback view here
    }
    
    // MARK: - Movement Creation Action
    
    private func handleMovementCreationAction(_ action: GenieAction) {
        print("🏋️ [ActionHandler] Processing movement creation action...")
        print("🏋️ [ActionHandler] Action data: \(action.data)")
        
        // Parse movement data from action
        guard let name = action.data["name"]?.stringValue ?? action.data["movement1Name"]?.stringValue,
              !name.isEmpty else {
            print("❌ [ActionHandler] Invalid movement action: name missing")
            logActionValidationError(action, missingFields: ["name or movement1Name"])
            return
        }
        
        let movement2Name = action.data["movement2Name"]?.stringValue
        let isSingle = action.data["isSingle"]?.boolValue ?? (movement2Name == nil)
        let isTimed = action.data["isTimed"]?.boolValue ?? false
        let category = action.data["category"]?.stringValue
        let difficulty = action.data["difficulty"]?.stringValue
        let description = action.data["description"]?.stringValue
        let equipmentNeeded = action.data["equipmentNeeded"]?.boolValue ?? action.data["equipmentsNeeded"]?.boolValue ?? false
        let tags = action.data["tags"]?.arrayValue?.compactMap { ($0 as? AnyCodable)?.stringValue } ?? []
        
        // Parse sets
        let firstSectionSets = parseSets(from: action.data["firstSectionSets"])
        let secondSectionSets = parseSets(from: action.data["secondSectionSets"])
        let weavedSets = parseSets(from: action.data["weavedSets"])
        let templateSets = parseSets(from: action.data["templateSets"])
        
        let workoutAction = WorkoutCreationAction(
            type: .movement,
            name: name,
            description: description,
            category: category,
            difficulty: difficulty,
            equipmentNeeded: equipmentNeeded,
            tags: tags,
            movement1Name: name,
            movement2Name: movement2Name,
            isSingle: isSingle,
            isTimed: isTimed,
            firstSectionSets: firstSectionSets,
            secondSectionSets: secondSectionSets,
            weavedSets: weavedSets,
            templateSets: templateSets,
            movements: nil,
            isDayOfTheWeekPlan: nil,
            sessions: nil
        )
        
        currentMovement = workoutAction
        // Don't show preview immediately - wait for user to click "Preview Movement" button
        // showingMovementPreview = true  // Removed - will be set when user clicks button
        
        print("✅ [ActionHandler] Movement prepared: \(name) (preview will show on button click)")
    }
    
    // MARK: - Session Creation Action
    
    private func handleSessionCreationAction(_ action: GenieAction) {
        print("📋 [ActionHandler] Processing session creation action...")
        print("📋 [ActionHandler] Action data: \(action.data)")
        
        guard let name = action.data["name"]?.stringValue, !name.isEmpty else {
            print("❌ [ActionHandler] Invalid session action: name missing")
            logActionValidationError(action, missingFields: ["name"])
            return
        }
        
        let description = action.data["description"]?.stringValue
        let difficulty = action.data["difficulty"]?.stringValue
        let equipmentNeeded = action.data["equipmentNeeded"]?.boolValue ?? false
        let tags = action.data["tags"]?.arrayValue?.compactMap { ($0 as? AnyCodable)?.stringValue } ?? []
        
        // Parse movements array
        var parsedMovements: [WorkoutCreationAction] = []
        if let movementsData = action.data["movements"]?.arrayValue {
            for movementData in movementsData {
                if let movementDict = movementData as? [String: Any] {
                    let movementName = movementDict["movement1Name"] as? String ?? movementDict["name"] as? String ?? ""
                    if !movementName.isEmpty {
                        let movement2Name = movementDict["movement2Name"] as? String
                        let isSingle = (movementDict["isSingle"] as? Bool) ?? (movement2Name == nil)
                        let isTimed = (movementDict["isTimed"] as? Bool) ?? false
                        let category = movementDict["category"] as? String
                        let difficulty = movementDict["difficulty"] as? String
                        let description = movementDict["description"] as? String
                        let equipmentNeeded = (movementDict["equipmentNeeded"] as? Bool) ?? (movementDict["equipmentsNeeded"] as? Bool) ?? false
                        
                        // Parse sets for this movement
                        let firstSectionSets = parseSetsFromDict(movementDict["firstSectionSets"])
                        let secondSectionSets = parseSetsFromDict(movementDict["secondSectionSets"])
                        let weavedSets = parseSetsFromDict(movementDict["weavedSets"])
                        let templateSets = parseSetsFromDict(movementDict["templateSets"])
                        
                        let movementAction = WorkoutCreationAction(
                            type: .movement,
                            name: movementName,
                            description: description,
                            category: category,
                            difficulty: difficulty,
                            equipmentNeeded: equipmentNeeded,
                            tags: [],
                            movement1Name: movementName,
                            movement2Name: movement2Name,
                            isSingle: isSingle,
                            isTimed: isTimed,
                            firstSectionSets: firstSectionSets,
                            secondSectionSets: secondSectionSets,
                            weavedSets: weavedSets,
                            templateSets: templateSets,
                            movements: nil,
                            isDayOfTheWeekPlan: nil,
                            sessions: nil
                        )
                        parsedMovements.append(movementAction)
                    }
                }
            }
        }
        
        let workoutAction = WorkoutCreationAction(
            type: .session,
            name: name,
            description: description,
            category: nil,
            difficulty: difficulty,
            equipmentNeeded: equipmentNeeded,
            tags: tags,
            movement1Name: nil,
            movement2Name: nil,
            isSingle: nil,
            isTimed: nil,
            firstSectionSets: nil,
            secondSectionSets: nil,
            weavedSets: nil,
            templateSets: nil,
            movements: parsedMovements.isEmpty ? nil : parsedMovements,
            isDayOfTheWeekPlan: nil,
            sessions: nil
        )
        
        currentSession = workoutAction
        // Don't show preview immediately - wait for user to click "Preview Session" button
        // showingSessionPreview = true  // Removed - will be set when user clicks button
        
        print("✅ [ActionHandler] Session prepared: \(name) with \(parsedMovements.count) movements (preview will show on button click)")
    }
    
    // MARK: - Plan Creation Action
    
    private func handlePlanCreationAction(_ action: GenieAction) {
        print("📅 [ActionHandler] Processing plan creation action...")
        print("📅 [ActionHandler] Action data: \(action.data)")
        
        guard let name = action.data["name"]?.stringValue, !name.isEmpty else {
            print("❌ [ActionHandler] Invalid plan action: name missing")
            logActionValidationError(action, missingFields: ["name"])
            return
        }
        
        let description = action.data["description"]?.stringValue
        let difficulty = action.data["difficulty"]?.stringValue
        let equipmentNeeded = action.data["equipmentNeeded"]?.boolValue ?? false
        let tags = action.data["tags"]?.arrayValue?.compactMap { ($0 as? AnyCodable)?.stringValue } ?? []
        let isDayOfTheWeekPlan = action.data["isDayOfTheWeekPlan"]?.boolValue ?? false
        
        // Parse sessions map
        var sessionsMap: [String: String] = [:]
        if let sessionsData = action.data["sessions"]?.dictValue {
            for (key, value) in sessionsData {
                if let stringValue = value as? String {
                    sessionsMap[key] = stringValue
                } else if let stringValue = (value as? AnyCodable)?.stringValue {
                    sessionsMap[key] = stringValue
                }
            }
        }
        
        let workoutAction = WorkoutCreationAction(
            type: .plan,
            name: name,
            description: description,
            category: nil,
            difficulty: difficulty,
            equipmentNeeded: equipmentNeeded,
            tags: tags,
            movement1Name: nil,
            movement2Name: nil,
            isSingle: nil,
            isTimed: nil,
            firstSectionSets: nil,
            secondSectionSets: nil,
            weavedSets: nil,
            templateSets: nil,
            movements: nil,
            isDayOfTheWeekPlan: isDayOfTheWeekPlan,
            sessions: sessionsMap.isEmpty ? nil : sessionsMap
        )
        
        currentPlan = workoutAction
        // Don't show preview immediately - wait for user to click "Preview Plan" button
        // showingPlanPreview = true  // Removed - will be set when user clicks button
        
        print("✅ [ActionHandler] Plan prepared: \(name) with \(sessionsMap.count) schedule items (preview will show on button click)")
    }
    
    // MARK: - Helper Functions for Parsing Sets
    
    private func parseSets(from data: Any?) -> [[String: Any]]? {
        guard let data = data else { return nil }
        
        if let array = data as? [[String: Any]] {
            return array
        } else if let anyCodableArray = data as? [AnyCodable] {
            return anyCodableArray.compactMap { $0.value as? [String: Any] }
        } else if let arrayValue = (data as? AnyCodable)?.arrayValue {
            return arrayValue.compactMap { $0 as? [String: Any] }
        }
        
        return nil
    }
    
    private func parseSetsFromDict(_ data: Any?) -> [[String: Any]]? {
        guard let data = data else { return nil }
        
        if let array = data as? [[String: Any]] {
            return array
        } else if let anyCodableArray = data as? [AnyCodable] {
            return anyCodableArray.compactMap { $0.value as? [String: Any] }
        } else if let arrayValue = (data as? AnyCodable)?.arrayValue {
            return arrayValue.compactMap { $0 as? [String: Any] }
        }
        
        return nil
    }
    
    // MARK: - Meal Plan Action
    
    private func handleMealPlanAction(_ action: GenieAction) {
        guard let duration = action.data["duration"]?.intValue ?? action.data["duration"]?.doubleValue.map({ Int($0) }) else {
            print("❌ [ActionHandler] Invalid meal plan action data - missing duration")
            return
        }
        
        // Try to parse plan JSON if available
        var plan: MealPlanData? = nil
        if let planData = action.data["plan"]?.dictValue {
            plan = parseMealPlanData(from: planData)
        }
        
        let planText = action.data["planText"]?.stringValue ?? ""
        
        currentMealPlan = MealPlanAction(
            duration: duration,
            plan: plan,
            planText: planText
        )
        
        showingMealPlan = true
        
        // Auto-save meal plan to prod-nutrition table if plan data is available
        if let plan = plan, !plan.meals.isEmpty {
            Task {
                do {
                    try await MealPlanTrackingService.shared.saveMealPlan(
                        planName: "Genie Meal Plan - \(duration) days",
                        duration: duration,
                        startDate: Date(),
                        meals: plan.meals,
                        planText: planText
                    )
                    print("✅ [ActionHandler] Meal plan auto-saved to prod-nutrition table")
                } catch {
                    print("⚠️ [ActionHandler] Could not auto-save meal plan: \(error)")
                    // Continue to show the plan even if auto-save fails
                }
            }
        }
        
        print("✅ [ActionHandler] Meal plan action: \(duration) days, has plan data: \(plan != nil)")
    }
    
    private func parseMealPlanData(from dict: [String: Any]) -> MealPlanData? {
        guard let mealsData = dict["meals"] as? [[String: Any]] else {
            return nil
        }
        
        let meals = mealsData.compactMap { mealDict -> MealPlanMeal? in
            guard let mealType = mealDict["mealType"] as? String,
                  let name = mealDict["name"] as? String else {
                return nil
            }
            
            return MealPlanMeal(
                mealType: mealType,
                name: name,
                calories: (mealDict["calories"] as? Double) ?? (mealDict["calories"] as? Int).map { Double($0) } ?? 0,
                protein: (mealDict["protein"] as? Double) ?? (mealDict["protein"] as? Int).map { Double($0) } ?? 0,
                carbs: (mealDict["carbs"] as? Double) ?? (mealDict["carbs"] as? Int).map { Double($0) } ?? 0,
                fat: (mealDict["fat"] as? Double) ?? (mealDict["fat"] as? Int).map { Double($0) } ?? 0
            )
        }
        
        return MealPlanData(meals: meals)
    }
    
    // MARK: - Meal Suggestions Action
    
    private func handleMealSuggestionsAction(_ action: GenieAction) {
        let suggestions = action.data["suggestions"]?.arrayValue?.compactMap { $0 as? String } ?? []
        let recipes = action.data["recipes"]?.arrayValue?.compactMap { $0 as? String } ?? []
        let analysis = action.data["analysis"]?.stringValue ?? ""
        
        // Parse structured recipes from the response (removes duplicates)
        let parsedRecipes = Recipe.parseMultiple(from: suggestions, analysis: analysis)
        
        // Remove duplicates from suggestions array
        var uniqueSuggestions: [String] = []
        var seen = Set<String>()
        for suggestion in suggestions {
            let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.lowercased()
            if !key.isEmpty && !seen.contains(key) && !String.matches(key, pattern: "^\\d+\\.|^\\*\\*") {
                seen.insert(key)
                uniqueSuggestions.append(trimmed)
            }
        }
        
        currentMealSuggestions = MealSuggestionsAction(
            suggestions: uniqueSuggestions,
            recipes: parsedRecipes,
            analysis: analysis
        )
        
        showingMealSuggestions = true
        
        // Save recipes to cookbook (RecipeStorageService)
        // When user tracks a recipe, it's logged as a food entry via FoodTrackingService
        // which uses prod-nutrition table with entryType: "food"
        if !parsedRecipes.isEmpty {
            Task {
                for recipe in parsedRecipes {
                    RecipeStorageService.shared.saveRecipe(recipe)
                }
                print("✅ [ActionHandler] Saved \(parsedRecipes.count) recipes to cookbook")
            }
        }
        
        print("✅ [ActionHandler] Meal suggestions: \(uniqueSuggestions.count) unique suggestions, \(parsedRecipes.count) parsed recipes")
    }
    
    // MARK: - Restaurant Search Action
    
    private func handleRestaurantSearchAction(_ action: GenieAction) {
        let requiresLocation = action.data["requiresLocation"]?.boolValue ?? false
        let query = action.data["query"]?.stringValue ?? ""
        let suggestions = action.data["suggestions"]?.arrayValue?.compactMap { $0 as? String } ?? []
        
        currentRestaurantSearch = RestaurantSearchAction(
            requiresLocation: requiresLocation,
            query: query,
            suggestions: suggestions
        )
        
        showingRestaurantSearch = true
        
        print("✅ [ActionHandler] Restaurant search: requires location: \(requiresLocation), \(suggestions.count) suggestions")
    }
    
    // MARK: - Preferences Updated Action
    
    private func handlePreferencesUpdatedAction(_ action: GenieAction) {
        let message = action.data["message"]?.stringValue ?? ""
        let preferences = action.data["preferences"]?.dictValue ?? [:]
        
        print("✅ [ActionHandler] Preferences updated: \(message)")
        
        // Extract and store preferences locally (could sync to backend later)
        if let likes = preferences["likes"] as? [String] {
            print("  - Likes: \(likes)")
        }
        if let dislikes = preferences["dislikes"] as? [String] {
            print("  - Dislikes: \(dislikes)")
        }
        if let allergies = preferences["allergies"] as? [String] {
            print("  - Allergies: \(allergies)")
        }
        if let restrictions = preferences["restrictions"] as? [String] {
            print("  - Restrictions: \(restrictions)")
        }
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .foodPreferencesUpdated, object: preferences)
    }
    
    // MARK: - Vision Board Action
    
    private func handleVisionBoardAction(_ action: GenieAction) {
        print("🎨 [ActionHandler] Processing vision board action...")
        
        let title = action.data["title"]?.stringValue ?? "My Vision Board"
        let goals = (action.data["goals"]?.arrayValue as? [AnyCodable])?.compactMap { $0.stringValue } ?? []
        let affirmations = (action.data["affirmations"]?.arrayValue as? [AnyCodable])?.compactMap { $0.stringValue } ?? []
        let description = action.data["description"]?.stringValue ?? ""
        let theme = action.data["theme"]?.stringValue ?? "general"
        
        print("✅ [ActionHandler] Vision board: '\(title)', \(goals.count) goals, theme: \(theme)")
        
        let visionBoard = VisionBoardAction(
            title: title,
            goals: goals,
            affirmations: affirmations,
            description: description,
            theme: theme
        )
        
        currentVisionBoard = visionBoard
        showingVisionBoard = true
        
        // Post notification
        NotificationCenter.default.post(name: .visionBoardCreated, object: visionBoard)
    }
    
    // MARK: - Manifestation Action
    
    private func handleManifestationAction(_ action: GenieAction) {
        print("✨ [ActionHandler] Processing manifestation action...")
        
        let intention = action.data["intention"]?.stringValue ?? ""
        let steps = (action.data["steps"]?.arrayValue as? [AnyCodable])?.compactMap { $0.stringValue } ?? []
        let visualization = action.data["visualization"]?.stringValue ?? ""
        let timeframe = action.data["timeframe"]?.stringValue ?? "ongoing"
        let affirmations = (action.data["affirmations"]?.arrayValue as? [AnyCodable])?.compactMap { $0.stringValue } ?? []
        
        print("✅ [ActionHandler] Manifestation: '\(intention)', \(steps.count) steps, timeframe: \(timeframe)")
        
        let manifestation = ManifestationAction(
            intention: intention,
            steps: steps,
            visualization: visualization,
            timeframe: timeframe,
            affirmations: affirmations
        )
        
        currentManifestation = manifestation
        showingManifestation = true
        
        // Post notification
        NotificationCenter.default.post(name: .manifestationCreated, object: manifestation)
    }
    
    // MARK: - Affirmation Action
    
    private func handleAffirmationAction(_ action: GenieAction) {
        print("💭 [ActionHandler] Processing affirmation action...")
        
        let affirmations = (action.data["affirmations"]?.arrayValue as? [AnyCodable])?.compactMap { $0.stringValue } ?? []
        let category = action.data["category"]?.stringValue ?? "general"
        let frequency = action.data["frequency"]?.stringValue ?? "daily"
        let description = action.data["description"]?.stringValue ?? ""
        
        print("✅ [ActionHandler] Affirmations: \(affirmations.count) affirmations, category: \(category), frequency: \(frequency)")
        
        let affirmation = AffirmationAction(
            affirmations: affirmations,
            category: category,
            frequency: frequency,
            description: description
        )
        
        currentAffirmation = affirmation
        showingAffirmation = true
        
        // Post notification
        NotificationCenter.default.post(name: .affirmationCreated, object: affirmation)
    }
    
    // MARK: - Bedtime Story Action
    
    private func handleBedtimeStoryAction(_ action: GenieAction) {
        print("📖 [ActionHandler] Processing bedtime story action...")
        
        let title = action.data["title"]?.stringValue ?? "Bedtime Story"
        let story = action.data["story"]?.stringValue ?? ""
        let storyType = action.data["storyType"]?.stringValue ?? "bedtime"
        let audience = action.data["audience"]?.stringValue ?? "adult"
        let tone = action.data["tone"]?.stringValue ?? "calming"
        let duration = action.data["duration"]?.intValue ?? 10
        let playAudio = action.data["playAudio"]?.boolValue ?? true
        let audioUrl = action.data["audioUrl"]?.stringValue
        let audioDuration = action.data["audioDuration"]?.doubleValue
        let ambientSoundTypeString = action.data["ambientSoundType"]?.stringValue
        
        // Convert ambient sound type string to AmbientSoundType
        // Default to "story" type for bedtime stories, or use specified type
        let ambientType: AmbientSoundType = {
            if let ambientSoundTypeString = ambientSoundTypeString {
                switch ambientSoundTypeString.lowercased() {
                case "rain":
                    return .rain
                case "ocean":
                    return .ocean
                case "forest":
                    return .forest
                case "zen":
                    return .zen
                case "white_noise", "whitenoise", "white noise":
                    return .whiteNoise
                case "story", "calm", "peaceful":
                    return .story
                default:
                    return .story // Default to story type for bedtime stories
                }
            } else {
                // If no ambient sound specified, use story type (optional - can be nil if playAudio is false)
                return .story
            }
        }()
        
        print("✅ [ActionHandler] Bedtime story: '\(title)', \(duration) min, audience: \(audience), tone: \(tone)")
        print("✅ [ActionHandler] Story length: \(story.count) characters")
        print("✅ [ActionHandler] Play audio: \(playAudio)")
        if playAudio {
            print("✅ [ActionHandler] Ambient sound: \(ambientType.description)")
        }
        
        let bedtimeStory = BedtimeStoryAction(
            title: title,
            story: story,
            storyType: storyType,
            audience: audience,
            tone: tone,
            duration: duration,
            playAudio: playAudio,
            audioUrl: audioUrl,
            audioDuration: audioDuration,
            ambientSoundType: playAudio ? ambientType : nil // Only set if playAudio is true
        )
        
        currentBedtimeStory = bedtimeStory
        showingBedtimeStory = true
        
        // Don't start audio automatically - wait for user to click "Get Started" (similar to meditation)
        if playAudio {
            print("🔊 [ActionHandler] Bedtime story prepared with \(ambientType.description) ambient sound")
            print("🔊 [ActionHandler] Story length: \(story.count) characters")
            print("🔊 [ActionHandler] Audio will start when user clicks 'Get Started'")
        } else {
            print("⚠️ [ActionHandler] Bedtime story audio playback disabled")
        }
        
        // Post notification
        NotificationCenter.default.post(name: .bedtimeStoryCreated, object: bedtimeStory)
    }
    
    // MARK: - Motivation Action
    
    private func handleMotivationAction(_ action: GenieAction) {
        print("💪 [ActionHandler] Processing motivation action...")
        
        // Validate required fields
        guard let script = action.data["script"]?.stringValue, !script.isEmpty else {
            logActionValidationError(action, missingFields: ["script"])
            return
        }
        
        let title = action.data["title"]?.stringValue ?? "Motivational Session"
        // Parse duration - try multiple formats
        let duration: Int = {
            if let intValue = action.data["duration"]?.intValue {
                return intValue
            } else if let doubleValue = action.data["duration"]?.doubleValue {
                return Int(doubleValue)
            } else if let stringValue = action.data["duration"]?.stringValue,
                      let parsed = Int(stringValue) {
                return parsed
            } else {
                // Try to extract from script or use default
                print("⚠️ [ActionHandler] No duration found in action data, defaulting to 10 min")
                return 10
            }
        }()
        let playAudio = action.data["playAudio"]?.boolValue ?? true
        let audioUrl = action.data["audioUrl"]?.stringValue
        let audioDuration = action.data["audioDuration"]?.doubleValue
        let ambientSoundTypeString = action.data["ambientSoundType"]?.stringValue ?? "motivation"
        
        // Convert ambient sound type string to AmbientSoundType
        // Motivation always uses motivation type (energetic, inspiring music)
        let ambientType: AmbientSoundType = {
            switch ambientSoundTypeString.lowercased() {
            case "motivation", "energetic", "inspiring", "uplifting":
                return .motivation
            case "forest":
                return .forest // Fallback option
            default:
                return .motivation // Default to motivation type
            }
        }()
        
        print("✅ [ActionHandler] Motivation action validated successfully")
        print("✅ [ActionHandler] Title: \(title)")
        print("✅ [ActionHandler] Duration: \(duration) min")
        print("✅ [ActionHandler] Play Audio: \(playAudio)")
        print("✅ [ActionHandler] Script length: \(script.count) characters")
        print("✅ [ActionHandler] Ambient Sound: \(ambientType.description)")
        
        if let audioUrl = audioUrl {
            print("✅ [ActionHandler] Audio URL available: \(audioUrl)")
            if let audioDuration = audioDuration {
                print("✅ [ActionHandler] Audio duration: \(audioDuration) seconds")
            }
        } else {
            print("⚠️ [ActionHandler] No audio URL - will generate TTS")
        }
        
        let motivation = MotivationAction(
            title: title,
            script: script,
            duration: duration,
            playAudio: playAudio,
            audioUrl: audioUrl,
            audioDuration: audioDuration,
            ambientSoundType: ambientType
        )
        
        currentMotivation = motivation
        showingMotivation = true
        
        // Don't start audio automatically - wait for user to click "Get Started" (similar to meditation)
        if playAudio {
            print("🔊 [ActionHandler] Motivation prepared with \(ambientType.description) ambient sound")
            print("🔊 [ActionHandler] Script length: \(script.count) characters")
            print("🔊 [ActionHandler] Audio will start when user clicks 'Get Started'")
        } else {
            print("⚠️ [ActionHandler] Motivation audio playback disabled")
        }
        
        // Post notification
        NotificationCenter.default.post(name: .motivationStarted, object: motivation)
        
        print("✅ [ActionHandler] Motivation action complete")
        print("✅ [ActionHandler] - Motivation UI shown (showingMotivation = true)")
        print("✅ [ActionHandler] - Notification posted: motivationStarted")
    }
    
    // MARK: - Grocery List Action
    
    private func handleGroceryListAction(_ action: GenieAction) {
        // Parse grocery list from action data
        let listName = action.data["name"]?.stringValue ?? "Grocery List"
        let items = action.data["items"]?.arrayValue?.compactMap { item -> GroceryListItem? in
            guard let itemDict = item as? [String: Any],
                  let name = itemDict["name"] as? String,
                  let amount = itemDict["amount"] as? Double,
                  let unit = itemDict["unit"] as? String else {
                return nil
            }
            
            // Create grocery ingredient
            let category = parseCategory(from: itemDict["category"] as? String)
            let ingredient = GroceryIngredient(
                id: UUID().uuidString,
                name: name,
                amount: amount,
                unit: unit,
                category: category,
                notes: itemDict["notes"] as? String,
                isOptional: itemDict["isOptional"] as? Bool ?? false
            )
            
            return GroceryListItem(
                id: UUID().uuidString,
                ingredient: ingredient,
                isChecked: false,
                notes: itemDict["notes"] as? String,
                estimatedPrice: itemDict["estimatedPrice"] as? Double
            )
        } ?? []
        
        let estimatedCost = action.data["estimatedCost"]?.doubleValue
        let storeSuggestions = action.data["storeSuggestions"]?.arrayValue?.compactMap { $0 as? String }
        
        let groceryList = GroceryList(
            id: UUID().uuidString,
            name: listName,
            createdAt: Date(),
            items: items,
            estimatedCost: estimatedCost,
            storeSuggestions: storeSuggestions
        )
        
        currentGroceryList = groceryList
        showingGroceryList = true
        
        print("✅ [ActionHandler] Grocery list: \(listName) with \(items.count) items")
    }
    
    private func parseCategory(from categoryString: String?) -> GroceryFoodCategory {
        guard let categoryString = categoryString else { return .other }
        return GroceryFoodCategory(rawValue: categoryString.lowercased()) ?? .other
    }
    
    // MARK: - Cookbook Action
    
    private func handleCookbookAction(_ action: GenieAction) {
        // Show cookbook view
        showingCookbook = true
        print("✅ [ActionHandler] Showing cookbook")
    }
    
    @Published var currentGroceryList: GroceryList?
}

// MARK: - Action Models

struct MeditationAction {
    let duration: Int
    let focus: String
    let isMotivation: Bool
    let script: String
    let playAudio: Bool
    let audioUrl: String? // Polly audio URL if available
    let audioDuration: Int? // Duration in seconds
    let ambientSoundType: AmbientSoundType // Agent-specified or auto-selected ambient sound
}

struct EquipmentAction {
    let name: String
    let description: String
    let category: String
}

struct VideoResultsAction {
    let query: String
    let videos: [VideoResult]
}

struct VideoResult: Identifiable {
    let id = UUID()
    let videoId: String
    let title: String
    let thumbnail: String?
    let channel: String
    let url: String
}

struct NutritionAction {
    let calories: Int
    let macros: Macros
    let foods: [String]
    let analysis: String
}

// MARK: - Food Action Models

struct MealPlanAction {
    let duration: Int
    let plan: MealPlanData?
    let planText: String
}

struct MealPlanData {
    let meals: [MealPlanMeal]
}

struct MealPlanMeal {
    let mealType: String
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

struct MealSuggestionsAction {
    let suggestions: [String]
    let recipes: [Recipe] // Changed from [String] to structured Recipe objects
    let analysis: String
}

struct RestaurantSearchAction {
    let requiresLocation: Bool
    let query: String
    let suggestions: [String]
}

// MARK: - Vision Board, Manifestation, and Affirmation Models

struct VisionBoardAction {
    let title: String
    let goals: [String]
    let affirmations: [String]
    let description: String
    let theme: String
}

struct ManifestationAction {
    let intention: String
    let steps: [String]
    let visualization: String
    let timeframe: String
    let affirmations: [String]
}

struct AffirmationAction {
    let affirmations: [String]
    let category: String
    let frequency: String
    let description: String
}

struct BedtimeStoryAction {
    let title: String
    let story: String
    let storyType: String
    let audience: String
    let tone: String
    let duration: Int
    let playAudio: Bool
    let audioUrl: String?
    let audioDuration: Double?
    let ambientSoundType: AmbientSoundType? // Optional - only set if playAudio is true
}

struct MotivationAction {
    let title: String
    let script: String
    let duration: Int
    let playAudio: Bool
    let audioUrl: String?
    let audioDuration: Double?
    let ambientSoundType: AmbientSoundType // Always required for motivation
}

// MARK: - Workout Creation Action

enum WorkoutCreationType {
    case movement
    case session
    case plan
}

struct WorkoutCreationAction {
    let type: WorkoutCreationType
    let name: String
    let description: String?
    let category: String?
    let difficulty: String?
    let equipmentNeeded: Bool
    let tags: [String]
    
    // Movement-specific
    let movement1Name: String?
    let movement2Name: String?
    let isSingle: Bool?
    let isTimed: Bool?
    let firstSectionSets: [[String: Any]]?
    let secondSectionSets: [[String: Any]]?
    let weavedSets: [[String: Any]]?
    let templateSets: [[String: Any]]?
    
    // Session-specific
    let movements: [WorkoutCreationAction]? // Nested movements
    
    // Plan-specific
    let isDayOfTheWeekPlan: Bool?
    let sessions: [String: String]? // Day -> sessionId/activity
}

// MARK: - Notification Names

extension Notification.Name {
    static let meditationStarted = Notification.Name("meditationStarted")
    static let equipmentIdentified = Notification.Name("equipmentIdentified")
    static let videoResultsAvailable = Notification.Name("videoResultsAvailable")
    static let foodPreferencesUpdated = Notification.Name("foodPreferencesUpdated")
    static let mealPlanCreated = Notification.Name("mealPlanCreated")
    static let visionBoardCreated = Notification.Name("visionBoardCreated")
    static let manifestationCreated = Notification.Name("manifestationCreated")
    static let affirmationCreated = Notification.Name("affirmationCreated")
    static let bedtimeStoryCreated = Notification.Name("bedtimeStoryCreated")
    static let motivationStarted = Notification.Name("motivationStarted")
}

