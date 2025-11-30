//
//  Constants.swift
//  Do
//

import Foundation

enum Constants {
    // AWS Configuration
    enum AWS {
        static let apiBaseURL = "https://da8pzl5lu9.execute-api.us-east-1.amazonaws.com/prod"
        static let genieAPIURL = "https://fylggf6z63.execute-api.us-east-1.amazonaws.com/prod"
        static let webSocketURL = "wss://sxu6zkh5vb.execute-api.us-east-1.amazonaws.com/prod"
        static let s3BucketURL = "https://do-app-media-prod-201409139361.s3.amazonaws.com"
        static let region = "us-east-1"
    }
    
    // Cognito Configuration
    enum Cognito {
        // NEW User Pool with username + email alias support
        static let userPoolId = "us-east-1_hjFzpbX9B"
        static let clientId = "14bgt9cruh3pvfb93nfpeqtd9i"
        static let identityPoolId = "us-east-1:abc799ce-6beb-46c8-9624-b072211f1fe1"
        
        // OLD User Pool (for reference)
        // static let userPoolId = "us-east-1_ZNBwfBBaC"
        // static let clientId = "6fjinl8gllrbl3vtvdu4c2kke5"
    }
    
    // App Configuration
    enum App {
        static let bundleId = "com.do.fitness"
        static let appName = "Do"
        static let version = "2.0.0"
    }
    
    // Google Configuration (set your iOS Client ID here)
    enum Google {
        static let clientID = "612395561006-8uvh182daa1l5jkuqg7agvdmdit09b4g.apps.googleusercontent.com"
        static let reversedClientID = "com.googleusercontent.apps.612395561006-8uvh182daa1l5jkuqg7agvdmdit09b4g"
    }
    
    // Keychain Keys
    enum Keychain {
        static let accessToken = "do_access_token"
        static let refreshToken = "do_refresh_token"
        static let idToken = "do_id_token"
        static let userId = "do_user_id"
    }
    
    // UserDefaults Keys
    enum UserDefaults {
        static let isLoggedIn = "is_logged_in"
        static let currentUserId = "current_user_id"
        static let hasCompletedOnboarding = "has_completed_onboarding"
    }
}
