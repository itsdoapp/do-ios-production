//
//  WorkoutListView.swift
//  Do Watch App
//
//  Main workout selection screen - Enhanced with contextual intelligence
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit

struct WorkoutListView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @ObservedObject var genieService = GenieService.shared
    @ObservedObject var dailyBricksService = DailyBricksService.shared
    
    // Brand colors
    private let brandOrange = Color(red: 0.969, green: 0.576, blue: 0.122)
    
    let workoutTypes: [(WorkoutType, String, String, Color)] = [
        (.running, "Running", "figure.run", Color.brandOrange),
        (.walking, "Walking", "figure.walk", Color.blue),
        (.meditation, "Meditation", "figure.mind.and.body", Color(hex: "9B87F5")),
        (.gym, "Gym", "figure.strengthtraining.traditional", Color.purple),
        (.biking, "Biking", "figure.outdoor.cycle", Color.green),
        (.hiking, "Hiking", "figure.hiking", Color.brown),
        (.swimming, "Swimming", "figure.pool.swim", Color.cyan),
        (.sports, "Sports", "sportscourt", Color.red)
    ]
    
    @State private var greeting: String = "Good Morning"
    @State private var dailyTip: String = "Ready to move?"
    @State private var phoneWorkout: [String: Any]? = nil
    @State private var isCheckingPhoneWorkout = false
    
    // Enhanced state
    @State private var todaySteps: Int = 0
    @State private var todayCalories: Double = 0
    @State private var todayActiveMinutes: Int = 0
    @State private var currentHeartRate: Double = 0
    @State private var workoutStreak: Int = 0
    @State private var lastWorkoutType: WorkoutType? = nil
    @State private var lastWorkoutTime: Date? = nil
    @State private var suggestedWorkout: WorkoutType? = nil
    @State private var weatherCondition: String = "sunny"
    @State private var energyLevel: EnergyLevel = .medium
    
    enum EnergyLevel {
        case low, medium, high
        
        var color: Color {
            switch self {
            case .low: return .red
            case .medium: return .yellow
            case .high: return .green
            }
        }
        
        var icon: String {
            switch self {
            case .low: return "battery.25"
            case .medium: return "battery.50"
            case .high: return "battery.100"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Living Dashboard: Ambient Background
                AmbientBackground(color: .blue.opacity(0.3), heartRate: currentHeartRate > 0 ? currentHeartRate : 60)
                
                if let activeWorkout = workoutCoordinator.activeWorkout {
                    // Active Workout View (Return to Session)
                    VStack(spacing: 12) {
                        Spacer()
                        
                        Text("Active Session")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.gray)
                        
                        NavigationLink(destination: workoutView(for: activeWorkout.workoutType), isActive: .constant(true)) {
                            EmptyView()
                        }
                        .hidden()
                        
                        NavigationLink(destination: workoutView(for: activeWorkout.workoutType)) {
                            WorkoutRowCard(
                                type: activeWorkout.workoutType,
                                name: "Return to Session",
                                icon: "play.circle.fill",
                                color: brandOrange,
                                isHighlighted: true,
                                isHero: true
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        
                        Spacer()
                    }
                } else {
                    // Enhanced Kinetic Launchpad
                    ScrollView {
                        VStack(spacing: 10) {
                            // 1. Smart Header with Context
                            smartHeader
                            
                            // 2. Daily Bricks Brickwall
                            DailyBricksBrickwallView(summary: dailyBricksService.todaySummary)
                                .padding(.horizontal, 8)
                            
                            // 3. Join Phone Workout (if available)
                            Group {
                                if let phoneWorkout = phoneWorkout,
                                   let workoutActive = phoneWorkout["workoutActive"] as? Bool,
                                   workoutActive,
                                   let workoutTypeString = phoneWorkout["workoutType"] as? String {
                                    
                                    let workoutType = workoutTypeFromString(workoutTypeString)
                                    let workoutTypeName = getWorkoutName(for: workoutType)
                                    
                                    let userInfo = phoneWorkout["user"] as? [String: Any]
                                    let userDisplayName = (userInfo?["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let userHandle = (userInfo?["userName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                                    
                                    // Build informative join title with workout type
                                    let joinTitle: String = {
                                        if let displayName = userDisplayName, !displayName.isEmpty {
                                            return "Active \(workoutTypeName) - Join \(displayName)"
                                        } else if let handle = userHandle, !handle.isEmpty {
                                            return "Active \(workoutTypeName) - Join \(handle)"
                                        } else {
                                            return "Active \(workoutTypeName) - Join on iPhone"
                                        }
                                    }()
                                    
                                    Button(action: {
                                        joinPhoneWorkout(phoneWorkout)
                                    }) {
                                        WorkoutRowCard(
                                            type: workoutType,
                                            name: joinTitle,
                                            icon: "iphone",
                                            color: .green,
                                            isHighlighted: true,
                                            isHero: true
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 8)
                                }
                            }
                            
                            // 4. Suggested Workout (Smart Recommendation)
                            if let suggested = suggestedWorkout {
                                NavigationLink(destination: workoutView(for: suggested)) {
                                    SuggestedWorkoutCard(
                                        type: suggested,
                                        reason: getSuggestionReason(for: suggested)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 8)
                            }
                            
                            // 5. Hero Card (Most Used or First Item)
                            if let heroType = getHeroWorkout() {
                                NavigationLink(destination: workoutView(for: heroType)) {
                                    WorkoutRowCard(
                                        type: heroType,
                                        name: getWorkoutName(for: heroType),
                                        icon: getWorkoutIcon(for: heroType),
                                        color: getWorkoutColor(for: heroType),
                                        isHero: true
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 8)
                            }
                            
                            // 6. Recent Workout Quick Access
                            if let lastType = lastWorkoutType, let lastTime = lastWorkoutTime {
                                NavigationLink(destination: workoutView(for: lastType)) {
                                    RecentWorkoutCard(
                                        type: lastType,
                                        timeAgo: timeAgoString(from: lastTime)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 8)
                            }
                            
                            // 7. The Glass List (All Workouts)
                            VStack(spacing: 8) {
                                ForEach(getRemainingWorkouts(), id: \.self) { type in
                                    NavigationLink(destination: workoutView(for: type)) {
                                        WorkoutRowCard(
                                            type: type,
                                            name: getWorkoutName(for: type),
                                            icon: getWorkoutIcon(for: type),
                                            color: getWorkoutColor(for: type)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 8)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                updateGreeting()
                fetchDailyTip()
                checkForPhoneWorkout()
                loadHealthData()
                calculateSuggestions()
                
                // Load daily bricks progress
                Task {
                    await dailyBricksService.loadTodayProgress()
                }
                
                // Listen for phone workout updates from application context
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("PhoneWorkoutUpdate"),
                    object: nil,
                    queue: .main
                ) { [self] notification in
                    if let userInfo = notification.userInfo {
                        // Convert [AnyHashable: Any] to [String: Any]
                        var workoutData: [String: Any] = [:]
                        for (key, value) in userInfo {
                            if let stringKey = key as? String {
                                workoutData[stringKey] = value
                            }
                        }
                        
                        if let workoutActive = workoutData["workoutActive"] as? Bool, workoutActive {
                            self.phoneWorkout = workoutData
                            print("⌚️ [WorkoutListView] Updated phoneWorkout from application context: \(workoutData)")
                        } else {
                            self.phoneWorkout = nil
                            print("⌚️ [WorkoutListView] Cleared phoneWorkout (workout not active)")
                        }
                    }
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PhoneWorkoutUpdate"), object: nil)
            }
        }
    }
    
    // MARK: - Smart Header
    private var smartHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(greeting)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray.opacity(0.8))
                    
                    Text(dailyTip)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.75)
                }
                
                Spacer()
                
                // Energy Level Indicator
                VStack(spacing: 2) {
                    Image(systemName: energyLevel.icon)
                        .font(.system(size: 12))
                        .foregroundColor(energyLevel.color)
                    Text("ENERGY")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
    
    // MARK: - Daily Bricks Brickwall (replaces Quick Stats Widget)
    // Now using DailyBricksBrickwallView component above
    
    // MARK: - Helper Methods
    
    private func getHeroWorkout() -> WorkoutType? {
        // Return suggested workout if available, otherwise most used, otherwise first
        return suggestedWorkout ?? lastWorkoutType ?? workoutTypes.first?.0
    }
    
    private func getRemainingWorkouts() -> [WorkoutType] {
        let hero = getHeroWorkout()
        let last = lastWorkoutType
        return workoutTypes.map { $0.0 }.filter { $0 != hero && $0 != last }
    }
    
    private func getWorkoutName(for type: WorkoutType) -> String {
        return workoutTypes.first(where: { $0.0 == type })?.1 ?? type.rawValue.capitalized
    }
    
    private func getWorkoutIcon(for type: WorkoutType) -> String {
        return workoutTypes.first(where: { $0.0 == type })?.2 ?? "figure.run"
    }
    
    private func getWorkoutColor(for type: WorkoutType) -> Color {
        return workoutTypes.first(where: { $0.0 == type })?.3 ?? .blue
    }
    
    private func getSuggestionReason(for type: WorkoutType) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch type {
        case .running:
            if hour < 10 { return "Morning run?" }
            if hour < 18 { return "Perfect weather" }
            return "Evening pace"
        case .walking:
            return "Gentle movement"
        case .meditation:
            if hour < 8 || hour > 20 { return "Wind down time" }
            return "Mindful break"
        case .gym:
            if hour < 14 { return "Strength time" }
            return "Power session"
        case .biking:
            return "Great day for it"
        case .hiking:
            return "Adventure awaits"
        case .swimming:
            return "Pool ready"
        case .sports:
            return "Game time"
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        
        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        }
    }
    
    private func loadHealthData() {
        // Load today's activity from HealthKit
        let healthStore = HKHealthStore()
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        // Steps
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let stepsQuery = HKStatisticsQuery(
            quantityType: stepsType,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate),
            options: .cumulativeSum
        ) { _, result, _ in
            if let sum = result?.sumQuantity() {
                DispatchQueue.main.async {
                    self.todaySteps = Int(sum.doubleValue(for: HKUnit.count()))
                }
            }
        }
        healthStore.execute(stepsQuery)
        
        // Active Energy
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let energyQuery = HKStatisticsQuery(
            quantityType: energyType,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate),
            options: .cumulativeSum
        ) { _, result, _ in
            if let sum = result?.sumQuantity() {
                DispatchQueue.main.async {
                    self.todayCalories = sum.doubleValue(for: HKUnit.kilocalorie())
                }
            }
        }
        healthStore.execute(energyQuery)
        
        // Heart Rate (current)
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let hrQuery = HKSampleQuery(
            sampleType: hrType,
            predicate: HKQuery.predicateForSamples(withStart: now.addingTimeInterval(-300), end: now, options: .strictEndDate),
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        ) { _, samples, _ in
            if let sample = samples?.first as? HKQuantitySample {
                DispatchQueue.main.async {
                    self.currentHeartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                }
            }
        }
        healthStore.execute(hrQuery)
    }
    
    private func calculateSuggestions() {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Time-based suggestions
        if hour < 8 {
            suggestedWorkout = .meditation
            energyLevel = .low
        } else if hour < 12 {
            suggestedWorkout = .running
            energyLevel = .high
        } else if hour < 18 {
            suggestedWorkout = .walking
            energyLevel = .medium
        } else if hour < 22 {
            suggestedWorkout = .gym
            energyLevel = .medium
        } else {
            suggestedWorkout = .meditation
            energyLevel = .low
        }
        
        // Override based on activity level
        if todaySteps > 10000 {
            suggestedWorkout = .meditation // Rest day suggestion
        } else if todaySteps < 3000 {
            suggestedWorkout = .running // Need more activity
        }
    }
    
    private func workoutTypeFromString(_ type: String) -> WorkoutType {
        switch type.lowercased() {
        case "run", "running", "outdoorrun", "treadmillrun": return .running
        case "walk", "walking": return .walking
        case "bike", "biking", "cycling": return .biking
        case "hike", "hiking": return .hiking
        case "swim", "swimming": return .swimming
        case "gym", "strength": return .gym
        case "sport", "sports": return .sports
        case "meditation", "mindfulness": return .meditation
        default: return .running
        }
    }
    
    private func checkForPhoneWorkout() {
        guard !isCheckingPhoneWorkout else { return }
        isCheckingPhoneWorkout = true
        
        connectivityManager.requestActiveWorkoutFromPhone { [self] workoutData in
            DispatchQueue.main.async {
                self.isCheckingPhoneWorkout = false
                if let workoutData = workoutData {
                    self.phoneWorkout = workoutData
                    print("⌚️ [WorkoutListView] Found active phone workout: \(workoutData)")
                } else {
                    self.phoneWorkout = nil
                }
            }
        }
    }
    
    private func joinPhoneWorkout(_ workoutData: [String: Any]) {
        guard let workoutTypeString = workoutData["workoutType"] as? String else { return }
        let workoutType = workoutTypeFromString(workoutTypeString)
        
        var metrics = WorkoutMetrics()
        if let metricsDict = workoutData["metrics"] as? [String: Any] {
            if let distance = metricsDict["distance"] as? Double {
                metrics.distance = distance
            }
            if let elapsedTime = metricsDict["elapsedTime"] as? TimeInterval {
                metrics.elapsedTime = elapsedTime
            }
            if let heartRate = metricsDict["heartRate"] as? Double {
                metrics.heartRate = heartRate
            }
            if let calories = metricsDict["calories"] as? Double {
                metrics.calories = calories
            }
        }
        
        let state: WorkoutState
        if let stateString = workoutData["state"] as? String {
            switch stateString.lowercased() {
            case "running", "inprogress", "active": state = .running
            case "paused": state = .paused
            default: state = .running
            }
        } else {
            state = .running
        }
        
        let session = WatchWorkoutSession(
            workoutType: workoutType,
            state: state,
            metrics: metrics,
            deviceSource: .phone
        )
        
        workoutCoordinator.activeWorkout = session
    }
    
    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { greeting = "Good Morning" }
        else if hour < 18 { greeting = "Good Afternoon" }
        else { greeting = "Good Evening" }
    }
    
    private func fetchDailyTip() {
        let tips = [
            "Perfect time to move.",
            "Your goals are waiting.",
            "Time to crush it?",
            "Focus on form today.",
            "Stay consistent."
        ]
        dailyTip = tips.randomElement() ?? "Ready to move?"
    }
    
    @ViewBuilder
    private func workoutView(for type: WorkoutType) -> some View {
        switch type {
        case .running: RunningWorkoutView()
        case .biking: BikingWorkoutView()
        case .hiking: HikingWorkoutView()
        case .walking: WalkingWorkoutView()
        case .swimming: SwimmingWorkoutView()
        case .meditation: MeditationView()
        case .sports: SportsWorkoutView()
        case .gym: GymWorkoutView()
        }
    }
}

// MARK: - Stat Pill Component
struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
        )
    }
}

// MARK: - Suggested Workout Card
struct SuggestedWorkoutCard: View {
    let type: WorkoutType
    let reason: String
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.green.opacity(0.4), Color.green.opacity(0.0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.6), Color.green.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.green.opacity(0.7), lineWidth: 1.5)
                    )
                
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .shadow(color: Color.green.opacity(0.5), radius: 8, x: 0, y: 0)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("SUGGESTED")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.green.opacity(0.9))
                
                Text(getWorkoutName(for: type))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(reason)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.gray.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.15),
                            Color.green.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [Color.green.opacity(0.5), Color.green.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
    
    private func getWorkoutName(for type: WorkoutType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .meditation: return "Meditation"
        case .gym: return "Gym"
        case .biking: return "Biking"
        case .hiking: return "Hiking"
        case .swimming: return "Swimming"
        case .sports: return "Sports"
        }
    }
}

