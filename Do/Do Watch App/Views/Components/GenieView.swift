//
//  GenieView.swift
//  Do Watch App
//
//  AI Coach "Genie" smart tips and motivation
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct GenieView: View {
    let workoutType: String
    @ObservedObject var genieService = GenieService.shared
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Genie Avatar / Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 0)
                
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            isAnimating = true
                        }
                    }
            }
            .padding(.top)
            
            // Balance Indicator (Top Right)
            if let balance = genieService.tokenBalance {
                Text("\(balance) ⚡️")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(balance > 0 ? .yellow : .gray)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal)
                    .offset(y: -80) // Push to top right
            }
            
            Text(genieService.isOutOfTokens ? "GENIE (OFFLINE)" : "GENIE SAYS")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(genieService.isOutOfTokens ? .gray : .purple)
            
            if genieService.isLoading {
                 ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
            } else {
                // Always show the tip (smart or fallback)
                Text(genieService.currentTip ?? "Analyzing...")
                    .font(.system(size: 14, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .transition(.opacity)
                    .id(genieService.currentTip) // Force redraw on change
                
                // "Smart Fallback" Indicator
                if genieService.isOutOfTokens {
                    VStack(spacing: 4) {
                        Text("Basic Mode")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow)
                        Text("Recharge on iPhone for AI tips")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            Button(action: refreshTip) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .padding(.bottom)
            // Allow refreshing even if out of tokens (to get new local tips)
            .disabled(genieService.isLoading)
            .opacity(genieService.isLoading ? 0.5 : 1.0)
        }
        .onAppear {
            // Fetch balance on appear
            genieService.fetchBalance()
            
            // Only refresh tip if we don't have one yet
            if genieService.currentTip == nil {
                refreshTip()
            }
        }
    }
    
    private func refreshTip() {
        genieService.fetchTip(for: workoutType, metrics: nil)
    }
}
