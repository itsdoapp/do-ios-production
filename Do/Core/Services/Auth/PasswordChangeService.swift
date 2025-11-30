//
//  PasswordChangeService.swift
//  Do
//
//  Service to handle password changes via backend Lambda
//

import Foundation

class PasswordChangeService {
    static let shared = PasswordChangeService()
    
    private let baseURL = "https://l1qgkmrn12.execute-api.us-east-1.amazonaws.com/prod"
    
    private init() {}
    
    func setUserPassword(username: String, newPassword: String) async throws {
        print("🔐 [PasswordChangeService] Setting password for: \(username)")
        
        guard let url = URL(string: "\(baseURL)/auth/set-password") else {
            throw NSError(domain: "PasswordChangeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "username": username,
            "newPassword": newPassword
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "PasswordChangeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("🔐 [PasswordChangeService] Response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorResponse["error"] as? String {
                throw NSError(domain: "PasswordChangeService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            throw NSError(domain: "PasswordChangeService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to update password"])
        }
        
        print("✅ [PasswordChangeService] Password updated successfully")
    }
}
