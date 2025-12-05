//
//  ProfileView.swift
//  Do.
//
//  Created by Mikiyas Tadesse on 8/19/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import UIKit
import NotificationBannerSwift
import CoreLocation

struct ProfileView: View {
    // MARK: - Properties
    @StateObject private var viewModel: ProfileViewModel
    @StateObject private var authService = AuthService.shared
    var showsDismissButton: Bool = false
    var animateAppear: Bool = true
    var onDismiss: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var selectedPost: Post?
    @State private var showShareSheet = false
    @State private var scrollOffset: CGFloat = 0
    @State private var segmentedTop: CGFloat = .infinity
    // Controls how far down the profile header (gradient + avatar) starts
    // Keep at 0 to keep hero at the very top
    private let headerTopOffset: CGFloat = 0
    
    init(user: UserModel? = nil, showsDismissButton: Bool = false, animateAppear: Bool = true, onDismiss: (() -> Void)? = nil) {
        // Initialize with provided user or current user
        let userToDisplay = user ?? CurrentUserService.shared.user
        print("👤 [ProfileView] init() - userID: \(userToDisplay.userID ?? "nil"), userName: \(userToDisplay.userName ?? "nil"), isCurrentUser: \(UserIDResolver.shared.isCurrentUser(userId: userToDisplay.userID ?? ""))")
        _viewModel = StateObject(wrappedValue: ProfileViewModel(user: userToDisplay))
        self.showsDismissButton = showsDismissButton
        self.animateAppear = animateAppear
        self.onDismiss = onDismiss
    }
    
    // Animation states
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 1.0
    @State private var shimmerPhase: CGFloat = 0.0
    @State private var shimmerOffset: CGFloat = -200
    
    // MARK: - Precomputed Collections (help SwiftUI type-checker)
    private var gridPosts: [Post] {
        computeGridPosts(from: viewModel.posts)
    }


    private var sortedThoughts: [Post] {
        computeThoughtPosts(from: viewModel.thoughts)
    }

