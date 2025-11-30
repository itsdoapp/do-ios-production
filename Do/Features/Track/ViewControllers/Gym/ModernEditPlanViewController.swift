//
//  ModernEditPlanViewController.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/26/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import SwiftUI

/// View controller for editing or creating workout plans
class ModernEditPlanViewController: UIViewController {
    
    var planToEdit: plan?
    var onSave: ((plan) -> Void)?
    
    private var hostingController: UIHostingController<EditPlanView>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let editView = EditPlanView(
            plan: planToEdit,
            onSave: { [weak self] savedPlan in
                self?.onSave?(savedPlan)
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

// MARK: - SwiftUI Edit Plan View

struct EditPlanView: View {
    @State private var draftPlan: plan
    let onSave: (plan) -> Void
    let onCancel: () -> Void
    
    init(plan existingPlan: plan?, onSave: @escaping (plan) -> Void, onCancel: @escaping () -> Void) {
        if let existingPlan = existingPlan {
            self._draftPlan = State(initialValue: existingPlan)
        } else {
            var newPlan = plan()
            newPlan.id = UUID().uuidString
            self._draftPlan = State(initialValue: newPlan)
        }
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Plan Details")) {
                    TextField("Plan name", text: Binding(
                        get: { draftPlan.name },
                        set: { draftPlan.name = $0 }
                    ))
                    TextField("Description", text: Binding(
                        get: { draftPlan.description ?? "" },
                        set: { draftPlan.description = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("Difficulty", text: Binding(
                        get: { draftPlan.difficulty ?? "" },
                        set: { draftPlan.difficulty = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section(header: Text("Schedule Type")) {
                    Toggle("Day of the week plan", isOn: Binding(
                        get: { draftPlan.isDayOfTheWeekPlan ?? false },
                        set: { draftPlan.isDayOfTheWeekPlan = $0 }
                    ))
                }
                
                Section(header: Text("Equipment")) {
                    Toggle("Equipment needed", isOn: Binding(
                        get: { draftPlan.equipmentNeeded ?? false },
                        set: { draftPlan.equipmentNeeded = $0 }
                    ))
                }
            }
            .navigationTitle(planToEdit == nil ? "New Plan" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePlan()
                    }
                    .disabled(draftPlan.name.isEmpty)
                }
            }
        }
    }
    
    private var planToEdit: plan? {
        // Check if this is editing an existing plan by comparing IDs
        return draftPlan.id.isEmpty ? nil : draftPlan
    }
    
    private func savePlan() {
        // Save to AWS
        guard let userId = CurrentUserService.shared.userID else {
            onCancel()
            return
        }
        
        let isEditing = planToEdit != nil
        
        if isEditing {
            // Update existing plan
            AWSWorkoutService.shared.updatePlan(
                userId: userId,
                planId: draftPlan.id,
                name: draftPlan.name,
                description: draftPlan.description,
                sessions: draftPlan.sessions ?? [:],
                isDayOfTheWeekPlan: draftPlan.isDayOfTheWeekPlan ?? false,
                difficulty: draftPlan.difficulty,
                equipmentNeeded: draftPlan.equipmentNeeded ?? false                
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let savedItem):
                        var savedPlan = draftPlan
                        savedPlan.id = savedItem.planId ?? draftPlan.id
                        self.onSave(savedPlan)
                    case .failure(let error):
                        print("❌ Error updating plan: \(error.localizedDescription)")
                        self.onCancel()
                    }
                }
            }
        } else {
            // Create new plan
            AWSWorkoutService.shared.createPlan(
                userId: userId,
                planId: draftPlan.id,
                name: draftPlan.name,
                description: draftPlan.description,
                sessions: draftPlan.sessions ?? [:],
                isDayOfTheWeekPlan: draftPlan.isDayOfTheWeekPlan ?? false,
                difficulty: draftPlan.difficulty,
                equipmentNeeded: draftPlan.equipmentNeeded ?? false
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let savedItem):
                        var savedPlan = draftPlan
                        savedPlan.id = savedItem.planId ?? draftPlan.id
                        self.onSave(savedPlan)
                    case .failure(let error):
                        print("❌ Error creating plan: \(error.localizedDescription)")
                        self.onCancel()
                    }
                }
            }
        }
    }
}

