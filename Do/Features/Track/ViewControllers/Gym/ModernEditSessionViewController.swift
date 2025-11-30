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
        NavigationView {
            Form {
                Section(header: Text("Session Details")) {
                    TextField("Session name", text: Binding(
                        get: { draftSession.name ?? "" },
                        set: { draftSession.name = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("Description", text: Binding(
                        get: { draftSession.description ?? "" },
                        set: { draftSession.description = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("Difficulty", text: Binding(
                        get: { draftSession.difficulty ?? "" },
                        set: { draftSession.difficulty = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section(header: Text("Duration")) {
                    HStack {
                        Text("Duration (minutes)")
                        Spacer()
                        TextField("0", value: Binding(
                            get: { Double(draftSession.duration ?? 0) },
                            set: { draftSession.duration = $0 > 0 ? Int($0) : nil }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Equipment")) {
                    if let equipment = draftSession.equipmentNeeded {
                        ForEach(equipment, id: \.self) { item in
                            Text(item)
                        }
                    } else {
                        Text("No equipment specified")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(sessionToEdit == nil ? "New Session" : "Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSession()
                    }
                    .disabled(draftSession.name?.isEmpty ?? true)
                }
            }
        }
    }
    
    private var sessionToEdit: workoutSession? {
        // Check if this is editing an existing session by comparing IDs
        return draftSession.id.isEmpty ? nil : draftSession
    }
    
    private func saveSession() {
        // Save to AWS
        guard let userId = CurrentUserService.shared.userID else {
            onCancel()
            return
        }
        
        let isEditing = sessionToEdit != nil
        
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
                    switch result {
                    case .success(let savedItem):
                        var savedSession = draftSession
                        savedSession.id = savedItem.sessionId ?? draftSession.id
                        self.onSave(savedSession)
                    case .failure(let error):
                        print("❌ Error updating session: \(error.localizedDescription)")
                        self.onCancel()
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
                    switch result {
                    case .success(let savedItem):
                        var savedSession = draftSession
                        savedSession.id = savedItem.sessionId ?? draftSession.id
                        self.onSave(savedSession)
                    case .failure(let error):
                        print("❌ Error creating session: \(error.localizedDescription)")
                        self.onCancel()
                    }
                }
            }
        }
    }
}

