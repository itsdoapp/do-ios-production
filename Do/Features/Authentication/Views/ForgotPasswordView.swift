//
//  ForgotPasswordView.swift
//  Do
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authService = AuthService.shared
    
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var codeSent = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlue.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 60))
                                .foregroundColor(.brandOrange)
                            
                            Text(codeSent ? "Reset Password" : "Forgot Password?")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(.textPrimary)
                            
                            Text(codeSent ? "Enter the code sent to your email" : "Enter your email to receive a reset code")
                                .font(.system(size: 16))
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 60)
                        
                        // Form
                        VStack(spacing: 20) {
                            if !codeSent {
                                // Email field
                                AuthTextField(
                                    title: "Email",
                                    text: $email,
                                    placeholder: "your@email.com",
                                    keyboardType: .emailAddress
                                )
                                .textInputAutocapitalization(.never)
                                
                                Button(action: sendCode) {
                                    if authService.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Send Reset Code")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.brandOrange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .disabled(email.isEmpty || authService.isLoading)
                                .opacity(email.isEmpty ? 0.5 : 1.0)
                            } else {
                                // Code field
                                AuthTextField(
                                    title: "Reset Code",
                                    text: $code,
                                    placeholder: "Enter 6-digit code",
                                    keyboardType: .numberPad
                                )
                                
                                // New password
                                AuthTextField(
                                    title: "New Password",
                                    text: $newPassword,
                                    placeholder: "Min. 8 characters",
                                    isSecure: true
                                )
                                
                                // Confirm password
                                AuthTextField(
                                    title: "Confirm Password",
                                    text: $confirmPassword,
                                    placeholder: "Re-enter password",
                                    isSecure: true
                                )
                                
                                Button(action: resetPassword) {
                                    if authService.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Reset Password")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.brandOrange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .disabled(!isResetFormValid || authService.isLoading)
                                .opacity(isResetFormValid ? 1.0 : 0.5)
                                
                                Button("Resend Code") {
                                    sendCode()
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.brandOrange)
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.brandOrange)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your password has been reset successfully")
            }
        }
    }
    
    private var isResetFormValid: Bool {
        !code.isEmpty &&
        !newPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8
    }
    
    private func sendCode() {
        Task {
            do {
                try await authService.forgotPassword(email: email)
                await MainActor.run {
                    codeSent = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func resetPassword() {
        Task {
            do {
                try await authService.confirmForgotPassword(
                    email: email,
                    code: code,
                    newPassword: newPassword
                )
                await MainActor.run {
                    showSuccess = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
}
