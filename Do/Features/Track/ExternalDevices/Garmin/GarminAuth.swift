//
//  GarminAuth.swift
//  Do
//
//  OAuth authentication for Garmin Connect
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import AuthenticationServices

class GarminAuth: NSObject {
    static let shared = GarminAuth()
    
    private let consumerKey: String
    private let consumerSecret: String
    private let userDefaults = UserDefaults.standard
    private let tokenKey = "garmin_access_token"
    private let tokenSecretKey = "garmin_access_token_secret"
    
    private override init() {
        self.consumerKey = userDefaults.string(forKey: "garmin_consumer_key") ?? ""
        self.consumerSecret = userDefaults.string(forKey: "garmin_consumer_secret") ?? ""
        super.init()
    }
    
    func startOAuthFlow() {
        // Garmin uses OAuth 1.0a
        let authURL = URL(string: "https://connect.garmin.com/oauthConfirm?oauth_token=\(consumerKey)")!
        
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(authURL)
        }
    }
    
    func handleOAuthCallback(verifier: String) async throws {
        // Exchange request token for access token
        let tokenURL = URL(string: "https://connect.garmin.com/oauth/access_token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        // OAuth 1.0a signature would be added here
        // This is simplified - full implementation requires OAuth 1.0a signing
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DeviceError.authenticationRequired
        }
        
        // Parse OAuth response and store tokens
        // Implementation would parse oauth_token and oauth_token_secret
        userDefaults.set("access_token", forKey: tokenKey)
        userDefaults.set("token_secret", forKey: tokenSecretKey)
    }
}

