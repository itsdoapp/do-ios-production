//
//  AllPostCells.swift
//  Do
//
//  EXACT replicas of original UIKit cells
//

import SwiftUI

// MARK: - Environment Keys for Post Operations
private struct PostIdKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var postId: String? {
        get { self[PostIdKey.self] }
        set { self[PostIdKey.self] = newValue }
    }
}
import MapKit
import CoreLocation

// MARK: - Standard Social Buttons (Reusable)
struct StandardSocialButtons: View {
    let interactions: InteractionSummary
    let timestamp: String
    @State private var showingReactionPicker = false
    @State private var showingShareOptions = false
    @State private var selectedReaction: String? = nil
    @State private var heartButtonFrame: CGRect = .zero
    
    // Convenience initializer for backward compatibility
    init(totalReactions: Int, timestamp: String) {
        self.interactions = InteractionSummary(totalCount: totalReactions)
        self.timestamp = timestamp
    }
    
    init(interactions: InteractionSummary, timestamp: String) {
        self.interactions = interactions
        self.timestamp = timestamp
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Date
            Text(timestamp)
                .font(.custom("AvenirNext-Medium", size: 13))
                .foregroundColor(.white)
            
            // Reactions and share row (all on left)
            HStack(spacing: 20) {
                // Heart button with long press for reaction picker
                Button(action: {
                    // Single tap - toggle heart
                    selectedReaction = selectedReaction == nil ? "fullheart_40" : nil
                }) {
                    Image(systemName: selectedReaction != nil ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedReaction != nil ? .red : .white.opacity(0.9))
                }
                .background(GeometryReader { geo in
                    Color.clear.preference(key: HeartButtonFrameKey.self, value: geo.frame(in: .global))
                })
                .onPreferenceChange(HeartButtonFrameKey.self) { frame in
                    heartButtonFrame = frame
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.3)
                        .onEnded { _ in
                            showingReactionPicker = true
                        }
                )
                
                // Reaction count
                if interactions.totalReactionCount > 0 {
                    Text("\(interactions.totalReactionCount)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // Share button with long press for options
                Button(action: {
                    // Single tap - show share sheet
                    showingShareOptions = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            showingShareOptions = true
                        }
                )
                
                Spacer()
            }
        }
        .overlay(alignment: .bottomLeading) {
            // Reaction picker appears above heart button
            if showingReactionPicker {
                ReactionPickerPopover(
                    selectedReaction: $selectedReaction,
                    isShowing: $showingReactionPicker,
                    heartButtonFrame: heartButtonFrame
                )
            }
        }
        .confirmationDialog("Share Post", isPresented: $showingShareOptions, titleVisibility: .hidden) {
            Button("Share in App") {
                // TODO: Implement share in app
                print("Share in app")
            }
            Button("Copy Link") {
                // TODO: Implement copy link
                UIPasteboard.general.string = "https://itsdoapp.com/post?id=example"
                print("Link copied")
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// Preference key for heart button frame
struct HeartButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Reaction Picker Popover (appears above heart button)
struct ReactionPickerPopover: View {
    @Binding var selectedReaction: String?
    @Binding var isShowing: Bool
    let heartButtonFrame: CGRect
    
    let reactions = ["fullgoat_40", "fullstar_40", "fullheart_40", "PartyFaceEmoji", "ClappingEmoji", "ExplodingFaceEmoji"]
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(reactions, id: \.self) { reaction in
                Button(action: {
                    selectedReaction = reaction
                    isShowing = false
                }) {
                    Image(reaction)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color(red: 15/255, green: 22/255, blue: 62/255))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .offset(y: -60) // Position above the heart button
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isShowing)
    }
}

// MARK: - More Button Component (Instagram-style)
struct MoreButton: View {
    let isOwnPost: Bool
    @Binding var isShowingMenu: Bool
    @State private var buttonRotation: Double = 0
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isShowingMenu.toggle()
                buttonRotation = isShowingMenu ? 90 : 0
            }
        }) {
            ZStack {
                // Subtle circle background that blends with the dark blue background
                Circle()
                    .fill(Color(red: 30/255, green: 40/255, blue: 80/255)) // Darker blue-gray that blends
                    .frame(width: 24, height: 24)
                
                // Three white dots with slight opacity
                HStack(spacing: 2) {
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 2.5, height: 2.5)
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 2.5, height: 2.5)
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 2.5, height: 2.5)
                }
                .rotationEffect(.degrees(buttonRotation))
            }
        }
    }
}

// MARK: - Post Options Menu (Instagram-style)
struct PostOptionsMenu: View {
    let isOwnPost: Bool
    let onDelete: () -> Void
    let onHide: () -> Void
    let onArchive: () -> Void
    let onReport: () -> Void
    @Binding var isShowing: Bool
    @Environment(\.postId) var postId // Read postId from environment
    var alignment: Alignment = .topTrailing // Default to top-right
    
    var body: some View {
        VStack(spacing: 0) {
            if isOwnPost {
                // Own post options
                MenuButton(
                    icon: "trash",
                    title: "Delete",
                    isDestructive: true,
                    action: {
                        // Broadcast delete notification with post ID from environment
                        if let postId = postId {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("DeletePost"),
                                object: nil,
                                userInfo: ["postId": postId]
                            )
                        }
                        isShowing = false
                    }
                )
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                MenuButton(
                    icon: "eye.slash",
                    title: "Hide",
                    isDestructive: false,
                    action: {
                        // Broadcast hide notification with post ID from environment
                        if let postId = postId {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("HidePost"),
                                object: nil,
                                userInfo: ["postId": postId]
                            )
                        }
                        isShowing = false
                    }
                )
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                MenuButton(
                    icon: "archivebox",
                    title: "Archive",
                    isDestructive: false,
                    action: {
                        // Broadcast archive notification with post ID from environment
                        if let postId = postId {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ArchivePost"),
                                object: nil,
                                userInfo: ["postId": postId]
                            )
                        }
                        isShowing = false
                    }
                )
            } else {
                // Other user's post options
                MenuButton(
                    icon: "exclamationmark.triangle",
                    title: "Report",
                    isDestructive: true,
                    action: {
                        // Broadcast report notification with post ID from environment
                        if let postId = postId {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ReportPost"),
                                object: nil,
                                userInfo: ["postId": postId]
                            )
                        }
                        isShowing = false
                    }
                )
            }
        }
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 20/255, green: 28/255, blue: 68/255))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Menu Button Item
struct MenuButton: View {
    let icon: String
    let title: String
    let isDestructive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDestructive ? .red : .white.opacity(0.8))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isDestructive ? .red : .white)
                
                    Spacer()
                }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            }
    }
}

// MARK: - Standard Post Cell (postCell) - EXACT REPLICA
struct StandardPostCell: View {
    let timestamp: String
    let caption: String?
    let imageUrl: String?
    let interactions: InteractionSummary
    let isOwnPost: Bool
    let userName: String?
    let userUsername: String?
    let userProfileImageUrl: String?
    
    @State private var showingMenu = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Header: Profile (50x50), Name, Username, More button
                HStack(spacing: 10) {
                    // Profile picture
                    ProfileImageView(url: userProfileImageUrl, size: 50, cellName: "StandardPostCell")
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(userName ?? "User")
                            .font(.custom("AvenirNext-DemiBold", size: 16))
                            .foregroundColor(.white)
                        
                        if let username = userUsername {
                            Text("@\(username)")
                            .font(.custom("AvenirNext-Medium", size: 14))
                            .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                        }
                    }
                    
                    Spacer()
                    
