//
//  ModernUserListViewController.swift
//  Do.
//
//  Created by Mikiyas Tadesse on 8/19/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import NotificationBannerSwift

class ModernUserListViewController: UIViewController {
    
    // MARK: - Properties
    
    var users: [UserModel] = []
    var currentUser: UserModel?
    var listType: ListType = .followers
    var completion: (([UserModel]?) -> Void)?
    
    // Pagination state
    private var nextToken: String?
    private var isLoadingMore = false
    private var hasMore = true
    private var initialLoadComplete = false
    
    private let tableView = UITableView()
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let emptyStateLabel = UILabel()
    private let footerLoadingView = UIView()
    private let footerLoadingIndicator = UIActivityIndicatorView(style: .medium)
    
    enum ListType {
        case followers
        case following
        
        var title: String {
            switch self {
            case .followers: return "Followers"
            case .following: return "Following"
            }
        }
        
        var emptyMessage: String {
            switch self {
            case .followers: return "No followers yet"
            case .following: return "Not following anyone yet"
            }
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupTableView()
        
        // Clean expired cache on view load
        UserListCacheManager.shared.cleanExpiredCache()
        
        // CRITICAL: Reset state when view loads to prevent appending to wrong list
        print("📋 [UserList] viewDidLoad - listType: \(listType.title), userId: \(currentUser?.userID ?? "nil")")
        users = []
        nextToken = nil
        hasMore = true
        isLoadingMore = false
        initialLoadComplete = false
        
        // CRITICAL: Ensure loading indicator is stopped when view loads
        loadingIndicator.stopAnimating()
        footerLoadingView.isHidden = true
        footerLoadingIndicator.stopAnimating()
        
        loadUsers()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update gradient layer frame
        if let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = view.bounds
        }
    }
    
    // MARK: - Setup
    
