//
//  AppDelegate.swift
//  Do
//

import UIKit
import AWSCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static let appStartTime = Date()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize WatchConnectivity early to ensure it's ready for authentication sync
        // This must happen before any authentication occurs
        _ = CrossDeviceAuthManager.shared
        print("📱 [AppDelegate] CrossDeviceAuthManager initialized for watch connectivity")
        
        // Configure AWS (skip if not configured)
        if !Constants.Cognito.identityPoolId.isEmpty {
            configureAWS()
        }
        
        // Configure appearance
        configureAppearance()
        
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
    
    // MARK: - Configuration
    
    private func configureAWS() {
        let credentialsProvider = AWSCognitoCredentialsProvider(
            regionType: .USEast1,
            identityPoolId: Constants.Cognito.identityPoolId
        )
        
        let configuration = AWSServiceConfiguration(
            region: .USEast1,
            credentialsProvider: credentialsProvider
        )
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }
    
    private func configureAppearance() {
        // Navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.059, green: 0.086, blue: 0.243, alpha: 1.0)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // Tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(red: 0.059, green: 0.086, blue: 0.243, alpha: 1.0)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}
