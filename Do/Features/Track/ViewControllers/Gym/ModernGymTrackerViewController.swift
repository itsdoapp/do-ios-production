//
//  ModernGymTrackerViewController.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/26/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import UIKit
import CoreLocation
import HealthKit
import Combine
import WatchConnectivity
import Foundation

// MARK: - Main ModernGymTracker View Controller

class ModernGymTrackerViewController: UIViewController, ObservableObject, CategorySwitchable {
    
    // MARK: - Properties
     var hostingController: UIHostingController<GymTrackerView>?
     let gymTracker = GymTrackingEngine.shared
     var cancellables = Set<AnyCancellable>()
    
    weak var categoryDelegate: CategorySelectionDelegate?
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGymTracker()
        setupHostingController()
        setupNotificationObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    deinit {
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup Methods
    private func setupGymTracker() {
        // Initialize the gym tracker
        // Note: User setup is handled by GymTrackingEngine if needed
        
        // Set the view background color to match the SwiftUI background
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        
        // Subscribe to gym tracker updates
        gymTracker.$isTracking
            .sink { [weak self] isTracking in
                // Handle tracking state changes
                if isTracking {
                    print("🏋️ [ModernGymTracker] Workout started")
                } else {
                    print("🏋️ [ModernGymTracker] Workout stopped")
                }
            }
            .store(in: &cancellables)
        
        // Setup watch integration
        setupWatchIntegration()
    }
    
    private func setupNotificationObservers() {
        // Observe deep link notifications for opening workouts
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenMovementById(_:)),
            name: Notification.Name("OpenMovementById"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSessionById(_:)),
            name: Notification.Name("OpenSessionById"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenPlanById(_:)),
            name: Notification.Name("OpenPlanById"),
            object: nil
        )
        
