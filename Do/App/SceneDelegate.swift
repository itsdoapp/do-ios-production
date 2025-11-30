//
//  SceneDelegate.swift
//  Do
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else {
            return
        }
        
        let window = UIWindow(windowScene: windowScene)
        
        // Don't manually set window frame - iOS will handle it automatically
        // Setting it manually can cause scaling issues
        self.window = window
        
        // Debug: Print initial sizes
        print("📱 [SceneDelegate] UIScreen.main.bounds: \(UIScreen.main.bounds)")
        print("📱 [SceneDelegate] Window scene screen.bounds: \(windowScene.screen.bounds)")
        print("📱 [SceneDelegate] Window scene coordinateSpace.bounds: \(windowScene.coordinateSpace.bounds)")
        
        // Check authentication status and show appropriate view
        Task { @MainActor in
            let authService = AuthService.shared
            print("📱 [SceneDelegate] AuthService initialized, isAuthenticated: \(authService.isAuthenticated)")
            print("📱 [SceneDelegate] CurrentUserService userID: \(CurrentUserService.shared.user.userID ?? "nil")")
            
            // Give a tiny moment for auth check to complete if needed
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            self.showInitialView(authService: authService, window: window)
        }
    }
    
    @MainActor
    private func showInitialView(authService: AuthService, window: UIWindow) {
        guard let windowScene = window.windowScene else {
            print("❌ [SceneDelegate] Window scene is nil")
            return
        }
        if authService.isAuthenticated {
            // User is logged in - show main tab view
            print("📱 [SceneDelegate] Showing MainTabView (authenticated)")
            let mainTabView = MainTabView()
            let hostingController = UIHostingController(rootView: mainTabView)
            hostingController.view.backgroundColor = UIColor(red: 15/255, green: 22/255, blue: 62/255, alpha: 1.0)
            // Ensure the view extends to edges - remove all safe area insets
            hostingController.additionalSafeAreaInsets = .zero
            
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
            
            // Force layout and print after view is laid out
            DispatchQueue.main.async {
                hostingController.view.setNeedsLayout()
                hostingController.view.layoutIfNeeded()
                
                print("📱 [SceneDelegate] After layout - Window bounds: \(window.bounds)")
                print("📱 [SceneDelegate] After layout - Window frame: \(window.frame)")
                print("📱 [SceneDelegate] After layout - Window scene screen.bounds: \(window.windowScene?.screen.bounds ?? .zero)")
                print("📱 [SceneDelegate] After layout - HostingController view frame: \(hostingController.view.frame)")
                print("📱 [SceneDelegate] After layout - HostingController view bounds: \(hostingController.view.bounds)")
                print("📱 [SceneDelegate] After layout - HostingController view safe area: \(hostingController.view.safeAreaInsets)")
            }
        } else {
            // User is not logged in - show intro view
            print("📱 [SceneDelegate] Showing IntroView (not authenticated)")
            let introView = IntroView()
            let hostingController = UIHostingController(rootView: introView)
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
        }
        
        // Observe auth state changes
        observeAuthChanges()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Ensure window is properly sized after scene becomes active
        guard let windowScene = scene as? UIWindowScene,
              let window = self.window else {
            return
        }
        
        // Check if window frame needs correction
        let screenBounds = windowScene.screen.bounds
        if window.frame != screenBounds && screenBounds.width > 0 && screenBounds.height > 0 {
            print("📱 [SceneDelegate] Correcting window frame from \(window.frame) to \(screenBounds)")
            window.frame = screenBounds
            window.setNeedsLayout()
            window.layoutIfNeeded()
        }
        
        print("📱 [SceneDelegate] sceneDidBecomeActive - Window frame: \(window.frame), Screen bounds: \(screenBounds)")
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
    }
    
    // MARK: - Private Methods
    
    private func createMainViewController() -> UIViewController {
        let tabBarController = UITabBarController()
        tabBarController.tabBar.backgroundColor = UIColor(red: 0.059, green: 0.086, blue: 0.243, alpha: 1.0)
        tabBarController.tabBar.tintColor = UIColor(red: 0.969, green: 0.576, blue: 0.122, alpha: 1.0)
        tabBarController.tabBar.unselectedItemTintColor = UIColor.white.withAlphaComponent(0.5)
        
        // Feed
        let feedVC = UIViewController()
        feedVC.view.backgroundColor = UIColor(red: 0.059, green: 0.086, blue: 0.243, alpha: 1.0)
        feedVC.tabBarItem = UITabBarItem(title: "Feed", image: UIImage(systemName: "house"), tag: 0)
        
        // Tracking
        let trackingVC = UIViewController()
        trackingVC.view.backgroundColor = UIColor(red: 0.059, green: 0.086, blue: 0.243, alpha: 1.0)
        trackingVC.tabBarItem = UITabBarItem(title: "Track", image: UIImage(systemName: "figure.run"), tag: 1)
        
        // Genie
        let genieVC = UIViewController()
        genieVC.view.backgroundColor = UIColor(red: 0.059, green: 0.086, blue: 0.243, alpha: 1.0)
        genieVC.tabBarItem = UITabBarItem(title: "Genie", image: UIImage(systemName: "sparkles"), tag: 2)
        
        // Challenges
        let challengesVC = UIViewController()
        challengesVC.view.backgroundColor = UIColor(red: 0.059, green: 0.086, blue: 0.243, alpha: 1.0)
        challengesVC.tabBarItem = UITabBarItem(title: "Challenges", image: UIImage(systemName: "trophy"), tag: 3)
        
        // Profile
        let profileVC = UIViewController()
        profileVC.view.backgroundColor = UIColor(red: 0.059, green: 0.086, blue: 0.243, alpha: 1.0)
        profileVC.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person"), tag: 4)
        
        tabBarController.viewControllers = [feedVC, trackingVC, genieVC, challengesVC, profileVC]
        
        return tabBarController
    }
    
    private func observeAuthChanges() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AuthStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateRootViewController()
            }
        }
    }
    
    @MainActor
    private func updateRootViewController() {
        let authService = AuthService.shared
        
        UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve) {
            if authService.isAuthenticated {
                let mainTabView = MainTabView()
                let hostingController = UIHostingController(rootView: mainTabView)
                hostingController.view.backgroundColor = UIColor(red: 15/255, green: 22/255, blue: 62/255, alpha: 1.0)
                // Ensure the view extends to edges - remove all safe area insets
                hostingController.additionalSafeAreaInsets = .zero
                self.window?.rootViewController = hostingController
            } else {
                let loginView = LoginView()
                self.window?.rootViewController = UIHostingController(rootView: loginView)
            }
        }
    }
    
    func logoutUser(windowScene: UIWindowScene) {
        // Clear stored session tokens
        UserDefaults.standard.removeObject(forKey: "sessionToken")
        UserDefaults.standard.removeObject(forKey: "cognito_user_id")
        UserDefaults.standard.removeObject(forKey: "cognito_id_token")
        UserDefaults.standard.removeObject(forKey: "cognito_access_token")
        
        let window = UIWindow(windowScene: windowScene)
        // Don't manually set window frame - iOS will handle it automatically
        let loginView = IntroView()
        window.rootViewController = UIHostingController(rootView: loginView)
        self.window = window
        window.makeKeyAndVisible()
    }
}
