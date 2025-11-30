//
//  AttachmentMenuView.swift
//  Modern attachment menu with icons
//

import SwiftUI

struct AttachmentMenuView: View {
    @Environment(\.dismiss) var dismiss
    
    let onSnapCalorieSelected: () -> Void
    let onEquipmentSelected: () -> Void
    let onFridgeSelected: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background
                LinearGradient(
                    colors: [
                        Color.brandBlue,
                        Color("1A2148")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with safe area padding
                    Text("Add Attachment")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                    
                    // Options grid
                    VStack(spacing: 24) {
                        // Snap Calorie option
                        AttachmentOption(
                            icon: "camera.fill",
                            title: "Snap Calorie",
                            subtitle: "Food analysis",
                            color: Color("4CAF50"),
                            gradient: [Color("4CAF50"), Color("81C784")]
                        ) {
                            onSnapCalorieSelected()
                        }
                        
                        // Equipment Detection option
                        AttachmentOption(
                            icon: "figure.strengthtraining.traditional",
                            title: "Equipment Detection",
                            subtitle: "Gym equipment scanner",
                            color: Color("2196F3"),
                            gradient: [Color("2196F3"), Color("64B5F6")]
                        ) {
                            onEquipmentSelected()
                        }
                        
                        // Show My Fridge option
                        AttachmentOption(
                            icon: "refrigerator.fill",
                            title: "Show My Fridge",
                            subtitle: "Meal suggestions from ingredients",
                            color: Color("9C27B0"),
                            gradient: [Color("9C27B0"), Color("BA68C8")]
                        ) {
                            onFridgeSelected()
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Cancel button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.height(480)])
        .presentationDragIndicator(.visible)
        .safeAreaInset(edge: .top) {
            // Extra top padding to prevent clipping
            Color.clear.frame(height: 10)
        }
    }
}

struct AttachmentOption: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let gradient: [Color]
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            print("📸 [AttachmentOption] Button tapped: \(title)")
            // Haptic feedback on tap
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
            
            // Small animation feedback
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            // Reset and trigger action
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = false
                }
                print("📸 [AttachmentOption] Calling action for: \(title)")
                action()
            }
        }) {
            HStack(spacing: 20) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                }
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isPressed ? 0.15 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isPressed ? color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: isPressed ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AttachmentMenuView(
        onSnapCalorieSelected: {},
        onEquipmentSelected: {},
        onFridgeSelected: {}
    )
}

