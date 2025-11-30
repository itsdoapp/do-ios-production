//
//  PasswordChangePrompt.swift
//  Do
//
//  Password change prompt for first-time AWS Cognito login (FORCE_CHANGE_PASSWORD status)
//

import SwiftUI

struct PasswordChangePrompt: View {
    @Binding var isPresented: Bool
    let username: String
    let temporaryPassword: String
    let onPasswordChanged: () -> Void
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissal by tapping outside
                }
            
            // Card
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.brandOrange)
                    
                    Text("Security Update Required")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("We've enhanced our security standards. Please create a new password that meets our updated requirements to continue.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                
                // New Password field
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Password")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary.opacity(0.9))
                    
                    HStack {
                        if showNewPassword {
                            TextField("", text: $newPassword)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("", text: $newPassword)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        
                        Button(action: { showNewPassword.toggle() }) {
                            Image(systemName: showNewPassword ? "eye.slash" : "eye")
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.brandOrange.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Confirm Password field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary.opacity(0.9))
                    
                    HStack {
                        if showConfirmPassword {
                            TextField("", text: $confirmPassword)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("", text: $confirmPassword)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        
                        Button(action: { showConfirmPassword.toggle() }) {
                            Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.brandOrange.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Password requirements
                VStack(alignment: .leading, spacing: 6) {
                    Text("Password Requirements:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        RequirementRow(text: "At least 8 characters")
                        RequirementRow(text: "One uppercase letter (A-Z)")
                        RequirementRow(text: "One lowercase letter (a-z)")
                        RequirementRow(text: "One number (0-9)")
                        RequirementRow(text: "One special character (!@#$%^&*)")
                    }
                }
                .padding(.horizontal, 8)
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                // Confirm button
                Button(action: changePassword) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Set Password")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.brandOrange,
                                        Color.brandOrange.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.brandOrange.opacity(0.4), radius: 8, x: 0, y: 4)
                    )
                }
                .disabled(isLoading || newPassword.isEmpty || confirmPassword.isEmpty)
                .opacity((newPassword.isEmpty || confirmPassword.isEmpty) ? 0.5 : 1.0)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.brandBlue)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.brandOrange.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
            )
            .padding(.horizontal, 24)
        }
    }
    
    private func changePassword() {
        guard !newPassword.isEmpty, !confirmPassword.isEmpty else { return }
        
        // Validate passwords match
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        // Validate password requirements
        if newPassword.count < 8 {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        
        let hasUppercase = newPassword.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = newPassword.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = newPassword.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecial = newPassword.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        
        if !hasUppercase || !hasLowercase || !hasNumber || !hasSpecial {
            errorMessage = "Password must contain uppercase, lowercase, number, and special character"
            return
        }
        
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                print("🔐 [PasswordChange] Setting password for user: \(username)")
                
                // Step 1: Set the new password via backend Lambda
                try await PasswordChangeService.shared.setUserPassword(
                    username: username,
                    newPassword: newPassword
                )
                
                print("✅ [PasswordChange] Password set successfully")
                
                // Step 2: Sign in with the new password
                print("🔐 [PasswordChange] Signing in with new password...")
                try await AuthService.shared.signIn(email: username, password: newPassword)
                
                print("✅ [PasswordChange] Signed in successfully")
                
                await MainActor.run {
                    isLoading = false
                    isPresented = false
                    onPasswordChanged()
                }
            } catch {
                print("❌ [PasswordChange] Error: \(error)")
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Requirement Row Component
struct RequirementRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.brandOrange.opacity(0.8))
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}
