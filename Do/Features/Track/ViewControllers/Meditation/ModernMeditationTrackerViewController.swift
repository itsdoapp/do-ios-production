//
//  ModernMeditationTrackerViewController.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/26/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//


import SwiftUI
import UIKit
import CoreLocation
import MapKit
import HealthKit
import Combine
import WatchConnectivity
import Foundation

// MARK: - Main ModernMeditationTracker View Controller

class ModernMeditationTrackerViewController: UIViewController, ObservableObject, CategorySwitchable {
    
    // MARK: - Properties
    private var hostingController: UIHostingController<MeditationTrackerView>?
    private let meditationTracker = MeditationTrackingEngine.shared
    private var cancellables = Set<AnyCancellable>()
    
    weak var categoryDelegate: CategorySelectionDelegate?
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMeditationTracker()
        setupHostingController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - Setup Methods
    private func setupMeditationTracker() {
        // Initialize the meditation tracker and set up the current user
        if CurrentUserService.shared.user == nil {
            meditationTracker.setCurrentUser()
        } else {
            meditationTracker.currentUser = CurrentUserService.shared.user
        }
    }
    
    private func setupHostingController() {
        let meditationTrackerView = MeditationTrackerView(viewModel: self)
        hostingController = UIHostingController(rootView: meditationTrackerView)
        
        if let hostingController = hostingController {
            addChild(hostingController)
            view.addSubview(hostingController.view)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            hostingController.didMove(toParent: self)
        }
    }
    
    // MARK: - Public Methods
    public func startMeditation() {
        meditationTracker.startTracking()
    }
    
    public func handleCategorySelection(_ index: Int) {
        categoryDelegate?.didSelectCategory(at: index)
    }
}

// MARK: - Main SwiftUI View
struct MeditationTrackerView: View {
    @ObservedObject var viewModel: ModernMeditationTrackerViewController
    @StateObject private var meditationTracker = MeditationTrackingEngine.shared
    @StateObject private var meditationService = GenieMeditationService.shared
    @StateObject private var apiService = GenieAPIService.shared
    
    // State properties
    @State private var showingGuidedMeditations = false
    @State private var showingCategorySelector = false
    @State private var selectedCategoryIndex: Int = 7 // Default to Meditation (index 7)
    @State private var showAIMeditationSheet = false
    @State private var featuredMeditations: [MeditationLibraryItem] = []
    @State private var recommendedMeditations: [MeditationLibraryItem] = []
    @State private var timeBasedMeditations: [MeditationLibraryItem] = []
    @State private var isLoadingFeatured = false
    @State private var userPreferences: [String: Any] = [:]
    
    // Category data
    private let categoryTitles = ["Running", "Gym", "Cycling", "Hiking", "Walking", "Swimming", "Food", "Meditation", "Sports"]
    private let categoryIcons = ["figure.run", "figure.strengthtraining.traditional", "figure.outdoor.cycle", "figure.hiking", "figure.walk", "figure.pool.swim", "fork.knife", "sparkles", "sportscourt"]
    
