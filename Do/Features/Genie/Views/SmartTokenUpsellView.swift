// SmartTokenUpsellView.swift
// Unified subscription and token purchase experience with monthly/annual plans and top-ups
// Modern design with Do. brand colors and premium card styling

import SwiftUI
@_spi(STP) import StripePaymentSheet

struct SmartTokenUpsellView: View {
    let required: Int
    let balance: Int
    let queryType: String
    let tier: Int
    let hasSubscription: Bool
    let recommendation: String
    let tokenPacks: [TokenPack]
    let subscriptions: [UpsellSubscriptionPlan]
    
    @Environment(\.dismiss) var dismiss
    @State private var paymentSheet: StripePaymentSheet.PaymentSheet?
    @State private var subscriptionPaymentSheet: StripePaymentSheet.PaymentSheet?
    @State private var isProcessing = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var selectedSubscriptionTier: PremiumTier?
    @State private var selectedPeriod: SubscriptionPeriod = .monthly
    @State private var pendingTokenPack: TokenPack?
    @State private var currentSubscriptionTier: Int = 0 // 0 = free, 1 = athlete, 2 = champion, 3 = legend
    @State private var showingTab: PurchaseTab = .subscriptions
    @State private var animateCards = false
    @State private var currentBalance: Int = 0
    
    // Brand colors
    private let doBlue = Color(red: 0.06, green: 0.09, blue: 0.24) // #0F163E
    private let doBlueLight = Color(red: 0.08, green: 0.12, blue: 0.28)
    private let doOrange = Color(red: 0.969, green: 0.576, blue: 0.122) // #F7931F
    private let doOrangeLight = Color(red: 1.0, green: 0.42, blue: 0.21)
    
