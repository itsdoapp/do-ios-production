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

// MARK: - NewWorkoutTrackingViewController

class NewWorkoutTrackingViewController: UIViewController {
    // MARK: - Properties
    private var session: workoutSession
    private var cancellables = Set<AnyCancellable>()
    
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
        startTimer()
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
        } else {
            startTimer()
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
        // TODO: Implement movement selector
        print("Add movement tapped")
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
        guard let userId = CurrentUserService.shared.userID else {
            dismiss(animated: true)
            return
        }
        
        // session.id is always non-nil, but we use sessionId if available, otherwise fall back to id
        let sessionId = session.sessionId ?? session.id
        
        let duration = elapsedTime
        let activityService = ActivityService.shared
        
        activityService.saveSessionLog(
            userId: userId,
            originalSessionId: sessionId,
            duration: duration,
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
        cell.textLabel?.text = movement.movement1Name ?? "Movement"
        cell.textLabel?.textColor = .white
        cell.selectionStyle = .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // TODO: Show movement detail/edit
    }
}

