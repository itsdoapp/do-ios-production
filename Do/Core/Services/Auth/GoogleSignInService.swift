//
//  GoogleSignInService.swift
//  Do
//

import Foundation
import GoogleSignIn
import UIKit

class GoogleSignInService {
    static let shared = GoogleSignInService()
    
    private init() {}
    
    func signIn() async throws -> String {
        // Ensure Google Client ID is configured
        guard !Constants.Google.clientID.isEmpty else {
            throw AuthError.unknown("Google clientID is not set. Set Constants.Google.clientID and add reversed client ID URL scheme to Info.plist.")
        }
        // Configure GIDSignIn if needed
        if GIDSignIn.sharedInstance.configuration == nil {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: Constants.Google.clientID)
        }
        
        guard let presentingViewController = await getRootViewController() else {
            throw AuthError.unknown("No presenting view controller")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    continuation.resume(throwing: AuthError.invalidCredentials)
                    return
                }
                
                continuation.resume(returning: idToken)
            }
        }
    }
    
    @MainActor
    private func getRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = scene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }
}
