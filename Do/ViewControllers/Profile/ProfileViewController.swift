import UIKit

final class Profile: UIViewController {
    var selectedProfile: UserModel? {
        didSet { configure() }
    }
    
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()
    private let emailLabel = UILabel()
    private let dismissButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.06, green: 0.09, blue: 0.24, alpha: 1)
        setupViews()
        configure()
    }
    
    private func setupViews() {
        nameLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        usernameLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        usernameLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        emailLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        emailLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        emailLabel.numberOfLines = 0
        
        dismissButton.setTitle("Close", for: .normal)
        dismissButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        dismissButton.tintColor = .white
        dismissButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.3)
        dismissButton.layer.cornerRadius = 12
        dismissButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        view.addSubview(nameLabel)
        view.addSubview(usernameLabel)
        view.addSubview(emailLabel)
        view.addSubview(dismissButton)
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 12),
            usernameLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            usernameLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            emailLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 8),
            emailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            emailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            dismissButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            dismissButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func configure() {
        let profile = selectedProfile ?? CurrentUserService.shared.user
        nameLabel.text = profile.name ?? "Profile"
        usernameLabel.text = "@" + (profile.userName ?? "username")
        emailLabel.text = profile.email ?? ""
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