        // Observe create/update notifications to refresh data
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMovementCreated(_:)),
            name: Notification.Name("MovementCreated"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMovementUpdated(_:)),
            name: Notification.Name("MovementUpdated"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionCreated(_:)),
            name: Notification.Name("SessionCreated"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionUpdated(_:)),
            name: Notification.Name("SessionUpdated"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlanCreated(_:)),
            name: Notification.Name("PlanCreated"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlanUpdated(_:)),
            name: Notification.Name("PlanUpdated"),
            object: nil
        )
    }
    
    @objc private func handleMovementCreated(_ notification: Notification) {
        print("🔄 [GymTracker] Movement created, refreshing data...")
        // Refresh the SwiftUI view
        if let hostingController = hostingController,
           let gymTrackerView = hostingController.rootView as? GymTrackerView {
            // Trigger a refresh by reloading featured content
            Task { @MainActor in
                await gymTrackerView.loadFeaturedContent()
            }
        }
    }
    
    @objc private func handleMovementUpdated(_ notification: Notification) {
        print("🔄 [GymTracker] Movement updated, refreshing data...")
        handleMovementCreated(notification)
    }
    
    @objc private func handleSessionCreated(_ notification: Notification) {
        print("🔄 [GymTracker] Session created, refreshing data...")
        // Refresh the SwiftUI view
        if let hostingController = hostingController,
           let gymTrackerView = hostingController.rootView as? GymTrackerView {
            // Trigger a refresh by reloading personalized content
            Task { @MainActor in
                await gymTrackerView.loadPersonalizedContent()
            }
        }
    }
    
    @objc private func handleSessionUpdated(_ notification: Notification) {
        print("🔄 [GymTracker] Session updated, refreshing data...")
        handleSessionCreated(notification)
    }
    
    @objc private func handlePlanCreated(_ notification: Notification) {
        print("🔄 [GymTracker] Plan created, refreshing data...")
        // Refresh the SwiftUI view
        if let hostingController = hostingController,
           let gymTrackerView = hostingController.rootView as? GymTrackerView {
            // Trigger a refresh by reloading personalized content and today's workout
            Task { @MainActor in
                await gymTrackerView.loadPersonalizedContent()
                await gymTrackerView.loadTodayWorkout()
            }
        }
    }
    
    @objc private func handlePlanUpdated(_ notification: Notification) {
        print("🔄 [GymTracker] Plan updated, refreshing data...")
        handlePlanCreated(notification)
    }
    
    // MARK: - Deep Link Handlers
    
    @objc private func handleOpenMovementById(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let movementId = userInfo["movementId"] as? String else {
            print("❌ [DeepLink] Missing movementId in notification")
            return
        }
        
        print("🔗 [DeepLink] Opening movement: \(movementId)")
        openMovementDetail(movementId: movementId)
    }
    
    @objc private func handleOpenSessionById(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let sessionId = userInfo["sessionId"] as? String else {
            print("❌ [DeepLink] Missing sessionId in notification")
            return
        }
        
        print("🔗 [DeepLink] Opening session: \(sessionId)")
        openSessionDetail(sessionId: sessionId)
    }
    
    @objc private func handleOpenPlanById(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let planId = userInfo["planId"] as? String else {
            print("❌ [DeepLink] Missing planId in notification")
            return
        }
        
        print("🔗 [DeepLink] Opening plan: \(planId)")
        openPlanDetail(planId: planId)
    }
    
    // MARK: - Deep Link Navigation Methods
    
    private func openMovementDetail(movementId: String) {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("❌ [DeepLink] No user ID available")
            showErrorAlert(message: "Please log in to view this workout")
            return
        }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Loading...", message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // Fetch movements from AWS and find the one with matching ID
        // First try user's movements, then try public movements
        AWSWorkoutService.shared.getMovements(userId: userId, limit: 1000) { [weak self] userResult in
            DispatchQueue.main.async {
                switch userResult {
                case .success(let response):
                    guard let items = response.data else {
                        // Try public movements
                        AWSWorkoutService.shared.getMovements(userId: nil, isPublic: true, limit: 1000) { [weak self] publicResult in
                            DispatchQueue.main.async {
                                switch publicResult {
                                case .success(let publicResponse):
                                    if let item = publicResponse.data?.first(where: { $0.movementId == movementId }) {
                                        guard let strongSelf = self else { return }
                                        let movement = strongSelf.convertToMovement(from: item)
                                        if !movement.id.isEmpty {
                                            strongSelf.showExerciseDetail(movement)
                                        } else {
                                            strongSelf.showErrorAlert(message: "Workout not found")
                                        }
                                    } else {
                                        self?.showErrorAlert(message: "Workout not found")
                                    }
                                case .failure(let error):
                                    print("❌ [DeepLink] Error fetching movement: \(error.localizedDescription)")
                                    self?.showErrorAlert(message: "Unable to load workout. Please try again.")
                                }
                            }
                        }
                        return
                    }
                    // Find the movement with matching ID
                    if let item = items.first(where: { $0.movementId == movementId }) {
                        loadingAlert.dismiss(animated: true) {
                            guard let strongSelf = self else { return }
                            let movement = strongSelf.convertToMovement(from: item)
                            if !movement.id.isEmpty {
                                strongSelf.showExerciseDetail(movement)
                            } else {
                                strongSelf.showErrorAlert(message: "Workout not found")
                            }
                        }
                        return
                    }
                case .failure:
                    break
                }
                
                // If not found in user's movements, try public movements
                AWSWorkoutService.shared.getMovements(userId: nil, isPublic: true, limit: 1000) { [weak self] publicResult in
                    DispatchQueue.main.async {
                        loadingAlert.dismiss(animated: true) {
                            switch publicResult {
                            case .success(let publicResponse):
                                if let item = publicResponse.data?.first(where: { $0.movementId == movementId }) {
                                    guard let strongSelf = self else { return }
                                    let movement = strongSelf.convertToMovement(from: item)
                                    if !movement.id.isEmpty {
                                        strongSelf.showExerciseDetail(movement)
                                    } else {
                                        strongSelf.showErrorAlert(message: "Workout not found")
                                    }
                                } else {
                                    self?.showErrorAlert(message: "Workout not found")
                                }
                            case .failure(let error):
                                print("❌ [DeepLink] Error fetching movement: \(error.localizedDescription)")
                                self?.showErrorAlert(message: "Unable to load workout. Please try again.")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func openSessionDetail(sessionId: String) {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("❌ [DeepLink] No user ID available")
            showErrorAlert(message: "Please log in to view this workout")
            return
        }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Loading...", message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // Fetch sessions from AWS and find the one with matching ID
        // First try user's sessions, then try public sessions
        AWSWorkoutService.shared.getSessions(userId: userId, limit: 1000) { [weak self] userResult in
            DispatchQueue.main.async {
                switch userResult {
                case .success(let response):
                    guard let items = response.data else {
                        // Try public sessions
                        AWSWorkoutService.shared.getSessions(userId: nil, isPublic: true, limit: 1000) { [weak self] publicResult in
                            DispatchQueue.main.async {
                                loadingAlert.dismiss(animated: true) {
                                    switch publicResult {
                                    case .success(let publicResponse):
                                        if let item = publicResponse.data?.first(where: { $0.sessionId == sessionId }) {
                                            guard let strongSelf = self else { return }
                                            if let session = strongSelf.convertToWorkoutSession(from: item, userId: userId ?? "") {
                                                strongSelf.showSessionDetail(session)
                                            } else {
                                                strongSelf.showErrorAlert(message: "Workout session not found")
                                            }
                                        } else {
                                            self?.showErrorAlert(message: "Workout session not found")
                                        }
                                    case .failure(let error):
                                        print("❌ [DeepLink] Error fetching session: \(error.localizedDescription)")
                                        self?.showErrorAlert(message: "Unable to load workout session. Please try again.")
                                    }
                                }
                            }
                        }
                        return
                    }
                    if let item = items.first(where: { $0.sessionId == sessionId }) {
                        loadingAlert.dismiss(animated: true) {
                            guard let strongSelf = self else { return }
                            if let session = strongSelf.convertToWorkoutSession(from: item, userId: userId) {
                                strongSelf.showSessionDetail(session)
                            } else {
                                strongSelf.showErrorAlert(message: "Workout session not found")
                            }
                        }
                        return
                    }
                case .failure:
                    break
                }
                
                // If not found in user's sessions, try public sessions
                AWSWorkoutService.shared.getSessions(userId: nil, isPublic: true, limit: 1000) { [weak self] publicResult in
                    DispatchQueue.main.async {
                        loadingAlert.dismiss(animated: true) {
                            switch publicResult {
                            case .success(let publicResponse):
                                if let item = publicResponse.data?.first(where: { $0.sessionId == sessionId }) {
                                    guard let strongSelf = self else { return }
                                    if let session = strongSelf.convertToWorkoutSession(from: item, userId: userId ?? "") {
                                        strongSelf.showSessionDetail(session)
                                    } else {
                                        strongSelf.showErrorAlert(message: "Workout session not found")
                                    }
                                } else {
                                    self?.showErrorAlert(message: "Workout session not found")
                                }
                            case .failure(let error):
                                print("❌ [DeepLink] Error fetching session: \(error.localizedDescription)")
                                self?.showErrorAlert(message: "Unable to load workout session. Please try again.")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func openPlanDetail(planId: String) {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("❌ [DeepLink] No user ID available")
            showErrorAlert(message: "Please log in to view this workout plan")
            return
        }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Loading...", message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // Fetch plans from AWS and find the one with matching ID
        AWSWorkoutService.shared.getPlans(userId: userId, limit: 1000) { [weak self] result in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let response):
                        guard let items = response.data else {
                            self?.showErrorAlert(message: "Workout plan not found")
                            return
                        }
                        // Find the plan with matching ID
                        if let item = items.first(where: { $0.planId == planId }) {
                            guard let strongSelf = self else { return }
                            let plan = strongSelf.convertToPlan(from: item)
                            if !plan.id.isEmpty {
                                strongSelf.showPlanDetail(plan)
                            } else {
                                strongSelf.showErrorAlert(message: "Workout plan not found")
                            }
                        } else {
                            self?.showErrorAlert(message: "Workout plan not found")
                        }
                    case .failure(let error):
                        print("❌ [DeepLink] Error fetching plan: \(error.localizedDescription)")
                        self?.showErrorAlert(message: "Unable to load workout plan. Please try again.")
                    }
                }
            }
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Find the topmost view controller to present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }
            topVC.present(alert, animated: true)
        }
    }
    
    private func setupHostingController() {
        let gymTrackerView = GymTrackerView(viewModel: self)
        hostingController = UIHostingController(rootView: gymTrackerView)
        
        if let hostingController = hostingController {
            // Set hosting controller's background to match the main gradient
            hostingController.view.backgroundColor = UIColor.clear
            
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
    
    func startOpenTraining() {
        print("Starting Open Training workout")
        
        // PERMISSION CHECK: Ensure all required permissions before starting gym workout
        PermissionsManager.shared.ensureWorkoutPermissions(for: "gym", isIndoor: true) { success, missingPermissions in
            if !success {
                // Show alert about missing permissions
                let permissionNames = missingPermissions.map { $0.name }.joined(separator: ", ")
                let alert = UIAlertController(
                    title: "Permissions Required",
                    message: "To start your workout, Do. needs: \(permissionNames). Please grant these permissions in Settings.",
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
            
            // All permissions granted - proceed with starting the workout
            self.continueStartingOpenTraining()
        }
    }
    
    private func continueStartingOpenTraining() {
        print("✅ Permissions verified, starting Open Training workout")
        
        // Create a new session for open training
        var session = workoutSession()
        session.name = "Open Training"
        session.id = UUID().uuidString
        
        // Present the NewWorkoutTrackingViewController with isOpenTraining = true
        let trackingVC = NewWorkoutTrackingViewController(session: session, isOpenTraining: true)
        trackingVC.modalPresentationStyle = .fullScreen
        
        // Add animation transition
        let transition = CATransition()
        transition.duration = 0.3
        transition.type = CATransitionType.push
        transition.subtype = .fromRight
        view.window?.layer.add(transition, forKey: kCATransition)
        
        self.present(trackingVC, animated: false)
    }
    
    // MARK: - Quick Actions Methods
    
    func createNewMovement() {
        let editVC = ModernEditMovementViewController()
        editVC.movementToEdit = nil
        editVC.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        if let sheet = editVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        editVC.onSave = { [weak self] savedMovement in
            // Refresh the view or update UI as needed
            NotificationCenter.default.post(name: NSNotification.Name("MovementCreated"), object: savedMovement)
        }
        
        // Find the topmost presented view controller
        if let topVC = topMostViewController() {
            topVC.present(editVC, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(editVC, animated: true)
        }
    }
    
    func createNewSession() {
        let editVC = ModernEditSessionViewController()
        editVC.sessionToEdit = nil
        editVC.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        if let sheet = editVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        editVC.onSave = { [weak self] savedSession in
            // Refresh the view or update UI as needed
            NotificationCenter.default.post(name: NSNotification.Name("SessionCreated"), object: savedSession)
        }
        
        // Find the topmost presented view controller
        if let topVC = topMostViewController() {
            topVC.present(editVC, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(editVC, animated: true)
        }
    }
    
    func createNewPlan() {
        let editVC = ModernEditPlanViewController()
        editVC.planToEdit = nil
        editVC.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        if let sheet = editVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        editVC.onSave = { [weak self] savedPlan in
            // Refresh the view or update UI as needed
            NotificationCenter.default.post(name: NSNotification.Name("PlanCreated"), object: savedPlan)
        }
        
        // Find the topmost presented view controller
        if let topVC = topMostViewController() {
            topVC.present(editVC, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(editVC, animated: true)
        }
    }
    
    // Legacy method - kept for compatibility
    private func createNewMovementLegacy() {
        print("Creating new movement")
        
        // Present modern SwiftUI-based create flow
        let hostingController = UIHostingController(rootView: ModernCreateMovementView())
        hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        hostingController.view.backgroundColor = UIColor.clear
        
        // Add transition animation
        let transition = CATransition()
        transition.duration = 0.3
        transition.type = CATransitionType.fade
        view.window?.layer.add(transition, forKey: kCATransition)
        
        self.present(hostingController, animated: false)
    }
    
    // Old createNewSession and createNewPlan methods removed - using modern edit views above
    
    func showHistory() {
        print("Showing workout history")
        
        // Present as page sheet (not full screen) for better UX
        let historyVC = WorkoutHistoryVC()
        historyVC.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        
        // Configure sheet presentation for drag-to-dismiss
        if let sheet = historyVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        // Find the topmost view controller to present from
        if let topVC = topMostViewController() {
            topVC.present(historyVC, animated: true)
        } else {
            self.present(historyVC, animated: true)
        }
    }
    
    // MARK: - CategorySwitchable Methods
    public func handleCategorySelection(_ index: Int) {
        categoryDelegate?.didSelectCategory(at: index)
    }
    
    // MARK: - Conversion Helpers
    
    /// Helper function to parse a set dictionary into a set struct
    static func parseSet(from setDict: [String: Any]) -> set {
        var set = set()
        set.id = setDict["id"] as? String ?? setDict["setId"] as? String ?? UUID().uuidString
        if let weightStr = setDict["weight"] as? String {
            set.weight = Double(weightStr)
        } else if let weightDouble = setDict["weight"] as? Double {
            set.weight = weightDouble
        }
        if let repsStr = setDict["reps"] as? String {
            set.reps = Int(repsStr)
        } else if let repsInt = setDict["reps"] as? Int {
            set.reps = repsInt
        }
        if let secStr = setDict["sec"] as? String ?? setDict["time"] as? String, let seconds = Int(secStr) {
            set.duration = seconds
        } else if let durationInt = setDict["duration"] as? Int {
            set.duration = durationInt
        }
        return set
    }
    
    func convertToMovement(from item: AWSWorkoutService.WorkoutItem) -> movement {
        var mov = movement()
        mov.id = item.movementId ?? UUID().uuidString
        
        // Handle movement names - prioritize movement1Name, fallback to name field
        mov.movement1Name = item.movement1Name ?? item.name ?? "Unnamed Movement"
        mov.movement2Name = item.movement2Name
        
        // Set isSingle flag from explicit value in data
        mov.isSingle = item.isSingle ?? true
        
        mov.category = item.category
        mov.description = item.description
        mov.difficulty = item.difficulty
        // Convert Bool equipmentNeeded to [String]? equipmentsNeeded
        if let equipmentNeeded = item.equipmentNeeded {
            mov.equipmentsNeeded = equipmentNeeded ? ["Equipment needed"] : []
        }
        mov.isTimed = item.isTimed ?? false
        
        // Parse sets if available
        // Sets can be directly on the movement item or nested in a movements array
        if let firstSectionSets = item.firstSectionSets as? [[String: Any]] {
            mov.firstSectionSets = firstSectionSets.compactMap { setDict -> set? in
                var set = set()
                set.id = setDict["id"] as? String ?? setDict["setId"] as? String ?? UUID().uuidString
                if let weightStr = setDict["weight"] as? String {
                    set.weight = Double(weightStr)
                } else if let weightDouble = setDict["weight"] as? Double {
                    set.weight = weightDouble
                }
                if let repsStr = setDict["reps"] as? String {
                    set.reps = Int(repsStr)
                } else if let repsInt = setDict["reps"] as? Int {
                    set.reps = repsInt
                }
                if let secStr = setDict["sec"] as? String ?? setDict["time"] as? String, let seconds = Int(secStr) {
                    set.duration = seconds
                } else if let durationInt = setDict["duration"] as? Int {
                    set.duration = durationInt
                }
                return set
            }
        }
        
        if let secondSectionSets = item.secondSectionSets as? [[String: Any]] {
            mov.secondSectionSets = secondSectionSets.compactMap { setDict -> set? in
                var set = set()
                set.id = setDict["id"] as? String ?? setDict["setId"] as? String ?? UUID().uuidString
                if let weightStr = setDict["weight"] as? String {
                    set.weight = Double(weightStr)
                } else if let weightDouble = setDict["weight"] as? Double {
                    set.weight = weightDouble
                }
                if let repsStr = setDict["reps"] as? String {
                    set.reps = Int(repsStr)
                } else if let repsInt = setDict["reps"] as? Int {
                    set.reps = repsInt
                }
                if let secStr = setDict["sec"] as? String ?? setDict["time"] as? String, let seconds = Int(secStr) {
                    set.duration = seconds
                } else if let durationInt = setDict["duration"] as? Int {
                    set.duration = durationInt
                }
                return set
            }
        }
        
        if let weavedSets = item.weavedSets as? [[String: Any]] {
            mov.weavedSets = weavedSets.compactMap { setDict -> set? in
                var set = set()
                set.id = setDict["id"] as? String ?? setDict["setId"] as? String ?? UUID().uuidString
                if let weightStr = setDict["weight"] as? String {
                    set.weight = Double(weightStr)
                } else if let weightDouble = setDict["weight"] as? Double {
                    set.weight = weightDouble
                }
                if let repsStr = setDict["reps"] as? String {
                    set.reps = Int(repsStr)
                } else if let repsInt = setDict["reps"] as? Int {
                    set.reps = repsInt
                }
                if let secStr = setDict["sec"] as? String ?? setDict["time"] as? String, let seconds = Int(secStr) {
                    set.duration = seconds
                } else if let durationInt = setDict["duration"] as? Int {
                    set.duration = durationInt
                }
                return set
            }
        }
        
        // Also check if sets are nested in a movements array (for backward compatibility)
        if let movementsData = item.movements as? [[String: Any]], let firstMovement = movementsData.first {
            // Parse firstSectionSets
            if let firstSectionSets = firstMovement["firstSectionSets"] as? [[String: Any]], mov.firstSectionSets == nil {
                mov.firstSectionSets = firstSectionSets.compactMap { setDict -> set? in
                    var set = set()
                    set.id = setDict["id"] as? String ?? setDict["setId"] as? String ?? UUID().uuidString
                    if let weightStr = setDict["weight"] as? String {
                        set.weight = Double(weightStr)
                    } else if let weightDouble = setDict["weight"] as? Double {
                        set.weight = weightDouble
                    }
                    if let repsStr = setDict["reps"] as? String {
                        set.reps = Int(repsStr)
                    } else if let repsInt = setDict["reps"] as? Int {
                        set.reps = repsInt
                    }
                    if let secStr = setDict["sec"] as? String ?? setDict["time"] as? String, let seconds = Int(secStr) {
                        set.duration = seconds
                    } else if let durationInt = setDict["duration"] as? Int {
                        set.duration = durationInt
                    }
                    return set
                }
            }
            
            // Parse secondSectionSets
            if let secondSectionSets = firstMovement["secondSectionSets"] as? [[String: Any]], mov.secondSectionSets == nil {
                mov.secondSectionSets = secondSectionSets.compactMap { setDict -> set? in
                    var set = set()
                    set.id = setDict["id"] as? String ?? setDict["setId"] as? String ?? UUID().uuidString
                    if let weightStr = setDict["weight"] as? String {
                        set.weight = Double(weightStr)
                    } else if let weightDouble = setDict["weight"] as? Double {
                        set.weight = weightDouble
                    }
                    if let repsStr = setDict["reps"] as? String {
                        set.reps = Int(repsStr)
                    } else if let repsInt = setDict["reps"] as? Int {
                        set.reps = repsInt
                    }
                    if let secStr = setDict["sec"] as? String ?? setDict["time"] as? String, let seconds = Int(secStr) {
                        set.duration = seconds
                    } else if let durationInt = setDict["duration"] as? Int {
                        set.duration = durationInt
                    }
                    return set
                }
            }
            
            // Parse weavedSets
            if let weavedSets = firstMovement["weavedSets"] as? [[String: Any]], mov.weavedSets == nil {
                mov.weavedSets = weavedSets.compactMap { setDict -> set? in
                    var set = set()
                    set.id = setDict["id"] as? String ?? setDict["setId"] as? String ?? UUID().uuidString
                    if let weightStr = setDict["weight"] as? String {
                        set.weight = Double(weightStr)
                    } else if let weightDouble = setDict["weight"] as? Double {
                        set.weight = weightDouble
                    }
                    if let repsStr = setDict["reps"] as? String {
                        set.reps = Int(repsStr)
                    } else if let repsInt = setDict["reps"] as? Int {
                        set.reps = repsInt
                    }
                    if let secStr = setDict["sec"] as? String ?? setDict["time"] as? String, let seconds = Int(secStr) {
                        set.duration = seconds
                    } else if let durationInt = setDict["duration"] as? Int {
                        set.duration = durationInt
                    }
                    return set
                }
            }
        }
        
        return mov
    }
    
    func convertToWorkoutSession(from item: AWSWorkoutService.WorkoutItem, userId: String) -> workoutSession? {
        guard let sessionId = item.sessionId else { return nil }
        
        var session = workoutSession()
        session.id = sessionId
        session.name = item.name
        session.description = item.description
        session.difficulty = item.difficulty ?? item.category
        // Convert Bool equipmentNeeded to [String]? equipmentNeeded
        if let equipmentNeeded = item.equipmentNeeded {
            session.equipmentNeeded = equipmentNeeded ? ["Equipment needed"] : []
        }
        
        // Parse createdAt if available
        if let createdAtString = item.createdAt {
            let formatter = ISO8601DateFormatter()
            session.createdAt = formatter.date(from: createdAtString)
        }
        
        // Convert movements if available (embedded movements in session)
        // According to schema, sessions have 'movements' array (embedded movements)
        let movementsData = item.movements ?? item.movementsInSession
        if let movementsData = movementsData {
            session.movementsInSession = movementsData.compactMap { dict -> movement? in
                var mov = movement()
                
                // Try different possible keys for movement ID
                mov.id = (dict["movementId"] as? String) ?? (dict["id"] as? String) ?? UUID().uuidString
                // Handle movement names - prioritize movement1Name, fallback to name field
                mov.movement1Name = (dict["movement1Name"] as? String) 
                    ?? (dict["name"] as? String)
                    ?? "Unnamed Movement"
                mov.movement2Name = dict["movement2Name"] as? String
                
                // Set isSingle flag from explicit value in data
                mov.isSingle = (dict["isSingle"] as? Bool) ?? true
                
                mov.category = dict["category"] as? String
                mov.isTimed = (dict["isTimed"] as? Bool) ?? false
                mov.difficulty = dict["difficulty"] as? String
                mov.description = dict["description"] as? String
                
                // Handle equipment needed - check both spellings
                if let equipmentNeeded = dict["equipmentNeeded"] as? Bool {
                    mov.equipmentsNeeded = equipmentNeeded ? ["Equipment needed"] : []
                } else if let equipmentsNeeded = dict["equipmentsNeeded"] as? Bool {
                    mov.equipmentsNeeded = equipmentsNeeded ? ["Equipment needed"] : []
                }
                
                // Handle sets if available
                if let firstSectionSets = dict["firstSectionSets"] as? [[String: Any]] {
                    mov.firstSectionSets = firstSectionSets.compactMap { setDict -> set? in
                        ModernGymTrackerViewController.parseSet(from: setDict)
                    }
                }
                
                if let secondSectionSets = dict["secondSectionSets"] as? [[String: Any]] {
                    mov.secondSectionSets = secondSectionSets.compactMap { setDict -> set? in
                        ModernGymTrackerViewController.parseSet(from: setDict)
                    }
                }
                
                if let weavedSets = dict["weavedSets"] as? [[String: Any]] {
                    mov.weavedSets = weavedSets.compactMap { setDict -> set? in
                        ModernGymTrackerViewController.parseSet(from: setDict)
                    }
                }
                
                // Only return movement if it has a valid name (not just the default)
                guard let name = mov.movement1Name, !name.isEmpty, name != "Unnamed Movement" else {
                    return nil
                }
                
                return mov
            }
        }
        
        return session
    }
    
    func convertToPlan(from item: AWSWorkoutService.WorkoutItem) -> plan {
        var p = plan()
        p.id = item.planId ?? UUID().uuidString
        p.name = item.name ?? "Unnamed Plan"
        p.description = item.description
        p.difficulty = item.difficulty ?? item.category
        p.category = item.category
        p.duration = item.duration
        p.equipmentNeeded = item.equipmentNeeded
        p.tags = item.tags ?? []
        p.imageURL = item.imageURL
        p.ratingValue = item.ratingValue ?? 0.0
        p.numOfRating = item.ratingCount ?? 0
        
        // According to schema, plans have 'sessions' as a Map<String, String>
        // (e.g., {"Monday": "sessionId1", "Day 1": "sessionId2"})
        // Use the sessions field if available, otherwise fall back to movementsInPlan
        if let sessions = item.sessions {
            p.sessions = sessions
        } else if let sessionsData = item.movementsInPlan {
            // Fallback: try to extract from movementsInPlan if sessions field not available
            var sessions: [String: String] = [:]
            for (index, sessionData) in sessionsData.enumerated() {
                if let sessionId = sessionData["sessionId"] as? String 
                    ?? sessionData["id"] as? String
                    ?? sessionData["session"] as? String {
                    sessions["Day \(index + 1)"] = sessionId
                } else if let dayKey = sessionData["day"] as? String,
                          let sessionId = sessionData["sessionId"] as? String {
                    sessions[dayKey] = sessionId
                }
            }
            p.sessions = sessions.isEmpty ? nil : sessions
        }
        
        // Determine plan type: use explicit value from AWS, or infer from session keys
        if let explicitValue = item.isDayOfTheWeekPlan {
            p.isDayOfTheWeekPlan = explicitValue
        } else if let sessions = p.sessions, !sessions.isEmpty {
            // Infer from session keys: if keys are day names (Monday, Tuesday, etc.), it's day-of-week
            // If keys are "Day 1", "Day 2", etc., it's sequential
            let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            let hasDayNameKeys = sessions.keys.contains { dayNames.contains($0) }
            p.isDayOfTheWeekPlan = hasDayNameKeys
        } else {
            // Default to sequential if we can't determine
            p.isDayOfTheWeekPlan = false
        }
        
        return p
    }
    
    // MARK: - Detail View Presentation Methods
    
    // Helper method to find the topmost view controller
    private func topMostViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            return nil
        }
        
        var topVC = rootVC
        while let presentedVC = topVC.presentedViewController {
            topVC = presentedVC
        }
        
        return topVC
    }
    
    func showExerciseDetail(_ exercise: movement) {
        // If the exercise already has sets, show it directly
        // Otherwise, fetch it fresh from AWS to ensure sets are loaded
        let hasSets = (exercise.firstSectionSets?.isEmpty == false) ||
                     (exercise.secondSectionSets?.isEmpty == false) ||
                     (exercise.weavedSets?.isEmpty == false)
        
        if hasSets || exercise.id == nil {
            // Show directly if sets are present or no ID to fetch
            let hostingController = UIHostingController(rootView: ExerciseDetailView(exercise: exercise, viewModel: self))
            hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
            hostingController.view.backgroundColor = UIColor.clear
            
            if let topVC = topMostViewController() {
                topVC.present(hostingController, animated: true)
            } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(hostingController, animated: true)
            }
        } else {
            // Fetch fresh from AWS to get sets
            guard let userId = UserIDHelper.shared.getCurrentUserID(),
                  !exercise.id.isEmpty else {
                // Fallback to showing without sets
                let hostingController = UIHostingController(rootView: ExerciseDetailView(exercise: exercise, viewModel: self))
                hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                hostingController.view.backgroundColor = UIColor.clear
                
                if let topVC = topMostViewController() {
                    topVC.present(hostingController, animated: true)
                } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    rootVC.present(hostingController, animated: true)
                }
                return
            }
            
            // Fetch from AWS
            let movementId = exercise.id
            AWSWorkoutService.shared.getMovements(userId: userId, limit: 1000) { [weak self] userResult in
                DispatchQueue.main.async {
                    switch userResult {
                    case .success(let response):
                        guard let items = response.data else {
                            // Try public movements
                            AWSWorkoutService.shared.getMovements(userId: nil, isPublic: true, limit: 1000) { [weak self] publicResult in
                                DispatchQueue.main.async {
                                    switch publicResult {
                                    case .success(let publicResponse):
                                        if let item = publicResponse.data?.first(where: { $0.movementId == movementId }) {
                                            guard let strongSelf = self else { return }
                                            let movementWithSets = strongSelf.convertToMovement(from: item)
                                            
                                            let hostingController = UIHostingController(rootView: ExerciseDetailView(exercise: movementWithSets, viewModel: strongSelf))
                                            hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                                            hostingController.view.backgroundColor = UIColor.clear
                                            
                                            if let topVC = strongSelf.topMostViewController() {
                                                topVC.present(hostingController, animated: true)
                                            } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                               let window = windowScene.windows.first,
                                               let rootVC = window.rootViewController {
                                                rootVC.present(hostingController, animated: true)
                                            }
                                        } else {
                                            // Fallback to showing without sets
                                            guard let strongSelf = self else { return }
                                            let hostingController = UIHostingController(rootView: ExerciseDetailView(exercise: exercise, viewModel: strongSelf))
                                            hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                                            hostingController.view.backgroundColor = UIColor.clear
                                            
                                            if let topVC = strongSelf.topMostViewController() {
                                                topVC.present(hostingController, animated: true)
                                            } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                               let window = windowScene.windows.first,
                                               let rootVC = window.rootViewController {
                                                rootVC.present(hostingController, animated: true)
                                            }
                                        }
                                    case .failure:
                                        // Fallback to showing without sets
                                        guard let strongSelf = self else { return }
                                        let hostingController = UIHostingController(rootView: ExerciseDetailView(exercise: exercise, viewModel: strongSelf))
                                        hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                                        hostingController.view.backgroundColor = UIColor.clear
                                        
                                        if let topVC = strongSelf.topMostViewController() {
                                            topVC.present(hostingController, animated: true)
                                        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                           let window = windowScene.windows.first,
                                           let rootVC = window.rootViewController {
                                            rootVC.present(hostingController, animated: true)
                                        }
                                    }
                                }
                            }
                            return
                        }
                        if let item = items.first(where: { $0.movementId == movementId }) {
                            guard let strongSelf = self else { return }
                            let movementWithSets = strongSelf.convertToMovement(from: item)
                            
                            let hostingController = UIHostingController(rootView: ExerciseDetailView(exercise: movementWithSets, viewModel: strongSelf))
                            hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                            hostingController.view.backgroundColor = UIColor.clear
                            
                            if let topVC = strongSelf.topMostViewController() {
                                topVC.present(hostingController, animated: true)
                            } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first,
                               let rootVC = window.rootViewController {
                                rootVC.present(hostingController, animated: true)
                            }
                            return
                        }
                    case .failure:
                        break
                    }
                    
                    // If not found in user's movements, try public movements
                    AWSWorkoutService.shared.getMovements(userId: nil, isPublic: true, limit: 1000) { [weak self] publicResult in
                        DispatchQueue.main.async {
                            switch publicResult {
                            case .success(let publicResponse):
                                if let item = publicResponse.data?.first(where: { $0.movementId == movementId }) {
                                    guard let strongSelf = self else { return }
                                    let movementWithSets = strongSelf.convertToMovement(from: item)
                                    
                                    let hostingController = UIHostingController(rootView: ExerciseDetailView(exercise: movementWithSets, viewModel: strongSelf))
                                    hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                                    hostingController.view.backgroundColor = UIColor.clear
                                    
                                    if let topVC = strongSelf.topMostViewController() {
                                        topVC.present(hostingController, animated: true)
                                    } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = windowScene.windows.first,
                                       let rootVC = window.rootViewController {
                                        rootVC.present(hostingController, animated: true)
                                    }
                                } else {
                                    // Fallback to showing without sets
                                    guard let strongSelf = self else { return }
                                    let hostingController = UIHostingController(rootView: ExerciseDetailView(exercise: exercise, viewModel: strongSelf))
                                    hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                                    hostingController.view.backgroundColor = UIColor.clear
                                    
                                    if let topVC = strongSelf.topMostViewController() {
                                        topVC.present(hostingController, animated: true)
                                    } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = windowScene.windows.first,
                                       let rootVC = window.rootViewController {
                                        rootVC.present(hostingController, animated: true)
                                    }
                                }
                            case .failure:
                                // Fallback to showing without sets
                                guard let strongSelf = self else { return }
                                let hostingController = UIHostingController(rootView: ExerciseDetailView(exercise: exercise, viewModel: strongSelf))
                                hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                                hostingController.view.backgroundColor = UIColor.clear
                                
                                if let topVC = strongSelf.topMostViewController() {
                                    topVC.present(hostingController, animated: true)
                                } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = windowScene.windows.first,
                                   let rootVC = window.rootViewController {
                                    rootVC.present(hostingController, animated: true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func showSessionDetail(_ session: workoutSession) {
        let hostingController = UIHostingController(rootView: SessionDetailView(session: session, viewModel: self))
        hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        hostingController.view.backgroundColor = UIColor.clear
        
        // Find the topmost presented view controller (handles modals like BrowseLibraryView)
        if let topVC = topMostViewController() {
            topVC.present(hostingController, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(hostingController, animated: true)
        }
    }
    
    func showPlanDetail(_ plan: plan) {
        let hostingController = UIHostingController(rootView: PlanDetailView(plan: plan, viewModel: self))
        hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        hostingController.view.backgroundColor = UIColor.clear
        
        // Find the topmost presented view controller (handles modals like BrowseLibraryView)
        if let topVC = topMostViewController() {
            topVC.present(hostingController, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(hostingController, animated: true)
        }
    }
    
    // MARK: - Edit Methods
    
    func editExercise(_ exercise: movement, from presentingViewController: UIViewController? = nil) {
        let editVC = ModernEditMovementViewController()
        editVC.movementToEdit = exercise
        editVC.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        if let sheet = editVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        editVC.onSave = { [weak self] savedMovement in
            // Refresh the view or update UI as needed
            NotificationCenter.default.post(name: NSNotification.Name("MovementUpdated"), object: savedMovement)
        }
        
        // If a presenting view controller is provided, use it; otherwise find the topmost
        if let presentingVC = presentingViewController {
            presentingVC.present(editVC, animated: true)
        } else if let topVC = topMostViewController() {
            topVC.present(editVC, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(editVC, animated: true)
        }
    }
    
    func editSession(_ session: workoutSession, from presentingViewController: UIViewController? = nil) {
        let editVC = ModernEditSessionViewController()
        editVC.sessionToEdit = session
        editVC.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        if let sheet = editVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        editVC.onSave = { [weak self] savedSession in
            // Refresh the view or update UI as needed
            NotificationCenter.default.post(name: NSNotification.Name("SessionUpdated"), object: savedSession)
        }
        
        // If a presenting view controller is provided, use it; otherwise find the topmost
        if let presentingVC = presentingViewController {
            presentingVC.present(editVC, animated: true)
        } else if let topVC = topMostViewController() {
            topVC.present(editVC, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(editVC, animated: true)
        }
    }
    
    func editPlan(_ plan: plan, from presentingViewController: UIViewController? = nil) {
        let editVC = ModernEditPlanViewController()
        editVC.planToEdit = plan
        editVC.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        if let sheet = editVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        editVC.onSave = { [weak self] savedPlan in
            // Refresh the view or update UI as needed
            NotificationCenter.default.post(name: NSNotification.Name("PlanUpdated"), object: savedPlan)
        }
        
        // If a presenting view controller is provided, use it; otherwise find the topmost
        if let presentingVC = presentingViewController {
            presentingVC.present(editVC, animated: true)
        } else if let topVC = topMostViewController() {
            topVC.present(editVC, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(editVC, animated: true)
        }
    }
    
    // MARK: - Delete Methods
    
    func deleteExercise(_ exercise: movement) {
        let alertController = UIAlertController(
            title: "Delete Movement",
            message: "Are you sure you want to delete this movement from your library?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDeleteExercise(exercise)
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(alertController, animated: true)
        }
    }
    
    private func performDeleteExercise(_ exercise: movement) {
        guard let userId = CurrentUserService.shared.userID else {
            showErrorAlert(message: "Cannot delete: User not logged in")
            return
        }
        
        // TODO: Implement AWS deletion endpoint when available
        // For now, show a message that deletion is not yet supported
        let alert = UIAlertController(
            title: "Delete Movement",
            message: "Movement deletion is not yet available. This feature will be added soon.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    func deleteSession(_ session: workoutSession) {
        let alertController = UIAlertController(
            title: "Delete Session",
            message: "Are you sure you want to delete this session from your library?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDeleteSession(session)
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(alertController, animated: true)
        }
    }
    
    private func performDeleteSession(_ session: workoutSession) {
        guard let userId = CurrentUserService.shared.userID else {
            showErrorAlert(message: "Cannot delete: User not logged in")
            return
        }
        
        // TODO: Implement AWS deletion endpoint when available
        // For now, show a message that deletion is not yet supported
        let alert = UIAlertController(
            title: "Delete Session",
            message: "Session deletion is not yet available. This feature will be added soon.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    func deletePlan(_ plan: plan) {
        let alertController = UIAlertController(
            title: "Delete Plan",
            message: "Are you sure you want to delete this plan from your library?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDeletePlan(plan)
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(alertController, animated: true)
        }
    }
    
    private func performDeletePlan(_ plan: plan) {
        guard let userId = CurrentUserService.shared.userID else {
            showErrorAlert(message: "Cannot delete: User not logged in")
            return
        }
        
        // TODO: Implement AWS deletion endpoint when available
        // For now, show a message that deletion is not yet supported
        let alert = UIAlertController(
            title: "Delete Plan",
            message: "Plan deletion is not yet available. This feature will be added soon.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
}

// MARK: - Today's Plan Item Model
enum TodayPlanItem {
    case workout(workoutSession)
    case activity(PlanActivity)
    case restDay
    
    var displayName: String {
        switch self {
        case .workout(let session):
            return session.name ?? "Workout"
        case .activity(let activity):
            return activity.displayName
        case .restDay:
            return "Rest Day"
        }
    }
    
    var icon: String {
        switch self {
        case .workout:
            return "dumbbell.fill"
        case .activity(let activity):
            return activity.icon
        case .restDay:
            return "moon.zzz.fill"
        }
    }
}

struct PlanActivity {
    let activityType: String // running, biking, cycling, walking, hiking, swimming, sports
    let distance: Double?
    let duration: Double?
    let runType: String?
    let sportType: String?
    
    var displayName: String {
        switch activityType.lowercased() {
        case "running", "run":
            return "Run"
        case "biking", "cycling", "bike":
            return "Bike"
        case "walking", "walk":
            return "Walk"
        case "hiking", "hike":
            return "Hike"
        case "swimming", "swim":
            return "Swim"
        case "sports", "sport":
            return sportType ?? "Sports"
        default:
            return activityType.capitalized
        }
    }
    
    var icon: String {
        switch activityType.lowercased() {
        case "running", "run":
            return "figure.run"
        case "biking", "cycling", "bike":
            return "bicycle"
        case "walking", "walk":
            return "figure.walk"
        case "hiking", "hike":
            return "figure.hiking"
        case "swimming", "swim":
            return "figure.pool.swim"
        case "sports", "sport":
            return "sportscourt.fill"
        default:
            return "figure.mixed.cardio"
        }
    }
    
    var subtitle: String {
        var parts: [String] = []
        if let distance = distance {
            parts.append(String(format: "%.1f km", distance))
        }
        if let duration = duration {
            let minutes = Int(duration / 60)
            parts.append("\(minutes) min")
        }
        return parts.joined(separator: " • ")
    }
    
    static func fromString(_ string: String) -> PlanActivity? {
        let components = string.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        var activityType: String?
        var distance: Double?
        var duration: Double?
        var runType: String?
        var sportType: String?
        
        for component in components {
            let parts = component.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            
            let key = parts[0].lowercased()
            let value = parts[1]
            
            switch key {
            case "activitytype":
                activityType = value
            case "distance":
                distance = Double(value)
            case "duration":
                duration = Double(value)
            case "runtype":
                runType = value
            case "sporttype":
                sportType = value
            default:
                break
            }
        }
        
        guard let type = activityType else { return nil }
        return PlanActivity(
            activityType: type,
            distance: distance,
            duration: duration,
            runType: runType,
            sportType: sportType
        )
    }
}

// MARK: - Main SwiftUI View
struct GymTrackerView: View {
    @ObservedObject var viewModel: ModernGymTrackerViewController
    @StateObject private var gymTracker = GymTrackingEngine.shared
    
    // State properties
    @State private var showingCategorySelector = false
    @State private var selectedCategoryIndex: Int = 1 // Default to Gym (index 1)
    
    // Stats data - now using real AWS data
    @State private var totalWorkoutsThisWeek: Int = 0
    @State private var currentStreak: Int = 0
    @State private var totalExercisesThisMonth: Int = 0
    
    // Today's workout
    @State private var todayPlanItem: TodayPlanItem? = nil
    @State private var todayWorkout: workoutSession? = nil // Keep for backward compatibility
    @State private var activePlan: plan? = nil
    
    // Content data
    @State private var featuredExercises: [movement] = []
    @State private var recommendedSessions: [workoutSession] = []
    @State private var activePlans: [plan] = []
    @State private var recentSessions: [workoutSession] = []
    
    // Loading states
    @State private var isLoadingTodayWorkout = false
    @State private var isLoadingFeatured = false
    @State private var isLoadingRecommended = false
    
    // Insights data
    @State private var workoutInsights: WorkoutInsights? = nil
    @State private var isLoadingInsights = false
    
    // Category data
    private let categoryTitles = ["Running", "Gym", "Cycling", "Hiking", "Walking", "Swimming", "Food", "Meditation", "Sports"]
    private let categoryIcons = ["figure.run", "figure.strengthtraining.traditional", "figure.outdoor.cycle", "figure.hiking", "figure.walk", "figure.pool.swim", "fork.knife", "sparkles", "sportscourt"]
    
    // Quick action buttons
    private let quickActions = [
        (title: "New Movement", icon: "dumbbell.fill", color: Color(UIColor(hex: "#20D474"))),
        (title: "New Session", icon: "rectangle.stack.fill.badge.plus", color: Color(UIColor(hex: "#F2994A"))),
        (title: "New Plan", icon: "calendar.badge.plus", color: Color(UIColor(hex: "#3C7EF9")))
    ]
    
    var body: some View {
        ZStack {
            // Premium background gradient matching meditation tracker
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.08, green: 0.08, blue: 0.12), location: 0.5),
                    .init(color: Color(red: 0.1, green: 0.1, blue: 0.15), location: 1)
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
                    
                    // Today's Workout Section (prominent card at top)
                    if let planItem = todayPlanItem {
                        todayPlanItemSection(item: planItem)
                            .padding(.horizontal, 20)
                    } else if !isLoadingTodayWorkout {
                        emptyTodayWorkoutSection()
                            .padding(.horizontal, 20)
                    }
                    
                    // Stats Section ("Your Journey")
                    statsSection()
                        .padding(.horizontal, 20)
                        .task {
                            await loadWorkoutStats()
                        }
                    
                    // Insights Section
                    insightsSection()
                        .padding(.horizontal, 20)
                        .task {
                            await loadInsights()
                        }
                    
                    // Quick Actions Section
                    quickActionsSection()
                        .padding(.horizontal, 20)
                    
                    // Open Training Button
                    openTrainingSection()
                        .padding(.horizontal, 20)
                    
                    // Personalized Recommendations Section ("For You")
                    if !recommendedSessions.isEmpty {
                        personalizedRecommendationsSection()
                            .padding(.horizontal, 20)
                    } else if !isLoadingRecommended {
                        emptyRecommendationsSection()
                            .padding(.horizontal, 20)
                    }
                    
                    // Featured Exercises Section
                    if !featuredExercises.isEmpty {
                        featuredExercisesSection()
                            .padding(.horizontal, 20)
                    } else if !isLoadingFeatured {
                        emptyFeaturedSection()
                            .padding(.horizontal, 20)
                    }
                    
                    // Recent Sessions Section
                    if !recentSessions.isEmpty {
                        recentSessionsSection()
                            .padding(.horizontal, 20)
                    }
                    
                    // Active Plans Section
                    if !activePlans.isEmpty {
                        activePlansSection()
                            .padding(.horizontal, 20)
                    } else if !isLoadingRecommended {
                        emptyPlansSection()
                            .padding(.horizontal, 20)
                    }
                    
                    // Browse Library Section
                    browseLibrarySection()
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
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
                            // Call the delegate directly for navigation using the viewModel
                            viewModel.categoryDelegate?.didSelectCategory(at: newIndex)
                        }
                    }
                ),
                categories: Array(zip(categoryTitles, categoryIcons)).map { ($0.0, $0.1) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            loadTodayWorkout()
            loadFeaturedContent()
            loadPersonalizedContent()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshGymData"))) { notification in
            if let type = notification.userInfo?["type"] as? String {
                switch type {
                case "movement":
                    loadFeaturedContent()
                case "session", "plan":
                    loadPersonalizedContent()
                    loadTodayWorkout()
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Section Views
    
    private func headerSection() -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                            Text("Workout")
                    .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Track your fitness journey")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
            HStack(spacing: 12) {
                            // History Button
                    Button(action: {
                        withAnimation(.spring()) {
                                    viewModel.showHistory()
                                }
                            }) {
                                Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            // Category Button
                            Button(action: {
                                    showingCategorySelector = true
                            }) {
                                    Image(systemName: "figure.strengthtraining.traditional")
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
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
                    
    private func todayPlanItemSection(item: TodayPlanItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Today's Plan")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            TodayPlanItemCard(item: item, planName: activePlan?.name, delay: 0) {
                startTodayPlanItem(item)
            }
        }
    }
    
    private func todayWorkoutSection(workout: workoutSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Today's Workout")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            TodayWorkoutCard(workout: workout, planName: activePlan?.name, delay: 0) {
                startWorkout(workout)
            }
        }
    }
    
    private func startTodayPlanItem(_ item: TodayPlanItem) {
        switch item {
        case .workout(let session):
            startWorkout(session)
        case .activity(let activity):
            startActivity(activity)
        case .restDay:
            // Show rest day message
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                let alert = UIAlertController(
                    title: "Rest Day",
                    message: "Today is a rest day. Take time to recover!",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    private func startActivity(_ activity: PlanActivity) {
        // Navigate to appropriate activity tracking based on type
        let activityType = activity.activityType.lowercased()
        
        // Find topmost view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        var topVC = rootVC
        while let presentedVC = topVC.presentedViewController {
            topVC = presentedVC
        }
        
        let vc: UIViewController
        
        switch activityType {
        case "running", "run":
            vc = ModernRunTrackerViewController()
        case "biking", "cycling", "bike":
            vc = ModernBikeTrackerViewController()
        case "walking", "walk":
            vc = ModernWalkingTrackerViewController()
        case "hiking", "hike":
            vc = ModernHikeTrackerViewController()
        case "swimming", "swim":
            vc = ModernSwimmingTrackerViewController()
        case "sports", "sport":
            vc = ModernSportsTrackerViewController()
        default:
            print("Unknown activity type: \(activityType)")
            return
        }
        
        vc.modalPresentationStyle = .fullScreen
        topVC.present(vc, animated: true)
    }
    
    private func statsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Your Journey")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
        HStack(spacing: 20) {
            GymStatCard(
                value: "\(totalWorkoutsThisWeek)",
                label: "This Week",
                icon: "figure.strengthtraining.traditional",
                gradient: [Color.green, Color(red: 0.125, green: 0.8, blue: 0.45)]
            )
            
            GymStatCard(
                value: "\(currentStreak)",
                label: "Day Streak",
                icon: "flame.fill",
                gradient: [Color(red: 1.0, green: 0.42, blue: 0.21), Color(red: 0.976, green: 0.576, blue: 0.125)]
            )
            
            GymStatCard(
                value: "\(totalExercisesThisMonth)",
                label: "Monthly",
                icon: "chart.bar.fill",
                gradient: [Color.blue, Color.cyan]
            )
        }
        }
    }
    
    private func insightsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Insights & Recommendations")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if isLoadingInsights {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if let insights = workoutInsights {
                // Gaps section
                if !insights.gaps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Areas to Focus On")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        
                        ForEach(insights.gaps.prefix(3), id: \.category) { gap in
                            InsightGapCard(gap: gap)
                        }
                    }
                }
                
                // Recommendations section
                if !insights.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommendations")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.top, 8)
                        
                        ForEach(Array(insights.recommendations.enumerated()), id: \.offset) { index, recommendation in
                            InsightRecommendationCard(
                                recommendation: recommendation,
                                onTap: {
                                    if let sessionId = recommendation.sessionId {
                                        // Navigate to session detail
                                        // This would need to fetch and show the session
                                    }
                                }
                            )
                        }
                    }
                }
                
                // Category breakdown
                if !insights.categoryBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Activity Breakdown")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.top, 8)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(insights.categoryBreakdown.keys.sorted()), id: \.self) { category in
                                    if let stats = insights.categoryBreakdown[category] {
                                        CategoryBreakdownCard(category: category, stats: stats)
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    }
                } else {
                Text("Start working out to see insights!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.vertical, 20)
            }
        }
    }
    
    private func loadInsights() async {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else { return }
        
        isLoadingInsights = true
        
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<WorkoutInsights, Error>, Never>) in
            WorkoutInsightsService.shared.analyzeWorkoutHistory(userId: userId, days: 30) { result in
                continuation.resume(returning: result)
            }
        }
        
        switch result {
        case .success(let insights):
            await MainActor.run {
                self.workoutInsights = insights
                self.isLoadingInsights = false
            }
        case .failure(let error):
            print("❌ [GymTracker] Error loading insights: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoadingInsights = false
            }
        }
    }
    
    private func quickActionsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                quickActionButton(title: "New Movement", icon: "dumbbell.fill", color: Color(UIColor(hex: "#20D474"))) {
                    viewModel.createNewMovement()
                }
                
                quickActionButton(title: "New Session", icon: "rectangle.stack.fill.badge.plus", color: Color(UIColor(hex: "#F2994A"))) {
                    viewModel.createNewSession()
                }
                
                quickActionButton(title: "New Plan", icon: "calendar.badge.plus", color: Color(UIColor(hex: "#3C7EF9"))) {
                    viewModel.createNewPlan()
                }
            }
        }
    }
    
    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
                    Button(action: {
                        withAnimation(.spring()) {
                action()
                        }
                    }) {
                        VStack(spacing: 8) {
                Image(systemName: icon)
                                .font(.system(size: 24))
                    .foregroundColor(color)
                                .frame(width: 48, height: 48)
                                .background(
                                    Circle()
                            .fill(color.opacity(0.15))
                                )
                            
                Text(title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
    
    private func openTrainingSection() -> some View {
        Button(action: {
            withAnimation(.spring()) {
                viewModel.startOpenTraining()
            }
        }) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.3))
                    )
                
                Text("Open Training")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.125, green: 0.8, blue: 0.45),
                        Color(red: 0.125, green: 0.7, blue: 0.35)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func personalizedRecommendationsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("For You")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(recommendedSessions.enumerated()), id: \.offset) { index, session in
                        SessionCard(
                            session: session,
                            lastCompleted: nil,
                            action: {
                                viewModel.showSessionDetail(session)
                            },
                            onEdit: {
                                viewModel.editSession(session)
                            },
                            onDelete: {
                                viewModel.deleteSession(session)
                            },
                            delay: Double(index) * 0.1
                        )
                    }
                }
            }
        }
    }
    
    private func featuredExercisesSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Featured")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(featuredExercises.enumerated()), id: \.offset) { index, exercise in
                        FeaturedExerciseCard(
                            exercise: exercise,
                            action: {
                                viewModel.showExerciseDetail(exercise)
                            },
                            onEdit: {
                                viewModel.editExercise(exercise)
                            },
                            onDelete: {
                                viewModel.deleteExercise(exercise)
                            },
                            delay: Double(index) * 0.1
                        )
                    }
                }
            }
        }
    }
    
    private func recentSessionsSection() -> some View {
            VStack(alignment: .leading, spacing: 16) {
            Text("Recent Sessions")
                .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(recentSessions.enumerated()), id: \.offset) { index, session in
                        SessionCard(
                            session: session,
                            lastCompleted: nil,
                            action: {
                                viewModel.showSessionDetail(session)
                            },
                            onEdit: {
                                viewModel.editSession(session)
                            },
                            onDelete: {
                                viewModel.deleteSession(session)
                            },
                            delay: Double(index) * 0.1
                        )
                    }
                }
            }
        }
    }
    
    private func activePlansSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Plans")
                .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(activePlans.enumerated()), id: \.offset) { index, plan in
                        PlanCard(
                            plan: plan,
                            progress: calculatePlanProgress(plan),
                            nextWorkout: nil,
                            action: {
                                viewModel.showPlanDetail(plan)
                            },
                            onEdit: {
                                viewModel.editPlan(plan)
                            },
                            onDelete: {
                                viewModel.deletePlan(plan)
                            },
                            delay: Double(index) * 0.1
                        )
                    }
                }
            }
        }
    }
    
    private func calculatePlanProgress(_ plan: plan) -> Double? {
        // Only calculate progress for sequential plans
        guard let isDayOfWeek = plan.isDayOfTheWeekPlan, !isDayOfWeek else {
            return nil // Day-of-week plans don't have progress
        }
        
        // For sequential plans, calculate based on days completed vs total days
        guard let sessions = plan.sessions, !sessions.isEmpty else {
            return nil
        }
        
        // Get total number of days in the plan
        let totalDays = sessions.keys.filter { $0.hasPrefix("Day ") }.count
        
        guard totalDays > 0 else {
            return nil
        }
        
        // Calculate current day based on start date
        let calendar = Calendar.current
        let today = Date()
        let startDate = plan.startDate ?? today
        
        let daysSinceStart = max(0, calendar.dateComponents([.day], from: startDate, to: today).day ?? 0)
        let currentDay = min(daysSinceStart + 1, totalDays) // Cap at total days
        
        // Progress is current day / total days
        let progress = Double(currentDay) / Double(totalDays)
        return min(1.0, max(0.0, progress)) // Clamp between 0 and 1
    }
    
    private func browseLibrarySection() -> some View {
            VStack(alignment: .leading, spacing: 16) {
            Text("Browse Library")
                .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            
            VStack(spacing: 12) {
                browseLibraryButton(title: "Browse Exercises", icon: "dumbbell.fill", color: Color(UIColor(hex: "#20D474"))) {
                    // Show modern browse view
                    showBrowseView(type: .exercises)
                }
                
                browseLibraryButton(title: "Browse Sessions", icon: "rectangle.stack.fill", color: Color(UIColor(hex: "#F2994A"))) {
                    // Show modern browse view
                    showBrowseView(type: .sessions)
                }
                
                browseLibraryButton(title: "Browse Plans", icon: "calendar", color: Color(UIColor(hex: "#3C7EF9"))) {
                    // Show modern browse view
                    showBrowseView(type: .plans)
                }
            }
        }
    }
    
    // MARK: - Empty State Sections
    
    private func emptyTodayWorkoutSection() -> some View {
            VStack(alignment: .leading, spacing: 16) {
        HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Today's Workout")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            EmptyStateCard(
                icon: "figure.strengthtraining.traditional",
                title: "No workout planned",
                subtitle: "Start a plan or create a session to see it here",
                gradient: [Color(red: 0.976, green: 0.576, blue: 0.125), Color(red: 1.0, green: 0.42, blue: 0.21)],
                action: {
                    viewModel.createNewSession()
                },
                actionTitle: "Create Session"
            )
        }
    }
    
    private func emptyRecommendationsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
        HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("For You")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            
            Spacer()
            }
            
            EmptyStateCard(
                icon: "wand.and.stars",
                title: "Start your journey",
                subtitle: "Complete workouts to get personalized recommendations",
                gradient: [Color(red: 0.125, green: 0.8, blue: 0.45), Color(red: 0.125, green: 0.7, blue: 0.35)],
                action: {
                    viewModel.startOpenTraining()
                },
                actionTitle: "Start Training"
            )
        }
    }
    
    private func emptyFeaturedSection() -> some View {
            VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Featured")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            
            Spacer()
            }
            
            EmptyStateCard(
                icon: "dumbbell.fill",
                title: "No exercises yet",
                subtitle: "Create your first movement to get started",
                gradient: [Color(UIColor(hex: "#20D474")), Color(UIColor(hex: "#1DB863"))],
                action: {
                    viewModel.createNewMovement()
                },
                actionTitle: "Create Movement"
            )
        }
    }
    
    private func emptyPlansSection() -> some View {
            VStack(alignment: .leading, spacing: 16) {
            Text("Active Plans")
                .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            
            EmptyStateCard(
                icon: "calendar.badge.plus",
                title: "No active plans",
                subtitle: "Create a workout plan to track your progress",
                gradient: [Color(UIColor(hex: "#3C7EF9")), Color(UIColor(hex: "#2E5FD9"))],
                action: {
                    viewModel.createNewPlan()
                },
                actionTitle: "Create Plan"
            )
        }
    }
    
    private func browseLibraryButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            HStack(spacing: 20) {
                // Large icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    color.opacity(0.8),
                                    color.opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: icon)
                        .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                    Text("Explore and discover")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
                // Arrow with background
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.06)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        color.opacity(0.3),
                                        color.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Helper Functions
    
    private func startWorkout(_ session: workoutSession) {
        let trackingVC = NewWorkoutTrackingViewController(session: session)
        trackingVC.modalPresentationStyle = .fullScreen
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(trackingVC, animated: true)
        }
    }
    
    private func showBrowseView(type: BrowseType) {
        let hostingController = UIHostingController(rootView: BrowseLibraryView(browseType: type, viewModel: viewModel))
        hostingController.modalPresentationStyle = .fullScreen
        hostingController.view.backgroundColor = UIColor.clear
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(hostingController, animated: true)
        }
    }
    
    private func startExerciseWorkout(_ exercise: movement) {
        var tempSession = workoutSession()
        tempSession.id = "temp_" + UUID().uuidString
        tempSession.name = exercise.movement1Name ?? "Movement"
        tempSession.movementsInSession = [exercise]
        
        let trackingVC = NewWorkoutTrackingViewController(session: tempSession)
        trackingVC.isStandaloneMovement = true
        trackingVC.modalPresentationStyle = .fullScreen
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(trackingVC, animated: true)
        }
    }
    
    
    // MARK: - Data Fetching Methods
    
    private func loadTodayWorkout() {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else { return }
        isLoadingTodayWorkout = true
        
        Task {
            // Fetch active plan logs
            let planLogsResult = await withCheckedContinuation { (continuation: CheckedContinuation<Result<GetWorkoutLogsResponse, Error>, Never>) in
                ActivityService.shared.getPlanLogs(
                    userId: userId,
                    limit: 10,
                    active: true
                ) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch planLogsResult {
            case .success(let response):
                if let planLogs = response.data?.logs, !planLogs.isEmpty {
                    // Fetch all plans to find the active ones
                    let plansResult = await withCheckedContinuation { (continuation: CheckedContinuation<Result<AWSWorkoutService.GetWorkoutResponse, Error>, Never>) in
                        AWSWorkoutService.shared.getPlans(userId: userId, limit: 100) { result in
                            continuation.resume(returning: result)
                        }
                    }
                    
                    switch plansResult {
                    case .success(let planResponse):
                        guard let planItems = planResponse.data else {
                            await MainActor.run {
                                self.isLoadingTodayWorkout = false
                            }
                            return
                        }
                        // Find today's workout from active plans
                        for planLog in planLogs {
                            if let planId = planLog.planId,
                               let planItem = planItems.first(where: { $0.planId == planId }) {
                                
                                let plan = viewModel.convertToPlan(from: planItem)
                                let todayItem = await getTodayPlanItemFromPlan(plan, userId: userId)
                                
                                if let item = todayItem {
                                    await MainActor.run {
                                        self.todayPlanItem = item
                                        self.activePlan = plan
                                        // Keep backward compatibility
                                        if case .workout(let session) = item {
                                            self.todayWorkout = session
                                        } else {
                                            self.todayWorkout = nil
                                        }
                                        self.isLoadingTodayWorkout = false
                                    }
                                    return
                                }
                            }
                        }
                    case .failure(let error):
                        print("❌ [GymTracker] Error loading plans: \(error.localizedDescription)")
                    }
                }
                await MainActor.run {
                    self.isLoadingTodayWorkout = false
                }
            case .failure(let error):
                print("❌ [GymTracker] Error loading today's workout: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingTodayWorkout = false
                }
            }
        }
    }
    
    private func getTodayPlanItemFromPlan(_ plan: plan, userId: String) async -> TodayPlanItem? {
        let calendar = Calendar.current
        let today = Date()
        
        var sessionValue: String?
        
        if let isDayOfWeek = plan.isDayOfTheWeekPlan, isDayOfWeek {
            // Day of week plan
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE"
            let dayName = dateFormatter.string(from: today)
            
            sessionValue = plan.sessions?[dayName]
        } else {
            // Sequential plan
            if let startDate = plan.startDate {
                let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
                let dayKey = "Day \(max(1, daysSinceStart + 1))"
                sessionValue = plan.sessions?[dayKey]
            } else {
                // No start date, assume Day 1
                sessionValue = plan.sessions?["Day 1"]
            }
        }
        
        guard let value = sessionValue else {
            return nil
        }
        
        // Check if it's a rest day
        let lowercased = value.lowercased()
        if lowercased.contains("rest") || lowercased == "rest session" {
            return .restDay
        }
        
        // Check if it's an activity
        if lowercased.contains("activitytype:") || lowercased.contains("activitytype") {
            if let activity = PlanActivity.fromString(value) {
                return .activity(activity)
            }
        }
        
        // Otherwise, it's a workout session ID
        // Fetch the session from AWS
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<[AWSWorkoutService.WorkoutItem], Error>, Never>) in
            AWSWorkoutService.shared.getSessions(userId: userId, limit: 100) { result in
                continuation.resume(returning: result)
            }
        }
        
        switch result {
        case .success(let items):
            if let sessionItem = items.first(where: { $0.sessionId == value }) {
                if let session = viewModel.convertToWorkoutSession(from: sessionItem, userId: userId) {
                    return .workout(session)
                }
            }
        case .failure(let error):
            print("❌ [GymTracker] Error fetching session: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // Legacy method for backward compatibility
    private func getTodayWorkoutFromPlan(_ plan: plan, userId: String) async -> workoutSession? {
        if let item = await getTodayPlanItemFromPlan(plan, userId: userId) {
            if case .workout(let session) = item {
                return session
            }
        }
        return nil
    }
    
    private func loadFeaturedContent() {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else { return }
        isLoadingFeatured = true
        
        Task {
            // Fetch user's exercises from AWS
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<AWSWorkoutService.GetWorkoutResponse, Error>, Never>) in
                AWSWorkoutService.shared.getMovements(userId: userId, limit: 20) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch result {
            case .success(let response):
                guard let items = response.data else {
                    await MainActor.run {
                        self.isLoadingFeatured = false
                    }
                    return
                }
                // Convert to movement structs
                let exercises = items.prefix(10).compactMap { item -> movement? in
                    viewModel.convertToMovement(from: item)
                }
                
                await MainActor.run {
                    self.featuredExercises = exercises
                    self.isLoadingFeatured = false
                }
            case .failure(let error):
                print("❌ [GymTracker] Error loading featured exercises: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingFeatured = false
                }
            }
        }
    }
    
    private func loadPersonalizedContent() {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else { return }
        isLoadingRecommended = true
        
        Task {
            // Fetch recent session logs to get recommendations
            let logsResult = await withCheckedContinuation { (continuation: CheckedContinuation<Result<GetWorkoutLogsResponse, Error>, Never>) in
                ActivityService.shared.getSessionLogs(
                    userId: userId,
                    limit: 10
                ) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch logsResult {
            case .success(let response):
                if let logs = response.data?.logs {
                    // Get unique session IDs from logs
                    let sessionIds = Array(Set(logs.compactMap { $0.originalSessionId }))
                    
                    // Fetch sessions from AWS
                    let sessionsResult = await withCheckedContinuation { (continuation: CheckedContinuation<Result<AWSWorkoutService.GetWorkoutResponse, Error>, Never>) in
                        AWSWorkoutService.shared.getSessions(userId: userId, limit: 100) { result in
                            continuation.resume(returning: result)
                        }
                    }
                    
                    switch sessionsResult {
                    case .success(let sessionResponse):
                        guard let sessionItems = sessionResponse.data else {
                            await MainActor.run {
                                self.isLoadingRecommended = false
                            }
                            return
                        }
                        var sessions: [workoutSession] = []
                        for sessionId in sessionIds {
                            if let sessionItem = sessionItems.first(where: { $0.sessionId == sessionId }) {
                                if let session = viewModel.convertToWorkoutSession(from: sessionItem, userId: userId) {
                                    sessions.append(session)
                                }
                            }
                        }
                        
                        await MainActor.run {
                            self.recommendedSessions = Array(sessions.prefix(5))
                            self.recentSessions = Array(sessions.prefix(5))
                            self.isLoadingRecommended = false
                        }
                    case .failure(let error):
                        print("❌ [GymTracker] Error fetching sessions: \(error.localizedDescription)")
                        await MainActor.run {
                            self.isLoadingRecommended = false
                        }
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingRecommended = false
                    }
                }
            case .failure(let error):
                print("❌ [GymTracker] Error loading personalized content: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingRecommended = false
                }
            }
            
            // Also load active plans
            let planLogsResult = await withCheckedContinuation { (continuation: CheckedContinuation<Result<GetWorkoutLogsResponse, Error>, Never>) in
                ActivityService.shared.getPlanLogs(
                    userId: userId,
                    limit: 10,
                    active: true
                ) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch planLogsResult {
            case .success(let response):
                if let planLogs = response.data?.logs {
                    let planIds = Array(Set(planLogs.compactMap { $0.planId }))
                    
                    // Fetch plans from AWS
                    let plansResult = await withCheckedContinuation { (continuation: CheckedContinuation<Result<AWSWorkoutService.GetWorkoutResponse, Error>, Never>) in
                        AWSWorkoutService.shared.getPlans(userId: userId, limit: 100) { result in
                            continuation.resume(returning: result)
                        }
                    }
                    
                    switch plansResult {
                    case .success(let planResponse):
                        guard let planItems = planResponse.data else {
                            return
                        }
                        var plans: [plan] = []
                        for planId in planIds {
                            if let planItem = planItems.first(where: { $0.planId == planId }) {
                                plans.append(viewModel.convertToPlan(from: planItem))
                            }
                        }
                        
                        await MainActor.run {
                            self.activePlans = plans
                        }
                    case .failure(let error):
                        print("❌ [GymTracker] Error fetching plans: \(error.localizedDescription)")
                    }
                }
            case .failure(let error):
                print("❌ [GymTracker] Error loading active plans: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Conversion Helpers (in GymTrackerView - delegate to viewModel)
    
    private func convertToMovement(from item: AWSWorkoutService.WorkoutItem) -> movement {
        return viewModel.convertToMovement(from: item)
    }
    
    private func convertToWorkoutSession(from item: AWSWorkoutService.WorkoutItem, userId: String) -> workoutSession? {
        return viewModel.convertToWorkoutSession(from: item, userId: userId)
    }
    
    private func convertToPlan(from item: AWSWorkoutService.WorkoutItem) -> plan {
        return viewModel.convertToPlan(from: item)
    }
    
    private func loadWorkoutStats() async {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("⚠️ [GymTracker] No user ID available for loading workout stats")
            return
        }
        
        print("📊 [GymTracker] Loading workout stats for user: \(userId)")
        
        // Fetch all session logs from the last 30 days to calculate stats
        var allSessionLogs: [WorkoutLog] = []
        var nextToken: String? = nil
        
        // Fetch all pages
        repeat {
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<GetWorkoutLogsResponse, Error>, Never>) in
                ActivityService.shared.getSessionLogs(
                    userId: userId,
                    limit: 100,
                    nextToken: nextToken
                ) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch result {
            case .success(let response):
                if let logs = response.data?.logs {
                    allSessionLogs.append(contentsOf: logs)
                    nextToken = response.data?.nextToken
                    
                    if !(response.data?.hasMore ?? false) {
                        break
                    }
                } else {
                    break
                }
            case .failure(let error):
                print("❌ [GymTracker] Error fetching session logs: \(error.localizedDescription)")
                break
            }
        } while nextToken != nil
        
        print("✅ [GymTracker] Fetched \(allSessionLogs.count) session logs")
        
        // Filter completed sessions
        let completedSessions = allSessionLogs.filter { $0.completed == true }
        
        // Calculate weekly workouts (last 7 days)
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        let weeklyWorkouts = completedSessions.filter { log in
            if let createdAt = ISO8601DateFormatter().date(from: log.createdAt) {
                return createdAt >= sevenDaysAgo
            }
            return false
        }
        
        // Calculate streak (consecutive days with completed sessions)
        let uniqueDays = Set(completedSessions.compactMap { log -> Date? in
            guard let date = ISO8601DateFormatter().date(from: log.createdAt) else {
                return nil
            }
            return calendar.startOfDay(for: date)
        })
        
        let sortedDays = Array(uniqueDays).sorted(by: >)
        var streak = 0
        var expectedDate = calendar.startOfDay(for: now)
        
        // Check if today has a session
        let hasToday = sortedDays.contains(where: { calendar.isDate($0, inSameDayAs: now) })
        
        // If no session today, check from yesterday
        if !hasToday {
            expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
        }
        
        // Count consecutive days backwards
        for day in sortedDays {
            if calendar.isDate(day, inSameDayAs: expectedDate) {
                streak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            } else {
                // Gap found, break
                break
            }
        }
        
        // Calculate monthly exercises (total movements from sessions this month)
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let monthlySessions = completedSessions.filter { log in
            if let createdAt = ISO8601DateFormatter().date(from: log.createdAt) {
                return createdAt >= firstOfMonth
            }
            return false
        }
        
        // Count total exercises (movements) from monthly sessions
        // Each session log may have multiple movements, we'll estimate based on totalSets if available
        // Or count each completed session as contributing to exercises
        let monthlyExercises = monthlySessions.reduce(0) { total, log in
            // If we have totalSets, use that as a proxy for exercises
            // Otherwise, count each session as 1 exercise
            return total + (log.totalSets ?? 1)
        }
        
        await MainActor.run {
            self.totalWorkoutsThisWeek = weeklyWorkouts.count
            self.currentStreak = streak
            self.totalExercisesThisMonth = monthlyExercises
            
            print("📊 [GymTracker] Stats loaded - Weekly: \(weeklyWorkouts.count), Streak: \(streak), Monthly Exercises: \(monthlyExercises)")
        }
    }
    
}

// MARK: - Gym Tracking Engine Extension
// Note: GymTrackingEngine is now defined in iOS/Do/Features/Track/Engines/GymTrackingEngine.swift
// This extension adds convenience methods specific to ModernGymTrackerViewController

extension GymTrackingEngine {
    func setCurrentUser() {
        // Use CurrentUserService instead of Parse
        if CurrentUserService.shared.user.userID != nil {
            // User already loaded
        } else {
            // If user not loaded, try to load from UserIDHelper
            if let userId = UserIDHelper.shared.getCurrentUserID() {
                Task {
                    // Try to fetch user profile from AWS
                    if let userProfile = try? await UserProfileService.shared.fetchUserProfile(userId: userId) {
                        await MainActor.run {
                            // User profile loaded
                        }
                    } else {
                        // Fallback to CurrentUserService
                        await MainActor.run {
                            // Use CurrentUserService
                        }
                    }
                }
            }
        }
    }
    
    func startOpenTraining() {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("❌ [OpenTraining] Cannot start - no user ID")
            return
        }
        
        print("🏋️ [OpenTraining] Starting open training for user: \(userId)")
        
        // Create session using AWS
        AWSWorkoutService.shared.createSession(
            userId: userId,
            name: "Open Training",
            description: "Freestyle workout session",
            movements: [], // Empty for open training
            difficulty: nil,
            equipmentNeeded: false,
            tags: ["open_training"]
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let sessionItem):
                print("✅ [OpenTraining] Session created successfully")
                print("📋 [OpenTraining] Session ID: \(sessionItem.sessionId)")
                
                // Create a workout session model
                var session = workoutSession()
                session.name = "Open Training"
                session.id = sessionItem.sessionId ?? UUID().uuidString
                session.description = "Freestyle workout session"
                
                // Start tracking with the new engine
                self.startWorkout(session: session)
                
                // Present the workout tracking view controller
                DispatchQueue.main.async {
                    let trackingVC = NewWorkoutTrackingViewController(session: session, isOpenTraining: true)
                    
                    // Find the top-most view controller to present from
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        var topVC = rootVC
                        while let presentedVC = topVC.presentedViewController {
                            topVC = presentedVC
                        }
                        trackingVC.modalPresentationStyle = .fullScreen
                        topVC.present(trackingVC, animated: true) {
                            print("✅ [OpenTraining] View presented")
                        }
                    } else {
                        print("❌ [OpenTraining] Could not find top view controller")
                    }
                }
                
            case .failure(let error):
                print("❌ [OpenTraining] Failed to create session: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    // Show error to user
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to start open training. Please try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        var topVC = rootVC
                        while let presentedVC = topVC.presentedViewController {
                            topVC = presentedVC
                        }
                        topVC.present(alert, animated: true)
                    }
                }
            }
        }
    }
}

