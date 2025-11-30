//
//  YouTubeService.swift
//  Do
//
//  Service for searching YouTube videos using YouTube Data API v3
//

import Foundation

// Use existing VideoResult instead of creating duplicate
// YouTubeVideo is now just a typealias for VideoResult

@MainActor
class YouTubeService: ObservableObject {
    static let shared = YouTubeService()
    
    private var apiKey: String? {
        // Get API key from KeychainManager (stored as "google" service)
        if let key = KeychainManager.shared.getAPIKey(for: "google"),
           !key.isEmpty,
           key != "YOUR_GOOGLE_API_KEY_HERE" {
            return key
        }
        // Fallback to environment variable for development
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"],
           !envKey.isEmpty {
            return envKey
        }
        return nil
    }
    
    private init() {}
    
    /// Search for YouTube videos using YouTube Data API v3
    func searchVideos(query: String, limit: Int = 5) async throws -> [VideoResult] {
        // Check if API key is available
        guard let apiKey = apiKey else {
            print("⚠️ [YouTube] API key not configured, falling back to YouTube search URL")
            return createSearchPlaceholder(query: query)
        }
        
        // Build YouTube Data API v3 search URL
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "maxResults", value: "\(limit)"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "order", value: "relevance") // Get most relevant results
        ]
        
        guard let url = components.url else {
            throw YouTubeServiceError.invalidURL
        }
        
        print("🎥 [YouTube] Searching for videos: \(query)")
        
        // Make API request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            print("❌ [YouTube] Network error: \(error.localizedDescription)")
            throw YouTubeServiceError.networkError(error)
        }
        
        // Check HTTP response
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 403 {
                print("❌ [YouTube] API key invalid or quota exceeded")
                throw YouTubeServiceError.apiKeyInvalid
            } else if httpResponse.statusCode != 200 {
                print("❌ [YouTube] API error: HTTP \(httpResponse.statusCode)")
                throw YouTubeServiceError.apiError(statusCode: httpResponse.statusCode)
            }
        }
        
        // Parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            print("❌ [YouTube] Failed to parse API response")
            throw YouTubeServiceError.invalidResponse
        }
        
        // Convert API response to VideoResult array
        var videos: [VideoResult] = []
        
        for item in items {
            guard let id = item["id"] as? [String: Any],
                  let videoId = id["videoId"] as? String,
                  let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String,
                  let channelTitle = snippet["channelTitle"] as? String else {
                continue
            }
            
            // Get thumbnail URL (prefer high quality, fallback to default)
            let thumbnails = snippet["thumbnails"] as? [String: Any]
            let thumbnailDict = thumbnails?["high"] as? [String: Any] ?? thumbnails?["default"] as? [String: Any]
            let thumbnail = thumbnailDict?["url"] as? String ?? "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"
            
            videos.append(VideoResult(
                videoId: videoId,
                title: title,
                thumbnail: thumbnail,
                channel: channelTitle,
                url: "https://www.youtube.com/watch?v=\(videoId)"
            ))
        }
        
        print("✅ [YouTube] Found \(videos.count) videos")
        
        // If no videos found, return placeholder with search link
        if videos.isEmpty {
            print("⚠️ [YouTube] No videos found, returning search placeholder")
            return createSearchPlaceholder(query: query)
        }
        
        return videos
    }
    
    /// Create a placeholder video result that opens YouTube search
    private func createSearchPlaceholder(query: String) -> [VideoResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return [VideoResult(
            videoId: "placeholder",
            title: "Search YouTube for: \(query)",
            thumbnail: nil,
            channel: "YouTube",
            url: "https://www.youtube.com/results?search_query=\(encodedQuery)"
        )]
    }
}

// MARK: - Error Types

enum YouTubeServiceError: LocalizedError {
    case apiKeyInvalid
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .apiKeyInvalid:
            return "YouTube API key is invalid or quota exceeded"
        case .invalidURL:
            return "Invalid YouTube API URL"
        case .invalidResponse:
            return "Invalid response from YouTube API"
        case .apiError(let statusCode):
            return "YouTube API error: HTTP \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

