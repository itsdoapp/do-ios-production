import SwiftUI
import Foundation
import UIKit

struct GenieWorkoutPreviewView: View {
    let workoutAction: WorkoutCreationAction
    @Environment(\.dismiss) var dismiss
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showEditView = false
    @State private var savedItem: Any? = nil
    @State private var animateHeader = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Premium gradient background (like meditation tracker)
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 0.08, green: 0.0, blue: 0.15), location: 0),
                        .init(color: Color(red: 0.12, green: 0.02, blue: 0.22), location: 0.5),
                        .init(color: Color(red: 0.15, green: 0.03, blue: 0.28), location: 1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Modern Header with Illustration
                        headerSection
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        
                        // Details Card
                        detailsCard
                            .padding(.horizontal, 20)
                        
                        // Type-specific content with modern design
                        Group {
                            switch workoutAction.type {
                            case .movement:
                                movementContent
                            case .session:
                                sessionContent
                            case .plan:
                                planContent
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Action buttons
                        actionButtons
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showEditView) {
                editView
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateHeader = true
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Character illustration based on workout type
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: workoutTypeGradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: (workoutTypeGradient.first ?? Color.orange).opacity(0.4), radius: 20, x: 0, y: 10)
                
                Image(systemName: iconForType)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(animateHeader ? 1.0 : 0.8)
            .opacity(animateHeader ? 1.0 : 0.0)
            
            VStack(spacing: 8) {
                Text(workoutAction.name)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if let description = workoutAction.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .opacity(animateHeader ? 1.0 : 0.0)
        }
    }
    
    // MARK: - Details Card
    
    private var detailsCard: some View {
        VStack(spacing: 20) {
            // Category & Difficulty Row
            HStack(spacing: 16) {
                if let category = workoutAction.category {
                    DetailBadge(
                        icon: "tag.fill",
                        label: category,
                        gradient: [Color(red: 0.976, green: 0.576, blue: 0.125), Color(red: 1.0, green: 0.42, blue: 0.21)]
                    )
                }
                
                if let difficulty = workoutAction.difficulty {
                    DetailBadge(
                        icon: "chart.bar.fill",
                        label: difficulty.capitalized,
                        gradient: difficultyGradient(for: difficulty)
                    )
                }
                
                DetailBadge(
                    icon: workoutAction.equipmentNeeded ? "wrench.and.screwdriver.fill" : "figure.walk",
                    label: workoutAction.equipmentNeeded ? "Equipment" : "Bodyweight",
                    gradient: [Color.purple, Color.blue]
                )
            }
            
            // Tags
            if !workoutAction.tags.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tags")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    GenieWorkoutPreviewFlowLayout(spacing: 8) {
                        ForEach(workoutAction.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.3),
                                                    Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.3)
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Movement Content
    
    @ViewBuilder
    private var movementContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Workout Details")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            if let isSingle = workoutAction.isSingle, !isSingle {
                // Compound movement
                if let movement1Name = workoutAction.movement1Name {
                    ModernSetsSection(title: movement1Name, sets: workoutAction.firstSectionSets, icon: "figure.strengthtraining.traditional")
                }
                if let movement2Name = workoutAction.movement2Name {
                    ModernSetsSection(title: movement2Name, sets: workoutAction.secondSectionSets, icon: "figure.strengthtraining.traditional")
                }
                if let weavedSets = workoutAction.weavedSets, !weavedSets.isEmpty {
                    ModernSetsSection(title: "Weaved Sets", sets: weavedSets, icon: "arrow.triangle.2.circlepath")
                }
            } else {
                // Single movement
                if let firstSectionSets = workoutAction.firstSectionSets, !firstSectionSets.isEmpty {
                    ModernSetsSection(title: "Sets", sets: firstSectionSets, icon: "list.bullet.rectangle")
                } else if let weavedSets = workoutAction.weavedSets, !weavedSets.isEmpty {
                    ModernSetsSection(title: "Sets", sets: weavedSets, icon: "list.bullet.rectangle")
                }
            }
        }
    }
    
    // MARK: - Session Content
    
    @ViewBuilder
    private var sessionContent: some View {
        if let movements = workoutAction.movements, !movements.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                Text("Exercises")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                ForEach(Array(movements.enumerated()), id: \.offset) { index, movement in
                    ModernMovementCard(movement: movement, index: index + 1)
                }
            }
        }
    }
    
    // MARK: - Plan Content
    
    @ViewBuilder
    private var planContent: some View {
        if let sessions = workoutAction.sessions, !sessions.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                Text("Schedule")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                let sortedKeys = workoutAction.isDayOfTheWeekPlan == true
                    ? ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                        .filter { sessions.keys.contains($0) }
                    : sessions.keys.sorted { key1, key2 in
                        let num1 = Int(key1.replacingOccurrences(of: "Day ", with: "")) ?? 0
                        let num2 = Int(key2.replacingOccurrences(of: "Day ", with: "")) ?? 0
                        return num1 < num2
                    }
                
                ForEach(sortedKeys, id: \.self) { key in
                    if let value = sessions[key] {
                        ModernScheduleCard(day: key, value: value)
                    }
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                saveToLibrary()
            }) {
                HStack(spacing: 12) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    Text(isSaving ? "Saving..." : "Save to Library")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.976, green: 0.576, blue: 0.125),
                            Color(red: 1.0, green: 0.42, blue: 0.21)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.4), radius: 16, x: 0, y: 8)
            }
            .disabled(isSaving)
            
            HStack(spacing: 12) {
                Button(action: {
                    showEditView = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Edit")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var iconForType: String {
        switch workoutAction.type {
        case .movement: return "figure.strengthtraining.traditional"
        case .session: return "list.bullet.rectangle"
        case .plan: return "calendar"
        }
    }
    
    private var workoutTypeGradient: [Color] {
        switch workoutAction.type {
        case .movement:
            return [Color(red: 0.976, green: 0.576, blue: 0.125), Color(red: 1.0, green: 0.42, blue: 0.21)]
        case .session:
            return [Color.purple, Color.blue]
        case .plan:
            return [Color.blue, Color.cyan]
        }
    }
    
    private func difficultyGradient(for difficulty: String) -> [Color] {
        switch difficulty.lowercased() {
        case "beginner":
            return [Color.green, Color.mint]
        case "intermediate":
            return [Color.orange, Color.yellow]
        case "advanced", "expert":
            return [Color.red, Color.pink]
        default:
            return [Color.gray, Color.gray.opacity(0.7)]
        }
    }
    
    // MARK: - Edit View
    
    @ViewBuilder
    private var editView: some View {
        Group {
            switch workoutAction.type {
            case .movement:
                if let movement = convertToMovement() {
                    EditMovementWrapper(movement: movement) { savedMovement in
                        showEditView = false
                        GenieActionHandler.shared.showingMovementPreview = false
                        dismiss()
                    }
                } else {
                    EmptyView()
                }
            case .session:
                if let session = convertToSession() {
                    EditSessionWrapper(session: session) { savedSession in
                        showEditView = false
                        GenieActionHandler.shared.showingSessionPreview = false
                        dismiss()
                    }
                } else {
                    EmptyView()
                }
            case .plan:
                if let plan = convertToPlan() {
                    EditPlanWrapper(plan: plan) { savedPlan in
                        showEditView = false
                        GenieActionHandler.shared.showingPlanPreview = false
                        dismiss()
                    }
                } else {
                    EmptyView()
                }
            }
        }
    }
    
    // MARK: - Save Functions
    
    private func saveToLibrary() {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            errorMessage = "Unable to get user ID"
            showError = true
            return
        }
        
        isSaving = true
        
        switch workoutAction.type {
        case .movement:
            saveMovement(userId: userId)
        case .session:
            saveSession(userId: userId)
        case .plan:
            savePlan(userId: userId)
        }
    }
    
    private func saveMovement(userId: String) {
        AWSWorkoutService.shared.createMovement(
            userId: userId,
            movement1Name: workoutAction.movement1Name ?? workoutAction.name,
            movement2Name: workoutAction.movement2Name,
            isSingle: workoutAction.isSingle ?? true,
            isTimed: workoutAction.isTimed ?? false,
            category: workoutAction.category,
            difficulty: workoutAction.difficulty,
            equipmentsNeeded: workoutAction.equipmentNeeded,
            description: workoutAction.description,
            tags: workoutAction.tags,
            firstSectionSets: workoutAction.firstSectionSets ?? [],
            secondSectionSets: workoutAction.secondSectionSets ?? [],
            weavedSets: workoutAction.weavedSets ?? []
        ) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success(let item):
                    var savedMovement = movement()
                    savedMovement.id = item.movementId ?? ""
                    savedMovement.movement1Name = item.movement1Name
                    savedMovement.movement2Name = item.movement2Name
                    savedMovement.isSingle = item.isSingle ?? true
                    savedMovement.isTimed = item.isTimed ?? false
                    savedMovement.category = item.category
                    savedMovement.description = item.description
                    savedMovement.difficulty = item.difficulty
                    // Convert Bool? to [String]? - if equipmentNeeded is true, use empty array (equipment needed but not specified)
                    savedMovement.equipmentsNeeded = item.equipmentNeeded == true ? [] : nil
                    savedMovement.tags = item.tags
                    
                    NotificationCenter.default.post(name: NSNotification.Name("MovementCreated"), object: savedMovement)
                    GenieActionHandler.shared.showingMovementPreview = false
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func saveSession(userId: String) {
        var movementsArray: [[String: Any]] = []
        if let movements = workoutAction.movements {
            for movement in movements {
                var movementDict: [String: Any] = [
                    "movement1Name": movement.movement1Name ?? movement.name,
                    "isSingle": movement.isSingle ?? true,
                    "isTimed": movement.isTimed ?? false,
                    "equipmentNeeded": movement.equipmentNeeded
                ]
                
                if let movement2Name = movement.movement2Name {
                    movementDict["movement2Name"] = movement2Name
                }
                if let category = movement.category {
                    movementDict["category"] = category
                }
                if let difficulty = movement.difficulty {
                    movementDict["difficulty"] = difficulty
                }
                if let description = movement.description {
                    movementDict["description"] = description
                }
                if let firstSectionSets = movement.firstSectionSets {
                    movementDict["firstSectionSets"] = firstSectionSets
                }
                if let secondSectionSets = movement.secondSectionSets {
                    movementDict["secondSectionSets"] = secondSectionSets
                }
                if let weavedSets = movement.weavedSets {
                    movementDict["weavedSets"] = weavedSets
                }
                
                movementsArray.append(movementDict)
            }
        }
        
        AWSWorkoutService.shared.createSession(
            userId: userId,
            name: workoutAction.name,
            description: workoutAction.description,
            movements: movementsArray,
            difficulty: workoutAction.difficulty,
            equipmentNeeded: workoutAction.equipmentNeeded,
            tags: workoutAction.tags
        ) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success(let item):
                    var savedSession = workoutSession()
                    savedSession.id = item.sessionId ?? ""
                    savedSession.name = item.name
                    savedSession.description = item.description
                    savedSession.difficulty = item.difficulty
                    // Convert Bool? to [String]? - if equipmentNeeded is true, use empty array (equipment needed but not specified)
                    savedSession.equipmentNeeded = item.equipmentNeeded == true ? [] : nil
                    
                    NotificationCenter.default.post(name: NSNotification.Name("SessionCreated"), object: savedSession)
                    GenieActionHandler.shared.showingSessionPreview = false
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func savePlan(userId: String) {
        AWSWorkoutService.shared.createPlan(
            userId: userId,
            name: workoutAction.name,
            description: workoutAction.description,
            sessions: workoutAction.sessions ?? [:],
            isDayOfTheWeekPlan: workoutAction.isDayOfTheWeekPlan ?? false,
            difficulty: workoutAction.difficulty,
            equipmentNeeded: workoutAction.equipmentNeeded,
            tags: workoutAction.tags
        ) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success(let item):
                    var savedPlan = plan()
                    savedPlan.id = item.planId ?? ""
                    savedPlan.name = item.name ?? ""
                    savedPlan.description = item.description
                    savedPlan.difficulty = item.difficulty
                    // plan.equipmentNeeded is Bool?, so we can assign directly
                    savedPlan.equipmentNeeded = item.equipmentNeeded
                    savedPlan.isDayOfTheWeekPlan = item.isDayOfTheWeekPlan
                    // sessions is [String: String]? (day name -> session ID)
                    savedPlan.sessions = item.sessions
                    
                    NotificationCenter.default.post(name: NSNotification.Name("PlanCreated"), object: savedPlan)
                    GenieActionHandler.shared.showingPlanPreview = false
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Conversion Helpers
    
    private func convertToMovement() -> movement? {
        var m = movement()
        m.movement1Name = workoutAction.movement1Name ?? workoutAction.name
        m.movement2Name = workoutAction.movement2Name
        m.isSingle = workoutAction.isSingle ?? true
        m.isTimed = workoutAction.isTimed ?? false
        m.category = workoutAction.category
        m.difficulty = workoutAction.difficulty
        m.description = workoutAction.description
        // Convert Bool to [String]? - if equipmentNeeded is true, use empty array (equipment needed but not specified)
        m.equipmentsNeeded = workoutAction.equipmentNeeded ? [] : nil
        m.tags = workoutAction.tags.isEmpty ? nil : workoutAction.tags
        
        if let firstSectionSets = workoutAction.firstSectionSets {
            m.firstSectionSets = convertSets(from: firstSectionSets)
        }
        if let secondSectionSets = workoutAction.secondSectionSets {
            m.secondSectionSets = convertSets(from: secondSectionSets)
        }
        if let weavedSets = workoutAction.weavedSets {
            m.weavedSets = convertSets(from: weavedSets)
        }
        
        return m
    }
    
    private func convertToSession() -> workoutSession? {
        var s = workoutSession()
        s.name = workoutAction.name
        s.description = workoutAction.description
        s.difficulty = workoutAction.difficulty
        // Convert Bool to [String]? - if equipmentNeeded is true, use empty array (equipment needed but not specified)
        s.equipmentNeeded = workoutAction.equipmentNeeded ? [] : nil
        
        if let movements = workoutAction.movements {
            s.movementsInSession = movements.compactMap { movementAction in
                var m = movement()
                m.movement1Name = movementAction.movement1Name ?? movementAction.name
                m.movement2Name = movementAction.movement2Name
                m.isSingle = movementAction.isSingle ?? true
                m.isTimed = movementAction.isTimed ?? false
                m.category = movementAction.category
                m.difficulty = movementAction.difficulty
                m.description = movementAction.description
                // Convert Bool to [String]? - if equipmentNeeded is true, use empty array (equipment needed but not specified)
                m.equipmentsNeeded = movementAction.equipmentNeeded ? [] : nil
                m.tags = movementAction.tags.isEmpty ? nil : movementAction.tags
                
                if let firstSectionSets = movementAction.firstSectionSets {
                    m.firstSectionSets = convertSets(from: firstSectionSets)
                }
                if let secondSectionSets = movementAction.secondSectionSets {
                    m.secondSectionSets = convertSets(from: secondSectionSets)
                }
                if let weavedSets = movementAction.weavedSets {
                    m.weavedSets = convertSets(from: weavedSets)
                }
                
                return m
            }
        }
        
        return s
    }
    
    private func convertToPlan() -> plan? {
        var p = plan()
        p.name = workoutAction.name
        p.description = workoutAction.description
        p.difficulty = workoutAction.difficulty
        // plan.equipmentNeeded is Bool?, so we can assign directly
        p.equipmentNeeded = workoutAction.equipmentNeeded
        p.isDayOfTheWeekPlan = workoutAction.isDayOfTheWeekPlan
        // workoutAction.sessions is [String: String]? where key=day, value=sessionId
        // sessions property is also [String: String]?, so assign directly
        p.sessions = workoutAction.sessions
        
        return p
    }
    
    private func convertSets(from sets: [[String: Any]]) -> [set] {
        return sets.compactMap { setDict in
            var converted = set()
            converted.id = UUID().uuidString
            
            func intValue(for key: String) -> Int? {
                if let value = setDict[key] as? Int {
                    return value
                }
                if let value = setDict[key] as? Double {
                    return Int(value)
                }
                if let value = setDict[key] as? String {
                    return Int(value)
                }
                return nil
            }
            
            func doubleValue(for key: String) -> Double? {
                if let value = setDict[key] as? Double {
                    return value
                }
                if let value = setDict[key] as? Int {
                    return Double(value)
                }
                if let value = setDict[key] as? String {
                    return Double(value)
                }
                return nil
            }
            
            converted.weight = doubleValue(for: "weight")
            converted.reps = intValue(for: "reps")
            converted.duration = intValue(for: "sec") ?? intValue(for: "time")
            converted.restPeriod = intValue(for: "rest")
            converted.notes = setDict["notes"] as? String
            converted.completed = setDict["completed"] as? Bool ?? false
            
            return converted
        }
    }
}

// MARK: - Supporting Views

struct DetailBadge: View {
    let icon: String
    let label: String
    let gradient: [Color]
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: gradient.map { $0.opacity(0.3) }),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: gradient),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct ModernSetsSection: View {
    let title: String
    let sets: [[String: Any]]?
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red: 0.976, green: 0.576, blue: 0.125))
                
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            if let sets = sets, !sets.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(sets.enumerated()), id: \.offset) { index, setDict in
                        ModernSetRow(setDict: setDict, setNumber: index + 1)
                    }
                }
            } else {
                Text("No sets defined")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ModernSetRow: View {
    let setDict: [String: Any]
    let setNumber: Int
    
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.3),
                                Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Text("\(setNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            if let isTimed = setDict["isTimed"] as? Bool, isTimed {
                if let sec = setDict["sec"] as? String ?? (setDict["sec"] as? Int).map({ String($0) }) ?? setDict["time"] as? String ?? (setDict["time"] as? Int).map({ String($0) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                        Text("\(sec)s")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
            } else {
                HStack(spacing: 12) {
                    if let weight = setDict["weight"] as? String ?? (setDict["weight"] as? Int).map({ String($0) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "scalemass.fill")
                                .font(.system(size: 12))
                            Text("\(weight) lbs")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                    }
                    if let reps = setDict["reps"] as? String ?? (setDict["reps"] as? Int).map({ String($0) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                            Text("× \(reps)")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct ModernMovementCard: View {
    let movement: WorkoutCreationAction
    let index: Int
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.976, green: 0.576, blue: 0.125),
                                Color(red: 1.0, green: 0.42, blue: 0.21)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Text("\(index)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(movement.movement1Name ?? movement.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                if let movement2Name = movement.movement2Name {
                    Text(movement2Name)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let sets = movement.firstSectionSets ?? movement.weavedSets, !sets.isEmpty {
                    Text("\(sets.count) sets")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ModernScheduleCard: View {
    let day: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.6),
                                Color.cyan.opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "calendar")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(day)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Flow Layout (keep existing implementation)

struct GenieWorkoutPreviewFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? 0,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Edit View Wrappers (keep existing implementation)

struct EditMovementWrapper: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draftMovement: movement
    let onSave: (movement) -> Void
    
    init(movement: movement, onSave: @escaping (movement) -> Void) {
        self._draftMovement = State(initialValue: movement)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Primary Exercise")) {
                    TextField("Exercise name", text: stringBinding($draftMovement.movement1Name))
                    Toggle("Single movement", isOn: $draftMovement.isSingle)
                    Toggle("Timed movement", isOn: $draftMovement.isTimed)
                }
                
                Section(header: Text("Secondary Exercise")) {
                    TextField("Second exercise", text: stringBinding($draftMovement.movement2Name))
                        .disabled(draftMovement.isSingle)
                }
                
                Section(header: Text("Details")) {
                    TextField("Category", text: stringBinding($draftMovement.category))
                    TextField("Difficulty", text: stringBinding($draftMovement.difficulty))
                    TextField("Description", text: stringBinding($draftMovement.description))
                }
            }
            .navigationTitle("Edit Movement")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        NotificationCenter.default.post(name: NSNotification.Name("MovementCreated"), object: draftMovement)
                        onSave(draftMovement)
                        dismiss()
                    }
                    .disabled((draftMovement.movement1Name ?? "").isEmpty)
                }
            }
        }
    }
}

struct EditSessionWrapper: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draftSession: workoutSession
    let onSave: (workoutSession) -> Void
    
    init(session: workoutSession, onSave: @escaping (workoutSession) -> Void) {
        self._draftSession = State(initialValue: session)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Session Info")) {
                    TextField("Name", text: stringBinding($draftSession.name))
                    TextField("Description", text: stringBinding($draftSession.description))
                    TextField("Difficulty", text: stringBinding($draftSession.difficulty))
                }
                
                Section(header: Text("Details")) {
                    Stepper("Duration: \(draftSession.duration ?? 0) min", value: intBinding($draftSession.duration), in: 0...240)
                    Stepper("Calories: \(draftSession.calories ?? 0)", value: intBinding($draftSession.calories), in: 0...2000, step: 25)
                }
            }
            .navigationTitle("Edit Session")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        NotificationCenter.default.post(name: NSNotification.Name("SessionCreated"), object: draftSession)
                        onSave(draftSession)
                        dismiss()
                    }
                    .disabled((draftSession.name ?? "").isEmpty)
                }
            }
        }
    }
}