// MARK: - Character Views

struct WorkoutCharacterView: View {
    let workout: workoutSession
    @State private var bounceOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Outer glow effect
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            characterType.colors.first?.opacity(glowOpacity) ?? Color.clear,
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
                .scaleEffect(pulseScale)
            
            // Background circle with gradient
            Circle()
                .fill(characterBackgroundGradient)
                .frame(width: 80, height: 80)
                .shadow(color: characterType.colors.first?.opacity(0.5) ?? Color.clear, radius: 10, x: 0, y: 5)
            
            // Character illustration
            characterIllustration
                .offset(y: bounceOffset)
        }
        .onAppear {
            startBounceAnimation()
            startPulseAnimation()
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
            glowOpacity = 0.6
        }
    }
    
    private var characterIllustration: some View {
        Group {
            switch characterType {
            case .chest:
                ChestCharacter()
            case .legs:
                LegsCharacter()
            case .arms:
                ArmsCharacter()
            case .back:
                BackCharacter()
            case .shoulders:
                ShouldersCharacter()
            case .fullBody:
                FullBodyCharacter()
            case .cardio:
                CardioCharacter()
            case .strength:
                StrengthCharacter()
            case .default:
                DefaultCharacter()
            }
        }
    }
    
    private var characterType: WorkoutCharacterType {
        if let movements = workout.movementsInSession, !movements.isEmpty {
            if let category = movements.first?.category {
                return mapCategoryToCharacterType(category)
            }
        }
        return .default
    }
    
    private func mapCategoryToCharacterType(_ category: String?) -> WorkoutCharacterType {
        guard let category = category?.lowercased() else { return .default }
        if category.contains("chest") { return .chest }
        if category.contains("leg") { return .legs }
        if category.contains("arm") || category.contains("bicep") || category.contains("tricep") { return .arms }
        if category.contains("back") { return .back }
        if category.contains("shoulder") { return .shoulders }
        if category.contains("cardio") { return .cardio }
        if category.contains("strength") { return .strength }
        return .fullBody
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

struct ExerciseCharacterView: View {
    let exercise: movement
    @State private var bounceOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Outer glow effect
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            characterType.colors.first?.opacity(glowOpacity) ?? Color.clear,
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
                .scaleEffect(pulseScale)
            
            // Background circle with gradient
            Circle()
                .fill(characterBackgroundGradient)
                .frame(width: 80, height: 80)
                .shadow(color: characterType.colors.first?.opacity(0.5) ?? Color.clear, radius: 10, x: 0, y: 5)
            
            // Character illustration
            characterIllustration
                .offset(y: bounceOffset)
        }
        .onAppear {
            startBounceAnimation()
            startPulseAnimation()
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
            glowOpacity = 0.6
        }
    }
    
    private var characterIllustration: some View {
        Group {
            switch characterType {
            case .chest:
                ChestCharacter()
            case .legs:
                LegsCharacter()
            case .arms:
                ArmsCharacter()
            case .back:
                BackCharacter()
            case .shoulders:
                ShouldersCharacter()
            case .fullBody:
                FullBodyCharacter()
            case .cardio:
                CardioCharacter()
            case .strength:
                StrengthCharacter()
            case .default:
                DefaultCharacter()
            }
        }
    }
    
    private var characterType: WorkoutCharacterType {
        if let category = exercise.category {
            return mapCategoryToCharacterType(category)
        }
        return .default
    }
    
    private func mapCategoryToCharacterType(_ category: String?) -> WorkoutCharacterType {
        guard let category = category?.lowercased() else { return .default }
        if category.contains("chest") { return .chest }
        if category.contains("leg") { return .legs }
        if category.contains("arm") || category.contains("bicep") || category.contains("tricep") { return .arms }
        if category.contains("back") { return .back }
        if category.contains("shoulder") { return .shoulders }
        if category.contains("cardio") { return .cardio }
        if category.contains("strength") { return .strength }
        return .fullBody
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

enum WorkoutCharacterType {
    case chest
    case legs
    case arms
    case back
    case shoulders
    case fullBody
    case cardio
    case strength
    case `default`
    
    var colors: [Color] {
        switch self {
        case .chest:
            return [Color(hex: "FF6B6B").opacity(0.4), Color(hex: "FF8E53").opacity(0.6)]
        case .legs:
            return [Color(hex: "4ECDC4").opacity(0.4), Color(hex: "44A08D").opacity(0.6)]
        case .arms:
            return [Color(hex: "F7931F").opacity(0.4), Color(hex: "FFB84D").opacity(0.6)]
        case .back:
            return [Color(hex: "9B87F5").opacity(0.4), Color(hex: "6B5CE6").opacity(0.6)]
        case .shoulders:
            return [Color(hex: "87CEEB").opacity(0.4), Color(hex: "5F9EA0").opacity(0.6)]
        case .fullBody:
            return [Color(hex: "FFD700").opacity(0.4), Color(hex: "FFA500").opacity(0.6)]
        case .cardio:
            return [Color(hex: "FF6B6B").opacity(0.4), Color(hex: "FF8E53").opacity(0.6)]
        case .strength:
            return [Color(hex: "A8E6CF").opacity(0.4), Color(hex: "7FCDBB").opacity(0.6)]
        case .default:
            return [Color(hex: "B19CD9").opacity(0.4), Color(hex: "8B7FA8").opacity(0.6)]
        }
    }
}

// MARK: - Character Illustrations

struct ChestCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
            }
            
            // Determined mouth
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 12, height: 2)
                .offset(y: 10)
            
            // Dumbbell icon (chest emphasis)
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "FF6B6B"))
                .offset(y: 25)
        }
    }
}