// MARK: - Recent Workout Card
struct RecentWorkoutCard: View {
    let type: WorkoutType
    let timeAgo: String
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.blue.opacity(0.5), lineWidth: 1.5)
                    )
                
                Image(systemName: "clock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text("LAST: \(getWorkoutName(for: type).uppercased())")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.blue.opacity(0.9))
                
                Text(timeAgo)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func getWorkoutName(for type: WorkoutType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .meditation: return "Meditation"
        case .gym: return "Gym"
        case .biking: return "Biking"
        case .hiking: return "Hiking"
        case .swimming: return "Swimming"
        case .sports: return "Sports"
        }
    }
}

// MARK: - Kinetic Row Card (Redesigned)
struct WorkoutRowCard: View {
    let type: WorkoutType
    let name: String
    let icon: String
    let color: Color
    var isHighlighted: Bool = false
    var isHero: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon with Enhanced Glow
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(0.3), color.opacity(0.0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: isHero ? 30 : 25
                        )
                    )
                    .frame(width: isHero ? 48 : 40, height: isHero ? 48 : 40)
                
                // Icon container
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.5), color.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isHero ? 40 : 36, height: isHero ? 40 : 36)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.6), lineWidth: 1.5)
                    )
                
                // Icon
                if type == .meditation {
                    Image(systemName: "figure.mind.and.body")
                        .font(.system(size: isHero ? 16 : 14, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: isHero ? 16 : 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .shadow(color: color.opacity(isHero ? 0.6 : 0.3), radius: isHero ? 10 : 6, x: 0, y: 0)
            
            // Text Content - Better Text Handling
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: isHero ? 15 : 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                
                if isHero {
                    Text("Tap to start")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(color.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Subtle Arrow (only if not hero)
            if !isHero {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.4))
                    .padding(.trailing, 2)
            }
        }
        .padding(.horizontal, isHero ? 12 : 10)
        .padding(.vertical, isHero ? 14 : 10)
        .background(
            // Enhanced Glassmorphism
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
        )
        .overlay(
            // Refined Border
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            color.opacity(isHighlighted ? 0.8 : 0.25),
                            color.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: isHighlighted ? 2 : 1
                )
        )
        .scaleEffect(isHighlighted ? 1.01 : 1.0)
    }
}
