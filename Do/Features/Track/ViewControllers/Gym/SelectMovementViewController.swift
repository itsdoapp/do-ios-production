//
//  SelectMovementViewController.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/26/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import SwiftUI

/// View controller for selecting movements from a list
class SelectMovementViewController: UIViewController {
    
    var onMovementSelected: ((movement) -> Void)?
    
    private var hostingController: UIHostingController<SelectMovementView>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let selectView = SelectMovementView { [weak self] selectedMovement in
            self?.onMovementSelected?(selectedMovement)
            self?.dismiss(animated: true)
        }
        
        let hostingController = UIHostingController(rootView: selectView)
        self.hostingController = hostingController
        
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

// MARK: - SwiftUI Select Movement View

struct SelectMovementView: View {
    @State private var movements: [movement] = []
    @State private var isLoading = true
    @State private var searchText = ""
    let onMovementSelected: (movement) -> Void
    
    var filteredMovements: [movement] {
        if searchText.isEmpty {
            return movements
        }
        return movements.filter { movement in
            (movement.movement1Name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (movement.movement2Name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (movement.category?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredMovements.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No movements found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if !searchText.isEmpty {
                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredMovements) { movement in
                        MovementRow(movement: movement) {
                            onMovementSelected(movement)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search movements")
                }
            }
            .navigationTitle("Select Movement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        // Dismiss handled by parent
                    }
                }
            }
            .onAppear {
                loadMovements()
            }
        }
    }
    
    private func loadMovements() {
        let userIds = UserIDResolver.shared.getUserIdsForDataFetch()
        guard !userIds.isEmpty else {
            isLoading = false
            return
        }
        
        var allItems: [AWSWorkoutService.WorkoutItem] = []
        var existingIds = Set<String>()
        let dispatchGroup = DispatchGroup()
        
        // Load user's own movements from all IDs (Parse first, then Cognito)
        for userId in userIds {
            dispatchGroup.enter()
            AWSWorkoutService.shared.getMovements(userId: userId, limit: 100) { result in
                switch result {
                case .success(let response):
                    if let items = response.data {
                        DispatchQueue.main.async {
                            let newItems = items.filter { item in
                                guard let id = item.movementId else { return false }
                                return !existingIds.contains(id)
                            }
                            for item in newItems {
                                if let id = item.movementId {
                                    existingIds.insert(id)
                                }
                            }
                            allItems.append(contentsOf: newItems)
                        }
                    }
                case .failure(let error):
                    print("❌ Error loading user movements for ID \(userId): \(error.localizedDescription)")
                }
                dispatchGroup.leave()
            }
        }
        
        // Also load public movements
        dispatchGroup.enter()
        AWSWorkoutService.shared.getMovements(userId: nil, isPublic: true, limit: 100) { result in
            switch result {
            case .success(let response):
                if let items = response.data {
                    DispatchQueue.main.async {
                        let newItems = items.filter { item in
                            guard let id = item.movementId else { return false }
                            return !existingIds.contains(id)
                        }
                        for item in newItems {
                            if let id = item.movementId {
                                existingIds.insert(id)
                            }
                        }
                        allItems.append(contentsOf: newItems)
                    }
                }
            case .failure(let error):
                print("❌ Error loading public movements: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isLoading = false
            self.movements = allItems.compactMap { item -> movement? in
                var mov = movement()
                mov.id = item.movementId ?? UUID().uuidString
                mov.movement1Name = item.movement1Name ?? item.name
                mov.movement2Name = item.movement2Name
                mov.isSingle = item.isSingle ?? true
                mov.isTimed = item.isTimed ?? false
                mov.category = item.category
                mov.difficulty = item.difficulty
                mov.description = item.description
                
                // Parse sets if available - handle both timed and rep-based sets
                if let templateSets = item.templateSets {
                    mov.templateSets = templateSets.compactMap { dict -> set? in
                        var s = set()
                        s.id = dict["id"] as? String ?? UUID().uuidString
                        // For rep-based sets: use reps
                        s.reps = dict["reps"] as? Int
                        // For timed sets: use duration (may be stored as "sec" or "duration")
                        if let duration = dict["duration"] as? Int {
                            s.duration = duration
                        } else if let sec = dict["sec"] as? Int {
                            s.duration = sec
                        }
                        s.weight = dict["weight"] as? Double
                        return s
                    }
                }
                
                // Also parse firstSectionSets, secondSectionSets, weavedSets if available
                if let firstSectionSets = item.firstSectionSets {
                    mov.firstSectionSets = firstSectionSets.compactMap { dict -> set? in
                        var s = set()
                        s.id = dict["id"] as? String ?? UUID().uuidString
                        s.reps = dict["reps"] as? Int
                        if let duration = dict["duration"] as? Int {
                            s.duration = duration
                        } else if let sec = dict["sec"] as? Int {
                            s.duration = sec
                        }
                        s.weight = dict["weight"] as? Double
                        return s
                    }
                }
                
                return mov
            }
        }
    }
}

struct MovementRow: View {
    let movement: movement
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(movement.movement1Name ?? "Unnamed Movement")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let movement2Name = movement.movement2Name, !movement.isSingle {
                        Text(movement2Name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let category = movement.category {
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