    // Explicit helpers to avoid type inference issues in property closures
    // Use Post.createdAt string and parse it to Date
    private func postDate(_ post: Post) -> Date {
        // Try to parse createdAt string
        if let createdAtString = post.createdAt, !createdAtString.isEmpty {
            let formatters = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                "yyyy-MM-dd'T'HH:mm:ss'Z'",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd HH:mm:ss"
            ]
            
            for format in formatters {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                
                if let date = formatter.date(from: createdAtString) {
                    return date
                }
            }
            
            // Try ISO8601DateFormatter as fallback
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: createdAtString) {
                return date
            }
        }
        // Fallback: distantPast to push unknowns to end
        return Date.distantPast
    }
    
    // Helper to parse date from string (used for sorting posts)
    private func parseDate(from dateString: String) -> Date? {
        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // Try ISO8601DateFormatter as fallback
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return isoFormatter.date(from: dateString)
    }

    private func computeGridPosts(from posts: [Post]) -> [Post] {
        let nonThoughts: [Post] = posts.filter { (post: Post) -> Bool in
            let type: String = post.postType ?? ""
            return type != "postThoughts"
        }
        let sorted: [Post] = nonThoughts.sorted { (a: Post, b: Post) -> Bool in
            let ad: Date = postDate(a)
            let bd: Date = postDate(b)
            return ad > bd
        }
        return sorted
    }

    private func computeThoughtPosts(from posts: [Post]) -> [Post] {
        let thoughts: [Post] = posts.filter { (post: Post) -> Bool in
            let type: String = post.postType ?? ""
            return type == "postThoughts"
        }
        let sorted: [Post] = thoughts.sorted { (a: Post, b: Post) -> Bool in
            let ad: Date = postDate(a)
            let bd: Date = postDate(b)
            return ad > bd
        }
        return sorted
    }
    
    // MARK: - Helper logging method for grid layout info
    private func logGridLayoutInfo(cellSize: CGFloat, postCount: Int, rows: Int, calculatedHeight: CGFloat, userName: String) {
        print("🔍 [ProfileView] Grid layout info:")
        print("🔍 [ProfileView] - User: \(userName)")
        print("🔍 [ProfileView] - Cell size: \(cellSize)")
        print("🔍 [ProfileView] - Post count: \(postCount)")
        print("🔍 [ProfileView] - Rows: \(rows)")
        print("🔍 [ProfileView] - Calculated height: \(calculatedHeight)")
    }

    // MARK: - Body
    @State private var initialScrollOffset: CGFloat? = nil
    @State private var statsTop: CGFloat = .infinity
    @State private var gridTop: CGFloat = .infinity
    var body: some View {
        GeometryReader { geometry in
        ZStack(alignment: .top) {
                // Dynamic background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "1A1A2E"),
                        Color(hex: "16213E"),
                        Color(hex: "0F3460")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Top-anchored stretchy hero background image (behind content)
                HeroBackground(image: viewModel.profileImage, scrollOffset: scrollOffset, topOffset: headerTopOffset)
                // Gradient cover ABOVE hero but BELOW scroll content (covers hero as we scroll up)
                HeroOverlayCover(
                    upDistance: max(0, -((initialScrollOffset.map { scrollOffset - $0 }) ?? 0)),
                    statsTop: statsTop,
                    segmentedTop: segmentedTop,
                    gridTop: gridTop,
                    safeTop: geometry.safeAreaInsets.top
                )
                // Do. blue background begins under the segmented control (so hero stays clean)
                if segmentedTop.isFinite && segmentedTop > geometry.safeAreaInsets.top {
                    // Richer, deeper blue to complement orange header
                    Color(UIColor(red: 0.03, green: 0.08, blue: 0.22, alpha: 1)) // Slightly richer than 0F163E
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, segmentedTop)
                        .ignoresSafeArea()
                }
                ScrollView(showsIndicators: false) {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: proxy.frame(in: .named("scroll")).minY
                        )
                    }
                    .frame(height: 1)
                    
            ZStack {
                        // PROGRESSIVE UI: Show profile header immediately (optimistic data from init)
                        // Only hide if we don't have even basic name/username data
                        if !viewModel.name.isEmpty || !viewModel.username.isEmpty || viewModel.hasBeenLoaded {
                            VStack(spacing: 0) {
                                heroSection(geometry: geometry)
                                
                                // Unified profile section (image, name, username, bio) below hero
                                unifiedProfileSection
                                    .padding(.top, -50) // Overlap slightly with hero for seamless transition
                                
                                // Hide in-flow stats when sticky header is active
                                if segmentedTop > geometry.safeAreaInsets.top + 1 {
                                    statsSection
                                        .background(
                                            GeometryReader { proxy in
                                                Color.clear.preference(
                                                    key: StatsTopPreferenceKey.self,
                                                    value: proxy.frame(in: .global).minY
                                                )
                                            }
                                        )
                                }
                                actionButtons
                                if isLocked {
                                    lockedContent
                                    Color.clear.frame(height: 100) // reduced bottom scroll space
                                } else {
                                    contentSection
                                    // Show skeleton for posts while loading
                                    if viewModel.isLoadingPosts && viewModel.posts.isEmpty && viewModel.thoughts.isEmpty {
                                        postsLoadingSkeleton
                                            .padding(.top, 20)
                                    }
                                    Color.clear.frame(height: 100) // reduced bottom scroll space
                                }
                            }
                            .transition(animateAppear ? .opacity.combined(with: .scale(scale: 0.95)) : .identity)
                            // Only fade if profile is loading (posts load separately)
                            .opacity(viewModel.isLoadingProfile && !viewModel.hasBeenLoaded ? 0.3 : 1)
                            .scaleEffect(viewModel.isLoadingProfile && !viewModel.hasBeenLoaded ? 0.98 : 1)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isLoadingProfile)
                        }
                        
                        // Only show full loading overlay if we have NO data at all (very first load)
                        if viewModel.isLoadingProfile && viewModel.name.isEmpty && viewModel.username.isEmpty && !viewModel.hasBeenLoaded {
                            loadingView
                                .transition(.opacity)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.isLoadingProfile)
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.name)
                    .animation(.spring(response: 0.2, dampingFraction: 0.9), value: viewModel.isLoadingPosts)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    if initialScrollOffset == nil { initialScrollOffset = value }
                    scrollOffset = value
                    // Debug: log scroll and backup sticky trigger
                    let upDistance = max(0, -((initialScrollOffset.map { scrollOffset - $0 }) ?? 0))
                    let backupSticky = scrollOffset <= -40
                    // debugPrint("[ProfileView] scrollOffset=\(scrollOffset), upDistance=\(upDistance), backupSticky=\(backupSticky)")
                }
                .onPreferenceChange(SegmentedTopPreferenceKey.self) { value in
                    segmentedTop = value
                    // Debug: log segmented position and sticky-by-segment condition
                    let stickyBySegment = segmentedTop <= geometry.safeAreaInsets.top + 1
                    // Compute overlay opacity snapshot for logging
                    let upDistance = max(0, -((initialScrollOffset.map { scrollOffset - $0 }) ?? 0))
                    let statsReached = statsTop <= geometry.safeAreaInsets.top + 1
                    let baseOpacity: CGFloat = statsReached ? 0.3 : 0.0
                    let segRamp: CGFloat = 80
                    let segProgress = max(0, min(1, (geometry.safeAreaInsets.top - segmentedTop) / segRamp))
                    let gridRamp: CGFloat = 160
                    let gridDistance = max(0, gridTop - geometry.safeAreaInsets.top)
                    let gridProgress = 1 - min(1, gridDistance / gridRamp)
                    let rampProgress = gridTop.isFinite ? gridProgress : segProgress
                    let totalOpacity: CGFloat = min(1.0, baseOpacity + (statsReached ? (0.7 * rampProgress) : 0))
                    // debugPrint("[ProfileView] segmentedTop=\(segmentedTop), safeTop=\(geometry.safeAreaInsets.top), stickyBySegment=\(stickyBySegment), overlayOpacity=\(String(format: "%.3f", totalOpacity))")
                }
                .onPreferenceChange(StatsTopPreferenceKey.self) { value in
                    statsTop = value
                    // Debug: log stats position and whether stats reached top
                    let statsReached = statsTop <= geometry.safeAreaInsets.top + 1
                    // Also log overlay opacity snapshot
                    let upDistance = max(0, -((initialScrollOffset.map { scrollOffset - $0 }) ?? 0))
                    let baseOpacity: CGFloat = statsReached ? 0.3 : 0.0
                    let segRamp: CGFloat = 80
                    let distance = max(0, segmentedTop - geometry.safeAreaInsets.top)
                    let segProgress = 1 - min(1, distance / segRamp)
                    // Prefer grid-based ramp if available
                    let gridRamp: CGFloat = 160
                    let gridDistance = max(0, gridTop - geometry.safeAreaInsets.top)
                    let gridProgress = 1 - min(1, gridDistance / gridRamp)
                    let rampProgress = gridTop.isFinite ? gridProgress : segProgress
                    let totalOpacity: CGFloat = min(1.0, baseOpacity + (statsReached ? (0.7 * rampProgress) : 0))
                    // debugPrint("[ProfileView] statsTop=\(statsTop), statsReached=\(statsReached), gridTop=\(gridTop), overlayOpacity=\(String(format: "%.3f", totalOpacity))")
                }
                .onPreferenceChange(GridTopPreferenceKey.self) { value in
                    gridTop = value
                    // Debug: log grid top and computed overlay opacity
                    let statsReached = statsTop <= geometry.safeAreaInsets.top + 1
                    let baseOpacity: CGFloat = statsReached ? 0.3 : 0.0
                    let gridRamp: CGFloat = 160
                    let gridDistance = max(0, gridTop - geometry.safeAreaInsets.top)
                    let gridProgress = 1 - min(1, gridDistance / gridRamp)
                    let totalOpacity: CGFloat = min(1.0, baseOpacity + (statsReached ? (0.7 * gridProgress) : 0))
                    // debugPrint("[ProfileView] gridTop=\(gridTop), safeTop=\(geometry.safeAreaInsets.top), overlayOpacity=\(String(format: "%.3f", totalOpacity))")
                }
                
                // Back button when hosted (left side)
                if showsDismissButton {
                    VStack {
                        HStack {
                            Button(action: { 
                                // Use callback if provided (for UIKit modal presentation)
                                if let onDismiss = onDismiss {
                                    onDismiss()
                                } else {
                                    // Fallback to SwiftUI dismiss
                                    dismiss()
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.black.opacity(0.3),
                                                        Color.black.opacity(0.5)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                            }
                            .padding(.leading, 16)
                            .padding(.top, 60)
                            Spacer()
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                }
                
                // Floating header when the segmented control reaches the top
                // Force sticky header to appear when scrolling beyond the stats section
                let statsScrollDepth = max(0, -statsTop)
                
                // Aggressively trigger sticky header - it should ALWAYS appear when stats section passes safe area
                if statsScrollDepth > 20 { // Just 20pt of downward scroll to trigger
                    ZStack(alignment: .top) {
                        // Unified deep blue background
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(UIColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 1.0)), // Deep Do Blue
                                Color(UIColor(red: 0.06, green: 0.10, blue: 0.24, alpha: 0.98))  // Darker Deep Do Blue
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geometry.safeAreaInsets.top + 130) // Increased to accommodate bio
                        .frame(maxWidth: .infinity)
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .zIndex(999)
                        
                        // Header content
                        VStack(spacing: 0) {
                            floatingHeader
                                .padding(.top, geometry.safeAreaInsets.top + 24) // Adjusted for better spacing
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .zIndex(1000)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: statsScrollDepth > 20)
                    .zIndex(1000)
                }

                // Loading overlay
                if viewModel.isLoading {
                    loadingView
                }
            }
        }
        // Ensure nothing (including parent container/nav) adds a top inset
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            print("👤 [ProfileView] onAppear - isCurrentUserProfile: \(viewModel.isCurrentUserProfile), userID: \(viewModel.user.userID ?? "nil")")
            
            // CRITICAL: Only update with current user data if this is the current user's profile
            // For other users, NEVER update with current user data - this would show wrong user's posts/followers
            if viewModel.isCurrentUserProfile {
                let freshUser = CurrentUserService.shared.user
                print("👤 [ProfileView] onAppear - updating current user from CurrentUserService")
                print("👤 [ProfileView] CurrentUserService userID: \(freshUser.userID ?? "nil")")
                print("👤 [ProfileView] CurrentUserService userName: \(freshUser.userName ?? "nil")")
                print("👤 [ProfileView] CurrentUserService bio: \(freshUser.bio ?? "nil")")
                
                // Update the view model with fresh user data
                viewModel.updateUser(freshUser)
            } else {
                print("👤 [ProfileView] onAppear - viewing OTHER user's profile")
                print("   - userID: \(viewModel.user.userID ?? "nil")")
                print("   - userName: \(viewModel.user.userName ?? "nil")")
                print("   - NOT calling updateUser() to prevent showing wrong user's posts/followers")
                print("   - ProfileViewModel will use profileUserId internally to load correct data")
                // CRITICAL: For other users, NEVER call updateUser() with current user data
                // The ProfileViewModel's profileUserId ensures we always load the correct user's data
            }
            
            // PROGRESSIVE LOADING: Load data if not already loaded
            // This works for both current user and other users
            // The ProfileViewModel uses profileUserId internally to ensure correct data
            // For current user, also reload if posts haven't been fetched yet (in case profile was incorrectly identified before)
            let shouldLoad = !viewModel.hasBeenLoaded || (viewModel.isCurrentUserProfile && !viewModel.hasFetchedPosts)
            if shouldLoad && !viewModel.isLoadingProfile && !viewModel.isLoadingInBackground {
                print("🔄 ProfileView.onAppear: Loading user data (hasBeenLoaded: \(viewModel.hasBeenLoaded), hasFetchedPosts: \(viewModel.hasFetchedPosts), isCurrentUser: \(viewModel.isCurrentUserProfile))")
                viewModel.loadUserData()
            } else {
                print("⏭️ ProfileView.onAppear: Skipping load (hasBeenLoaded: \(viewModel.hasBeenLoaded), hasFetchedPosts: \(viewModel.hasFetchedPosts), isLoadingProfile: \(viewModel.isLoadingProfile), isLoadingInBackground: \(viewModel.isLoadingInBackground))")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CurrentUserUpdated"))) { _ in
            // When user data is updated (e.g., from settings), refresh the profile view
            if viewModel.isCurrentUserProfile {
                print("🔄 [ProfileView] Received CurrentUserUpdated - refreshing profile data")
                let freshUser = CurrentUserService.shared.user
                viewModel.updateUser(freshUser)
            }
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
        .task {
            // Use task to continuously monitor for user updates
            for await _ in NotificationCenter.default.notifications(named: NSNotification.Name("CurrentUserUpdated")) {
                let freshUser = CurrentUserService.shared.user
                print("👤 [ProfileView] Received user update notification: \(freshUser.userID ?? "nil")")
                viewModel.updateUser(freshUser)
                
                if freshUser.userID != nil && !viewModel.hasBeenLoaded {
                    await viewModel.loadUserData()
                }
            }
        }
        // Hide nav bar to prevent top insets pushing content down
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            if let post = selectedPost {
                ShareSheetView(activityItems: shareItems(for: post))
            }
        }
        .fullScreenCover(item: $selectedPost) { post in
            // Combine both regular posts and thoughts for complete navigation (like Instagram)
            // Sort by date so posts appear in chronological order
            let allPosts = (viewModel.posts + viewModel.thoughts).sorted { post1, post2 in
                // Sort by createdAt if available, otherwise by objectId
                if let date1 = parseDate(from: post1.createdAt ?? ""),
                   let date2 = parseDate(from: post2.createdAt ?? "") {
                    return date1 > date2
                }
                return (post1.objectId ?? "") > (post2.objectId ?? "")
            }
            
            let selectedIndex = allPosts.firstIndex(where: { $0.objectId == post.objectId }) ?? 0
            
            // Ensure we use the most up-to-date user data
            // For current user, prefer CurrentUserService if it has more complete data
            let userToUse: UserModel = {
                if viewModel.isCurrentUserProfile {
                    let currentUser = CurrentUserService.shared.user
                    // Use CurrentUserService if it has more complete data (e.g., username)
                    if currentUser.userName != nil || currentUser.name != nil {
                        return currentUser
                    }
                }
                // Otherwise use viewModel.user (which should be updated from API)
                return viewModel.user
            }()
            
            PostDetailView(
                posts: allPosts,
                initialIndex: selectedIndex,
                profileUser: userToUse,
                onDismiss: {
                    selectedPost = nil
                }
            )
        }
    }

    // MARK: - Locked State
    private var isLocked: Bool {
        !viewModel.isCurrentUserProfile && !viewModel.canSharePosts
    }

    private var lockedContent: some View {
                VStack(spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("This account is private")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text(viewModel.followRequestPending ? "Follow request sent. Pending approval." : "Follow to see their posts and thoughts.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 5) {
                ForEach(0..<6) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: UIScreen.main.bounds.width/3 - 2)
                }
            }
            .padding(.horizontal, 0)

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }
    
    // MARK: - Minimal Loading View
    private var loadingView: some View {
        VStack(spacing: 32) {
            // Clean profile header placeholder
            VStack(spacing: 20) {
                // Simple avatar circle with subtle pulse
                        Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.04)
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 55
                        )
                    )
                    .frame(width: 110, height: 110)
                    .scaleEffect(viewModel.isLoading ? 1.0 : 0.95)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: viewModel.isLoading
                    )
                
                // Minimal name placeholders
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 140, height: 20)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 100, height: 14)
                }
                .opacity(viewModel.isLoading ? 0.6 : 1.0)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: viewModel.isLoading
                )
            }
            .padding(.top, 60)
            
            // Clean stats placeholder
            HStack(spacing: 50) {
                ForEach(0..<3) { _ in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 32, height: 16)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.03))
                            .frame(width: 48, height: 12)
                    }
                }
            }
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.02))
                            .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                    )
            )
            
            Spacer()
        }
        .transition(.opacity)
    }
    
    // MARK: - Posts Loading Skeleton
    private var postsLoadingSkeleton: some View {
        VStack(spacing: 16) {
            // Grid skeleton for posts
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2)
            ], spacing: 2) {
                ForEach(0..<9) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.05))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            // Shimmer effect
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .offset(x: shimmerOffset)
                        )
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(.vertical, 20)
        .onAppear {
            // Start shimmer animation
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }
        .onDisappear {
            shimmerOffset = -200
        }
    }
    
    // Enhanced shimmer effect modifier
    private struct ShimmerEffect: ViewModifier {
        @State private var phase: CGFloat = 0
        @State private var isAnimating = false
        
        func body(content: Content) -> some View {
            content
                .overlay(
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.12), location: 0.35),
                                .init(color: .white.opacity(0.20), location: 0.5),
                                .init(color: .white.opacity(0.12), location: 0.65),
                                .init(color: .clear, location: 1)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 1.2)
                        .offset(x: -geometry.size.width + (geometry.size.width * 1.2) * phase)
                        .animation(
                            isAnimating ? 
                            Animation.easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: false) :
                            .default,
                            value: phase
                        )
                    }
                    .mask(content)
                    .onAppear {
                        isAnimating = true
                        withAnimation {
                            phase = 1
                        }
                    }
                    .onDisappear {
                        isAnimating = false
                    }
                )
        }
    }
    
    // MARK: - Floating Header
    private var floatingHeader: some View {
        VStack(spacing: 10) { // Adjusted spacing for bio
            HStack(spacing: 16) { // Increased from 12 to 16
                // Mini avatar without border
                if let profileImage = viewModel.profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.white.opacity(0.85))
                }

                // Name & username with action button
                VStack(alignment: .leading, spacing: 3) { // Increased spacing to accommodate bio
                    HStack {
                        VStack(alignment: .leading, spacing: 3) { // Increased spacing for bio
                            Text(viewModel.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text("@\(viewModel.username.lowercased())")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(UIColor(red: 247/255, green: 147/255, blue: 31/255, alpha: 1.0)))
                                .lineLimit(1)
                            
                            // Condensed bio in floating header - single line, truncated with padding
                            if let bio = viewModel.user.bio, !bio.isEmpty {
                                // Limit bio length to prevent spacing issues (max 70 characters)
                                let truncatedBio = bio.count > 70 ? String(bio.prefix(67)) + "..." : bio
                                Text(truncatedBio)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                                    .padding(.top, 4)
                                    .padding(.trailing, 8) // Add horizontal padding
                            }
                        }
                        
                        Spacer()
                        
                        // Compact action button aligned with name
                        if viewModel.isCurrentUserProfile {
                            Button(action: viewModel.editProfile) {
                                Text("Edit")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.16))
                                    .clipShape(Capsule())
                            }
                        } else {
                            Button {
                                Task { await viewModel.toggleFollow() }
                            } label: {
                                Text(viewModel.isFollowing ? "Following" : "Follow")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(viewModel.isFollowing ? .white : .black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(viewModel.isFollowing ? Color.brandOrange : Color.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    
                    // Condensed stats row (labels above counts for tighter horizontal layout)
                    HStack(spacing: 24) {
                        // Posts
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { selectedTab = 0 }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 2) {
                                Text("Posts")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.white)
                                Text("\(viewModel.postsCount)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(selectedTab == 0 ? Color(UIColor(red: 247/255, green: 147/255, blue: 31/255, alpha: 1.0)) : .white)
                            }
                            .frame(minWidth: 56)
                        }
                        .buttonStyle(.plain)

                        // Followers - show stats, but only make clickable if:
                        // 1. Current user's profile, OR
                        // 2. Public profile, OR
                        // 3. Private profile but following
                        let canViewFollowers = viewModel.isCurrentUserProfile || 
                                               !(viewModel.user.privacyToggle ?? false) || 
                                               viewModel.isFollowing
                        Button {
                            if canViewFollowers {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.showFollowersList()
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text("Followers")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.white)
                                Text("\(viewModel.followerCount)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(minWidth: 56)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canViewFollowers)

                        // Following - show stats, but only make clickable if:
                        // 1. Current user's profile, OR
                        // 2. Public profile, OR
                        // 3. Private profile but following
                        let canViewFollowing = viewModel.isCurrentUserProfile || 
                                              !(viewModel.user.privacyToggle ?? false) || 
                                              viewModel.isFollowing
                        Button {
                            if canViewFollowing {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.showFollowingList()
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text("Following")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Color.white)
                                Text("\(viewModel.followingCount)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.white)
                            }
                            .frame(minWidth: 56)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canViewFollowing)
                    }
                }

            }

            // Compact segmented control
            HStack(spacing: 24) {
                ForEach(["Posts", "Thoughts"], id: \.self) { tab in
                    let isSelected = selectedTab == (tab == "Posts" ? 0 : 1)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = (tab == "Posts" ? 0 : 1)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 4) {
                            Text(tab)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                                .frame(minWidth: 44)
                            Capsule()
                                .fill(isSelected ? Color(UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0)) : Color.clear)
                                .frame(width: 18, height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 30)  // Increased back to 20 for more internal spacing
        .padding(.bottom, 16) // Increased from 10 to 16 for more space below tabs
        .background(
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(UIColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 1.0)), // Deep Do Blue
                            Color(UIColor(red: 0.06, green: 0.10, blue: 0.24, alpha: 1.0))  // Darker Deep Do Blue
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        )
    }
    
    // MARK: - Hero Section (Background Only)
    private func heroSection(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .bottom) {
            // Reserve space for the hero background image drawn behind the scroll content
            Color.clear.frame(height: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - Unified Profile Section (Image, Name, Username, Bio)
    private var unifiedProfileSection: some View {
        VStack(spacing: 0) {
            // Profile Image (on top - minimal background area)
            Group {
                if let profileImage = viewModel.profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 8)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.15)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2.5
                                )
                        )
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.white.opacity(0.7))
                        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 8)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
            .zIndex(1) // Keep image above gradient background
            
            // Name
            if !viewModel.name.isEmpty {
                Text(viewModel.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
            
            // Username
            if !viewModel.username.isEmpty {
                Text("@\(viewModel.username.lowercased())")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.brandOrange)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .padding(.horizontal, 24)
                    .padding(.bottom, viewModel.user.bio != nil && !viewModel.user.bio!.isEmpty ? 14 : 0)
            }
            
            // Bio - seamlessly integrated below username
            if let bio = viewModel.user.bio, !bio.isEmpty {
                VStack(spacing: 0) {
                    // Divider line with gradient
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.0)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                    
                    Text(bio)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                }
            } else {
                // Add bottom padding if no bio
                Color.clear.frame(height: 20)
            }
        }
        .background(
            // Seamless alpha phase-out gradient - transparent at top, darker at bottom
            // Matches the followers section color scheme with darker bottom
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            // Top area (around profile image) - almost transparent
                            .init(color: Color(UIColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 0.0)), location: 0.0),
                            .init(color: Color(UIColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 0.2)), location: 0.25),
                            .init(color: Color(UIColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 0.6)), location: 0.5),
                            .init(color: Color(UIColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 0.9)), location: 0.75),
                            // Bottom area (name, username, bio) - fully opaque like followers view
                            .init(color: Color(UIColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 1.0)), location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .background(
                    // Additional depth with darker gradient matching followers view
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color(UIColor(red: 0.06, green: 0.10, blue: 0.24, alpha: 0.0)), location: 0.0),
                                    .init(color: Color(UIColor(red: 0.06, green: 0.10, blue: 0.24, alpha: 0.4)), location: 0.5),
                                    // Bottom matches followers view - fully opaque darker blue
                                    .init(color: Color(UIColor(red: 0.06, green: 0.10, blue: 0.24, alpha: 1.0)), location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
        .overlay(
            // Subtle border that also phases in
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.0), location: 0.0),
                            .init(color: Color.white.opacity(0.1), location: 0.4),
                            .init(color: Color.white.opacity(0.25), location: 0.7),
                            .init(color: Color.white.opacity(0.3), location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 10)
        .padding(.horizontal, 20)
        .fixedSize(horizontal: false, vertical: false) // Prevent collapsing
    }
    

    // MARK: - Hero Background (Top-Anchored)
    private struct HeroBackground: View {
        let image: UIImage?
        let scrollOffset: CGFloat
        let topOffset: CGFloat
        private let baseHeight: CGFloat = 300
        
        var body: some View {
            ZStack(alignment: .top) {
                let pullDown = max(0, scrollOffset)
                let scrollUp = min(0, scrollOffset)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width)
                        .frame(height: baseHeight + pullDown)
                        .offset(y: topOffset - pullDown + (scrollUp / 3))
                        .scaleEffect(1 + (pullDown / 800))
                        .clipped()
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "1A1A2E"),
                            Color(hex: "16213E")
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: UIScreen.main.bounds.width)
                    .frame(height: baseHeight + pullDown)
                    .offset(y: topOffset - pullDown + (scrollUp / 3))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Separate Hero Overlay Cover (fades in on scroll up)
    private struct HeroOverlayCover: View {
        let upDistance: CGFloat   // 0 at rest; increases as user scrolls up
        let statsTop: CGFloat     // global minY of stats section
        let segmentedTop: CGFloat // global minY of segmented control
        let gridTop: CGFloat
        let safeTop: CGFloat
        private let baseHeight: CGFloat = 360 // Increased from 300 for better coverage
        
        var body: some View {
            // Step 1: Base opacity when stats section reaches top
            let statsReached = statsTop <= safeTop + 1
            let baseOpacity: CGFloat = statsReached ? 0.5 : 0.0
            
            // Step 2: Calculate additional opacity based on how far we've scrolled past statsTop
            let scrollDepth = max(0, -statsTop)
            let rampDistance: CGFloat = 300 // Faster ramp - reduced from 400
            let scrollProgress = min(1, scrollDepth / rampDistance)
            
            // Step 3: Combine base opacity with scroll progress for final opacity
            let totalOpacity: CGFloat = min(1.0, baseOpacity + (statsReached ? (0.5 * scrollProgress) : 0))
            
            // print("[ProfileView] statsTop=\(statsTop), statsReached=\(statsReached), scrollDepth=\(scrollDepth), overlayOpacity=\(String(format: "%.3f", totalOpacity))")
            
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.85),
                    Color(UIColor(red: 0.03, green: 0.08, blue: 0.22, alpha: 0.95)) // Match the richer blue we're using
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: baseHeight)
            .frame(maxHeight: .infinity, alignment: .top)
            .opacity(totalOpacity)
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Preference Key: Stats top position
    private struct StatsTopPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = .infinity
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = min(value, nextValue())
        }
    }

    

    // MARK: - Hero Content Effect
    private struct HeroContentScrollEffect: ViewModifier {
        let scrollOffset: CGFloat
        func body(content: Content) -> some View {
            // pullDown > 0 when dragging down; scrollUp < 0 when pushing up
            let pullDown = max(0, scrollOffset)
            let scrollUp = min(0, scrollOffset)
            let translateY = (pullDown * 0.4) + (scrollUp / 6)
            let fade = max(0, 1 - min(abs(scrollUp), 160) / 160)
            return content
                .offset(y: translateY)
                .opacity(fade)
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 0) {
            ForEach([
                ("photo.stack", "Posts", viewModel.postsCount),
                ("person.2.fill", "Followers", viewModel.followerCount),
                ("person.2.circle.fill", "Following", viewModel.followingCount)
            ], id: \.0) { icon, label, count in
                // Check if user can view followers/following lists
                let canViewList: Bool = {
                    switch label {
                    case "Posts":
                        return true // Always allow viewing posts tab
                    case "Followers", "Following":
                        // Can view if: current user OR public profile OR private but following
                        return viewModel.isCurrentUserProfile || 
                               !(viewModel.user.privacyToggle ?? false) || 
                               viewModel.isFollowing
                    default:
                        return true
                    }
                }()
                
                Button(action: {
                    guard canViewList else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        switch label {
                        case "Posts": selectedTab = 0
                        case "Followers": viewModel.showFollowersList()
                        case "Following": viewModel.showFollowingList()
                        default: break
                        }
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }) {
                    VStack(spacing: 6) {
                        Text("\(count)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StatButtonStyle())
                .disabled(!canViewList)
                
                if label != "Following" {
                    Divider()
                        .frame(height: 30)
                        .background(Color.white.opacity(0.1))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.15))
                        .blur(radius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
                    if viewModel.isCurrentUserProfile {
                Button(action: viewModel.editProfile) {
                    Text("Edit Profile")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(UIColor(red: 1, green: 0.4, blue: 0, alpha: 1))) // DO Orange
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .shadow(color: Color(UIColor(red: 1, green: 0.4, blue: 0, alpha: 0.3)), radius: 8, y: 2)
                }
                    } else {
                // Follow/Following Button
                Button {
                    Task { await viewModel.toggleFollow() }
                } label: {
                    Text(viewModel.isFollowing ? "Following" : "Follow")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(viewModel.isFollowing ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(viewModel.isFollowing ? Color.brandOrange : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
                
                // Message Button
                Button(action: {}) {
                    Text("Message")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 40) {
            ForEach(["Posts", "Thoughts"], id: \.self) { tab in
                Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab == "Posts" ? 0 : 1
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }) {
                    VStack(spacing: 8) {
                        Text(tab)
                            .font(.system(size: 16, weight: selectedTab == (tab == "Posts" ? 0 : 1) ? .bold : .medium))
                            .foregroundColor(selectedTab == (tab == "Posts" ? 0 : 1) ? .white : .white.opacity(0.6))
                        
                        // Indicator
                            if selectedTab == (tab == "Posts" ? 0 : 1) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "E94560"))
                                    .frame(width: 20, height: 2)
                                    .transition(.scale)
                            }
                        }
                    }
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SegmentedTopPreferenceKey.self,
                        value: proxy.frame(in: .global).minY
                    )
                }
            )
            .opacity(scrollOffset < -50 ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: scrollOffset < -50)
            .padding(.vertical, 12)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Grid top probe: always present, measures the top of the scrollable content area (grid/list)
            Color.clear
                .frame(height: 1)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: GridTopPreferenceKey.self,
                            value: proxy.frame(in: .global).minY
                        )
                    }
                )

            // Content
            if selectedTab == 0 {
                postsGrid
            } else {
                thoughtsList
            }
        }
        .background(Color.black.opacity(0.2))
    }
    
    // MARK: - Posts Grid
    
    // Helper computed properties to break up complex expressions
    private var gridCellSize: CGFloat {
        UIScreen.main.bounds.width / 3
    }
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.fixed(gridCellSize), spacing: 0),
            GridItem(.fixed(gridCellSize), spacing: 0),
            GridItem(.fixed(gridCellSize), spacing: 0)
        ]
    }
    
    private var totalItemCount: Int {
        let baseCount = gridPosts.count
        let loadingCount = (viewModel.isLoadingMorePosts && viewModel.hasMorePosts) ? 3 : 0
        return baseCount + loadingCount
    }
    
    private var gridRowCount: Int {
        totalItemCount / 3 + (totalItemCount % 3 > 0 ? 1 : 0)
    }
    
    private var gridHeight: CGFloat {
        CGFloat(gridRowCount) * gridCellSize
    }
    
    @ViewBuilder
    private var loadingIndicators: some View {
        if viewModel.isLoadingMorePosts && viewModel.hasMorePosts {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: gridCellSize, height: gridCellSize)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.5)))
                            .scaleEffect(0.7)
                    )
            }
        }
    }
    
    private var postsGrid: some View {
        VStack(spacing: 0) {
            if viewModel.posts.isEmpty {
                emptyStateView(
                    icon: "photo.on.rectangle.angled",
                    message: "No posts yet"
                )
            } else {
                postsGridView
            }
        }
        .background(Color.black.opacity(0.2))
    }
    
    @ViewBuilder
    private var postsGridView: some View {
        GeometryReader { geometry in
            let cellSize = gridCellSize
            let postCount = gridPosts.count
            let rows = gridRowCount
            let calculatedHeight = gridHeight
            
            LazyVGrid(
                columns: gridColumns,
                spacing: 0
            ) {
                ForEach(gridPosts) { post in
                    ProfileGridCell(
                        post: post,
                        cellSize: cellSize,
                        onTap: { selectedPost = post }
                    )
                }
                
                loadingIndicators
            }
            .onAppear {
                logGridLayoutInfo(
                    cellSize: cellSize,
                    postCount: postCount,
                    rows: rows,
                    calculatedHeight: calculatedHeight,
                    userName: viewModel.user.userName ?? "unknown"
                )
            }
        }
        .frame(height: gridHeight)
    }

    // Compute grid height to match ProfileSelected (0 interitem, 5pt line spacing)
    private func gridHeight(for itemCount: Int) -> CGFloat {
        let vSpacing: CGFloat = 5
        let hSpacing: CGFloat = 0
        let columns = 3
        let rows = Int(ceil(Double(itemCount) / Double(columns)))
        // Estimate cell size using screen width with zero outer padding and zero horizontal gutters
        let width = UIScreen.main.bounds.width
        let outerPadding: CGFloat = 0
        let totalHSpacing = hSpacing * CGFloat(columns - 1)
        let cell = (width - outerPadding - totalHSpacing) / CGFloat(columns)
        // height: rows*cell + vertical spacing between rows
        let verticalGutters = CGFloat(max(0, rows - 1)) * vSpacing
        return CGFloat(rows) * cell + verticalGutters
    }
    
    // MARK: - Thoughts List
    private var thoughtsList: some View {
        Group {
            if viewModel.thoughts.isEmpty {
                emptyStateView(
                    icon: "text.bubble",
                    message: "No thoughts shared yet"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sortedThoughts) { thought in
                        PostThoughtsRepresentable(
                            post: thought,
                            onTap: { selectedPost = thought },
                            onShare: { handleShare(post: thought) }
                        )
                        // No horizontal padding - PostThoughtsCell already has internal padding
                        // This makes thoughts wider, matching post detail view
                    }
                    
                    // Show subtle loading indicator when loading more thoughts
                    if viewModel.isLoadingMorePosts && viewModel.hasMorePosts {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.5)))
                                .scaleEffect(0.8)
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    }
                }
                .padding(.vertical, 12)
                // No horizontal padding - thoughts should be full width like in post detail
            }
        }
    }
    
    // MARK: - Empty State View
    private func emptyStateView(icon: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.6))
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Helper Methods
    private func handleShare(post: Post) {
        selectedPost = post
                    if viewModel.canSharePosts {
                        showShareSheet = true
                    } else {
            let banner = NotificationBanner(
                title: "Sharing not allowed",
                subtitle: "Follow this user or ensure their profile is public to share.",
                style: .warning
            )
                        banner.show(bannerPosition: .top)
                    }
    }
    
    private func shareItems(for post: Post) -> [Any] {
        var items: [Any] = []
        if let image = post.media, (post.postType ?? "") != "postThoughts" {
            items.append(image)
        }
        if let text = post.postCaption, !text.isEmpty {
            items.append(text)
        }
        if let id = post.objectId,
           let url = URL(string: "https://itsdoapp.com/post?id=\(id)") {
            items.append(url)
        }
        return items
    }
}