    private func setupView() {
        // Background setup - matches profile view gradient
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 1.0).cgColor, // Deep Do Blue
            UIColor(red: 0.06, green: 0.10, blue: 0.24, alpha: 1.0).cgColor  // Darker Deep Do Blue
        ]
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
        view.backgroundColor = UIColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 1.0)
        
        // Update gradient on view bounds change
        view.layoutIfNeeded()
        
        // Header view setup - clean, minimal with blur effect
        headerView.backgroundColor = UIColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 0.95)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        // Add subtle bottom border to header
        let headerBorder = UIView()
        headerBorder.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        headerBorder.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(headerBorder)
        
        // Title label setup - refined typography
        titleLabel.text = listType.title
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)
        
        // Close button setup - minimal, clean
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = UIColor.white.withAlphaComponent(0.7)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(closeButton)
        
        // Table view setup - no separators, card-based design
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.separatorColor = .clear
        tableView.separatorInset = .zero
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.showsVerticalScrollIndicator = false
        view.addSubview(tableView)
        
        // Loading indicator setup
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        // Empty state label setup
        emptyStateLabel.text = listType.emptyMessage
        emptyStateLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        emptyStateLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Header view
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 100),
            
            // Header border
            headerBorder.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerBorder.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerBorder.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            headerBorder.heightAnchor.constraint(equalToConstant: 0.5),
            
            // Title label
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
            
            // Close button
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Table view
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Empty state label
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ModernUserCell.self, forCellReuseIdentifier: "UserCell")
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 20, right: 0)
        tableView.sectionHeaderHeight = 0
        tableView.sectionFooterHeight = 0
        
        // Setup footer loading view for pagination
        footerLoadingView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 60)
        footerLoadingIndicator.color = .white
        footerLoadingIndicator.hidesWhenStopped = true
        footerLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        footerLoadingView.addSubview(footerLoadingIndicator)
        footerLoadingView.isHidden = true
        
        NSLayoutConstraint.activate([
            footerLoadingIndicator.centerXAnchor.constraint(equalTo: footerLoadingView.centerXAnchor),
            footerLoadingIndicator.centerYAnchor.constraint(equalTo: footerLoadingView.centerYAnchor)
        ])
        
        tableView.tableFooterView = footerLoadingView
    }
    
    // MARK: - Data Loading
    
    private func loadUsers(loadMore: Bool = false) {
        // If users are already provided and this is initial load, use them
        if !loadMore && !users.isEmpty && !initialLoadComplete {
            self.loadingIndicator.stopAnimating()
            self.initialLoadComplete = true
            self.tableView.reloadData()
            self.checkEmptyState()
            return
        }
        
        // Prevent multiple simultaneous loads
        if isLoadingMore && loadMore {
            return
        }
        
        // Fetch users from AWS
        // Use UserIDResolver to get the best user ID (Parse ID preferred for follows table)
        guard let rawUserId = currentUser?.userID else {
            if loadMore {
                isLoadingMore = false
                footerLoadingView.isHidden = true
                footerLoadingIndicator.stopAnimating()
            } else {
                loadingIndicator.stopAnimating()
            }
            showErrorBanner(message: "Couldn't load user data")
            return
        }
        
        // Resolve to Parse ID if available (follows table uses Parse IDs)
        // Try Parse ID first, then fallback to Cognito ID
        let userIdsToTry = UserIDResolver.shared.getUserIdsForDataFetch(userModel: currentUser)
        let userId = userIdsToTry.first ?? rawUserId
        
        guard let currentUserId = AWSCognitoAuth.shared.getCurrentUserId() ?? CurrentUserService.shared.userID else {
            if loadMore {
                isLoadingMore = false
                footerLoadingView.isHidden = true
                footerLoadingIndicator.stopAnimating()
            } else {
                loadingIndicator.stopAnimating()
            }
            showErrorBanner(message: "Not authenticated")
            return
        }
        
        // Convert listType to cache manager's ListType
        let cacheListType: UserListCacheManager.ListType = listType == .followers ? .followers : .following
        
        // Check cache first (only for initial load, not pagination)
        if !loadMore {
            if let cached = UserListCacheManager.shared.getCachedUsers(userId: userId, listType: cacheListType) {
                // Show cached data immediately
                print("📦 [UserList] Using cached data: \(cached.users.count) users for \(cacheListType.rawValue)")
                self.users = cached.users
                self.nextToken = cached.nextToken
                self.hasMore = cached.hasMore
                self.initialLoadComplete = true
                self.loadingIndicator.stopAnimating()
                self.tableView.reloadData()
                self.checkEmptyState()
                
                // Refresh in background if cache is stale
                if UserListCacheManager.shared.isCacheStale(userId: userId, listType: cacheListType) {
                    print("📦 [UserList] Cache is stale, refreshing in background... (will REPLACE cache, not append)")
                    Task {
                        // CRITICAL: loadMore must be false to replace cache, not append
                        await fetchAndUpdateUsers(userId: userId, currentUserId: currentUserId, loadMore: false, cacheListType: cacheListType)
                    }
                }
                return
            } else {
                print("📦 [UserList] No cache found for \(cacheListType.rawValue), fetching from API...")
            }
        }
        
        // No cache or loading more - fetch from API
        if loadMore {
            guard hasMore && !isLoadingMore else { return }
            isLoadingMore = true
            footerLoadingView.isHidden = false
            footerLoadingIndicator.startAnimating()
        } else {
            loadingIndicator.startAnimating()
            users = []
            nextToken = nil
            hasMore = true
        }
        
        print("📋 [UserList] Loading \(listType.title) for userId: \(userId) (Parse ID: \(UserIDResolver.shared.isParseUserId(userId)))")
        
        Task {
            await fetchAndUpdateUsers(userId: userId, currentUserId: currentUserId, loadMore: loadMore, cacheListType: cacheListType)
            
            // CRITICAL: Ensure loading indicator is stopped even if fetchAndUpdateUsers returns early
            await MainActor.run {
                if !loadMore && self.loadingIndicator.isAnimating {
                    print("⚠️ [UserList] Force stopping loading indicator after fetchAndUpdateUsers")
                    self.loadingIndicator.stopAnimating()
                }
            }
        }
    }
    
    private func fetchAndUpdateUsers(userId: String, currentUserId: String, loadMore: Bool, cacheListType: UserListCacheManager.ListType) async {
        // CRITICAL: Prevent duplicate concurrent calls
        let shouldSkip: Bool = await MainActor.run {
            if !loadMore {
                // For initial load, only skip if already loaded
                // CRITICAL: Don't check isLoadingMore for initial loads - it might be stuck from previous operations
                if self.initialLoadComplete {
                    print("⚠️ [UserList] Ignoring duplicate fetchAndUpdateUsers call (already loaded, loadMore=false)")
                    // CRITICAL: Always stop loading indicator if it's running
                    if self.loadingIndicator.isAnimating {
                        print("🛑 [UserList] Stopping loading indicator (duplicate call detected)")
                        self.loadingIndicator.stopAnimating()
                    }
                    return true
                }
                // CRITICAL: Reset isLoadingMore if it's incorrectly set for initial load
                if self.isLoadingMore {
                    print("⚠️ [UserList] Resetting isLoadingMore flag (was incorrectly set for initial load)")
                    self.isLoadingMore = false
                    self.footerLoadingView.isHidden = true
                    self.footerLoadingIndicator.stopAnimating()
                }
            } else {
                // For load more, only skip if already loading more
                if self.isLoadingMore {
                    print("⚠️ [UserList] Ignoring duplicate fetchAndUpdateUsers call (already loading more)")
                    return true
                }
            }
            return false
        }
        
        guard !shouldSkip else {
            // Ensure loading indicator is stopped even when skipping
            await MainActor.run {
                if !loadMore && self.loadingIndicator.isAnimating {
                    print("🛑 [UserList] Stopping loading indicator (skipped call)")
                    self.loadingIndicator.stopAnimating()
                }
            }
            return
        }
        
        do {
            let response: PaginatedUsersResponse
            let limit = 50
            
            switch listType {
            case .followers:
                response = try await ProfileAPIService.shared.fetchFollowers(
                    userId: userId,
                    currentUserId: currentUserId,
                    limit: limit,
                    nextToken: loadMore ? nextToken : nil
                )
            case .following:
                response = try await ProfileAPIService.shared.fetchFollowing(
                    userId: userId,
                    currentUserId: currentUserId,
                    limit: limit,
                    nextToken: loadMore ? nextToken : nil
                )
            }
            
            // Convert to userModel (optimized - no image loading)
            var loadedUsers: [UserModel] = []
            for userWithStatus in response.data {
                var user = userWithStatus.toUserModel()
                if let followStatus = userWithStatus.followStatus {
                    user.isFollowing = followStatus.isFollowing
                    user.isFollower = followStatus.isFollower
                }
                loadedUsers.append(user)
            }
            
            // NOTE: We keep the current user in the list but hide the follow/following button for them
            // The button hiding is handled in cellForRowAt
            
            await MainActor.run {
                // CRITICAL: Prevent duplicate calls - check if we're already loaded
                // But still stop loading indicator even if we skip the update
                if !loadMore && self.initialLoadComplete {
                    print("⚠️ [UserList] Ignoring duplicate loadUsers call (already loaded)")
                    // Still stop loading indicator
                    self.loadingIndicator.stopAnimating()
                    return
                }
                
                if loadMore {
                    print("📋 [UserList] Appending \(loadedUsers.count) users (loadMore=true)")
                    // Append to existing users (avoid duplicates)
                    let existingIds = Set(self.users.compactMap { $0.userID })
                    let newUsers = loadedUsers.filter { user in
                        guard let userId = user.userID else { return false }
                        return !existingIds.contains(userId)
                    }
                    self.users.append(contentsOf: newUsers)
                    // Update cache with appended users
                    UserListCacheManager.shared.appendCachedUsers(
                        newUsers,
                        nextToken: response.nextToken,
                        hasMore: response.hasMore,
                        userId: userId,
                        listType: cacheListType
                    )
                } else {
                    print("📋 [UserList] Replacing users with \(loadedUsers.count) new users (loadMore=false)")
                    // Replace users
                    self.users = loadedUsers
                    // Cache the fresh data (REPLACING, not append)
                    UserListCacheManager.shared.cacheUsers(
                        loadedUsers,
                        nextToken: response.nextToken,
                        hasMore: response.hasMore,
                        userId: userId,
                        listType: cacheListType
                    )
                }
                
                // Update pagination state
                self.nextToken = response.nextToken
                self.hasMore = response.hasMore
                self.initialLoadComplete = true
                
                // CRITICAL: Always stop loading indicators
                if loadMore {
                    self.isLoadingMore = false
                    self.footerLoadingView.isHidden = true
                    self.footerLoadingIndicator.stopAnimating()
                } else {
                    // CRITICAL: For initial load, ensure all loading states are reset
                    self.isLoadingMore = false // Reset in case it was incorrectly set
                    self.loadingIndicator.stopAnimating()
                    print("✅ [UserList] Stopped loading indicator after initial load")
                }
                
                self.tableView.reloadData()
                self.checkEmptyState()
            }
        } catch {
            print("❌ Error loading users from AWS: \(error.localizedDescription)")
            await MainActor.run {
                if loadMore {
                    self.isLoadingMore = false
                    self.footerLoadingView.isHidden = true
                    self.footerLoadingIndicator.stopAnimating()
                } else {
                    self.loadingIndicator.stopAnimating()
                }
                self.showErrorBanner(message: "Failed to load \(self.listType.title.lowercased())")
                self.checkEmptyState()
            }
        }
    }
    
    private func loadMoreIfNeeded() {
        guard hasMore && !isLoadingMore else { return }
        loadUsers(loadMore: true)
    }
    
    private func checkEmptyState() {
        emptyStateLabel.isHidden = !users.isEmpty
    }
    
    // MARK: - User Actions
    
    @objc private func closeButtonTapped() {
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Animate button
        UIView.animate(withDuration: 0.1, animations: {
            self.closeButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: { _ in
            UIView.animate(withDuration: 0.1, animations: {
                self.closeButton.transform = CGAffineTransform.identity
            }, completion: { _ in
                // Return users list through completion handler
                self.completion?(self.users)
                
                // Dismiss with animation
                let transition = CATransition()
                transition.duration = 0.3
                transition.type = .push
                transition.subtype = .fromLeft
                self.view.window?.layer.add(transition, forKey: kCATransition)
                self.dismiss(animated: false)
            })
        })
    }
    
    private func showErrorBanner(message: String) {
        let banner = NotificationBanner(title: message, style: .danger)
        banner.show(bannerPosition: .top)
    }
    
    // MARK: - Follow Actions
    
    private func handleFollowToggle(user: UserModel, isFollowing: Bool, cell: ModernUserCell) {
        guard let currentUserId = AWSCognitoAuth.shared.getCurrentUserId() ?? CurrentUserService.shared.userID,
              let targetUserId = user.userID,
              let listUserId = currentUser?.userID else {
            showErrorBanner(message: "Unable to \(isFollowing ? "unfollow" : "follow") user")
            return
        }
        
        Task {
            do {
                let cacheListType: UserListCacheManager.ListType = listType == .followers ? .followers : .following
                
                if isFollowing {
                    // Unfollow
                    try await ProfileAPIService.shared.unfollowUser(
                        followerId: currentUserId,
                        followingId: targetUserId
                    )
                    
                    await MainActor.run {
                        // Update cell and user model
                        cell.isFollowing = false
                        if let index = users.firstIndex(where: { $0.userID == targetUserId }) {
                            users[index].isFollowing = false
                        }
                        
                        // Update cache
                        UserListCacheManager.shared.updateFollowStatus(
                            userId: listUserId,
                            targetUserId: targetUserId,
                            isFollowing: false,
                            listType: cacheListType
                        )
                        
                        let banner = NotificationBanner(title: "Unfollowed @\(user.userName ?? "")", style: .info)
                        banner.show(bannerPosition: .top)
                    }
                } else {
                    // Follow
                    _ = try await ProfileAPIService.shared.followUser(
                        followerId: currentUserId,
                        followingId: targetUserId
                    )
                    
                    await MainActor.run {
                        // Update cell and user model
                        cell.isFollowing = true
                        if let index = users.firstIndex(where: { $0.userID == targetUserId }) {
                            users[index].isFollowing = true
                        }
                        
                        // Update cache
                        UserListCacheManager.shared.updateFollowStatus(
                            userId: listUserId,
                            targetUserId: targetUserId,
                            isFollowing: true,
                            listType: cacheListType
                        )
                        
                        let banner = NotificationBanner(title: "Following @\(user.userName ?? "")", style: .success)
                        banner.show(bannerPosition: .top)
                    }
                }
            } catch {
                print("❌ Error toggling follow: \(error.localizedDescription)")
                await MainActor.run {
                    showErrorBanner(message: "Failed to \(isFollowing ? "unfollow" : "follow") user")
                }
            }
        }
    }

}