                    // More button (consistent across all cells)
                    MoreButton(isOwnPost: isOwnPost, isShowingMenu: $showingMenu)
                }
                .padding(.horizontal, 15)
                .padding(.top, 5)
                .frame(height: 60)
            
            // Post Image (square, fills available width)
            if let imageUrl = imageUrl {
                GeometryReader { geometry in
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: geometry.size.width, height: geometry.size.width)
                        case .success(let image):
                            image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: geometry.size.width, height: geometry.size.width)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                    .padding(.top, 10)
            }
            
            // Caption (if exists)
            if let caption = caption, !caption.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text(caption)
                        .font(.custom("AvenirNext-DemiBold", size: 14))
                        .foregroundColor(.white)
                        .lineLimit(4)
                }
                .padding(.horizontal, 15)
                .padding(.top, 15)
                .padding(.bottom, 15)
            }
            
            // Bottom section: social buttons
            VStack(alignment: .leading, spacing: 5) {
                    StandardSocialButtons(
                        totalReactions: interactions.totalReactionCount,
                        timestamp: timestamp
                    )
                
                // Username
                if let username = userUsername {
                    Text("@\(username)")
                    .font(.custom("AvenirNext-Medium", size: 14))
                    .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 10)
            .padding(.bottom, 15)
            }
            .frame(maxWidth: .infinity)
            .background(Color(red: 15/255, green: 22/255, blue: 62/255))
            .cornerRadius(20)
            .shadow(color: Color(red: 112/255, green: 112/255, blue: 112/255).opacity(0.4), radius: 5, x: 0, y: 0)
        }
            
        // Post Options Menu - positioned relative to top-right button (outside ZStack for proper positioning)
        .overlay(alignment: .topTrailing) {
            if showingMenu {
                PostOptionsMenu(
                    isOwnPost: isOwnPost,
                    onDelete: {
                        // Delete handled internally by PostOptionsMenu using environment
                    },
                    onHide: {
                        // Hide handled internally by PostOptionsMenu using environment
                    },
                    onArchive: {
                        // Archive handled internally by PostOptionsMenu using environment
                    },
                    onReport: {
                        // Report handled internally by PostOptionsMenu using environment
                    },
                    isShowing: $showingMenu
                )
                .offset(x: -15, y: 60) // Position just below the header (where button is)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .zIndex(100)
            }
        }
    }
}

// MARK: - Post Caption Top (PostCaptionTop) - EXACT REPLICA
struct PostCaptionTopCell: View {
    let timestamp: String
    let caption: String
    let imageUrl: String?
    let interactions: InteractionSummary
    let isOwnPost: Bool
    let userName: String?
    let userUsername: String?
    let userProfileImageUrl: String?
    
    @State private var showingMenu = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    // Profile picture
                    ProfileImageView(url: userProfileImageUrl, size: 50, cellName: "PostCaptionCenterCell")
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(userName ?? "User")
                            .font(.custom("AvenirNext-DemiBold", size: 16))
                            .foregroundColor(.white)
                        
                        if let username = userUsername {
                            Text("@\(username)")
                            .font(.custom("AvenirNext-Medium", size: 14))
                            .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                        }
                    }
                
                Spacer()
                
                // More button (consistent across all cells)
                MoreButton(isOwnPost: isOwnPost, isShowingMenu: $showingMenu)
            }
            .padding(.horizontal, 15)
            .padding(.top, 5)
            .frame(height: 60)
            
            // Image with caption overlay at top
            ZStack(alignment: .top) {
                if let imageUrl = imageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 400)
                        case .success(let image):
                            image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                        .frame(minHeight: 400)
                        .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 400)
                        @unknown default:
                            EmptyView()
                        }
                    }
                        .padding(.top, 10)
                }
                
                // Caption box at top (just profile, name, username, logo, caption)
                captionBox(caption: caption)
                    .padding(.top, 20)
            }
            .padding(.bottom, 15)
            
            // Social buttons at bottom - aligned to left to match caption box
            VStack(alignment: .leading, spacing: 5) {
                StandardSocialButtons(
                    totalReactions: interactions.totalReactionCount,
                    timestamp: timestamp
                )
                
                if let username = userUsername {
                    Text("@\(username)")
                    .font(.custom("AvenirNext-Medium", size: 14))
                    .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                }
            }
            .padding(.leading, 20) // Match caption box horizontal padding (20px)
            .padding(.trailing, 15)
            .padding(.top, 10)
            .padding(.bottom, 15)
            
            }
            .background(Color(red: 15/255, green: 22/255, blue: 62/255))
            .cornerRadius(20)
            .shadow(color: Color(red: 112/255, green: 112/255, blue: 112/255).opacity(0.4), radius: 5, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            // Post Options Menu - positioned relative to top-right button
            if showingMenu {
                PostOptionsMenu(
                    isOwnPost: isOwnPost,
                    onDelete: {
                        // Delete handled internally by PostOptionsMenu using environment
                    },
                    onHide: {
                        // Hide handled internally by PostOptionsMenu using environment
                    },
                    onArchive: {
                        // Archive handled internally by PostOptionsMenu using environment
                    },
                    onReport: {
                        // Report handled internally by PostOptionsMenu using environment
                    },
                    isShowing: $showingMenu
                )
                .offset(x: -15, y: 60) // Position just below the header (where button is at y: 60)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .zIndex(100)
            }
        }
    }
    
    private func captionBox(caption: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Profile picture on left, name/username/timestamp on right
            HStack(alignment: .top, spacing: 16) {
                // Profile picture (left side, like Twitter) - bigger
                ProfileImageView(url: userProfileImageUrl, size: 56, cellName: "PostCaptionTopCell")
                
                // Name, username, timestamp, and caption content - aligned to left
                VStack(alignment: .leading, spacing: 12) {
                    // Name on its own line (highlighted)
                    Text(userName ?? "User")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                    
                    // Username and timestamp on same line (like Twitter)
                    HStack(alignment: .center, spacing: 6) {
                        if let username = userUsername {
                            Text("@\(username)")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Timestamp (dot separator, like Twitter)
                        Text("·")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(timestamp)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // Caption text (tweet content) - bigger and better spacing
                    Text(caption)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 15/255, green: 22/255, blue: 62/255).opacity(0.7))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(red: 247/255, green: 147/255, blue: 31/255).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color(red: 112/255, green: 112/255, blue: 112/255).opacity(0.4), radius: 5, x: 0, y: 0)
    }
}

// MARK: - Post Caption Center (PostCaptionCenter) - EXACT REPLICA
struct PostCaptionCenterCell: View {
    let timestamp: String
    let caption: String
    let imageUrl: String?
    let interactions: InteractionSummary
    let isOwnPost: Bool
    let userName: String?
    let userUsername: String?
    let userProfileImageUrl: String?
    
    @State private var showingMenu = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    // Profile picture
                    ProfileImageView(url: userProfileImageUrl, size: 50, cellName: "PostCaptionCenterCell")
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(userName ?? "User")
                            .font(.custom("AvenirNext-DemiBold", size: 16))
                            .foregroundColor(.white)
                        