struct LegsCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
            }
            
            // Mouth
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 12, height: 2)
                .offset(y: 10)
            
            // Squatting figure (legs emphasis)
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "4ECDC4"))
                .offset(y: 25)
        }
    }
}

struct ArmsCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
            }
            
            // Mouth
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 12, height: 2)
                .offset(y: 10)
            
            // Bicep curl icon
            Image(systemName: "figure.strengthtraining.functional.traditional")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "F7931F"))
                .offset(y: 25)
        }
    }
}

struct BackCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
            }
            
            // Mouth
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 12, height: 2)
                .offset(y: 10)
            
            // Rowing motion icon
            Image(systemName: "figure.rower")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "9B87F5"))
                .offset(y: 25)
        }
    }
}

struct ShouldersCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
            }
            
            // Mouth
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 12, height: 2)
                .offset(y: 10)
            
            // Overhead press icon
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "87CEEB"))
                .offset(y: 25)
        }
    }
}

struct FullBodyCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
            }
            
            // Mouth
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 12, height: 2)
                .offset(y: 10)
            
            // Full body icon
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "FFD700"))
                .offset(y: 25)
        }
    }
}

struct CardioCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
            }
            
            // Mouth
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 12, height: 2)
                .offset(y: 10)
            
            // Running figure
            Image(systemName: "figure.run")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "FF6B6B"))
                .offset(y: 25)
        }
    }
}

struct StrengthCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
            }
            
            // Mouth
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 12, height: 2)
                .offset(y: 10)
            
            // Powerlifting icon
            Image(systemName: "bolt.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "A8E6CF"))
                .offset(y: 25)
        }
    }
}

