//
//  LLMModels.swift
//  Do
//
//  LLM-related models for Genie
//

import Foundation

/// Token usage details returned by LLM providers
public struct LLMUsage: Codable, Hashable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
    public let model: String?
    
    public init(promptTokens: Int, completionTokens: Int, totalTokens: Int, model: String?) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.model = model
    }
}


