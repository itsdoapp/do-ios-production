//
//  NewWorkoutTrackingViewController.swift
//  Do
//
//  Workout tracking view controller for gym sessions
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import Combine
import Foundation
import SwiftUI

// MARK: - NewWorkoutTrackingViewController

class NewWorkoutTrackingViewController: UIViewController {
    // MARK: - Properties
    private var session: workoutSession
    private var cancellables = Set<AnyCancellable>()
    private let gymTracker = GymTrackingEngine.shared
    
    // Context flags
    var isStandaloneMovement = false
    var isPlanLog = false
    var planID: String?
    var isOpenTraining = false
    
    // Workout state
    private var startTime: Date?
    private var elapsedTime: TimeInterval = 0
    private var timer: Timer?
    private var isPaused = false
    private var heartRate: Double = 0
    private var calories: Double = 0
    private var movements: [movement] = []
    
    // Set completion state
    private var showingSetCompletion: movement? = nil
    
    // MARK: - UI Components
    private lazy var statsView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 20
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var sessionNameContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let gradientLayer = CAGradientLayer()
        let doOrangeColor = uicolorFromHex(rgbValue: 0xF7931F)
        gradientLayer.colors = [
            doOrangeColor.withAlphaComponent(0.95).cgColor,
            doOrangeColor.withAlphaComponent(0.8).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 16
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        
        return view
    }()
    
    private lazy var sessionNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 2
        label.layer.shadowOpacity = 0.3
        label.layer.masksToBounds = false
        
