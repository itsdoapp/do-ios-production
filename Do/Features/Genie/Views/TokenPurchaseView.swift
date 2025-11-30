// TokenPurchaseView.swift
// Modern unified token purchase view combining subscriptions and top-ups

import SwiftUI

struct TokenPurchaseView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PurchaseViewModel()
    @State private var selectedTab: PurchaseTab = .subscriptions
    @State private var selectedPeriod: SubscriptionPeriod = .monthly
    @State private var showingSubscriptionUpgrade = false
    @State private var selectedTier: PremiumTier = .athlete
    @State private var showingTopUp = false
    
    enum PurchaseTab {
        case subscriptions
        case topUps
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Balance display
                balanceHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                
                // Tab selector
                tabSelector
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
                // Content
                TabView(selection: $selectedTab) {
                    subscriptionsTab
                        .tag(PurchaseTab.subscriptions)
                    
                    topUpsTab
                        .tag(PurchaseTab.topUps)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(
                ZStack {
                    // Deep space gradient
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.02, green: 0.02, blue: 0.08),
                            Color.black
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Glowing orbs
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.orange.opacity(0.15), Color.clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                        .frame(width: 400, height: 400)
                        .offset(x: -100, y: -150)
                        .blur(radius: 40)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.1), Color.clear],
                                center: .bottomTrailing,
                                startRadius: 0,
                                endRadius: 250
                            )
                        )
                        .frame(width: 350, height: 350)
                        .offset(x: 100, y: 150)
                        .blur(radius: 50)
                }
                .ignoresSafeArea()
            )
            .navigationTitle("Get Tokens")
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
                await viewModel.loadBalance()
            }
            .sheet(isPresented: $showingSubscriptionUpgrade) {
                SubscriptionUpgradeView(
                    initialTier: selectedTier,
                    initialPeriod: selectedPeriod
                )
                .onDisappear {
                    // Refresh balance when subscription view dismisses
                    Task {
                        await viewModel.loadBalance()
                    }
                }
            }
            .sheet(isPresented: $showingTopUp) {
                TokenTopUpView()
                    .onDisappear {
                        // Refresh balance when top-up view dismisses
                        Task {
                            await viewModel.loadBalance()
                        }
                    }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SubscriptionUpdated"))) { _ in
                // Reload balance when subscription is updated
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // Delay to allow backend propagation
                    await viewModel.loadBalance()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Balance Header
    private var balanceHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("\(viewModel.balance)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                
                Text("tokens")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.balance > 0 {
                Text("≈ \(viewModel.estimatedQueries) AI queries remaining")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Get tokens to unlock Genie AI")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "Subscriptions",
                subtitle: "Best Value",
                isSelected: selectedTab == .subscriptions
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = .subscriptions
                }
            }
            
            TabButton(
                title: "Top-Ups",
                subtitle: "One-Time",
                isSelected: selectedTab == .topUps
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = .topUps
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Subscriptions Tab
    private var subscriptionsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Period toggle
                HStack(spacing: 12) {
                    ForEach([SubscriptionPeriod.monthly, SubscriptionPeriod.annual], id: \.self) { period in
                        Button(action: { selectedPeriod = period }) {
                            VStack(spacing: 6) {
                                Text(period.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(selectedPeriod == period ? .white : .gray)
                                
                                if period == .annual {
                                    Text("Save up to $100")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.green)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedPeriod == period ? Color.orange.opacity(0.2) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedPeriod == period ? Color.orange : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                // Info card
                InfoCard(
                    icon: "infinity",
                    title: selectedPeriod == .monthly ? "Monthly Subscriptions" : "Annual Plans",
                    description: selectedPeriod == .monthly ? 
                        "Recurring tokens every month with the best value" :
                        "Pay once, get tokens all year with 2 months free"
                )
                .padding(.horizontal, 20)
                
                // Subscription tiers
                VStack(spacing: 12) {
                    ForEach(PremiumTier.allCases.filter { $0 != .free }, id: \.self) { tier in
                        CompactSubscriptionCard(
                            tier: tier,
                            period: selectedPeriod,
                            onSelect: {
                                selectedTier = tier
                                showingSubscriptionUpgrade = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Top-Ups Tab
    private var topUpsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Info card
                InfoCard(
                    icon: "purchased",
                    title: "One-Time Top-Ups",
                    description: "Buy extra tokens on demand. Never expire, use anytime"
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                // Top-up packages
                VStack(spacing: 12) {
                    ForEach(TokenTopUp.allCases, id: \.self) { topUp in
                        CompactTopUpCard(
                            topUp: topUp,
                            onSelect: {
                                showingTopUp = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .orange : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.orange.opacity(0.15) : Color.clear)
            .foregroundColor(isSelected ? .orange : .secondary)
        }
    }
}

// MARK: - Info Card
struct InfoCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Compact Subscription Card
struct CompactSubscriptionCard: View {
    let tier: PremiumTier
    let period: SubscriptionPeriod
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(tier.name)
                                .font(.headline)
                            
                            if let badge = tier.badge {
                                Text(badge)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("\(tier.monthlyTokens) tokens/month")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(priceString)
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text(period == .monthly ? "/month" : "/year")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if period == .annual {
                            Text("Save \(annualSavings)")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    ForEach(tier.features.prefix(3), id: \.self) { feature in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text(feature)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tier.badge != nil ? Color.orange : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var priceString: String {
        let price = period == .monthly ? tier.monthlyPrice : tier.annualPrice
        return String(format: "$%.0f", Double(price) / 100.0)
    }
    
    private var annualSavings: String {
        let monthlyCost = tier.monthlyPrice * 12
        let annualCost = tier.annualPrice
        let savings = monthlyCost - annualCost
        return String(format: "$%.0f", Double(savings) / 100.0)
    }
}

// MARK: - Compact Top-Up Card
struct CompactTopUpCard: View {
    let topUp: TokenTopUp
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(topUp.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 4) {
                        Text("\(topUp.tokens) tokens")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(valueText)
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(priceString)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(perTokenString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var priceString: String {
        String(format: "$%.2f", Double(topUp.price) / 100.0)
    }
    
    private var perTokenString: String {
        String(format: "$%.3f/token", topUp.pricePerToken)
    }
    
    private var valueText: String {
        switch topUp {
        case .small: return "Quick boost"
        case .medium: return "Good value"
        case .large: return "Best value"
        }
    }
}

// MARK: - View Model
@MainActor
class PurchaseViewModel: ObservableObject {
    @Published var balance: Int = 0
    @Published var estimatedQueries: Int = 0
    
    func loadBalance() async {
        do {
            let response = try await GenieAPIService.shared.getTokenBalance()
            balance = response.balance
            estimatedQueries = balance / 3 // Average 3 tokens per query
        } catch {
            print("❌ [Purchase] Error loading balance: \(error)")
        }
    }
}

// MARK: - Preview
struct TokenPurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        TokenPurchaseView()
    }
}
