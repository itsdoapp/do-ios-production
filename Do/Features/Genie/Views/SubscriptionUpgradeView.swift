// SubscriptionUpgradeView.swift
// Premium subscription management with modern design and accurate pricing

import SwiftUI
@_spi(STP) import StripePaymentSheet

struct SubscriptionUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SubscriptionViewModel()
    @State private var selectedTier: PremiumTier
    @State private var selectedPeriod: SubscriptionPeriod
    @State private var showingPayment = false
    @State private var showingSuccess = false
    @State private var successTier: PremiumTier?
    @State private var successPeriod: SubscriptionPeriod?
    @State private var successTokens: Int = 0
    
    init(initialTier: PremiumTier = .athlete, initialPeriod: SubscriptionPeriod = .monthly) {
        _selectedTier = State(initialValue: initialTier)
        _selectedPeriod = State(initialValue: initialPeriod)
    }
    
    // Get available tiers (only higher than current)
    private var availableTiers: [PremiumTier] {
        let currentTier = viewModel.currentSubscription?.tier ?? .free
        let allTiers = PremiumTier.allCases.filter { $0 != .free }
        
        // Return only tiers higher than current
        switch currentTier {
        case .free:
            return allTiers // Show all tiers for free users
        case .athlete:
            return allTiers.filter { $0 == .champion || $0 == .legend }
        case .champion:
            return allTiers.filter { $0 == .legend }
        case .legend:
            return [] // No higher tiers available
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero section
                    heroSection
                        .padding(.bottom, 32)
                    
                    // Current status (if subscribed)
                    if viewModel.currentSubscription != nil {
                        currentStatusCard
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                    }
                    
                    // Period toggle
                    periodToggle
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    
                    // Subscription tiers - only show tiers higher than current
                    VStack(spacing: 16) {
                        ForEach(availableTiers, id: \.self) { tier in
                            SubscriptionTierCard(
                                tier: tier,
                                period: selectedPeriod,
                                isSelected: selectedTier == tier,
                                isCurrent: viewModel.currentSubscription?.tier == tier
                            ) {
                                selectedTier = tier
                            }
                        }
                        
                        if availableTiers.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.orange)
                                Text("You're on the highest tier!")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("You already have access to all premium features.")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    
                    // CTA Button
                    if viewModel.currentSubscription == nil || viewModel.currentSubscription?.tier != selectedTier {
                        ctaButton
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                    }
                    
                    // Features comparison
                    featuresSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    
                    // FAQ / Info
                    infoSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
            .background(
                ZStack {
                    // Deep space gradient base
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.02, green: 0.02, blue: 0.08),
                            Color.black
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Glowing orbs for depth
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.orange.opacity(0.2),
                                    Color.orange.opacity(0.05),
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 350
                            )
                        )
                        .frame(width: 500, height: 500)
                        .offset(x: -150, y: -200)
                        .blur(radius: 40)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.purple.opacity(0.15),
                                    Color.purple.opacity(0.03),
                                    Color.clear
                                ],
                                center: .bottomTrailing,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                        .frame(width: 400, height: 400)
                        .offset(x: 150, y: 200)
                        .blur(radius: 50)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 300, height: 300)
                        .blur(radius: 30)
                }
                .ignoresSafeArea()
            )
            .navigationTitle("Genie Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .task {
                await viewModel.loadSubscription()
            }
            .sheet(isPresented: $showingPayment) {
                SubscriptionPaymentSheet(
                    tier: selectedTier,
                    period: selectedPeriod,
                    onSuccess: { tier, period, tokens in
                        showingPayment = false
                        successTier = tier
                        successPeriod = period
                        successTokens = tokens
                        
                        // Post notification immediately so all views know subscription was created
                        NotificationCenter.default.post(name: NSNotification.Name("SubscriptionUpdated"), object: nil)
                        
                        // Poll for subscription update with exponential backoff
                        // This handles DynamoDB eventual consistency delays
                        Task {
                            let maxRetries = 8
                            var attempt = 0
                            var foundSubscription = false
                            
                            // Initial small delay to allow write to propagate
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            
                            while attempt < maxRetries && !foundSubscription {
                                // Reload subscription data
                                await viewModel.loadSubscription()
                                
                                // Check if subscription has been updated
                                let currentTier = viewModel.currentTier.lowercased()
                                let expectedTier = tier.rawValue.lowercased()
                                
                                print("🔄 [Subscription] Poll attempt \(attempt + 1)/\(maxRetries): currentTier=\(currentTier), expectedTier=\(expectedTier), allowance=\(viewModel.monthlyAllowance)")
                                
                                if currentTier == expectedTier && viewModel.monthlyAllowance > 0 {
                                    print("✅ [Subscription] Subscription confirmed in database!")
                                    foundSubscription = true
                                } else {
                                    attempt += 1
                                    if attempt < maxRetries {
                                        // Exponential backoff: 1s, 2s, 4s, 4s, 4s...
                                        let seconds: UInt64
                                        switch attempt {
                                        case 1: seconds = 1
                                        case 2: seconds = 2
                                        default: seconds = 4
                                        }
                                        let delay = seconds * 1_000_000_000
                                        print("⏳ [Subscription] Subscription not yet visible, retrying in \(seconds)s...")
                                        try? await Task.sleep(nanoseconds: delay)
                                    }
                                }
                            }
                            
                            if foundSubscription {
                                print("✅ [Subscription] Successfully verified subscription is active")
                            } else {
                                print("⚠️ [Subscription] Subscription verification timeout after \(attempt) attempts, but proceeding anyway")
                            }
                            
                            // Post notification again after data is refreshed
                            NotificationCenter.default.post(name: NSNotification.Name("SubscriptionUpdated"), object: nil)
                            
                            showingSuccess = true
                        }
                    }
                )
            }
            .fullScreenCover(isPresented: $showingSuccess) {
                if let tier = successTier, let period = successPeriod {
                    SubscriptionSuccessView(
                        tier: tier,
                        period: period,
                        monthlyTokens: successTokens
                    )
                    .onDisappear {
                        // Reload subscription when success view dismisses
                        Task {
                            await viewModel.loadSubscription()
                            // Post notification and dismiss after a short delay
                            NotificationCenter.default.post(name: NSNotification.Name("SubscriptionUpdated"), object: nil)
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            await MainActor.run {
                                dismiss()
                            }
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SubscriptionUpdated"))) { _ in
                // Reload subscription when notification is received
                Task {
                    await viewModel.loadSubscription()
                }
            }
            .overlay {
                if viewModel.isProcessing {
                    ProcessingOverlay()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.orange)
                }
                .padding(.top, 20)
                
                // Title
                VStack(spacing: 8) {
                    Text("Unlock Your Full Potential")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("AI-powered coaching that learns from every workout")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 220)
    }
    
    // MARK: - Current Status Card
    private var currentStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text(viewModel.currentSubscription?.tier.name ?? "Free")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let tier = viewModel.currentSubscription?.tier, tier != .free {
                            Text("• \(viewModel.currentSubscription?.period.displayName ?? "")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Token balance
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(viewModel.tokensRemaining)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("tokens left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Usage bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Monthly Usage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(viewModel.tokensUsedThisMonth) of \(viewModel.monthlyAllowance) used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange, Color.orange.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * viewModel.usagePercentage)
                    }
                }
                .frame(height: 8)
            }
            
            // Renewal info
            if let renewalDate = viewModel.currentSubscription?.renewalDate {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("Renews on \(renewalDate, style: .date)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Period Toggle
    private var periodToggle: some View {
        HStack(spacing: 0) {
            ForEach([SubscriptionPeriod.monthly, SubscriptionPeriod.annual], id: \.self) { period in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPeriod = period
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(period.displayName)
                            .font(.subheadline)
                            .fontWeight(selectedPeriod == period ? .semibold : .regular)
                        
                        if period == .annual {
                            Text("Save 2 months")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedPeriod == period ? Color.orange.opacity(0.15) : Color.clear)
                    .foregroundColor(selectedPeriod == period ? .orange : .secondary)
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - CTA Button
    private var ctaButton: some View {
        Button {
            showingPayment = true
        } label: {
            VStack(spacing: 4) {
                Text("Subscribe to \(selectedTier.name)")
                    .fontWeight(.semibold)
                
                Text(priceDisplay)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.orange, Color.orange.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: Color.orange.opacity(0.3), radius: 10, y: 5)
        }
    }
    
    private var priceDisplay: String {
        let price = selectedPeriod == .monthly ? selectedTier.monthlyPrice : selectedTier.annualPrice
        let formatted = String(format: "$%.2f", Double(price) / 100.0)
        let period = selectedPeriod == .monthly ? "/month" : "/year"
        return "\(formatted)\(period)"
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Included")
                .font(.title3)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                SubscriptionFeatureRow(icon: "bolt.fill", title: "AI-Powered Coaching", description: "Personalized insights from your workouts")
                SubscriptionFeatureRow(icon: "photo", title: "Visual Analysis", description: "Food logging and form checking")
                SubscriptionFeatureRow(icon: "leaf.fill", title: "Meditation Generation", description: "Custom guided sessions for you")
                SubscriptionFeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking", description: "Detailed analytics and trends")
                SubscriptionFeatureRow(icon: "brain.head.profile", title: "Learning AI", description: "Gets smarter with every interaction")
            }
        }
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            InfoItem(
                icon: "arrow.clockwise",
                text: "Cancel anytime. No commitments."
            )
            
            InfoItem(
                icon: "checkmark.shield.fill",
                text: "Tokens never expire. Keep them forever."
            )
            
            InfoItem(
                icon: "creditcard.fill",
                text: "Secure payment via Stripe."
            )
        }
    }
}

// MARK: - Subscription Tier Card
struct SubscriptionTierCard: View {
    let tier: PremiumTier
    let period: SubscriptionPeriod
    let isSelected: Bool
    let isCurrent: Bool
    let onSelect: () -> Void
    
    // Do blue theme
    private let doBlue = Color(red: 0.0, green: 0.48, blue: 0.80) // #007ACC
    private let doBlueLight = Color(red: 0.2, green: 0.58, blue: 0.85)
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 20) {
                // Header with badge and price
                VStack(alignment: .leading, spacing: 12) {
                    // Tier name and badge
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tier.name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            if let badge = tier.badge {
                                Text(badge)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(Color.orange.opacity(0.2))
                                    )
                            }
                        }
                        
                        Spacer()
                        
                        // Selection indicator
                        if isSelected {
                            Circle()
                                .fill(doBlue)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        } else {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 28, height: 28)
                        }
                    }
                    
                    // Price section
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(priceDisplay)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(period == .monthly ? "/mo" : "/yr")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            if period == .annual {
                                Text("Save \(annualSavings)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    // Token allocation - prominent
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(doBlue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(tier.monthlyTokens) tokens")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("≈ \(tokensPerDay) per day")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                
                // Features - improved layout
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(tier.features.prefix(4), id: \.self) { feature in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                                .frame(width: 20)
                            
                            Text(feature)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(2)
                        }
                    }
                }
                
                // Current badge
                if isCurrent {
                    HStack {
                        Spacer()
                        Text("CURRENT PLAN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.2))
                            )
                    }
                }
            }
            .padding(24)
            .background(
                ZStack {
                    // Glassmorphism background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.05))
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    // Selected glow with Do blue
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        doBlue,
                                        doBlueLight
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    }
                }
            )
            .shadow(
                color: isSelected ? doBlue.opacity(0.4) : Color.black.opacity(0.2),
                radius: isSelected ? 20 : 10,
                y: isSelected ? 10 : 5
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var priceDisplay: String {
        let price = period == .monthly ? tier.monthlyPrice : tier.annualPrice
        return String(format: "$%.0f", Double(price) / 100.0)
    }
    
    private var tokensPerDay: Int {
        tier.monthlyTokens / 30
    }
    
    private var annualSavings: String {
        let monthlyCost = tier.monthlyPrice * 12
        let annualCost = tier.annualPrice
        let savings = monthlyCost - annualCost
        return String(format: "$%.0f", Double(savings) / 100.0)
    }
}