                        if let username = userUsername {
                            Text("@\(username)")
                        .font(.custom("AvenirNext-Medium", size: 14))
                        .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                        }
                }
                
                Spacer()
                
                Image("logo_45")
                    .resizable()
                    .frame(width: 25, height: 25)
            }
            .padding(.horizontal, 15)
            .padding(.top, 5)
            .frame(height: 60)
            
            // Image with caption overlay centered
            ZStack {
                if let imageUrl = imageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 400)
                        case .success(let image):
                            image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                        .frame(minHeight: 400)
                        .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 400)
                        @unknown default:
                            EmptyView()
                        }
                    }
                        .padding(.top, 10)
                }
                
                // Caption box centered on image
                captionBox(caption: caption)
            }
            .padding(.bottom, 15)
            
            // Social buttons at bottom - aligned to left to match caption box
            VStack(alignment: .leading, spacing: 5) {
                StandardSocialButtons(
                    totalReactions: interactions.totalReactionCount,
                    timestamp: timestamp
                )
                
                if let username = userUsername {
                    Text("@\(username)")
                    .font(.custom("AvenirNext-Medium", size: 14))
                    .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                }
            }
            .padding(.leading, 20) // Match caption box horizontal padding (20px)
            .padding(.trailing, 15)
            .padding(.top, 10)
            .padding(.bottom, 15)
            
            }
            .background(Color(red: 15/255, green: 22/255, blue: 62/255))
            .cornerRadius(20)
            .shadow(color: Color(red: 112/255, green: 112/255, blue: 112/255).opacity(0.4), radius: 5, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            // Post Options Menu - positioned relative to top-right button
            if showingMenu {
                PostOptionsMenu(
                    isOwnPost: isOwnPost,
                    onDelete: {
                        // Delete handled internally by PostOptionsMenu using environment
                    },
                    onHide: {
                        // Hide handled internally by PostOptionsMenu using environment
                    },
                    onArchive: {
                        // Archive handled internally by PostOptionsMenu using environment
                    },
                    onReport: {
                        // Report handled internally by PostOptionsMenu using environment
                    },
                    isShowing: $showingMenu
                )
                .offset(x: -15, y: 60) // Position just below the header (where button is at y: 60)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .zIndex(100)
            }
        }
    }
    
    private func captionBox(caption: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Profile picture on left, name/username/timestamp on right
            HStack(alignment: .top, spacing: 16) {
                // Profile picture (left side, like Twitter) - bigger
                ProfileImageView(url: userProfileImageUrl, size: 56, cellName: "PostCaptionTopCell")
                
                // Name, username, timestamp, and caption content - aligned to left
                VStack(alignment: .leading, spacing: 12) {
                    // Name on its own line (highlighted)
                    Text(userName ?? "User")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                    
                    // Username and timestamp on same line (like Twitter)
                    HStack(alignment: .center, spacing: 6) {
                        if let username = userUsername {
                            Text("@\(username)")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Timestamp (dot separator, like Twitter)
                        Text("·")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(timestamp)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // Caption text (tweet content) - bigger and better spacing
                    Text(caption)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 15/255, green: 22/255, blue: 62/255).opacity(0.7))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(red: 247/255, green: 147/255, blue: 31/255).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color(red: 112/255, green: 112/255, blue: 112/255).opacity(0.4), radius: 5, x: 0, y: 0)
    }
}

// MARK: - Post Caption Bottom (PostCaptionBottom) - EXACT REPLICA
struct PostCaptionBottomCell: View {
    let timestamp: String
    let caption: String
    let imageUrl: String?
    let interactions: InteractionSummary
    let isOwnPost: Bool
    let userName: String?
    let userUsername: String?
    let userProfileImageUrl: String?
    
    @State private var showingMenu = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    // Profile picture
                    ProfileImageView(url: userProfileImageUrl, size: 50, cellName: "PostCaptionCenterCell")
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(userName ?? "User")
                            .font(.custom("AvenirNext-DemiBold", size: 16))
                            .foregroundColor(.white)
                        
                        if let username = userUsername {
                            Text("@\(username)")
                        .font(.custom("AvenirNext-Medium", size: 14))
                        .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                        }
                }
                
                Spacer()
                
                Image("logo_45")
                    .resizable()
                    .frame(width: 25, height: 25)
            }
            .padding(.horizontal, 15)
            .padding(.top, 5)
            .frame(height: 60)
            
            // Image with caption overlay at bottom
            ZStack(alignment: .bottom) {
                if let imageUrl = imageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 400)
                        case .success(let image):
                            image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                        .frame(minHeight: 400)
                        .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 400)
                        @unknown default:
                            EmptyView()
                        }
                    }
                        .padding(.top, 10)
                }
                
                // Caption box at bottom
                captionBox(caption: caption)
                    .padding(.bottom, 20)
            }
            .padding(.bottom, 15)
            
            // Social buttons at bottom - aligned to left to match caption box
            VStack(alignment: .leading, spacing: 5) {
                StandardSocialButtons(
                    interactions: interactions,
                    timestamp: timestamp
                )
                
                if let username = userUsername {
                    Text("@\(username)")
                    .font(.custom("AvenirNext-Medium", size: 14))
                    .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                }
            }
            .padding(.leading, 20) // Match caption box horizontal padding (20px)
            .padding(.trailing, 15)
            .padding(.top, 10)
            .padding(.bottom, 15)
            
            }
            .background(Color(red: 15/255, green: 22/255, blue: 62/255))
            .cornerRadius(20)
            .shadow(color: Color(red: 112/255, green: 112/255, blue: 112/255).opacity(0.4), radius: 5, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            // Post Options Menu - positioned relative to top-right button
            if showingMenu {
                PostOptionsMenu(
                    isOwnPost: isOwnPost,
                    onDelete: {
                        // Delete handled internally by PostOptionsMenu using environment
                    },
                    onHide: {
                        // Hide handled internally by PostOptionsMenu using environment
                    },
                    onArchive: {
                        // Archive handled internally by PostOptionsMenu using environment
                    },
                    onReport: {
                        // Report handled internally by PostOptionsMenu using environment
                    },
                    isShowing: $showingMenu
                )
                .offset(x: -15, y: 60) // Position just below the header (where button is at y: 60)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .zIndex(100)
            }
        }
    }
    
    private func captionBox(caption: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Profile picture on left, name/username/timestamp on right
            HStack(alignment: .top, spacing: 16) {
                // Profile picture (left side, like Twitter) - bigger
                ProfileImageView(url: userProfileImageUrl, size: 56, cellName: "PostCaptionTopCell")
                
                // Name, username, timestamp, and caption content - aligned to left
                VStack(alignment: .leading, spacing: 12) {
                    // Name on its own line (highlighted)
                    Text(userName ?? "User")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                    
                    // Username and timestamp on same line (like Twitter)
                    HStack(alignment: .center, spacing: 6) {
                        if let username = userUsername {
                            Text("@\(username)")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Timestamp (dot separator, like Twitter)
                        Text("·")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(timestamp)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // Caption text (tweet content) - bigger and better spacing
                    Text(caption)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 15/255, green: 22/255, blue: 62/255).opacity(0.7))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(red: 247/255, green: 147/255, blue: 31/255).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color(red: 112/255, green: 112/255, blue: 112/255).opacity(0.4), radius: 5, x: 0, y: 0)
    }
}

// MARK: - Post Workout (postWorkoutCell) - EXACT REPLICA
struct PostWorkoutCell: View {
    let timestamp: String
    let caption: String?
    let workoutImageUrl: String?
    let interactions: InteractionSummary
    let isOwnPost: Bool
    let userName: String?
    let userUsername: String?
    let userProfileImageUrl: String?
    
    @State private var showingMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                // Profile picture
                ProfileImageView(url: userProfileImageUrl, size: 50, cellName: "PostWorkoutCell")
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(userName ?? "User")
                        .font(.custom("AvenirNext-DemiBold", size: 16))
                        .foregroundColor(.white)
                    
                    if let username = userUsername {
                        Text("@\(username)")
                        .font(.custom("AvenirNext-Medium", size: 14))
                        .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                    }
                }
                
                Spacer()
                
                // More button (consistent across all cells)
                MoreButton(isOwnPost: isOwnPost, isShowingMenu: $showingMenu)
            }
            .padding(.horizontal, 15)
            .padding(.top, 5)
            .frame(height: 60)
            
            // Caption (if exists) - ABOVE image
            if let caption = caption, !caption.isEmpty {
                Text(caption)
                    .font(.custom("AvenirNext-DemiBold", size: 14))
                    .foregroundColor(.white)
                    .lineLimit(nil)
                    .padding(.horizontal, 15)
                    .padding(.top, 15)
            }
            
            // Workout Image (aspect fit, full width like UIKit - leading/trailing 0, height 300)
            if let workoutImageUrl = workoutImageUrl {
                GeometryReader { geometry in
                    AsyncImage(url: URL(string: workoutImageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: geometry.size.width)
                                .frame(minHeight: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width)
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: geometry.size.width)
                                .frame(minHeight: 200)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .frame(height: 300) // Match UIKit fixed height
                .padding(.top, caption != nil ? 10 : 0)
            }
            
            // Bottom section: Standard social buttons
            VStack(alignment: .leading, spacing: 5) {
                StandardSocialButtons(
                    interactions: interactions,
                    timestamp: timestamp
                )
                
                if let username = userUsername {
                    Text("@\(username)")
                    .font(.custom("AvenirNext-Medium", size: 14))
                    .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 10)
            .padding(.bottom, 15)
        }
        .background(Color(red: 15/255, green: 22/255, blue: 62/255))
        .cornerRadius(20)
        .shadow(color: Color(red: 112/255, green: 112/255, blue: 112/255).opacity(0.4), radius: 5, x: 0, y: 0)
        .overlay(alignment: .topTrailing) {
            // Post Options Menu - positioned relative to top-right button
            if showingMenu {
                PostOptionsMenu(
                    isOwnPost: isOwnPost,
                    onDelete: {
                        // Delete handled internally by PostOptionsMenu using environment
                    },
                    onHide: {
                        // Hide handled internally by PostOptionsMenu using environment
                    },
                    onArchive: {
                        // Archive handled internally by PostOptionsMenu using environment
                    },
                    onReport: {
                        // Report handled internally by PostOptionsMenu using environment
                    },
                    isShowing: $showingMenu
                )
                .offset(x: -15, y: 60) // Position just below the header (where button is at y: 60)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .zIndex(100)
            }
        }
    }
}

