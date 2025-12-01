//
//  IndoorOutdoorSelectionView.swift
//  Do Watch App
//
//  Indoor/Outdoor selection view for running workouts
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import WatchKit

struct IndoorOutdoorSelectionView: View {
    @Binding var isIndoor: Bool
    var onStart: () -> Void
    var onCancel: () -> Void
    
    @State private var selectedOption: SelectionOption? = nil
    
    enum SelectionOption {
        case indoor
        case outdoor
    }
    
    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [
                    Color.black.opacity(0.95),
                    Color.black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("CHOOSE YOUR RUN")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .tracking(0.5)
                    
                    Text("Select tracking mode")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
                
                // Selection Cards
                VStack(spacing: 12) {
                    // Indoor Card
                    SelectionCard(
                        icon: "house.fill",
                        title: "INDOOR",
                        subtitle: "Treadmill",
                        isSelected: selectedOption == .indoor || (selectedOption == nil && isIndoor),
                        accentColor: Color(red: 0.969, green: 0.576, blue: 0.122)
                    ) {
                        selectedOption = .indoor
                        isIndoor = true
                        WKInterfaceDevice.current().play(.click)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onStart()
                        }
                    }
                    
                    // Outdoor Card
                    SelectionCard(
                        icon: "location.fill",
                        title: "OUTDOOR",
                        subtitle: "GPS Tracked",
                        isSelected: selectedOption == .outdoor || (selectedOption == nil && !isIndoor),
                        accentColor: Color(red: 0.059, green: 0.086, blue: 0.243)
                    ) {
                        selectedOption = .outdoor
                        isIndoor = false
                        WKInterfaceDevice.current().play(.click)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onStart()
                        }
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
                
                // Cancel Button
                Button(action: {
                    WKInterfaceDevice.current().play(.click)
                    onCancel()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text("CANCEL")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(0.5)
                    }
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }
        }
    }
}

struct SelectionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
            action()
        }) {
            HStack(spacing: 12) {
                // Icon Container
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? accentColor.opacity(0.25)
                                : Color.white.opacity(0.08)
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(
                            isSelected
                                ? accentColor
                                : .white.opacity(0.7)
                        )
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.gray.opacity(0.7))
                }
                
                Spacer()
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [
                                    accentColor.opacity(0.15),
                                    accentColor.opacity(0.08)
                                ]
                                : [
                                    Color.white.opacity(0.06),
                                    Color.white.opacity(0.04)
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected
                                    ? accentColor.opacity(0.4)
                                    : Color.white.opacity(0.12),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