// MARK: - UITableViewDelegate & UITableViewDataSource

extension ModernUserListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath) as? ModernUserCell else {
            return UITableViewCell()
        }
        
        let user = users[indexPath.row]
        cell.configure(with: user)
        
        // Check if this user is the current user using UserIDResolver (handles both Parse and Cognito IDs)
        let isCurrentUser = UserIDResolver.shared.isCurrentUser(userId: user.userID) || 
                           (user.userName != nil && user.userName == CurrentUserService.shared.userName)
        
        // CRITICAL: Hide follow button if this is the current user (they shouldn't follow themselves)
        if isCurrentUser {
            cell.hideFollowButton = true
            print("🚫 [UserList] Hiding follow button for current user: \(user.userID ?? user.userName ?? "unknown")")
            cell.onFollowTapped = nil
        } else {
            // Not the current user - show follow button
            cell.hideFollowButton = false
            if let isFollowing = user.isFollowing {
                cell.isFollowing = isFollowing
            } else {
                cell.isFollowing = false
            }
            
            // Set up follow button action
            cell.onFollowTapped = { [weak self] user, isCurrentlyFollowing in
                self?.handleFollowToggle(user: user, isFollowing: isCurrentlyFollowing, cell: cell)
            }
        }
        
        // Add spacing between cells
        cell.contentView.layoutMargins = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 96
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Add spacing between cells
        cell.contentView.layer.masksToBounds = true
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Load more if user is near the end (within 5 rows)
        if indexPath.row >= users.count - 5 {
            loadMoreIfNeeded()
        }
        
        // Navigate to user profile - ALWAYS create a fresh instance
        let selectedUser = users[indexPath.row]
        print("👤 [UserList] Navigating to profile: \(selectedUser.userID ?? "nil"), userName: \(selectedUser.userName ?? "nil")")
        
        let profileVC = Profile()
        profileVC.selectedProfile = selectedUser
        profileVC.modalPresentationStyle = .fullScreen
        
        // Present with smooth transition
        let transition = CATransition()
        transition.duration = 0.35
        transition.type = .push
        transition.subtype = .fromRight
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        view.window?.layer.add(transition, forKey: kCATransition)
        
        present(profileVC, animated: false) { [weak profileVC] in
            // Ensure the profile loads fresh data for the selected user
            print("👤 [UserList] Profile presented, selectedProfile: \(profileVC?.selectedProfile?.userID ?? "nil")")
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Load more when user scrolls near bottom (within 200 points)
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height
        
        if offsetY > contentHeight - height - 200 {
            loadMoreIfNeeded()
        }
    }
}