// MARK: - Feature Row
private struct SubscriptionFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Info Item
struct InfoItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - View Model
@MainActor
class SubscriptionViewModel: ObservableObject {
    @Published var currentSubscription: UserSubscription?
    @Published var currentTier: String = "free"
    @Published var tokensRemaining: Int = 0
    @Published var tokensUsedThisMonth: Int = 0
    @Published var monthlyAllowance: Int = 0
    @Published var isProcessing = false
    
    var usagePercentage: Double {
        guard monthlyAllowance > 0 else { return 0 }
        return min(1.0, Double(tokensUsedThisMonth) / Double(monthlyAllowance))
    }
    
    func loadSubscription() async {
        do {
            // Load from AWS - get full subscription details
            let response = try await GenieAPIService.shared.getTokenBalance()
            tokensRemaining = response.balance
            
            if let subscription = response.subscription {
                // Use actual subscription data from backend
                currentTier = subscription.tier
                monthlyAllowance = subscription.monthlyAllowance
                tokensUsedThisMonth = subscription.tokensUsedThisMonth
                
                print("✅ [Subscription] Loaded: tier=\(subscription.tier), allowance=\(subscription.monthlyAllowance), used=\(subscription.tokensUsedThisMonth), remaining=\(subscription.tokensRemainingThisMonth), topup=\(subscription.topUpBalance)")
            } else {
                // No subscription data - user is on free tier
                currentTier = "free"
                monthlyAllowance = 0
                tokensUsedThisMonth = 0
                print("ℹ️ [Subscription] No subscription - free tier")
            }
        } catch {
            print("❌ [Subscription] Error loading: \(error)")
            // Default to free tier on error
            currentTier = "free"
            monthlyAllowance = 0
            tokensUsedThisMonth = 0
        }
    }
}

