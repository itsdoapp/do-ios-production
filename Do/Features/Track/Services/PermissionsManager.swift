//
//  PermissionsManager.swift
//  Do
//
//  Manages workout permissions (HealthKit, Location, Motion)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit
import CoreLocation
import CoreMotion
import UIKit

// MARK: - Permission Types

struct Permission {
    let type: PermissionType
    let name: String
    
    enum PermissionType {
        case healthKit
        case location
        case motion
    }
}

// MARK: - Permissions Manager

class PermissionsManager {
    static let shared = PermissionsManager()
    
    private let healthStore = HKHealthStore()
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionActivityManager()
    
    private init() {}
    
    /// Ensures all required permissions for a workout type are granted
    /// - Parameters:
    ///   - workoutType: Type of workout ("running", "swimming", "cycling", "hiking", "gym", "sports")
    ///   - isIndoor: Whether the workout is indoor (affects location permission requirement)
    ///   - completion: Callback with success status and missing permissions
    func ensureWorkoutPermissions(
        for workoutType: String,
        isIndoor: Bool,
        completion: @escaping (Bool, [Permission]) -> Void
    ) {
        var requiredPermissions: [Permission] = []
        var missingPermissions: [Permission] = []
        
        // Determine required permissions based on workout type
        switch workoutType.lowercased() {
        case "running", "cycling", "hiking", "sports":
            // Outdoor workouts require location
            if !isIndoor {
                requiredPermissions.append(Permission(type: .location, name: "Location"))
            }
            requiredPermissions.append(Permission(type: .healthKit, name: "Health"))
            
        case "swimming", "gym":
            // Indoor workouts typically don't need location
            requiredPermissions.append(Permission(type: .healthKit, name: "Health"))
            
        default:
            // Default: require health and location
            requiredPermissions.append(Permission(type: .healthKit, name: "Health"))
            if !isIndoor {
                requiredPermissions.append(Permission(type: .location, name: "Location"))
            }
        }
        
        // Check each required permission
        var healthKitGranted = false
        var locationGranted = false
        
        // Check HealthKit
        if requiredPermissions.contains(where: { $0.type == .healthKit }) {
            if HKHealthStore.isHealthDataAvailable() {
                let workoutType = HKObjectType.workoutType()
                let status = healthStore.authorizationStatus(for: workoutType)
                healthKitGranted = (status == .sharingAuthorized)
                
                if !healthKitGranted {
                    // Request authorization
                    let typesToShare: Set<HKSampleType> = [workoutType]
                    let typesToRead: Set<HKObjectType> = [
                        HKObjectType.quantityType(forIdentifier: .heartRate)!,
                        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
                    ]
                    
                    healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                healthKitGranted = true
                                self.checkAllPermissions(
                                    required: requiredPermissions,
                                    healthKit: healthKitGranted,
                                    location: locationGranted,
                                    completion: completion
                                )
                            } else {
                                missingPermissions.append(Permission(type: .healthKit, name: "Health"))
                                completion(false, missingPermissions)
                            }
                        }
                    }
                    return // Will complete asynchronously
                }
            } else {
                missingPermissions.append(Permission(type: .healthKit, name: "Health"))
            }
        } else {
            healthKitGranted = true // Not required
        }
        
        // Check Location
        if requiredPermissions.contains(where: { $0.type == .location }) {
            let status = locationManager.authorizationStatus
            locationGranted = (status == .authorizedWhenInUse || status == .authorizedAlways)
            
            if !locationGranted {
                if status == .notDetermined {
                    // Request authorization
                    locationManager.requestWhenInUseAuthorization()
                    // Note: This is asynchronous, but we'll check status immediately after
                    // In a real implementation, you might want to use a delegate to wait for the response
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let newStatus = self.locationManager.authorizationStatus
                        locationGranted = (newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways)
                        if !locationGranted {
                            missingPermissions.append(Permission(type: .location, name: "Location"))
                        }
                        self.checkAllPermissions(
                            required: requiredPermissions,
                            healthKit: healthKitGranted,
                            location: locationGranted,
                            completion: completion
                        )
                    }
                    return // Will complete asynchronously
                } else {
                    missingPermissions.append(Permission(type: .location, name: "Location"))
                }
            }
        } else {
            locationGranted = true // Not required
        }
        
        // All permissions checked synchronously
        checkAllPermissions(
            required: requiredPermissions,
            healthKit: healthKitGranted,
            location: locationGranted,
            completion: completion
        )
    }
    
    private func checkAllPermissions(
        required: [Permission],
        healthKit: Bool,
        location: Bool,
        completion: @escaping (Bool, [Permission]) -> Void
    ) {
        var missing: [Permission] = []
        
        if required.contains(where: { $0.type == .healthKit }) && !healthKit {
            missing.append(Permission(type: .healthKit, name: "Health"))
        }
        
        if required.contains(where: { $0.type == .location }) && !location {
            missing.append(Permission(type: .location, name: "Location"))
        }
        
        completion(missing.isEmpty, missing)
    }
}




