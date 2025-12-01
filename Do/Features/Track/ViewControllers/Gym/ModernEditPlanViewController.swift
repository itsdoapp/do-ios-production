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
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
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
                        Image(systemName: "calendar")
                            .font(.system(size: 48))
                            .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.98))
                            .padding(.top, 20)
                        
                        Text(planToEdit == nil ? "New Plan" : "Edit Plan")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 8)
                    
                    // Plan Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Plan Details")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            ModernTextField(
                                title: "Plan Name",
                                text: Binding(
                                    get: { draftPlan.name },
                                    set: { draftPlan.name = $0 }
                                ),
                                placeholder: "e.g., 4-Week Strength Program"
                            )
                            
                            ModernTextEditor(
                                title: "Description",
                                placeholder: "Add a description...",
                                text: Binding(
                                    get: { draftPlan.description ?? "" },
                                    set: { draftPlan.description = $0.isEmpty ? nil : $0 }
                                ),
                                icon: "text.alignleft"
                            )
                            
                            ModernTextField(
                                title: "Difficulty",
                                text: Binding(
                                    get: { draftPlan.difficulty ?? "" },
                                    set: { draftPlan.difficulty = $0.isEmpty ? nil : $0 }
                                ),
                                placeholder: "e.g., Advanced"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Schedule Type Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Schedule Type")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 20)
                        
                        ModernToggle(
                            title: "Day of the Week Plan",
                            icon: "calendar.badge.clock",
                            isOn: Binding(
                                get: { draftPlan.isDayOfTheWeekPlan ?? false },
                                set: { draftPlan.isDayOfTheWeekPlan = $0 }
                            )
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Equipment Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Equipment")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 20)
                        
                        ModernToggle(
                            title: "Equipment Needed",
                            icon: "wrench.and.screwdriver",
                            isOn: Binding(
                                get: { draftPlan.equipmentNeeded ?? false },
                                set: { draftPlan.equipmentNeeded = $0 }
                            )
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
                    
                    Button(action: savePlan) {
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
                            if draftPlan.name.isEmpty || isSaving {
                                Color.gray.opacity(0.3)
                            } else {
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.3, green: 0.5, blue: 0.98),
                                        Color(red: 0.2, green: 0.4, blue: 0.9)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    )
                    .cornerRadius(16)
                    .disabled(draftPlan.name.isEmpty || isSaving)
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
    
    private var planToEdit: plan? {
        return draftPlan.id.isEmpty ? nil : draftPlan
    }
    
    private func savePlan() {
        guard let userId = CurrentUserService.shared.userID else {
            errorMessage = "Please log in to save plans"
            showError = true
            return
        }
        
        guard !draftPlan.name.isEmpty else {
            errorMessage = "Please enter a plan name"
            showError = true
            return
        }
        
        isSaving = true
        
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
                    self.isSaving = false
                    switch result {
                    case .success(let savedItem):
                        var savedPlan = self.draftPlan
                        savedPlan.id = savedItem.planId ?? self.draftPlan.id
                        self.onSave(savedPlan)
                    case .failure(let error):
                        print("❌ Error updating plan: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        self.showError = true
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
                    self.isSaving = false
                    switch result {
                    case .success(let savedItem):
                        var savedPlan = self.draftPlan
                        savedPlan.id = savedItem.planId ?? self.draftPlan.id
                        self.onSave(savedPlan)
                    case .failure(let error):
                        print("❌ Error creating plan: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        self.showError = true
                    }
                }
            }
        }
    }
}
