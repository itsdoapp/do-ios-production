//
//  VisionBoardView.swift
//  Do
//
//  Displays a vision board with goals, affirmations, and visualizations
//

import SwiftUI

struct VisionBoardView: View {
    let visionBoard: VisionBoardAction
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(visionBoard.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        if !visionBoard.description.isEmpty {
                            Text(visionBoard.description)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(nil)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Goals Section
                    if !visionBoard.goals.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "target")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.doOrange)
                                Text("Goals & Aspirations")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(Array(visionBoard.goals.enumerated()), id: \.offset) { index, goal in
                                    VisionBoardGoalCard(goal: goal, index: index + 1)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Affirmations Section
                    if !visionBoard.affirmations.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "quote.bubble.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.doOrange)
                                Text("Affirmations")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(Array(visionBoard.affirmations.enumerated()), id: \.offset) { index, affirmation in
                                    VisionBoardAffirmationCard(text: affirmation)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(hex: "0F163E"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.doOrange)
                }
            }
        }
    }
}

struct VisionBoardGoalCard: View {
    let goal: String
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.doOrange)
                .frame(width: 32, height: 32)
                .background(Color.doOrange.opacity(0.2))
                .clipShape(Circle())
            
            Text(goal)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct VisionBoardAffirmationCard: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.doOrange)
            
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.doOrange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.doOrange.opacity(0.3), lineWidth: 1)
        )
    }
}


