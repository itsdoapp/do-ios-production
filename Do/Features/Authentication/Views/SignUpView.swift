//
//  SignUpView.swift
//  Do
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authService = AuthService.shared
    
    @State private var email = ""
    @State private var username = ""
    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var agreedToTerms = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlue.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Create Account")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(.textPrimary)
                            
                            Text("Join the Do community")
                                .font(.system(size: 16))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.top, 40)
                        
                        // Form
                        VStack(spacing: 20) {
                            // Name
                            AuthTextField(
                                title: "Full Name",
                                text: $name,
                                placeholder: "John Doe"
                            )
                            
                            // Username
                            AuthTextField(
                                title: "Username",
                                text: $username,
                                placeholder: "johndoe"
                            )
                            .textInputAutocapitalization(.never)
                            
                            // Email
                            AuthTextField(
                                title: "Email",
                                text: $email,
                                placeholder: "john@example.com",
                                keyboardType: .emailAddress
                            )
                            .textInputAutocapitalization(.never)
                            
                            // Password
                            AuthTextField(
                                title: "Password",
                                text: $password,
                                placeholder: "Min. 8 characters",
                                isSecure: !showPassword,
                                showPasswordToggle: true,
                                showPassword: $showPassword
                            )
                            
                            // Confirm Password
                            AuthTextField(
                                title: "Confirm Password",
                                text: $confirmPassword,
                                placeholder: "Re-enter password",
                                isSecure: true
                            )
                            
                            // Terms checkbox
                            HStack(spacing: 12) {
                                Button(action: { agreedToTerms.toggle() }) {
                                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                        .foregroundColor(agreedToTerms ? .brandOrange : .textSecondary)
                                        .font(.system(size: 20))
                                }
                                
                                Text("I agree to the Terms & Conditions")
                                    .font(.system(size: 14))
                                    .foregroundColor(.textSecondary)
                                
                                Spacer()
                            }
                            
                            // Sign up button
                            Button(action: signUp) {
                                if authService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Create Account")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.brandOrange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .disabled(!isFormValid || authService.isLoading)
                            .opacity(isFormValid ? 1.0 : 0.5)
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
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !username.isEmpty &&
        !name.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 8 &&
        agreedToTerms
    }
    
    private func signUp() {
        Task {
            do {
                try await authService.signUp(
                    email: email,
                    password: password,
                    username: username,
                    name: name
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Auth Text Field Component

struct AuthTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var showPasswordToggle: Bool = false
    @Binding var showPassword: Bool
    
    init(title: String,
         text: Binding<String>,
         placeholder: String = "",
         keyboardType: UIKeyboardType = .default,
         isSecure: Bool = false,
         showPasswordToggle: Bool = false,
         showPassword: Binding<Bool> = .constant(false)) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.isSecure = isSecure
        self.showPasswordToggle = showPasswordToggle
        self._showPassword = showPassword
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textPrimary.opacity(0.9))
            
            HStack {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(.textPrimary)
                        .keyboardType(keyboardType)
                } else {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(.textPrimary)
                        .keyboardType(keyboardType)
                }
                
                if showPasswordToggle {
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.textSecondary)
                    }
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
    }
}

#Preview {
    SignUpView()
}
