// TokenBalanceWarningBanner.swift
import SwiftUI

struct TokenBalanceWarningBanner: View {
    let warning: BalanceWarning
    let onTopUp: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
            
            Text(warning.message)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if warning.recommendation != nil {
                Button("Top Up", action: onTopUp)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(color)
                    .cornerRadius(8)
            }
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var icon: String {
        warning.level == "critical" ? "exclamationmark.triangle.fill" : "info.circle.fill"
    }
    
    private var color: Color {
        warning.level == "critical" ? .red : warning.level == "low" ? .orange : .blue
    }
}

// Note: BalanceWarning is defined in GenieAPIService.swift