// MARK: - Subscription Payment Sheet

struct SubscriptionPaymentSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SubscriptionPaymentViewModel()
    
    let tier: PremiumTier
    let period: SubscriptionPeriod
    let onSuccess: (PremiumTier, SubscriptionPeriod, Int) -> Void
    
    @State private var paymentSheet: StripePaymentSheet.PaymentSheet?
    @State private var isLoadingPaymentSheet = false
    
    // Brand colors (matching SmartTokenUpsellView)
    private let doBlue = Color(red: 0.06, green: 0.09, blue: 0.24) // #0F163E
    private let doOrange = Color(red: 0.969, green: 0.576, blue: 0.122) // #F7931F
    private let doOrangeLight = Color(red: 1.0, green: 0.42, blue: 0.21)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Subscription summary
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .padding(.top, 40)
                        
                        Text(tier.name)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(priceDisplay)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("\(tier.monthlyTokens) tokens/month")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.vertical, 8)
                    
                    // Information text
                    Text("Tap below to securely enter your payment information")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    // Subscribe button - opens Stripe PaymentSheet
                    Button(action: {
                        if let sheet = paymentSheet {
                            sheet.present(from: getRootViewController()) { result in
                                viewModel.handlePaymentResult(result, tier: tier, period: period, onSuccess: onSuccess)
                            }
                        } else {
                            // Load payment sheet first
                            loadPaymentSheet()
                        }
                    }) {
                        HStack(spacing: 12) {
                            if isLoadingPaymentSheet || viewModel.isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "creditcard.fill")
                                Text("Enter Payment Details")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [doOrange, doOrangeLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoadingPaymentSheet || viewModel.isProcessing)
                    .padding(.horizontal, 20)
                    
                    // Terms
                    Text("By subscribing, you agree to our Terms of Service. Subscription renews automatically and can be cancelled anytime.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    
                    // Secure payment badge
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("Secured by Stripe")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 32)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [doBlue, Color.black]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Complete Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .alert("Payment Failed", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .onAppear {
            loadPaymentSheet()
        }
    }
    
    private var priceDisplay: String {
        let price = period == .monthly ? tier.monthlyPrice : tier.annualPrice
        let formatted = String(format: "$%.2f", Double(price) / 100.0)
        return period == .monthly ? "\(formatted)/month" : "\(formatted)/year"
    }
    
    private func loadPaymentSheet() {
        isLoadingPaymentSheet = true
        Task {
            do {
                let setupIntentResponse = try await GenieAPIService.shared.createSetupIntent()
                
                var configuration = StripePaymentSheet.PaymentSheet.Configuration()
                configuration.merchantDisplayName = "Do."
                configuration.allowsDelayedPaymentMethods = true
                configuration.returnURL = "do-app://stripe-redirect"
                
                // Enable Apple Pay
                let applePayConfig = StripePaymentSheet.PaymentSheet.ApplePayConfiguration(
                    merchantId: "merchant.com.doapp",
                    merchantCountryCode: "US",
                    buttonType: .plain
                )
                configuration.applePay = applePayConfig
                
                await MainActor.run {
                    self.paymentSheet = StripePaymentSheet.PaymentSheet(
                        setupIntentClientSecret: setupIntentResponse.clientSecret,
                        configuration: configuration
                    )
                    self.isLoadingPaymentSheet = false
                    print("✅ [Payment] PaymentSheet loaded successfully")
                }
            } catch {
                await MainActor.run {
                    self.isLoadingPaymentSheet = false
                    self.viewModel.errorMessage = "Failed to load payment form: \(error.localizedDescription)"
                    self.viewModel.showError = true
                    print("❌ [Payment] Failed to create setup intent: \(error)")
                }
            }
        }
    }
    
    private func getRootViewController() -> UIViewController {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = scene.windows.first?.rootViewController else {
            fatalError("No root view controller found")
        }
        
        // Get the topmost presented view controller
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        
        return topViewController
    }
}