    var body: some View {
        ZStack {
            // Premium background gradient
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.08, green: 0.0, blue: 0.15), location: 0),
                    .init(color: Color(red: 0.12, green: 0.02, blue: 0.22), location: 0.5),
                    .init(color: Color(red: 0.15, green: 0.03, blue: 0.28), location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header Section
                    headerSection()
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    
                    // Time-Based Suggestions
                    if !timeBasedMeditations.isEmpty {
                        timeBasedSection()
                            .padding(.horizontal, 20)
                    }
                    
                    // Personalized Recommendations
                    if !recommendedMeditations.isEmpty {
                        recommendedSection()
                            .padding(.horizontal, 20)
                    }
                    
                    // Featured Meditations (Library)
                    if !featuredMeditations.isEmpty {
                        featuredMeditationsSection()
                            .padding(.horizontal, 20)
                    }
                    
                    // Discovery & Spontaneity
                    discoverySection()
                        .padding(.horizontal, 20)
                    
                    // Quick Start Section
                    quickStartSection()
                        .padding(.horizontal, 20)
                    
                    // Browse Library Section
                    browseLibrarySection()
                        .padding(.horizontal, 20)
                    
                    // Progress Stats
                    progressStatsSection()
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
            }
        }
        .onAppear {
            loadFeaturedMeditations()
            loadPersonalizedContent()
            setupMeditationTracking()
        }
        .sheet(isPresented: $showingCategorySelector) {
            CategorySelectorView(
                isPresented: $showingCategorySelector,
                selectedCategory: Binding(
                    get: { self.selectedCategoryIndex },
                    set: { newIndex in
                        self.selectedCategoryIndex = newIndex
                        self.showingCategorySelector = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.categoryDelegate?.didSelectCategory(at: newIndex)
                        }
                    }
                ),
                categories: Array(zip(categoryTitles, categoryIcons)).map { ($0.0, $0.1) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAIMeditationSheet) {
            MeditationOptionsSheet(onMeditationSelected: startAIMeditation)
        }
        .sheet(isPresented: $showingGuidedMeditations) {
            GuidedMeditationsView()
        }
        .overlay {
            // Meditation Player Overlay (when active)
            if meditationService.isPlaying, let script = meditationService.currentScript {
                MeditationPlayerOverlay(script: script)
            }
        }
    }
    
    // MARK: - Section Views
    
    private func headerSection() -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Meditation")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .dynamicTypeSize(.medium ... .accessibility3)
                .accessibilityAddTraits(.isHeader)
            
            Text("A sanctuary for your mind")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .dynamicTypeSize(.medium ... .accessibility3)
            }
            
            Spacer()
            
            Button(action: {
                showingCategorySelector = true
            }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.976, green: 0.576, blue: 0.125),
                                Color(red: 1.0, green: 0.42, blue: 0.21)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(18)
                    .shadow(color: Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .accessibilityLabel("Switch activity category")
            .accessibilityHint("Double tap to view other activity types")
        }
    }
    
    private func featuredMeditationsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Featured")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .dynamicTypeSize(.medium ... .accessibility3)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Button(action: {
                    showingGuidedMeditations = true
                }) {
                    Text("See All")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .accessibilityLabel("See all featured meditations")
                .accessibilityHint("Double tap to view the full meditation library")
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(featuredMeditations.prefix(5), id: \.meditationId) { meditation in
                        FeaturedMeditationCard(meditation: meditation) {
                            startLibraryMeditation(meditation)
                        }
                    }
                }
            }
        }
    }
    
    private func quickStartSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Start")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .dynamicTypeSize(.medium ... .accessibility3)
                .accessibilityAddTraits(.isHeader)
            
            HStack(spacing: 12) {
                // Create Custom Button
                Button(action: {
                    showAIMeditationSheet = true
                }) {
                    HStack(spacing: 12) {
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
                            
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create Custom")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Personalized for you")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
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
                                                Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.15),
                                                Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.15)
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
                }
                .accessibilityLabel("Create custom meditation")
                .accessibilityHint("Double tap to create a personalized meditation session")
            }
        }
    }
    
    private func browseLibrarySection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Browse Library")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .dynamicTypeSize(.medium ... .accessibility3)
                .accessibilityAddTraits(.isHeader)
            
            Button(action: {
                showingGuidedMeditations = true
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.purple.opacity(0.6),
                                        Color.blue.opacity(0.6)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "book.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Guided Library")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("\(featuredMeditations.isEmpty ? "100+" : "\(featuredMeditations.count)+") curated meditations")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
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
            .accessibilityLabel("Browse guided meditation library")
            .accessibilityHint("Double tap to view all available guided meditations")
        }
    }
    
    private func timeBasedSection() -> some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let (title, description, icon) = getTimeBasedInfo(hour: hour)
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .dynamicTypeSize(.medium ... .accessibility3)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(timeBasedMeditations.prefix(3), id: \.meditationId) { meditation in
                        FeaturedMeditationCard(meditation: meditation) {
                            startLibraryMeditation(meditation)
                        }
                    }
                }
            }
        }
    }
    
    private func recommendedSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("For You")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .dynamicTypeSize(.medium ... .accessibility3)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(recommendedMeditations, id: \.meditationId) { meditation in
                        FeaturedMeditationCard(meditation: meditation) {
                            startLibraryMeditation(meditation)
                        }
                    }
                }
            }
        }
    }
    
    private func discoverySection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discover")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .dynamicTypeSize(.medium ... .accessibility3)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 12) {
                // Surprise Me Button
                Button(action: {
                    surpriseMe()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.purple.opacity(0.8),
                                            Color.blue.opacity(0.8)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "dice.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Surprise Me")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Random meditation")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .accessibilityLabel("Surprise me with a random meditation")
                .accessibilityHint("Double tap to start a randomly selected meditation")
                
                // Try Something New Button
                Button(action: {
                    trySomethingNew()
                }) {
                    HStack(spacing: 12) {
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
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "star.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Try Something New")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Explore new categories")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .accessibilityLabel("Try something new meditation")
                .accessibilityHint("Double tap to explore meditations from categories you haven't tried")
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func getTimeBasedInfo(hour: Int) -> (String, String, String) {
        switch hour {
        case 5..<12:
            return ("Morning Focus", "Start your day with clarity", "sunrise.fill")
        case 12..<17:
            return ("Midday Reset", "Recharge your energy", "sun.max.fill")
        case 17..<21:
            return ("Evening Wind-Down", "Reflect and relax", "sunset.fill")
        default:
            return ("Nighttime Sleep", "Prepare for rest", "moon.stars.fill")
        }
    }
    
    private func surpriseMe() {
        Task {
            do {
                // Get all meditations
                let response = try await apiService.getMeditationLibrary(limit: 100)
                let allMeditations = response.data.meditations
                
                // Pick a random one
                if let randomMeditation = allMeditations.randomElement() {
                    await MainActor.run {
                        startLibraryMeditation(randomMeditation)
                    }
                }
            } catch {
                print("Error getting surprise meditation: \(error)")
            }
        }
    }
    
    private func trySomethingNew() {
        // Load meditations from a category the user hasn't tried
        Task {
            let history = try? await MeditationTrackingService.shared.getSessionHistory(days: 30)
            let triedCategories = Set(history?.compactMap { $0.notes?.components(separatedBy: " • ").first } ?? [])
            
            let allCategories = ["Performance", "Healing & Recovery", "Gratitude & Happiness", "Relationships", "Daily Practice"]
            let newCategories = allCategories.filter { !triedCategories.contains($0) }
            
            let category = newCategories.randomElement() ?? allCategories.randomElement() ?? "Meditation Basics"
            
            do {
                let response = try await apiService.getMeditationLibrary(category: category, limit: 5)
                if let meditation = response.data.meditations.randomElement() {
                    await MainActor.run {
                        startLibraryMeditation(meditation)
                    }
                }
            } catch {
                print("Error getting new meditation: \(error)")
            }
        }
    }
    
    private func progressStatsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Journey")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .dynamicTypeSize(.medium ... .accessibility3)
                .accessibilityAddTraits(.isHeader)
            
            HStack(spacing: 20) {
                MeditationStatCard(
                    value: "\(trackingService.currentStreak)",
                    label: "Day Streak",
                    icon: "flame.fill",
                    gradient: [Color(red: 1.0, green: 0.42, blue: 0.21), Color(red: 0.976, green: 0.576, blue: 0.125)]
                )
                
                MeditationStatCard(
                    value: "\(totalMeditationMinutes)",
                    label: "Minutes",
                    icon: "clock.fill",
                    gradient: [Color.purple, Color.blue]
                )
                
                MeditationStatCard(
                    value: "\(totalMeditationSessions)",
                    label: "Sessions",
                    icon: "sparkles",
                    gradient: [Color.blue, Color.cyan]
                )
            }
        }
        .task {
            await loadMeditationStats()
        }
    }
    
    @State private var totalMeditationMinutes: Int = 0
    @State private var totalMeditationSessions: Int = 0
    
    private let trackingService = MeditationTrackingService.shared
    
    private func loadMeditationStats() async {
        do {
            let history = try await trackingService.getSessionHistory(days: 365)
            totalMeditationSessions = history.count
            totalMeditationMinutes = history.reduce(0) { $0 + Int($1.actualDuration / 60) }
        } catch {
            print("⚠️ [MeditationTracker] Error loading stats: \(error)")
            // Fallback to local storage
            let allSessions = trackingService.loadAllFromLocalStorage()
            totalMeditationSessions = allSessions.count
            totalMeditationMinutes = allSessions.reduce(0) { $0 + Int($1.actualDuration / 60) }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadFeaturedMeditations() {
        isLoadingFeatured = true
        Task {
            do {
                let response = try await apiService.getMeditationLibrary(limit: 20)
                await MainActor.run {
                    self.featuredMeditations = response.data.featured ?? Array(response.data.meditations.prefix(5))
                    self.isLoadingFeatured = false
                }
            } catch {
                print("Error loading featured meditations: \(error)")
                await MainActor.run {
                    self.isLoadingFeatured = false
                }
            }
        }
    }
    
    private func loadPersonalizedContent() {
        Task {
            // Load user preferences
            let preferences = await GenieUserLearningService.shared.getUserPreferences()
            await MainActor.run {
                self.userPreferences = preferences
            }
            
            // Get meditation history for recommendations
            do {
                let history = try await MeditationTrackingService.shared.getSessionHistory(days: 30)
                
                // Get time-based suggestions
                let timeBased = await getTimeBasedMeditations()
                
                // Get personalized recommendations
                let recommendations = await getPersonalizedRecommendations(history: history, preferences: preferences)
                
                await MainActor.run {
                    self.timeBasedMeditations = timeBased
                    self.recommendedMeditations = recommendations
                }
            } catch {
                print("Error loading personalized content: \(error)")
            }
        }
    }
    
    private func getTimeBasedMeditations() async -> [MeditationLibraryItem] {
        let hour = Calendar.current.component(.hour, from: Date())
        let category: String
        
        switch hour {
        case 5..<12:
            // Morning: Focus, Energy, Performance
            category = "Focus"
        case 12..<17:
            // Afternoon: Stress relief, Energy boost
            category = "Stress & Anxiety"
        case 17..<21:
            // Evening: Wind-down, Gratitude
            category = "Gratitude & Happiness"
        default:
            // Night: Sleep, Relaxation
            category = "Sleep"
        }
        
        // Fetch meditations for this time of day
        do {
            let response = try await apiService.getMeditationLibrary(category: category, limit: 3)
            return Array(response.data.meditations.prefix(3))
        } catch {
            return []
        }
    }
    
    private func getPersonalizedRecommendations(history: [MeditationSession], preferences: [String: Any]) async -> [MeditationLibraryItem] {
        // Analyze history to find patterns
        var favoriteFocus: String = "stress"
        var preferredDuration: Int = 10
        
        if let meditationPrefs = preferences["meditation"] as? [String: Any] {
            favoriteFocus = meditationPrefs["favoriteFocus"] as? String ?? "stress"
            preferredDuration = meditationPrefs["averageDuration"] as? Int ?? 10
        }
        
        // Find meditations matching user preferences
        do {
            let response = try await apiService.getMeditationLibrary(
                category: mapFocusToCategory(favoriteFocus),
                duration: preferredDuration,
                technique: nil,
                limit: 5
            )
            return Array(response.data.meditations.prefix(5))
        } catch {
            return []
        }
    }
    
    private func mapFocusToCategory(_ focus: String) -> String {
        switch focus.lowercased() {
        case "stress", "anxiety": return "Stress & Anxiety"
        case "sleep": return "Sleep"
        case "focus": return "Focus"
        case "breathing", "breathe": return "Breathe"
        case "gratitude": return "Gratitude & Happiness"
        case "recovery", "healing": return "Healing & Recovery"
        case "energy", "performance": return "Performance"
        default: return "Meditation Basics"
        }
    }
    
    private func startLibraryMeditation(_ meditation: MeditationLibraryItem) {
        let focus = mapCategoryToFocus(meditation.category)
        
        let script = MeditationScript(
            duration: meditation.duration,
            focus: focus,
            segments: [MeditationSegment(name: meditation.title, content: meditation.script)]
        )
        
        meditationService.startMeditation(script, libraryMeditationId: meditation.meditationId)
    }
    
    private func mapCategoryToFocus(_ category: String) -> MeditationFocus {
        switch category.lowercased() {
        case "sleep", "sleep health": return .sleep
        case "focus", "work & productivity": return .focus
        case "stress & anxiety": return .anxiety
        case "breathe": return .breathing
        case "gratitude & happiness": return .gratitude
        case "healing & recovery": return .recovery
        case "performance": return .energy
        default: return .stress
        }
    }
    
    // MARK: - AI Meditation Handlers
    
    private func setupMeditationTracking() {
        let trackingService = MeditationTrackingService.shared
        
        // Track when AI meditation starts
        meditationService.onMeditationStart = { [self] script, libraryId in
            // For AI-generated meditations (no libraryId), track start
            if libraryId == nil {
                Task {
                    do {
                        try await trackingService.logAIMeditation(
                            focus: script.focus,
                            duration: TimeInterval(script.duration * 60),
                            script: script,
                            completed: false
                        )
                    } catch {
                        print("Error tracking AI meditation start: \(error)")
                    }
                }
            }
        }
        
        // Track when meditation completes
        meditationService.onMeditationComplete = { [self] completed in
            // Update the meditation session as completed if it was completed
            if completed {
                print("🧘 [Tracker] Meditation completed - tracking updated")
            } else {
                print("🧘 [Tracker] Meditation stopped early")
            }
        }
    }
    
    private func startAIMeditation(focus: MeditationFocus, duration: Int) {
        setupMeditationTracking()
        
        Task {
            do {
                let script = try await meditationService.generateMeditation(
                    duration: duration,
                    focus: focus,
                    userContext: nil
                )
                meditationService.startMeditation(script, libraryMeditationId: nil)
            } catch {
                print("Error generating meditation: \(error)")
            }
        }
    }
    
    private func getCurrentUserId() -> String {
        return CurrentUserService.shared.userID ?? ""
    }
}

// MARK: - Supporting Card Views

struct FeaturedMeditationCard: View {
    let meditation: MeditationLibraryItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Cute character illustration
                MeditationCharacterView(category: meditation.category)
                    .frame(width: 80, height: 80)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Category badge and duration
                    HStack {
                        Text(meditation.category)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                        
                        Spacer()
                        
                        Text("\(meditation.duration) min")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Title
                    Text(meditation.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .dynamicTypeSize(.medium ... .accessibility3)
                    
                    // Description
                    Text(meditation.description ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .dynamicTypeSize(.medium ... .accessibility3)
                }
            }
            .padding(20)
            .frame(width: 320, height: 200)
            .background(
                ZStack {
                    // Dynamic gradient background based on character type - more vibrant
                    RoundedRectangle(cornerRadius: 24)
                        .fill(characterBackgroundGradient)
                    
                    // Subtle pattern overlay for depth
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ]),
                                center: .topTrailing,
                                startRadius: 0,
                                endRadius: 250
                            )
                        )
                }
            )
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
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(meditation.title), \(meditation.category), \(meditation.duration) minutes")
        .accessibilityHint("Double tap to start this meditation")
        .accessibilityAddTraits(.isButton)
    }
    
    private var characterBackgroundGradient: LinearGradient {
        // Use design system colors for consistency
        let colors = TrackingDesignSystem.Colors.Meditation.gradientColors(for: meditation.category)
        // Make the gradient more vibrant and visible for the card background
        let enhancedColors = colors.map { $0.opacity(0.8) }
        return LinearGradient(
            colors: enhancedColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func getCharacterType(for category: String) -> MeditationCharacterType {
        let lowerCategory = category.lowercased()
        if lowerCategory.contains("sleep") || lowerCategory.contains("sleep health") {
            return .sleep
        } else if lowerCategory.contains("focus") || lowerCategory.contains("productivity") || lowerCategory.contains("work") {
            return .focus
        } else if lowerCategory.contains("stress") || lowerCategory.contains("anxiety") {
            return .stress
        } else if lowerCategory.contains("breathe") || lowerCategory.contains("breathing") {
            return .breathing
        } else if lowerCategory.contains("gratitude") || lowerCategory.contains("happiness") {
            return .gratitude
        } else if lowerCategory.contains("performance") || lowerCategory.contains("energy") {
            return .performance
        } else if lowerCategory.contains("healing") || lowerCategory.contains("recovery") {
            return .recovery
        } else if lowerCategory.contains("emotions") || lowerCategory.contains("relationships") {
            return .gratitude // Use gratitude character for emotional/relationship meditations
        } else if lowerCategory.contains("movement") || lowerCategory.contains("basics") {
            return .default // Use mindfulness character for general meditations
        }
        return .default
    }
}

struct MeditationStatCard: View {
    let value: String
    let label: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: gradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .dynamicTypeSize(.medium ... .accessibility3)
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .dynamicTypeSize(.medium ... .accessibility3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct MeditationPlayerOverlay: View {
    @ObservedObject var meditationService = GenieMeditationService.shared
    @ObservedObject var voiceService = GenieVoiceService.shared
    let script: MeditationScript
    
    private var currentSegment: MeditationSegment? {
        guard meditationService.currentSegment > 0,
              meditationService.currentSegment <= script.segments.count else {
            return script.segments.first
        }
        return script.segments[meditationService.currentSegment - 1]
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 28) {
                // Current Segment Info
                VStack(spacing: 16) {
                    // Category/Intention Badge
                    HStack {
                        Text(script.focus.rawValue.capitalized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
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
                        
                        Spacer()
                        
                        Text("\(script.duration) min")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Current segment name
                    if let segment = currentSegment {
                        Text(segment.name)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel("Current segment: \(segment.name)")
                    }
                }
                
                // Progress indicator
                VStack(spacing: 12) {
                    // Progress bar with smooth animation
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.976, green: 0.576, blue: 0.125),
                                            Color(red: 1.0, green: 0.42, blue: 0.21)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * max(0, min(1, meditationService.progress)), height: 6)
                                .animation(.linear(duration: 0.3), value: meditationService.progress)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 32)
                    .accessibilityElement()
                    .accessibilityLabel("Progress")
                    .accessibilityValue("\(Int(meditationService.progress * 100)) percent complete")
                    
                    // Segment indicator
                    Text("Segment \(meditationService.currentSegment) of \(meditationService.totalSegments)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .accessibilityLabel("Segment \(meditationService.currentSegment) of \(meditationService.totalSegments)")
                    
                    // Status indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(meditationService.isPlaying ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                            .opacity(meditationService.isPlaying ? 1.0 : 0.6)
                            .accessibilityHidden(true)
                        
                        Text(meditationService.isPlaying ? "In Session" : "Paused")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(meditationService.isPlaying ? "In Session" : "Paused")
                }
                
                // Control buttons
                HStack(spacing: 40) {
                    Button(action: {
                        meditationService.stopMeditation()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .accessibilityLabel("Stop meditation")
                    .accessibilityHint("Double tap to stop the current meditation session")
                    
                    Button(action: {
                        if meditationService.isPlaying {
                            meditationService.pauseMeditation()
                        } else {
                            meditationService.resumeMeditation()
                        }
                    }) {
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
                                .frame(width: 72, height: 72)
                                .shadow(color: Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.5), radius: 16, x: 0, y: 8)
                            
                            Image(systemName: meditationService.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white)
                                .offset(x: meditationService.isPlaying ? 0 : 2) // Slight offset for play icon
                        }
                    }
                    .accessibilityLabel(meditationService.isPlaying ? "Pause meditation" : "Resume meditation")
                    .accessibilityHint(meditationService.isPlaying ? "Double tap to pause" : "Double tap to resume")
                    
                    // Spacer to balance stop button
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.clear)
                        .accessibilityHidden(true)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(red: 0.1, green: 0.05, blue: 0.2, opacity: 0.98), location: 0),
                                .init(color: Color(red: 0.15, green: 0.08, blue: 0.25, opacity: 0.98), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
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
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .shadow(color: Color.black.opacity(0.5), radius: 40, x: 0, y: -10)
        }
        .background(
            Color.black.opacity(0.4)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Supporting Types

// Note: MeditationType is defined in MeditationTrackingService.swift
// This duplicate definition has been removed to avoid redeclaration errors

// MARK: - Meditation Tracking Engine
class MeditationTrackingEngine: ObservableObject {
    static let shared = MeditationTrackingEngine()
    
    @Published var isTracking = false
    @Published var currentUser: UserModel?
    
    private init() {}
    
    func setCurrentUser() {
        // Use AWS/Cognito instead of Parse
        if let userId = UserIDHelper.shared.getCurrentUserID() {
            Task {
                // Load user profile from AWS
                if let userProfile = try? await UserProfileService.shared.fetchUserProfile(userId: userId) {
                    await MainActor.run {
                        self.currentUser = userProfile
                    }
                } else {
                    // Fallback to CurrentUserService if available
                    await MainActor.run {
                        self.currentUser = CurrentUserService.shared.user
                    }
                }
            }
        } else {
            // Fallback to CurrentUserService
            currentUser = CurrentUserService.shared.user
        }
    }
    
    func startTracking() {
        isTracking = true
        // Initialize meditation session
    }
    
    private func getImageFromURL(from input: String) async -> UIImage? {
        var image: UIImage? = nil
        let incomingString = input
        if (incomingString != "") {
            guard let url = URL(string: incomingString) else {
                print("Unable to create URL")
                return nil
            }
            
            do {
                let data = try Data(contentsOf: url, options: [])
                image = UIImage(data: data)
            } catch {
                print(error.localizedDescription)
            }
        }
        return image
    }
}

// Updated ActivityCategory enum to match Track.swift categories
enum ActivityCategory: String, CaseIterable, Identifiable {
    case running = "Running"
    case gym = "Gym"
    case cycling = "Cycling"
    case hiking = "Hiking"
    case walking = "Walking"
    case swimming = "Swimming"
    case food = "Food"
    case meditation = "Meditation"
    case sports = "Sports"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .gym: return "dumbbell.fill"
        case .cycling: return "bicycle"
        case .hiking: return "figure.hiking"
        case .walking: return "figure.walk"
        case .swimming: return "figure.pool.swim"
        case .food: return "fork.knife"
        case .meditation: return "sparkles"
        case .sports: return "sportscourt"
        }
    }
}


