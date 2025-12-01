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
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(red: 0.976, green: 0.576, blue: 0.125))
                            .padding(.top, 20)
                        
                        Text(sessionToEdit == nil ? "New Session" : "Edit Session")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 8)
                    
                    // Session Details Section
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
                                text: Binding(
                                    get: { draftSession.description ?? "" },
                                    set: { draftSession.description = $0.isEmpty ? nil : $0 }
                                ),
                                placeholder: "Add a description...",
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
                    
                    // Duration Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Duration")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 20)
                        
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 24)
                            
                            Text("Duration (minutes)")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            TextField("0", value: Binding(
                                get: { Double(draftSession.duration ?? 0) },
                                set: { draftSession.duration = $0 > 0 ? Int($0) : nil }
                            ), format: .number)
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
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
                    .background(
                        (draftSession.name?.isEmpty ?? true) || isSaving
                            ? Color.gray.opacity(0.3)
                            : LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.976, green: 0.576, blue: 0.125),
                                    Color(red: 1.0, green: 0.42, blue: 0.21)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .cornerRadius(16)
                    .disabled((draftSession.name?.isEmpty ?? true) || isSaving)
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
        
        // Convert movements to dictionaries
        let movementsDict: [[String: Any]] = (draftSession.movementsInSession ?? []).map { movement in
            var dict: [String: Any] = ["id": movement.id]
            if let name = movement.movement1Name { dict["movement1Name"] = name }
            if let name2 = movement.movement2Name { dict["movement2Name"] = name2 }
            if let category = movement.category { dict["category"] = category }
            if let difficulty = movement.difficulty { dict["difficulty"] = difficulty }
            if let description = movement.description { dict["description"] = description }
            dict["isSingle"] = movement.isSingle
            dict["isTimed"] = movement.isTimed
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