// MARK: - Supporting Views
// Grid cell for profile view
struct ProfileGridCell: View {
    let post: Post
    let cellSize: CGFloat
    var onTap: () -> Void
    
    @State private var loadedImage: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            // Fixed square container that absolutely cannot be exceeded
            Rectangle()
                .fill(Color.clear)
                .frame(width: cellSize, height: cellSize)
                .onAppear {
                    print("🔍 [ProfileGridCell] Cell appeared:")
                    print("🔍 [ProfileGridCell] - Post ID: \(post.objectId ?? "nil")")
                    print("🔍 [ProfileGridCell] - Cell size: \(cellSize)")
                    print("🔍 [ProfileGridCell] - Post type: \(post.postType ?? "nil")")
                    print("🔍 [ProfileGridCell] - Has media: \(post.media != nil)")
                    print("🔍 [ProfileGridCell] - Has mediaUrl: \(post.mediaUrl != nil)")
                    if let media = post.media {
                        print("🔍 [ProfileGridCell] - Media size: \(media.size)")
                        print("🔍 [ProfileGridCell] - Media aspect ratio: \(media.size.width / media.size.height)")
                    }
                    
                    // Load image from URL if not already loaded
                    if loadedImage == nil && post.media == nil {
                        Task {
                            await loadImageFromURL()
                        }
                    }
                }
                .overlay(
                    ZStack(alignment: .bottomTrailing) {
                        // Image background - strictly clipped to square
                        cellBackground
                            .frame(width: cellSize, height: cellSize)
                            .clipped()

                        // Reaction count pill overlay
                        let hasMy = (post.postInteractions?.first { $0.userId == CurrentUserService.shared.user.userID } != nil)
                        let raw = post.interactionCount ?? 0
                        let display = (raw == 0 && hasMy) ? 1 : raw
                        if display > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(UIColor(red: 247/255, green: 147/255, blue: 31/255, alpha: 1.0)))
                                Text("\(display)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Capsule())
                            .padding(6)
                        }
                    }
                )
                .clipped()
        }
        .frame(width: cellSize, height: cellSize)
        .contentShape(Rectangle())
    }
    
    // MARK: - Cell Background
    @ViewBuilder
    private var cellBackground: some View {
        if let image = loadedImage ?? post.media {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipped()
                .background(Color.black.opacity(0.08))
        } else if post.postType == "postThoughts" {
            thoughtBackground
        } else {
            workoutBackground
        }
    }
    
    // MARK: - Image Loading
    private func loadImageFromURL() async {
        // Try different sizes in order of preference
        let urls = [
            post.mediaUrlMedium,
            post.mediaUrlThumb,
            post.mediaUrl,
            post.mediaUrlLarge
        ].compactMap { $0 }.compactMap { URL(string: $0) }
        
        for url in urls {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                await MainActor.run {
                    self.loadedImage = image
                }
                return
            }
        }
    }
    
    // MARK: - Thought Background
    private var thoughtBackground: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor(red: 26/255, green: 26/255, blue: 46/255, alpha: 1.0)),
                    Color(UIColor(red: 22/255, green: 33/255, blue: 62/255, alpha: 1.0)),
                    Color(UIColor(red: 15/255, green: 22/255, blue: 62/255, alpha: 1.0))
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            if let caption = post.postCaption {
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(caption)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
    
    // MARK: - Workout Background
    private var workoutBackground: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor(red: 26/255, green: 26/255, blue: 46/255, alpha: 1.0)),
                    Color(UIColor(red: 22/255, green: 33/255, blue: 62/255, alpha: 1.0)),
                    Color(UIColor(red: 15/255, green: 22/255, blue: 62/255, alpha: 1.0))
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: (post.workoutType != nil || post.workoutId != nil) ? "figure.run.circle.fill" : "figure.hiking.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }
                
                Text((post.workoutType != nil || post.workoutId != nil) ? "Workout" : "Activity")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(8)
        }
    }
    
}

