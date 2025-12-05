//
//  ModernEditSessionViewController.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/26/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import SwiftUI

/// View controller for editing or creating workout sessions
class ModernEditSessionViewController: UIViewController {
    
    var sessionToEdit: workoutSession?
    var onSave: ((workoutSession) -> Void)?
    
    private var hostingController: UIHostingController<EditSessionView>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let editView = EditSessionView(
            session: sessionToEdit,
            onSave: { [weak self] savedSession in
                self?.onSave?(savedSession)
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

// MARK: - SwiftUI Edit Session View

struct EditSessionView: View {
    @State private var draftSession: workoutSession
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    let onSave: (workoutSession) -> Void
    let onCancel: () -> Void
    
    init(session existingSession: workoutSession?, onSave: @escaping (workoutSession) -> Void, onCancel: @escaping () -> Void) {
        if let existingSession = existingSession {
            self._draftSession = State(initialValue: existingSession)
        } else {
            var newSession = workoutSession()
            newSession.id = UUID().uuidString
            self._draftSession = State(initialValue: newSession)
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
    
    private var saveButtonGradient: LinearGradient {
        let color1 = Color(red: 0.976, green: 0.576, blue: 0.125)
        let color2 = Color(red: 1.0, green: 0.42, blue: 0.21)
        return LinearGradient(
            gradient: Gradient(colors: [color1, color2]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var bottomBackgroundGradient: LinearGradient {
        let baseColor = Color(red: 0.05, green: 0.05, blue: 0.08)
        let stops = [
            Gradient.Stop(color: baseColor.opacity(0), location: 0),
            Gradient.Stop(color: baseColor, location: 0.3),
            Gradient.Stop(color: baseColor, location: 1)
        ]
        return LinearGradient(
            gradient: Gradient(stops: stops),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    @ViewBuilder
    private var saveButtonBackground: some View {
        if (draftSession.name?.isEmpty ?? true) || isSaving {
            Color.gray.opacity(0.3)
        } else {
            saveButtonGradient
        }
    }
    
    // MARK: - Sub-views
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(red: 0.976, green: 0.576, blue: 0.125))
                .padding(.top, 20)
            
            Text(sessionToEdit == nil ? "New Session" : "Edit Session")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.bottom, 8)
    }
    
    private var sessionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Details")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                ModernTextField(
                    title: "Session Name",
                    text: Binding(
                        get: { draftSession.name ?? "" },
                        set: { draftSession.name = $0.isEmpty ? nil : $0 }
                    ),
                    placeholder: "e.g., Full Body Workout"
                )
                
                ModernTextEditor(
                    title: "Description",
                    placeholder: "Add a description...",
                    text: Binding(
                        get: { draftSession.description ?? "" },
                        set: { draftSession.description = $0.isEmpty ? nil : $0 }
                    ),
                    icon: "text.alignleft"
                )
                
                ModernTextField(
                    title: "Difficulty",
                    text: Binding(
                        get: { draftSession.difficulty ?? "" },
                        set: { draftSession.difficulty = $0.isEmpty ? nil : $0 }
                    ),
                    placeholder: "e.g., Intermediate"
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var durationBinding: Binding<Double> {
        Binding(
            get: { Double(draftSession.duration ?? 0) },
            set: { draftSession.duration = $0 > 0 ? Int($0) : nil }
        )
    }
    
    private var durationTextField: some View {
        TextField("0", value: durationBinding, format: .number)
            .keyboardType(.numberPad)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
    }
    
    private var durationInputRow: some View {
        HStack {
            Image(systemName: "clock.fill")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 24)
            
            Text("Duration (minutes)")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white)
            
            Spacer()
            
            durationTextField
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
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Duration")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 20)
            
            durationInputRow
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    private var saveButtonSection: some View {
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
                
                Button(action: saveSession) {
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
                .background(saveButtonBackground)
                .cornerRadius(16)
                .disabled((draftSession.name?.isEmpty ?? true) || isSaving)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(bottomBackgroundGradient)
        }
    }
    
    private var scrollContent: some View {
        VStack(spacing: 24) {
            headerView
            sessionDetailsSection
            durationSection
            movementsSection
        }
        .padding(.vertical, 20)
    }
    
    private var movementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Movements")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Button(action: {
                    // Present movement selector
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        let movementSelector = SelectMovementViewController()
                        movementSelector.modalPresentationStyle = .pageSheet
                        movementSelector.onMovementSelected = { selectedMovement in
                            if draftSession.movementsInSession == nil {
                                draftSession.movementsInSession = []
                            }
                            draftSession.movementsInSession?.append(selectedMovement)
                        }
                        rootVC.present(movementSelector, animated: true)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add Movement")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            
            if let movements = draftSession.movementsInSession, !movements.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(movements.enumerated()), id: \.element.id) { index, movement in
                        MovementRowView(
                            movement: movement,
                            onDelete: {
                                draftSession.movementsInSession?.remove(at: index)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No movements added yet")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 40)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                scrollContent
                    .padding(.bottom, 100) // Extra padding for save button
            }
            
            // Save Button (fixed at bottom)
            saveButtonSection
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var sessionToEdit: workoutSession? {
        return draftSession.id.isEmpty ? nil : draftSession
    }
    
    private func saveSession() {
        guard let userId = CurrentUserService.shared.userID else {
            errorMessage = "Please log in to save sessions"
            showError = true
            return
        }
        
        guard !(draftSession.name?.isEmpty ?? true) else {
            errorMessage = "Please enter a session name"
            showError = true
            return
        }
        
        isSaving = true
        
        // Convert movements to dictionaries with all fields including sets
        let movementsDict: [[String: Any]] = (draftSession.movementsInSession ?? []).map { movement in
            var dict: [String: Any] = ["id": movement.id, "movementId": movement.id]
            if let name = movement.movement1Name { dict["movement1Name"] = name }
            if let name2 = movement.movement2Name { dict["movement2Name"] = name2 }
            if let category = movement.category { dict["category"] = category }
            if let difficulty = movement.difficulty { dict["difficulty"] = difficulty }
            if let description = movement.description { dict["description"] = description }
            dict["isSingle"] = movement.isSingle
            dict["isTimed"] = movement.isTimed
            
            // Include sets
            if let templateSets = movement.templateSets {
                dict["templateSets"] = templateSets.map { set -> [String: Any] in
                    var setDict: [String: Any] = ["id": set.id]
                    if let reps = set.reps { setDict["reps"] = reps }
                    if let weight = set.weight { setDict["weight"] = weight }
                    if let duration = set.duration { setDict["duration"] = duration }
                    if let sec = set.duration { setDict["sec"] = sec } // Also include "sec" for compatibility
                    return setDict
                }
            }
            
            if let firstSectionSets = movement.firstSectionSets {
                dict["firstSectionSets"] = firstSectionSets.map { set -> [String: Any] in
                    var setDict: [String: Any] = ["id": set.id]
                    if let reps = set.reps { setDict["reps"] = reps }
                    if let weight = set.weight { setDict["weight"] = weight }
                    if let duration = set.duration { setDict["duration"] = duration }
                    if let sec = set.duration { setDict["sec"] = sec }
                    return setDict
                }
            }
            
            if let secondSectionSets = movement.secondSectionSets {
                dict["secondSectionSets"] = secondSectionSets.map { set -> [String: Any] in
                    var setDict: [String: Any] = ["id": set.id]
                    if let reps = set.reps { setDict["reps"] = reps }
                    if let weight = set.weight { setDict["weight"] = weight }
                    if let duration = set.duration { setDict["duration"] = duration }
                    if let sec = set.duration { setDict["sec"] = sec }
                    return setDict
                }
            }
            
            if let weavedSets = movement.weavedSets {
                dict["weavedSets"] = weavedSets.map { set -> [String: Any] in
                    var setDict: [String: Any] = ["id": set.id]
                    if let reps = set.reps { setDict["reps"] = reps }
                    if let weight = set.weight { setDict["weight"] = weight }
                    if let duration = set.duration { setDict["duration"] = duration }
                    if let sec = set.duration { setDict["sec"] = sec }
                    return setDict
                }
            }
            
            // Include equipment
            if let equipmentsNeeded = movement.equipmentsNeeded {
                dict["equipmentNeeded"] = !equipmentsNeeded.isEmpty
            }
            
            return dict
        }
        
        // Convert duration from minutes to seconds for estimatedDuration
        let estimatedDuration: Double? = draftSession.duration.map { Double($0 * 60) }
        
        let isEditing = sessionToEdit != nil
        
        if isEditing {
            // Update existing session
            AWSWorkoutService.shared.updateSession(
                userId: userId,
                sessionId: draftSession.id,
                name: draftSession.name,
                description: draftSession.description,
                movements: movementsDict,
                difficulty: draftSession.difficulty,
                estimatedDuration: estimatedDuration
            ) { result in
                DispatchQueue.main.async {
                    self.isSaving = false
                    switch result {
                    case .success(let savedItem):
                        var savedSession = self.draftSession
                        savedSession.id = savedItem.sessionId ?? self.draftSession.id
                        self.onSave(savedSession)
                    case .failure(let error):
                        print("❌ Error updating session: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        self.showError = true
                    }
                }
            }
        } else {
            // Create new session
            AWSWorkoutService.shared.createSession(
                userId: userId,
                sessionId: draftSession.id,
                name: draftSession.name ?? "",
                description: draftSession.description,
                movements: movementsDict,
                difficulty: draftSession.difficulty,
                estimatedDuration: estimatedDuration
            ) { result in
                DispatchQueue.main.async {
                    self.isSaving = false
                    switch result {
                    case .success(let savedItem):
                        var savedSession = self.draftSession
                        savedSession.id = savedItem.sessionId ?? self.draftSession.id
                        self.onSave(savedSession)
                    case .failure(let error):
                        print("❌ Error creating session: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        self.showError = true
                    }
                }
            }
        }
    }
}

// MARK: - Movement Row View

struct MovementRowView: View {
    let movement: movement
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(movement.movement1Name ?? "Unnamed Movement")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                if let name2 = movement.movement2Name, !name2.isEmpty {
                    Text(name2)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let category = movement.category {
                    Text(category)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(8)
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