    init(required: Int, balance: Int, queryType: String, tier: Int, hasSubscription: Bool, recommendation: String, tokenPacks: [TokenPack] = [], subscriptions: [UpsellSubscriptionPlan] = []) {
        self.required = required
        self.balance = balance
        self.queryType = queryType
        self.tier = tier
        self.hasSubscription = hasSubscription
        self.recommendation = recommendation
        self.tokenPacks = tokenPacks
        self.subscriptions = subscriptions
        // Set initial tab based on recommendation
        // Backend sends "subscription" or "token_pack", normalize to match
        let normalizedRec = recommendation.lowercased()
        _showingTab = State(initialValue: normalizedRec == "subscription" ? .subscriptions : .topUps)
        _currentBalance = State(initialValue: balance)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                        .padding(.top, 8)
                        .padding(.horizontal, 20)
                    
                    // Context Card
                    queryContextCard
                        .padding(.horizontal, 20)
                    
                    // Tab selector
                    tabSelector
                        .padding(.horizontal, 20)
                    
                    // Content based on selected tab
                    if showingTab == .subscriptions {
                        subscriptionsContent
                            .padding(.horizontal, 20)
                    } else {
                        topUpsContent
                            .padding(.horizontal, 20)
                    }
                    
                    // Free features reminder
                    freeFeaturesBanner
                        .padding(.horizontal, 20)
                    
                    // Unsubscribe section (only if user has subscription)
                    unsubscribeSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [doBlue, Color.black]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        }
                    }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadCurrentSubscriptionTier()
            await reloadBalance()
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateCards = true
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(hasSubscription ? "Get More Tokens" : "Choose Your Plan")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text(hasSubscription 
                 ? "Purchase tokens or upgrade your subscription to continue."
                 : "Select a subscription plan or buy tokens to unlock AI features.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Query Context Card
    
    private var queryContextCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Available Tokens")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("\(max(currentBalance, 0))")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            Button(action: { 
                withAnimation(.spring(response: 0.3)) {
                    showingTab = .subscriptions
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                    Text("Subscriptions")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(showingTab == .subscriptions ? .white : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Group {
                        if showingTab == .subscriptions {
                            LinearGradient(
                                colors: [doOrange, doOrangeLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.clear
                        }
                    }
                )
            }
            
            Button(action: { 
                withAnimation(.spring(response: 0.3)) {
                    showingTab = .topUps
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Top-Ups")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(showingTab == .topUps ? .white : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Group {
                        if showingTab == .topUps {
                            LinearGradient(
                                colors: [doOrange, doOrangeLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.clear
                        }
                    }
                )
            }
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Subscriptions Content
    
    private var subscriptionsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Period toggle
            periodToggle
            
            // Available subscription tiers
            VStack(spacing: 16) {
                ForEach(Array(availableTiers.enumerated()), id: \.element) { index, tier in
                    UnifiedSubscriptionCard(
                        tier: tier,
                        period: selectedPeriod,
                        isCurrent: currentSubscriptionTier == getTierNumber(tier),
                        onSelect: {
                            handleSubscriptionPurchase(tier, period: selectedPeriod)
                        }
                    )
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1), value: animateCards)
                }
                
                if availableTiers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.doOrange)
                        Text("You're on the highest tier")
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
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Top-Ups Content
    
    private var topUpsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("One-Time Purchase")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Perfect for when you need extra tokens")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Show all token top-up packs
            VStack(spacing: 12) {
                ForEach(Array(allTokenPacks.enumerated()), id: \.element.id) { index, pack in
                    ModernTokenPackCard(pack: pack, isSelected: pendingTokenPack?.id == pack.id) {
                        handleTokenPackPurchase(pack)
                    }
                }
            }
        }
    }
    
    // MARK: - Period Toggle
    
    private var periodToggle: some View {
        HStack(spacing: 0) {
            Button(action: { 
                withAnimation(.spring(response: 0.3)) {
                    selectedPeriod = .monthly
                }
            }) {
                Text("Monthly")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(selectedPeriod == .monthly ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedPeriod == .monthly ? Color.doOrange : Color.clear)
            }
            
            Button(action: { 
                withAnimation(.spring(response: 0.3)) {
                    selectedPeriod = .annual
                }
            }) {
                HStack(spacing: 6) {
                    Text("Annual")
                        .font(.system(size: 15, weight: .medium))
                    Text("Save 17%")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .foregroundColor(selectedPeriod == .annual ? .white : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedPeriod == .annual ? Color.doOrange : Color.clear)
            }
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Unsubscribe Section
    
    private var unsubscribeSection: some View {
        Group {
            if hasSubscription && currentSubscriptionTier > 0 {
                VStack(spacing: 12) {
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.vertical, 8)
                    
                    Button(action: {
                        handleUnsubscribe()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                            Text("Cancel Subscription")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .disabled(isProcessing)
                    
                    Text("Your subscription will remain active until the end of the current billing period")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
        }
    }
    
    // MARK: - Free Features Banner
    
    private var freeFeaturesBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                
                Text("Free features always available")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 20)
                    Text("View your activity stats")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 20)
                    Text("Check your last workout")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 20)
                    Text("See your personal records")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Purchase Handling
    
    private func handleTokenPackPurchase(_ pack: TokenPack) {
        isProcessing = true
        pendingTokenPack = pack
        
        // Store initial balance before purchase for comparison
        let initialBalance = currentBalance
        
        Task {
            let packageId = mapTokenPackIdToPackageId(pack.id)
            print("💰 [Upsell] Purchasing pack: id=\(pack.id), mapped=\(packageId), tokens=\(pack.tokens), price=\(pack.price), initialBalance=\(initialBalance)")
            
            do {
                let paymentIntent = try await GenieAPIService.shared.createPaymentIntent(packageId: packageId)
                print("✅ [Upsell] Payment intent created: \(paymentIntent.clientSecret.prefix(20))...")
                
                // Verify price matches what's displayed
                let displayedPrice = pack.price
                let backendPrice = paymentIntent.package.price
                if displayedPrice != backendPrice {
                    print("⚠️ [Upsell] Price mismatch! Displayed: \(displayedPrice), Backend: \(backendPrice)")
                } else {
                    print("✅ [Upsell] Price verified: \(displayedPrice) cents")
                }
                
                var configuration = StripePaymentSheet.PaymentSheet.Configuration()
                configuration.merchantDisplayName = "Do."
                configuration.allowsDelayedPaymentMethods = true
                configuration.returnURL = "do-app://stripe-redirect"
                
                // Customize appearance to match SmartTokenUpsellView dark gradient
                var appearance = StripePaymentSheet.PaymentSheet.Appearance()
                appearance.colors.background = UIColor(red: 0.06, green: 0.09, blue: 0.24, alpha: 1.0) // doBlue
                appearance.colors.componentBackground = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) // Dark gray
                appearance.colors.text = .white
                appearance.colors.textSecondary = UIColor.white.withAlphaComponent(0.7)
                appearance.colors.componentText = .white
                appearance.colors.componentPlaceholderText = UIColor.white.withAlphaComponent(0.5)
                appearance.colors.componentBorder = UIColor.white.withAlphaComponent(0.2)
                appearance.colors.primary = UIColor(red: 0.969, green: 0.576, blue: 0.122, alpha: 1.0) // doOrange
                appearance.primaryButton.backgroundColor = UIColor(red: 0.969, green: 0.576, blue: 0.122, alpha: 1.0) // doOrange
                appearance.primaryButton.textColor = .white
                appearance.cornerRadius = 12.0
                configuration.appearance = appearance
                
                // Enable Apple Pay
                let applePayConfig = StripePaymentSheet.PaymentSheet.ApplePayConfiguration(
                    merchantId: "merchant.com.doapp",
                    merchantCountryCode: "US",
                    buttonType: .plain
                )
                configuration.applePay = applePayConfig
                
                await MainActor.run {
                    paymentSheet = StripePaymentSheet.PaymentSheet(
                        paymentIntentClientSecret: paymentIntent.clientSecret,
                        configuration: configuration
                    )
                    isProcessing = false
                    print("✅ [Upsell] PaymentSheet created, presenting...")
                    
                    // Present PaymentSheet directly
                    presentPaymentSheet()
                }
            } catch {
                print("❌ [Upsell] Error creating payment intent: \(error)")
                if let genieError = error as? GenieError {
                    print("❌ [Upsell] GenieError details: \(genieError)")
                    
                    if case .serverError(let code) = genieError {
                        if code == 500 {
                            await MainActor.run {
                                isProcessing = false
                                errorMessage = "Payment service is temporarily unavailable. Please try again later or contact support."
                                showError = true
                            }
                            return
                        }
                    }
                }
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to load payment: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func handleSubscriptionPurchase(_ tier: PremiumTier, period: SubscriptionPeriod) {
        isProcessing = true
            selectedSubscriptionTier = tier
        selectedPeriod = period
        
        Task {
            do {
                print("💳 [Upsell] Creating setup intent for subscription: tier=\(tier.rawValue), period=\(period.rawValue)")
                
                let setupIntentResponse = try await GenieAPIService.shared.createSetupIntent()
                print("✅ [Upsell] Setup intent created: \(setupIntentResponse.clientSecret.prefix(20))...")
                
                var configuration = StripePaymentSheet.PaymentSheet.Configuration()
                configuration.merchantDisplayName = "Do."
                configuration.allowsDelayedPaymentMethods = true
                configuration.returnURL = "do-app://stripe-redirect"
                
                // Customize appearance to match SmartTokenUpsellView dark gradient
                var appearance = StripePaymentSheet.PaymentSheet.Appearance()
                appearance.colors.background = UIColor(red: 0.06, green: 0.09, blue: 0.24, alpha: 1.0) // doBlue
                appearance.colors.componentBackground = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) // Dark gray
                appearance.colors.text = .white
                appearance.colors.textSecondary = UIColor.white.withAlphaComponent(0.7)
                appearance.colors.componentText = .white
                appearance.colors.componentPlaceholderText = UIColor.white.withAlphaComponent(0.5)
                appearance.colors.componentBorder = UIColor.white.withAlphaComponent(0.2)
                appearance.colors.primary = UIColor(red: 0.969, green: 0.576, blue: 0.122, alpha: 1.0) // doOrange
                appearance.primaryButton.backgroundColor = UIColor(red: 0.969, green: 0.576, blue: 0.122, alpha: 1.0) // doOrange
                appearance.primaryButton.textColor = .white
                appearance.cornerRadius = 12.0
                configuration.appearance = appearance
                
                // Enable Apple Pay
                let applePayConfig = StripePaymentSheet.PaymentSheet.ApplePayConfiguration(
                    merchantId: "merchant.com.doapp",
                    merchantCountryCode: "US",
                    buttonType: .plain
                )
                configuration.applePay = applePayConfig
                
                await MainActor.run {
                    subscriptionPaymentSheet = StripePaymentSheet.PaymentSheet(
                        setupIntentClientSecret: setupIntentResponse.clientSecret,
                        configuration: configuration
                    )
                    isProcessing = false
                    print("✅ [Upsell] Subscription PaymentSheet created, presenting...")
                    
                    // Present PaymentSheet directly
                    presentSubscriptionPaymentSheet()
                }
            } catch {
                print("❌ [Upsell] Error creating setup intent: \(error)")
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to load payment: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func handleUnsubscribe() {
        isProcessing = true
        Task {
            do {
                let response = try await GenieAPIService.shared.cancelSubscription()
                print("✅ [Upsell] Subscription cancelled: \(response.message)")
                
                await MainActor.run {
                    isProcessing = false
                    errorMessage = response.message
                    showError = true
                    
                    // Reload subscription status
                    Task {
                        await loadCurrentSubscriptionTier()
                        await reloadBalance()
                        NotificationCenter.default.post(name: NSNotification.Name("SubscriptionUpdated"), object: nil)
                    }
                }
            } catch {
                print("❌ [Upsell] Error cancelling subscription: \(error)")
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to cancel subscription: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Payment Sheet Presentation
    
    private func presentPaymentSheet() {
        guard let paymentSheet = paymentSheet else {
            errorMessage = "Payment sheet not loaded"
            showError = true
            return
        }
        
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = scene.windows.first?.rootViewController else {
            errorMessage = "Unable to present payment sheet"
            showError = true
            return
        }
        
        // Get the topmost presented view controller
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        
        // Present the payment sheet
        paymentSheet.present(from: topViewController) { result in
            switch result {
            case .completed:
                print("✅ [Upsell] Payment completed for token pack")
                Task {
                    // Wait for webhook to process (usually 2-5 seconds)
                    print("⏳ [Upsell] Waiting for webhook to process payment...")
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                    
                    // Reload balance with retry logic (webhook may take a few seconds)
                    await reloadBalanceWithRetry(maxAttempts: 5, delaySeconds: 2)
                    
                    NotificationCenter.default.post(name: NSNotification.Name("TokensPurchased"), object: nil)
                }
                dismiss()
            case .canceled:
                print("⚠️ [Upsell] Payment canceled")
            case .failed(let error):
                print("❌ [Upsell] Payment failed: \(error.localizedDescription)")
                errorMessage = "Payment failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func presentSubscriptionPaymentSheet() {
        guard let paymentSheet = subscriptionPaymentSheet else {
            errorMessage = "Payment sheet not loaded"
            showError = true
            return
        }
        
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = scene.windows.first?.rootViewController else {
            errorMessage = "Unable to present payment sheet"
            showError = true
            return
        }
        
        // Get the topmost presented view controller
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        
        // Present the payment sheet
        paymentSheet.present(from: topViewController) { result in
            switch result {
            case .completed:
                print("✅ [Upsell] Payment method collected for subscription")
                // Create subscription after payment method is collected
                createSubscriptionAfterPaymentMethod()
            case .canceled:
                print("⚠️ [Upsell] Payment canceled")
            case .failed(let error):
                print("❌ [Upsell] Payment failed: \(error.localizedDescription)")
                errorMessage = "Payment failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func createSubscriptionAfterPaymentMethod() {
        guard let tier = selectedSubscriptionTier else { return }
        
        isProcessing = true
        
        Task {
            do {
                // Get price ID based on tier and period
                let priceId = selectedPeriod == .monthly ?
                    tier.stripeMonthlyPriceId :
                    tier.stripeAnnualPriceId
                
                // Verify price matches what's displayed
                let displayedPrice = selectedPeriod == .monthly ? tier.monthlyPrice : tier.annualPrice
                print("✅ [Upsell] Creating subscription: tier=\(tier.rawValue), period=\(selectedPeriod.rawValue), priceId=\(priceId), displayedPrice=\(displayedPrice) cents")
                
                let response = try await GenieAPIService.shared.createSubscription(
                    tier: tier.rawValue,
                    priceId: priceId,
                    paymentMethodId: "default" // Uses customer's default payment method from SetupIntent
                )
                
                print("✅ [Upsell] Subscription created: tier=\(tier.rawValue), status=\(response.status ?? "unknown")")
                
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                    Task {
                        await reloadBalance()
                        NotificationCenter.default.post(name: NSNotification.Name("SubscriptionUpdated"), object: nil)
                    }
                }
            } catch {
                print("❌ [Upsell] Error creating subscription: \(error)")
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to create subscription: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func mapTokenPackIdToPackageId(_ packId: String) -> String {
        switch packId.lowercased() {
        case "quickboost": return "topup_100"
        case "powerpack": return "topup_300"
        case "probundle": return "topup_500"
        default:
            if packId.contains("100") || packId.contains("quick") {
                return "topup_100"
            } else if packId.contains("300") || packId.contains("power") {
                return "topup_300"
            } else if packId.contains("500") || packId.contains("pro") || packId.contains("700") {
                return "topup_500"
            }
            return "topup_100"
        }
    }
    
    private func reloadBalance() async {
        do {
            let response = try await GenieAPIService.shared.getTokenBalance()
            await MainActor.run {
                // Use the balance field directly - it already includes subscription + top-up
                // This is the correct total available tokens
                currentBalance = max(response.balance, 0)
                
                // Log breakdown for debugging
                let subscriptionTokens = response.subscription?.tokensRemainingThisMonth ?? 0
                let topUpTokens = response.subscription?.topUpBalance ?? 0
                print("✅ [Upsell] Balance reloaded: \(currentBalance) tokens (balance field: \(response.balance), subscription remaining: \(subscriptionTokens), top-up: \(topUpTokens))")
            }
        } catch {
            print("❌ [Upsell] Error reloading balance: \(error)")
            // Keep the current balance if reload fails
        }
    }
    
    private func reloadBalanceWithRetry(maxAttempts: Int, delaySeconds: Int) async {
        // Get initial top-up balance for comparison
        var initialTopUpBalance = 0
        do {
            let initialResponse = try await GenieAPIService.shared.getTokenBalance()
            initialTopUpBalance = initialResponse.subscription?.topUpBalance ?? 0
            print("⏳ [Upsell] Initial top-up balance: \(initialTopUpBalance), waiting for webhook to process...")
        } catch {
            print("⚠️ [Upsell] Could not get initial balance, will check for any top-up tokens")
        }
        
        for attempt in 1...maxAttempts {
            do {
                let response = try await GenieAPIService.shared.getTokenBalance()
                // Use balance field directly - it already includes subscription + top-up
                let totalBalance = response.balance
                let topUpTokens = response.subscription?.topUpBalance ?? 0
                let subscriptionTokens = response.subscription?.tokensRemainingThisMonth ?? 0
                
                await MainActor.run {
                    currentBalance = max(totalBalance, 0)
                }
                
                // Check if top-up balance has increased (webhook processed)
                let balanceIncreased = topUpTokens > initialTopUpBalance
                
                if balanceIncreased {
                    print("✅ [Upsell] Balance updated: \(currentBalance) tokens (balance field: \(totalBalance), subscription: \(subscriptionTokens), top-up: \(topUpTokens), increased by \(topUpTokens - initialTopUpBalance)) after \(attempt) attempt(s)")
                    return
                } else if attempt == maxAttempts {
                    print("⚠️ [Upsell] Balance check completed after \(maxAttempts) attempts. Current: \(currentBalance) tokens (balance field: \(totalBalance), subscription: \(subscriptionTokens), top-up: \(topUpTokens)). Webhook may still be processing.")
                    return
                }
                
                // Wait before next attempt
                if attempt < maxAttempts {
                    print("⏳ [Upsell] Balance not updated yet (attempt \(attempt)/\(maxAttempts), top-up: \(topUpTokens)), waiting \(delaySeconds)s...")
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
                }
            } catch {
                print("❌ [Upsell] Error reloading balance (attempt \(attempt)/\(maxAttempts)): \(error)")
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
                }
            }
        }
    }
    
    private var availableTiers: [PremiumTier] {
        let allTiers: [PremiumTier] = [.athlete, .champion, .legend]
        return allTiers.filter { getTierNumber($0) > currentSubscriptionTier }
    }
    
    private var allTokenPacks: [TokenPack] {
        if !tokenPacks.isEmpty {
            return tokenPacks
        }
        
        return [
            TokenPack(id: "topup_100", name: "Quick Boost", tokens: 100, bonus: 0, price: 499, popular: false),
            TokenPack(id: "topup_300", name: "Power Pack", tokens: 300, bonus: 0, price: 999, popular: true), // $9.99 - matches backend
            TokenPack(id: "topup_500", name: "Pro Bundle", tokens: 500, bonus: 0, price: 1999, popular: false)
        ]
    }
    
    private func getTierNumber(_ tier: PremiumTier) -> Int {
        switch tier {
        case .free: return 0
        case .athlete: return 1
        case .champion: return 2
        case .legend: return 3
        }
    }
    
    private func loadCurrentSubscriptionTier() async {
        do {
            let response = try await GenieAPIService.shared.getTokenBalance()
            
            if let subscription = response.subscription {
                let tier = subscription.tier.lowercased()
                await MainActor.run {
                    switch tier {
                    case "athlete": currentSubscriptionTier = 1
                    case "champion": currentSubscriptionTier = 2
                    case "legend": currentSubscriptionTier = 3
                    default: currentSubscriptionTier = 0
                    }
                }
            } else {
                await MainActor.run {
                    currentSubscriptionTier = 0
                }
            }
        } catch {
            print("❌ [Upsell] Error loading subscription tier: \(error)")
            // Gracefully handle errors - default to free tier
            // This prevents the view from breaking if the API is temporarily unavailable
            await MainActor.run {
                currentSubscriptionTier = 0
                // If balance was passed as 0, try to use the passed value
                // Otherwise, we'll show the view with default values
            }
        }
    }
    
    private var tierIcon: String {
        switch tier {
        case 0: return "database.fill"
        case 1: return "brain.fill"
        case 2: return "chart.line.uptrend.xyaxis"
        case 3: return "wand.and.stars"
        case 4: return "sparkles"
        default: return "questionmark.circle"
        }
    }
    
    private var queryTypeDescription: String {
        switch queryType {
        case "database": return "Database lookup"
        case "ai": return tier == 1 ? "Simple AI query" : tier == 2 ? "Advanced analysis" : "Content generation"
        case "agent": return "Multi-step AI reasoning"
        default: return "AI query"
        }
    }
}

// MARK: - Supporting Views

struct UpsellFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.green)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
    }
}

// MARK: - Unified Subscription Card

struct UnifiedSubscriptionCard: View {
    let tier: PremiumTier
    let period: SubscriptionPeriod
    let isCurrent: Bool
    let onSelect: () -> Void
    
    private let doOrange = Color(red: 0.969, green: 0.576, blue: 0.122)
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(tier.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if isCurrent {
                        Text("Current")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                    
                    if tier == .champion {
                        Text("Popular")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.doOrange)
                            .cornerRadius(4)
                    }
                }
                
                Text("\(tier.monthlyTokens) tokens/month")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("~\(tier.monthlyTokens / 30) tokens/day")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                Text(priceDisplay)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                if period == .annual {
                    Text("Save \(savingsDisplay)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                } else {
                        Text("Cancel anytime")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCurrent ? Color.green : (Color.doOrange.opacity(0.3)), lineWidth: isCurrent ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
    }
    
    private var tierIcon: String {
        switch tier {
        case .athlete: return "figure.run"
        case .champion: return "trophy.fill"
        case .legend: return "crown.fill"
        default: return "star.fill"
        }
    }
    
    private var tierIconGradient: [Color] {
        switch tier {
        case .athlete: return [Color.blue, Color.cyan]
        case .champion: return [doOrange, Color.yellow]
        case .legend: return [Color.purple, Color.pink]
        default: return [Color.gray, Color.gray]
        }
    }
    
    private var priceDisplay: String {
        let price = period == .monthly ? tier.monthlyPrice : tier.annualPrice
        let formatted = String(format: "$%.2f", Double(price) / 100.0)
        return period == .monthly ? "\(formatted)/mo" : "\(formatted)/yr"
    }
    
    private var savingsDisplay: String {
        let monthlyTotal = tier.monthlyPrice * 12
        let annualPrice = tier.annualPrice
        let savings = monthlyTotal - annualPrice
        return String(format: "$%.2f", Double(savings) / 100.0)
    }
}

// MARK: - Modern Token Pack Card

struct ModernTokenPackCard: View {
    let pack: TokenPack
    let isSelected: Bool
    let action: () -> Void
    
    private let doOrange = Color(red: 0.969, green: 0.576, blue: 0.122)
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(pack.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if pack.popular {
                            Text("Popular")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.doOrange)
                                .cornerRadius(4)
                        }
                    }
                    
                        Text("\(pack.tokens) tokens")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        
                        if pack.bonus > 0 {
                            Text("+\(pack.bonus) bonus tokens")
                            .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", Double(pack.price) / 100))")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("One-time")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.doOrange : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Models

struct TokenPack: Codable, Identifiable {
    let id: String
    let name: String
    let tokens: Int
    let bonus: Int
    let price: Int
    let popular: Bool
}

struct UpsellSubscriptionPlan: Codable, Identifiable {
    let id: String
    let name: String
    let tokens: Int
    let price: Int
    let perDay: Int
}

enum PurchaseOption: Identifiable {
    case tokenPack(TokenPack)
    case subscription(UpsellSubscriptionPlan)
    
    var id: String {
        switch self {
        case .tokenPack(let pack): return pack.id
        case .subscription(let plan): return plan.id
        }
    }
}

enum PurchaseTab {
    case subscriptions
    case topUps
}
