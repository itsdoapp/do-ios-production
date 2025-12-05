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
                    // MARK: Plan Type Explanation
                    // Day of Week (DOW) Plans:
                    //   - Uses day names as keys: "Monday", "Tuesday", "Wednesday", etc.
                    //   - Sessions repeat weekly (e.g., same workout every Monday)
                    //   - No start date needed - always shows today's workout based on current day
                    //   - Example: {"Monday": "sessionId1", "Wednesday": "sessionId2"}
                    //
                    // Numeric/Sequential Plans:
                    //   - Uses day numbers as keys: "Day 1", "Day 2", "Day 3", etc.
                    //   - Sessions progress sequentially from start date
                    //   - Requires startDate to calculate current day
                    //   - Shows progress based on days since start
                    //   - Example: {"Day 1": "sessionId1", "Day 2": "sessionId2"}
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
                    
                    // Sessions Management Section
                    sessionsManagementSection
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
    
    @State private var showingSessionSelector = false
    
    private var planToEdit: plan? {
        return draftPlan.id.isEmpty ? nil : draftPlan
    }
    
    private var sessionsManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sessions")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Button(action: {
                    showingSessionSelector = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add Session")
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
            
            if let sessions = draftPlan.sessions, !sessions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(sessions.keys.sorted()), id: \.self) { key in
                        if let sessionId = sessions[key] {
                            SessionRowView(
                                dayKey: key,
                                sessionId: sessionId,
                                isDayOfWeek: draftPlan.isDayOfTheWeekPlan ?? false,
                                onDelete: {
                                    var updatedSessions = draftPlan.sessions ?? [:]
                                    updatedSessions.removeValue(forKey: key)
                                    draftPlan.sessions = updatedSessions.isEmpty ? nil : updatedSessions
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No sessions added yet")
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
        .sheet(isPresented: $showingSessionSelector) {
            SessionSelectorView(
                isDayOfWeek: draftPlan.isDayOfTheWeekPlan ?? false,
                existingKeys: Set(draftPlan.sessions.map { Array($0.keys) } ?? []),
                onSessionSelected: { dayKey, sessionId in
                    if draftPlan.sessions == nil {
                        draftPlan.sessions = [:]
                    }
                    draftPlan.sessions?[dayKey] = sessionId
                    showingSessionSelector = false
                }
            )
        }
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

// MARK: - Session Row View

struct SessionRowView: View {
    let dayKey: String
    let sessionId: String
    let isDayOfWeek: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayKey)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(sessionId)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
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

// MARK: - Session Selector View

struct SessionSelectorView: View {
    @Environment(\.dismiss) var dismiss
    let isDayOfWeek: Bool
    let existingKeys: Set<String>
    let onSessionSelected: (String, String) -> Void
    
    @State private var selectedDay: String = ""
    @State private var selectedSessionId: String = ""
    @State private var availableSessions: [workoutSession] = []
    @State private var isLoading = true
    
    private let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    
    var body: some View {
        ZStack {
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
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Add Session to Plan")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.top, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Day Selection
                            if isDayOfWeek {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Select Day")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    ForEach(daysOfWeek, id: \.self) { day in
                                        Button(action: {
                                            selectedDay = day
                                        }) {
                                            HStack {
                                                Text(day)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                                Spacer()
                                                if selectedDay == day {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.green)
                                                }
                                            }
                                            .padding(12)
                                            .background(selectedDay == day ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                        .disabled(existingKeys.contains(day))
                                        .opacity(existingKeys.contains(day) ? 0.5 : 1.0)
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Day Number")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    TextField("Day 1", text: $selectedDay)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            
                            // Session Selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select Session")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                if availableSessions.isEmpty {
                                    Text("No sessions available. Create a session first.")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.5))
                                        .padding(20)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(12)
                                } else {
                                    ForEach(availableSessions, id: \.id) { session in
                                        Button(action: {
                                            selectedSessionId = session.id
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(session.name ?? "Unnamed Session")
                                                        .font(.system(size: 16, weight: .semibold))
                                                        .foregroundColor(.white)
                                                    if let desc = session.description {
                                                        Text(desc)
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.white.opacity(0.7))
                                                            .lineLimit(2)
                                                    }
                                                }
                                                Spacer()
                                                if selectedSessionId == session.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.green)
                                                }
                                            }
                                            .padding(12)
                                            .background(selectedSessionId == session.id ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            
                            // Add Button
                            Button(action: {
                                if !selectedDay.isEmpty && !selectedSessionId.isEmpty {
                                    onSessionSelected(selectedDay, selectedSessionId)
                                }
                            }) {
                                Text("Add to Plan")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        Group {
                                            if !selectedDay.isEmpty && !selectedSessionId.isEmpty {
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color(red: 0.3, green: 0.5, blue: 0.98),
                                                        Color(red: 0.2, green: 0.4, blue: 0.9)
                                                    ]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            } else {
                                                Color.gray.opacity(0.3)
                                            }
                                        }
                                    )
                                    .cornerRadius(12)
                            }
                            .disabled(selectedDay.isEmpty || selectedSessionId.isEmpty)
                            .padding(.top, 20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            loadSessions()
        }
    }
    
    private func loadSessions() {
        guard let userId = UserIDResolver.shared.getBestUserIdForAPI() else {
            isLoading = false
            return
        }
        
        AWSWorkoutService.shared.getSessions(userId: userId, limit: 100) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let response):
                    if let items = response.data {
                        // Convert to workoutSession objects
                        availableSessions = items.compactMap { item -> workoutSession? in
                            guard let sessionId = item.sessionId else { return nil }
                            var session = workoutSession()
                            session.id = sessionId
                            session.name = item.name
                            session.description = item.description
                            return session
                        }
                    }
                case .failure(let error):
                    print("❌ Error loading sessions: \(error.localizedDescription)")
                }
            }
        }
    }
}