// MARK: - Post Workout Session (postWorkoutSessionCell) - EXACT REPLICA
struct PostWorkoutSessionCell: View {
    let timestamp: String
    let caption: String?
    let workoutTitle: String
    let duration: String
    let calories: String
    let exercises: String // Summary exercise text
    let exerciseData: [ExerciseCarouselItem] // Exercise data for carousel
    let interactions: InteractionSummary
    let isOwnPost: Bool
    let userName: String?
    let userUsername: String?
    let userProfileImageUrl: String?
    
    @State private var currentPage: Int = 0
    @State private var showingMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Profile (50x50), Name, Username, Date
            HStack(spacing: 10) {
                // Profile picture
                ProfileImageView(url: userProfileImageUrl, size: 50, cellName: "PostWorkoutCell")
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(userName ?? "User")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let username = userUsername {
                        Text("@\(username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                    }
                    
                    Text(timestamp)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Logo icon (keep logo in top-right for this cell)
                Image("logo_45")
                    .resizable()
                    .frame(width: 30, height: 30)
            }
            .padding(.horizontal, 15)
            .padding(.top, 15)
            
            // Caption text (e.g., "Arm day")
            if let caption = caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 15)
                    .padding(.top, 12)
            }
            
            // "Workout Session" label with orange left border
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color(red: 247/255, green: 147/255, blue: 31/255))
                    .frame(width: 4)
                
                Text("Workout Session")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.leading, 12)
                    .padding(.vertical, 12)
                
                Spacer()
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 15)
            .padding(.top, 12)
            
            // "WORKOUT REPORT" section with carousel
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WORKOUT REPORT")
                            .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                            .tracking(1)
                        
                        // Duration and Calories inline
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Text(duration)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                }
                
                            HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                                    .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Text(calories)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Exercise counter
                    if !exerciseData.isEmpty {
                        Text("\(currentPage + 1)/\(exerciseData.count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                if exerciseData.isEmpty {
                    // Fallback to summary text if no carousel data
                    VStack(alignment: .leading, spacing: 6) {
                        let lines = exercises.components(separatedBy: "\n")
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            if line.isEmpty {
                                Color.clear.frame(height: 4)
                            } else if line.contains("🔥") || line.contains("🏆") {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(line)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                                    Spacer()
                                }
                            } else if line.contains("+") {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(line)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                    Spacer()
                                }
                            } else if line.contains("•") {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(line)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                    Spacer()
                                }
                            } else {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(line)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.8))
                                    Spacer()
                                }
                            }
                        }
                    }
                } else {
                    // Exercise carousel (like Instagram)
                    let maxSets = exerciseData.map { $0.sets.count }.max() ?? 0
                    TabView(selection: $currentPage) {
                        ForEach(Array(exerciseData.enumerated()), id: \.element.id) { index, exercise in
                            ExerciseCarouselPage(exercise: exercise, index: index)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: CGFloat(100 + maxSets * 40))
                    
                    // Custom page indicators (scrollable and tappable)
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(0..<exerciseData.count, id: \.self) { index in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            currentPage = index
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            // Exercise number badge
                                            Text("\(index + 1)")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(index == currentPage ? .white : .white.opacity(0.6))
                                            
                                            // Exercise name (truncated)
                                            if index == currentPage {
                                                Text(exerciseData[index].name)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                    .transition(.opacity)
                                            }
                                        }
                                        .padding(.horizontal, index == currentPage ? 12 : 8)
                                        .padding(.vertical, 6)
                                        .background(
                                            index == currentPage ?
                                            Color(red: 247/255, green: 147/255, blue: 31/255) :
                                            Color.white.opacity(0.1)
                                        )
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(
                                                    index == currentPage ?
                                                    Color(red: 247/255, green: 147/255, blue: 31/255) :
                                                    Color.white.opacity(0.2),
                                                    lineWidth: index == currentPage ? 1.5 : 1
                                                )
                                        )
                                    }
                                    .id(index)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .onChange(of: currentPage) { newPage in
                            withAnimation {
                                proxy.scrollTo(newPage, anchor: .center)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 15)
            .padding(.horizontal, 15)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.03)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 247/255, green: 147/255, blue: 31/255).opacity(0.4),
                                Color(red: 247/255, green: 147/255, blue: 31/255).opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 15)
            .padding(.top, 12)
            
            // Social buttons at bottom with more button inline
            HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                StandardSocialButtons(
                    interactions: interactions,
                    timestamp: ""
                )
                
                    if let username = userUsername {
                        Text("@\(username)")
                    .font(.custom("AvenirNext-Medium", size: 14))
                    .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                    }
                }
                
                Spacer()
                
                // More button inline with social section
                MoreButton(isOwnPost: isOwnPost, isShowingMenu: $showingMenu)
            }
            .padding(.horizontal, 15)
            .padding(.top, 15)
            .padding(.bottom, 20)
        }
        .background(Color(red: 15/255, green: 22/255, blue: 62/255))
        .cornerRadius(20)
        .shadow(color: Color(red: 112/255, green: 112/255, blue: 112/255).opacity(0.4), radius: 5, x: 0, y: 0)
        .overlay(alignment: .bottomTrailing) {
            // Post Options Menu - positioned above bottom-right button
            if showingMenu {
                PostOptionsMenu(
                    isOwnPost: isOwnPost,
                    onDelete: {
                        // Delete handled internally by PostOptionsMenu using environment
                    },
                    onHide: {
                        // Hide handled internally by PostOptionsMenu using environment
                    },
                    onArchive: {
                        // Archive handled internally by PostOptionsMenu using environment
                    },
                    onReport: {
                        // Report handled internally by PostOptionsMenu using environment
                    },
                    isShowing: $showingMenu
                )
                .offset(x: -15, y: -120) // Position above button, aligned to the right (adjusted height)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .zIndex(100)
            }
        }
    }
}

