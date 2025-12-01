//
//  GenieService.swift
//  Do Watch App
//
//  Service for fetching Genie smart tips
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

/// Service responsible for fetching Genie tips.
class GenieService: ObservableObject {
    static let shared = GenieService()
    
    @Published var currentTip: String?
    @Published var isLoading = false
    @Published var tokenBalance: Int?
    @Published var isOutOfTokens = false
    
    private let baseURL = "https://nuexjddrx7.execute-api.us-east-1.amazonaws.com"
    private let session = URLSession.shared
    
    private init() {}
    
    func fetchBalance() {
        Task {
            do {
                let balance = try await getTokenBalance()
                DispatchQueue.main.async {
                    self.tokenBalance = balance
                    self.isOutOfTokens = balance <= 0
                }
            } catch {
                print("❌ [GenieService] Error fetching balance: \(error)")
            }
        }
    }
    
    func fetchTip(for workoutType: String, metrics: [String: Any]?) {
        guard !isLoading else { return }
        
        // Optimistic check
        if let balance = tokenBalance, balance <= 0 {
            self.isOutOfTokens = true
            // Provide fallback immediately even if out of tokens
            let fallback = self.generateFallbackTip(for: workoutType)
            self.currentTip = fallback
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let tip = try await queryGenie(workoutType: workoutType, metrics: metrics)
                DispatchQueue.main.async {
                    self.currentTip = tip
                    self.isLoading = false
                    // Decrement local balance optimistically
                    if let current = self.tokenBalance, current > 0 {
                        self.tokenBalance = current - 1
                    }
                }
            } catch let error as NSError where error.code == 402 { // 402 Payment Required
                 print("⚠️ [GenieService] Insufficient tokens")
                 DispatchQueue.main.async {
                     self.isOutOfTokens = true
                     self.isLoading = false
                     self.tokenBalance = 0
                     // Provide fallback tip so user sees something
                     self.currentTip = self.generateFallbackTip(for: workoutType)
                 }
            } catch {
                print("❌ [GenieService] Error fetching tip: \(error)")
                // Fallback to local tip on error
                let fallback = self.generateFallbackTip(for: workoutType)
                DispatchQueue.main.async {
                    self.currentTip = fallback
                    self.isLoading = false
                }
            }
        }
    }
    
    private func getTokenBalance() async throws -> Int {
        guard let url = URL(string: "\(baseURL)/tokens/balance") else {
            throw URLError(.badURL)
        }
        
        guard let tokens = WatchAuthService.shared.getCachedTokens(),
              let idToken = tokens["idToken"] as? String, !idToken.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        // Add X-User-Id header if available (required for Parse user lookup)
        if let userId = tokens["userId"] as? String, !userId.isEmpty {
             request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let balanceResponse = try JSONDecoder().decode(TokenBalanceResponse.self, from: data)
        return balanceResponse.balance
    }
    
    private func queryGenie(workoutType: String, metrics: [String: Any]?) async throws -> String {
        guard let url = URL(string: "\(baseURL)/query") else {
            throw URLError(.badURL)
        }
        
        // Get Auth Token
        guard let tokens = WatchAuthService.shared.getCachedTokens(),
              let idToken = tokens["idToken"] as? String, !idToken.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        // Construct Context Query
        var queryText = "I am currently doing a \(workoutType) workout."
        if let metrics = metrics {
            // flatten metrics into a readable string
            let metricsString = metrics.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            queryText += " My current stats are: \(metricsString)."
        }
        queryText += " Give me a short, motivational tip or coaching advice in 1 sentence."
        
        // Create Request Body
        let requestBody = GenieQueryRequest(
            query: queryText,
            sessionId: UUID().uuidString,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            locale: Locale.current.identifier,
            isVoiceInput: false
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 15 // Short timeout for watch
        
        // Execute Request
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 402 {
            // 402 Payment Required (Insufficient Tokens)
            // We use a custom error code since URLError doesn't have paymentRequired
            throw NSError(domain: "com.do.genie", code: 402, userInfo: [NSLocalizedDescriptionKey: "Insufficient tokens"])
        }
        
        guard httpResponse.statusCode == 200 else {
            if let str = String(data: data, encoding: .utf8) {
                 print("❌ [GenieService] Server Error: \(str)")
            }
            throw URLError(.badServerResponse)
        }
        
        let genieResponse = try JSONDecoder().decode(GenieQueryResponse.self, from: data)
        
        // Update balance if returned
        DispatchQueue.main.async {
            self.tokenBalance = genieResponse.tokensRemaining
        }
        
        return genieResponse.response
    }
    
    private func generateFallbackTip(for workoutType: String) -> String {
        let genericTips = [
            "Great pace! You're trending faster than yesterday.",
            "Heart rate is in the fat burn zone. Keep it steady!",
            "Shoulders down, chin up. Form check!",
            "You're crushing your weekly goal!",
            "Hydrate soon if you haven't yet.",
            "Only 5 minutes to beat your personal best!",
            "Focus on your breathing. In through nose, out through mouth.",
            "Looking strong! Keep that cadence up."
        ]
        
        return genericTips.randomElement() ?? "Keep going!"
    }
}
