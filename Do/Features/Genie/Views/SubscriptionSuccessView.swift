// SubscriptionSuccessView.swift
// Celebration view when subscription is successful

import SwiftUI

struct SubscriptionSuccessView: View {
    @Environment(\.dismiss) var dismiss
    let tier: PremiumTier
    let period: SubscriptionPeriod
    let monthlyTokens: Int
    
    @State private var showConfetti = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    // Do blue theme
    private let doBlue = Color(red: 0.0, green: 0.48, blue: 0.80)
    private let doBlueLight = Color(red: 0.2, green: 0.58, blue: 0.85)
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Content
            VStack(spacing: 32) {
                Spacer()
                
                // Success icon with animation
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [doBlue.opacity(0.3), doBlue.opacity(0.1), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)
                    
                    Circle()
                        .fill(doBlue)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .scaleEffect(scale)
                .opacity(opacity)
                
                // Title
                VStack(spacing: 12) {
                    Text("Welcome to")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("\(tier.name) Plan")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .opacity(opacity)
                
                // Benefits card
                VStack(alignment: .leading, spacing: 20) {
                    Text("You now have access to:")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        BenefitRow(
                            icon: "bolt.fill",
                            title: "\(monthlyTokens) tokens per month",
                            subtitle: period == .annual ? "Billed annually" : "Billed monthly"
                        )
                        
                        BenefitRow(
                            icon: "sparkles",
                            title: "All Genie AI features",
                            subtitle: "Unlimited access to AI coaching"
                        )
                        
                        BenefitRow(
                            icon: "photo.fill",
                            title: "Visual analysis",
                            subtitle: "Food logging & form checking"
                        )
                        
                        BenefitRow(
                            icon: "leaf.fill",
                            title: "Meditation generation",
                            subtitle: "Custom guided sessions"
                        )
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.05))
                )
                .padding(.horizontal, 24)
                .opacity(opacity)
                
                Spacer()
                
                // CTA Button
                Button {
                    // Post notification immediately and dismiss
                    // The notification will trigger balance refresh in all listening views
                    NotificationCenter.default.post(name: NSNotification.Name("SubscriptionUpdated"), object: nil)
                    
                    // Small delay to ensure notification is processed
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        
                        await MainActor.run {
                            dismiss()
                        }
                    }
                } label: {
                    Text("Start Using Genie")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [doBlue, doBlueLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Benefit Row
struct BenefitRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    private let doBlue = Color(red: 0.0, green: 0.48, blue: 0.80)
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(doBlue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Preview
struct SubscriptionSuccessView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionSuccessView(
            tier: .athlete,
            period: .monthly,
            monthlyTokens: 500
        )
    }
}

