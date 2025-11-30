//
//  GuidedMeditationsView.swift
//  Do.
//
//  Guided meditation library view
//

import SwiftUI

struct GuidedMeditationsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var apiService = GenieAPIService.shared
    @StateObject private var meditationService = GenieMeditationService.shared
    @StateObject private var trackingService = MeditationTrackingService.shared
    
    @State private var currentMeditation: MeditationLibraryItem?
    @State private var meditationStartTime: Date?
    
    @State private var meditations: [MeditationLibraryItem] = []
    @State private var featuredMeditations: [MeditationLibraryItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCategory: String?
    @State private var searchText = ""
    @State private var showSearch = false
    
    // Categories matching the library
    private let categories = [
        "Sleep", "Focus", "Stress & Anxiety", "Meditation Basics", "Movement",
        "Performance", "Healing & Recovery", "Sleep Health", "Work & Productivity",
        "Breathe", "Gratitude & Happiness", "Emotions", "Relationships", "Daily Practice"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(UIColor(red: 0.1, green: 0.0, blue: 0.2, alpha: 1.0)),
                        Color(UIColor(red: 0.2, green: 0.0, blue: 0.3, alpha: 1.0))
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Text("Error loading meditations")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Retry") {
                            loadMeditations()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Featured section
                            if !featuredMeditations.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Featured")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(featuredMeditations, id: \.meditationId) { meditation in
                                                MeditationLibraryCard(meditation: meditation, onSelect: startMeditation)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Categories
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Categories")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        // All button
                                        CategoryChip(
                                            title: "All",
                                            isSelected: selectedCategory == nil,
                                            action: { selectedCategory = nil; loadMeditations() }
                                        )
                                        
                                        ForEach(categories, id: \.self) { category in
                                            CategoryChip(
                                                title: category,
                                                isSelected: selectedCategory == category,
                                                action: {
                                                    selectedCategory = category
                                                    loadMeditations(category: category)
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            // All meditations
                            VStack(alignment: .leading, spacing: 12) {
                                Text(selectedCategory ?? "All Meditations")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredMeditations, id: \.meditationId) { meditation in
                                        MeditationLibraryCard(meditation: meditation, onSelect: startMeditation)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Guided Meditations")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(UIColor(red: 0.1, green: 0.0, blue: 0.2, alpha: 1.0)), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17, weight: .regular))
                        }
                        .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            showSearch.toggle()
                        }) {
                            Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            // Surprise me - random meditation
                            surpriseMe()
                        }) {
                            Image(systemName: "dice.fill")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .searchable(text: $searchText, prompt: "Search meditations...")
            .refreshable {
                loadMeditations()
            }
            .onAppear {
                // Set navigation bar title color to white
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                // Match the background gradient color
                let hexColor = UIColor(red: 0.1, green: 0.0, blue: 0.2, alpha: 1.0)
                appearance.backgroundColor = hexColor
                appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
                
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
                
                // Load meditations and setup callbacks
                loadMeditations()
                setupMeditationCallbacks()
            }
            .onDisappear {
                cleanupMeditationCallbacks()
            }
        }
    }
    
    func setupMeditationCallbacks() {
        // Track when meditation starts
        meditationService.onMeditationStart = { [self] script, libraryId in
            if let libraryId = libraryId, let meditation = self.currentMeditation {
                self.meditationStartTime = Date()
                print("🧘 [Library] Started meditation: \(meditation.title)")
            }
        }
        
        // Track when meditation completes
        meditationService.onMeditationComplete = { [self] completed in
            if let meditation = self.currentMeditation, let startTime = self.meditationStartTime {
                let endTime = Date()
                let duration = TimeInterval(meditation.duration * 60)
                let focus = self.mapCategoryToFocus(meditation.category)
                
                Task {
                    do {
                        try await self.trackingService.logLibraryMeditation(
                            libraryMeditationId: meditation.meditationId,
                            title: meditation.title,
                            category: meditation.category,
                            focus: focus,
                            duration: duration,
                            startTime: startTime,
                            endTime: completed ? endTime : nil,
                            completed: completed
                        )
                    } catch {
                        print("Error tracking library meditation: \(error)")
                    }
                }
                
                // Clear tracking state
                self.currentMeditation = nil
                self.meditationStartTime = nil
            }
        }
    }
    
    func cleanupMeditationCallbacks() {
        meditationService.onMeditationStart = nil
        meditationService.onMeditationComplete = nil
    }
    
    var filteredMeditations: [MeditationLibraryItem] {
        let allMeditations = meditations.filter { meditation in
            !featuredMeditations.contains(where: { $0.meditationId == meditation.meditationId })
        }
        
        if searchText.isEmpty {
            return allMeditations
        }
        
        return allMeditations.filter { meditation in
            meditation.title.localizedCaseInsensitiveContains(searchText) ||
            (meditation.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            meditation.category.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    func loadMeditations(category: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await apiService.getMeditationLibrary(
                    category: category,
                    duration: nil,
                    technique: nil,
                    limit: 100
                )
                
                await MainActor.run {
                    self.meditations = response.data.meditations
                    self.featuredMeditations = response.data.featured ?? []
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func startMeditation(_ meditation: MeditationLibraryItem) {
        // Store current meditation for tracking
        currentMeditation = meditation
        
        // Map library category to MeditationFocus
        let focus = mapCategoryToFocus(meditation.category)
        
        // Convert library item to MeditationScript
        let script = MeditationScript(
            duration: meditation.duration,
            focus: focus,
            segments: [MeditationSegment(name: meditation.title, content: meditation.script)]
        )
        
        // Start meditation with library ID for tracking
        meditationService.startMeditation(script, libraryMeditationId: meditation.meditationId)
        
        // Don't dismiss - let the meditation play
        // User can return to tracker after completion or manually dismiss
    }
    
    func mapCategoryToFocus(_ category: String) -> MeditationFocus {
        switch category.lowercased() {
        case "sleep", "sleep health":
            return .sleep
        case "focus", "work & productivity":
            return .focus
        case "stress & anxiety", "anxiety":
            return .anxiety
        case "breathe", "breathing":
            return .breathing
        case "gratitude & happiness":
            return .gratitude
        case "healing & recovery", "recovery":
            return .recovery
        case "movement", "meditation basics", "daily practice":
            return .bodyScan
        case "performance":
            return .energy
        case "emotions", "relationships":
            return .stress
        default:
            return .stress
        }
    }
    
    func surpriseMe() {
        Task {
            do {
                // Get all meditations
                let response = try await apiService.getMeditationLibrary(limit: 100)
                let allMeditations = response.data.meditations
                
                // Pick a random one
                if let randomMeditation = allMeditations.randomElement() {
                    await MainActor.run {
                        startMeditation(randomMeditation)
                    }
                }
            } catch {
                print("Error getting surprise meditation: \(error)")
            }
        }
    }
}
// MARK: - Supporting Views

struct MeditationLibraryCard: View {
    let meditation: MeditationLibraryItem
    let onSelect: (MeditationLibraryItem) -> Void
    
    var body: some View {
        Button(action: { onSelect(meditation) }) {
            HStack(spacing: 16) {
                // Cute character illustration with enhanced styling
                ZStack {
                    // Background glow
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    characterGradientColors.first?.opacity(0.3) ?? Color.clear,
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                MeditationCharacterView(category: meditation.category)
                    .frame(width: 80, height: 80)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meditation.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            
                            Text(meditation.description ?? "")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text("\(meditation.duration)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.976, green: 0.576, blue: 0.125),
                                            Color(red: 1.0, green: 0.42, blue: 0.21)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("min")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    // Tags with enhanced styling
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Text(meditation.category)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.purple.opacity(0.4),
                                                    Color.blue.opacity(0.4)
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            
                            Text(meditation.technique)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.4),
                                                    Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.4)
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        characterGradientColors.first?.opacity(0.1) ?? Color.clear,
                                        characterGradientColors.last?.opacity(0.05) ?? Color.clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var characterGradientColors: [Color] {
        let lowerCategory = meditation.category.lowercased()
        if lowerCategory.contains("sleep") {
            return [Color.purple, Color.blue]
        } else if lowerCategory.contains("focus") {
            return [Color(red: 0.976, green: 0.576, blue: 0.125), Color(red: 1.0, green: 0.42, blue: 0.21)]
        } else if lowerCategory.contains("stress") {
            return [Color.blue, Color.cyan]
        } else if lowerCategory.contains("breath") {
            return [Color.green, Color.mint]
        } else if lowerCategory.contains("gratitude") {
            return [Color.yellow, Color.orange]
        } else {
            return [Color.purple, Color.pink]
        }
    }
}

// MARK: - Cute Meditation Characters

struct MeditationCharacterView: View {
    let category: String
    @State private var bounceOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background circle with gradient
            Circle()
                .fill(characterBackgroundGradient)
                .frame(width: 80, height: 80)
            
            // Character illustration
            characterIllustration
                .offset(y: bounceOffset)
        }
        .onAppear {
            startBounceAnimation()
        }
    }
    
    private var characterIllustration: some View {
        Group {
            switch characterType {
            case .sleep:
                SleepCharacter()
            case .focus:
                FocusCharacter()
            case .stress:
                StressReliefCharacter()
            case .breathing:
                BreathingCharacter()
            case .gratitude:
                GratitudeCharacter()
            case .performance:
                PerformanceCharacter()
            case .recovery:
                RecoveryCharacter()
            case .default:
                MindfulnessCharacter()
            }
        }
    }
    
    private var characterType: MeditationCharacterType {
        let lowerCategory = category.lowercased()
        if lowerCategory.contains("sleep") {
            return .sleep
        } else if lowerCategory.contains("focus") || lowerCategory.contains("productivity") {
            return .focus
        } else if lowerCategory.contains("stress") || lowerCategory.contains("anxiety") {
            return .stress
        } else if lowerCategory.contains("breathe") {
            return .breathing
        } else if lowerCategory.contains("gratitude") || lowerCategory.contains("happiness") {
            return .gratitude
        } else if lowerCategory.contains("performance") || lowerCategory.contains("energy") {
            return .performance
        } else if lowerCategory.contains("healing") || lowerCategory.contains("recovery") {
            return .recovery
        }
        return .default
    }
    
    private var characterBackgroundGradient: LinearGradient {
        let colors = characterType.colors
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func startBounceAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            bounceOffset = -3
        }
    }
}

enum MeditationCharacterType {
    case sleep
    case focus
    case stress
    case breathing
    case gratitude
    case performance
    case recovery
    case `default`
    
    var colors: [Color] {
        switch self {
        case .sleep:
            return [Color(hex: "9B87F5").opacity(0.4), Color(hex: "6B5CE6").opacity(0.6)]
        case .focus:
            return [Color.brandOrange.opacity(0.4), Color(hex: "FFB84D").opacity(0.6)]
        case .stress:
            return [Color(hex: "4ECDC4").opacity(0.4), Color(hex: "44A08D").opacity(0.6)]
        case .breathing:
            return [Color(hex: "87CEEB").opacity(0.4), Color(hex: "5F9EA0").opacity(0.6)]
        case .gratitude:
            return [Color(hex: "FFD700").opacity(0.4), Color(hex: "FFA500").opacity(0.6)]
        case .performance:
            return [Color(hex: "FF6B6B").opacity(0.4), Color(hex: "FF8E53").opacity(0.6)]
        case .recovery:
            return [Color(hex: "A8E6CF").opacity(0.4), Color(hex: "7FCDBB").opacity(0.6)]
        case .default:
            return [Color(hex: "B19CD9").opacity(0.4), Color(hex: "8B7FA8").opacity(0.6)]
        }
    }
}

// MARK: - Character Illustrations

struct SleepCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Closed eyes (sleepy)
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 8, height: 3)
                    .offset(x: -8)
                Capsule()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 8, height: 3)
                    .offset(x: 8)
            }
            
            // Sleepy mouth (small smile)
            Capsule()
                .fill(Color.black.opacity(0.2))
                .frame(width: 12, height: 2)
                .offset(y: 8)
            
            // Moon above head
            Image(systemName: "moon.fill")
                .font(.system(size: 12))
                .foregroundColor(Color("FFD700").opacity(0.8))
                .offset(y: -35)
        }
    }
}

