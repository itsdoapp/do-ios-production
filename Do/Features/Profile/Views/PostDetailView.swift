//
//  PostDetailView.swift
//  Do
//
//  Full-screen post detail view with vertical feed and profile header
//

import SwiftUI

struct PostDetailView: View {
    let posts: [Post]
    let initialIndex: Int
    let onDismiss: () -> Void
    let profileUser: UserModel?
    
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    init(posts: [Post], initialIndex: Int, profileUser: UserModel?, onDismiss: @escaping () -> Void) {
        // Attach user info to all posts that are missing it
        let user = profileUser ?? posts.first?.createdBy
        self.posts = posts.map { post in
            var postWithUser = post
            if postWithUser.createdBy == nil, let user = user {
                postWithUser.createdBy = user
            }
            return postWithUser
        }
        self.initialIndex = max(0, min(initialIndex, self.posts.count - 1))
        self.profileUser = user
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: max(0, min(initialIndex, self.posts.count - 1)))
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.brandBlue
                .ignoresSafeArea(.all, edges: .all)
            
            // Dismiss button (top left)
            VStack {
                HStack {
                    Button(action: {
                        onDismiss()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 16)
                    .padding(.top, 8)
                    
                    Spacer()
                }
                
                Spacer()
            }
            .zIndex(100)
            
            // Vertical feed with profile header
            if !posts.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Profile header
                            profileHeader
                                .id("profileHeader")
                                .padding(.top, 60) // Space for dismiss button
                                .padding(.bottom, 16)
                            
                            // Posts feed
                            ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                                PostCellRenderer(post: post)
                                    .id("post_\(index)")
                                    .padding(.horizontal, 0)
                            }
                        }
                    }
                    .onAppear {
                        // Scroll to initial post after a brief delay to ensure layout
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo("post_\(initialIndex)", anchor: .top)
                            }
                        }
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No posts")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    // Handle swipe down to dismiss
                    if value.translation.height > 100 {
                        onDismiss()
                        dismiss()
                    }
                }
        )
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        HStack(spacing: 16) {
            // Profile image - try multiple sources
            if let profileUrl = profileUser?.profilePictureUrl, !profileUrl.isEmpty {
                ProfileImageView(url: profileUrl, size: 60, cellName: "PostDetailView")
            } else if let profileImage = profileUser?.profilePicture {
                Image(uiImage: profileImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Name and username - show what's available
            VStack(alignment: .leading, spacing: 4) {
                // Show name, username, or userID as fallback
                let displayName: String = {
                    if let name = profileUser?.name, !name.isEmpty {
                        return name
                    } else if let username = profileUser?.userName, !username.isEmpty {
                        return username
                    } else if let userId = profileUser?.userID {
                        return String(userId.prefix(8)) // Show first 8 chars of ID
                    } else {
                        return "User"
                    }
                }()
                
                Text(displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                // Show username if available and different from display name
                if let username = profileUser?.userName, !username.isEmpty, username != displayName {
                    Text("@\(username.lowercased())")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.brandOrange)
                } else if let userId = profileUser?.userID, displayName != String(userId.prefix(8)) {
                    // Show userID if we're showing name/username
                    Text("@\(String(userId.prefix(8)))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.brandOrange.opacity(0.7))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
        )
        .padding(.horizontal, 16)
    }
    
    private func isCurrentUserPost(_ post: Post) -> Bool {
        guard let currentUserId = CurrentUserService.shared.user.userID else { return false }
        return post.createdBy?.userID == currentUserId
    }
}

