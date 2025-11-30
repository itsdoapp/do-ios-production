//
//  GymWorkoutSync.swift
//  Do Watch App
//
//  Gym workout synchronization service
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

class GymWorkoutSync: ObservableObject {
    static let shared = GymWorkoutSync()
    
    @Published var currentSession: GymWorkoutSession?
    @Published var lastSyncTime: Date?
    
    private let connectivityManager = WatchConnectivityManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: NSNotification.Name("GymWorkoutStateChanged"))
            .sink { [weak self] notification in
                self?.syncWorkoutState()
            }
            .store(in: &cancellables)
    }
    
    func syncWorkoutState() {
        guard let session = currentSession else { return }
        
        let state: [String: Any] = [
            "type": "gymWorkoutState",
            "sessionId": session.id,
            "sessionName": session.name,
            "elapsedTime": session.elapsedTime,
            "totalCalories": session.metrics.totalCalories,
            "totalVolume": session.metrics.totalVolume,
            "totalReps": session.metrics.totalReps,
            "heartRate": session.metrics.heartRate,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        connectivityManager.sendMessage(state)
        lastSyncTime = Date()
    }
    
    func syncSetCompletion(movementId: String, movementName: String, set: WorkoutSet) {
        let setData: [String: Any] = [
            "type": "gymSetCompleted",
            "movementId": movementId,
            "movementName": movementName,
            "setId": set.id,
            "reps": set.reps,
            "weight": set.weight ?? 0,
            "duration": set.duration ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        connectivityManager.sendMessage(setData)
    }
}

struct GymWorkoutSession: Identifiable {
    let id: String
    let name: String
    var metrics: GymWorkoutMetrics
    var startTime: Date
    var isActive: Bool
    
    /// Computed property that calculates elapsed time since workout started
    var elapsedTime: TimeInterval {
        guard isActive else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    init(id: String = UUID().uuidString,
         name: String,
         metrics: GymWorkoutMetrics = GymWorkoutMetrics(),
         startTime: Date = Date(),
         isActive: Bool = false) {
        self.id = id
        self.name = name
        self.metrics = metrics
        self.startTime = startTime
        self.isActive = isActive
    }
}

struct WorkoutSet: Identifiable, Codable {
    let id: String
    var reps: Int
    var weight: Double?
    var duration: TimeInterval?
    var timestamp: Date
    
    init(id: String = UUID().uuidString,
         reps: Int,
         weight: Double? = nil,
         duration: TimeInterval? = nil,
         timestamp: Date = Date()) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.timestamp = timestamp
    }
}