struct FocusCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Focused eyes (wide open)
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 10, height: 10)
            }
            
            // Determined mouth
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 14, height: 3)
                .offset(y: 10)
            
            // Lightbulb above (idea/insight)
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.brandOrange)
                .offset(y: -38)
        }
    }
}

struct StressReliefCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Relaxed eyes
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(-20))
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(20))
            }
            
            // Gentle smile
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 16, height: 3)
                .offset(y: 8)
            
            // Waves around (calm)
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 60 + CGFloat(index * 8))
            }
        }
    }
}

struct BreathingCharacter: View {
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
                .scaleEffect(scale)
            
            // Simple eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 8, height: 8)
            }
            
            // Open mouth (breathing)
            Ellipse()
                .fill(Color.black.opacity(0.2))
                .frame(width: 12, height: 8)
                .offset(y: 10)
            
            // Breath circles
            ForEach(0..<2) { index in
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: 40 + CGFloat(index * 10))
                    .scaleEffect(scale)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                scale = 1.2
            }
        }
    }
}

struct GratitudeCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Happy eyes
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(-20))
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(20))
            }
            
            // Big smile
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 20, height: 4)
                .offset(y: 10)
            
            // Heart above
            Image(systemName: "heart.fill")
                .font(.system(size: 12))
                .foregroundColor(Color("FF6B6B"))
                .offset(y: -35)
        }
    }
}

