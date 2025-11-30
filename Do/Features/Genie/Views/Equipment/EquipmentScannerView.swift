//
//  EquipmentScannerView.swift
//  Do
//
//  Equipment scanner with workout suggestions
//

import SwiftUI

struct EquipmentScannerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var visionService = GenieVisionService.shared
    @StateObject private var trackingService = GenieWorkoutTrackingService.shared
    @StateObject private var voiceService = GenieVoiceService.shared
    
    @State private var capturedImage: UIImage?
    @State private var identifiedEquipment: Equipment?
    @State private var isAnalyzing = false
    @State private var showWorkoutSelection = false
    @State private var showTutorials = false
    @State private var selectedWorkout: EquipmentWorkout?
    @State private var detectedRegions: [DetectionRegion] = []
    @State private var isDetecting = false
    @State private var scanAnimationProgress: CGFloat = 0
    @State private var listeningForTutorials = false
    
    struct DetectionRegion: Identifiable {
        let id = UUID()
        let rect: CGRect
        let label: String
        let confidence: Float
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 15/255, green: 22/255, blue: 62/255),
                        Color(red: 25/255, green: 32/255, blue: 72/255)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if let image = capturedImage {
                            // Captured image
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(16)
                                .shadow(radius: 10)
                        } else {
                            // Camera placeholder
                            VStack(spacing: 16) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 80))
                                    .foregroundColor(.orange)
                                
                                Text("Scan Gym Equipment")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                
                                Text("Take a photo of any gym equipment to identify it and get workout suggestions")
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(height: 300)
                        }
                        
                        // Capture button
                        if capturedImage == nil {
                            Button(action: capturePhoto) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Take Photo")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Analysis result
                        if isAnalyzing {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.orange)
                                Text("Analyzing equipment...")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding()
                        }
                        
                        if let equipment = identifiedEquipment {
                            equipmentCard(equipment)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Equipment Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
                
                if capturedImage != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Retake") {
                            capturedImage = nil
                            identifiedEquipment = nil
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
        }
        .sheet(isPresented: $showWorkoutSelection) {
            if let equipment = identifiedEquipment {
                WorkoutSelectionView(
                    equipment: equipment,
                    onWorkoutSelected: { workout in
                        startWorkout(workout)
                    }
                )
            }
        }
        .sheet(isPresented: $showTutorials) {
            if let equipment = identifiedEquipment {
                EquipmentTutorialsView(
                    equipment: equipment,
                    suggestedExercises: equipment.suggestedWorkouts.map { $0.name },
                    category: "equipment"
                )
            }
        }
        .onChange(of: voiceService.recognizedText) { text in
            if listeningForTutorials && !text.isEmpty {
                handleVoiceCommand(text)
            }
        }
    }
    
    private func equipmentCard(_ equipment: Equipment) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Equipment name
            Text(equipment.name)
                .font(.title.bold())
                .foregroundColor(.white)
            
            // Description
            Text(equipment.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
            
            // Muscle groups
            if !equipment.muscleGroups.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Muscles")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(equipment.muscleGroups, id: \.self) { muscle in
                            Text(muscle.capitalized)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.3))
                                )
                        }
                    }
                }
            }
            
            // Action buttons
            VStack(spacing: 12) {
                // Tutorials button
                Button(action: {
                    showTutorials = true
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Watch Tutorials")
                    }
                    .font(.headline)
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
                
                // Voice command button
                Button(action: {
                    if listeningForTutorials {
                        voiceService.stopListening()
                        listeningForTutorials = false
                    } else {
                        startListeningForTutorials()
                    }
                }) {
                    HStack {
                        Image(systemName: listeningForTutorials ? "mic.fill" : "mic")
                            .foregroundColor(listeningForTutorials ? .red : .white)
                        Text(listeningForTutorials ? "Listening..." : "Voice: Show Tutorials")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(listeningForTutorials ? Color.red : Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Workouts button
                Button(action: {
                    generateWorkouts()
                }) {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                        Text("Show Workouts")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
        .padding(.horizontal)
    }
    
    private func capturePhoto() {
        Task {
            // Get current view controller
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let viewController = windowScene.windows.first?.rootViewController else {
                return
            }
            
            if let image = await visionService.captureImage(from: viewController) {
                await MainActor.run {
                    capturedImage = image
                }
                await analyzeEquipment(image)
            }
        }
    }
    
    private func analyzeEquipment(_ image: UIImage) async {
        await MainActor.run {
            isAnalyzing = true
        }
        
        defer {
            Task { @MainActor in
                isAnalyzing = false
            }
        }
        
        do {
            // Use Genie API to analyze equipment - this ensures we get live data
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                print("❌ [Equipment] Failed to convert image to data")
                return
            }
            let base64 = imageData.base64EncodedString()
            
            // Get conversation context
            let conversationId = GenieConversationManager.shared.currentConversationId ?? UUID().uuidString
            
            // Send to Genie API for equipment identification
            let response = try await GenieAPIService.shared.queryWithImage(
                "Identify this gym equipment. Provide: 1. Equipment name (be specific), 2. What muscle groups it targets, 3. Brief description. Format clearly with equipment name first.",
                imageBase64: base64,
                sessionId: conversationId
            )
            
            // Parse equipment from response
            let equipment = parseEquipmentFromResponse(response.response, image: image)
            
            await MainActor.run {
                identifiedEquipment = equipment
            }
        } catch {
            print("❌ [Equipment] Error analyzing equipment: \(error)")
        }
    }
    
    private func parseEquipmentFromResponse(_ response: String, image: UIImage?) -> Equipment {
        // Clean markdown
        let cleanedResponse = MarkdownFormatter.cleanMarkdown(response)
        
        // Extract equipment name
        var name = "Unknown Equipment"
        let lines = cleanedResponse.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        // Look for equipment name in first few lines
        for line in lines.prefix(5) {
            let lower = line.lowercased()
            // Skip common prefixes
            if lower.contains("this is") || lower.contains("i can see") || lower.contains("this appears") {
                // Extract name after "a" or "an"
                if let match = line.range(of: #"(?:this is|i can see|this appears)\s+(?:a|an)\s+([A-Z][a-z]+(?:\s+[a-z]+)*)"#, options: [.regularExpression, .caseInsensitive]) {
                    let extracted = String(line[match])
                    if let nameMatch = extracted.range(of: #"[A-Z][a-z]+(?:\s+[a-z]+)*"#, options: .regularExpression) {
                        name = String(extracted[nameMatch])
                        break
                    }
                }
            } else if line.count > 3 && line.count < 60 && 
                      !lower.contains("muscle") && !lower.contains("target") &&
                      !lower.contains("equipment") && !lower.contains("machine") &&
                      line.first?.isUppercase == true {
                // First significant capitalized line
                name = line
                break
            }
        }
        
        // Extract muscle groups
        let muscleKeywords = ["chest", "back", "legs", "shoulders", "arms", "biceps", "triceps", "core", "abs", "glutes", "hamstrings", "quads", "quadriceps", "calves", "lats", "delts", "traps"]
        var foundMuscles: [String] = []
        let lowerResponse = cleanedResponse.lowercased()
        
        for muscle in muscleKeywords {
            if lowerResponse.contains(muscle) {
                foundMuscles.append(muscle.capitalized)
            }
        }
        
        // Build description
        let description = lines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        
        return Equipment(
            id: UUID().uuidString,
            name: name,
            description: description.isEmpty ? cleanedResponse : description,
            muscleGroups: foundMuscles,
            image: image,
            suggestedWorkouts: []
        )
    }
    
    private func generateWorkouts() {
        guard let equipment = identifiedEquipment else { return }
        
        // Generate workouts using Genie
        Task {
            do {
                let query = "Show me 5 exercises I can do with a \(equipment.name). For each exercise, provide: name, description, sets, reps, difficulty, and step-by-step instructions."
                
                let response = try await GenieAPIService.shared.query(query)
                
                // Parse workouts from response
                // For now, show workout selection
                showWorkoutSelection = true
            } catch {
                print("Error generating workouts: \(error)")
            }
        }
    }
    
    private func startWorkout(_ workout: EquipmentWorkout) {
        guard let equipment = identifiedEquipment else { return }
        
        let trackedWorkout = trackingService.createWorkoutFromEquipment(equipment, selectedWorkout: workout)
        trackingService.startWorkout(trackedWorkout)
        
        dismiss()
    }
    
    private func startListeningForTutorials() {
        listeningForTutorials = true
        
        Task {
            do {
                let text = try await voiceService.startListening()
                await MainActor.run {
                    listeningForTutorials = false
                    handleVoiceCommand(text)
                }
            } catch {
                await MainActor.run {
                    listeningForTutorials = false
                }
            }
        }
    }
    
    private func handleVoiceCommand(_ text: String) {
        let lowerText = text.lowercased()
        
        // Check for tutorial-related commands
        if lowerText.contains("tutorial") || 
           lowerText.contains("how to") || 
           lowerText.contains("show me") ||
           lowerText.contains("video") ||
           lowerText.contains("watch") {
            if identifiedEquipment != nil {
                showTutorials = true
            }
        }
    }
}

// MARK: - Workout Selection View

struct WorkoutSelectionView: View {
    @Environment(\.dismiss) var dismiss
    let equipment: Equipment
    let onWorkoutSelected: (EquipmentWorkout) -> Void
    
    // Sample workouts - in production, these come from Genie
    @State private var workouts: [EquipmentWorkout] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 15/255, green: 22/255, blue: 62/255)
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .tint(.orange)
                        Text("Generating workouts...")
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(workouts) { workout in
                                WorkoutCard(workout: workout) {
                                    onWorkoutSelected(workout)
                                    dismiss()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .onAppear {
            loadWorkouts()
        }
    }
    
    private func loadWorkouts() {
        Task {
            // Generate sample workouts
            workouts = [
                EquipmentWorkout(
                    id: UUID().uuidString,
                    name: "Standard \(equipment.name) Exercise",
                    description: "Classic movement targeting primary muscles",
                    sets: 3,
                    reps: "12",
                    difficulty: "Intermediate",
                    instructions: [
                        "Position yourself correctly",
                        "Maintain proper form",
                        "Control the movement",
                        "Breathe steadily"
                    ],
                    videoURL: nil,
                    muscleGroups: equipment.muscleGroups
                )
            ]
            
            isLoading = false
        }
    }
}

struct WorkoutCard: View {
    let workout: EquipmentWorkout
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("\(workout.sets) sets × \(workout.reps) reps")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    Text(workout.difficulty)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(difficultyColor(workout.difficulty))
                        )
                }
                
                Text(workout.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                
                if !workout.muscleGroups.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(workout.muscleGroups, id: \.self) { muscle in
                            Text(muscle.capitalized)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
    
    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "beginner": return .green.opacity(0.3)
        case "intermediate": return .orange.opacity(0.3)
        case "advanced": return .red.opacity(0.3)
        default: return .gray.opacity(0.3)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
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
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
