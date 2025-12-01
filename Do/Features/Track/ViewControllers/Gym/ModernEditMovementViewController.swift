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
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
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
                    VStack(spacing: 8) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(red: 0.125, green: 0.8, blue: 0.45))
                            .padding(.top, 20)
                        
                        Text(movementToEdit == nil ? "New Movement" : "Edit Movement")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 8)
                    
                    // Primary Exercise Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Primary Exercise")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            ModernTextField(
                                title: "Exercise Name",
                                text: Binding(
                                    get: { draftMovement.movement1Name ?? "" },
                                    set: { draftMovement.movement1Name = $0.isEmpty ? nil : $0 }
                                ),
                                placeholder: "e.g., Bench Press"
                            )
                            
                            ModernToggle(
                                title: "Single Movement",
                                icon: "figure.strengthtraining.traditional",
                                isOn: Binding(
                                    get: { draftMovement.isSingle },
                                    set: { draftMovement.isSingle = $0 }
                                )
                            )
                            
                            ModernToggle(
                                title: "Timed Movement",
                                icon: "timer",
                                isOn: Binding(
                                    get: { draftMovement.isTimed },
                                    set: { draftMovement.isTimed = $0 }
                                )
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Secondary Exercise Section (only if not single)
                    if !draftMovement.isSingle {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Secondary Exercise")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 20)
                            
                            ModernTextField(
                                title: "Second Exercise",
                                text: Binding(
                                    get: { draftMovement.movement2Name ?? "" },
                                    set: { draftMovement.movement2Name = $0.isEmpty ? nil : $0 }
                                ),
                                placeholder: "e.g., Tricep Extension"
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            ModernTextField(
                                title: "Category",
                                text: Binding(
                                    get: { draftMovement.category ?? "" },
                                    set: { draftMovement.category = $0.isEmpty ? nil : $0 }
                                ),
                                placeholder: "e.g., Upper Body"
                            )
                            
                            ModernTextField(
                                title: "Difficulty",
                                text: Binding(
                                    get: { draftMovement.difficulty ?? "" },
                                    set: { draftMovement.difficulty = $0.isEmpty ? nil : $0 }
                                ),
                                placeholder: "e.g., Beginner"
                            )
                            
                            ModernTextEditor(
                                title: "Description",
                                placeholder: "Add a description...",
                                text: Binding(
                                    get: { draftMovement.description ?? "" },
                                    set: { draftMovement.description = $0.isEmpty ? nil : $0 }
                                ),
                                icon: "text.alignleft"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .padding(.vertical, 20)
            }
            
            // Save Button (fixed at bottom)
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                    }
                    
                    Button(action: saveMovement) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Save")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Group {
                            if (draftMovement.movement1Name?.isEmpty ?? true) || isSaving {
                                Color.gray.opacity(0.3)
                            } else {
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.125, green: 0.8, blue: 0.45),
                                        Color(red: 0.125, green: 0.7, blue: 0.35)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    )
                    .cornerRadius(16)
                    .disabled((draftMovement.movement1Name?.isEmpty ?? true) || isSaving)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(red: 0.05, green: 0.05, blue: 0.08).opacity(0), location: 0),
                            .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0.3),
                            .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var movementToEdit: movement? {
        // Check if this is editing an existing movement by comparing IDs
        return draftMovement.id.isEmpty ? nil : draftMovement
    }
    
    private func saveMovement() {
        guard let userId = CurrentUserService.shared.userID else {
            errorMessage = "Please log in to save movements"
            showError = true
            return
        }
        
        guard !(draftMovement.movement1Name?.isEmpty ?? true) else {
            errorMessage = "Please enter an exercise name"
            showError = true
            return
        }
        
        isSaving = true
        
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
                    self.isSaving = false
                    switch result {
                    case .success(let savedItem):
                        var savedMovement = self.draftMovement
                        savedMovement.id = savedItem.movementId ?? self.draftMovement.id
                        self.onSave(savedMovement)
                    case .failure(let error):
                        print("❌ Error updating movement: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        self.showError = true
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
                    self.isSaving = false
                    switch result {
                    case .success(let savedItem):
                        var savedMovement = self.draftMovement
                        savedMovement.id = savedItem.movementId ?? self.draftMovement.id
                        self.onSave(savedMovement)
                    case .failure(let error):
                        print("❌ Error creating movement: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        self.showError = true
                    }
                }
            }
        }
    }
}

// MARK: - Modern UI Components

struct ModernTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            TextField(placeholder, text: $text)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}


struct ModernToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

