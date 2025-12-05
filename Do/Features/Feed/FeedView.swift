//
//  FeedView.swift
//  Do
//
//  Main feed view with header navigation
//

import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var showSearch = false
    @State private var showNotifications = false
    @State private var showMessages = false
    @State private var showCreatePost = false
    
    // Helper to create interaction summary
    private func interactions(heart: Int, star: Int, goat: Int) -> InteractionSummary {
        return InteractionSummary(
            totalCount: heart + star + goat,
            heartCount: heart,
            starCount: star,
            goatCount: goat
        )
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.brandBlue
                .ignoresSafeArea(.all, edges: .all)
                
                // Feed Content (behind header)
                ScrollView {
                    VStack(spacing: 20) {
                        // Top padding for header
                        Color.clear
                            .frame(height: 64)
                        
                        // Loading indicator
                        if viewModel.isLoading && viewModel.posts.isEmpty {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding(.top, 100)
                        }
                        
                        // Error message
                        if let error = viewModel.error {
                            VStack(spacing: 10) {
                                Text("Error")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                Button("Retry") {
                                    Task {
                                        await viewModel.loadFeed()
                                    }
                                }
                                .foregroundColor(.brandOrange)
                            }
                            .padding()
                        }
                        
                        // Feed posts from ViewModel
                        ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                            PostCellRenderer(post: post)
                                .frame(maxWidth: UIScreen.main.bounds.width * 0.98)
                                .padding(.bottom, 20)
                                .onAppear {
                                    // Load more when approaching the end
                                    if viewModel.shouldPrefetch(currentIndex: index) {
                                        Task {
                                            await viewModel.loadMore()
                                        }
                                    }
                                }
                        }
                        .onChange(of: viewModel.isLoading) { isLoading in
                            // When initial load completes, check if we need to load more
                            if !isLoading && viewModel.hasMorePages && viewModel.posts.count <= 20 {
                                Task {
                                    await viewModel.loadMore()
                                }
                            }
                        }
                        
                        // Load more indicator
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .padding()
                        }
                        
                        // Empty state
                        if viewModel.posts.isEmpty && !viewModel.isLoading && viewModel.error == nil {
                            VStack(spacing: 20) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("No posts yet")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                Text("Follow people to see their posts here")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.top, 100)
                        }
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    await viewModel.refresh()
                }
                .task {
                    // Always load fresh data when view appears
                    await viewModel.loadFeed()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeletePost"))) { notification in
                    if let postId = notification.userInfo?["postId"] as? String, !postId.isEmpty {
                        Task {
                            await viewModel.deletePost(postId: postId)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HidePost"))) { notification in
                    if let postId = notification.userInfo?["postId"] as? String, !postId.isEmpty {
                        Task {
                            await viewModel.hidePost(postId: postId)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ArchivePost"))) { notification in
                    if let postId = notification.userInfo?["postId"] as? String, !postId.isEmpty {
                        Task {
                            await viewModel.archivePost(postId: postId)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReportPost"))) { notification in
                    if let postId = notification.userInfo?["postId"] as? String, !postId.isEmpty {
                        Task {
                            await viewModel.reportPost(postId: postId)
                        }
                    }
                }
                
                // Transparent Header (overlay on top)
                VStack {
                    FeedHeaderView(
                        showSearch: $showSearch,
                        showNotifications: $showNotifications,
                        showMessages: $showMessages,
                        showCreatePost: $showCreatePost
                    )
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showSearch) {
                SearchView()
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $showMessages) {
                MessagesView()
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
            }
        }
}


// MARK: - Feed Header
struct FeedHeaderView: View {
    @Binding var showSearch: Bool
    @Binding var showNotifications: Bool
    @Binding var showMessages: Bool
    @Binding var showCreatePost: Bool
    @State private var addButtonRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Left side button with rotation
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        addButtonRotation += 45
                    }
                    showCreatePost = true
                }) {
                    Image("Add")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(addButtonRotation))
                }
                Spacer()
            }
            
            // Centered Logo
            HStack {
                Spacer()
                Image("logo_45")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                Spacer()
            }
            
            // Right side buttons
            HStack {
                Spacer()
                HStack(spacing: 20) {
                    // Search Button
                    Button(action: { showSearch = true }) {
                        Image("searchIcon")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 22, height: 22)
                            .foregroundColor(.white)
                    }
                    
                    // Notifications Button
                    Button(action: { showNotifications = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image("notification_40")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 22, height: 22)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Messages Button (single bubble)
                    Button(action: { showMessages = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        // No background - fully transparent
    }
}

// MARK: - Placeholder Views
struct SearchView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlue.ignoresSafeArea()
                Text("Search")
                    .foregroundColor(.white)
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct NotificationsView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlue.ignoresSafeArea()
                Text("Notifications")
                    .foregroundColor(.white)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MessagesView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlue.ignoresSafeArea()
                Text("Messages")
                    .foregroundColor(.white)
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CreatePostView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlue.ignoresSafeArea()
                Text("Create Post")
                    .foregroundColor(.white)
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