// MARK: - Exercise Carousel Page
struct ExerciseCarouselPage: View {
    let exercise: ExerciseCarouselItem
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise name
            HStack {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                
                // Set count badge
                Text("\(exercise.sets.count) set\(exercise.sets.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 247/255, green: 147/255, blue: 31/255).opacity(0.15))
                    .cornerRadius(12)
            }
            
            // Sets list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, set in
                    HStack(spacing: 12) {
                        // Set number
                        Text("\(setIndex + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                            .frame(width: 24, height: 24)
                            .background(Color(red: 247/255, green: 147/255, blue: 31/255).opacity(0.2))
                            .clipShape(Circle())
                        
                        // Set details
                        if exercise.isTimed {
                            if set.weight > 0 {
                                let weightStr = set.weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(set.weight))" : String(format: "%.1f", set.weight)
                                let timeStr = formatTime(set.time ?? 0)
                                Text("\(weightStr) lbs × \(timeStr)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            } else if let time = set.time {
                                Text(formatTime(time))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        } else {
                            if set.weight > 0 {
                                let weightStr = set.weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(set.weight))" : String(format: "%.1f", set.weight)
                                Text("\(weightStr) lbs × \(set.reps ?? 0) reps")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            } else if let reps = set.reps {
                                Text("\(reps) reps")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let secs = seconds % 60
            if secs == 0 {
                return "\(minutes)min"
            } else {
                return "\(minutes):\(String(format: "%02d", secs))"
            }
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Location Workout Post (postLocationWorkoutCell) - EXACT REPLICA
struct LocationWorkoutPostCell: View {
    let timestamp: String
    let caption: String?
    let mapImageUrl: String?
    let distance: String
    let duration: String
    let pace: String
    let calories: String
    let interactions: InteractionSummary
    let isOwnPost: Bool
    let userName: String?
    let userUsername: String?
    let userProfileImageUrl: String?
    
    @State private var showingMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                // Profile picture
                ProfileImageView(url: userProfileImageUrl, size: 50, cellName: "PostWorkoutCell")
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(userName ?? "User")
                        .font(.custom("AvenirNext-DemiBold", size: 16))
                        .foregroundColor(.white)
                    
                    if let username = userUsername {
                        Text("@\(username)")
                        .font(.custom("AvenirNext-Medium", size: 14))
                        .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                    }
                }
                
                Spacer()
                
                Image("logo_45")
                    .resizable()
                    .frame(width: 25, height: 25)
            }
            .padding(.horizontal, 15)
            .padding(.top, 5)
            .frame(height: 60)
            
            // Caption (if exists)
            if let caption = caption, !caption.isEmpty {
                Text(caption)
                    .font(.custom("AvenirNext-DemiBold", size: 14))
                    .foregroundColor(.white)
                    .lineLimit(nil)
                    .padding(.horizontal, 15)
                    .padding(.top, 5)
            }
            
            // Map image - shows full image with proper aspect ratio (stats are already on the image)
            if let mapImageUrl = mapImageUrl {
                AsyncImage(url: URL(string: mapImageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 400)
                            .frame(maxHeight: 600)
                    case .success(let image):
                        image
                        .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 400)
                            .frame(maxHeight: 600)
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 400)
                            .frame(maxHeight: 600)
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.top, 10)
            }
            
            // Bottom section: social buttons, username with more button inline
            HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                // Standard social buttons
                StandardSocialButtons(
                    interactions: interactions,
                    timestamp: timestamp
                )
                
                // Username
                    if let username = userUsername {
                        Text("@\(username)")
                    .font(.custom("AvenirNext-Medium", size: 14))
                    .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                    }
                }
                
                Spacer()
                
                // More button inline with social section
                MoreButton(isOwnPost: isOwnPost, isShowingMenu: $showingMenu)
            }
            .padding(.horizontal, 15)
            .padding(.top, 10)
            .padding(.bottom, 15)
        }
        .background(Color(red: 15/255, green: 22/255, blue: 62/255))
        .cornerRadius(20)
        .shadow(color: Color(red: 112/255, green: 112/255, blue: 112/255).opacity(0.4), radius: 5, x: 0, y: 0)
        .overlay(alignment: .bottomTrailing) {
            // Post Options Menu - positioned above bottom-right button
            if showingMenu {
                PostOptionsMenu(
                    isOwnPost: isOwnPost,
                    onDelete: {
                        // Delete handled internally by PostOptionsMenu using environment
                    },
                    onHide: {
                        // Hide handled internally by PostOptionsMenu using environment
                    },
                    onArchive: {
                        // Archive handled internally by PostOptionsMenu using environment
                    },
                    onReport: {
                        // Report handled internally by PostOptionsMenu using environment
                    },
                    isShowing: $showingMenu
                )
                .offset(x: -15, y: -5) // Position just above and aligned with button
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .zIndex(100)
            }
        }
    }
}

// MARK: - Post Thoughts (Tweet-style design)
struct PostThoughtsCell: View {
    let timestamp: String
    let thought: String
    let interactions: InteractionSummary
    let isOwnPost: Bool
    let userName: String?
    let userUsername: String?
    let userProfileImageUrl: String?
    