// MARK: - UIKit Thought Cell (direct)
// MARK: - Post Thoughts Cell (SwiftUI version matching Feed)
struct PostThoughtsRepresentable: View {
    let post: Post
    var onTap: () -> Void
    var onShare: () -> Void
    
    @State private var showingMenu = false
    
    // Check if this is the current user's post
    private var isOwnPost: Bool {
        guard let currentUserId = CurrentUserService.shared.user.userID else { return false }
        return post.createdBy?.userID == currentUserId
    }
    
    // Create InteractionSummary from post data
    private var interactions: InteractionSummary {
        InteractionSummary(
            heartCount: post.hearts,
            starCount: post.stars,
            goatCount: post.goats
        )
    }
    
    var body: some View {
        PostThoughtsCell(
            timestamp: post.formattedTimestamp,
            thought: post.postCaption ?? "",
            interactions: interactions,
            isOwnPost: isOwnPost,
            userName: post.createdBy?.name,
            userUsername: post.createdBy?.userName,
            userProfileImageUrl: post.createdBy?.profilePictureUrl
        )
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(action: onShare) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}

// Custom label style for stats
private struct StatLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
                .font(.system(size: 10))
            configuration.title
                .font(.system(size: 12, weight: .semibold))
        }
    }
}

struct ThoughtCell: View {
    let thought: Post
    var onTap: () -> Void
    var onShare: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Thought text
                Text(thought.postCaption ?? "")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    if let date = thought.dateLabelString,
                       !date.isEmpty {
                        Text(date)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        // Computed reaction count with fallback to 1 when user reacted but count is 0
                        let hasMy = (thought.postInteractions?.first { $0.userId == CurrentUserService.shared.user.userID } != nil)
                        let raw = thought.interactionCount ?? 0
                        let display = (raw == 0 && hasMy) ? 1 : raw
                        if display > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(UIColor(red: 247/255, green: 147/255, blue: 31/255, alpha: 1.0)))
                                Text("\(display)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                        }

                        Button(action: onShare) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .blur(radius: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .white.opacity(0.2),
                                        .white.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
    }
}

// MARK: - Supporting Types
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SegmentedTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct GridTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}



