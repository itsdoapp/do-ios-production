//
//  FitbitAuth.swift
//  Do
//
//  OAuth authentication for Fitbit API
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import AuthenticationServices

class FitbitAuth: NSObject {
    static let shared = FitbitAuth()
    
    private let clientId: String
    private let redirectURI = "doapp://fitbit/callback"
    private let userDefaults = UserDefaults.standard
    private let tokenKey = "fitbit_access_token"
    private let refreshTokenKey = "fitbit_refresh_token"
    
    private override init() {
        self.clientId = userDefaults.string(forKey: "fitbit_client_id") ?? ""
        super.init()
    }
    
    func startOAuthFlow() {
        let scope = "activity%20heartrate%20profile"
        let authURL = URL(string: "https://www.fitbit.com/oauth2/authorize?response_type=code&client_id=\(clientId)&redirect_uri=\(redirectURI)&scope=\(scope)")!
        
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(authURL)
        }
    }
    
    func handleOAuthCallback(code: String) async throws {
        let tokenURL = URL(string: "https://api.fitbit.com/oauth2/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let clientSecret = userDefaults.string(forKey: "fitbit_client_secret") ?? ""
        let credentials = "\(clientId):\(clientSecret)".data(using: .utf8)?.base64EncodedString() ?? ""
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        let body = "grant_type=authorization_code&code=\(code)&redirect_uri=\(redirectURI)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String else {
            throw DeviceError.authenticationRequired
        }
        
        userDefaults.set(accessToken, forKey: tokenKey)
        userDefaults.set(refreshToken, forKey: refreshTokenKey)
    }
    
    func refreshAccessToken() async throws {
        guard let refreshToken = userDefaults.string(forKey: refreshTokenKey) else {
            throw DeviceError.authenticationRequired
        }
        
        let tokenURL = URL(string: "https://api.fitbit.com/oauth2/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let clientSecret = userDefaults.string(forKey: "fitbit_client_secret") ?? ""
        let credentials = "\(clientId):\(clientSecret)".data(using: .utf8)?.base64EncodedString() ?? ""
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)"
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