struct DefaultCharacter: View {
    var body: some View {
        ZStack {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            // Eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 9, height: 9)
            }
            
            // Neutral mouth
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 12, height: 2)
                .offset(y: 10)
            
            // Generic gym icon
            Image(systemName: "dumbbell")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "B19CD9"))
                .offset(y: 25)
        }
    }
}

// MARK: - Card Components

struct TodayPlanItemCard: View {
    let item: TodayPlanItem
    let planName: String?
    let action: () -> Void
    @State private var cardOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.95
    var delay: Double = 0
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            HStack(spacing: 20) {
                // Icon/Illustration
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: iconGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: item.icon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    if let planName = planName {
                        Text(planName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                    
                    Text(item.displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                    
                    // Subtitle based on type
                    Group {
                        switch item {
                        case .workout(let session):
                            HStack(spacing: 16) {
                                if let movements = session.movementsInSession {
                                    Label("\(movements.count)", systemImage: "dumbbell.fill")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                if let difficulty = session.difficulty {
                                    Text(difficulty.capitalized)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        case .activity(let activity):
                            Text(activity.subtitle)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        case .restDay:
                            Text("Recovery and rest")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    // Action button
                    HStack {
                        Text(actionButtonText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: actionButtonIcon)
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(24)
            .frame(width: 360, height: 200)
            .background(
                ZStack {
                    // Dark base background
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.08, blue: 0.12),
                                    Color(red: 0.12, green: 0.12, blue: 0.18),
                                    Color(red: 0.1, green: 0.1, blue: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Subtle accent gradient
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: accentGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Radial highlight for icon area
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: radialGradient),
                                center: .leading,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: borderGradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(delay)) {
                cardOpacity = 1
                cardScale = 1
            }
        }
    }
    
    private var iconGradient: [Color] {
        switch item {
        case .workout:
            return [
                Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.8),
                Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.8)
            ]
        case .activity(let activity):
            let activityType = activity.activityType.lowercased()
            switch activityType {
            case "running", "run":
                return [Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.8), Color(red: 0.1, green: 0.4, blue: 0.9).opacity(0.8)]
            case "biking", "cycling", "bike":
                return [Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.8), Color(red: 0.1, green: 0.6, blue: 0.3).opacity(0.8)]
            case "walking", "walk":
                return [Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.8), Color(red: 0.5, green: 0.3, blue: 0.8).opacity(0.8)]
            case "hiking", "hike":
                return [Color(red: 0.8, green: 0.5, blue: 0.2).opacity(0.8), Color(red: 0.7, green: 0.4, blue: 0.1).opacity(0.8)]
            case "swimming", "swim":
                return [Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.8), Color(red: 0.1, green: 0.5, blue: 0.8).opacity(0.8)]
            case "sports", "sport":
                return [Color(red: 1.0, green: 0.4, blue: 0.4).opacity(0.8), Color(red: 0.9, green: 0.3, blue: 0.3).opacity(0.8)]
        default:
                return [Color.white.opacity(0.3), Color.white.opacity(0.2)]
            }
        case .restDay:
            return [Color(red: 0.4, green: 0.4, blue: 0.6).opacity(0.8), Color(red: 0.3, green: 0.3, blue: 0.5).opacity(0.8)]
        }
    }
    
    private var accentGradient: [Color] {
        switch item {
        case .workout:
            return [
                Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.15),
                Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.1)
            ]
        case .activity(let activity):
            let activityType = activity.activityType.lowercased()
            switch activityType {
            case "running", "run":
                return [Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.15), Color(red: 0.1, green: 0.4, blue: 0.9).opacity(0.1)]
            case "biking", "cycling", "bike":
                return [Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.15), Color(red: 0.1, green: 0.6, blue: 0.3).opacity(0.1)]
            case "walking", "walk":
                return [Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.15), Color(red: 0.5, green: 0.3, blue: 0.8).opacity(0.1)]
            case "hiking", "hike":
                return [Color(red: 0.8, green: 0.5, blue: 0.2).opacity(0.15), Color(red: 0.7, green: 0.4, blue: 0.1).opacity(0.1)]
            case "swimming", "swim":
                return [Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.15), Color(red: 0.1, green: 0.5, blue: 0.8).opacity(0.1)]
            case "sports", "sport":
                return [Color(red: 1.0, green: 0.4, blue: 0.4).opacity(0.15), Color(red: 0.9, green: 0.3, blue: 0.3).opacity(0.1)]
            default:
                return [Color.white.opacity(0.1), Color.white.opacity(0.05)]
            }
        case .restDay:
            return [Color(red: 0.4, green: 0.4, blue: 0.6).opacity(0.15), Color(red: 0.3, green: 0.3, blue: 0.5).opacity(0.1)]
        }
    }
    
    private var radialGradient: [Color] {
        switch item {
        case .workout:
            return [Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.2), Color.clear]
        case .activity(let activity):
            let activityType = activity.activityType.lowercased()
            switch activityType {
            case "running", "run":
                return [Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.2), Color.clear]
            case "biking", "cycling", "bike":
                return [Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.2), Color.clear]
            case "walking", "walk":
                return [Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.2), Color.clear]
            case "hiking", "hike":
                return [Color(red: 0.8, green: 0.5, blue: 0.2).opacity(0.2), Color.clear]
            case "swimming", "swim":
                return [Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2), Color.clear]
            case "sports", "sport":
                return [Color(red: 1.0, green: 0.4, blue: 0.4).opacity(0.2), Color.clear]
            default:
                return [Color.white.opacity(0.1), Color.clear]
            }
        case .restDay:
            return [Color(red: 0.4, green: 0.4, blue: 0.6).opacity(0.2), Color.clear]
        }
    }
    
    private var borderGradient: [Color] {
        switch item {
        case .workout:
            return [Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.3), Color.white.opacity(0.05)]
        case .activity(let activity):
            let activityType = activity.activityType.lowercased()
            switch activityType {
            case "running", "run":
                return [Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.3), Color.white.opacity(0.05)]
            case "biking", "cycling", "bike":
                return [Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.3), Color.white.opacity(0.05)]
            case "walking", "walk":
                return [Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.3), Color.white.opacity(0.05)]
            case "hiking", "hike":
                return [Color(red: 0.8, green: 0.5, blue: 0.2).opacity(0.3), Color.white.opacity(0.05)]
            case "swimming", "swim":
                return [Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.3), Color.white.opacity(0.05)]
            case "sports", "sport":
                return [Color(red: 1.0, green: 0.4, blue: 0.4).opacity(0.3), Color.white.opacity(0.05)]
            default:
                return [Color.white.opacity(0.2), Color.white.opacity(0.05)]
            }
        case .restDay:
            return [Color(red: 0.4, green: 0.4, blue: 0.6).opacity(0.3), Color.white.opacity(0.05)]
        }
    }
    
    private var actionButtonText: String {
        switch item {
        case .workout:
            return "Start Workout"
        case .activity:
            return "Start Activity"
        case .restDay:
            return "Rest Day"
        }
    }
    
    private var actionButtonIcon: String {
        switch item {
        case .workout:
            return "arrow.right.circle.fill"
        case .activity:
            return "play.circle.fill"
        case .restDay:
            return "moon.zzz.fill"
        }
    }
}

struct TodayWorkoutCard: View {
    let workout: workoutSession
    let planName: String?
    let action: () -> Void
    @State private var cardOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.95
    var delay: Double = 0
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            HStack(spacing: 20) {
                // Character illustration
                WorkoutCharacterView(workout: workout)
                    .frame(width: 80, height: 80)
                
                VStack(alignment: .leading, spacing: 12) {
                    if let planName = planName {
                        Text(planName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                    
                    Text(workout.name ?? "Workout")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 16) {
                        if let movements = workout.movementsInSession {
                            Label("\(movements.count)", systemImage: "dumbbell.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if let difficulty = workout.difficulty {
                            Text(difficulty.capitalized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    HStack {
                        Text("Start Workout")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(24)
            .frame(width: 360, height: 200)
            .background(
                ZStack {
                    // Dark base background
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.08, blue: 0.12),
                                    Color(red: 0.12, green: 0.12, blue: 0.18),
                                    Color(red: 0.1, green: 0.1, blue: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Subtle orange accent gradient
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.15),
                                    Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Radial highlight for illustration area
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.2),
                                    Color.clear
                                ]),
                                center: .leading,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.3),
                                Color.white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(delay)) {
                cardOpacity = 1
                cardScale = 1
            }
        }
    }
    
    private var characterBackgroundGradient: LinearGradient {
        // Dark background with subtle orange accent
        return LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.12, green: 0.12, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func getCharacterType(for workout: workoutSession) -> WorkoutCharacterType {
        // Determine character type based on workout content
        if let movements = workout.movementsInSession, !movements.isEmpty {
            if let category = movements.first?.category {
                return mapCategoryToCharacterType(category)
            }
        }
        return .default
    }
    
    private func mapCategoryToCharacterType(_ category: String?) -> WorkoutCharacterType {
        guard let category = category?.lowercased() else { return .default }
        if category.contains("chest") { return .chest }
        if category.contains("leg") { return .legs }
        if category.contains("arm") || category.contains("bicep") || category.contains("tricep") { return .arms }
        if category.contains("back") { return .back }
        if category.contains("shoulder") { return .shoulders }
        if category.contains("cardio") { return .cardio }
        if category.contains("strength") { return .strength }
        return .fullBody
    }
}

struct FeaturedExerciseCard: View {
    let exercise: movement
    let action: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    @State private var cardOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.95
    var delay: Double = 0
    
    init(exercise: movement, action: @escaping () -> Void, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil, delay: Double = 0) {
        self.exercise = exercise
        self.action = action
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.delay = delay
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            HStack(spacing: 20) {
                // Character illustration - made bigger
                ZStack {
                    // Background circle for illustration
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.3),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    ExerciseCharacterView(exercise: exercise)
                        .frame(width: 100, height: 100)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    // Category badge
                    if let category = exercise.category {
                        Text(category)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                    
                    Spacer(minLength: 4)
                    
                    // Exercise name with shadow for visibility - ensure it always fits
                    Text(exercise.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .shadow(color: Color.black.opacity(0.6), radius: 6, x: 0, y: 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer(minLength: 4)
                    
                    // Additional info row
                    HStack(spacing: 16) {
                        // Sets info
                        if let sets = exercise.firstSectionSets, !sets.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "list.number")
                                    .font(.system(size: 11))
                                Text("\(sets.count) sets")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Difficulty if available
                        if let difficulty = exercise.difficulty {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 11))
                                Text(difficulty.capitalized)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            .padding(24)
            .frame(width: 360, height: 220)
            .background(
                ZStack {
                    // Dark base background
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.08, blue: 0.12),
                                    Color(red: 0.12, green: 0.12, blue: 0.18),
                                    Color(red: 0.1, green: 0.1, blue: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Subtle colorful accent gradient
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.15),
                                    Color(red: 0.1, green: 0.6, blue: 0.3).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Radial highlight for illustration area - enhanced
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.25),
                                    Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.1),
                                    Color.clear
                                ]),
                                center: .leading,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.3),
                                Color.white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.6), radius: 25, x: 0, y: 12)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(delay)) {
                cardOpacity = 1
                cardScale = 1
            }
        }
    }
    
    private var characterBackgroundGradient: LinearGradient {
        // Dark background with subtle green accent
        return LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.12, green: 0.12, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func mapCategoryToCharacterType(_ category: String?) -> WorkoutCharacterType {
        guard let category = category?.lowercased() else { return .default }
        if category.contains("chest") { return .chest }
        if category.contains("leg") { return .legs }
        if category.contains("arm") || category.contains("bicep") || category.contains("tricep") { return .arms }
        if category.contains("back") { return .back }
        if category.contains("shoulder") { return .shoulders }
        if category.contains("cardio") { return .cardio }
        if category.contains("strength") { return .strength }
        return .default
    }
}

struct SessionCard: View {
    let session: workoutSession
    let lastCompleted: Date?
    let action: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    @State private var cardOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.95
    var delay: Double = 0
    
    init(session: workoutSession, lastCompleted: Date? = nil, action: @escaping () -> Void, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil, delay: Double = 0) {
        self.session = session
        self.lastCompleted = lastCompleted
        self.action = action
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.delay = delay
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            HStack(spacing: 20) {
                // Character illustration - made bigger
                ZStack {
                    // Background circle for illustration
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.6, blue: 0.3).opacity(0.3),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    WorkoutCharacterView(workout: session)
                        .frame(width: 100, height: 100)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    // Session name with shadow for visibility - ensure it always fits
                    Text(session.name ?? "Workout Session")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .shadow(color: Color.black.opacity(0.6), radius: 6, x: 0, y: 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer(minLength: 4)
                    
                    // Info row
                    VStack(alignment: .leading, spacing: 6) {
                        // Movement count
                        if let movements = session.movementsInSession {
                            HStack(spacing: 4) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 11))
                                Text("\(movements.count) movement\(movements.count == 1 ? "" : "s")")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Difficulty if available
                        if let difficulty = session.difficulty {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 11))
                                Text(difficulty.capitalized)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Last completed
                        if let lastCompleted = lastCompleted {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 11))
                                Text("Last: \(formatDate(lastCompleted))")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    // Quick start button
                    HStack {
                        Text("Start Session")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(24)
            .frame(width: 340, height: 200)
            .background(
                ZStack {
                    // Dark base background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.08, blue: 0.12),
                                    Color(red: 0.12, green: 0.12, blue: 0.18),
                                    Color(red: 0.1, green: 0.1, blue: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Subtle orange accent gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.6, blue: 0.3).opacity(0.15),
                                    Color(red: 0.9, green: 0.4, blue: 0.2).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Radial highlight for illustration area - enhanced
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.6, blue: 0.3).opacity(0.25),
                                    Color(red: 1.0, green: 0.6, blue: 0.3).opacity(0.1),
                                    Color.clear
                                ]),
                                center: .leading,
                                startRadius: 0,
                                endRadius: 130
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.6, blue: 0.3).opacity(0.3),
                                Color.white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: 10)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(delay)) {
                cardOpacity = 1
                cardScale = 1
            }
        }
    }
    
    private var characterBackgroundGradient: LinearGradient {
        // Dark background with subtle orange accent
        return LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.12, green: 0.12, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func getCharacterType(for session: workoutSession) -> WorkoutCharacterType {
        if let movements = session.movementsInSession, !movements.isEmpty {
            if let category = movements.first?.category {
                return mapCategoryToCharacterType(category)
            }
        }
        return .default
    }
    
    private func mapCategoryToCharacterType(_ category: String?) -> WorkoutCharacterType {
        guard let category = category?.lowercased() else { return .default }
        if category.contains("chest") { return .chest }
        if category.contains("leg") { return .legs }
        if category.contains("arm") || category.contains("bicep") || category.contains("tricep") { return .arms }
        if category.contains("back") { return .back }
        if category.contains("shoulder") { return .shoulders }
        if category.contains("cardio") { return .cardio }
        if category.contains("strength") { return .strength }
        return .fullBody
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct PlanCard: View {
    let plan: plan
    let progress: Double? // Optional - only for sequential plans
    let nextWorkout: workoutSession?
    let action: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    @State private var cardOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.95
    @State private var animatedProgress: Double = 0
    var delay: Double = 0
    
    // Computed properties
    private var isDayOfWeekPlan: Bool {
        plan.isDayOfTheWeekPlan ?? false
    }
    
    private var planTypeText: String {
        isDayOfWeekPlan ? "Weekly Plan" : "Sequential Plan"
    }
    
    private var sessionCount: Int {
        plan.sessions?.count ?? 0
    }
    
    init(plan: plan, progress: Double? = nil, nextWorkout: workoutSession? = nil, action: @escaping () -> Void, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil, delay: Double = 0) {
        self.plan = plan
        self.progress = progress
        self.nextWorkout = nextWorkout
        self.action = action
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.delay = delay
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    // Plan name with shadow for visibility
                    Text(plan.name ?? "Workout Plan")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                    
                    Spacer()
                    
                    // Active badge
                    Text("Active")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.3))
                        )
                }
                
                // Progress or Plan Info (only show progress for sequential plans)
                if let progressValue = progress, !isDayOfWeekPlan {
                    // Progress bar for sequential plans
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Progress")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                            
                            Text("\(Int(animatedProgress * 100))%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.976, green: 0.576, blue: 0.125),
                                                Color(red: 1.0, green: 0.42, blue: 0.21),
                                                Color(red: 0.9, green: 0.3, blue: 0.3)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * max(0, min(1, animatedProgress)), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                } else {
                    // Plan info for day-of-week plans or plans without progress
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: isDayOfWeekPlan ? "calendar.badge.clock" : "list.number")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(planTypeText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if sessionCount > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.stack.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("\(sessionCount) session\(sessionCount == 1 ? "" : "s")")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                
                // Plan details
                HStack {
                    if let difficulty = plan.difficulty {
                        Label(difficulty.capitalized, systemImage: "chart.bar.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    if let duration = plan.duration {
                        Label(duration, systemImage: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(20)
            .frame(width: 280, height: 180)
            .background(
                ZStack {
                    // Dark base background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.08, blue: 0.12),
                                    Color(red: 0.12, green: 0.12, blue: 0.18),
                                    Color(red: 0.1, green: 0.1, blue: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Subtle blue accent gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.24, green: 0.49, blue: 0.98).opacity(0.15),
                                    Color(red: 0.18, green: 0.37, blue: 0.85).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Radial highlight for visual interest
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.24, green: 0.49, blue: 0.98).opacity(0.2),
                                    Color.clear
                                ]),
                                center: .topTrailing,
                                startRadius: 0,
                                endRadius: 120
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.24, green: 0.49, blue: 0.98).opacity(0.3),
                                Color.white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.5), radius: 15, x: 0, y: 8)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(delay)) {
                cardOpacity = 1
                cardScale = 1
            }
            if let progressValue = progress {
                withAnimation(.linear(duration: 0.3).delay(delay)) {
                    animatedProgress = progressValue
                }
            }
        }
    }
}

// MARK: - Placeholder View Controllers
// These classes should be replaced with actual implementations

class NewMovementViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    private func setupView() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0) // Updated to match the app's dark theme
        
        let titleLabel = UILabel()
        titleLabel.text = "Create New Movement"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Updated to use a consistent close button style
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(titleLabel)
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    @objc private func closeTapped() {
        // Added animation for smoother dismissal
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0
        }) { _ in
            self.dismiss(animated: false)
        }
    }
}

class NewSessionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    private func setupView() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0) // Updated to match the app's dark theme
        
        let titleLabel = UILabel()
        titleLabel.text = "Create New Session"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Updated to use a consistent close button style
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(titleLabel)
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    @objc private func closeTapped() {
        // Added animation for smoother dismissal
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0
        }) { _ in
            self.dismiss(animated: false)
        }
    }
}

// MARK: - Empty State Card Component

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    let action: () -> Void
    let actionTitle: String
    @State private var cardOpacity: Double = 0
    @State private var iconRotation: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: gradient.map { $0.opacity(0.3) }),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(iconRotation))
            }
            .padding(.top, 20)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button(action: {
                withAnimation(.spring()) {
                    action()
                }
            }) {
                HStack {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: gradient),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: gradient.map { $0.opacity(0.3) }),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .opacity(cardOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                cardOpacity = 1
            }
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                iconRotation = 360
            }
        }
    }
}

// MARK: - Modern Create Flows (SwiftUI)

struct ModernCreateMovementView: View {
    @Environment(\.dismiss) var dismiss
    @State private var movementName: String = ""
    @State private var isSingle: Bool = true
    @State private var isTimed: Bool = false
    @State private var category: String = "general"
    @State private var difficulty: String = "beginner"
    @State private var equipmentNeeded: Bool = false
    @State private var description: String = ""
    @State private var isCreating: Bool = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.08, green: 0.08, blue: 0.12), location: 0.5),
                    .init(color: Color(red: 0.1, green: 0.1, blue: 0.15), location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header with illustration
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(UIColor(hex: "#20D474")).opacity(0.3),
                                            Color(UIColor(hex: "#1DB863")).opacity(0.2)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(Color(UIColor(hex: "#20D474")))
                        }
                        .padding(.top, 20)
                        
                        Text("Create Movement")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Add a new exercise to your library")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // Form fields
                    VStack(spacing: 24) {
                        WorkoutTextField(
                            title: "Movement Name",
                            placeholder: "e.g., Bench Press",
                            text: $movementName,
                            icon: "textformat"
                        )
                        
                        WorkoutSegmentedControl(
                            title: "Type",
                            options: ["Single", "Compound"],
                            selectedIndex: Binding(
                                get: { isSingle ? 0 : 1 },
                                set: { isSingle = $0 == 0 }
                            ),
                            icon: "square.stack.3d.up"
                        )
                        
                        WorkoutSegmentedControl(
                            title: "Tracking Mode",
                            options: ["Reps", "Time"],
                            selectedIndex: Binding(
                                get: { isTimed ? 1 : 0 },
                                set: { isTimed = $0 == 1 }
                            ),
                            icon: "timer"
                        )
                        
                        ModernPickerField(
                            title: "Category",
                            options: ["Chest", "Legs", "Arms", "Back", "Shoulders", "Cardio", "Full Body", "Other"],
                            selected: $category,
                            icon: "tag.fill"
                        )
                        
                        ModernPickerField(
                            title: "Difficulty",
                            options: ["Beginner", "Intermediate", "Advanced"],
                            selected: $difficulty,
                            icon: "chart.bar.fill"
                        )
                        
                        ModernToggleField(
                            title: "Equipment Needed",
                            isOn: $equipmentNeeded,
                            icon: "wrench.and.screwdriver.fill"
                        )
                        
                        ModernTextEditor(
                            title: "Description",
                            placeholder: "Add notes or instructions...",
                            text: $description,
                            icon: "text.alignleft"
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Create button
                    Button(action: {
                        createMovement()
                    }) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Continue to Sets")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(UIColor(hex: "#20D474")),
                                    Color(UIColor(hex: "#1DB863"))
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .foregroundColor(.white)
                        .shadow(color: Color(UIColor(hex: "#20D474")).opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isCreating || movementName.isEmpty)
                    .opacity(movementName.isEmpty ? 0.6 : 1.0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .overlay(
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
        )
    }
    
    private func createMovement() {
        guard !movementName.isEmpty else { return }
        isCreating = true
        
        // Present the existing createNewWorkout flow for sets configuration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isCreating = false
            dismiss()
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                // Create a new movement with pre-filled values
                var newMovement = movement()
                newMovement.movement1Name = movementName
                newMovement.isTimed = isTimed
                newMovement.isSingle = true
                
                let vc = ModernEditMovementViewController()
                vc.movementToEdit = newMovement
                vc.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                if let sheet = vc.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.prefersGrabberVisible = true
                }
                rootVC.present(vc, animated: true)
            }
        }
    }
}

