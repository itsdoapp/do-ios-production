//
//  ModernEditMovementViewController.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/26/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import SwiftUI

/// View controller for editing or creating movements
class ModernEditMovementViewController: UIViewController {
    
    var movementToEdit: movement?
    var onSave: ((movement) -> Void)?
    
    private var hostingController: UIHostingController<EditMovementView>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let editView = EditMovementView(
            movement: movementToEdit,
            onSave: { [weak self] savedMovement in
                self?.onSave?(savedMovement)
                self?.dismiss(animated: true)
            },
            onCancel: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        
        let hostingController = UIHostingController(rootView: editView)
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

// MARK: - SwiftUI Edit Movement View

struct EditMovementView: View {
    @State private var draftMovement: movement
    let onSave: (movement) -> Void
    let onCancel: () -> Void
    
    init(movement existingMovement: movement?, onSave: @escaping (movement) -> Void, onCancel: @escaping () -> Void) {
        if let existingMovement = existingMovement {
            self._draftMovement = State(initialValue: existingMovement)
        } else {
            var newMovement = movement()
            newMovement.id = UUID().uuidString
            self._draftMovement = State(initialValue: newMovement)
        }
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Primary Exercise")) {
                    TextField("Exercise name", text: Binding(
                        get: { draftMovement.movement1Name ?? "" },
                        set: { draftMovement.movement1Name = $0.isEmpty ? nil : $0 }
                    ))
                    Toggle("Single movement", isOn: Binding(
                        get: { draftMovement.isSingle },
                        set: { draftMovement.isSingle = $0 }
                    ))
                    Toggle("Timed movement", isOn: Binding(
                        get: { draftMovement.isTimed },
                        set: { draftMovement.isTimed = $0 }
                    ))
                }
                
                Section(header: Text("Secondary Exercise")) {
                    TextField("Second exercise", text: Binding(
                        get: { draftMovement.movement2Name ?? "" },
                        set: { draftMovement.movement2Name = $0.isEmpty ? nil : $0 }
                    ))
                    .disabled(draftMovement.isSingle)
                }
                
                Section(header: Text("Details")) {
                    TextField("Category", text: Binding(
                        get: { draftMovement.category ?? "" },
                        set: { draftMovement.category = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("Difficulty", text: Binding(
                        get: { draftMovement.difficulty ?? "" },
                        set: { draftMovement.difficulty = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("Description", text: Binding(
                        get: { draftMovement.description ?? "" },
                        set: { draftMovement.description = $0.isEmpty ? nil : $0 }
                    ))
                }
            }
            .navigationTitle(movementToEdit == nil ? "New Movement" : "Edit Movement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMovement()
                    }
                    .disabled(draftMovement.movement1Name?.isEmpty ?? true)
                }
            }
        }
    }
    
    private var movementToEdit: movement? {
        // Check if this is editing an existing movement by comparing IDs
        return draftMovement.id.isEmpty ? nil : draftMovement
    }
    
    private func saveMovement() {
        // Save to AWS
        guard let userId = CurrentUserService.shared.userID else {
            onCancel()
            return
        }
        
        // Convert sets to dictionaries
        let firstSectionSets = draftMovement.firstSectionSets?.map { set -> [String: Any] in
            var dict: [String: Any] = ["id": set.id]
            if let reps = set.reps { dict["reps"] = reps }
            if let weight = set.weight { dict["weight"] = weight }
            if let duration = set.duration { dict["duration"] = duration }
            return dict
        } ?? []
        
        let secondSectionSets = draftMovement.secondSectionSets?.map { set -> [String: Any] in
            var dict: [String: Any] = ["id": set.id]
            if let reps = set.reps { dict["reps"] = reps }
            if let weight = set.weight { dict["weight"] = weight }
            if let duration = set.duration { dict["duration"] = duration }
            return dict
        } ?? []
        
        let weavedSets = draftMovement.weavedSets?.map { set -> [String: Any] in
            var dict: [String: Any] = ["id": set.id]
            if let reps = set.reps { dict["reps"] = reps }
            if let weight = set.weight { dict["weight"] = weight }
            if let duration = set.duration { dict["duration"] = duration }
            return dict
        } ?? []
        
        let isEditing = movementToEdit != nil
        
        if isEditing {
            // Update existing movement
            AWSWorkoutService.shared.updateMovement(
                userId: userId,
                movementId: draftMovement.id,
                movement1Name: draftMovement.movement1Name ?? "",
                movement2Name: draftMovement.movement2Name,
                isSingle: draftMovement.isSingle,
                isTimed: draftMovement.isTimed,
                category: draftMovement.category,
                difficulty: draftMovement.difficulty,
                equipmentsNeeded: !(draftMovement.equipmentsNeeded?.isEmpty ?? true),
                description: draftMovement.description,
                tags: draftMovement.tags ?? [],
                firstSectionSets: firstSectionSets,
                secondSectionSets: secondSectionSets,
                weavedSets: weavedSets
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let savedItem):
                        var savedMovement = draftMovement
                        savedMovement.id = savedItem.movementId ?? draftMovement.id
                        self.onSave(savedMovement)
                    case .failure(let error):
                        print("❌ Error updating movement: \(error.localizedDescription)")
                        self.onCancel()
                    }
                }
            }
        } else {
            // Create new movement
            AWSWorkoutService.shared.createMovement(
                userId: userId,
                movementId: draftMovement.id,
                movement1Name: draftMovement.movement1Name ?? "",
                movement2Name: draftMovement.movement2Name,
                isSingle: draftMovement.isSingle,
                isTimed: draftMovement.isTimed,
                category: draftMovement.category,
                difficulty: draftMovement.difficulty,
                equipmentsNeeded: !(draftMovement.equipmentsNeeded?.isEmpty ?? true),
                description: draftMovement.description,
                tags: draftMovement.tags ?? [],
                firstSectionSets: firstSectionSets,
                secondSectionSets: secondSectionSets,
                weavedSets: weavedSets
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let savedItem):
                        var savedMovement = draftMovement
                        savedMovement.id = savedItem.movementId ?? draftMovement.id
                        self.onSave(savedMovement)
                    case .failure(let error):
                        print("❌ Error creating movement: \(error.localizedDescription)")
                        self.onCancel()
                    }
                }
            }
        }
    }
}