    @State private var showingMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Profile picture on left, name/username/timestamp on right, more button top right
            HStack(alignment: .top, spacing: 16) {
                // Profile picture (left side, like Twitter) - bigger
                ProfileImageView(url: userProfileImageUrl, size: 56, cellName: "PostThoughtsCell")
                
                // Name, username, timestamp, and thought content
                VStack(alignment: .leading, spacing: 12) {
                    // Name on its own line (highlighted)
                    HStack(alignment: .center, spacing: 0) {
                        Text(userName ?? "User")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                        
                        Spacer()
                        
                        // More button (top right)
                        MoreButton(isOwnPost: isOwnPost, isShowingMenu: $showingMenu)
                    }
                    
                    // Username on second line
                    if let username = userUsername {
                        Text("@\(username)")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Timestamp below username
                    Text(timestamp)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                    
                    // Thought text (tweet content) - bigger and better spacing
                    Text(thought)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Social buttons (like Twitter: heart, share) - bigger and better spacing
            HStack(spacing: 0) {
                // Heart button
                Button(action: {
                    // Toggle heart
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                        
                        if interactions.totalReactionCount > 0 {
                            Text("\(interactions.totalReactionCount)")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                // Share button
                Button(action: {
                    // Share
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
        }
        .background(Color(red: 15/255, green: 22/255, blue: 62/255))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(red: 247/255, green: 147/255, blue: 31/255).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color(red: 112/255, green: 112/255, blue: 112/255).opacity(0.4), radius: 5, x: 0, y: 0)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            // Post Options Menu
            if showingMenu {
                PostOptionsMenu(
                    isOwnPost: isOwnPost,
                    onDelete: {
                        // Delete handled internally by PostOptionsMenu using environment
                    },
                    onHide: {
                        // Hide handled internally by PostOptionsMenu using environment
                    },
                    onArchive: {
                        // Archive handled internally by PostOptionsMenu using environment
                    },
                    onReport: {
                        // Report handled internally by PostOptionsMenu using environment
                    },
                    isShowing: $showingMenu
                )
                .offset(x: -15, y: 60)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .zIndex(100)
            }
        }
    }
}

// MARK: - Post Classic Workout (postWorkoutClassicCell) - EXACT REPLICA
struct PostClassicWorkoutCell: View {
    let timestamp: String
    let caption: String?
    let distance: String
    let elevationGain: String
    let movingTime: String
    let avgPace: String
    let routeDataUrl: String? // S3 URL for route data
    let routeDataS3Key: String?
    let routePolyline: String?
    let mapPreviewUrl: String?
    let fallbackMapImageUrl: String?
    let attachment: [String: Any]?
    let elevationData: [Double]? // Elevation points throughout the run
    let runType: String? // e.g., "Outdoor Run", "Indoor Run", "Trail Run"
    let interactions: InteractionSummary
    let isOwnPost: Bool
    let userName: String?
    let userUsername: String?
    let userProfileImageUrl: String?
    
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var showMapBackground: Bool = true
    @State private var isLoadingRoute: Bool = false
    @State private var attachmentMapImageUrl: String?
    @State private var coloredRoutePoints: [ColoredRoutePoint] = []
    @State private var showingMenu = false
    
    private struct ColoredRoutePoint {
        let coordinate: CLLocationCoordinate2D
        let color: Color?
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with profile, name, username, timestamp, logo
            HStack(spacing: 12) {
                // Profile picture
                ProfileImageView(url: userProfileImageUrl, size: 42, cellName: "PostClassicWorkoutCell")
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(userName ?? "User")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let username = userUsername {
                        Text("@\(username)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                    }
                    
                    Text(timestamp)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // More button (consistent across all cells)
                MoreButton(isOwnPost: isOwnPost, isShowingMenu: $showingMenu)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
            
            // Caption
                if let caption = caption, !caption.isEmpty {
                HStack {
                    Text(caption)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(nil)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            
            // Map section (220pt height)
            ZStack {
                mapContent
                
                // Run type overlay (replaces Route Preview)
                VStack {
                    HStack {
                if let runType = runType {
                    Text(runType)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black.opacity(0.6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                                        )
                                )
                                .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255)) // Orange
                        }
                        Spacer()
                    }
            .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    Spacer()
                }
            }
            .frame(height: 220)
            
            // Elevation profile section
            if let elevationData = elevationData, !elevationData.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("ELEVATION PROFILE")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(0.5)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    HStack {
                        Spacer()
                        ClassicElevationProfile(data: elevationData)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: 24
                            )
                            .frame(height: 24)
                        Spacer()
                    }
                }
                .padding(.top, 16)
            }
            
            // Stats section
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Distance
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Distance")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text(distance)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Elevation Gain
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Elevation Gain")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text(elevationGain)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                HStack(spacing: 16) {
                    // Moving Time
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moving time")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text(movingTime)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Avg Pace
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avg pace")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text(avgPace)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Timestamp above social section
            HStack {
                Text(timestamp)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Social section at bottom
            VStack(alignment: .leading, spacing: 5) {
                StandardSocialButtons(
                    interactions: interactions,
                    timestamp: ""
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(
            Color(red: 15/255, green: 22/255, blue: 62/255) // 0x0F163E - matches FeedVC
        )
        .cornerRadius(20)
        .shadow(color: Color(red: 112/255, green: 112/255, blue: 112/255).opacity(0.4), radius: 5, x: 0, y: 0)
        .overlay(alignment: .topTrailing) {
            // Post Options Menu - positioned relative to top-right button
            if showingMenu {
                PostOptionsMenu(
                    isOwnPost: isOwnPost,
                    onDelete: {
                        // Delete handled internally by PostOptionsMenu using environment
                    },
                    onHide: {
                        // Hide handled internally by PostOptionsMenu using environment
                    },
                    onArchive: {
                        // Archive handled internally by PostOptionsMenu using environment
                    },
                    onReport: {
                        // Report handled internally by PostOptionsMenu using environment
                    },
                    isShowing: $showingMenu
                )
                .offset(x: -15, y: 60) // Position just below the header (where button is at y: 60)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .zIndex(100)
            }
        }
        .onAppear {
            logRouteEvent("Appear - routeDataUrl=\(routeDataUrl ?? "nil"), s3Key=\(routeDataS3Key ?? "nil"), routePolylineLength=\(routePolyline?.count ?? 0)")
            
            loadRouteFromAttachmentIfAvailable()
            
            if routeCoordinates.isEmpty {
                decodePolylineIfNeeded()
            } else {
                logRouteEvent("Route already loaded (\(routeCoordinates.count) points)")
            }
            
            if routeCoordinates.isEmpty {
                if let routeUrl = routeDataUrl {
                    loadRouteData(from: routeUrl)
                } else if let s3Key = routeDataS3Key {
                    logRouteEvent("No route URL, but found S3 key: \(s3Key)")
                } else {
                    logRouteEvent("No route data URL available and no polyline decoded.")
                }
            }
        }
    }
    
    private func loadRouteData(from urlString: String) {
        guard !urlString.isEmpty else {
            logRouteEvent("Empty route data URL")
            return
        }
        
        isLoadingRoute = true
        logRouteEvent("Loading route data from: \(urlString)")
        
        Task {
            do {
                let coordinates = try await RouteDataService.shared.fetchRouteData(from: urlString)
                await MainActor.run {
                    routeCoordinates = coordinates
                    coloredRoutePoints = coordinates.map { ColoredRoutePoint(coordinate: $0, color: nil) }
                    isLoadingRoute = false
                    // Auto-show map if we have route data
                    if !coordinates.isEmpty {
                        showMapBackground = true
                    }
                    logRouteEvent("Loaded \(coordinates.count) route points from remote data")
                }
            } catch {
                await MainActor.run {
                    isLoadingRoute = false
                    logRouteEvent("Failed to load route data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func decodePolylineIfNeeded() {
        guard routeCoordinates.isEmpty,
              let polyline = routePolyline,
              !polyline.isEmpty else {
            logRouteEvent("Skipping polyline decode - already have coordinates or no polyline provided.")
            return
        }
        
        let decoded = RouteDataService.shared.decodePolyline(polyline)
        if decoded.isEmpty {
            logRouteEvent("routePolyline decode returned 0 points")
            return
        }
        
        routeCoordinates = decoded
        coloredRoutePoints = decoded.map { ColoredRoutePoint(coordinate: $0, color: nil) }
        showMapBackground = true
        logRouteEvent("Decoded \(decoded.count) points from routePolyline")
    }
    
    private func logRouteEvent(_ message: String) {
    }

    private func loadRouteFromAttachmentIfAvailable() {
        guard routeCoordinates.isEmpty else { return }
        coloredRoutePoints = []
        
        guard let attachment = attachment else {
            logRouteEvent("No attachment payload available")
            return
        }
        
        let keysDescription = attachment.keys.joined(separator: ", ")
        logRouteEvent("Attachment keys: [\(keysDescription)]")
        
        if let locationData = attachment["locationData"] as? [[String: Any]], !locationData.isEmpty {
            logLocationDataSample(locationData, source: "locationData")
            if applyLocationData(locationData, source: "locationData") { return }
        } else {
            logRouteEvent("Attachment missing locationData array")
        }
        
        if let coordinateArray = attachment["coordinateArray"] as? [[String: Double]], !coordinateArray.isEmpty {
            let converted = coordinateArray.map { dict -> [String: Any] in
                var copy: [String: Any] = [:]
                dict.forEach { copy[$0.key] = $0.value }
                return copy
            }
            if applyLocationData(converted, source: "coordinateArray") { return }
        }
        
        if let coordinateArrays = attachment["coordinates"] as? [[String: Any]] ??
            attachment["routeCoordinates"] as? [[String: Any]] ??
            attachment["route"] as? [[String: Any]], !coordinateArrays.isEmpty {
            if applyLocationData(coordinateArrays, source: "routeCoordinates") { return }
        }
        
        let polylineCandidates: [String?] = [
            attachment["polyline"] as? String,
            attachment["routePolyline"] as? String,
            attachment["encodedPolyline"] as? String
        ]
        
        for candidate in polylineCandidates {
            guard let polyline = candidate, !polyline.isEmpty else { continue }
            let decoded = RouteDataService.shared.decodePolyline(polyline)
            if !decoded.isEmpty {
                routeCoordinates = decoded
                coloredRoutePoints = decoded.map { ColoredRoutePoint(coordinate: $0, color: nil) }
                showMapBackground = true
                logRouteEvent("Decoded \(decoded.count) points from attachment polyline")
                return
            } else {
                logRouteEvent("Attachment polyline decode returned 0 points")
            }
        }
        
        let mapImageCandidates: [String?] = [
            attachment["mapImageUrl"] as? String,
            attachment["mapPreviewUrl"] as? String,
            attachment["mapSnapshotUrl"] as? String
        ]
        
        if let fallback = mapImageCandidates.compactMap({ $0 }).first(where: { !($0?.isEmpty ?? true) }) {
            attachmentMapImageUrl = fallback
            logRouteEvent("Using attachment map image fallback")
        }
    }
    
    private func logLocationDataSample(_ data: [[String: Any]], source: String) {
        let sample = Array(data.prefix(2))
        if let sampleData = try? JSONSerialization.data(withJSONObject: sample, options: [.sortedKeys]),
           let sampleString = String(data: sampleData, encoding: .utf8) {
            logRouteEvent("\(source) sample: \(sampleString)")
        } else {
            let sampleKeys = sample.map { Array($0.keys) }
            logRouteEvent("\(source) sample keys: \(sampleKeys)")
        }
    }
    
    @discardableResult
    private func applyLocationData(_ array: [[String: Any]], source: String) -> Bool {
        var coordinates: [CLLocationCoordinate2D] = []
        var colored: [ColoredRoutePoint] = []
        
        for dict in array {
            let lat = extractDouble(dict["lat"]) ??
                extractDouble(dict["latitude"])
            let lon = extractDouble(dict["lon"]) ??
                extractDouble(dict["lng"]) ??
                extractDouble(dict["longitude"])
            
            guard let lat = lat, let lon = lon else { continue }
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            guard CLLocationCoordinate2DIsValid(coordinate) else { continue }
            
            coordinates.append(coordinate)
            let color = colorFromLocationEntry(dict)
            colored.append(ColoredRoutePoint(coordinate: coordinate, color: color))
        }
        
        guard !coordinates.isEmpty else {
            logRouteEvent("\(source) parsing produced 0 coordinates")
            return false
        }
        
        routeCoordinates = coordinates
        coloredRoutePoints = colored
        showMapBackground = true
        let coloredCount = colored.filter { $0.color != nil }.count
        logRouteEvent("Parsed \(coordinates.count) coordinates from \(source) (colored points: \(coloredCount))")
        return true
    }
    
    private func colorFromLocationEntry(_ dict: [String: Any]) -> Color? {
        if let colorValue = dict["color"] {
            if let color = colorFromAny(colorValue) {
                return color
            }
        }
        
        let fallbackKeys = ["colorHex", "paceColor", "paceColorHex", "segmentColor", "strokeColor"]
        for key in fallbackKeys {
            if let value = dict[key], let color = colorFromAny(value) {
                return color
            }
        }
        
        if let r = extractDouble(dict["r"]) ?? extractDouble(dict["red"]),
           let g = extractDouble(dict["g"]) ?? extractDouble(dict["green"]),
           let b = extractDouble(dict["b"]) ?? extractDouble(dict["blue"]) {
            let a = extractDouble(dict["a"]) ?? extractDouble(dict["alpha"]) ?? 1.0
            return Color(
                red: normalizeColorComponent(r),
                green: normalizeColorComponent(g),
                blue: normalizeColorComponent(b),
                opacity: normalizeColorComponent(a)
            )
        }
        
        return nil
    }
    
    private func colorFromAny(_ value: Any?) -> Color? {
        switch value {
        case let string as String:
            return colorFromHexString(string)
        case let number as NSNumber:
            let hex = String(format: "%06X", number.intValue)
            return colorFromHexString(hex)
        case let dict as [String: Any]:
            if let hex = dict["hex"] as? String ?? dict["value"] as? String {
                return colorFromHexString(hex)
            }
            if let r = extractDouble(dict["r"]) ?? extractDouble(dict["red"]),
               let g = extractDouble(dict["g"]) ?? extractDouble(dict["green"]),
               let b = extractDouble(dict["b"]) ?? extractDouble(dict["blue"]) {
                let a = extractDouble(dict["a"]) ?? extractDouble(dict["alpha"]) ?? 1.0
                return Color(
                    red: normalizeColorComponent(r),
                    green: normalizeColorComponent(g),
                    blue: normalizeColorComponent(b),
                    opacity: normalizeColorComponent(a)
                )
            }
            return nil
        default:
            return nil
        }
    }
    
    private func colorFromHexString(_ hexString: String) -> Color? {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hex.hasPrefix("#") { hex.removeFirst() }
        if hex.hasPrefix("0X") { hex = String(hex.dropFirst(2)) }
        
        guard hex.count == 6 || hex.count == 8 else { return nil }
        
        var value: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&value) else { return nil }
        
        let red, green, blue, alpha: Double
        if hex.count == 6 {
            red = Double((value & 0xFF0000) >> 16) / 255.0
            green = Double((value & 0x00FF00) >> 8) / 255.0
            blue = Double(value & 0x0000FF) / 255.0
            alpha = 1.0
        } else {
            red = Double((value & 0xFF000000) >> 24) / 255.0
            green = Double((value & 0x00FF0000) >> 16) / 255.0
            blue = Double((value & 0x0000FF00) >> 8) / 255.0
            alpha = Double(value & 0x000000FF) / 255.0
        }
        
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    private func normalizeColorComponent(_ value: Double) -> Double {
        if value > 1 {
            return min(max(value / 255.0, 0), 1)
        }
        return min(max(value, 0), 1)
    }
    
    private func extractDouble(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let double as Double:
            return double
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }
    
    private var hasAnyMapSource: Bool {
        !routeCoordinates.isEmpty ||
        !coloredRoutePoints.isEmpty ||
        mapPreviewUrl != nil ||
        attachmentMapImageUrl != nil ||
        fallbackMapImageUrl != nil
    }
    
    @ViewBuilder
    private var mapContent: some View {
        if !routeCoordinates.isEmpty {
            return AnyView(
                MapViewRepresentable(coordinates: routeCoordinates)
                    .clipped()
            )
        } else if let preview = mapPreviewUrl ?? attachmentMapImageUrl ?? fallbackMapImageUrl,
                  let url = URL(string: preview) {
            return AnyView(
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.1))
                            ProgressView()
                                .tint(.white)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    case .failure:
                        terrainBackground
                    @unknown default:
                        terrainBackground
                    }
                }
            )
        } else {
            return AnyView(terrainBackground)
        }
    }
    
    private var terrainBackground: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 42/255, green: 59/255, blue: 92/255).opacity(0.4))
            
            // Grid pattern
            VStack(spacing: 0) {
                ForEach(0..<10, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)
                    Spacer()
                }
            }
            
            HStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.03))
                        .frame(width: 1)
                    Spacer()
                }
            }
            
