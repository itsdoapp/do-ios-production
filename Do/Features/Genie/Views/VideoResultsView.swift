//
//  VideoResultsView.swift
//  Do
//
//  Displays YouTube video search results from Genie
//

import SwiftUI
import WebKit

struct VideoResultsView: View {
    let videos: [VideoResult]
    let query: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if videos.isEmpty {
                        EmptyStateView(query: query)
                    } else {
                        ForEach(videos) { video in
                            VideoCard(video: video)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Videos: \(query)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.brandOrange)
                }
            }
            .background(Color.brandBlue.ignoresSafeArea())
        }
    }
}

struct VideoCard: View {
    let video: VideoResult
    @State private var showingPlayer = false
    
    var body: some View {
        Button {
            if video.videoId != "placeholder" {
                showingPlayer = true
            } else {
                // Open YouTube search URL
                if let url = URL(string: video.url) {
                    UIApplication.shared.open(url)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                if let thumbnail = video.thumbnail, let thumbnailUrl = URL(string: thumbnail) {
                    AsyncImage(url: thumbnailUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .aspectRatio(16/9, contentMode: .fill)
                    }
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                            .opacity(0.9)
                            .shadow(color: .black.opacity(0.3), radius: 5)
                    )
                } else {
                    // Placeholder thumbnail
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .aspectRatio(16/9, contentMode: .fill)
                        .cornerRadius(12)
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.7))
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(video.channel)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 4)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .fullScreenCover(isPresented: $showingPlayer) {
            YouTubePlayerView(videoId: video.videoId, title: video.title)
        }
    }
}

struct YouTubePlayerView: View {
    let videoId: String
    let title: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Custom top bar with close button
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
                        
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                        
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
                                Color.black.opacity(0.9),
                                Color.black.opacity(0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                    // Video content
                    if videoId == "placeholder" {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "play.rectangle.slash")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.5))
                            Text("Video not available")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    } else {
                        WebView(url: URL(string: "https://www.youtube.com/embed/\(videoId)?playsinline=1&autoplay=1&rel=0&modestbranding=1")!)
                            .ignoresSafeArea(.all, edges: .bottom)
                    }
                }
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        
        // Enable JavaScript for YouTube embeds
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Load the URL
        let request = URLRequest(url: url)
        webView.load(request)
        
        print("🎥 [WebView] Loading YouTube embed: \(url.absoluteString)")
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload if URL changed
        if webView.url?.absoluteString != url.absoluteString {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🎥 [WebView] Started loading")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ [WebView] Navigation error: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("❌ [WebView] URL Error code: \(urlError.code.rawValue)")
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ [WebView] Failed to load: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ [WebView] Page loaded successfully: \(webView.url?.absoluteString ?? "unknown")")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation for YouTube embeds
            decisionHandler(.allow)
        }
    }
}

struct EmptyStateView: View {
    let query: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.slash")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.5))
            
            Text("No videos found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            Text("Try a different search term")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(40)
    }
}

// Preview
struct VideoResultsView_Previews: PreviewProvider {
    static var previews: some View {
        VideoResultsView(
            videos: [
                VideoResult(
                    videoId: "dQw4w9WgXcQ",
                    title: "Sample Workout Video",
                    thumbnail: nil,
                    channel: "Fitness Channel",
                    url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
                )
            ],
            query: "Bench Press"
        )
        .preferredColorScheme(.dark)
    }
}










