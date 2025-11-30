//
//  EquipmentTutorialsView.swift
//  Do
//
//  View for displaying YouTube tutorials for equipment
//

import SwiftUI
import SafariServices

struct EquipmentTutorialsView: View {
    let equipment: Equipment
    let suggestedExercises: [String]
    let category: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var youtubeService = YouTubeService.shared
    @State private var videos: [VideoResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showRetry = false
    
    var body: some View {
        ZStack {
            // Futuristic gradient background
            LinearGradient(
                colors: [
                    Color.brandBlue,
                    Color("1A2148")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with close button - properly positioned with safe area
                GeometryReader { geometry in
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Close")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(10)
                        }
                        
                        Spacer()
                        
                        Text("\(equipment.name) Tutorials")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                        
                        Spacer()
                        
                        // Spacer to balance the close button
                        Color.clear
                            .frame(width: 80, height: 44)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(geometry.safeAreaInsets.top, 44) + 8)
                    .padding(.bottom, 12)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.brandBlue.opacity(0.95),
                                Color("1A2148").opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: 100) // Fixed height for top bar
                
                // Content area
                if isLoading {
                    Spacer()
                    VStack(spacing: 20) {
                        ProgressView()
                            .tint(Color.brandOrange)
                            .scaleEffect(1.5)
                        
                        Text("Finding tutorials...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                } else if videos.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: showRetry ? "exclamationmark.triangle" : "play.rectangle.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(showRetry ? "Search Failed" : "No Tutorials Found")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        } else {
                            Text("We couldn't find video tutorials for this equipment. Try searching YouTube directly.")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        VStack(spacing: 12) {
                            if showRetry {
                                Button {
                                    Task {
                                        await loadVideos()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Retry Search")
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.brandOrange, Color("FF6B35")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(10)
                                }
                            }
                            
                            Button {
                                let searchQuery = buildSearchQuery()
                                if let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                                   let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.right.square")
                                    Text("Search on YouTube")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [Color.brandOrange, Color("FF6B35")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(40)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(videos) { video in
                                VideoCard(video: video)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .task {
            await loadVideos()
        }
    }
    
    private func loadVideos() async {
        isLoading = true
        errorMessage = nil
        showRetry = false
        defer { isLoading = false }
        
        do {
            let query = buildSearchQuery()
            
            print("🎥 [EquipmentTutorials] Searching for: \(query)")
            
            videos = try await youtubeService.searchVideos(
                query: query,
                limit: 8
            )
            
            print("🎥 [EquipmentTutorials] Loaded \(videos.count) videos")
            
            // If we got placeholder videos, show retry option
            if videos.count == 1 && videos.first?.videoId == "placeholder" {
                showRetry = true
                errorMessage = "Unable to search YouTube. Please check your API key configuration or try searching directly."
            }
        } catch {
            print("❌ [Equipment] Error loading videos: \(error)")
            videos = []
            showRetry = true
            
            // Set user-friendly error message
            if let youtubeError = error as? YouTubeServiceError {
                switch youtubeError {
                case .apiKeyInvalid:
                    errorMessage = "YouTube API key is invalid or quota exceeded. Please check your API key configuration."
                case .networkError(let networkError):
                    errorMessage = "Network error: \(networkError.localizedDescription). Please check your internet connection."
                case .apiError(let statusCode):
                    errorMessage = "YouTube API error (HTTP \(statusCode)). Please try again later."
                default:
                    errorMessage = "Failed to load videos. Please try again."
                }
            } else {
                errorMessage = "Failed to load videos: \(error.localizedDescription)"
            }
        }
    }
    
    /// Build a clean, focused search query
    private func buildSearchQuery() -> String {
        // Start with equipment name and "workout tutorial" for best results
        var query = "\(equipment.name) workout tutorial"
        
        // Only add category if it's meaningful (not "other")
        if !category.isEmpty && category != "other" && category.count < 20 {
            query = "\(equipment.name) \(category) workout tutorial"
        }
        
        return query
    }
}

// VideoCard is already defined in VideoResultsView.swift, so we use that instead

