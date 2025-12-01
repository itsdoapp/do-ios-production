//
//  HikeHistoryViewController.swift
//  Do
//
//  View controller for displaying hiking workout history
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import SwiftUI

class HikeHistoryViewController: UIViewController {
    weak var delegate: HikeHistoryDelegate?
    
    private var hikeLogs: [HikeLog] = []
    private var isLoading = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadHikeHistory()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        
        title = "Hiking History"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissViewController)
        )
        
        // Create SwiftUI hosting controller
        let hostingController = UIHostingController(rootView: HikeHistoryView(
            hikeLogs: hikeLogs,
            isLoading: isLoading,
            onSelectHike: { [weak self] hike in
                self?.delegate?.didSelectHike(hike)
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
    
    private func loadHikeHistory() {
        isLoading = true
        
        // Fetch hiking logs from ActivityService
        Task {
            guard let userId = UserIDResolver.shared.getBestUserIdForAPI() else {
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }
            
            ActivityService.shared.getHikes(userId: userId, limit: 100) { [weak self] result in
                guard let self = self else { return }
                
                Task { @MainActor in
                    switch result {
                    case .success(let response):
                        guard let activities = response.data?.activities else {
                            self.hikeLogs = []
                            self.isLoading = false
                            self.updateHostingController()
                            return
                        }
                        
                        // Convert AWS activities to HikeLog
                        let logs = activities.compactMap { activity -> HikeLog? in
                            // Parse date from createdAt string
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            guard let date = formatter.date(from: activity.createdAt) else {
                                return nil
                            }
                            
                            // Format duration (convert seconds to HH:MM:SS)
                            let hours = Int(activity.duration) / 3600
                            let minutes = (Int(activity.duration) % 3600) / 60
                            let seconds = Int(activity.duration) % 60
                            let durationString: String
                            if hours > 0 {
                                durationString = String(format: "%d:%02d:%02d", hours, minutes, seconds)
                            } else {
                                durationString = String(format: "%d:%02d", minutes, seconds)
                            }
                            
                            // Format distance (convert meters to miles, then to string)
                            let distanceMiles = activity.distance / 1609.34
                            let distanceString = String(format: "%.2f mi", distanceMiles)
                            
                            // Format elevation gain (convert meters to feet, then to string)
                            let elevationGainString: String?
                            if let elevationGain = activity.elevationGain {
                                let elevationFeet = elevationGain * 3.28084
                                elevationGainString = String(format: "%.0f ft", elevationFeet)
                            } else {
                                elevationGainString = nil
                            }
                            
                            return HikeLog(
                                id: activity.id,
                                duration: durationString,
                                distance: distanceString,
                                coordinateArray: nil,
                                avgPace: nil,
                                paceValues: nil,
                                createdAt: date,
                                createdAtFormatted: nil,
                                createdBy: nil,
                                netElevation: nil,
                                elevationGain: elevationGainString,
                                elevationLoss: nil,
                                caloriesBurned: activity.calories,
                                locationData: nil,
                                routeDataUrl: activity.routeDataUrl
                            )
                        }
                        
                        self.hikeLogs = logs
                        self.isLoading = false
                        self.updateHostingController()
                        
                    case .failure(let error):
                        print("❌ Error loading hike history: \(error.localizedDescription)")
                        self.hikeLogs = []
                        self.isLoading = false
                        self.updateHostingController()
                    }
                }
            }
        }
    }
    
    private func updateHostingController() {
        self.children.forEach { child in
            if let hosting = child as? UIHostingController<HikeHistoryView> {
                hosting.rootView = HikeHistoryView(
                    hikeLogs: self.hikeLogs,
                    isLoading: self.isLoading,
                    onSelectHike: { [weak self] hike in
                        self?.delegate?.didSelectHike(hike)
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

// MARK: - Hike History Delegate

protocol HikeHistoryDelegate: AnyObject {
    func didSelectHike(_ hike: Any)
}

// MARK: - SwiftUI View

struct HikeHistoryView: View {
    let hikeLogs: [HikeLog]
    let isLoading: Bool
    let onSelectHike: (HikeLog) -> Void
    
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
            } else if hikeLogs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "figure.hiking")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)
                    Text("No Hiking Workouts")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Start tracking your hiking workouts to see them here")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(hikeLogs, id: \.id) { hike in
                            HikeLogCard(hike: hike)
                                .onTapGesture {
                                    onSelectHike(hike)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Hike Log Card

struct HikeLogCard: View {
    let hike: HikeLog
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: hike.createdAt ?? Date())
    }
    
    private var formattedDuration: String {
        guard let duration = hike.duration else { return "--:--" }
        return duration
    }
    
    private var formattedDistance: String {
        guard let distance = hike.distance else { return "0.0 km" }
        return distance
    }
    
    private var formattedPace: String {
        guard let pace = hike.avgPace else { return "--:--" }
        return pace
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hike")
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
                MetricView(icon: "figure.hiking", value: formattedDistance, label: "Distance")
                MetricView(icon: "clock", value: formattedDuration, label: "Duration")
                MetricView(icon: "timer", value: formattedPace, label: "Pace")
                if let elevation = hike.elevationGain {
                    MetricView(icon: "mountain.2", value: elevation, label: "Elevation")
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}




