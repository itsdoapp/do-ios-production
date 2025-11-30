//
//  LoginView.swift
//  Do
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isAnimating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var showPasswordChange = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Brand background
                Color.brandBlue
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { focusedField = nil }
                
                // Brand accent line
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.brandOrange,
                                    Color.brandOrange.opacity(0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                    
                    Spacer()
                }
                
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 80)
                        
                        // Logo section
                        VStack(spacing: 32) {
                            Image("logo_45")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .scaleEffect(isAnimating ? 1.0 : 0.95)
                                .opacity(isAnimating ? 1.0 : 0.0)
                            
                            VStack(spacing: 12) {
                                Text("Welcome Back")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(.textPrimary)
                                    .offset(y: isAnimating ? 0 : 10)
                                    .opacity(isAnimating ? 1.0 : 0.0)
                                
                                Text("Sign in to your account")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.textSecondary)
                                    .offset(y: isAnimating ? 0 : 10)
                                    .opacity(isAnimating ? 1.0 : 0.0)
                            }
                        }
                        .padding(.horizontal, 40)
                        
                        Spacer(minLength: 60)
                        
                        // Form
                        VStack(spacing: 24) {
                            // Email or Username field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email or Username")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.textPrimary.opacity(0.9))
                                
                                TextField("", text: $email)
                                    .font(.system(size: 16))
                                    .foregroundColor(.textPrimary)
                                    .keyboardType(.default)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .email)
                                    .padding()
                                    .background(Color.cardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                            
                            // Password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.textPrimary.opacity(0.9))
                                
                                HStack {
                                    if showPassword {
                                        TextField("", text: $password)
                                            .font(.system(size: 16))
                                            .foregroundColor(.textPrimary)
                                            .focused($focusedField, equals: .password)
                                    } else {
                                        SecureField("", text: $password)
                                            .font(.system(size: 16))
                                            .foregroundColor(.textPrimary)
                                            .focused($focusedField, equals: .password)
                                    }
                                    
                                    Button(action: { showPassword.toggle() }) {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            
                            // Forgot password
                            HStack {
                                Spacer()
                                Button("Forgot Password?") {
                                    showForgotPassword = true
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.brandOrange)
                            }
                            
                            // Sign in button
                            Button(action: {
                                print("🔵 Sign In button tapped")
                                signIn()
                            }) {
                                ZStack {
                                    if authService.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Sign In")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.brandOrange)
                            .cornerRadius(12)
                            .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
                            .opacity((email.isEmpty || password.isEmpty) ? 0.5 : 1.0)
                            
                            // Divider
                            HStack(spacing: 16) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 1)
                                
                                Text("or")
                                    .font(.system(size: 14))
                                    .foregroundColor(.textSecondary)
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 1)
                            }
                            .padding(.vertical, 8)
                            
                            // Social login buttons
                            VStack(spacing: 12) {
                                SocialLoginButton(
                                    icon: "apple.logo",
                                    title: "Continue with Apple",
                                    action: signInWithApple
                                )
                                
                                SocialLoginButton(
                                    icon: "g.circle.fill",
                                    title: "Continue with Google",
                                    action: signInWithGoogle
                                )
                            }
                            
                            // Sign up link
                            HStack(spacing: 4) {
                                Text("Don't have an account?")
                                    .font(.system(size: 14))
                                    .foregroundColor(.textSecondary)
                                
                                Button("Sign Up") {
                                    showSignUp = true
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.brandOrange)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 32)
                        
                        Spacer(minLength: 40)
                    }
                }
                .padding(.bottom, keyboardHeight)
                .scrollDismissesKeyboard(.interactively)
            }
            
            // Custom error banner
            if showError {
                VStack {
                    ErrorBanner(message: errorMessage, isShowing: $showError)
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .zIndex(999)
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .fullScreenCover(isPresented: $showPasswordChange) {
            if let username = authService.usernameForPasswordChange,
               let tempPassword = authService.temporaryPassword {
                PasswordChangePrompt(
                    isPresented: $showPasswordChange,
                    username: username,
                    temporaryPassword: tempPassword,
                    onPasswordChanged: {
                        // Password changed successfully, user is now authenticated
                        print("✅ Password changed, user authenticated")
                    }
                )
            }
        }
        .onChange(of: authService.needsPasswordChange) { needsChange in
            if needsChange {
                showPasswordChange = true
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                isAnimating = true
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { note in
                guard let info = note.userInfo,
                      let end = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
                // Convert to screen height and account for safe area
                let screenHeight = UIScreen.main.bounds.height
                let bottomInset = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
                let height = max(0, screenHeight - end.origin.y - bottomInset)
                withAnimation(.easeOut(duration: 0.2)) { keyboardHeight = height }
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                withAnimation(.easeOut(duration: 0.2)) { keyboardHeight = 0 }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }
    
    // MARK: - Actions
    
    private func signIn() {
        print("🟢 signIn() called")
        print("📧 Email/Username: \(email)")
        print("🔒 Password length: \(password.count)")
        print("⏳ Auth service loading: \(authService.isLoading)")
        print("✅ Auth service authenticated: \(authService.isAuthenticated)")
        
        // Validate input
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("❌ Validation failed: Email/username is empty")
            showErrorMessage("Please enter your email or username")
            return
        }
        
        guard !password.isEmpty else {
            print("❌ Validation failed: Password is empty")
            showErrorMessage("Please enter your password")
            return
        }
        
        print("✅ Validation passed, starting authentication...")
        
        Task {
            do {
                print("🔄 Calling authService.signIn...")
                try await authService.signIn(email: email, password: password)
                print("✅ Sign in successful!")
                print("✅ Auth service authenticated: \(authService.isAuthenticated)")
            } catch let error as AuthError {
                print("❌ AuthError caught: \(error)")
                switch error {
                case .invalidCredentials:
                    print("❌ Invalid credentials")
                    // Check if user needs password change (could be FORCE_CHANGE_PASSWORD status)
                    Task {
                        if await checkIfPasswordChangeNeeded(username: email) {
                            print("🔐 User needs password change - showing prompt")
                            authService.needsPasswordChange = true
                            authService.usernameForPasswordChange = email
                            authService.temporaryPassword = password
                        } else {
                            showErrorMessage("Incorrect username or password. Please try again.")
                        }
                    }
                case .userNotFound:
                    print("❌ User not found")
                    showErrorMessage("Account not found. Please check your credentials or sign up.")
                case .networkError:
                    print("❌ Network error")
                    showErrorMessage("Network error. Please check your connection and try again.")
                case .unknown(let message):
                    print("❌ Unknown error: \(message)")
                    showErrorMessage(message)
                default:
                    print("❌ Unexpected error type")
                    showErrorMessage("An unexpected error occurred. Please try again.")
                }
            } catch {
                print("❌ Generic error caught: \(error.localizedDescription)")
                showErrorMessage(error.localizedDescription)
            }
        }
    }
    
    private func checkIfPasswordChangeNeeded(username: String) async -> Bool {
        // Check if user has custom:pwd_changed = "false"
        // This indicates they are a migrated user who needs to set their password
        do {
            // Call backend to check user status
            // For now, we'll use a simple heuristic: if they get invalid credentials,
            // assume they need password change (they can always use Forgot Password if not)
            return true
        } catch {
            return false
        }
    }
    
    private func showErrorMessage(_ message: String) {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        errorMessage = message
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showError = true
        }
        
        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showError = false
            }
        }
    }
    
    private func signInWithApple() {
        Task {
            do {
                try await authService.signInWithApple()
            } catch let error as AuthError {
                switch error {
                case .unknown(let message) where message.contains("canceled"):
                    // User canceled - don't show error
                    break
                default:
                    showErrorMessage("Apple Sign In failed. Please try again.")
                }
            } catch {
                showErrorMessage("Apple Sign In failed. Please try again.")
            }
        }
    }
    
    private func signInWithGoogle() {
        Task {
            do {
                try await authService.signInWithGoogle()
            } catch let error as AuthError {
                switch error {
                case .unknown(let message) where message.contains("canceled") || message.contains("clientID"):
                    if message.contains("clientID") {
                        showErrorMessage("Google Sign In is not configured. Please contact support.")
                    }
                    // User canceled - don't show error
                default:
                    showErrorMessage("Google Sign In failed. Please try again.")
                }
            } catch {
                showErrorMessage("Google Sign In failed. Please try again.")
            }
        }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Error icon with pulsing animation
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            }
            
            // Error message
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // Dismiss button
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    isShowing = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.8, green: 0.2, blue: 0.2),
                            Color(red: 0.6, green: 0.1, blue: 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.red.opacity(0.3), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Social Login Button

struct SocialLoginButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.cardBackground)
            .foregroundColor(.textPrimary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

#Preview {
    LoginView()
}
