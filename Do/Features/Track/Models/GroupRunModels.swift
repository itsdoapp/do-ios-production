//
//  GroupRunModels.swift
//  Do
//
//  Models for group run/bike ride functionality
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

// MARK: - Group Run Type

enum GroupRunType: String, Codable {
    case race = "race"
    case groupRun = "groupRun"
    case trainingSession = "trainingSession"
    
    var displayName: String {
        switch self {
        case .race: return "Race"
        case .groupRun: return "Group Run"
        case .trainingSession: return "Training Session"
        }
    }
}

// MARK: - Group Run Stats

struct GroupRunStats: Codable {
    var distance: Double = 0.0 // in meters
    var duration: TimeInterval = 0.0 // in seconds
    var pace: Double = 0.0 // seconds per meter
    var heartRate: Double = 0.0 // bpm
    var calories: Double = 0.0 // kcal
    
    init(distance: Double = 0.0,
         duration: TimeInterval = 0.0,
         pace: Double = 0.0,
         heartRate: Double = 0.0,
         calories: Double = 0.0) {
        self.distance = distance
        self.duration = duration
        self.pace = pace
        self.heartRate = heartRate
        self.calories = calories
    }
}

// MARK: - Group Run Participant

struct GroupRunParticipant: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let displayName: String
    let profileImageURL: String?
    var status: ParticipantStatus
    var stats: GroupRunStats?
    
    init(id: String = UUID().uuidString,
         userId: String,
         userName: String,
         displayName: String,
         profileImageURL: String? = nil,
         status: ParticipantStatus,
         stats: GroupRunStats? = nil) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.status = status
        self.stats = stats
    }
}

// MARK: - Group Run Invitation

struct GroupRunInvitation: Identifiable, Codable {
    let id: UUID
    let fromUser: UserModel
    let runType: GroupRunType
    let scheduledStart: Date?
    let distance: Double? // in kilometers
    let message: String?
    let participants: [GroupRunParticipant]
    let createdAt: Date
    
    init(id: UUID = UUID(),
         fromUser: UserModel,
         runType: GroupRunType,
         scheduledStart: Date? = nil,
         distance: Double? = nil,
         message: String? = nil,
         participants: [GroupRunParticipant] = [],
         createdAt: Date = Date()) {
        self.id = id
        self.fromUser = fromUser
        self.runType = runType
        self.scheduledStart = scheduledStart
        self.distance = distance
        self.message = message
        self.participants = participants
        self.createdAt = createdAt
    }
}



