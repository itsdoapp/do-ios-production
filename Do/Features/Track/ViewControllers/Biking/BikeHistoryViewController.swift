//
//  BikeHistoryViewController.swift
//  Do
//
//  View controller for displaying biking workout history
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import SwiftUI

class BikeHistoryViewController: UIViewController {
    weak var delegate: BikeHistoryDelegate?
    
    private var bikeLogs: [BikeRideLog] = []
    private var isLoading = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadBikeHistory()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        
        title = "Biking History"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissViewController)
        )
        
        // Create SwiftUI hosting controller
        let hostingController = UIHostingController(rootView: BikeHistoryView(
            bikeLogs: bikeLogs,
            isLoading: isLoading,
            onSelectBike: { [weak self] bike in
                self?.delegate?.didSelectBikeRide(bike)
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
    
    private func loadBikeHistory() {
        isLoading = true
        
        // Fetch biking logs from ActivityService
        Task {
            guard let userId = UserIDResolver.shared.getBestUserIdForAPI() else {
                await MainActor.run {
                    self.isLoading = false
                    self.updateHostingController()
                }
                return
            }
            
            ActivityService.shared.getBikes(userId: userId, limit: 100) { [weak self] result in
                guard let self = self else { return }
                
                Task { @MainActor in
                    switch result {
                    case .success(let response):
                        guard let activities = response.data?.activities else {
                            self.bikeLogs = []
                            self.isLoading = false
                            self.updateHostingController()
                            return
                        }
                        
                        // Convert AWS activities to BikeRideLog
                        let logs = activities.compactMap { activity -> BikeRideLog? in
                            var bikeLog = BikeRideLog()
                            bikeLog.id = activity.id
                            
                            // Parse date
                            let dateFormatter = ISO8601DateFormatter()
                            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            if let date = dateFormatter.date(from: activity.createdAt) {
                                bikeLog.createdAt = date
                            } else {
                                dateFormatter.formatOptions = [.withInternetDateTime]
                                bikeLog.createdAt = dateFormatter.date(from: activity.createdAt)
                            }
                            
                            bikeLog.createdBy = activity.userId
                            
                            // Format duration
                            let hours = Int(activity.duration) / 3600
                            let minutes = (Int(activity.duration) % 3600) / 60
                            let seconds = Int(activity.duration) % 60
                            if hours > 0 {
                                bikeLog.duration = String(format: "%d:%02d:%02d", hours, minutes, seconds)
                            } else {
                                bikeLog.duration = String(format: "%d:%02d", minutes, seconds)
                            }
                            
                            // Format distance
                            let useMetric = UserPreferences.shared.useMetricSystem
                            if useMetric {
                                let km = activity.distance / 1000.0
                                bikeLog.distance = String(format: "%.2f km", km)
                            } else {
                                let miles = activity.distance / 1609.34
                                bikeLog.distance = String(format: "%.2f mi", miles)
                            }
                            
                            bikeLog.caloriesBurned = activity.calories
                            
                            // Parse activityData if available
                            if let activityDataString = activity.activityData,
                               let data = activityDataString.data(using: .utf8) {
                                do {
                                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                        if let avgPace = json["averagePace"] as? String {
                                            bikeLog.avgPace = avgPace
                                        }
                                        if let bikeType = json["bikeType"] as? String {
                                            bikeLog.bikeType = bikeType
                                        }
                                        if let locationData = json["locationData"] as? [[String: Any]] {
                                            bikeLog.locationData = locationData
                                        }
                                        if let coordinateArray = json["coordinateArray"] as? [[String: Double]] {
                                            bikeLog.coordinateArray = coordinateArray
                                        }
                                    }
                                } catch {
                                    print("Error parsing activityData for BikeRideLog: \(error)")
                                }
                            }
                            
                            return bikeLog
                        }
                        
                        self.bikeLogs = logs
                        self.isLoading = false
                        self.updateHostingController()
                        
                    case .failure(let error):
                        print("Error loading bike history: \(error.localizedDescription)")
                        self.isLoading = false
                        self.updateHostingController()
                    }
                }
            }
        }
    }
    
    private func updateHostingController() {
        children.forEach { child in
            if let hosting = child as? UIHostingController<BikeHistoryView> {
                hosting.rootView = BikeHistoryView(
                    bikeLogs: self.bikeLogs,
                    isLoading: self.isLoading,
                    onSelectBike: { [weak self] bike in
                        self?.delegate?.didSelectBikeRide(bike)
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

// MARK: - SwiftUI View

struct BikeHistoryView: View {
    let bikeLogs: [BikeRideLog]
    let isLoading: Bool
    let onSelectBike: (BikeRideLog) -> Void
    
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
            } else if bikeLogs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "figure.outdoor.cycle")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)
                    Text("No Biking Workouts")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Start tracking your biking workouts to see them here")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(bikeLogs, id: \.id) { bike in
                            BikeLogCard(bike: bike)
                                .onTapGesture {
                                    onSelectBike(bike)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Bike Log Card

struct BikeLogCard: View {
    let bike: BikeRideLog
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: bike.createdAt ?? Date())
    }
    
    private var formattedDuration: String {
        guard let duration = bike.duration else { return "--:--" }
        return duration
    }
    
    private var formattedDistance: String {
        guard let distance = bike.distance else { return "0.0 km" }
        return distance
    }
    
    private var formattedSpeed: String {
        if let avgSpeed = bike.avgSpeed {
            let useMetric = UserPreferences.shared.useMetricSystem
            if useMetric {
                let kmh = avgSpeed * 1.60934
                return String(format: "%.1f km/h", kmh)
            } else {
                return String(format: "%.1f mph", avgSpeed)
            }
        }
        return "--"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bike Ride")
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
                MetricView(icon: "figure.outdoor.cycle", value: formattedDistance, label: "Distance")
                MetricView(icon: "clock", value: formattedDuration, label: "Duration")
                MetricView(icon: "speedometer", value: formattedSpeed, label: "Speed")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}


