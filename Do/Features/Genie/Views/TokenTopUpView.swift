// TokenTopUpView.swift
// Modern one-time token top-ups with premium design

import SwiftUI
@_spi(STP) import StripePaymentSheet

struct TokenTopUpView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = TokenTopUpViewModel()
    @State private var selectedTopUp: TokenTopUp = .medium
    @State private var showingPayment = false
    @State private var currentBalance: Int = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Hero with balance
                    heroSection
                    
                    // Why top up?
                    reasonSection
                        .padding(.horizontal, 20)
                    
                    // Top-up packages
                    VStack(spacing: 16) {
                        ForEach(TokenTopUp.allCases, id: \.self) { topUp in
                            TopUpPackageCard(
                                topUp: topUp,
                                isSelected: selectedTopUp == topUp,
                                onSelect: {
                                    selectedTopUp = topUp
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Purchase button
                    Button {
                        Task {
                            await viewModel.loadPaymentSheet(for: selectedTopUp)
                            showingPayment = true
                        }
                    } label: {
                        VStack(spacing: 4) {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Buy \(selectedTopUp.tokens) Tokens")
                                    .fontWeight(.semibold)
                                Text(priceString)
                                    .font(.caption)
                            }
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
                    .disabled(viewModel.isProcessing)
                    .padding(.horizontal, 20)
                    
                    // Info cards
                    infoSection
                        .padding(.horizontal, 20)
                    
                    // Upgrade suggestion
                    upgradeCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
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
                                colors: [Color.blue.opacity(0.1), Color.clear],
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
            .navigationTitle("Top Up Tokens")
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
            .onAppear {
                // Reload balance when view appears
                Task {
                    await viewModel.loadBalance()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SubscriptionUpdated"))) { _ in
                // Reload balance when subscription is updated
                Task {
                    await viewModel.loadBalance()
                }
            }
            .overlay {
                if viewModel.isProcessing {
                    ProcessingOverlay()
                }
            }
            .sheet(isPresented: $showingPayment) {
                if let paymentSheet = viewModel.paymentSheet {
                    TokenPaymentSheet(
                        paymentSheet: paymentSheet,
                        topUp: selectedTopUp,
                        onSuccess: {
                            dismiss()
                            NotificationCenter.default.post(name: NSNotification.Name("SubscriptionUpdated"), object: nil)
                        }
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 20) {
            // Icon with balance
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                VStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    Text("\(viewModel.balance)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Title
            VStack(spacing: 8) {
                Text(viewModel.balance < 10 ? "Running Low" : "Top Up Anytime")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(viewModel.balance < 10 ? "Get more tokens to continue with Genie" : "Buy extra tokens on demand")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 32)
    }
    
    // MARK: - Reason Section
    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why Top Up?")
                .font(.headline)
            
            VStack(spacing: 12) {
                ReasonRow(
                    icon: "sparkles",
                    title: "Instant Access",
                    description: "Tokens added immediately to your account"
                )
                
                ReasonRow(
                    icon: "infinity",
                    title: "Never Expire",
                    description: "Use them whenever you want, they're yours forever"
                )
                
                ReasonRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Better Value",
                    description: "More tokens = lower price per token"
                )
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                
                Text("About Top-Ups")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InfoBullet(text: "Top-ups are one-time purchases")
                InfoBullet(text: "Use alongside your subscription")
                InfoBullet(text: "Tokens never expire")
                InfoBullet(text: "Instant delivery")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Upgrade Card
    private var upgradeCard: some View {
        Button {
            // Navigate to subscription view
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.orange)
                    
                    Text("Want Better Value?")
                        .font(.headline)
                }
                
                Text("Upgrade to a monthly subscription and save up to 40% on tokens with unlimited AI coaching.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Spacer()
                    
                    Text("View Plans")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(20)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var priceString: String {
        String(format: "$%.2f", Double(selectedTopUp.price) / 100.0)
    }
}

// MARK: - Top-Up Package Card
struct TopUpPackageCard: View {
    let topUp: TokenTopUp
    let isSelected: Bool
    let onSelect: () -> Void
    
    // Do blue theme
    private let doBlue = Color(red: 0.0, green: 0.48, blue: 0.80) // #007ACC
    private let doBlueLight = Color(red: 0.2, green: 0.58, blue: 0.85)
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with selection indicator
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Package name
                        Text(topUp.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        // Token count
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(doBlue)
                            
                            Text("\(topUp.tokens) tokens")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
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
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                
                // Price and value
                HStack(alignment: .firstTextBaseline) {
                    Text(priceString)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Value per token
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(perTokenString)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text(valueText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
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
                    
                    // Selected state with Do blue
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
    
    private var priceString: String {
        String(format: "$%.2f", Double(topUp.price) / 100.0)
    }
    
    private var perTokenString: String {
        String(format: "$%.3f/token", topUp.pricePerToken)
    }
    
    private var valueText: String {
        switch topUp {
        case .small: return "Basic"
        case .medium: return "Good Value"
        case .large: return "Best Value"
        }
    }
}

// MARK: - Reason Row
struct ReasonRow: View {
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

// MARK: - Info Bullet
struct InfoBullet: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.blue)
            
            Text(text)
        }
    }
}

// MARK: - Token Payment Sheet
struct TokenPaymentSheet: View {
    @Environment(\.dismiss) var dismiss
    let paymentSheet: StripePaymentSheet.PaymentSheet
    let topUp: TokenTopUp
    let onSuccess: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Purchase \(topUp.tokens) Tokens")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(String(format: "$%.2f", Double(topUp.price) / 100.0))
                .font(.title)
                .foregroundColor(.orange)
            
            Button("Enter Payment Details") {
                presentPaymentSheet()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
    }
    
    private func presentPaymentSheet() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = scene.windows.first?.rootViewController else {
            return
        }
        
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        
        paymentSheet.present(from: topViewController) { result in
            switch result {
            case .completed:
                print("✅ [TopUp] Payment completed")
                onSuccess()
            case .canceled:
                print("⚠️ [TopUp] Payment canceled")
                dismiss()
            case .failed(let error):
                print("❌ [TopUp] Payment failed: \(error.localizedDescription)")
                dismiss()
            }
        }
    }
}

// MARK: - View Model
@MainActor
class TokenTopUpViewModel: ObservableObject {
    @Published var balance: Int = 0
    @Published var isProcessing = false
    @Published var paymentSheet: StripePaymentSheet.PaymentSheet?
    @Published var errorMessage = ""
    @Published var showError = false
    
    func loadBalance() async {
        do {
            let response = try await GenieAPIService.shared.getTokenBalance()
            balance = response.balance
        } catch {
            print("❌ [TopUp] Error loading balance: \(error)")
        }
    }
    
    func loadPaymentSheet(for topUp: TokenTopUp) async {
        isProcessing = true
        
        do {
            // Create payment intent for top-up
            let paymentIntent = try await GenieAPIService.shared.createPaymentIntent(packageId: topUp.rawValue)
            
            var configuration = StripePaymentSheet.PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Do."
            configuration.allowsDelayedPaymentMethods = true
            
            // Enable Apple Pay
            let applePayConfig = StripePaymentSheet.PaymentSheet.ApplePayConfiguration(
                merchantId: "merchant.com.doapp",
                merchantCountryCode: "US",
                buttonType: .plain
            )
            configuration.applePay = applePayConfig
            
            paymentSheet = StripePaymentSheet.PaymentSheet(
                paymentIntentClientSecret: paymentIntent.clientSecret,
                configuration: configuration
            )
            
            isProcessing = false
            print("✅ [TopUp] PaymentSheet loaded for \(topUp.tokens) tokens")
        } catch {
            isProcessing = false
            errorMessage = "Failed to load payment: \(error.localizedDescription)"
            showError = true
            print("❌ [TopUp] Error creating payment intent: \(error)")
        }
    }
}