        return label
    }()
    
    private lazy var timerLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        label.textColor = .white
        label.text = "00:00:00"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var heartRateView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView(image: UIImage(systemName: "heart.fill"))
        iconView.tintColor = .systemRed
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        label.textColor = .white
        label.text = "-- BPM"
        label.tag = 100
        
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(label)
        
        return stack
    }()
    
    private lazy var caloriesView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView(image: UIImage(systemName: "flame.fill"))
        iconView.tintColor = .systemOrange
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        label.textColor = .white
        label.text = "0 kcal"
        
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(label)
        
        return stack
    }()
    
    private lazy var pauseButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        button.setImage(UIImage(systemName: "pause.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = uicolorFromHex(rgbValue: 0xF7931F)
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(pauseButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var endButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        button.setImage(UIImage(systemName: "stop.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemRed
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(endButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var movementsTableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private lazy var addMovementButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        button.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: config), for: .normal)
        button.setTitle(" Add Movement", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.tintColor = .white
        button.backgroundColor = uicolorFromHex(rgbValue: 0x2D5016)
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(addMovementButtonTapped), for: .touchUpInside)
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Initialization
    init(session: workoutSession, isOpenTraining: Bool = false) {
        self.session = session
        self.isOpenTraining = isOpenTraining
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMovements()
        
        // Configure based on open training mode
        if isOpenTraining {
            addMovementButton.isHidden = false
            sessionNameLabel.text = "Open Training"
        } else {
            sessionNameLabel.text = session.name ?? "Workout"
        }
        
        // Register for heart rate notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHeartRateUpdate),
            name: Notification.Name("com.do.heartRate.update"),
            object: nil
        )
        
        startWorkout()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let gradientLayer = sessionNameContainer.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = sessionNameContainer.bounds
        }
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = uicolorFromHex(rgbValue: 0x0F163E)
        
        view.addSubview(statsView)
        statsView.addSubview(sessionNameContainer)
        sessionNameContainer.addSubview(sessionNameLabel)
        statsView.addSubview(timerLabel)
        statsView.addSubview(heartRateView)
        statsView.addSubview(caloriesView)
        view.addSubview(movementsTableView)
        view.addSubview(pauseButton)
        view.addSubview(endButton)
        view.addSubview(addMovementButton)
        
        addMovementButton.isHidden = !isOpenTraining
        
        NSLayoutConstraint.activate([
            statsView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            statsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            sessionNameContainer.topAnchor.constraint(equalTo: statsView.topAnchor, constant: 16),
            sessionNameContainer.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 16),
            sessionNameContainer.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -16),
            sessionNameContainer.heightAnchor.constraint(equalToConstant: 50),
            
            sessionNameLabel.topAnchor.constraint(equalTo: sessionNameContainer.topAnchor),
            sessionNameLabel.leadingAnchor.constraint(equalTo: sessionNameContainer.leadingAnchor, constant: 16),
            sessionNameLabel.trailingAnchor.constraint(equalTo: sessionNameContainer.trailingAnchor, constant: -16),
            sessionNameLabel.bottomAnchor.constraint(equalTo: sessionNameContainer.bottomAnchor),
            
            timerLabel.centerXAnchor.constraint(equalTo: statsView.centerXAnchor),
            timerLabel.topAnchor.constraint(equalTo: sessionNameContainer.bottomAnchor, constant: 16),
            
            heartRateView.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 8),
            heartRateView.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 16),
            
            caloriesView.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 8),
            caloriesView.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -16),
            caloriesView.bottomAnchor.constraint(equalTo: statsView.bottomAnchor, constant: -16),
            
            movementsTableView.topAnchor.constraint(equalTo: statsView.bottomAnchor, constant: 16),
            movementsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            movementsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            movementsTableView.bottomAnchor.constraint(equalTo: pauseButton.topAnchor, constant: -16),
            
            pauseButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            pauseButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            pauseButton.widthAnchor.constraint(equalToConstant: 50),
            pauseButton.heightAnchor.constraint(equalToConstant: 50),
            
            endButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            endButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            endButton.widthAnchor.constraint(equalToConstant: 50),
            endButton.heightAnchor.constraint(equalToConstant: 50),
            
            addMovementButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addMovementButton.centerYAnchor.constraint(equalTo: pauseButton.centerYAnchor),
            addMovementButton.heightAnchor.constraint(equalToConstant: 40),
            addMovementButton.widthAnchor.constraint(equalToConstant: 160)
        ])
        
        // Animate session name
        UIView.animate(withDuration: 0.5, delay: 0.3, options: .curveEaseOut) {
            self.sessionNameLabel.alpha = 1
        }
    }
    
    private func setupMovements() {
        movements = session.movementsInSession ?? []
        movementsTableView.delegate = self
        movementsTableView.dataSource = self
        movementsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "MovementCell")
    }
    
    // MARK: - Workout Control
    private func startWorkout() {
        startTime = Date()
        isPaused = false
        
        // Start workout in GymTrackingEngine
        gymTracker.startWorkout(session: session)
        
        // Subscribe to gym tracker updates
        gymTracker.$elapsedTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] elapsed in
                self?.elapsedTime = elapsed
                self?.updateTimerLabel()
            }
            .store(in: &cancellables)
        
        gymTracker.$heartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in
                self?.heartRate = hr
                if let heartRateLabel = self?.heartRateView.viewWithTag(100) as? UILabel {
                    heartRateLabel.text = hr > 0 ? "\(Int(hr)) BPM" : "-- BPM"
                }
            }
            .store(in: &cancellables)
        
        gymTracker.$totalCalories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cals in
                self?.calories = cals
                if let caloriesLabel = self?.caloriesView.arrangedSubviews.last as? UILabel {
                    caloriesLabel.text = "\(Int(cals)) kcal"
                }
            }
            .store(in: &cancellables)
        
        gymTracker.$completedSets
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Update movements with completed sets
                self?.updateMovementsWithCompletedSets()
                self?.movementsTableView.reloadData()
            }
            .store(in: &cancellables)
        
        startTimer()
    }
    
    private func updateMovementsWithCompletedSets() {
        // Update movements array with completed sets from gymTracker
        for (index, movement) in movements.enumerated() {
            // Find completed sets for this movement
            let movementCompletedSets = gymTracker.completedSets.filter { completedSet in
                // Match by movement ID or name
                return completedSet.id == movement.id || 
                       (movement.firstSectionSets?.contains(where: { $0.id == completedSet.id }) ?? false) ||
                       (movement.secondSectionSets?.contains(where: { $0.id == completedSet.id }) ?? false) ||
                       (movement.weavedSets?.contains(where: { $0.id == completedSet.id }) ?? false) ||
                       (movement.templateSets?.contains(where: { $0.id == completedSet.id }) ?? false)
            }
            
            // Update sets in movement
            if var firstSectionSets = movement.firstSectionSets {
                for (setIndex, var set) in firstSectionSets.enumerated() {
                    if let completedSet = movementCompletedSets.first(where: { $0.id == set.id }) {
                        set.completed = completedSet.completed
                        set.reps = completedSet.reps
                        set.weight = completedSet.weight
                        set.duration = completedSet.duration
                        firstSectionSets[setIndex] = set
                    }
                }
                movements[index].firstSectionSets = firstSectionSets
            }
            
            if var templateSets = movement.templateSets {
                for (setIndex, var set) in templateSets.enumerated() {
                    if let completedSet = movementCompletedSets.first(where: { $0.id == set.id }) {
                        set.completed = completedSet.completed
                        set.reps = completedSet.reps
                        set.weight = completedSet.weight
                        set.duration = completedSet.duration
                        templateSets[setIndex] = set
                    }
                }
                movements[index].templateSets = templateSets
            }
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            self.elapsedTime += 1
            self.updateTimerLabel()
        }
    }
    
    private func updateTimerLabel() {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        timerLabel.text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // MARK: - User Actions
    @objc private func pauseButtonTapped() {
        isPaused.toggle()
        updatePauseButton()
        
        if isPaused {
            timer?.invalidate()
            gymTracker.pauseWorkout()
        } else {
            startTimer()
            gymTracker.resumeWorkout()
        }
    }
    
    private func updatePauseButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        let imageName = isPaused ? "play.circle.fill" : "pause.circle.fill"
        pauseButton.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
    }
    
    @objc private func endButtonTapped() {
        let alert = UIAlertController(
            title: "End Workout",
            message: "What would you like to do with this workout?",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "Save Workout", style: .default) { [weak self] _ in
            self?.saveWorkout()
        })
        
        alert.addAction(UIAlertAction(title: "Discard Workout", style: .destructive) { [weak self] _ in
            self?.gymTracker.stopWorkout()
            self?.dismiss(animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    @objc private func addMovementButtonTapped() {
        let selectVC = SelectMovementViewController()
        selectVC.onMovementSelected = { [weak self] movement in
            guard let self = self else { return }
            
            // Add movement to session
            self.movements.append(movement)
            
            // Update session object
            if self.session.movementsInSession == nil {
                self.session.movementsInSession = []
            }
            self.session.movementsInSession?.append(movement)
            
            // Update gym tracker
            self.gymTracker.updateCurrentMovement(movement)
            
            // Update UI
            DispatchQueue.main.async {
                self.movementsTableView.reloadData()
                
                // If this was the first movement, start the timer if not already started
                if self.movements.count == 1 && self.startTime == nil {
                    self.startWorkout()
                }
            }
        }
        
        present(selectVC, animated: true)
    }
    
    @objc private func handleHeartRateUpdate(_ notification: Notification) {
        guard let heartRate = notification.userInfo?["heartRate"] as? Double else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.heartRate = heartRate
            if let heartRateLabel = self?.heartRateView.viewWithTag(100) as? UILabel {
                heartRateLabel.text = heartRate > 0 ? "\(Int(heartRate)) BPM" : "-- BPM"
            }
        }
    }
    
    // MARK: - Save Workout
    private func saveWorkout() {
        guard let userId = UserIDResolver.shared.getBestUserIdForAPI() else {
            dismiss(animated: true)
            return
        }
        
        // Stop workout in gym tracker
        gymTracker.stopWorkout()
        
        // session.id is always non-nil, but we use sessionId if available, otherwise fall back to id
        let sessionId = session.sessionId ?? session.id
        
        let duration = elapsedTime
        let activityService = ActivityService.shared
        
        // Calculate metrics - prefer gymTracker values, fallback to calculating from movements
        var totalVolume: Double = 0
        var totalSets: Int = 0
        var totalReps: Int = 0
        var totalWeight: Double = 0
        
        // Use gymTracker's completed sets for accurate metrics if available
        if !gymTracker.completedSets.isEmpty {
            totalSets = gymTracker.completedSets.count
            totalReps = gymTracker.totalReps
            totalVolume = gymTracker.totalVolume
            
            // Calculate totalWeight from completed sets
            for completedSet in gymTracker.completedSets {
                if let weight = completedSet.weight {
                    totalWeight += weight
                }
            }
        } else {
            // Fallback: calculate from movements
            for movement in movements {
                let allSets = (movement.templateSets ?? []) + 
                              (movement.firstSectionSets ?? []) + 
                              (movement.secondSectionSets ?? []) + 
                              (movement.weavedSets ?? [])
                
                for set in allSets {
                    if set.completed {
                        totalSets += 1
                        let reps = set.reps ?? 0
                        let weight = set.weight ?? 0
                        totalReps += reps
                        totalWeight += weight
                        totalVolume += Double(reps) * weight
                    }
                }
            }
        }
        
        activityService.saveSessionLog(
            userId: userId,
            originalSessionId: sessionId,
            duration: duration,
            totalVolume: totalVolume,
            totalSets: totalSets,
            totalReps: totalReps,
            totalWeight: totalWeight,
            completed: true,
            calories: calories > 0 ? calories : nil,
            notes: nil
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Workout saved successfully")
                    self?.dismiss(animated: true)
                case .failure(let error):
                    print("❌ Error saving workout: \(error.localizedDescription)")
                    self?.dismiss(animated: true)
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource & Delegate

extension NewWorkoutTrackingViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return movements.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MovementCell", for: indexPath)
        let movement = movements[indexPath.row]
        
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        
        // Clear existing subviews
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Create container stack
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Movement name
        let nameLabel = UILabel()
        nameLabel.text = movement.movement1Name ?? "Movement"
        nameLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        nameLabel.textColor = .white
        stackView.addArrangedSubview(nameLabel)
        
        // Set completion status
        let allSets = (movement.templateSets ?? []) + 
                      (movement.firstSectionSets ?? []) + 
                      (movement.secondSectionSets ?? []) + 
                      (movement.weavedSets ?? [])
        let completedCount = allSets.filter { $0.completed }.count
        let totalCount = allSets.count
        
        if totalCount > 0 {
            let statusLabel = UILabel()
            statusLabel.text = "\(completedCount)/\(totalCount) sets completed"
            statusLabel.font = .systemFont(ofSize: 14)
            statusLabel.textColor = completedCount == totalCount ? .systemGreen : UIColor.white.withAlphaComponent(0.6)
            stackView.addArrangedSubview(statusLabel)
        }
        
        cell.contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
        ])
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let movement = movements[indexPath.row]
        showingSetCompletion = movement
        
        // Get all sets for this movement
        let allSets = (movement.templateSets ?? []) + 
                      (movement.firstSectionSets ?? []) + 
                      (movement.secondSectionSets ?? []) + 
                      (movement.weavedSets ?? [])
        
        // Present set completion view
        let setCompletionView = SetCompletionView(
            movement: movement,
            sets: allSets,
            onSetCompleted: { [weak self] set, weight, reps, duration in
                guard let self = self else { return }
                
                // Complete set in gym tracker
                self.gymTracker.completeSet(
                    movement: movement,
                    set: set,
                    weight: weight,
                    reps: reps,
                    duration: duration
                )
                
                // Update current movement
                self.gymTracker.updateCurrentMovement(movement)
                
                // Update local movements array
                self.updateMovementsWithCompletedSets()
                self.movementsTableView.reloadData()
            },
            onCancel: { [weak self] in
                self?.showingSetCompletion = nil
            }
        )
        
        let hostingController = UIHostingController(rootView: setCompletionView)
        hostingController.modalPresentationStyle = .pageSheet
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        
        present(hostingController, animated: true)
    }
}

