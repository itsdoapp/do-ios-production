import UIKit

final class ModernUserCell: UITableViewCell {
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let followButton = UIButton(type: .system)
    
    var hideFollowButton: Bool = false {
        didSet { followButton.isHidden = hideFollowButton }
    }
    
    var isFollowing: Bool = false {
        didSet { updateFollowButton() }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    func configure(with user: UserModel) {
        nameLabel.text = user.name ?? user.userName ?? "Unknown"
        subtitleLabel.text = user.email ?? ""
    }
    
    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        avatarView.layer.cornerRadius = 24
        avatarView.layer.masksToBounds = true
        avatarView.contentMode = .scaleAspectFill
        
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        nameLabel.textColor = .label
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        
        followButton.translatesAutoresizingMaskIntoConstraints = false
        followButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        followButton.layer.cornerRadius = 16
        followButton.layer.borderWidth = 1
        followButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
        updateFollowButton()
        
        let labelsStack = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
        labelsStack.axis = .vertical
        labelsStack.spacing = 4
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(avatarView)
        contentView.addSubview(labelsStack)
        contentView.addSubview(followButton)
        
        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 48),
            avatarView.heightAnchor.constraint(equalToConstant: 48),
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            labelsStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            labelsStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            followButton.leadingAnchor.constraint(greaterThanOrEqualTo: labelsStack.trailingAnchor, constant: 12),
            followButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            followButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            contentView.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 12)
        ])
    }
    
    private func updateFollowButton() {
        if isFollowing {
            followButton.setTitle("Following", for: .normal)
            followButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
            followButton.layer.borderColor = UIColor.systemBlue.cgColor
            followButton.setTitleColor(.systemBlue, for: .normal)
        } else {
            followButton.setTitle("Follow", for: .normal)
            followButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.15)
            followButton.layer.borderColor = UIColor.systemOrange.cgColor
            followButton.setTitleColor(.systemOrange, for: .normal)
        }
    }
}