            // Show route overlay if coordinates are loaded, otherwise show indoor run icon
            if !routeCoordinates.isEmpty {
                routeOverlay(coordinates: routeCoordinates)
            } else {
            VStack(spacing: 12) {
                    if isLoadingRoute {
                        ProgressView()
                            .tint(Color(red: 247/255, green: 147/255, blue: 31/255))
                    } else {
                Image(systemName: "figure.run")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color(red: 247/255, green: 147/255, blue: 31/255))
                Text("Indoor Run")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .frame(height: 220)
    }
    
    private func routeOverlay(coordinates: [CLLocationCoordinate2D]) -> some View {
        GeometryReader { geometry in
            let effectiveCoordinates = coloredRoutePoints.isEmpty ? coordinates : coloredRoutePoints.map { $0.coordinate }
            let hasColoredSegments = coloredRoutePoints.count >= 2 && coloredRoutePoints.contains { $0.color != nil }
            let bounds = calculateBounds(for: effectiveCoordinates)
            let margin: CGFloat = 0.12
            let contentWidth = max(0, geometry.size.width * (1 - 2 * margin))
            let contentHeight = max(0, geometry.size.height * (1 - 2 * margin))
            let canDraw = effectiveCoordinates.count > 1 &&
                contentWidth > 0 &&
                contentHeight > 0 &&
                bounds.maxLon > bounds.minLon &&
                bounds.maxLat > bounds.minLat
            
            guard canDraw else { return AnyView(EmptyView()) }
            
            return AnyView(
                ZStack {
                // Route path
                if hasColoredSegments {
                    ForEach(0..<(coloredRoutePoints.count - 1), id: \.self) { index in
                        let start = coloredRoutePoints[index]
                        let end = coloredRoutePoints[index + 1]
                        let startPoint = projectedPoint(for: start.coordinate, bounds: bounds, geometry: geometry, margin: margin, contentWidth: contentWidth, contentHeight: contentHeight)
                        let endPoint = projectedPoint(for: end.coordinate, bounds: bounds, geometry: geometry, margin: margin, contentWidth: contentWidth, contentHeight: contentHeight)
                        
                        Path { path in
                            path.move(to: startPoint)
                            path.addLine(to: endPoint)
                        }
                        .stroke(
                            (start.color ?? Color(red: 247/255, green: 147/255, blue: 31/255)),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: (start.color ?? Color(red: 247/255, green: 147/255, blue: 31/255)).opacity(0.4), radius: 3, x: 0, y: 1)
                    }
                } else {
                    Path { path in
                        for (index, coord) in effectiveCoordinates.enumerated() {
                            let point = projectedPoint(for: coord, bounds: bounds, geometry: geometry, margin: margin, contentWidth: contentWidth, contentHeight: contentHeight)
                        if index == 0 {
                                path.move(to: point)
                        } else {
                                path.addLine(to: point)
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 247/255, green: 147/255, blue: 31/255),
                            Color(red: 255/255, green: 107/255, blue: 53/255),
                            Color(red: 247/255, green: 147/255, blue: 31/255)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color(red: 247/255, green: 147/255, blue: 31/255).opacity(0.4), radius: 3, x: 0, y: 1)
            }
                
                // Start marker (green)
                if let firstCoord = effectiveCoordinates.first {
                    let startPoint = projectedPoint(for: firstCoord, bounds: bounds, geometry: geometry, margin: margin, contentWidth: contentWidth, contentHeight: contentHeight)
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 14, height: 14)
                        Circle()
                            .stroke(.white, lineWidth: 3)
                            .frame(width: 14, height: 14)
                    }
                    .position(x: startPoint.x, y: startPoint.y)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                }
                
                // End marker (red)
                if let lastCoord = effectiveCoordinates.last, effectiveCoordinates.count > 1 {
                    let endPoint = projectedPoint(for: lastCoord, bounds: bounds, geometry: geometry, margin: margin, contentWidth: contentWidth, contentHeight: contentHeight)
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 14, height: 14)
                        Circle()
                            .stroke(.white, lineWidth: 3)
                            .frame(width: 14, height: 14)
                    }
                    .position(x: endPoint.x, y: endPoint.y)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                }
                }
            )
        }
    }
    
    private func projectedPoint(
        for coordinate: CLLocationCoordinate2D,
        bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double),
        geometry: GeometryProxy,
        margin: CGFloat,
        contentWidth: CGFloat,
        contentHeight: CGFloat
    ) -> CGPoint {
        let lonRange = max(bounds.maxLon - bounds.minLon, .leastNonzeroMagnitude)
        let latRange = max(bounds.maxLat - bounds.minLat, .leastNonzeroMagnitude)
        
        let x = contentWidth * ((coordinate.longitude - bounds.minLon) / lonRange) + geometry.size.width * margin
        let y = contentHeight * (1 - ((coordinate.latitude - bounds.minLat) / latRange)) + geometry.size.height * margin
        return CGPoint(x: x, y: y)
    }
    
    private func calculateBounds(for coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }
        
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        return (minLat, maxLat, minLon, maxLon)
    }
}