struct EditPlanWrapper: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draftPlan: plan
    let onSave: (plan) -> Void
    
    init(plan: plan, onSave: @escaping (plan) -> Void) {
        self._draftPlan = State(initialValue: plan)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Plan Info")) {
                    TextField("Name", text: $draftPlan.name)
                    TextField("Description", text: stringBinding($draftPlan.description))
                    TextField("Difficulty", text: stringBinding($draftPlan.difficulty))
                }
                
                Section(header: Text("Tags")) {
                    TextField("Comma separated tags", text: Binding(
                        get: { draftPlan.tags.joined(separator: ", ") },
                        set: { draftPlan.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
                    ))
                }
            }
            .navigationTitle("Edit Plan")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        NotificationCenter.default.post(name: NSNotification.Name("PlanCreated"), object: draftPlan)
                        onSave(draftPlan)
                        dismiss()
                    }
                    .disabled(draftPlan.name.isEmpty)
                }
            }
        }
    }
}

private func stringBinding(_ source: Binding<String?>, defaultValue: String = "") -> Binding<String> {
    Binding(
        get: { source.wrappedValue ?? defaultValue },
        set: { newValue in
            source.wrappedValue = newValue.isEmpty ? nil : newValue
        }
    )
}

private func intBinding(_ source: Binding<Int?>, defaultValue: Int = 0) -> Binding<Int> {
    Binding(
        get: { source.wrappedValue ?? defaultValue },
        set: { newValue in source.wrappedValue = newValue }
    )
}
