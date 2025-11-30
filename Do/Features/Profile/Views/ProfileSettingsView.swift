//
//  ProfileSettingsView.swift
//  Do.
//
//  Created by Mikiyas Tadesse on 8/19/25.
//

import SwiftUI
import NotificationBannerSwift

struct ProfileSettingsView: View {
    @ObservedObject var viewModel: ProfileSettingsViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var offset = CGSize.zero
    @State private var showSubscriptionUpgrade = false
    @State private var showGenieSettings = false
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    @State private var deleteReason = ""
    @State private var navigateToLogin = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor(red: 0.06, green: 0.09, blue: 0.24, alpha: 1.0)),
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Loading overlay
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Loading profile...")
                        .foregroundColor(.white)
                        .padding(.top, 16)
                }
            }
            
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Header with dismiss gesture
                    header
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    self.offset = gesture.translation
                                }
                                .onEnded { gesture in
                                    if gesture.translation.height > 50 {
                                        withAnimation(.spring()) {
                                            self.presentationMode.wrappedValue.dismiss()
                                        }
                                    } else {
                                        self.offset = .zero
                                    }
                                }
                        )
                    
                    // Profile Image Section
                    profileImageSection
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        formField(title: "Name", text: $viewModel.name)
                        formField(title: "Username", text: $viewModel.username)
                        bioField(title: "Bio", text: $viewModel.bio)
                        formField(title: "Email", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding(.horizontal)
                    
                    // Premium Account Section
                    premiumAccountSection
                                        
                    // Privacy Settings
                    privacySection
                    
                    // Account Actions
                    accountActionsSection
                    
                    // Bottom padding to ensure buttons are visible
                    Color.clear.frame(height: 100)
                }
                .padding(.top, 20)
                .opacity(viewModel.isLoading ? 0.5 : 1.0)
                .disabled(viewModel.isLoading)
            }
            
            // Save Button
            saveButton
        }
        .sheet(isPresented: $showSubscriptionUpgrade) {
            SmartTokenUpsellView(
                required: 100, // Default value for profile settings context
                balance: viewModel.tokensRemaining,
                queryType: "subscription",
                tier: tierToInt(viewModel.subscriptionTier),
                hasSubscription: viewModel.isPremium,
                recommendation: viewModel.isPremium ? "token_pack" : "subscription",
                tokenPacks: [],
                subscriptions: []
            )
            .onDisappear {
                // Reload subscription when view dismisses
                Task {
                    await viewModel.loadSubscriptionStatus()
                }
            }
        }
        .sheet(isPresented: $showGenieSettings) {
            SmartTokenUpsellView(
                required: 100, // Default value for token shop context
                balance: viewModel.tokensRemaining,
                queryType: "general",
                tier: tierToInt(viewModel.subscriptionTier),
                hasSubscription: viewModel.isPremium,
                recommendation: viewModel.isPremium ? "token_pack" : "subscription",
                tokenPacks: [],
                subscriptions: []
            )
            .onDisappear {
                // Reload balance when view dismisses
                Task {
                    await viewModel.loadSubscriptionStatus()
                }
            }
        }
        .fullScreenCover(isPresented: $navigateToLogin) {
            // Navigate to login screen
            LoginNavigationView()
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button(action: {
                withAnimation(.spring()) {
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Edit Profile")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Placeholder for symmetry
            Circle()
                .fill(Color.clear)
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal)
        .offset(y: offset.height)
    }
    
    // MARK: - Profile Image Section
    private var profileImageSection: some View {
        VStack(spacing: 16) {
            if let profileImage = viewModel.profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                    )
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .foregroundColor(.white)
            }
            
            Button(action: viewModel.changeProfilePicture) {
                Text("Change Profile Picture")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(20)
            }
        }
    }
    
    // MARK: - Form Field
    private func formField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            TextField("", text: text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
        }
    }
    
    private func bioField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            TextField("Tell us about yourself", text: text, axis: .vertical)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .lineLimit(3, reservesSpace: true)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
        }
    }
    
    // MARK: - Premium Account Section
    private var premiumAccountSection: some View {
        VStack(spacing: 16) {
            // Main subscription card
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // Always show the tier name if there's a subscription, otherwise show "Free Plan"
                        Text(viewModel.subscriptionTier != "free" ? tierDisplayName(viewModel.subscriptionTier) : "Free Plan")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        if viewModel.subscriptionTier != "free" {
                            Text("\(viewModel.tokensRemaining) tokens remaining")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            Text("Upgrade to unlock Genie AI")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    if viewModel.subscriptionTier != "free" {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 24))
                    } else {
                        Button(action: { showSubscriptionUpgrade = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "crown.fill")
                                Text("Upgrade")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.brandOrange, Color(hex: "FF6B35")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                        }
                    }
                }
                
                // Token usage bar (only show if premium)
                if viewModel.isPremium && viewModel.monthlyAllowance > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Monthly Allowance")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text("\(viewModel.monthlyAllowance - (viewModel.monthlyAllowance - viewModel.tokensRemaining))/\(viewModel.monthlyAllowance)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 8)
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.brandOrange, Color(hex: "FF6B35")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * usagePercentage, height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.top, 4)
                }
                
                // Manage subscription button (only show if has subscription tier)
                if viewModel.subscriptionTier != "free" {
                    Button(action: { showSubscriptionUpgrade = true }) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Manage Subscription")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }
    
    private func tierDisplayName(_ tier: String) -> String {
        switch tier.lowercased() {
        case "athlete":
            return "Athlete Plan"
        case "champion":
            return "Champion Plan"
        case "legend":
            return "Legend Plan"
        case "free":
            return "Free Plan"
        default:
            // Capitalize first letter for display
            return tier.prefix(1).uppercased() + tier.dropFirst().capitalized + " Plan"
        }
    }
    
    private func tierToInt(_ tier: String) -> Int {
        switch tier.lowercased() {
        case "free": return 0
        case "athlete": return 1
        case "champion": return 2
        case "legend": return 3
        default: return 0
        }
    }
    
    private var usagePercentage: Double {
        guard viewModel.monthlyAllowance > 0 else { return 0 }
        let used = viewModel.monthlyAllowance - viewModel.tokensRemaining
        return min(1.0, Double(used) / Double(viewModel.monthlyAllowance))
    }
    
    // MARK: - Privacy Section
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal)
            
            Toggle("Private Account", isOn: $viewModel.isPrivateAccount)
                .toggleStyle(SwitchToggleStyle(tint: Color(UIColor(red: 0.97, green: 0.58, blue: 0.12, alpha: 1.0))))
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Account Actions Section
    private var accountActionsSection: some View {
        VStack(spacing: 16) {
            Button(action: { showLogoutAlert = true }) {
                Text("Log Out")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    viewModel.logOut()
                    navigateToLogin = true
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            
            Button(action: { showDeleteAlert = true }) {
                Text("Delete Account")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showDeleteAlert) {
            DeleteAccountReasonView(reason: $deleteReason, onConfirm: {
                viewModel.deleteAccount(reason: deleteReason)
                showDeleteAlert = false
                navigateToLogin = true
            })
        }
        .onAppear {
            // Reload subscription status when view appears
            Task {
                await viewModel.loadSubscriptionStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SubscriptionUpdated"))) { _ in
            // Reload subscription when subscription is updated
            Task {
                await viewModel.loadSubscriptionStatus()
            }
        }
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        VStack {
            Spacer()
            
            Button(action: viewModel.saveChanges) {
                Text("Save Changes")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.2), radius: 10)
            }
            .padding()
        }
    }
}

