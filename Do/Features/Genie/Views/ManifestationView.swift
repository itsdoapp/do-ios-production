//
//  ManifestationView.swift
//  Do
//
//  Displays manifestation guidance with intention, steps, and visualization
//

import SwiftUI

struct ManifestationView: View {
    let manifestation: ManifestationAction
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Intention Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.brandOrange)
                            Text("Intention")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text(manifestation.intention)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.brandOrange.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.brandOrange.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Steps Section
                    if !manifestation.steps.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "list.number")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color.brandOrange)
                                Text("Action Steps")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 12) {
                                ForEach(Array(manifestation.steps.enumerated()), id: \.offset) { index, step in
                                    ManifestationStepCard(step: step, index: index + 1)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Visualization Section
                    if !manifestation.visualization.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color.brandOrange)
                                Text("Visualization")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text(manifestation.visualization)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
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
                    
                    // Affirmations Section
                    if !manifestation.affirmations.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "quote.bubble.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color.brandOrange)
                                Text("Supporting Affirmations")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 12) {
                                ForEach(Array(manifestation.affirmations.enumerated()), id: \.offset) { _, affirmation in
                                    ManifestationAffirmationCard(text: affirmation)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Timeframe
                    if manifestation.timeframe != "ongoing" {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.brandOrange)
                            Text("Timeframe: \(manifestation.timeframe)")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
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

struct ManifestationStepCard: View {
    let step: String
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.brandOrange)
                .frame(width: 28, height: 28)
                .background(Color.brandOrange.opacity(0.2))
                .clipShape(Circle())
            
            Text(step)
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

struct ManifestationAffirmationCard: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.brandOrange)
            
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
                .fill(Color.brandOrange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.brandOrange.opacity(0.3), lineWidth: 1)
        )
    }
}

