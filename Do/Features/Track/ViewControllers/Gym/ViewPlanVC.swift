//
//  ViewPlanVC.swift
//  Do
//
//  View controller for displaying workout plans
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import SwiftUI

class ViewPlanVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var orderOfSessions: [String] = []
    var arrayOfWorkoutSessions = [workoutSession]()
    
    // Day of the week collection view
    var dotwCollectionView: UICollectionView?
    
    // Numerical collection view
    var numericalCollectionView: UICollectionView?
    
    var dotMap = [String: AnyHashable]()
    var numberOfDaysMap = [String: AnyHashable]()
    var dotMapOld = [String: AnyHashable]()
    var numberOfDaysMapOld = [String: AnyHashable]()
    
    var isDayOfTheWeek = Bool()
    var equipmentBool = false
    
    let rateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "AvenirNext-DemiBold", size: 15)
        label.numberOfLines = 1
        label.text = "Rate this plan"
        label.textColor = .white
        label.textAlignment = .left
        return label
    }()
    
    let planNameLabel: UILabel = {
        let field = UILabel()
        field.font = UIFont(name: "AvenirNext-DemiBold", size: 18)
        field.textAlignment = .left
        field.textColor = .white
        return field
    }()
    
    let ratingInputView: RatingInputView = {
        let view = RatingInputView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    var thisPlan: plan?
    var isRated = Bool()
    var ratingValue: Int?
    var completion: ((plan) -> Void)?
    
    let descriptionView = UIView()
    let descriptionTextLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = self.uicolorFromHex(rgbValue: 0x0F163E)
        setupView()
        
        DispatchQueue.global().async {
            // Fetch all sessions from AWS service
            let userId = CurrentUserService.shared.userID
            
            Task {
                // Retrieve all sessions from AWS
                let allSessions = try await self.retrieveWorkoutSessions(containedIn: self.orderOfSessions)
                
                DispatchQueue.main.async {
                    self.arrayOfWorkoutSessions = allSessions
                    
                    if let planSessions = self.thisPlan?.sessions {
                        for sessionID in planSessions {
                            let key = sessionID.key
                            if let sessions = self.thisPlan?.sessions {
                                self.orderOfSessions = Array(sessions.values)
                            } else {
                                self.orderOfSessions = []
                            }
                            
                            if sessionID.value == "Rest Session" {
                                let sessionObject = "Rest Session"
                                if self.isDayOfTheWeek {
                                    self.dotMap[key] = sessionObject
                                } else {
                                    self.numberOfDaysMap[key] = sessionObject
                                }
                            } else if sessionID.value.contains("activity") {
                                let sessionObject = self.createActivity(from: sessionID.value)
                                if self.isDayOfTheWeek {
                                    self.dotMap[key] = sessionObject
                                } else {
                                    self.numberOfDaysMap[key] = sessionObject
                                }
                            } else {
                                let sessionObject = self.findSessionByID(sessionID.value)
                                if self.isDayOfTheWeek {
                                    self.dotMap[key] = sessionObject
                                } else {
                                    self.numberOfDaysMap[key] = sessionObject
                                }
                            }
                        }
                        
                        self.numberOfDaysMapOld = self.numberOfDaysMap
                        self.dotMapOld = self.dotMap
                    }
                    self.numericalCollectionView?.reloadData()
                    self.dotwCollectionView?.reloadData()
                }
            }
        }
    }
    
    // Function to parse the input string and create an Activity instance
    func createActivity(from input: String) -> Activity? {
        let keyValuePairs = input.split(separator: ";")
        
        var activityType: Activity.ActivityType?
        var distance: Double?
        
        for pair in keyValuePairs {
            let keyValue = pair.split(separator: ":")
            
            if keyValue.count == 2 {
                let key = keyValue[0].trimmingCharacters(in: .whitespaces)
                let value = keyValue[1].trimmingCharacters(in: .whitespaces)
                
                switch key {
                case "activityType":
                    activityType = Activity.ActivityType(rawValue: value)
                case "distance":
                    distance = Double(value)
                default:
                    break
                }
            }
        }
        
        if let activityType = activityType, let distance = distance {
            return Activity(activityType: activityType, distance: distance)
        } else {
            return nil
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if isBeingDismissed {
            if let plan = thisPlan {
                completion?(plan)
            }
            if isRated, let rating = ratingValue, let plan = thisPlan {
                saveRating(ratingValue: rating, thisPlan: plan)
            }
        }
    }
    
    // Function to find session in sessionMap by ID
    func findSessionByID(_ id: String) -> workoutSession? {
        return arrayOfWorkoutSessions.first { $0.id == id }
    }
    
    func setUpDOTWView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 20
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 20.0, left: 0.0, bottom: 80.0, right: 0.0)
        
        dotwCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        dotwCollectionView?.backgroundColor = .clear
        dotwCollectionView?.isScrollEnabled = true
        dotwCollectionView?.showsVerticalScrollIndicator = false
        dotwCollectionView?.showsHorizontalScrollIndicator = false
        
        if thisPlan?.startDate != nil && thisPlan?.isRated != true {
            view.addSubview(dotwCollectionView!)
            dotwCollectionView?.delegate = self
            dotwCollectionView?.dataSource = self
            dotwCollectionView?.translatesAutoresizingMaskIntoConstraints = false
            dotwCollectionView?.widthAnchor.constraint(equalToConstant: view.frame.width).isActive = true
            dotwCollectionView?.topAnchor.constraint(equalTo: rateLabel.bottomAnchor, constant: 20).isActive = true
            dotwCollectionView?.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
            dotwCollectionView?.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
            dotwCollectionView?.register(editPlanCell.self, forCellWithReuseIdentifier: editPlanCell.reuseIdentifier)
        } else {
            view.addSubview(dotwCollectionView!)
            dotwCollectionView?.delegate = self
            dotwCollectionView?.dataSource = self
            dotwCollectionView?.translatesAutoresizingMaskIntoConstraints = false
            dotwCollectionView?.widthAnchor.constraint(equalToConstant: view.frame.width).isActive = true
            dotwCollectionView?.topAnchor.constraint(equalTo: descriptionView.bottomAnchor, constant: 20).isActive = true
            dotwCollectionView?.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
            dotwCollectionView?.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
            dotwCollectionView?.register(editPlanCell.self, forCellWithReuseIdentifier: editPlanCell.reuseIdentifier)
        }
    }
    
    func setUpNumericalView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 20
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 20.0, left: 0.0, bottom: 80.0, right: 0.0)
        
        numericalCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        numericalCollectionView?.backgroundColor = .clear
        numericalCollectionView?.isScrollEnabled = true
        numericalCollectionView?.showsVerticalScrollIndicator = false
        numericalCollectionView?.showsHorizontalScrollIndicator = false
        
        if thisPlan?.startDate != nil && thisPlan?.isRated != true {
            view.addSubview(numericalCollectionView!)
            numericalCollectionView?.delegate = self
            numericalCollectionView?.dataSource = self
            numericalCollectionView?.translatesAutoresizingMaskIntoConstraints = false
            numericalCollectionView?.widthAnchor.constraint(equalToConstant: view.frame.width).isActive = true
            numericalCollectionView?.topAnchor.constraint(equalTo: rateLabel.bottomAnchor, constant: 20).isActive = true
            numericalCollectionView?.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
            numericalCollectionView?.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
            numericalCollectionView?.register(editPlanCell.self, forCellWithReuseIdentifier: editPlanCell.reuseIdentifier)
        } else {
            view.addSubview(numericalCollectionView!)
            numericalCollectionView?.delegate = self
            numericalCollectionView?.dataSource = self
            numericalCollectionView?.translatesAutoresizingMaskIntoConstraints = false
            numericalCollectionView?.widthAnchor.constraint(equalToConstant: view.frame.width).isActive = true
            numericalCollectionView?.topAnchor.constraint(equalTo: descriptionView.bottomAnchor, constant: 20).isActive = true
            numericalCollectionView?.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
            numericalCollectionView?.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
            numericalCollectionView?.register(editPlanCell.self, forCellWithReuseIdentifier: editPlanCell.reuseIdentifier)
        }
    }
    
    func setupView() {
        view.addSubview(planNameLabel)
        planNameLabel.translatesAutoresizingMaskIntoConstraints = false
        planNameLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 15).isActive = true
        planNameLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 15).isActive = true
        planNameLabel.widthAnchor.constraint(equalToConstant: view.frame.width - 20).isActive = true
        planNameLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        planNameLabel.text = thisPlan?.name ?? "Workout Plan"
        
        view.addSubview(descriptionView)
        descriptionView.backgroundColor = uicolorFromHex(rgbValue: 0x3D84F2).withAlphaComponent(0.1)
        descriptionView.translatesAutoresizingMaskIntoConstraints = false
        
        descriptionTextLabel.font = UIFont(name: "AvenirNext-DemiBold", size: 14)
        descriptionTextLabel.textColor = .white
        descriptionTextLabel.textAlignment = .left
        descriptionTextLabel.numberOfLines = 0
        descriptionTextLabel.lineBreakMode = .byWordWrapping
        descriptionTextLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionView.addSubview(descriptionTextLabel)
        
        descriptionTextLabel.text = thisPlan?.description ?? ""
        
        NSLayoutConstraint.activate([
            descriptionView.topAnchor.constraint(equalTo: planNameLabel.bottomAnchor, constant: 10),
            descriptionView.leadingAnchor.constraint(equalTo: planNameLabel.leadingAnchor, constant: 0),
            descriptionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            descriptionTextLabel.topAnchor.constraint(equalTo: descriptionView.topAnchor, constant: 10),
            descriptionTextLabel.leadingAnchor.constraint(equalTo: descriptionView.leadingAnchor, constant: 10),
            descriptionTextLabel.trailingAnchor.constraint(equalTo: descriptionView.trailingAnchor, constant: -20),
            descriptionTextLabel.bottomAnchor.constraint(equalTo: descriptionView.bottomAnchor, constant: -8)
        ])
        
        let charCount = thisPlan?.description?.count ?? 50
        let estimatedLines = max(1, charCount / 50)
        let heightPerLine: CGFloat = 18.0
        let estimatedHeight = CGFloat(estimatedLines) * heightPerLine
        
        descriptionView.heightAnchor.constraint(equalToConstant: estimatedHeight + 80).isActive = true
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
        self.descriptionView.layoutSubviews()
        self.descriptionView.layoutIfNeeded()
        
        if thisPlan?.startDate != nil && thisPlan?.isRated != true {
            view.addSubview(rateLabel)
            rateLabel.translatesAutoresizingMaskIntoConstraints = false
            rateLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
            rateLabel.widthAnchor.constraint(equalToConstant: 110).isActive = true
            rateLabel.topAnchor.constraint(equalTo: descriptionView.bottomAnchor, constant: 15).isActive = true
            rateLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 15).isActive = true
            
            let numOfrating = thisPlan?.numOfRating ?? 0
            let newNumOfrating = numOfrating + 1
            thisPlan?.numOfRating = newNumOfrating
            
            ratingInputView.completion = { [weak self] rating in
                guard let self = self else { return }
                let ratingAvg = self.thisPlan?.ratingValue ?? 0
                let total = (numOfrating) * Int(ratingAvg)
                let newAvg = (total + Int(rating)) / newNumOfrating
                
                if Double(newAvg) != self.thisPlan?.ratingValue {
                    self.isRated = true
                    self.ratingValue = Int(rating)
                }
                
                self.thisPlan?.ratingValue = Double(newAvg)
            }
            
            view.addSubview(ratingInputView)
            ratingInputView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                self.ratingInputView.leftAnchor.constraint(equalTo: self.rateLabel.rightAnchor, constant: 15),
                self.ratingInputView.centerYAnchor.constraint(equalTo: self.rateLabel.centerYAnchor),
                self.ratingInputView.heightAnchor.constraint(equalToConstant: 20),
                self.ratingInputView.widthAnchor.constraint(equalToConstant: 130)
            ])
        }
        
        if let isDayOfTheWeekBool = thisPlan?.isDayOfTheWeekPlan {
            self.isDayOfTheWeek = isDayOfTheWeekBool
            if isDayOfTheWeekBool {
                setUpDOTWView()
            } else {
                setUpNumericalView()
            }
        }
    }
    
    func saveRating(ratingValue: Int, thisPlan: plan) {
        // TODO: Save rating to AWS
        print("Saving rating: \(ratingValue) for plan: \(thisPlan.id)")
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == dotwCollectionView {
            return 7
        } else {
            return numberOfDaysMap.keys.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == dotwCollectionView {
            let dotwArray = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            let currentDay = dotwArray[indexPath.row]
            if let session = self.dotMap[currentDay] as? workoutSession {
                self.viewSessionSelected(session: session)
            }
        } else {
            let currentDay = "Day \(indexPath.row + 1)"
            if let session = self.numberOfDaysMap[currentDay] as? workoutSession {
                self.viewSessionSelected(session: session)
            }
        }
    }
    
    func viewSessionSelected(session: workoutSession) {
        // TODO: Show session detail view
        print("Selected session: \(session.name ?? "Unknown")")
    }
    
    // MARK: - Retrieve Sessions
    
    func retrieveWorkoutSessions(containedIn sessionIds: [String]) async throws -> [workoutSession] {
        guard !sessionIds.isEmpty else { return [] }
        
        let userId = CurrentUserService.shared.userID
        
        return try await withCheckedThrowingContinuation { continuation in
            AWSWorkoutService.shared.getSessions(
                userId: userId,
                isPublic: nil,
                category: nil,
                limit: 100
            ) { result in
                switch result {
                case .success(let response):
                    // Convert WorkoutItem to workoutSession and filter by sessionIds
                    let sessions = (response.data ?? [])
                        .filter { $0.sessionId != nil && sessionIds.contains($0.sessionId!) }
                        .compactMap { item -> workoutSession? in
                            guard let sessionId = item.sessionId else { return nil }
                            
                            var session = workoutSession()
                            session.id = sessionId
                            session.sessionId = sessionId
                            session.name = item.name
                            session.description = item.description
                            session.difficulty = item.difficulty ?? item.category
                            session.equipmentNeeded = item.equipmentNeeded != nil ? [item.equipmentNeeded! ? "Yes" : "No"] : nil
                            
                            // Parse createdAt if available
                            if let createdAtString = item.createdAt {
                                let formatter = ISO8601DateFormatter()
                                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                session.createdAt = formatter.date(from: createdAtString)
                            }
                            
                            // Convert movements if available
                            if let movementsData = item.movements ?? item.movementsInSession {
                                session.movementsInSession = movementsData.compactMap { movDict -> movement? in
                                    var mov = movement()
                                    mov.id = movDict["movementId"] as? String ?? movDict["id"] as? String ?? UUID().uuidString
                                    mov.movement1Name = movDict["movement1Name"] as? String ?? movDict["name"] as? String
                                    mov.movement2Name = movDict["movement2Name"] as? String
                                    mov.isSingle = movDict["isSingle"] as? Bool ?? true
                                    mov.isTimed = movDict["isTimed"] as? Bool ?? false
                                    mov.category = movDict["category"] as? String
                                    mov.difficulty = movDict["difficulty"] as? String
                                    mov.description = movDict["description"] as? String
                                    return mov
                                }
                            }
                            
                            return session
                        }
                    
                    continuation.resume(returning: sessions)
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == dotwCollectionView {
            let dotwArray = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            let cell = dotwCollectionView?.dequeueReusableCell(withReuseIdentifier: editPlanCell.reuseIdentifier, for: indexPath) as! editPlanCell
            
            let currentDay = dotwArray[indexPath.row]
            
            if let currentSession = dotMap[currentDay] as? workoutSession {
                cell.backgroundColor = .clear
                cell.dayLabel.text = currentDay
                cell.plusImageView.alpha = 0
                cell.boxView.alpha = 1
                cell.boxView.layer.borderColor = uicolorFromHex(rgbValue: 0xF7931F).cgColor
                cell.sessionLabel.text = currentSession.name
                cell.sessionLabel.textColor = uicolorFromHex(rgbValue: 0xF7931F)
                cell.deleteImageView.alpha = 0
                
                if let movements = currentSession.movementsInSession {
                    cell.movementCountLabel.text = "\(movements.count) Movements"
                } else {
                    cell.movementCountLabel.text = ""
                }
            } else if let restSession = dotMap[currentDay] as? String {
                if restSession == "Rest Session" {
                    cell.backgroundColor = .clear
                    cell.dayLabel.text = currentDay
                    cell.plusImageView.alpha = 0
                    cell.boxView.alpha = 1
                    cell.boxView.layer.borderColor = uicolorFromHex(rgbValue: 0x3D84F2).cgColor
                    cell.sessionLabel.text = "Rest Session"
                    cell.sessionLabel.textColor = uicolorFromHex(rgbValue: 0x3D84F2)
                    cell.movementCountLabel.text = "Take a break"
                    cell.avgTimeLabel.text = ""
                    cell.deleteImageView.alpha = 0
                }
            } else {
                cell.backgroundColor = .clear
                cell.dayLabel.text = currentDay
                cell.plusImageView.alpha = 0
                cell.boxView.alpha = 1
                cell.boxView.layer.borderColor = uicolorFromHex(rgbValue: 0x40F71F).cgColor
                cell.sessionLabel.text = "Select Session"
                cell.sessionLabel.textColor = uicolorFromHex(rgbValue: 0x40F71F)
                cell.movementCountLabel.text = "Click to add sessions"
                cell.avgTimeLabel.text = ""
                cell.deleteImageView.alpha = 0
            }
            
            return cell
        } else {
            let cell = numericalCollectionView?.dequeueReusableCell(withReuseIdentifier: editPlanCell.reuseIdentifier, for: indexPath) as! editPlanCell
            
            let currentDay = "Day \(indexPath.row + 1)"
            
            if let currentSession = numberOfDaysMap[currentDay] as? workoutSession {
                cell.backgroundColor = .clear
                cell.dayLabel.text = currentDay
                cell.plusImageView.alpha = 0
                cell.boxView.alpha = 1
                cell.boxView.layer.borderColor = uicolorFromHex(rgbValue: 0xF7931F).cgColor
                cell.sessionLabel.text = currentSession.name
                cell.sessionLabel.textColor = uicolorFromHex(rgbValue: 0xF7931F)
                cell.deleteImageView.alpha = 0
                
                if let movements = currentSession.movementsInSession {
                    cell.movementCountLabel.text = "\(movements.count) Movements"
                } else {
                    cell.movementCountLabel.text = ""
                }
            } else if let restSession = numberOfDaysMap[currentDay] as? String {
                if restSession == "Rest Session" {
                    cell.backgroundColor = .clear
                    cell.dayLabel.text = currentDay
                    cell.plusImageView.alpha = 0
                    cell.boxView.alpha = 1
                    cell.boxView.layer.borderColor = uicolorFromHex(rgbValue: 0x3D84F2).cgColor
                    cell.sessionLabel.text = "Rest Session"
                    cell.sessionLabel.textColor = uicolorFromHex(rgbValue: 0x3D84F2)
                    cell.movementCountLabel.text = "Take a break"
                    cell.avgTimeLabel.text = ""
                    cell.deleteImageView.alpha = 0
                }
            } else {
                cell.backgroundColor = .clear
                cell.dayLabel.text = currentDay
                cell.plusImageView.alpha = 0
                cell.boxView.alpha = 1
                cell.boxView.layer.borderColor = uicolorFromHex(rgbValue: 0x40F71F).cgColor
                cell.sessionLabel.text = "Select Session"
                cell.sessionLabel.textColor = uicolorFromHex(rgbValue: 0x40F71F)
                cell.movementCountLabel.text = "Click to add sessions"
                cell.avgTimeLabel.text = ""
                cell.deleteImageView.alpha = 0
            }
            
            return cell
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: view.frame.width, height: 50)
    }
}

// MARK: - Activity Model

struct Activity: Hashable {
    let activityType: ActivityType
    let distance: Double
    
    enum ActivityType: String, Hashable {
        case running = "running"
        case biking = "biking"
        case hiking = "hiking"
    }
}

