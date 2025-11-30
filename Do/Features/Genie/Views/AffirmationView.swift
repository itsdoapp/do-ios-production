//
//  AffirmationView.swift
//  Do
//
//  Displays personalized affirmations with guidance
//

import SwiftUI

struct AffirmationView: View {
    let affirmation: AffirmationAction
    @Environment(\.dismiss) var dismiss
    @State private var selectedIndex = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Affirmations")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        if affirmation.frequency != "daily" {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("Frequency: \(affirmation.frequency.capitalized)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        if affirmation.category != "general" {
                            Text(affirmation.category.capitalized)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.brandOrange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.brandOrange.opacity(0.2))
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Affirmations List
                    if !affirmation.affirmations.isEmpty {
                        VStack(spacing: 16) {
                            ForEach(Array(affirmation.affirmations.enumerated()), id: \.offset) { index, affText in
                                AffirmationDisplayCard(
                                    text: affText,
                                    index: index + 1,
                                    total: affirmation.affirmations.count
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Description
                    if !affirmation.description.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How to Use")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(affirmation.description)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .lineSpacing(4)
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
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.brandBlue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.brandOrange)
                }
            }
        }
    }
}

struct AffirmationDisplayCard: View {
    let text: String
    let index: Int
    let total: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.brandOrange)
                
                Text("\(index) of \(total)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
            }
            
            Text(text)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.brandOrange.opacity(0.15),
                            Color.brandOrange.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brandOrange.opacity(0.4), lineWidth: 1.5)
        )
    }
}