// MARK: - Subscription Payment ViewModel
@MainActor
class SubscriptionPaymentViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    func handlePaymentResult(
        _ result: StripePaymentSheet.PaymentSheetResult,
        tier: PremiumTier,
        period: SubscriptionPeriod,
        onSuccess: @escaping (PremiumTier, SubscriptionPeriod, Int) -> Void
    ) {
        switch result {
        case .completed:
            print("✅ [Payment] Payment method collected successfully")
            // Now create the subscription with the payment method ID
            createSubscriptionWithStripe(tier: tier, period: period, onSuccess: onSuccess)
            
        case .canceled:
            print("⚠️ [Payment] User canceled payment")
            errorMessage = "Payment canceled"
            showError = true
            
        case .failed(let error):
            print("❌ [Payment] Payment failed: \(error.localizedDescription)")
            errorMessage = "Payment failed: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func createSubscriptionWithStripe(
        tier: PremiumTier,
        period: SubscriptionPeriod,
        onSuccess: @escaping (PremiumTier, SubscriptionPeriod, Int) -> Void
    ) {
        isProcessing = true
        
        Task {
            do {
                // Get price ID based on tier and period
                let priceId = period == .monthly ?
                    tier.stripeMonthlyPriceId :
                    tier.stripeAnnualPriceId
                
                // Note: The payment method ID is already attached to the customer via SetupIntent
                // We just need to pass a placeholder since the backend will use the default payment method
                let response = try await GenieAPIService.shared.createSubscription(
                    tier: tier.rawValue,
                    priceId: priceId,
                    paymentMethodId: "default"
                )
                
                print("✅ [Subscription] Created successfully: tier=\(tier.rawValue), status=\(response.status ?? "unknown")")
                
                isProcessing = false
                onSuccess(tier, period, tier.monthlyTokens)
                
            } catch {
                print("❌ [Subscription] Error: \(error)")
                errorMessage = error.localizedDescription
                showError = true
                isProcessing = false
            }
        }
    }
}

// MARK: - Payment Method Data
struct PaymentMethodData: Codable {
    let cardNumber: String
    let expMonth: Int
    let expYear: Int
    let cvc: String
    let name: String
}

// MARK: - Preview
struct SubscriptionUpgradeView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionUpgradeView()
    }
}
