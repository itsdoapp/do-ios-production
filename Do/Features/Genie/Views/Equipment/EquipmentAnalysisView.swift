//
//  EquipmentAnalysisView.swift
//  Do
//
//  Beautiful view for displaying Genie equipment analysis with formatted stats
//

import SwiftUI
import UIKit

struct EquipmentAnalysisView: View {
    let image: UIImage?
    let analysis: GenieQueryResponse
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var parsedData: ParsedEquipmentData?
    @State private var allEquipment: [RankedEquipment] = []
    @State private var showingQuestionInput = false
    @State private var questionText = ""
    @State private var isProcessingQuestion = false
    @State private var showingTutorials = false
    @State private var selectedEquipment: RankedEquipment?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlue
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Equipment image
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 250)
                                .clipped()
                                .cornerRadius(16)
                                .padding(.horizontal)
                        }
                        
                        // Parse data on appear
                        if parsedData == nil && allEquipment.isEmpty {
                            ProgressView()
                                .tint(.white)
                                .padding()
                        } else if let data = parsedData, 
                                  !data.name.isEmpty && 
                                  data.name != "Unknown Equipment" && 
                                  data.name != "Workout Area" &&
                                  (!data.suggestedExercises.isEmpty || !data.description.isEmpty) {
                            // Show primary equipment first - only if we have valid data
                                // Equipment name card with non-official indicator (from agent response)
                                EquipmentNameCard(name: data.name, category: data.category, isNonOfficial: !data.isOfficialEquipment)
                                    .padding(.horizontal)
                                
                                // Muscle groups card
                                if !data.muscleGroups.isEmpty {
                                    MuscleGroupsCard(muscleGroups: data.muscleGroups)
                                        .padding(.horizontal)
                                }
                                
                                // Description card
                                if !data.description.isEmpty {
                                    DescriptionCard(description: data.description)
                                        .padding(.horizontal)
                                }
                                
                                // Suggested exercises
                                if !data.suggestedExercises.isEmpty {
                                    SuggestedExercisesCard(exercises: data.suggestedExercises)
                                        .padding(.horizontal)
                                }
                                
                                // Low confidence warning
                                if data.confidence < 0.7 {
                                    LowConfidenceCard(
                                        confidence: data.confidence,
                                        onAddDetails: {
                                            showingQuestionInput = true
                                        },
                                        onAskQuestion: {
                                            showingQuestionInput = true
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Show all identified equipment (ranked)
                            if !allEquipment.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("All Equipment Identified")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                    
                                    ForEach(allEquipment) { equipment in
                                        RankedEquipmentCard(
                                            equipment: equipment,
                                            onWatchTutorials: {
                                                selectedEquipment = equipment
                                                showingTutorials = true
                                            }
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            } else {
                                // Empty state - no equipment identified
                                EmptyEquipmentStateView()
                                    .padding(.horizontal)
                                    .padding(.vertical, 40)
                            }
                            
                            // Action buttons
                            VStack(spacing: 12) {
                                // Watch tutorials button for primary equipment
                                if let data = parsedData,
                                   !data.name.isEmpty && 
                                   data.name != "Unknown Equipment" && 
                                   data.name != "Workout Area" &&
                                   (!data.suggestedExercises.isEmpty || !data.description.isEmpty) {
                                    Button {
                                        selectedEquipment = RankedEquipment(
                                            id: UUID().uuidString,
                                            name: data.name,
                                            description: data.description,
                                            category: data.category,
                                            muscleGroups: data.muscleGroups,
                                            suggestedExercises: data.suggestedExercises,
                                            confidence: data.confidence,
                                            relevanceScore: 1.0,
                                            isOfficialEquipment: data.isOfficialEquipment
                                        )
                                        showingTutorials = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "play.circle.fill")
                                            Text("Watch Tutorials")
                                        }
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            LinearGradient(
                                                colors: [Color.brandOrange, Color("FF6B35")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(12)
                                    }
                                }
                                
                                // Done button
                                Button {
                                    onSave()
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Done")
                                    }
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Equipment Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                parseAnalysis()
            }
            .sheet(isPresented: $showingQuestionInput) {
                QuestionInputSheet(
                    questionText: $questionText,
                    isProcessing: $isProcessingQuestion,
                    onSubmit: handleQuestion
                )
            }
            .fullScreenCover(isPresented: $showingTutorials) {
                if let equipment = selectedEquipment {
                    EquipmentTutorialsView(
                        equipment: Equipment(
                            id: equipment.id,
                            name: equipment.name,
                            description: equipment.description,
                            muscleGroups: equipment.muscleGroups,
                            image: image,
                            suggestedWorkouts: []
                        ),
                        suggestedExercises: equipment.suggestedExercises,
                        category: equipment.category
                    )
                }
            }
        }
    
    
    // MARK: - Parsing
    
    private func parseAnalysis() {
        // Check if we have an equipment_identified action
        if let actions = analysis.actions,
           let equipmentAction = actions.first(where: { $0.type == "equipment_identified" }) {
            parseFromAction(equipmentAction)
        } else {
            // Parse from text response
            parseFromText(analysis.response)
        }
    }
    
    private func parseFromAction(_ action: GenieAction) {
        // The backend sometimes returns the JSON as a string in a field
        // Try to parse it first, then fall back to direct field access
        var parsedJsonData: [String: Any]?
        
        // Check if any field contains JSON string (similar to food analysis)
        for (key, value) in action.data {
            if let stringValue = value.stringValue,
               let jsonData = stringValue.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                // Try to get data field from the JSON
                if let dataDict = json["data"] as? [String: Any] {
                    parsedJsonData = dataDict
                    print("🔧 [EquipmentAnalysis] Found nested JSON in \(key) field, parsing data...")
                } else {
                    // If no "data" field, use the whole JSON
                    parsedJsonData = json
                    print("🔧 [EquipmentAnalysis] Found nested JSON in \(key) field, using entire JSON...")
                }
                break
            }
        }
        
        // Try to parse multiple equipment items first
        let equipmentArray = parsedJsonData?["equipment"] ?? action.data["equipment"]?.value
        if let equipmentArray = equipmentArray as? [Any], !equipmentArray.isEmpty {
            print("🔧 [EquipmentAnalysis] Found \(equipmentArray.count) equipment items")
            allEquipment = equipmentArray.compactMap { item -> RankedEquipment? in
                guard let dict = item as? [String: Any] else { return nil }
                return parseRankedEquipment(from: dict)
            }.sorted { $0.relevanceScore > $1.relevanceScore }
            
            // Set primary equipment from the first (highest relevance) item
            if let primary = allEquipment.first {
                parsedData = ParsedEquipmentData(
                    name: primary.name,
                    description: primary.description,
                    category: primary.category,
                    muscleGroups: primary.muscleGroups,
                    suggestedExercises: primary.suggestedExercises,
                    confidence: primary.confidence,
                    isOfficialEquipment: primary.isOfficialEquipment
                )
            }
        }
        
        // Also try to get primaryEquipment directly (this should always be present)
        let primaryEquipmentDict = parsedJsonData?["primaryEquipment"] ?? action.data["primaryEquipment"]?.value
        
        // Handle null primaryEquipment - check if it's NSNull or actual null
        if let primaryDict = primaryEquipmentDict as? [String: Any],
           !primaryDict.isEmpty,
           let primary = parseRankedEquipment(from: primaryDict) {
            // Only override if we don't already have parsedData or if this is better
            if parsedData == nil || primary.relevanceScore > (allEquipment.first?.relevanceScore ?? 0) {
                parsedData = ParsedEquipmentData(
                    name: primary.name,
                    description: primary.description,
                    category: primary.category,
                    muscleGroups: primary.muscleGroups,
                    suggestedExercises: primary.suggestedExercises,
                    confidence: primary.confidence,
                    isOfficialEquipment: primary.isOfficialEquipment
                )
            }
            
            // Add to allEquipment if not already there
            if !allEquipment.contains(where: { $0.name == primary.name }) {
                allEquipment.append(primary)
                allEquipment.sort { $0.relevanceScore > $1.relevanceScore }
            }
        }
        
        // Fallback: parse single equipment (old format or when structured data is empty)
        if parsedData == nil {
            let nameValue = parsedJsonData?["name"] ?? action.data["name"]?.value
            let descriptionValue = parsedJsonData?["description"] ?? action.data["description"]?.value
            
            // Check if description contains JSON that we need to parse
            var actualDescription: String?
            if let descString = (descriptionValue as? String) ?? action.data["description"]?.stringValue {
                // If description is a JSON string, try to parse it
                if let jsonData = descString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let dataDict = json["data"] as? [String: Any] {
                    // Try to extract from nested JSON
                    if let primary = dataDict["primaryEquipment"] as? [String: Any],
                       let parsed = parseRankedEquipment(from: primary) {
                        parsedData = ParsedEquipmentData(
                            name: parsed.name,
                            description: parsed.description,
                            category: parsed.category,
                            muscleGroups: parsed.muscleGroups,
                            suggestedExercises: parsed.suggestedExercises,
                            confidence: parsed.confidence,
                            isOfficialEquipment: parsed.isOfficialEquipment
                        )
                        allEquipment.append(parsed)
                        print("🔧 [EquipmentAnalysis] Extracted equipment from nested description JSON")
                    } else {
                        actualDescription = descString
                    }
                } else {
                    actualDescription = descString
                }
            }
            
            if parsedData == nil {
                if let name = (nameValue as? String) ?? action.data["name"]?.stringValue,
                   let description = actualDescription ?? action.data["description"]?.stringValue,
                   !name.isEmpty,
                   name != "Unknown Equipment",
                   name != "Workout Area",
                   !description.isEmpty {
                    let category = (parsedJsonData?["category"] as? String) ?? action.data["category"]?.stringValue ?? "other"
                    let muscleGroups = extractArray(from: parsedJsonData?["muscleGroups"] ?? action.data["muscleGroups"]?.value)
                    let exercises = extractArray(from: parsedJsonData?["suggestedExercises"] ?? action.data["suggestedExercises"]?.value)
                    var confidence: Double = {
                        if let parsedConfidence = parsedJsonData?["confidence"] as? Double {
                            return parsedConfidence
                        } else if let parsedConfidence = parsedJsonData?["confidence"] as? Int {
                            return Double(parsedConfidence)
                        } else if let actionConfidence = action.data["confidence"]?.doubleValue {
                            return actionConfidence
                        }
                        return 0.85
                    }()
                    
                    if confidence > 1.0 {
                        confidence = confidence / 100.0
                    }
                    confidence = max(0.0, min(1.0, confidence))
                    
                    parsedData = ParsedEquipmentData(
                        name: name,
                        description: description,
                        category: category,
                        muscleGroups: muscleGroups,
                        suggestedExercises: exercises,
                        confidence: confidence,
                        isOfficialEquipment: true // Default to true when parsing from old format
                    )
                } else {
                    // Last resort: parse from response text
                    print("⚠️ [EquipmentAnalysis] No structured data found, parsing from response text...")
                    parseFromText(analysis.response)
                }
            }
        }
        
        print("🔧 [EquipmentAnalysis] Parsed \(allEquipment.count) equipment items, primary: \(parsedData?.name ?? "none")")
    }
    
    private func parseRankedEquipment(from dict: [String: Any]) -> RankedEquipment? {
        guard let name = dict["name"] as? String,
              let description = dict["description"] as? String else {
            return nil
        }
        
        let category = dict["category"] as? String ?? "other"
        let muscleGroups = extractArray(from: dict["muscleGroups"])
        let exercises = extractArray(from: dict["suggestedExercises"])
        
        var confidence: Double = {
            if let conf = dict["confidence"] as? Double {
                return conf
            } else if let conf = dict["confidence"] as? Int {
                return Double(conf)
            }
            return 0.85
        }()
        
        if confidence > 1.0 {
            confidence = confidence / 100.0
        }
        confidence = max(0.0, min(1.0, confidence))
        
        var relevanceScore: Double = {
            if let score = dict["relevanceScore"] as? Double {
                return score
            } else if let score = dict["relevanceScore"] as? Int {
                return Double(score)
            }
            return confidence // Use confidence as relevance if not provided
        }()
        
        relevanceScore = max(0.0, min(1.0, relevanceScore))
        
        // Parse isOfficialEquipment from agent response (default to true if not provided)
        let isOfficialEquipment: Bool = {
            if let isOfficial = dict["isOfficialEquipment"] as? Bool {
                return isOfficial
            } else if let isOfficial = dict["isOfficialEquipment"] as? Int {
                return isOfficial != 0
            } else if let isOfficial = dict["isOfficialEquipment"] as? String {
                return isOfficial.lowercased() == "true"
            }
            return true // Default to official equipment if not specified
        }()
        
        return RankedEquipment(
            id: UUID().uuidString,
            name: name,
            description: description,
            category: category,
            muscleGroups: muscleGroups,
            suggestedExercises: exercises,
            confidence: confidence,
            relevanceScore: relevanceScore,
            isOfficialEquipment: isOfficialEquipment
        )
    }
    
    private func extractArray(from value: Any?) -> [String] {
        guard let value = value else { return [] }
        
        if let array = value as? [Any] {
            return array.compactMap { item -> String? in
                if let str = item as? String {
                    return str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : str.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return nil
            }
        }
        
        return []
    }
    
    private func parseFromText(_ text: String) {
        let cleanedText = MarkdownFormatter.cleanMarkdown(text)
        
        // Extract equipment name
        let name = extractEquipmentName(from: cleanedText)
        
        // Extract description
        let description = extractDescription(from: cleanedText, name: name)
        
        // Extract muscle groups
        let muscleGroups = extractMuscleGroups(from: cleanedText)
        
        // Extract category
        let category = extractCategory(from: cleanedText, name: name)
        
        // Extract suggested exercises
        let suggestedExercises = extractSuggestedExercises(from: cleanedText)
        
        // Extract confidence
        let confidence = extractConfidence(from: cleanedText)
        
        // Only create parsedData if we have meaningful data
        if !name.isEmpty && !description.isEmpty {
            parsedData = ParsedEquipmentData(
                name: name,
                description: description,
                category: category,
                muscleGroups: muscleGroups,
                suggestedExercises: suggestedExercises,
                confidence: confidence,
                isOfficialEquipment: true // Default to true when parsing from text (agent should specify in structured response)
            )
        }
    }
    
    private func extractEquipmentName(from text: String) -> String {
        // Don't extract equipment name from text - let the agent provide it in structured format
        // If we're parsing from text, it means the agent didn't provide structured data
        // Return empty string to trigger empty state
        return ""
    }
    
    private func extractDescription(from text: String, name: String) -> String {
        // Remove the name line and extract description
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.lowercased().contains(name.lowercased()) }
        
        // Join remaining lines as description
        var description = lines.joined(separator: " ")
        
        // Clean up common prefixes
        description = description.replacingOccurrences(of: #"^(?:this|it|the)\s+"#, with: "", options: .regularExpression)
        
        return description.isEmpty ? "Equipment for strength training and muscle development." : description
    }
    
    private func extractMuscleGroups(from text: String) -> [String] {
        let muscleKeywords = ["chest", "back", "legs", "shoulders", "arms", "biceps", "triceps", "core", "abs", "glutes", "hamstrings", "quads", "quadriceps", "calves", "lats", "delts", "traps", "pecs", "biceps", "triceps", "forearms", "traps"]
        var foundMuscles: [String] = []
        let lowerText = text.lowercased()
        
        for muscle in muscleKeywords {
            if lowerText.contains(muscle) {
                foundMuscles.append(muscle.capitalized)
            }
        }
        
        // Remove duplicates
        return Array(Set(foundMuscles))
    }
    
    private func extractCategory(from text: String, name: String) -> String {
        let lowerText = text.lowercased()
        let lowerName = name.lowercased()
        
        // Categorize based on keywords
        if lowerName.contains("cable") || lowerText.contains("cable") {
            return "Cable Machine"
        } else if lowerName.contains("smith") || lowerText.contains("smith") {
            return "Smith Machine"
        } else if lowerName.contains("dumbbell") || lowerText.contains("dumbbell") {
            return "Free Weights"
        } else if lowerName.contains("barbell") || lowerText.contains("barbell") {
            return "Free Weights"
        } else if lowerName.contains("bench") || lowerText.contains("bench") {
            return "Bench"
        } else if lowerName.contains("rack") || lowerText.contains("rack") {
            return "Rack"
        } else if lowerName.contains("machine") || lowerText.contains("machine") {
            return "Machine"
        } else {
            return "Strength Equipment"
        }
    }
    
    private func extractSuggestedExercises(from text: String) -> [String] {
        var exercises: [String] = []
        
        // Look for exercise patterns
        let exerciseKeywords = ["bench press", "squat", "deadlift", "row", "curl", "press", "fly", "extension", "raise", "pull", "push"]
        
        let lowerText = text.lowercased()
        for keyword in exerciseKeywords {
            if lowerText.contains(keyword) {
                // Try to extract the full exercise name
                if let range = lowerText.range(of: keyword) {
                    let start = text.index(text.startIndex, offsetBy: text.distance(from: text.startIndex, to: range.lowerBound))
                    let end = text.index(start, offsetBy: min(50, text.distance(from: start, to: text.endIndex)))
                    let exercise = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if exercise.count > 3 && exercise.count < 50 {
                        exercises.append(exercise.capitalized)
                    }
                }
            }
        }
        
        // If no exercises found, use muscle groups to suggest
        if exercises.isEmpty {
            let muscleGroups = extractMuscleGroups(from: text)
            for muscle in muscleGroups {
                exercises.append("\(muscle) Exercises")
            }
        }
        
        return Array(exercises.prefix(5))
    }
    
    private func extractConfidence(from text: String) -> Double {
        let lowerText = text.lowercased()
        
        // High confidence indicators
        if lowerText.contains("clearly") || lowerText.contains("definitely") || lowerText.contains("certain") {
            return 0.9
        }
        
        // Medium confidence indicators
        if lowerText.contains("approximately") || lowerText.contains("appears") || lowerText.contains("likely") || lowerText.contains("seems") {
            return 0.7
        }
        
        // Low confidence indicators
        if lowerText.contains("uncertain") || lowerText.contains("unclear") || lowerText.contains("difficult") || lowerText.contains("hard to") {
            return 0.5
        }
        
        // Default medium-high
        return 0.8
    }
    
    // MARK: - Actions
    
    private func handleQuestion(_ question: String) {
        guard !question.isEmpty else { return }
        
        isProcessingQuestion = true
        
        Task {
            // Send question back to Genie for clarification
            do {
                let response = try await GenieAPIService.shared.query(
                    "Regarding the equipment I just analyzed: \(question)",
                    sessionId: GenieConversationManager.shared.currentConversationId ?? UUID().uuidString
                )
                
                await MainActor.run {
                    // Re-parse with new response
                    isProcessingQuestion = false
                    showingQuestionInput = false
                    questionText = ""
                    parseFromText(response.response)
                }
            } catch {
                print("❌ [Equipment] Error asking question: \(error)")
                await MainActor.run {
                    isProcessingQuestion = false
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct ParsedEquipmentData {
    let name: String
    let description: String
    let category: String
    let muscleGroups: [String]
    let suggestedExercises: [String]
    let confidence: Double
    let isOfficialEquipment: Bool
}

struct RankedEquipment: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: String
    let muscleGroups: [String]
    let suggestedExercises: [String]
    let confidence: Double
    let relevanceScore: Double
    let isOfficialEquipment: Bool
}

// MARK: - UI Components

struct RankedEquipmentCard: View {
    let equipment: RankedEquipment
    let onWatchTutorials: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(equipment.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                    
                    Text(equipment.category)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.brandOrange)
                }
                
                Spacer()
                
                // Relevance score badge
                if equipment.relevanceScore < 1.0 {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                            Text("\(Int(equipment.relevanceScore * 100))%")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(Color.brandOrange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.brandOrange.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            
            if !equipment.description.isEmpty {
                Text(equipment.description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .lineSpacing(4)
            }
            
            if !equipment.muscleGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(equipment.muscleGroups, id: \.self) { muscle in
                            Text(muscle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.brandOrange.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            
            Button {
                onWatchTutorials()
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Watch Tutorials")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.brandOrange, Color("FF6B35")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct EquipmentNameCard: View {
    let name: String
    let category: String
    let isNonOfficial: Bool
    
    init(name: String, category: String, isNonOfficial: Bool = false) {
        self.name = name
        self.category = category
        self.isNonOfficial = isNonOfficial
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
            
            HStack(spacing: 8) {
                Image(systemName: isNonOfficial ? "lightbulb.fill" : "figure.strengthtraining.traditional")
                    .font(.system(size: 14, weight: .semibold))
                Text(category)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(Color.brandOrange)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.brandOrange.opacity(0.2))
            )
            
            // Show message for non-official equipment
            if isNonOfficial {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                    Text("Not official gym equipment, but great for workouts!")
                        .font(.system(size: 13, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                }
                .foregroundColor(Color.brandOrange)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.brandOrange.opacity(0.15))
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.brandOrange.opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

struct MuscleGroupsCard: View {
    let muscleGroups: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 16))
                    .foregroundColor(Color.brandOrange)
                Text("Target Muscles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(muscleGroups, id: \.self) { muscle in
                    Text(muscle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.brandOrange.opacity(0.2))
                        )
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}

struct DescriptionCard: View {
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 16))
                    .foregroundColor(Color.brandOrange)
                Text("Description")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(description)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct SuggestedExercisesCard: View {
    let exercises: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 16))
                    .foregroundColor(Color.brandOrange)
                Text("Suggested Exercises")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(exercises, id: \.self) { exercise in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.brandOrange)
                            .padding(.top, 2)
                        Text(exercise)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct EmptyEquipmentStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(Color.brandOrange.opacity(0.6))
            
            Text("No Equipment Identified")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("We couldn't identify any workout equipment or usable items in this image. Try taking a clearer photo or pointing the camera at gym equipment, benches, walls, or other workout-usable items.")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}
