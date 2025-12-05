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
    
    private var backgroundGradient: LinearGradient {
        let color1 = Color(red: 0.05, green: 0.05, blue: 0.08)
        let color2 = Color(red: 0.08, green: 0.08, blue: 0.12)
        let color3 = Color(red: 0.1, green: 0.1, blue: 0.15)
        let stops = [
            Gradient.Stop(color: color1, location: 0),
            Gradient.Stop(color: color2, location: 0.5),
            Gradient.Stop(color: color3, location: 1)
        ]
        return LinearGradient(
            gradient: Gradient(stops: stops),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
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
                            
                            ModernToggle(
                                title: "Equipment Needed",
                                icon: "wrench.and.screwdriver.fill",
                                isOn: Binding(
                                    get: { !(draftMovement.equipmentsNeeded?.isEmpty ?? true) },
                                    set: { draftMovement.equipmentsNeeded = $0 ? ["Equipment needed"] : [] }
                                )
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Sets Management Section
                    SetsManagementSection(
                        draftMovement: $draftMovement
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .padding(.vertical, 20)
                .padding(.bottom, 100) // Extra padding for save button
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
        
        // Convert sets to dictionaries - include both "duration" and "sec" for timed sets
        let firstSectionSets = draftMovement.firstSectionSets?.map { set -> [String: Any] in
            var dict: [String: Any] = ["id": set.id]
            if let reps = set.reps { dict["reps"] = reps }
            if let weight = set.weight { dict["weight"] = weight }
            if let duration = set.duration {
                dict["duration"] = duration
                dict["sec"] = duration // Also include "sec" for compatibility
            }
            return dict
        } ?? []
        
        let secondSectionSets = draftMovement.secondSectionSets?.map { set -> [String: Any] in
            var dict: [String: Any] = ["id": set.id]
            if let reps = set.reps { dict["reps"] = reps }
            if let weight = set.weight { dict["weight"] = weight }
            if let duration = set.duration {
                dict["duration"] = duration
                dict["sec"] = duration
            }
            return dict
        } ?? []
        
        let weavedSets = draftMovement.weavedSets?.map { set -> [String: Any] in
            var dict: [String: Any] = ["id": set.id]
            if let reps = set.reps { dict["reps"] = reps }
            if let weight = set.weight { dict["weight"] = weight }
            if let duration = set.duration {
                dict["duration"] = duration
                dict["sec"] = duration
            }
            return dict
        } ?? []
        
        let templateSets = draftMovement.templateSets?.map { set -> [String: Any] in
            var dict: [String: Any] = ["id": set.id]
            if let reps = set.reps { dict["reps"] = reps }
            if let weight = set.weight { dict["weight"] = weight }
            if let duration = set.duration {
                dict["duration"] = duration
                dict["sec"] = duration // Also include "sec" for compatibility
            }
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
                templateSets: templateSets,
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
                templateSets: templateSets,
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

// MARK: - Sets Management Section

struct SetsManagementSection: View {
    @Binding var draftMovement: movement
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sets Configuration")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 20)
            
            if draftMovement.isSingle {
                // Single Movement: Use templateSets or firstSectionSets
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sets")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                    
                    SetsManagementView(
                        sets: Binding(
                            get: { draftMovement.templateSets ?? draftMovement.firstSectionSets ?? [] },
                            set: { newSets in
                                if newSets.isEmpty {
                                    draftMovement.templateSets = nil
                                    draftMovement.firstSectionSets = nil
                                } else {
                                    // Prefer templateSets for single movements
                                    draftMovement.templateSets = newSets
                                    draftMovement.firstSectionSets = nil
                                }
                            }
                        ),
                        isTimed: draftMovement.isTimed,
                        sectionName: "Sets"
                    )
                }
            } else {
                // Compound Movement: Use firstSectionSets, secondSectionSets, and weavedSets
                VStack(alignment: .leading, spacing: 16) {
                    // First Movement Sets
                    if let movement1Name = draftMovement.movement1Name {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(movement1Name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            SetsManagementView(
                                sets: Binding(
                                    get: { draftMovement.firstSectionSets ?? [] },
                                    set: { draftMovement.firstSectionSets = $0.isEmpty ? nil : $0 }
                                ),
                                isTimed: draftMovement.isTimed,
                                sectionName: movement1Name
                            )
                        }
                    }
                    
                    // Second Movement Sets
                    if let movement2Name = draftMovement.movement2Name {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(movement2Name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            SetsManagementView(
                                sets: Binding(
                                    get: { draftMovement.secondSectionSets ?? [] },
                                    set: { draftMovement.secondSectionSets = $0.isEmpty ? nil : $0 }
                                ),
                                isTimed: draftMovement.isTimed,
                                sectionName: movement2Name
                            )
                        }
                    }
                    
                    // Weaved Sets (alternating between movements)
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("Weaved Sets")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                            
                            Text("Alternate between \(draftMovement.movement1Name ?? "Movement 1") and \(draftMovement.movement2Name ?? "Movement 2")")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                                .italic()
                        }
                        .padding(.horizontal, 20)
                        
                        SetsManagementView(
                            sets: Binding(
                                get: { draftMovement.weavedSets ?? [] },
                                set: { draftMovement.weavedSets = $0.isEmpty ? nil : $0 }
                            ),
                            isTimed: draftMovement.isTimed,
                            sectionName: "Weaved Sets"
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Sets Management View

struct SetsManagementView: View {
    @Binding var sets: [set]
    let isTimed: Bool
    let sectionName: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Sets List
            if sets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No sets added yet")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            } else {
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, setItem in
                    EditableSetRowView(
                        setItem: Binding(
                            get: { sets[index] },
                            set: { sets[index] = $0 }
                        ),
                        isTimed: isTimed,
                        setNumber: index + 1,
                        onDelete: {
                            sets.remove(at: index)
                        }
                    )
                    .padding(.horizontal, 20)
                }
            }
            
            // Add Set Button
            Button(action: {
                var newSet = set()
                newSet.id = UUID().uuidString
                if isTimed {
                    newSet.duration = 60 // Default 60 seconds
                } else {
                    newSet.reps = 10 // Default 10 reps
                }
                sets.append(newSet)
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Add Set")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
        }
    }
}

struct EditableSetRowView: View {
    @Binding var setItem: set
    let isTimed: Bool
    var setNumber: Int? = nil
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            // Set Number Badge (more compact)
            if let setNumber = setNumber {
                Text("\(setNumber)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.15))
                    )
            }
            
            // Reps or Duration - more compact layout
            if isTimed {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                        TextField("60", value: $setItem.duration, format: .number)
                            .keyboardType(.numberPad)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 60)
                    }
                    
                    Text("sec")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "repeat")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reps")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                        TextField("10", value: $setItem.reps, format: .number)
                            .keyboardType(.numberPad)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            }
            
            // Weight - more compact
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weight")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                    TextField("0", value: $setItem.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50)
                }
                
                Text("lbs")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .frame(maxWidth: .infinity)
            
            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