struct ModernCreateSessionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var sessionName: String = ""
    @State private var description: String = ""
    @State private var difficulty: String = "beginner"
    @State private var equipmentNeeded: Bool = false
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var isCreating: Bool = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.08, green: 0.08, blue: 0.12), location: 0.5),
                    .init(color: Color(red: 0.1, green: 0.1, blue: 0.15), location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header with illustration
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(UIColor(hex: "#F2994A")).opacity(0.3),
                                            Color(UIColor(hex: "#E8873A")).opacity(0.2)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "rectangle.stack.fill.badge.plus")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(Color(UIColor(hex: "#F2994A")))
                        }
                        .padding(.top, 20)
                        
                        Text("Create Session")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Build a complete workout")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // Form fields
                    VStack(spacing: 24) {
                        WorkoutTextField(
                            title: "Session Name",
                            placeholder: "e.g., Chest Day",
                            text: $sessionName,
                            icon: "textformat"
                        )
                        
                        ModernTextEditor(
                            title: "Description",
                            placeholder: "Describe your workout session...",
                            text: $description,
                            icon: "text.alignleft"
                        )
                        
                        ModernPickerField(
                            title: "Difficulty",
                            options: ["Beginner", "Intermediate", "Advanced"],
                            selected: $difficulty,
                            icon: "chart.bar.fill"
                        )
                        
                        ModernToggleField(
                            title: "Equipment Needed",
                            isOn: $equipmentNeeded,
                            icon: "wrench.and.screwdriver.fill"
                        )
                        
                        // Tags section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Tags")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                            }
                            
                            HStack {
                                TextField("Add a tag", text: $newTag)
                                    .textFieldStyle(WorkoutTextFieldStyle())
                                    .onSubmit {
                                        if !newTag.isEmpty {
                                            tags.append(newTag)
                                            newTag = ""
                                        }
                                    }
                                
                                Button(action: {
                                    if !newTag.isEmpty {
                                        tags.append(newTag)
                                        newTag = ""
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(UIColor(hex: "#F2994A")))
                                }
                            }
                            
                            if !tags.isEmpty {
                                WorkoutFlowLayout(spacing: 8) {
                                    ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                                        HStack(spacing: 6) {
                                            Text(tag)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                            
                                            Button(action: {
                                                tags.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color(UIColor(hex: "#F2994A")).opacity(0.2))
                                        )
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Create button
                    Button(action: {
                        createSession()
                    }) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Add Exercises")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(UIColor(hex: "#F2994A")),
                                    Color(UIColor(hex: "#E8873A"))
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .foregroundColor(.white)
                        .shadow(color: Color(UIColor(hex: "#F2994A")).opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isCreating || sessionName.isEmpty)
                    .opacity(sessionName.isEmpty ? 0.6 : 1.0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .overlay(
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
        )
    }
    
    private func createSession() {
        guard !sessionName.isEmpty else { return }
        isCreating = true
        
        // Present movement selector to add exercises to session
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isCreating = false
            dismiss()
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                let movementSelector = SelectMovementViewController()
                movementSelector.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                movementSelector.onMovementSelected = { (selectedMovement: movement) in
                    
                    var session = workoutSession()
                    session.name = sessionName
                    session.description = description.isEmpty ? nil : description
                    session.difficulty = difficulty
                    session.equipmentNeeded = equipmentNeeded ? ["Equipment needed"] : []
                    // Note: workoutSession doesn't have a tags property, only movement does
                    session.id = UUID().uuidString
                    session.movementsInSession = [selectedMovement]
                    
                    let trackingVC = NewWorkoutTrackingViewController(session: session)
                    trackingVC.modalPresentationStyle = .fullScreen
                    rootVC.present(trackingVC, animated: true)
                }
                rootVC.present(movementSelector, animated: true)
            }
        }
    }
}

struct ModernCreatePlanView: View {
    @Environment(\.dismiss) var dismiss
    @State private var planName: String = ""
    @State private var description: String = ""
    @State private var difficulty: String = "beginner"
    @State private var duration: String = ""
    @State private var isDayOfWeek: Bool = true
    @State private var equipmentNeeded: Bool = false
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var isCreating: Bool = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.08, green: 0.08, blue: 0.12), location: 0.5),
                    .init(color: Color(red: 0.1, green: 0.1, blue: 0.15), location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header with illustration
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(UIColor(hex: "#3C7EF9")).opacity(0.3),
                                            Color(UIColor(hex: "#2E5FD9")).opacity(0.2)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(Color(UIColor(hex: "#3C7EF9")))
                        }
                        .padding(.top, 20)
                        
                        Text("Create Plan")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Build a structured workout program")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // Form fields
                    VStack(spacing: 24) {
                        WorkoutTextField(
                            title: "Plan Name",
                            placeholder: "e.g., 5-Day Split",
                            text: $planName,
                            icon: "textformat"
                        )
                        
                        ModernTextEditor(
                            title: "Description",
                            placeholder: "Describe your workout plan...",
                            text: $description,
                            icon: "text.alignleft"
                        )
                        
                        WorkoutTextField(
                            title: "Duration",
                            placeholder: "e.g., 8 weeks",
                            text: $duration,
                            icon: "calendar"
                        )
                        
                        ModernPickerField(
                            title: "Difficulty",
                            options: ["Beginner", "Intermediate", "Advanced"],
                            selected: $difficulty,
                            icon: "chart.bar.fill"
                        )
                        
                        WorkoutSegmentedControl(
                            title: "Schedule Type",
                            options: ["Day of Week", "Numerical"],
                            selectedIndex: Binding(
                                get: { isDayOfWeek ? 0 : 1 },
                                set: { isDayOfWeek = $0 == 0 }
                            ),
                            icon: "calendar.badge.clock"
                        )
                        
                        ModernToggleField(
                            title: "Equipment Needed",
                            isOn: $equipmentNeeded,
                            icon: "wrench.and.screwdriver.fill"
                        )
                        
                        // Tags section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Tags")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                            }
                            
                            HStack {
                                TextField("Add a tag", text: $newTag)
                                    .textFieldStyle(WorkoutTextFieldStyle())
                                    .onSubmit {
                                        if !newTag.isEmpty {
                                            tags.append(newTag)
                                            newTag = ""
                                        }
                                    }
                                
                                Button(action: {
                                    if !newTag.isEmpty {
                                        tags.append(newTag)
                                        newTag = ""
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(UIColor(hex: "#3C7EF9")))
                                }
                            }
                            
                            if !tags.isEmpty {
                                WorkoutFlowLayout(spacing: 8) {
                                    ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                                        HStack(spacing: 6) {
                                            Text(tag)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                            
                                            Button(action: {
                                                tags.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color(UIColor(hex: "#3C7EF9")).opacity(0.2))
                                        )
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Create button
                    Button(action: {
                        createPlan()
                    }) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Continue to Sessions")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(UIColor(hex: "#3C7EF9")),
                                    Color(UIColor(hex: "#2E5FD9"))
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .foregroundColor(.white)
                        .shadow(color: Color(UIColor(hex: "#3C7EF9")).opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isCreating || planName.isEmpty)
                    .opacity(planName.isEmpty ? 0.6 : 1.0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .overlay(
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
        )
    }
    
    private func createPlan() {
        guard !planName.isEmpty else { return }
        isCreating = true
        
        // Present the existing createNewPlanViewController flow for session selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isCreating = false
            dismiss()
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                let vc = createNewPlanViewController()
                vc.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                rootVC.present(vc, animated: true)
            }
        }
    }
}

// MARK: - Modern Form Components

struct WorkoutTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(WorkoutTextFieldStyle())
        }
    }
}

struct WorkoutTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(.white)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
    }
}

struct ModernTextEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }
                
                TextEditor(text: $text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

struct WorkoutSegmentedControl: View {
    let title: String
    let options: [String]
    @Binding var selectedIndex: Int
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedIndex = index
                        }
                    }) {
                        Text(option)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(selectedIndex == index ? .white : .white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedIndex == index ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct ModernPickerField: View {
    let title: String
    let options: [String]
    @Binding var selected: String
    let icon: String
    @State private var showingPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Button(action: {
                showingPicker = true
            }) {
                HStack {
                    Text(selected.isEmpty ? "Select..." : selected)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingPicker) {
            ModernPickerSheet(
                title: title,
                options: options,
                selected: $selected,
                isPresented: $showingPicker
            )
        }
    }
}

struct ModernPickerSheet: View {
    let title: String
    let options: [String]
    @Binding var selected: String
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.08, green: 0.08, blue: 0.12), location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(20)
                
                // Options
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(options, id: \.self) { option in
                            Button(action: {
                                selected = option
                                isPresented = false
                            }) {
                                HStack {
                                    Text(option)
                                        .font(.system(size: 18, weight: .regular))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    if selected == option {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(Color(UIColor(hex: "#F7931F")))
                                    }
                                }
                                .padding(20)
                                .background(
                                    selected == option ? Color.white.opacity(0.1) : Color.clear
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                    }
                }
            }
        }
    }
}

struct ModernToggleField: View {
    let title: String
    @Binding var isOn: Bool
    let icon: String
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(Color(UIColor(hex: "#F7931F")))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// Flow layout for tags
struct WorkoutFlowLayout: Layout {
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
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
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

// MARK: - Browse Type Enum

enum BrowseType {
    case exercises
    case sessions
    case plans
}

// MARK: - Browse Library View

struct BrowseLibraryView: View {
    let browseType: BrowseType
    let viewModel: ModernGymTrackerViewController
    @Environment(\.dismiss) var dismiss
    @State private var items: [Any] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.08, green: 0.08, blue: 0.12), location: 0.5),
                    .init(color: Color(red: 0.1, green: 0.1, blue: 0.15), location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    
                    Spacer()
                    
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Placeholder for balance
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.6))
                    
                    TextField("Search...", text: $searchText)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .regular))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: searchText) { newValue in
                            // Debounce search text updates
                            debounceSearchText(newValue)
                        }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Content
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Spacer()
                } else if filteredItems.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: icon)
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text(debouncedSearchText.isEmpty ? "No items found" : "No results found")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        if !debouncedSearchText.isEmpty {
                            Text("Try a different search term")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.top, 4)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(filteredItems.enumerated()), id: \.offset) { index, item in
                                if let exercise = item as? movement {
                                    BrowseExerciseCard(exercise: exercise) {
                                        viewModel.showExerciseDetail(exercise)
                                    }
                                } else if let session = item as? workoutSession {
                                    BrowseSessionCard(session: session) {
                                        viewModel.showSessionDetail(session)
                                    }
                                } else if let plan = item as? plan {
                                    BrowsePlanCard(plan: plan) {
                                        viewModel.showPlanDetail(plan)
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .onAppear {
            loadItems()
        }
    }
    
    private var title: String {
        switch browseType {
        case .exercises: return "Exercises"
        case .sessions: return "Sessions"
        case .plans: return "Plans"
        }
    }
    
    private var icon: String {
        switch browseType {
        case .exercises: return "dumbbell.fill"
        case .sessions: return "rectangle.stack.fill"
        case .plans: return "calendar"
        }
    }
    
    private var filteredItems: [Any] {
        guard !debouncedSearchText.isEmpty else {
            return items
        }
        
        let searchLower = debouncedSearchText.lowercased()
        
        // Pre-compute lowercase strings once for better performance
        return items.filter { item in
            if let exercise = item as? movement {
                // Search in movement name, category, description
                let name = exercise.movement1Name?.lowercased() ?? exercise.displayName.lowercased()
                if name.contains(searchLower) { return true }
                
                if let category = exercise.category?.lowercased(), category.contains(searchLower) {
                    return true
                }
                
                if let description = exercise.description?.lowercased(), description.contains(searchLower) {
                    return true
                }
                
                return false
            } else if let session = item as? workoutSession {
                // Search in session name, description
                let name = session.name?.lowercased() ?? ""
                if name.contains(searchLower) { return true }
                
                if let description = session.description?.lowercased(), description.contains(searchLower) {
                    return true
                }
                
                return false
            } else if let plan = item as? plan {
                // Search in plan name, description
                let name = plan.name.lowercased() ?? ""
                if name.contains(searchLower) { return true }
                
                if let description = plan.description?.lowercased(), description.contains(searchLower) {
                    return true
                }
                
                return false
            }
            return false
        }
    }
    
    private func debounceSearchText(_ text: String) {
        // Cancel any existing task
        searchTask?.cancel()
        
        // Create new task
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                debouncedSearchText = text
            }
        }
    }
    
    private func loadItems() {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            isLoading = false
            return
        }
        
        Task {
            switch browseType {
            case .exercises:
                await loadAllMovements(userId: userId)
                
            case .sessions:
                await loadAllSessions(userId: userId)
                
            case .plans:
                await loadAllPlans(userId: userId)
            }
        }
    }
    
    private func loadAllMovements(userId: String) async {
        var allItems: [AWSWorkoutService.WorkoutItem] = []
        var lastEvaluatedKey: String? = nil
        
        // First load user's movements
        repeat {
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<AWSWorkoutService.GetWorkoutResponse, Error>, Never>) in
                AWSWorkoutService.shared.getMovements(
                    userId: userId,
                    limit: 100,
                    lastEvaluatedKey: lastEvaluatedKey
                ) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch result {
            case .success(let response):
                if let items = response.data {
                    allItems.append(contentsOf: items)
                    lastEvaluatedKey = response.lastEvaluatedKey
                    print("📥 [BrowseLibrary] Loaded \(items.count) user movements (total: \(allItems.count))")
                    
                    if response.lastEvaluatedKey == nil {
                        break
                    }
                } else {
                    break
                }
            case .failure(let error):
                print("❌ [BrowseLibrary] Error loading user movements: \(error.localizedDescription)")
                break
            }
        } while lastEvaluatedKey != nil
        
        // Then load public/starter movements (available to everyone)
        lastEvaluatedKey = nil
        repeat {
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<AWSWorkoutService.GetWorkoutResponse, Error>, Never>) in
                AWSWorkoutService.shared.getMovements(
                    userId: nil,
                    isPublic: true,
                    limit: 100,
                    lastEvaluatedKey: lastEvaluatedKey
                ) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch result {
            case .success(let response):
                if let items = response.data {
                    // Only add items that aren't already in the list (avoid duplicates)
                    let existingIds = Set(allItems.compactMap { $0.movementId })
                    let newItems = items.filter { item in
                        guard let id = item.movementId else { return false }
                        return !existingIds.contains(id)
                    }
                    allItems.append(contentsOf: newItems)
                    lastEvaluatedKey = response.lastEvaluatedKey
                    print("📥 [BrowseLibrary] Loaded \(newItems.count) public movements (total: \(allItems.count))")
                    
                    if response.lastEvaluatedKey == nil {
                        break
                    }
                } else {
                    break
                }
            case .failure(let error):
                print("❌ [BrowseLibrary] Error loading public movements: \(error.localizedDescription)")
                break
            }
        } while lastEvaluatedKey != nil
        
        let exercises = allItems.compactMap { item -> movement? in
                        var mov = movement()
                        mov.id = item.movementId ?? UUID().uuidString
                        mov.movement1Name = item.movement1Name ?? item.name ?? "Unnamed Movement"
                        mov.movement2Name = item.movement2Name ?? item.name ?? "Unnamed Movement"
                        mov.isSingle = item.isSingle ?? true
                        mov.category = item.category
                        mov.description = item.description
                        mov.difficulty = item.difficulty
                        // Convert Bool equipmentNeeded to [String]? equipmentsNeeded
        if let equipmentNeeded = item.equipmentNeeded {
            mov.equipmentsNeeded = equipmentNeeded ? ["Equipment needed"] : []
        }
                        mov.isTimed = item.isTimed ?? false
                        
                        // Parse sets if available
                        if let movementsData = item.movements, let firstMovement = movementsData.first as? [String: Any] {
                            // Parse firstSectionSets
                            if let firstSectionSets = firstMovement["firstSectionSets"] as? [[String: Any]] {
                                mov.firstSectionSets = firstSectionSets.map { setDict in
                                    ModernGymTrackerViewController.parseSet(from: setDict)
                                }
                            }
                            
                            // Parse secondSectionSets
                            if let secondSectionSets = firstMovement["secondSectionSets"] as? [[String: Any]] {
                                mov.secondSectionSets = secondSectionSets.compactMap { setDict -> set? in
                                    ModernGymTrackerViewController.parseSet(from: setDict)
                                }
                            }
                            
                            // Parse weavedSets
                            if let weavedSets = firstMovement["weavedSets"] as? [[String: Any]] {
                                mov.weavedSets = weavedSets.compactMap { setDict -> set? in
                                    ModernGymTrackerViewController.parseSet(from: setDict)
                                }
                            }
                        }
                        
                        return mov
                    }
        await MainActor.run {
            self.items = exercises
            self.isLoading = false
            print("✅ [BrowseLibrary] Total movements loaded: \(exercises.count)")
        }
    }
    
    private func loadAllSessions(userId: String) async {
        var allItems: [AWSWorkoutService.WorkoutItem] = []
        var lastEvaluatedKey: String? = nil
        
        // First load user's sessions
        repeat {
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<AWSWorkoutService.GetWorkoutResponse, Error>, Never>) in
                AWSWorkoutService.shared.getSessions(
                    userId: userId,
                    limit: 100,
                    lastEvaluatedKey: lastEvaluatedKey
                ) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch result {
            case .success(let response):
                if let items = response.data {
                    allItems.append(contentsOf: items)
                    lastEvaluatedKey = response.lastEvaluatedKey
                    print("📥 [BrowseLibrary] Loaded \(items.count) user sessions (total: \(allItems.count))")
                    
                    if response.lastEvaluatedKey == nil {
                        break
                    }
                } else {
                    break
                }
            case .failure(let error):
                print("❌ [BrowseLibrary] Error loading user sessions: \(error.localizedDescription)")
                break
            }
        } while lastEvaluatedKey != nil
        
        // Then load public sessions (available to everyone)
        lastEvaluatedKey = nil
        repeat {
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<AWSWorkoutService.GetWorkoutResponse, Error>, Never>) in
                AWSWorkoutService.shared.getSessions(
                    userId: nil,
                    isPublic: true,
                    limit: 100,
                    lastEvaluatedKey: lastEvaluatedKey
                ) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch result {
            case .success(let response):
                if let items = response.data {
                    // Only add items that aren't already in the list (avoid duplicates)
                    let existingIds = Set(allItems.compactMap { $0.sessionId })
                    let newItems = items.filter { item in
                        guard let id = item.sessionId else { return false }
                        return !existingIds.contains(id)
                    }
                    allItems.append(contentsOf: newItems)
                    lastEvaluatedKey = response.lastEvaluatedKey
                    print("📥 [BrowseLibrary] Loaded \(newItems.count) public sessions (total: \(allItems.count))")
                    
                    if response.lastEvaluatedKey == nil {
                        break
                    }
                } else {
                    break
                }
            case .failure(let error):
                print("❌ [BrowseLibrary] Error loading public sessions: \(error.localizedDescription)")
                break
            }
        } while lastEvaluatedKey != nil
        
        var sessions: [workoutSession] = []
        for item in allItems {
                        if let sessionId = item.sessionId {
                            var session = workoutSession()
                            session.id = sessionId
                            session.name = item.name
                            session.description = item.description
                            session.difficulty = item.difficulty
                            // Parse movements if available
                            if let movementsData = item.movements ?? item.movementsInSession {
                                session.movementsInSession = movementsData.compactMap { dict -> movement? in
                                    var mov = movement()
                                    
                                    mov.id = (dict["movementId"] as? String) ?? (dict["id"] as? String) ?? UUID().uuidString
                                    
                                    // Handle movement names - prioritize movement1Name, fallback to name field
                                    mov.movement1Name = (dict["movement1Name"] as? String) 
                                        ?? (dict["name"] as? String)
                                        ?? "Unnamed Movement"
                                    mov.movement2Name = dict["movement2Name"] as? String
                                    
                                    // Set isSingle flag from explicit value in data
                                    mov.isSingle = (dict["isSingle"] as? Bool) ?? true

                                    mov.category = dict["category"] as? String
                                    mov.isTimed = dict["isTimed"] as? Bool  ?? false
                                    mov.difficulty = dict["difficulty"] as? String
                                    mov.description = dict["description"] as? String
                                    
                                    // Handle equipment needed
                                    if let equipmentNeeded = dict["equipmentNeeded"] as? Bool {
                                        mov.equipmentsNeeded = equipmentNeeded ? ["Equipment needed"] : []
                                    } else if let equipmentsNeeded = dict["equipmentsNeeded"] as? Bool {
                                        mov.equipmentsNeeded = equipmentsNeeded ? ["Equipment needed"] : []
                                    }
                                    
                                    // Only return movement if it has a valid name (not just the default)
                                    guard let name = mov.movement1Name, !name.isEmpty, name != "Unnamed Movement" else {
                                        return nil
                                    }
                                    
                                    return mov
                                }
                            }
                            sessions.append(session)
                        }
                    }
        await MainActor.run {
            self.items = sessions
            self.isLoading = false
            print("✅ [BrowseLibrary] Total sessions loaded: \(sessions.count)")
        }
    }
    
    private func loadAllPlans(userId: String) async {
        var allItems: [AWSWorkoutService.WorkoutItem] = []
        var lastEvaluatedKey: String? = nil
        
        // First load user's plans
        repeat {
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<AWSWorkoutService.GetWorkoutResponse, Error>, Never>) in
                AWSWorkoutService.shared.getPlans(
                    userId: userId,
                    limit: 100,
                    lastEvaluatedKey: lastEvaluatedKey
                ) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch result {
            case .success(let response):
                if let items = response.data {
                    allItems.append(contentsOf: items)
                    lastEvaluatedKey = response.lastEvaluatedKey
                    print("📥 [BrowseLibrary] Loaded \(items.count) user plans (total: \(allItems.count))")
                    
                    if response.lastEvaluatedKey == nil {
                        break
                    }
                } else {
                    break
                }
            case .failure(let error):
                print("❌ [BrowseLibrary] Error loading user plans: \(error.localizedDescription)")
                break
            }
        } while lastEvaluatedKey != nil
        
        // Then load public plans (available to everyone)
        lastEvaluatedKey = nil
        repeat {
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<AWSWorkoutService.GetWorkoutResponse, Error>, Never>) in
                AWSWorkoutService.shared.getPlans(
                    userId: nil,
                    isPublic: true,
                    limit: 100,
                    lastEvaluatedKey: lastEvaluatedKey
                ) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch result {
            case .success(let response):
                if let items = response.data {
                    // Only add items that aren't already in the list (avoid duplicates)
                    let existingIds = Set(allItems.compactMap { $0.planId })
                    let newItems = items.filter { item in
                        guard let id = item.planId else { return false }
                        return !existingIds.contains(id)
                    }
                    allItems.append(contentsOf: newItems)
                    lastEvaluatedKey = response.lastEvaluatedKey
                    print("📥 [BrowseLibrary] Loaded \(newItems.count) public plans (total: \(allItems.count))")
                    
                    if response.lastEvaluatedKey == nil {
                        break
                    }
                } else {
                    break
                }
            case .failure(let error):
                print("❌ [BrowseLibrary] Error loading public plans: \(error.localizedDescription)")
                break
            }
        } while lastEvaluatedKey != nil
        
        var plans: [plan] = []
        for item in allItems {
                        if let planId = item.planId {
                            var p = plan()
                            p.id = planId
                            p.name = item.name ?? ""
                            p.description = item.description
                            p.difficulty = item.difficulty
                            p.sessions = item.sessions
                            plans.append(p)
                        }
                    }
        await MainActor.run {
            self.items = plans
            self.isLoading = false
            print("✅ [BrowseLibrary] Total plans loaded: \(plans.count)")
        }
    }
}