private struct StatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .background(
                configuration.isPressed ?
                Color.white.opacity(0.1) :
                Color.clear
            )
    }
}




struct CommentsView: View {
    let post: Post
    @Environment(\.presentationMode) var presentationMode
    @State private var commentText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor(red: 0.06, green: 0.09, blue: 0.24, alpha: 1.0))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(0..<8) { _ in
                                CommentCell()
                            }
                        }
                        .padding()
                    }
                    
                    // Comment input
                    HStack(spacing: 12) {
                        if let profileImage = post.createdBy?.profilePicture {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        TextField("Add a comment...", text: $commentText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(.white)
                        
                        Button(action: {}) {
                            Text("Post")
                                .foregroundColor(commentText.isEmpty ? .white.opacity(0.4) : Color(UIColor(red: 1, green: 0.4, blue: 0, alpha: 1)))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .disabled(commentText.isEmpty)
                    }
                    .padding()
                    .background(Color.black.opacity(0.2))
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - ProfileRunLogProxy for ClassicTemplate compatibility
class ProfileRunLogProxy {
    let distanceDisplay: String
    let durationDisplay: String
    let paceDisplay: String
    let caloriesDisplay: String?
    let elevationGainDisplay: String?
    let coordinates: [CLLocationCoordinate2D]
    let distanceMeters: Double?
    let durationSeconds: Double?
    let elevationGainMeters: Double?
    
    // Mock location data for ClassicTemplate
    var locationData: [[String: Any]]? {
        return coordinates.map { coord in
            return [
                "latitude": coord.latitude,
                "longitude": coord.longitude,
                "altitude": elevationGainMeters ?? 0.0
            ]
        }
    }
    
    var elevationGain: Any? {
        return elevationGainMeters ?? elevationGainDisplay
    }
    
    init(distanceDisplay: String, durationDisplay: String, paceDisplay: String, 
         caloriesDisplay: String?, elevationGainDisplay: String?, 
         coordinates: [CLLocationCoordinate2D], distanceMeters: Double?, 
         durationSeconds: Double?, elevationGainMeters: Double?) {
        self.distanceDisplay = distanceDisplay
        self.durationDisplay = durationDisplay
        self.paceDisplay = paceDisplay
        self.caloriesDisplay = caloriesDisplay
        self.elevationGainDisplay = elevationGainDisplay
        self.coordinates = coordinates
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.elevationGainMeters = elevationGainMeters
    }
}

struct CommentCell: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundColor(.white.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("username")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text("2h")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Text("This is a sample comment that could be multiple lines long and shows how the comment would look in the app.")
                    .font(.system(size: 14))
                
                HStack(spacing: 16) {
                    Text("Like")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Reply")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 4)
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "heart")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .foregroundColor(.white)
    }
}

// MARK: - ShareSheet View
struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

//// MARK: - ScaleButtonStyle
//private struct ScaleButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
//            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
//    }
//}



