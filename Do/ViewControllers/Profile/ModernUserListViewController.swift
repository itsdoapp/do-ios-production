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
    
    private let tableView = UITableView()
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let emptyStateLabel = UILabel()
    
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
        loadUsers()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        // Background setup - refined dark gradient
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.06, green: 0.09, blue: 0.24, alpha: 1.0).cgColor,
            UIColor(red: 0.04, green: 0.07, blue: 0.20, alpha: 1.0).cgColor
        ]
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
        view.backgroundColor = UIColor(red: 0.06, green: 0.09, blue: 0.24, alpha: 1.0)
        
        // Header view setup - clean, minimal
        headerView.backgroundColor = UIColor(red: 0.06, green: 0.09, blue: 0.24, alpha: 0.98)
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
        
        // Table view setup - subtle separators
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.06)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 72, bottom: 0, right: 16)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Loading indicator setup
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        // Empty state label setup
        emptyStateLabel.text = listType.emptyMessage
        emptyStateLabel.font = UIFont(name: "AvenirNext-Medium", size: 16)
        emptyStateLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        emptyStateLabel.textAlignment = .center
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
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
    }
    
    // MARK: - Data Loading
    
    private func loadUsers() {
        loadingIndicator.startAnimating()
        
        // If users are already provided, use them
        if !users.isEmpty {
            self.loadingIndicator.stopAnimating()
            self.tableView.reloadData()
            self.checkEmptyState()
            return
        }
        
        // Fetch users from AWS
        guard let userId = currentUser?.userID else {
            loadingIndicator.stopAnimating()
            showErrorBanner(message: "Couldn't load user data")
            return
        }
        
        guard let currentUserId = AWSCognitoAuth.shared.getCurrentUserId() ?? CurrentUserService.shared.userID else {
            loadingIndicator.stopAnimating()
            showErrorBanner(message: "Not authenticated")
            return
        }
        
        Task {
            do {
                let response: PaginatedUsersResponse
                
                switch listType {
                case .followers:
                    response = try await ProfileAPIService.shared.fetchFollowers(
                        userId: userId,
                        currentUserId: currentUserId,
                        limit: 100
                    )
                case .following:
                    response = try await ProfileAPIService.shared.fetchFollowing(
                        userId: userId,
                        currentUserId: currentUserId,
                        limit: 100
                    )
                }
                
                // Convert to userModel
                var loadedUsers: [UserModel] = []
                for userWithStatus in response.data {
                    var user = await userWithStatus.toUserModel()
                    if let followStatus = userWithStatus.followStatus {
                        user.isFollowing = followStatus.isFollowing
                        user.isFollower = followStatus.isFollower
                    }
                    loadedUsers.append(user)
                }
                
                await MainActor.run {
                    self.users = loadedUsers
                    self.loadingIndicator.stopAnimating()
                    self.tableView.reloadData()
                    self.checkEmptyState()
                }
            } catch {
                print("❌ Error loading users from AWS: \(error.localizedDescription)")
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    self.showErrorBanner(message: "Failed to load \(self.listType.title.lowercased())")
                    self.checkEmptyState()
                }
            }
        }
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
        
        // Use follow status from AWS data
        if let isFollowing = user.isFollowing {
            cell.isFollowing = isFollowing
        } else {
            cell.isFollowing = false
            cell.hideFollowButton = true
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Navigate to user profile - ALWAYS create a fresh instance
        let selectedUser = users[indexPath.row]
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
            // Ensure the profile loads fresh data
            profileVC?.viewWillAppear(true)
        }
    }
}
