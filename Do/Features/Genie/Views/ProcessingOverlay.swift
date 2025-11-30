//
//  ProcessingOverlay.swift
//  Do
//
//  A loading overlay view shown during processing operations
//

import SwiftUI

struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                Text("Processing...")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(32)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
        }
    }
}


