//
//  AnalysisResponse.swift
//  Do
//
//  Analysis response models for Genie
//

import Foundation
import SwiftUI

/// Analysis response from Genie
struct AnalysisResponse: Codable {
    let summary: String
    let analysis: Analysis
    let recommendations: [Recommendation]
    let insights: [String]
    let dataUsed: DataUsed
    
    enum CodingKeys: String, CodingKey {
        case summary, analysis, recommendations, insights
        case dataUsed = "data_used"
    }
    
    struct Analysis: Codable {
        let performance: String
        let patterns: String
        let recovery: String
    }
    
    struct Recommendation: Codable {
        let type: String
        let action: String
    }
    
    struct DataUsed: Codable {
        let runsAnalyzed: Int
        let dateRange: String
        let totalDistance: String
        
        enum CodingKeys: String, CodingKey {
            case runsAnalyzed = "runs_analyzed"
            case dateRange = "date_range"
            case totalDistance = "total_distance"
        }
    }
}

/// Extension to detect and parse JSON from strings
extension String {
    func tryParseAnalysisJSON() -> AnalysisResponse? {
        guard let data = self.data(using: .utf8) else { return nil }
        
        // Try to extract JSON if wrapped in markdown code blocks
        let jsonString: String
        if let range = self.range(of: "```json\\s*\\n?([\\s\\S]*?)\\n?```", options: .regularExpression) {
            jsonString = String(self[range].dropFirst(7).dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if self.trimmingCharacters(in: .whitespacesAndNewlines).first == "{" {
            jsonString = self
        } else {
            return nil
        }
        
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(AnalysisResponse.self, from: jsonData)
        } catch {
            print("Failed to parse analysis JSON: \(error)")
            return nil
        }
    }
}


