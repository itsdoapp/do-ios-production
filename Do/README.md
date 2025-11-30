# Do - Cross-Platform Fitness App

Modern fitness and wellness app with **Kotlin Multiplatform Mobile (KMM)** for shared business logic, native iOS (SwiftUI/UIKit) and Android (Jetpack Compose) UIs, powered by AWS.

## 🏗️ Architecture

### Cross-Platform (KMM Shared)
- **Kotlin Multiplatform** - Shared business logic (60-70% code reuse)
- **Models** - User, Post, Challenge, Activity data models
- **Networking** - API client, AWS integration
- **Storage** - Keychain (iOS) / EncryptedSharedPreferences (Android)
- **Services** - Auth, User, Feed, Tracking logic

### iOS Native
- **SwiftUI** - Modern authentication and simple views
- **UIKit** - Complex screens (Feed, Tracking)
- **HealthKit** - Fitness data integration
- **CoreLocation** - GPS tracking
- **AVFoundation** - Camera/media

### Android Native (✅ Structure Ready)
- **Jetpack Compose** - Modern UI (Material 3)
- **Health Connect** - Fitness data integration
- **Location Services** - GPS tracking
- **CameraX** - Camera/media
- **AWS Amplify** - Cognito authentication
- **ExoPlayer** - Audio playback

### Backend (AWS)
- **Cognito** - Authentication
- **DynamoDB** - Data storage (50+ tables)
- **Lambda** - API endpoints (100+ functions)
- **S3** - Media storage
- **API Gateway** - REST & WebSocket APIs

## 📁 Project Structure

```
DoIOS/
├── shared/                 # Kotlin Multiplatform (shared code)
│   ├── commonMain/        # Cross-platform code
│   │   ├── models/       # Data models
│   │   ├── network/      # API client
│   │   ├── services/     # Business logic
│   │   └── storage/      # Data persistence
│   ├── iosMain/          # iOS-specific implementations
│   └── androidMain/      # Android-specific implementations
│
├── iOS/Do/                # iOS app
│   ├── App/              # App lifecycle
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift
│   │   └── Info.plist
│   │
├── Core/                   # Core functionality
│   ├── Models/            # Data models
│   ├── Networking/        # API client
│   ├── Services/          # Business logic
│   │   ├── Auth/         # Authentication
│   │   ├── API/          # API services
│   │   └── Storage/      # Local storage
│   └── Utilities/         # Helpers & extensions
│
├── Features/              # Feature modules
│   ├── Authentication/   # Login, signup, forgot password
│   ├── Feed/            # Social feed
│   ├── Tracking/        # Activity tracking
│   ├── Challenges/      # Competitions
│   ├── Genie/          # AI assistant
│   ├── Profile/        # User profile
│   └── Messaging/      # Chat
│
└── Resources/            # Assets
    ├── Assets.xcassets/
    └── Audio/
```

## 🚀 Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 16.0+
- CocoaPods
- XcodeGen

### Installation

1. **Install Gradle (for KMM):**
   ```bash
   brew install gradle
   ```

2. **Build shared framework:**
   ```bash
   cd /path/to/DoIOS
   ./build_shared.sh
   ```

3. **Install iOS dependencies:**
   ```bash
   cd iOS/Do
   ./setup.sh
   ```

2. **Configure AWS:**
   - Open `Core/Utilities/Helpers/Constants.swift`
   - Add your Cognito Client ID and Identity Pool ID

3. **Add Google Sign In:**
   - Download `GoogleService-Info.plist` from Firebase Console
   - Add it to the project root

4. **Open workspace:**
   ```bash
   open Do.xcworkspace
   ```

5. **Build and run!**

## 🔐 Authentication

### Supported Methods
- ✅ Email/Password (Cognito)
- ✅ Apple Sign In
- ✅ Google Sign In

### Flow
1. User enters credentials
2. Cognito validates and returns tokens
3. Tokens stored securely in Keychain
4. User profile fetched from AWS API
5. Main app loads

## 🎨 Design System

### Brand Colors
- **Primary Blue:** `#0F163E` - Main background
- **Accent Orange:** `#F7931F` - CTAs and highlights

### Typography
- System font with various weights
- Light weight for headers
- Medium/Semibold for buttons

## 📡 AWS Integration

### Endpoints
- **Main API:** `https://da8pzl5lu9.execute-api.us-east-1.amazonaws.com/prod`
- **Genie API:** `https://fylggf6z63.execute-api.us-east-1.amazonaws.com/prod`
- **WebSocket:** `wss://sxu6zkh5vb.execute-api.us-east-1.amazonaws.com/prod`

### DynamoDB Tables
- `prod-users` - User profiles
- `prod-posts` - Social posts
- `prod-runs` - Running activities
- `prod-bikes` - Biking activities
- `prod-walks` - Walking activities
- `prod-challenges` - Competitions
- `prod-genie-conversations` - AI chats
- And 40+ more...

## 🔧 Configuration Files

### Constants.swift
```swift
enum Constants {
    enum AWS {
        static let apiBaseURL = "https://..."
        static let region = "us-east-1"
    }
    
    enum Cognito {
        static let userPoolId = "us-east-1_ZNBwfBBaC"
        static let clientId = "YOUR_CLIENT_ID"  // ⚠️ Add this
        static let identityPoolId = "YOUR_POOL" // ⚠️ Add this
    }
}
```

### Info.plist Permissions
- Location (for tracking)
- Motion (for activity detection)
- Health (for fitness data)
- Camera (for posts)
- Photo Library (for sharing)
- Microphone (for videos)

## 📦 Dependencies

```ruby
# AWS
pod 'AWSCognitoIdentityProvider', '~> 2.33.0'
pod 'AWSCore', '~> 2.33.0'

# Social Login
pod 'GoogleSignIn', '~> 7.0'

# Networking
pod 'Alamofire', '~> 5.8'

# UI
pod 'SkeletonView'
pod 'lottie-ios'

# Monitoring
pod 'Bugsnag'
```

## 🏃 Features

### ✅ Implemented
- Authentication (Email, Apple, Google)
- User profile management
- Tab bar navigation
- Brand design system
- Secure token storage
- API client with auth

### 🚧 In Progress
- Feed (social posts)
- Activity tracking
- Genie AI assistant
- Challenges
- Messaging

## 🧪 Testing

```bash
# Run tests
xcodebuild test -workspace Do.xcworkspace -scheme Do -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 📱 App Store

- **Bundle ID:** `com.do.fitness`
- **Display Name:** Do
- **Version:** 2.0.0
- **Min iOS:** 16.0

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Test thoroughly
4. Submit PR

## 📄 License

Proprietary - All rights reserved

## 📞 Support

For issues or questions, contact the development team.

---

**Built with ❤️ using Swift, SwiftUI, and AWS**
