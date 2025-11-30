//
//  ProfileSettingsHostingController.swift
//  Do.
//
//  Created by Mikiyas Tadesse on 8/19/25.
//

import UIKit
import SwiftUI

final class ProfileSettingsHostingController: UIViewController {
    private var hostingController: UIHostingController<AnyView>?
    private var user: UserModel
    private var viewModel: ProfileSettingsViewModel?

    init(user: UserModel) {
        // Use CurrentUserService if the passed user doesn't have a userID, otherwise use the passed user
        if user.userID == nil || user.userID?.isEmpty == true {
            print("⚠️ [ProfileSettings] Passed user has no userID, using CurrentUserService")
            self.user = CurrentUserService.shared.user
        } else {
            self.user = user
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.user = CurrentUserService.shared.user
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwiftUIView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh user data from CurrentUserService if available
        if let currentUserId = CurrentUserService.shared.userID,
           currentUserId == user.userID {
            // Update user model with latest from CurrentUserService
            self.user = CurrentUserService.shared.user
            // Reload data if view model exists
            viewModel?.loadUserData()
        }
    }

    private func setupSwiftUIView() {
        // Ensure we have a valid user with userID
        if user.userID == nil || user.userID?.isEmpty == true {
            print("❌ [ProfileSettings] No valid userID found, cannot initialize settings")
            // Try to get from CurrentUserService
            if let currentUserId = CurrentUserService.shared.userID {
                self.user = CurrentUserService.shared.user
                print("✅ [ProfileSettings] Using CurrentUserService user: \(currentUserId)")
            } else {
                print("❌ [ProfileSettings] No user available from CurrentUserService either")
                // Show error or dismiss
                return
            }
        }
        
        let vm = ProfileSettingsViewModel(userModel: user)
        self.viewModel = vm
        let swiftUIView = ProfileSettingsView(viewModel: vm)
            .navigationBarTitleDisplayMode(.inline)
        
        // Wrap in AnyView to handle type erasure from modifiers
        let host = UIHostingController(rootView: AnyView(swiftUIView))
        hostingController = host

        addChild(host)
        self.view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }
}
