//
//  AnalysisSharedComponents.swift
//  Do
//
//  Shared UI components for analysis views (food, equipment, etc.)
//

import SwiftUI

struct LowConfidenceCard: View {
    let confidence: Double
    let onAddDetails: () -> Void
    let onAskQuestion: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)
                Text("Low Confidence (\(Int(confidence * 100))%)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text("The analysis may not be completely accurate. You can add more details or ask questions to improve the results.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 12) {
                Button {
                    onAddDetails()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Details")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.brandOrange.opacity(0.3))
                    .cornerRadius(8)
                }
                
                Button {
                    onAskQuestion()
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                        Text("Ask Question")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.brandOrange.opacity(0.3))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct QuestionInputSheet: View {
    @Binding var questionText: String
    @Binding var isProcessing: Bool
    let onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlue
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Add details or ask a question about this to improve the analysis.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    TextField("Enter your question or details...", text: $questionText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .lineLimit(3...6)
                    
                    Button {
                        onSubmit(questionText)
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(isProcessing ? "Processing..." : "Submit")
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.brandOrange, Color("FF6B35")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .disabled(questionText.isEmpty || isProcessing)
                }
                .padding()
            }
            .navigationTitle("Improve Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}



