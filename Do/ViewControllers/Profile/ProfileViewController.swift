import UIKit
import SwiftUI

final class Profile: UIViewController {
    var selectedProfile: UserModel? {
        didSet { 
            configure() 
        }
    }
    
    private var hostingController: UIHostingController<AnyView>?
    private var profileView: ProfileView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure selectedProfile is set before view appears
        if let selectedProfile = selectedProfile {
            print("👤 [ProfileVC] viewWillAppear - selectedProfile: \(selectedProfile.userID ?? "nil"), userName: \(selectedProfile.userName ?? "nil")")
        }
    }
    
    private func configure() {
        // Remove existing hosting controller if any
        hostingController?.willMove(toParent: nil)
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        hostingController = nil
        
        // Get the user to display - prioritize selectedProfile, fallback to current user
        let userToDisplay: UserModel
        let isCurrentUser: Bool
        
        if let selectedProfile = selectedProfile {
            userToDisplay = selectedProfile
            // Check if selected profile is the current user
            let currentUserId = AWSCognitoAuth.shared.getCurrentUserId() ?? CurrentUserService.shared.userID
            isCurrentUser = (selectedProfile.userID == currentUserId) || 
                           (selectedProfile.userName == CurrentUserService.shared.userName)
            print("👤 [ProfileVC] Configuring with selectedProfile")
            print("   - userID: \(userToDisplay.userID ?? "nil")")
            print("   - userName: \(userToDisplay.userName ?? "nil")")
            print("   - currentUserId: \(currentUserId ?? "nil")")
            print("   - isCurrentUser: \(isCurrentUser)")
            print("   - This should load posts for: \(userToDisplay.userID ?? userToDisplay.userName ?? "unknown")")
        } else {
            userToDisplay = CurrentUserService.shared.user
            isCurrentUser = true
            print("👤 [ProfileVC] No selectedProfile, using current user: \(userToDisplay.userID ?? "nil"), userName: \(userToDisplay.userName ?? "nil")")
        }
        
        // Create ProfileView with the user (always provide dismiss callback for modal presentation)
        let profileView = ProfileView(
            user: userToDisplay, 
            showsDismissButton: true, 
            onDismiss: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        self.profileView = profileView
        
        setupHostingController(with: profileView)
    }
    
    private func setupHostingController(with profileView: ProfileView) {
        // Create hosting controller with type erasure
        let host = UIHostingController(rootView: AnyView(profileView))
        hostingController = host
        
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }
}