// MARK: - Subscription Options View
struct SubscriptionOptionsView: View {
    @ObservedObject var viewModel: ProfileSettingsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor(red: 0.06, green: 0.09, blue: 0.24, alpha: 1.0))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Premium Features
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Premium Features")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            FeatureRow(icon: "star.fill", title: "Exclusive Content", description: "Access premium workouts and challenges")
                            FeatureRow(icon: "chart.bar.fill", title: "Advanced Analytics", description: "Detailed insights into your performance")
                            FeatureRow(icon: "person.2.fill", title: "Priority Support", description: "24/7 dedicated customer support")
                            FeatureRow(icon: "crown.fill", title: "Premium Badge", description: "Show your premium status")
                        }
                        .padding()
                        
                        // Subscription Plans
                        VStack(spacing: 16) {
                            SubscriptionPlanCard(
                                title: "Monthly",
                                price: "$9.99",
                                period: "per month",
                                isRecommended: false,
                                action: { viewModel.subscribeToPlan(.monthly) }
                            )
                            
                            SubscriptionPlanCard(
                                title: "Annual",
                                price: "$99.99",
                                period: "per year",
                                isRecommended: true,
                                action: { viewModel.subscribeToPlan(.annual) }
                            )
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
    }
}

// MARK: - Helper Views
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(Color(UIColor(red: 0.97, green: 0.58, blue: 0.12, alpha: 1.0)))
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

struct SubscriptionPlanCard: View {
    let title: String
    let price: String
    let period: String
    let isRecommended: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                if isRecommended {
                    Text("BEST VALUE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(UIColor(red: 0.97, green: 0.58, blue: 0.12, alpha: 1.0)))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text(price)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text(period)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isRecommended ? Color(UIColor(red: 0.97, green: 0.58, blue: 0.12, alpha: 1.0)) : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Delete Account Reason View
struct DeleteAccountReasonView: View {
    @Binding var reason: String
    let onConfirm: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor(red: 0.06, green: 0.09, blue: 0.24, alpha: 1.0))
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("We're sorry to see you go")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Please let us know why you're deleting your account. This helps us improve.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    TextEditor(text: $reason)
                        .frame(height: 150)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        onConfirm()
                    }) {
                        Text("Delete Account")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
    }
}

// MARK: - Login Navigation View
struct LoginNavigationView: View {
    var body: some View {
        Color.black
            .ignoresSafeArea()
            .onAppear {
                // Use SceneDelegate's logout method to navigate to login
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let sceneDelegate = windowScene.delegate as? SceneDelegate {
                    sceneDelegate.logoutUser(windowScene: windowScene)
                }
            }
    }
}
