//
//  MainTabView.swift
//  Do
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var authService = AuthService.shared
    @State private var selectedTab = 2 // Default to Feed (index 2)
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Challenges Tab
            ChallengesView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text("Challenges")
                }
                .tag(0)
            
            // Track Tab
            TrackView()
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("Track")
                }
                .tag(1)
            
            // Feed Tab
            FeedView()
                .tabItem {
                    if let logoImage = UIImage(named: "logo_45") {
                        let resizedImage = logoImage.resized(to: CGSize(width: 20, height: 20))?.withRenderingMode(.alwaysTemplate) ?? logoImage.withRenderingMode(.alwaysTemplate)
                        Image(uiImage: resizedImage)
                    } else {
                        Image("logo_45")
                            .renderingMode(.template)
                    }
                    Text("Feed")
                }
                .tag(2)
            
            // Genie Tab
            GenieView(context: .general)
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("Genie")
                }
                .tag(3)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(Color.brandOrange)
        .ignoresSafeArea(.all, edges: .all)
        .background(Color.brandBlue.ignoresSafeArea(.all))
        .onAppear {
            print("📱 [MainTabView] Screen size: \(UIScreen.main.bounds.size)")
            print("📱 [MainTabView] Screen native bounds: \(UIScreen.main.nativeBounds)")
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                print("📱 [MainTabView] Window scene bounds: \(windowScene.coordinateSpace.bounds)")
            }
            
            // Ensure auth status is checked and CurrentUserService is populated
            print("📱 [MainTabView] Triggering checkAuthStatus()")
            authService.checkAuthStatus()
            
            configureTabBarAppearance()
        }
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        
        // Configure tab bar item appearance
        let itemAppearance = UITabBarItemAppearance()
        
        // Normal state - white icons with transparency (inactive)
        itemAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.7)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]
        
        // Selected state - orange icons (active)
        itemAppearance.selected.iconColor = UIColor(red: 247/255, green: 147/255, blue: 31/255, alpha: 1.0)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 247/255, green: 147/255, blue: 31/255, alpha: 1.0),
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        
        // Apply to all layout types
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        
        // Background with Do blue tint and transparency
        appearance.backgroundColor = UIColor(red: 15/255, green: 22/255, blue: 62/255, alpha: 0.95)
        
        // Apply appearance
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().tintColor = UIColor(red: 247/255, green: 147/255, blue: 31/255, alpha: 1.0)
        UITabBar.appearance().unselectedItemTintColor = UIColor.white.withAlphaComponent(0.7)
    }
}

#Preview {
    MainTabView()
}

// MARK: - UIImage Extension for Resizing
extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
