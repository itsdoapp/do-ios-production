//
//  NetworkError.swift
//  Do
//
//  Network error types for API calls
//

import Foundation

enum NetworkError: Error {
    case invalidURL
    case invalidResponse(String)
    case unauthorized
    case serverError(Int, String?)
    case httpError(Int, String?)
    case decodingError(Error)
    case noData
    case requestFailed(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .unauthorized:
            return "Unauthorized - please sign in"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .httpError(let code, let message):
            return "HTTP error (\(code)): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        }
    }
}