// MARK: - Profile Image View
struct ProfileImageView: View {
    let url: String?
    let size: CGFloat
    let cellName: String
    
    init(url: String?, size: CGFloat = 50, cellName: String = "Cell") {
        self.url = url
        self.size = size
        self.cellName = cellName
    }
    
    var body: some View {
        if let profileUrl = url, !profileUrl.isEmpty, let imageUrl = normalizeURL(from: profileUrl) {
            AsyncImage(url: imageUrl) { phase in
                switch phase {
                case .empty:
                    placeholderCircle
                        .onAppear { debugLog("Loading profile image from \(profileUrl)") }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .onAppear { debugLog("Loaded profile image from \(profileUrl)") }
                case .failure(let error):
                    placeholderCircle
                        .onAppear { debugLog("Failed to load profile image: \(profileUrl). error=\(error.localizedDescription)") }
                @unknown default:
                    placeholderCircle
                }
            }
        } else {
            placeholderCircle
                .onAppear {
                    if let url = url, !url.isEmpty {
                        debugLog("Invalid profile image URL string: \(url)")
                    } else {
                        debugLog("No profile image URL provided")
                    }
                }
        }
    }
    
    private var placeholderCircle: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: size, height: size)
    }
    
    private func normalizeURL(from rawString: String) -> URL? {
        if let direct = URL(string: rawString) {
            return direct
        }
        
        if let encoded = rawString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded) {
            return url
        }
        
        return nil
    }
    
    private func debugLog(_ message: String) {
      
    }
}

// MARK: - Map View Representable
struct MapViewRepresentable: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    
    private enum AnnotationType {
        case start
        case end
    }
    
    private class StartStopAnnotation: NSObject, MKAnnotation {
        let coordinate: CLLocationCoordinate2D
        let type: AnnotationType
        
        init(coordinate: CLLocationCoordinate2D, type: AnnotationType) {
            self.coordinate = coordinate
            self.type = type
            super.init()
        }
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.layer.cornerRadius = 12
        mapView.isUserInteractionEnabled = false
        
        // Configure dark mode styling
        if #available(iOS 13.0, *) {
            // Force dark appearance
            mapView.overrideUserInterfaceStyle = .dark
            
            // Use standard map configuration with dark styling
            let configuration = MKStandardMapConfiguration()
            configuration.elevationStyle = .realistic
            configuration.emphasisStyle = .muted
            mapView.preferredConfiguration = configuration
        } else {
            // Fallback for iOS 12 and earlier
            mapView.mapType = .standard
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        guard !coordinates.isEmpty else { return }
        
        // Remove existing overlays to avoid duplicates
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        // Add polyline
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        
        // Add start and end annotations
        if let first = coordinates.first {
            let startAnnotation = StartStopAnnotation(coordinate: first, type: .start)
            mapView.addAnnotation(startAnnotation)
        }
        if let last = coordinates.last, coordinates.count > 1 {
            let endAnnotation = StartStopAnnotation(coordinate: last, type: .end)
            mapView.addAnnotation(endAnnotation)
        }
        
        // Set region
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )
        
        mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
        mapView.delegate = context.coordinator
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 247/255, green: 147/255, blue: 31/255, alpha: 1.0)
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let startStopAnnotation = annotation as? StartStopAnnotation else {
                return nil
            }
            
            let identifier = "StartStopAnnotation"
            let view: MKAnnotationView
            if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
                view = dequeued
                view.annotation = annotation
            } else {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.frame = CGRect(x: 0, y: 0, width: 14, height: 14)
                view.layer.cornerRadius = 7
                view.layer.borderWidth = 2
                view.layer.borderColor = UIColor.white.cgColor
                view.layer.shadowColor = UIColor.black.withAlphaComponent(0.4).cgColor
                view.layer.shadowOpacity = 1
                view.layer.shadowRadius = 2
                view.layer.shadowOffset = CGSize(width: 0, height: 1)
            }
            
            switch startStopAnnotation.type {
            case .start:
                view.layer.backgroundColor = UIColor.systemGreen.cgColor
            case .end:
                view.layer.backgroundColor = UIColor.systemRed.cgColor
            }
            
            return view
        }
    }
}

// MARK: - Scrolling Text View (Marquee Effect)
struct ScrollingTextView: View {
    let text: String
    @State private var offset: CGFloat = 0
    @State private var animating = false
    
    var body: some View {
        GeometryReader { geometry in
            let textWidth = text.widthOfString(usingFont: UIFont.systemFont(ofSize: 13, weight: .medium))
            let totalWidth = textWidth + 50 // text width + spacing
            
            HStack(spacing: 50) {
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize()
                
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize()
                
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize()
            }
            .offset(x: offset)
            .onAppear {
                // Start from right edge
                offset = geometry.size.width
                
                // Start animation immediately
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(
                        Animation.linear(duration: Double(totalWidth + geometry.size.width) / 40)
                            .repeatForever(autoreverses: false)
                    ) {
                        offset = -totalWidth * 2
                    }
                }
            }
        }
        .frame(height: 20)
        .clipped()
    }
}

// Extension to calculate text width
extension String {
    func widthOfString(usingFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }
}

// MARK: - Classic Elevation Profile
struct ClassicElevationProfile: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            let points = normalizedPoints()
            
            if !points.isEmpty {
                Path { path in
                    if let first = points.first {
                        path.move(to: CGPoint(x: first.x * geometry.size.width,
                                              y: first.y * geometry.size.height))
                        
                        for point in points.dropFirst() {
                            path.addLine(to: CGPoint(x: point.x * geometry.size.width,
                                                     y: point.y * geometry.size.height))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 255/255, green: 107/255, blue: 71/255),  // 0xFF6B47
                            Color(red: 247/255, green: 147/255, blue: 31/255), // 0xF7931F
                            Color(red: 255/255, green: 107/255, blue: 71/255)  // 0xFF6B47
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color(red: 247/255, green: 147/255, blue: 31/255).opacity(0.2), radius: 1, x: 0, y: 0.5)
            }
        }
    }
    
    private func normalizedPoints() -> [CGPoint] {
        guard data.count > 1,
              let minElevation = data.min(),
              let maxElevation = data.max(),
              maxElevation - minElevation > 0 else {
            return []
        }
        
        let range = maxElevation - minElevation
        
        return data.enumerated().map { index, elevation in
            let normalizedX = CGFloat(index) / CGFloat(data.count - 1)
            let normalizedY = 1 - CGFloat((elevation - minElevation) / range)
            return CGPoint(x: normalizedX, y: normalizedY)
        }
    }
}