// MARK: - Movement Name Helper

extension movement {
    /// Returns a formatted display name for the movement
    /// Handles both single and compound movements
    var displayName: String {
        let name1 = movement1Name ?? "Unnamed Movement"
        
        if let name2 = movement2Name, !name2.isEmpty {
            // Compound movement: "Movement1 + Movement2"
            return "\(name1) + \(name2)"
        } else {
            // Single movement
            return name1
        }
    }
    
    /// Returns true if this is a compound movement (has movement2Name)
    var isCompound: Bool {
        return movement2Name != nil && !(movement2Name?.isEmpty ?? true)
    }
}

// MARK: - Detail Views

struct ExerciseDetailView: View {
    let exercise: movement
    let viewModel: ModernGymTrackerViewController
    @Environment(\.dismiss) var dismiss
    @State private var isStarting = false
    @State private var showShareSheet = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.08, green: 0.08, blue: 0.12), location: 0.5),
                    .init(color: Color(red: 0.1, green: 0.1, blue: 0.15), location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header with large illustration
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.4),
                                            Color(red: 0.125, green: 0.7, blue: 0.35).opacity(0.3)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 150, height: 150)
                            
                            ExerciseCharacterView(exercise: exercise)
                                .frame(width: 120, height: 120)
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 12) {
                            Text(exercise.displayName)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                            
                            if let category = exercise.category {
                                Text(category)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.15))
                                    )
                            }
                        }
                    }
                    
                    // Details section
                    VStack(spacing: 24) {
                        if let description = exercise.description, !description.isEmpty {
                            DetailSection(title: "Description", icon: "text.alignleft") {
                                Text(description)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        HStack(spacing: 24) {
                            if let difficulty = exercise.difficulty {
                                DetailInfoCard(
                                    title: "Difficulty",
                                    value: difficulty.capitalized,
                                    icon: "chart.bar.fill",
                                    color: Color(red: 0.976, green: 0.576, blue: 0.125)
                                )
                            }
                            
                            if let sets = exercise.firstSectionSets, !sets.isEmpty {
                                DetailInfoCard(
                                    title: "Sets",
                                    value: "\(sets.count)",
                                    icon: "list.number",
                                    color: Color(red: 0.125, green: 0.8, blue: 0.45)
                                )
                            }
                        }
                        
                        // Sets display section
                        if hasSets() {
                            DetailSection(title: "Sets", icon: "list.number") {
                                VStack(spacing: 12) {
                                    if let firstSectionSets = exercise.firstSectionSets, !firstSectionSets.isEmpty {
                                        ForEach(Array(firstSectionSets.enumerated()), id: \.offset) { index, set in
                                            SetRowView(set: set, setNumber: index + 1, isTimed: exercise.isTimed == true)
                                        }
                                    }
                                    
                                    if let secondSectionSets = exercise.secondSectionSets, !secondSectionSets.isEmpty {
                                        ForEach(Array(secondSectionSets.enumerated()), id: \.offset) { index, set in
                                            SetRowView(set: set, setNumber: (exercise.firstSectionSets?.count ?? 0) + index + 1, isTimed: exercise.isTimed == true)
                                        }
                                    }
                                    
                                    if let weavedSets = exercise.weavedSets, !weavedSets.isEmpty {
                                        ForEach(Array(weavedSets.enumerated()), id: \.offset) { index, set in
                                            SetRowView(set: set, setNumber: (exercise.firstSectionSets?.count ?? 0) + (exercise.secondSectionSets?.count ?? 0) + index + 1, isTimed: exercise.isTimed == true)
                                        }
                                    }
                                }
                            }
                        }
                        
                        if let equipments = exercise.equipmentsNeeded, !equipments.isEmpty {
                            DetailSection(title: "Equipment", icon: "wrench.and.screwdriver.fill") {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(red: 0.125, green: 0.8, blue: 0.45))
                                    Text("Equipment required")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            startExercise()
                        }) {
                            HStack {
                                if isStarting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 20))
                                    
                                    Text("Start Exercise")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.125, green: 0.8, blue: 0.45),
                                        Color(red: 0.125, green: 0.7, blue: 0.35)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .foregroundColor(.white)
                            .shadow(color: Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isStarting)
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Close")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .overlay(
            VStack {
                HStack {
                    Spacer()
                    // Edit button
                    Button(action: {
                        editExercise()
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 20)
                    
                    // Delete button
                    Button(action: {
                        deleteExercise()
                    }) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 20)
                    
                    // Close button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
        )
    }
    
    private func hasSets() -> Bool {
        let hasFirst = exercise.firstSectionSets?.isEmpty == false
        let hasSecond = exercise.secondSectionSets?.isEmpty == false
        let hasWeaved = exercise.weavedSets?.isEmpty == false
        return hasFirst || hasSecond || hasWeaved
    }
    
    private func editExercise() {
        // Find the hosting controller that's presenting this view
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }
            // Present edit view from the detail view's hosting controller
            viewModel.editExercise(exercise, from: topVC)
        } else {
            // Fallback: dismiss and present from topmost
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                viewModel.editExercise(exercise)
            }
        }
    }
    
    private func deleteExercise() {
        dismiss()
        
        // Find the topmost presented view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        var topVC = rootVC
        while let presentedVC = topVC.presentedViewController {
            topVC = presentedVC
        }
        
        let alertController = UIAlertController(
            title: "Delete Movement",
            message: "Are you sure you want to delete this movement from your library?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.performDeleteExercise()
        })
        
        topVC.present(alertController, animated: true)
    }
    
    private func performDeleteExercise() {
        guard let userId = CurrentUserService.shared.userID else {
            return
        }
        
        // TODO: Implement AWS deletion endpoint when available
        // For now, show a message that deletion is not yet supported
        let alert = UIAlertController(
            title: "Delete Exercise",
            message: "Exercise deletion is not yet available. This feature will be added soon.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    private func startExercise() {
        isStarting = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isStarting = false
            dismiss()
            
            var tempSession = workoutSession()
            tempSession.id = "temp_" + UUID().uuidString
            tempSession.name = exercise.displayName
            tempSession.movementsInSession = [exercise]
            
            let trackingVC = NewWorkoutTrackingViewController(session: tempSession)
            trackingVC.isStandaloneMovement = true
            trackingVC.modalPresentationStyle = .fullScreen
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(trackingVC, animated: true)
            }
        }
    }
    
    private func shareWorkout() {
        // Tap = send in messages
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            ShareManager.shared.shareWorkout(.movement(exercise), from: rootVC, sendInMessage: true)
        }
    }
    
    private func showShareOptions() {
        // Long press = show options
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            ShareManager.shared.shareWorkout(.movement(exercise), from: rootVC, sendInMessage: false)
        }
    }
}

// MARK: - Set Row View
struct SetRowView: View {
    let set: set
    let setNumber: Int
    let isTimed: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Set number
            Text("\(setNumber)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30, alignment: .leading)
            
            Spacer()
            
            if isTimed {
                // Timed set display
                if let duration = set.duration, duration > 0 {
                    let seconds = duration
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(formatTime(seconds))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                } else {
                    Text("No time set")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                // Rep-based set display
                HStack(spacing: 16) {
                    if let weight = set.weight {
                        HStack(spacing: 4) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                            Text(String(format: "%.1f lbs", weight))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    
                    if let reps = set.reps {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                            Text("\(reps) reps")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    
                    if set.weight == nil && set.reps == nil {
                        Text("No data")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

struct SessionDetailView: View {
    let session: workoutSession
    let viewModel: ModernGymTrackerViewController
    @Environment(\.dismiss) var dismiss
    @State private var isStarting = false
    @State private var showShareSheet = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.08, green: 0.08, blue: 0.12), location: 0.5),
                    .init(color: Color(red: 0.1, green: 0.1, blue: 0.15), location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header with large illustration
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 1.0, green: 0.6, blue: 0.3).opacity(0.4),
                                            Color(red: 0.95, green: 0.5, blue: 0.25).opacity(0.3)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 150, height: 150)
                            
                            WorkoutCharacterView(workout: session)
                                .frame(width: 120, height: 120)
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 12) {
                            Text(session.name ?? "Workout Session")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            if let difficulty = session.difficulty {
                                Text(difficulty.capitalized)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.15))
                                    )
                            }
                        }
                    }
                    
                    // Details section
                    VStack(spacing: 24) {
                        if let description = session.description, !description.isEmpty {
                            DetailSection(title: "Description", icon: "text.alignleft") {
                                Text(description)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        if let movements = session.movementsInSession, !movements.isEmpty {
                            DetailSection(title: "Exercises", icon: "dumbbell.fill") {
                                VStack(spacing: 12) {
                                    ForEach(Array(movements.enumerated()), id: \.offset) { index, movement in
                                        Button(action: {
                                            viewModel.showExerciseDetail(movement)
                                        }) {
                                            HStack {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color(red: 1.0, green: 0.6, blue: 0.3).opacity(0.2))
                                                        .frame(width: 40, height: 40)
                                                    
                                                    Text("\(index + 1)")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                                
                                                Text(movement.displayName)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .lineLimit(2)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                            .padding(12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.08))
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        
                        HStack(spacing: 24) {
                            if let movements = session.movementsInSession {
                                DetailInfoCard(
                                    title: "Exercises",
                                    value: "\(movements.count)",
                                    icon: "dumbbell.fill",
                                    color: Color(red: 1.0, green: 0.6, blue: 0.3)
                                )
                            }
                            
                            if let equipment = session.equipmentNeeded, !equipment.isEmpty {
                                DetailInfoCard(
                                    title: "Equipment",
                                    value: "Yes",
                                    icon: "wrench.and.screwdriver.fill",
                                    color: Color(red: 0.976, green: 0.576, blue: 0.125)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            startSession()
                        }) {
                            HStack {
                                if isStarting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 20))
                                    
                                    Text("Start Workout")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.6, blue: 0.3),
                                        Color(red: 0.95, green: 0.5, blue: 0.25)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .foregroundColor(.white)
                            .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.3).opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isStarting)
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Close")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .overlay(
            VStack {
                HStack {
                    Spacer()
                    // Edit button
                    Button(action: {
                        editSession()
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 20)
                    
                    // Share button
                    Button(action: {
                        shareWorkout()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.3)
                            .onEnded { _ in
                                showShareOptions()
                            }
                    )
                    .padding(.trailing, 12)
                    .padding(.top, 20)
                    
                    // Close button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
        )
    }
    
    private func editSession() {
        // Find the hosting controller that's presenting this view
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }
            // Present edit view from the detail view's hosting controller
            viewModel.editSession(session, from: topVC)
        } else {
            // Fallback: dismiss and present from topmost
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                viewModel.editSession(session)
            }
        }
    }
    
    private func shareWorkout() {
        // Tap = send in messages
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            ShareManager.shared.shareWorkout(.session(session), from: rootVC, sendInMessage: true)
        }
    }
    
    private func showShareOptions() {
        // Long press = show options
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            ShareManager.shared.shareWorkout(.session(session), from: rootVC, sendInMessage: false)
        }
    }
    
    private func startSession() {
        isStarting = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isStarting = false
            dismiss()
            
            let trackingVC = NewWorkoutTrackingViewController(session: session)
            trackingVC.modalPresentationStyle = .fullScreen
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(trackingVC, animated: true)
            }
        }
    }
}