// MARK: - Set Completion View

struct SetCompletionView: View {
    let movement: movement
    let sets: [set]
    let onSetCompleted: (set, Double?, Int?, TimeInterval?) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var currentSetIndex: Int = 0
    @State private var setReps: Int = 0
    @State private var setWeight: Double = 0
    @State private var setDuration: Int = 0
    
    private var currentSet: set? {
        guard currentSetIndex < sets.count else { return nil }
        return sets[currentSetIndex]
    }
    
    private var isTimed: Bool {
        movement.isTimed
    }
    
    var body: some View {
        ZStack {
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
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(movement.movement1Name ?? "Movement")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let name2 = movement.movement2Name, !name2.isEmpty {
                        Text(name2)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text("Set \(currentSetIndex + 1) of \(sets.count)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 20)
                
                // Set Input
                VStack(spacing: 20) {
                    if isTimed {
                        // Duration input
                        VStack(spacing: 12) {
                            Text("Duration (seconds)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Stepper(value: $setDuration, in: 0...3600, step: 5) {
                                Text("\(setDuration)s")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                        }
                    } else {
                        // Reps input
                        VStack(spacing: 12) {
                            Text("Reps")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Stepper(value: $setReps, in: 0...100) {
                                Text("\(setReps)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                        }
                    }
                    
                    // Weight input
                    VStack(spacing: 12) {
                        Text("Weight (lbs)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Stepper(value: $setWeight, in: 0...1000, step: 5) {
                            Text("\(Int(setWeight))")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        if currentSetIndex > 0 {
                            currentSetIndex -= 1
                            loadSetValues()
                        } else {
                            onCancel()
                            dismiss()
                        }
                    }) {
                        Text(currentSetIndex > 0 ? "Previous" : "Cancel")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                    }
                    
                    Button(action: {
                        guard let set = currentSet else { return }
                        
                        let weight = setWeight > 0 ? setWeight : nil
                        let reps = setReps > 0 ? setReps : nil
                        let duration = isTimed && setDuration > 0 ? TimeInterval(setDuration) : nil
                        
                        onSetCompleted(set, weight, reps, duration)
                        
                        // Move to next set or dismiss
                        if currentSetIndex < sets.count - 1 {
                            currentSetIndex += 1
                            loadSetValues()
                        } else {
                            dismiss()
                        }
                    }) {
                        Text(currentSetIndex < sets.count - 1 ? "Next Set" : "Complete")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
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
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            loadSetValues()
        }
    }
    
    private func loadSetValues() {
        guard let set = currentSet else { return }
        
        // Load existing values if set is already completed
        setReps = set.reps ?? 0
        setWeight = set.weight ?? 0
        setDuration = set.duration ?? 0
        
        // If not completed, use template values
        if !set.completed {
            setReps = set.reps ?? 10
            setWeight = set.weight ?? 0
            setDuration = set.duration ?? 60
        }
    }
}