struct PerformanceCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Energetic eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 10, height: 10)
            }
            
            // Confident smile
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 18, height: 3)
                .offset(y: 10)
            
            // Lightning bolt (energy)
            Image(systemName: "bolt.fill")
                .font(.system(size: 14))
                .foregroundColor(Color("FFD700"))
                .offset(y: -38)
        }
    }
}

struct RecoveryCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Gentle eyes
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 8, height: 3)
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 8, height: 3)
            }
            
            // Soft smile
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 14, height: 3)
                .offset(y: 8)
            
            // Leaf (healing/nature)
            Image(systemName: "leaf.fill")
                .font(.system(size: 12))
                .foregroundColor(Color("4ECDC4"))
                .offset(y: -35)
        }
    }
}

struct MindfulnessCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Balanced eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 9, height: 9)
            }
            
            // Neutral, peaceful mouth
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 12, height: 2)
                .offset(y: 10)
            
            // Sparkles (mindfulness)
            ForEach(0..<3) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(0.6))
                    .offset(
                        x: cos(Double(index) * 2 * .pi / 3) * 25,
                        y: sin(Double(index) * 2 * .pi / 3) * 25
                    )
            }
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.purple.opacity(0.5) : Color.black.opacity(0.3))
                .cornerRadius(20)
        }
    }
}