struct PlanDetailView: View {
    let plan: plan
    let viewModel: ModernGymTrackerViewController
    @Environment(\.dismiss) var dismiss
    @State private var selectedSessionId: String?
    @State private var isStarting = false
    @State private var todayWorkout: workoutSession?
    @State private var isLoadingTodayWorkout = false
    @State private var showShareSheet = false
    @State private var sessionNames: [String: String] = [:]
    @State private var isLoadingSessions = false
    @State private var selectedSession: workoutSession?
    @State private var showRestDayDetail = false
    @State private var showActivityDetail = false
    @State private var selectedActivity: PlanActivity?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.08, green: 0.08, blue: 0.12), location: 0.5),
                    .init(color: Color(red: 0.1, green: 0.1, blue: 0.15), location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.24, green: 0.49, blue: 0.98).opacity(0.4),
                                            Color(red: 0.18, green: 0.37, blue: 0.85).opacity(0.3)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 150, height: 150)
                            
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 60, weight: .bold))
                                .foregroundColor(Color(red: 0.24, green: 0.49, blue: 0.98))
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 12) {
                            Text(plan.name ?? "Workout Plan")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            if let difficulty = plan.difficulty {
                                Text(difficulty.capitalized)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.15))
                                    )
                            }
                        }
                    }
                    
                    // Details section
                    VStack(spacing: 24) {
                        if let description = plan.description, !description.isEmpty {
                            DetailSection(title: "Description", icon: "text.alignleft") {
                                Text(description)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        HStack(spacing: 24) {
                            if let duration = plan.duration {
                                DetailInfoCard(
                                    title: "Duration",
                                    value: duration,
                                    icon: "calendar",
                                    color: Color(red: 0.24, green: 0.49, blue: 0.98)
                                )
                            }
                            
                            if let sessions = plan.sessions {
                                DetailInfoCard(
                                    title: "Sessions",
                                    value: "\(sessions.count)",
                                    icon: "rectangle.stack.fill",
                                    color: Color(red: 0.976, green: 0.576, blue: 0.125)
                                )
                            }
                        }
                        
                        if let sessions = plan.sessions, !sessions.isEmpty {
                            DetailSection(title: "Schedule", icon: "calendar.badge.clock") {
                                VStack(spacing: 12) {
                                    ForEach(sortedScheduleKeys(plan.isDayOfTheWeekPlan ?? false, sessions: sessions), id: \.self) { dayKey in
                                        if let sessionValue = sessions[dayKey] {
                                            PlanScheduleRow(
                                                day: dayKey,
                                                value: sessionValue,
                                                sessionName: sessionNames[sessionValue],
                                                onTap: {
                                                    handleScheduleItemTap(value: sessionValue)
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Today's workout section (if plan is active)
                    if let workout = todayWorkout {
                        DetailSection(title: "Today's Workout", icon: "calendar.badge.clock") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(workout.name ?? "Workout")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                
                                if let movements = workout.movementsInSession {
                                    Text("\(movements.count) exercises")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Button(action: {
                                    startTodayWorkout(workout)
                                }) {
                                    HStack {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 18))
                                        
                                        Text("Start Today's Workout")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
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
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        // Start Plan button (if not already active)
                        if todayWorkout == nil {
                            Button(action: {
                                startPlan()
                            }) {
                                HStack {
                                    if isStarting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 18))
                                        
                                        Text("Start Plan")
                                            .font(.system(size: 18, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.24, green: 0.49, blue: 0.98),
                                            Color(red: 0.18, green: 0.37, blue: 0.85)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .foregroundColor(.white)
                                .shadow(color: Color(red: 0.24, green: 0.49, blue: 0.98).opacity(0.4), radius: 10, x: 0, y: 5)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(isStarting)
                        }
                        
                        Button(action: {
                            openPlanView()
                        }) {
                            HStack {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 18))
                                
                                Text("View Full Plan")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Close")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            loadSessionNames()
            loadTodayWorkoutIfActive()
        }
        .sheet(isPresented: Binding(
            get: { selectedSession != nil },
            set: { if !$0 { selectedSession = nil } }
        )) {
            if let session = selectedSession {
                SessionDetailView(session: session, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showRestDayDetail) {
            RestDayDetailView()
        }
        .sheet(isPresented: $showActivityDetail) {
            if let activity = selectedActivity {
                ActivityDetailView(activity: activity)
            }
        }
        .overlay(
            VStack {
                HStack {
                    Spacer()
                    // Edit button
                    Button(action: {
                        editPlan()
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 20)
                    
                    // Share button
                    Button(action: {
                        shareWorkout()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.3)
                            .onEnded { _ in
                                showShareOptions()
                            }
                    )
                    .padding(.trailing, 12)
                    .padding(.top, 20)
                    
                    // Close button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
        )
        .onAppear {
            loadTodayWorkoutIfActive()
        }
    }
    
    private func editPlan() {
        // Find the hosting controller that's presenting this view
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }
            // Present edit view from the detail view's hosting controller
            viewModel.editPlan(plan, from: topVC)
        } else {
            // Fallback: dismiss and present from topmost
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                viewModel.editPlan(plan)
            }
        }
    }
    
    private func sortedScheduleKeys(_ isDayOfWeek: Bool, sessions: [String: String]) -> [String] {
        if isDayOfWeek {
            // Day of week plan - sort by day order
            let dayOrder = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            return sessions.keys.sorted { key1, key2 in
                let index1 = dayOrder.firstIndex(of: key1) ?? Int.max
                let index2 = dayOrder.firstIndex(of: key2) ?? Int.max
                return index1 < index2
            }
        } else {
            // Sequential plan - sort by day number
            return sessions.keys.sorted { key1, key2 in
                let day1 = Int(key1.replacingOccurrences(of: "Day ", with: "")) ?? 0
                let day2 = Int(key2.replacingOccurrences(of: "Day ", with: "")) ?? 0
                return day1 < day2
            }
        }
    }
    
    private func handleScheduleItemTap(value: String) {
        let lowercased = value.lowercased()
        
        // Check if it's a rest day
        if lowercased.contains("rest") || lowercased == "rest session" {
            showRestDayDetail = true
            return
        }
        
        // Check if it's an activity
        if lowercased.contains("activitytype:") || lowercased.contains("activitytype") {
            if let activity = PlanActivity.fromString(value) {
                selectedActivity = activity
                showActivityDetail = true
            }
            return
        }
        
        // Otherwise, it's a workout session
        loadAndShowSession(sessionId: value)
    }
    
    private func loadAndShowSession(sessionId: String) {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else { return }
        
        Task {
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<AWSWorkoutService.GetWorkoutResponse, Error>, Never>) in
                AWSWorkoutService.shared.getSessions(userId: userId, limit: 100) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch result {
            case .success(let response):
                guard let items = response.data else { return nil }
                if let sessionItem = items.first(where: { $0.sessionId == sessionId }) {
                    var session = workoutSession()
                    session.id = sessionItem.sessionId ?? UUID().uuidString
                    session.name = sessionItem.name
                    session.description = sessionItem.description
                    session.difficulty = sessionItem.difficulty
                    // Convert Bool equipmentNeeded to [String]? equipmentNeeded
                    if let equipmentNeeded = sessionItem.equipmentNeeded {
                        session.equipmentNeeded = equipmentNeeded ? ["Equipment needed"] : []
                    }
                    
                    // Parse movements if available
                    if let movementsData = sessionItem.movements {
                        session.movementsInSession = movementsData.compactMap { movDict -> movement? in
                            var mov = movement()
                            mov.id = (movDict["movementId"] as? String) ?? (movDict["id"] as? String) ?? UUID().uuidString
                            mov.movement1Name = movDict["movement1Name"] as? String ?? movDict["name"] as? String
                            mov.movement2Name = movDict["movement2Name"] as? String
                            mov.isSingle = (movDict["isSingle"] as? Bool) ?? true
                            mov.isTimed = (movDict["isTimed"] as? Bool) ?? false
                            mov.category = movDict["category"] as? String
                            return mov
                        }
                    }
                    
                    await MainActor.run {
                        self.selectedSession = session
                    }
                }
            case .failure(let error):
                print("❌ [PlanDetail] Error loading session: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadSessionNames() {
        guard let userId = UserIDHelper.shared.getCurrentUserID(),
              let sessions = plan.sessions else { return }
        
        isLoadingSessions = true
        
        // Extract all session IDs (not rest days or activities)
        let sessionIds = sessions.values.filter { value in
            let lowercased = value.lowercased()
            return !lowercased.contains("rest") && !lowercased.contains("activitytype:")
        }
        
        guard !sessionIds.isEmpty else {
            isLoadingSessions = false
            return
        }
        
        Task {
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<AWSWorkoutService.GetWorkoutResponse, Error>, Never>) in
                AWSWorkoutService.shared.getSessions(userId: userId, limit: 100) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch result {
            case .success(let response):
                guard let items = response.data else {
                    await MainActor.run {
                        self.isLoadingSessions = false
                    }
                    return
                }
                var names: [String: String] = [:]
                for item in items {
                    if let sessionId = item.sessionId, sessionIds.contains(sessionId) {
                        names[sessionId] = item.name ?? "Unnamed Session"
                    }
                }
                await MainActor.run {
                    self.sessionNames = names
                    self.isLoadingSessions = false
                }
            case .failure:
                await MainActor.run {
                    self.isLoadingSessions = false
                }
            }
        }
    }
    
    private func loadTodayWorkoutIfActive() {
        guard let userId = UserIDHelper.shared.getCurrentUserID(),
              !plan.id.isEmpty else { return }
        let planId = plan.id
        
        isLoadingTodayWorkout = true
        
        Task {
            // Check if plan is already active
            let planLogsResult = await withCheckedContinuation { (continuation: CheckedContinuation<Result<GetWorkoutLogsResponse, Error>, Never>) in
                ActivityService.shared.getPlanLogs(
                    userId: userId,
                    limit: 1, planId: planId,
                    active: true
                ) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch planLogsResult {
            case .success(let response):
                if let planLogs = response.data?.logs, !planLogs.isEmpty {
                    // Plan is active, get today's workout
                    let workout = await getTodayWorkoutFromPlan(plan, userId: userId)
                    await MainActor.run {
                        self.todayWorkout = workout
                        self.isLoadingTodayWorkout = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingTodayWorkout = false
                    }
                }
            case .failure(let error):
                print("❌ [PlanDetail] Error checking plan status: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingTodayWorkout = false
                }
            }
        }
    }
    
    private func startPlan() {
        guard let userId = UserIDHelper.shared.getCurrentUserID(),
              !plan.id.isEmpty else {
            print("❌ [PlanDetail] Cannot start plan: missing userId or planId")
            return
        }
        let planId = plan.id
        
        isStarting = true
        
        Task {
            // First, create a plan log (subscription) to mark the plan as active
            let createResult = await withCheckedContinuation { (continuation: CheckedContinuation<Result<SaveWorkoutLogResponse, Error>, Never>) in
                ActivityService.shared.savePlanLog(
                    userId: userId,
                    planId: planId,
                    active: true, startDate: Date()
                ) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch createResult {
            case .success(let response):
                let logId = response.data?.logId ?? "unknown"
                print("✅ [PlanDetail] Plan log created: \(logId)")
                
                // Now get today's workout from the plan
                let todayWorkout = await getTodayWorkoutFromPlan(plan, userId: userId)
                
                await MainActor.run {
                    self.isStarting = false
                    self.todayWorkout = todayWorkout
                    
                    if let workout = todayWorkout {
                        // Start the workout immediately
                        startTodayWorkout(workout)
                    } else {
                        // No workout for today, show plan view
                        openPlanView()
                    }
                }
                
            case .failure(let error):
                print("❌ [PlanDetail] Error creating plan log: \(error.localizedDescription)")
                await MainActor.run {
                    self.isStarting = false
                }
            }
        }
    }
    
    private func getTodayWorkoutFromPlan(_ plan: plan, userId: String) async -> workoutSession? {
        let calendar = Calendar.current
        let today = Date()
        
        var sessionId: String?
        
        if let isDayOfWeek = plan.isDayOfTheWeekPlan, isDayOfWeek {
            // Day of week plan
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE"
            let dayName = dateFormatter.string(from: today)
            
            sessionId = plan.sessions?[dayName]
        } else {
            // Sequential plan - start from Day 1 if no start date
            let startDate = plan.startDate ?? Date()
            let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
            let dayKey = "Day \(max(1, daysSinceStart + 1))"
            sessionId = plan.sessions?[dayKey]
        }
        
        guard let sessionId = sessionId,
              !sessionId.lowercased().contains("rest"),
              !sessionId.lowercased().contains("activity") else {
            return nil
        }
        
        // Fetch the session from AWS
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<AWSWorkoutService.GetWorkoutResponse, Error>, Never>) in
            AWSWorkoutService.shared.getSessions(userId: userId, limit: 100) { result in
                continuation.resume(returning: result)
            }
        }
        
        switch result {
        case .success(let response):
            guard let items = response.data else { return nil }
            if let sessionItem = items.first(where: { $0.sessionId == sessionId }) {
                return convertToWorkoutSession(from: sessionItem, userId: userId)
            }
        case .failure(let error):
            print("❌ [PlanDetail] Error fetching session: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func convertToWorkoutSession(from item: AWSWorkoutService.WorkoutItem, userId: String) -> workoutSession? {
        guard let sessionId = item.sessionId else { return nil }
        
        var session = workoutSession()
        session.id = sessionId
        session.name = item.name
        session.description = item.description
        session.difficulty = item.difficulty ?? item.category
        // Convert Bool equipmentNeeded to [String]? equipmentNeeded
        if let equipmentNeeded = item.equipmentNeeded {
            session.equipmentNeeded = equipmentNeeded ? ["Equipment needed"] : []
        }
        
        // Parse createdAt if available
        if let createdAtString = item.createdAt {
            let formatter = ISO8601DateFormatter()
            session.createdAt = formatter.date(from: createdAtString)
        }
        
        // Convert movements if available (embedded movements in session)
        let movementsData = item.movements ?? item.movementsInSession
        if let movementsData = movementsData {
            session.movementsInSession = movementsData.compactMap { dict -> movement? in
                var mov = movement()
                
                mov.id = (dict["movementId"] as? String) ?? (dict["id"] as? String) ?? UUID().uuidString
                mov.movement1Name = (dict["movement1Name"] as? String) ?? (dict["name"] as? String) ?? "Unnamed Movement"
                mov.movement2Name = dict["movement2Name"] as? String
                mov.isSingle = (dict["isSingle"] as? Bool) ?? true
                mov.category = dict["category"] as? String
                mov.isTimed = (dict["isTimed"] as? Bool) ?? false
                mov.difficulty = dict["difficulty"] as? String
                mov.description = dict["description"] as? String
                
                if let equipmentNeeded = dict["equipmentNeeded"] as? Bool {
                    mov.equipmentsNeeded = equipmentNeeded ? ["Equipment needed"] : []
                } else if let equipmentsNeeded = dict["equipmentsNeeded"] as? Bool {
                    mov.equipmentsNeeded = equipmentsNeeded ? ["Equipment needed"] : []
                }
                
                guard let name = mov.movement1Name, !name.isEmpty, name != "Unnamed Movement" else {
                    return nil
                }
                
                return mov
            }
        }
        
        return session
    }
    
    private func startTodayWorkout(_ session: workoutSession) {
        dismiss()
        
        let trackingVC = NewWorkoutTrackingViewController(session: session)
        trackingVC.isPlanLog = true
        // Use plan.id directly (it's a non-optional String)
        let planId = plan.id
        // Note: planSubscriptionID might need to be set if available
        // For now, we'll use the plan ID
        trackingVC.modalPresentationStyle = .fullScreen
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(trackingVC, animated: true)
        }
    }
    
    private func openPlanView() {
        dismiss()
        
        let planVC = ViewPlanVC()
        planVC.thisPlan = plan
        if let sessions = plan.sessions {
            planVC.orderOfSessions = Array(sessions.values)
        }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            planVC.modalPresentationStyle = UIModalPresentationStyle.pageSheet
            rootVC.present(planVC, animated: true)
        }
    }
    
    private func shareWorkout() {
        // Tap = send in messages
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            ShareManager.shared.shareWorkout(.plan(plan), from: rootVC, sendInMessage: true)
        }
    }
    
    private func showShareOptions() {
        // Long press = show options
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            ShareManager.shared.shareWorkout(.plan(plan), from: rootVC, sendInMessage: false)
        }
    }
}

// MARK: - Detail View Components

struct PlanScheduleRow: View {
    let day: String
    let value: String
    let sessionName: String?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Day label
                Text(day)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 100, alignment: .leading)
                
                Spacer()
                
                // What's scheduled
                HStack(spacing: 8) {
                    if value.lowercased().contains("rest") || value.lowercased() == "rest session" {
                        HStack(spacing: 8) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 16))
                            Text("Rest Day")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    } else if value.lowercased().contains("activitytype:") {
                        let activityType = parseActivityType(from: value)
                        HStack(spacing: 8) {
                            Image(systemName: activityIcon(for: activityType))
                                .font(.system(size: 16))
                            Text(activityType.capitalized)
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    } else {
                        // Session
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 16))
                            Text(sessionName ?? "Workout Session")
                                .font(.system(size: 15, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                // Always show chevron to indicate it's tappable
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func parseActivityType(from value: String) -> String {
        if let range = value.range(of: "activityType:") {
            let afterType = String(value[range.upperBound...])
            if let semicolonRange = afterType.range(of: ";") {
                return String(afterType[..<semicolonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            return afterType.trimmingCharacters(in: .whitespaces)
        }
        return "activity"
    }
    
    private func activityIcon(for activityType: String) -> String {
        switch activityType.lowercased() {
        case "running", "run": return "figure.run"
        case "biking", "cycling", "bike": return "bicycle"
        case "walking", "walk": return "figure.walk"
        case "hiking", "hike": return "figure.hiking"
        case "swimming", "swim": return "figure.pool.swim"
        case "sports", "sport": return "sportscourt.fill"
        default: return "figure.mixed.cardio"
        }
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            content
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

struct DetailInfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Browse Cards

struct BrowseExerciseCard: View {
    let exercise: movement
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.125, green: 0.8, blue: 0.45).opacity(0.3),
                                    Color(red: 0.125, green: 0.7, blue: 0.35).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color(red: 0.125, green: 0.8, blue: 0.45))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    if let category = exercise.category {
                        Text(category)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
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
        .buttonStyle(PlainButtonStyle())
    }
}

struct BrowseSessionCard: View {
    let session: workoutSession
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.6, blue: 0.3).opacity(0.3),
                                    Color(red: 0.95, green: 0.5, blue: 0.25).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.3))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.name ?? "Session")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let movements = session.movementsInSession {
                        Text("\(movements.count) exercises")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
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
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Insight Cards

struct InsightGapCard: View {
    let gap: WorkoutGap
    
    var body: some View {
        HStack(spacing: 16) {
            // Severity indicator
            Circle()
                .fill(severityColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(gap.category)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                if let daysSince = gap.daysSinceLastWorkout {
                    Text("\(daysSince) days since last workout")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("Not worked recently")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(severityColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var severityColor: Color {
        switch gap.severity {
        case .high:
            return Color(red: 1.0, green: 0.42, blue: 0.21)
        case .medium:
            return Color(red: 0.976, green: 0.576, blue: 0.125)
        case .low:
            return Color.blue
        }
    }
}

struct InsightRecommendationCard: View {
    let recommendation: WorkoutRecommendation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(priorityColor)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(priorityColor.opacity(0.2))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(recommendation.description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(priorityColor.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconName: String {
        // Use category to determine icon, or default based on priority
        let categoryLower = recommendation.category.lowercased()
        if categoryLower.contains("gap") || categoryLower.contains("missing") {
            return "target"
        } else if categoryLower.contains("variety") || categoryLower.contains("divers") {
            return "sparkles"
        } else if categoryLower.contains("frequency") || categoryLower.contains("more") {
            return "arrow.up.circle.fill"
        } else if categoryLower.contains("new") || categoryLower.contains("try") {
            return "star.fill"
        } else {
            // Default icon based on priority
            switch recommendation.priority {
            case .high:
                return "exclamationmark.circle.fill"
            case .medium:
                return "checkmark.circle.fill"
            case .low:
                return "info.circle.fill"
            }
        }
    }
    
    private var priorityColor: Color {
        switch recommendation.priority {
        case .high:
            return Color(red: 1.0, green: 0.42, blue: 0.21)
        case .medium:
            return Color(red: 0.976, green: 0.576, blue: 0.125)
        case .low:
            return Color.blue
        }
    }
}

struct CategoryBreakdownCard: View {
    let category: String
    let stats: CategoryStats
    
    var body: some View {
        VStack(spacing: 8) {
            Text(category)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Text("\(stats.workoutCount)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("workouts")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(width: 100, height: 100)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct BrowsePlanCard: View {
    let plan: plan
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.24, green: 0.49, blue: 0.98).opacity(0.3),
                                    Color(red: 0.18, green: 0.37, blue: 0.85).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color(red: 0.24, green: 0.49, blue: 0.98))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.name ?? "Plan")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let sessions = plan.sessions {
                        Text("\(sessions.count) sessions")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
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
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Additional View Controllers

// Plan creation view controller
class createNewPlanViewController: UIViewController {
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let createButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        
        // Title
        titleLabel.text = "Create New Plan"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Close button
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        // Table view setup
        tableView.backgroundColor = UIColor.clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PlanCell")
        view.addSubview(tableView)
        
        // Create button
        createButton.setTitle("Create Plan", for: .normal)
        createButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        createButton.backgroundColor = self.uicolorFromHex(rgbValue: 0xF7931F)
        createButton.tintColor = .white
        createButton.layer.cornerRadius = 16
        createButton.addTarget(self, action: #selector(createPlanTapped), for: .touchUpInside)
        createButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(createButton)
        
        NSLayoutConstraint.activate([
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Close button constraints
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Table view constraints
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: createButton.topAnchor, constant: -20),
            
            // Create button constraints
            createButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            createButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            createButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            createButton.heightAnchor.constraint(equalToConstant: 56)
        ])
        
        // Add entrance animation
        titleLabel.alpha = 0
        closeButton.alpha = 0
        tableView.alpha = 0
        createButton.alpha = 0
        
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
            self.titleLabel.alpha = 1
            self.closeButton.alpha = 1
            self.tableView.alpha = 1
            self.createButton.alpha = 1
        })
    }
    
    @objc private func closeTapped() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0
        }) { _ in
            self.dismiss(animated: false)
        }
    }
    
    @objc private func createPlanTapped() {
        // Implement plan creation logic here
        dismiss(animated: true)
    }
}

// MARK: - Gym Stat Card Component
struct GymStatCard: View {
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
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: gradient.map { $0.opacity(0.3) }),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

extension createNewPlanViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1  // Plan name
        case 1: return 2  // Duration & Frequency
        case 2: return 3  // Exercises/Movements
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlanCell", for: indexPath)
        cell.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        cell.textLabel?.textColor = .white
        
        switch indexPath.section {
        case 0:
            cell.textLabel?.text = "Plan Name"
            cell.accessoryType = .disclosureIndicator
        case 1:
            cell.textLabel?.text = indexPath.row == 0 ? "Duration (weeks)" : "Frequency (per week)"
            cell.accessoryType = .disclosureIndicator
        case 2:
            cell.textLabel?.text = "Select Movement \(indexPath.row + 1)"
            cell.accessoryType = .disclosureIndicator
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Plan Details"
        case 1: return "Schedule"
        case 2: return "Movements"
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = .lightGray
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Handle selection based on the section and row
        switch indexPath.section {
        case 0:
            // Show plan name input
            break
        case 1:
            // Show duration/frequency selector
            break
        case 2:
            // Show movement selector
            let movementSelector = SelectMovementViewController()
            movementSelector.modalPresentationStyle = UIModalPresentationStyle.pageSheet
            present(movementSelector, animated: true)
        default:
            break
        }
    }
}

// MARK: - Rest Day Detail View

struct RestDayDetailView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.08, green: 0.08, blue: 0.12), location: 0.5),
                    .init(color: Color(red: 0.1, green: 0.1, blue: 0.15), location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.4, green: 0.3, blue: 0.6).opacity(0.3),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                            
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 40)
                        
                        Text("Rest Day")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Take time to recover and recharge")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    
                    // Info section
                    VStack(alignment: .leading, spacing: 16) {
                        DetailSection(title: "About Rest Days", icon: "info.circle.fill") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Rest days are an essential part of any training plan. They allow your body to:")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    RestDayBenefitRow(icon: "heart.fill", text: "Recover and repair muscle tissue")
                                    RestDayBenefitRow(icon: "battery.100", text: "Restore energy levels")
                                    RestDayBenefitRow(icon: "brain.head.profile", text: "Prevent mental burnout")
                                    RestDayBenefitRow(icon: "chart.line.uptrend.xyaxis", text: "Improve long-term performance")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Close button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Got it")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .overlay(
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
        )
    }
}

struct RestDayBenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Activity Detail View

struct ActivityDetailView: View {
    let activity: PlanActivity
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.08, green: 0.08, blue: 0.12), location: 0.5),
                    .init(color: Color(red: 0.1, green: 0.1, blue: 0.15), location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.24, green: 0.49, blue: 0.98).opacity(0.3),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                            
                            Image(systemName: activity.icon)
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 40)
                        
                        Text(activity.displayName)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        if !activity.subtitle.isEmpty {
                            Text(activity.subtitle)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Details section
                    VStack(alignment: .leading, spacing: 16) {
                        if let distance = activity.distance {
                            DetailInfoCard(
                                title: "Distance",
                                value: String(format: "%.1f km", distance),
                                icon: "ruler",
                                color: Color(red: 0.24, green: 0.49, blue: 0.98)
                            )
                        }
                        
                        if let duration = activity.duration {
                            let minutes = Int(duration / 60)
                            let hours = minutes / 60
                            let remainingMinutes = minutes % 60
                            let durationText = hours > 0 ? "\(hours)h \(remainingMinutes)m" : "\(minutes) min"
                            
                            DetailInfoCard(
                                title: "Duration",
                                value: durationText,
                                icon: "clock.fill",
                                color: Color(red: 0.125, green: 0.8, blue: 0.45)
                            )
                        }
                        
                        if let runType = activity.runType {
                            DetailInfoCard(
                                title: "Run Type",
                                value: runType.capitalized,
                                icon: "figure.run",
                                color: Color(red: 0.976, green: 0.576, blue: 0.125)
                            )
                        }
                        
                        if let sportType = activity.sportType {
                            DetailInfoCard(
                                title: "Sport Type",
                                value: sportType.capitalized,
                                icon: "sportscourt.fill",
                                color: Color(red: 1.0, green: 0.6, blue: 0.3)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Close button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Close")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .overlay(
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
        )
    }
}


