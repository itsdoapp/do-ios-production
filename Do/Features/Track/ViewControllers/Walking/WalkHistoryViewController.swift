//
//  WalkHistoryViewController.swift
//  Do
//
//  View controller for displaying walking workout history
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import SwiftUI

class WalkHistoryViewController: UIViewController {
    weak var delegate: WalkHistoryDelegate?
    
    private var walkLogs: [WalkLog] = []
    private var isLoading = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadWalkHistory()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        
        title = "Walking History"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissViewController)
        )
        
        // Create SwiftUI hosting controller
        let hostingController = UIHostingController(rootView: WalkHistoryView(
            walkLogs: walkLogs,
            isLoading: isLoading,
            onSelectWalk: { [weak self] walk in
                self?.delegate?.didSelectWalk(walk)
                self?.dismiss(animated: true)
            }
        ))
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }
    
    private func loadWalkHistory() {
        isLoading = true
        
        // Fetch walking logs from ActivityService
        Task {
            do {
                guard let userId = UserIDResolver.shared.getBestUserIdForAPI() else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                
                ActivityService.shared.getWalks(userId: userId, limit: 100) { [weak self] result in
                    guard let self = self else { return }
                    
                    Task { @MainActor in
                        switch result {
                        case .success(let response):
                            guard let activities = response.data?.activities else {
                                self.walkLogs = []
                                self.isLoading = false
                                self.updateHostingController()
                                return
                            }
                            
                            // Convert AWS activities to WalkLog
                            let logs = activities.compactMap { activity -> WalkLog? in
                                guard !activity.isIndoorWalk else { return nil }
                                
                                var walkLog = WalkLog()
                                walkLog.id = activity.id
                                
                                // Parse date
                                let dateFormatter = ISO8601DateFormatter()
                                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                if let date = dateFormatter.date(from: activity.createdAt) {
                                    walkLog.createdAt = date
                                } else {
                                    dateFormatter.formatOptions = [.withInternetDateTime]
                                    walkLog.createdAt = dateFormatter.date(from: activity.createdAt)
                                }
                                
                                walkLog.createdBy = activity.userId
                                
                                // Format duration
                                let hours = Int(activity.duration) / 3600
                                let minutes = (Int(activity.duration) % 3600) / 60
                                let seconds = Int(activity.duration) % 60
                                if hours > 0 {
                                    walkLog.duration = String(format: "%d:%02d:%02d", hours, minutes, seconds)
                                } else {
                                    walkLog.duration = String(format: "%d:%02d", minutes, seconds)
                                }
                                
                                // Format distance
                                let useMetric = UserPreferences.shared.useMetricSystem
                                if useMetric {
                                    let km = activity.distance / 1000.0
                                    walkLog.distance = String(format: "%.2f km", km)
                                } else {
                                    let miles = activity.distance / 1609.34
                                    walkLog.distance = String(format: "%.2f mi", miles)
                                }
                                
                                walkLog.caloriesBurned = activity.calories
                                walkLog.walkType = activity.walkType ?? "outdoorWalk"
                                
                                // Parse activityData if available
                                if let activityDataString = activity.activityData,
                                   let data = activityDataString.data(using: .utf8) {
                                    do {
                                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                            if let avgPace = json["averagePace"] as? String {
                                                walkLog.avgPace = avgPace
                                            }
                                            if let locationData = json["locationData"] as? [[String: Any]] {
                                                walkLog.locationData = locationData
                                            }
                                            if let coordinateArray = json["coordinateArray"] as? [[String: Double]] {
                                                walkLog.coordinateArray = coordinateArray
                                            }
                                        }
                                    } catch {
                                        print("Error parsing activityData for WalkLog: \(error)")
                                    }
                                }
                                
                                return walkLog
                            }
                            
                            self.walkLogs = logs
                            self.isLoading = false
                            self.updateHostingController()
                            
                        case .failure(let error):
                            print("Error loading walk history: \(error.localizedDescription)")
                            self.isLoading = false
                            self.updateHostingController()
                        }
                    }
                }
            }
        }
    }
    
    private func updateHostingController() {
        children.forEach { child in
            if let hosting = child as? UIHostingController<WalkHistoryView> {
                hosting.rootView = WalkHistoryView(
                    walkLogs: self.walkLogs,
                    isLoading: self.isLoading,
                    onSelectWalk: { [weak self] walk in
                        self?.delegate?.didSelectWalk(walk)
                        self?.dismiss(animated: true)
                    }
                )
            }
        }
    }
    
    @objc private func dismissViewController() {
        dismiss(animated: true)
    }
}

// MARK: - Walk History Delegate

protocol WalkHistoryDelegate: AnyObject {
    func didSelectWalk(_ walk: Any)
}

// MARK: - SwiftUI View

struct WalkHistoryView: View {
    let walkLogs: [WalkLog]
    let isLoading: Bool
    let onSelectWalk: (WalkLog) -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0x0F0F23),
                    Color(hex: 0x16213E),
                    Color(hex: 0x1A1A2E)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
            } else if walkLogs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)
                    Text("No Walking Workouts")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Start tracking your walking workouts to see them here")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(walkLogs, id: \.id) { walk in
                            WalkLogCard(walk: walk)
                                .onTapGesture {
                                    onSelectWalk(walk)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Walk Log Card

struct WalkLogCard: View {
    let walk: WalkLog
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: walk.createdAt ?? Date())
    }
    
    private var formattedDuration: String {
        guard let duration = walk.duration else { return "--:--" }
        return duration
    }
    
    private var formattedDistance: String {
        guard let distance = walk.distance else { return "0.0 km" }
        return distance
    }
    
    private var formattedPace: String {
        guard let pace = walk.avgPace else { return "--:--" }
        return pace
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Walk")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 20) {
                MetricView(icon: "figure.walk", value: formattedDistance, label: "Distance")
                MetricView(icon: "clock", value: formattedDuration, label: "Duration")
                MetricView(icon: "timer", value: formattedPace, label: "Pace")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - Metric View Helper

struct MetricView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}






