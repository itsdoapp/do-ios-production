//
//  WatchApp.swift
//  Do Watch App
//
//  Main watch app entry point
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit
import CoreLocation
import WatchConnectivity

@main
struct WatchApp: App {
    @StateObject private var locationPermissionManager = LocationPermissionManager()
    @StateObject private var healthKitPermissionManager = HealthKitPermissionManager()
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var authService = WatchAuthService.shared
    @StateObject private var workoutCoordinator = WatchWorkoutCoordinator.shared
    
    @State private var isCheckingAuth = true
    
    init() {
        print("⌚️ [WatchApp] Initializing Do Watch App")
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingAuth {
                    // Show loading while checking authentication
                    VStack {
                        ProgressView()
                        Text("Checking authentication...")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                } else if authService.isAuthenticated {
                    // Main app content
                    WorkoutListView()
                        .environmentObject(connectivityManager)
                        .environmentObject(workoutCoordinator)
                        .environmentObject(authService)
                } else {
                    // Not authenticated - show login prompt
                    ZStack {
                        // Brand blue background
                        Color(red: 0.059, green: 0.086, blue: 0.243)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            
                            // Icon container with subtle background
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 68, height: 68)
                                
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.bottom, 16)
                            
                            // Title
                            Text("Not Signed In")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.bottom, 8)
                            
                            // Description
                            Text("Please sign in on your iPhone to use the watch app")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 18)
                                .padding(.bottom, 20)
                            
                            // Button
                            Button(action: {
                                print("⌚️ [WatchApp] Check Again button tapped")
                                checkAuthentication()
                            }) {
                                HStack {
                                    if isCheckingAuth {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .scaleEffect(0.8)
                                    }
                                    Text(isCheckingAuth ? "Checking..." : "Check Again")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(Color(red: 0.059, green: 0.086, blue: 0.243))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isCheckingAuth)
                            .padding(.horizontal, 18)
                            
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .onAppear {
                checkAuthentication()
                requestPermissions()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WatchAuthStateChanged"))) { _ in
                print("⌚️ [WatchApp] Auth state changed notification received")
                self.isCheckingAuth = false
            }
        }
    }
    
    private func checkAuthentication() {
        isCheckingAuth = true
        authService.requestLoginStatus { authenticated, _ in
            DispatchQueue.main.async {
                self.isCheckingAuth = false
                if authenticated {
                    print("⌚️ [WatchApp] User is authenticated")
                } else {
                    print("⌚️ [WatchApp] User is not authenticated")
                }
            }
        }
    }
    
    private func requestPermissions() {
        locationPermissionManager.requestAuthorization()
        
        HealthKitEnabler.shared.requestAuthorization { success, error in
            DispatchQueue.main.async {
                if success {
                    print("⌚️ [WatchApp] HealthKit authorization successful")
                    self.healthKitPermissionManager.isAuthorized = true
                } else if let error = error {
                    print("⌚️ [WatchApp] HealthKit authorization failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Location Permission Manager

class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestAuthorization() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}

// MARK: - HealthKit Permission Manager

class HealthKitPermissionManager: ObservableObject {
    @Published var isAuthorized = false
}

// MARK: - HealthKit Enabler

class HealthKitEnabler {
    static let shared = HealthKitEnabler()
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "HealthKit not available"]))
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.workoutType()
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            completion(success, error)
        }
    }
}

