//
//  OuraRingAuth.swift
//  Do
//
//  OAuth authentication for Oura API
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import AuthenticationServices

class OuraRingAuth: NSObject {
    static let shared = OuraRingAuth()
    
    private let clientId: String
    private let redirectURI = "doapp://oura/callback"
    private let userDefaults = UserDefaults.standard
    private let tokenKey = "oura_access_token"
    private let refreshTokenKey = "oura_refresh_token"
    
    private override init() {
        // In production, load from secure storage or config
        self.clientId = userDefaults.string(forKey: "oura_client_id") ?? ""
        super.init()
    }
    
    func startOAuthFlow() {
        let authURL = URL(string: "https://cloud.ouraring.com/oauth/authorize?client_id=\(clientId)&redirect_uri=\(redirectURI)&response_type=code&scope=email%20personal")!
        
        // Open OAuth URL in browser
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(authURL)
        }
    }
    
    func handleOAuthCallback(code: String) async throws {
        // Exchange authorization code for access token
        let tokenURL = URL(string: "https://api.ouraring.com/oauth/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "grant_type=authorization_code&code=\(code)&redirect_uri=\(redirectURI)&client_id=\(clientId)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String else {
            throw DeviceError.authenticationRequired
        }
        
        // Store tokens
        userDefaults.set(accessToken, forKey: tokenKey)
        userDefaults.set(refreshToken, forKey: refreshTokenKey)
    }
    
    func refreshAccessToken() async throws {
        guard let refreshToken = userDefaults.string(forKey: refreshTokenKey) else {
            throw DeviceError.authenticationRequired
        }
        
        let tokenURL = URL(string: "https://api.ouraring.com/oauth/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(clientId)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw DeviceError.authenticationRequired
        }
        
        userDefaults.set(accessToken, forKey: tokenKey)
    }
}

