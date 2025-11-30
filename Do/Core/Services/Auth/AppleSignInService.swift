//
//  AppleSignInService.swift
//  Do
//

import Foundation
import AuthenticationServices
import UIKit

final class AppleSignInService: NSObject {
    static let shared = AppleSignInService()
    
    private var continuation: CheckedContinuation<(identityToken: String, authorizationCode: String), Error>?
    
    private override init() {
        super.init()
    }

    func signIn() async throws -> (identityToken: String, authorizationCode: String) {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

extension AppleSignInService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authorizationCodeData = credential.authorizationCode,
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            continuation?.resume(throwing: AuthError.invalidCredentials)
            return
        }
        
        continuation?.resume(returning: (identityToken: identityToken, authorizationCode: authorizationCode))
        continuation = nil
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            return window
        }
        // Fallback anchor
        return UIWindow()
    }
}
