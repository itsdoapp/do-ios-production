import UIKit

final class ModernUserCell: UITableViewCell {
    private let avatarView = UIImageView()
    private let placeholderIcon = UIImageView()
    private let initialsLabel = UILabel()
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()
    private let followButton = UIButton(type: .system)
    private var imageLoadTask: Task<Void, Never>?
    private var user: UserModel?
    
    var hideFollowButton: Bool = false {
        didSet { followButton.isHidden = hideFollowButton }
    }
    
    var isFollowing: Bool = false {
        didSet { updateFollowButton() }
    }
    
    var onFollowTapped: ((UserModel, Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        avatarView.image = nil
        nameLabel.text = nil
        usernameLabel.text = nil
        updatePlaceholder()
    }
    
    func configure(with user: UserModel) {
        self.user = user
        
        // Set name and username
        nameLabel.text = user.name ?? "Unknown"
        if let username = user.userName, !username.isEmpty {
            usernameLabel.text = "@\(username.lowercased())"
            usernameLabel.isHidden = false
        } else {
            usernameLabel.isHidden = true
        }
        
        // Load profile image
        if let profileImage = user.profilePicture {
            avatarView.image = profileImage
            hidePlaceholder()
        } else if let profilePicUrl = user.profilePictureUrl, !profilePicUrl.isEmpty {
            // Show placeholder while loading
            updatePlaceholder()
            loadProfileImage(from: profilePicUrl)
        } else {
            // No profile image - show placeholder
            avatarView.image = nil
            updatePlaceholder()
        }
    }
    
    private func loadProfileImage(from urlString: String) {
        imageLoadTask?.cancel()
        
        imageLoadTask = Task {
            guard let url = URL(string: urlString) else { return }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let image = UIImage(data: data) else { return }
                
                await MainActor.run {
                    UIView.transition(with: self.avatarView, duration: 0.2, options: .transitionCrossDissolve) {
                        self.avatarView.image = image
                        self.hidePlaceholder()
                    }
                }
            } catch {
                // Failed to load - show placeholder
                print("⚠️ Failed to load profile image: \(error.localizedDescription)")
                await MainActor.run {
                    self.updatePlaceholder()
                }
            }
        }
    }
    
    private func updatePlaceholder() {
        guard let user = user else {
            showPlaceholderIcon()
            return
        }
        
        // Try to show initials first, fallback to icon
        if let name = user.name, !name.isEmpty {
            let initials = getInitials(from: name)
            if !initials.isEmpty {
                showInitials(initials)
                return
            }
        }
        
        // Fallback to icon
        showPlaceholderIcon()
    }
    
    private func getInitials(from name: String) -> String {
        let components = name.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
        if components.count >= 2 {
            // First letter of first and last name
            let first = String(components[0].prefix(1)).uppercased()
            let last = String(components[components.count - 1].prefix(1)).uppercased()
            return "\(first)\(last)"
        } else if components.count == 1 {
            // First two letters of single name
            let name = components[0]
            if name.count >= 2 {
                return String(name.prefix(2)).uppercased()
            } else {
                return name.uppercased()
            }
        }
        return ""
    }
    
    private func showInitials(_ initials: String) {
        initialsLabel.text = initials
        initialsLabel.isHidden = false
        placeholderIcon.isHidden = true
    }
    
    private func showPlaceholderIcon() {
        initialsLabel.isHidden = true
        placeholderIcon.isHidden = false
    }
    
    private func hidePlaceholder() {
        initialsLabel.isHidden = true
        placeholderIcon.isHidden = true
    }
    
    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        
        // Content view with subtle background
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.03)
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        
        // Avatar setup - larger, with border
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        avatarView.layer.cornerRadius = 28
        avatarView.layer.masksToBounds = true
        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.borderWidth = 2
        avatarView.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        
        // Placeholder icon setup
        placeholderIcon.translatesAutoresizingMaskIntoConstraints = false
        placeholderIcon.image = UIImage(systemName: "person.circle.fill")
        placeholderIcon.tintColor = UIColor.white.withAlphaComponent(0.4)
        placeholderIcon.contentMode = .scaleAspectFit
        placeholderIcon.isHidden = true
        
        // Initials label setup
        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        initialsLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        initialsLabel.textAlignment = .center
        initialsLabel.isHidden = true
        
        // Name label - bold, white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 1
        
        // Username label - medium, orange accent
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        usernameLabel.textColor = UIColor(red: 247/255, green: 147/255, blue: 31/255, alpha: 1.0) // Brand orange
        usernameLabel.numberOfLines = 1
        
        // Follow button - modern styling
        followButton.translatesAutoresizingMaskIntoConstraints = false
        followButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        followButton.layer.cornerRadius = 18
        followButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        followButton.addTarget(self, action: #selector(followButtonTapped), for: .touchUpInside)
        updateFollowButton()
        
        // Labels stack
        let labelsStack = UIStackView(arrangedSubviews: [nameLabel, usernameLabel])
        labelsStack.axis = .vertical
        labelsStack.spacing = 3
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(avatarView)
        avatarView.addSubview(placeholderIcon)
        avatarView.addSubview(initialsLabel)
        contentView.addSubview(labelsStack)
        contentView.addSubview(followButton)
        
        NSLayoutConstraint.activate([
            // Avatar - larger size
            avatarView.widthAnchor.constraint(equalToConstant: 56),
            avatarView.heightAnchor.constraint(equalToConstant: 56),
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            // Placeholder icon - centered in avatar
            placeholderIcon.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            placeholderIcon.widthAnchor.constraint(equalToConstant: 32),
            placeholderIcon.heightAnchor.constraint(equalToConstant: 32),
            
            // Initials label - centered in avatar
            initialsLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            
            // Labels stack
            labelsStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 14),
            labelsStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labelsStack.trailingAnchor.constraint(lessThanOrEqualTo: followButton.leadingAnchor, constant: -12),
            
            // Follow button
            followButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            followButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            // Content view height
            contentView.heightAnchor.constraint(equalToConstant: 88)
        ])
    }
    
    @objc private func followButtonTapped() {
        guard let user = user else { return }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Call the callback
        onFollowTapped?(user, isFollowing)
    }
    
    private func updateFollowButton() {
        if isFollowing {
            followButton.setTitle("Following", for: .normal)
            followButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
            followButton.layer.borderWidth = 1
            followButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
            followButton.setTitleColor(.white, for: .normal)
        } else {
            followButton.setTitle("Follow", for: .normal)
            followButton.backgroundColor = UIColor(red: 247/255, green: 147/255, blue: 31/255, alpha: 1.0) // Brand orange
            followButton.layer.borderWidth = 0
            followButton.setTitleColor(.black, for: .normal)
        }
    }
}
