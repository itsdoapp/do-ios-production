//
//  ModernSwimmingTrackerViewController.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/26/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//


//
//  ModernSwimmingTrackerViewController.swift
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

// MARK: - Main ModernSwimmingTracker View Controller

class ModernSwimmingTrackerViewController: UIViewController, ObservableObject, CategorySwitchable {
    
    // MARK: - Properties
    private var hostingController: UIHostingController<SwimmingTrackerView>?
    private let swimmingTracker = SwimmingTrackingEngine.shared
    private var cancellables = Set<AnyCancellable>()
    
    weak var categoryDelegate: CategorySelectionDelegate?
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwimmingTracker()
        setupHostingController()
    }

    // MARK: - Live Dashboard
    // Moved into SwiftUI view for proper scope
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - Setup Methods
    private func setupSwimmingTracker() {
        // Initialize the swimming tracker and set up the current user
        if CurrentUserService.shared.user == nil {
            swimmingTracker.setCurrentUser()
        } else {
            swimmingTracker.currentUser = CurrentUserService.shared.user
        }
    }

    // MARK: - Live Dashboard (helpers are defined inside SwimmingTrackerView)

    // MARK: - Live Dashboard (helpers are defined inside SwimmingTrackerView)
    
    private func setupHostingController() {
        let swimmingTrackerView = SwimmingTrackerView(viewModel: self)
        hostingController = UIHostingController(rootView: swimmingTrackerView)
        
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
    public func startSwimmingTracking() {
        // PERMISSION CHECK: Swimming only requires Health permission
        PermissionsManager.shared.ensureWorkoutPermissions(for: "swimming", isIndoor: true) { success, missingPermissions in
            if !success {
                // Show alert about missing permissions
                let permissionNames = missingPermissions.map { $0.name }.joined(separator: ", ")
                let alert = UIAlertController(
                    title: "Permissions Required",
                    message: "To start swimming tracking, Do. needs: \(permissionNames). Please grant these permissions in Settings.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                })
                self.present(alert, animated: true)
                return
            }
            
            // All permissions granted - proceed with starting swimming tracking
            print("✅ Permissions verified, starting swimming tracking")
            self.swimmingTracker.startTracking()
        }
    }
    
    public func handleCategorySelection(_ index: Int) {
        categoryDelegate?.didSelectCategory(at: index)
    }
}

// MARK: - Main SwiftUI View
struct SwimmingTrackerView: View {
    @ObservedObject var viewModel: ModernSwimmingTrackerViewController
    @StateObject private var swimmingTracker = SwimmingTrackingEngine.shared
    
    // State properties
    @State private var selectedSwimType: SwimType = .freestyle
    @State private var selectedDuration: TimeInterval = 1800 // 30 minutes
    @State private var showingPoolSelection = false
    @State private var showingCategorySelector = false
    @State private var showingHistory = false
    @State private var selectedCategoryIndex: Int = 5 // Default to Swimming (index 5)
    weak var categoryDelegate: CategorySelectionDelegate?
    // Category data
    private let categoryTitles = ["Running", "Gym", "Cycling", "Hiking", "Walking", "Swimming", "Food", "Meditation", "Sports"]
    private let categoryIcons = ["figure.run", "figure.strengthtraining.traditional", "figure.outdoor.cycle", "figure.hiking", "figure.walk", "figure.pool.swim", "fork.knife", "sparkles", "sportscourt"]
    
    var body: some View {
        ZStack {
            // Background with blue gradient for swimming
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor(red: 0.0, green: 0.1, blue: 0.3, alpha: 1.0)),
                    Color(UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0))
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Top section with header and category button
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Swimming")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Track your swim")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // Category Button
                        Button(action: {
                            showingCategorySelector = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.pool.swim")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Swimming")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.976, green: 0.576, blue: 0.125),
                                        Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Swim type selector
                    swimTypeSelector()
                        .padding(.horizontal)
                    
                    // Duration selector
                    durationSelector()
                        .padding(.horizontal)
                    
                    // Start/Stop controls and Live Dashboard
                    VStack(spacing: 12) {
                        if swimmingTracker.isTracking {
                            liveDashboard()
                            Button(action: {
                                swimmingTracker.endWorkoutAndSave()
                            }) {
                                HStack {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 22))
                                    Text("End & Save")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(12)
                            }
                        } else {
                            Button(action: {
                                viewModel.startSwimmingTracking()
                            }) {
                                HStack {
                                    Image(systemName: "figure.pool.swim")
                                        .font(.system(size: 24))
                                    Text("Start Swimming (on Watch)")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.cyan, Color.blue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Quick actions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Actions")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 16) {
                            actionButton(iconName: "building.2.fill", label: "Pools") {
                                showingPoolSelection = true
                            }
                            
                            actionButton(iconName: "chart.bar.fill", label: "Stats") {
                                showingHistory = true
                            }
                            
                            actionButton(iconName: "person.3.fill", label: "Groups") {
                                // Show swimming groups
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Today's progress
                    progressView()
                        .padding(.horizontal)
                }
                .padding(.vertical, 20)
            }
        }
        .sheet(isPresented: $showingCategorySelector) {
            CategorySelectorView(
                isPresented: $showingCategorySelector,
                selectedCategory: Binding(
                    get: { self.selectedCategoryIndex },
                    set: { newIndex in
                        print("🎯 CategorySelectorView selected index: \(newIndex)")
                        // Directly update UI state
                        self.selectedCategoryIndex = newIndex
                        // Close the sheet first
                        self.showingCategorySelector = false
                        // Use a delay before triggering the navigation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // Call the delegate directly for navigation
                            viewModel.categoryDelegate?.didSelectCategory(at: newIndex)
                        }
                    }
                ),
                categories: Array(zip(categoryTitles, categoryIcons)).map { ($0.0, $0.1) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // History Sheet
        .sheet(isPresented: $showingHistory) {
            SwimmingHistoryView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func swimTypeSelector() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SwimType.allCases) { type in
                    swimTypeButton(type)
                }
            }
        }
    }
    
    private func swimTypeButton(_ type: SwimType) -> some View {
        Button(action: {
            selectedSwimType = type
        }) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(selectedSwimType == type ? .white : .gray)
                
                Text(type.name)
                    .font(.system(size: 12))
                    .foregroundColor(selectedSwimType == type ? .white : .gray)
            }
            .frame(width: 80, height: 80)
            .background(selectedSwimType == type ? Color.cyan.opacity(0.3) : Color.black.opacity(0.3))
            .cornerRadius(12)
        }
    }
    
    private func durationSelector() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duration")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                ForEach([900, 1800, 2700, 3600], id: \.self) { seconds in
                    durationButton(seconds)
                }
            }
        }
    }
    
    private func durationButton(_ seconds: TimeInterval) -> some View {
        Button(action: {
            selectedDuration = seconds
        }) {
            Text("\(Int(seconds/60)) min")
                .font(.system(size: 14))
                .foregroundColor(selectedDuration == seconds ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedDuration == seconds ? Color.cyan.opacity(0.3) : Color.black.opacity(0.3))
                .cornerRadius(20)
        }
    }
    
    private func actionButton(iconName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .frame(width: 80, height: 80)
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
        }
    }
    
    private func progressView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Progress")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("20")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Laps")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 4) {
                    Text("500")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("meters")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 4) {
                    Text("30")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("min")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.3))
            .cornerRadius(16)
        }
    }

    // MARK: - Live Dashboard helpers (in-view scope)
    private func liveDashboard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Dashboard")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            HStack(spacing: 16) {
                metricTile(title: "Laps", value: "\(swimmingTracker.laps)")
                metricTile(title: "Distance", value: String(format: "%.0f m", swimmingTracker.distanceMeters))
                metricTile(title: "Pace/100m", value: swimmingTracker.formattedPacePer100m)
                metricTile(title: "Time", value: swimmingTracker.formattedElapsedTime)
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
        }
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Supporting Types

enum SwimType: String, CaseIterable, Identifiable {
    case freestyle
    case breaststroke
    case backstroke
    case butterfly
    case mixed
    case openWater
    
    var id: String { rawValue }
    
    var name: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .freestyle: return "figure.pool.swim"
        case .breaststroke: return "figure.pool.swim"
        case .backstroke: return "figure.pool.swim"
        case .butterfly: return "figure.pool.swim"
        case .mixed: return "figure.pool.swim"
        case .openWater: return "figure.pool.swim"
        }
    }
}

// MARK: - Note
// SwimmingTrackingEngine has been moved to:
// Do/Features/Track/Engines/SwimmingTrackingEngine.swift




