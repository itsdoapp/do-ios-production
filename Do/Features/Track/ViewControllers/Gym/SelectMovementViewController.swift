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
        guard let userId = CurrentUserService.shared.userID else {
            isLoading = false
            return
        }
        
        AWSWorkoutService.shared.getMovements(userId: userId, limit: 100) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let response):
                    movements = (response.data ?? []).compactMap { item -> movement? in
                        var mov = movement()
                        mov.id = item.movementId ?? UUID().uuidString
                        mov.movement1Name = item.movement1Name ?? item.name
                        mov.movement2Name = item.movement2Name
                        mov.isSingle = item.isSingle ?? true
                        mov.isTimed = item.isTimed ?? false
                        mov.category = item.category
                        mov.difficulty = item.difficulty
                        mov.description = item.description
                        return mov
                    }
                case .failure(let error):
                    print("❌ Error loading movements: \(error.localizedDescription)")
                }
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

