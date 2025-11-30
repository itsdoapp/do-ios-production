# Do iOS App

> **Native iOS application built with Swift, SwiftUI, and UIKit, featuring comprehensive fitness tracking, social features, and AI-powered wellness assistance.**

## 📱 Overview

The Do iOS app is a full-featured fitness and wellness application that provides:

- **Activity Tracking** - Running, biking, walking, sports, gym workouts, meditation
- **Social Feed** - Share workouts, photos, and connect with friends
- **Challenges** - Compete in fitness challenges
- **Genie AI** - AI-powered wellness assistant
- **Apple Watch** - Full watchOS app with workout tracking
- **HealthKit Integration** - Sync with Apple Health

## 🏗️ Architecture

### Technology Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (modern views) + UIKit (complex screens)
- **Architecture**: MVVM with Combine
- **Dependencies**: CocoaPods
- **Minimum iOS**: 16.0
- **Target Devices**: iPhone, iPad, Apple Watch

### Project Structure

```
ios/
├── Do/
│   ├── App/                    # App lifecycle
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift
│   │   └── Info.plist
│   │
│   ├── Core/                   # Core functionality
│   │   ├── Models/            # Data models
│   │   ├── Networking/       # API client, AWS integration
│   │   ├── Services/          # Business logic
│   │   │   ├── Auth/         # Authentication
│   │   │   ├── API/          # API services
│   │   │   ├── Genie/        # AI assistant
│   │   │   └── Storage/      # Keychain, UserDefaults
│   │   └── Utilities/         # Helpers & extensions
│   │
│   ├── Features/              # Feature modules
│   │   ├── Authentication/   # Login, signup
│   │   ├── Feed/            # Social feed
│   │   ├── Track/           # Activity tracking
│   │   │   ├── Engines/     # Tracking engines
│   │   │   ├── Services/    # Location, weather, routes
│   │   │   └── ViewControllers/ # UI controllers
│   │   ├── Challenges/      # Competitions
│   │   ├── Genie/          # AI assistant UI
│   │   ├── Profile/        # User profile
│   │   └── Messaging/      # Chat
│   │
│   ├── Do Watch App/          # watchOS app
│   │   ├── Services/         # Watch services
│   │   ├── Views/           # Watch UI
│   │   └── Models/          # Watch models
│   │
│   ├── Common/                # Shared code
│   │   ├── Models/          # Shared models
│   │   └── Extensions/      # Swift extensions
│   │
│   └── Resources/            # Assets
│       ├── Assets.xcassets/
│       └── Audio/
│
├── Podfile                    # CocoaPods dependencies
├── Podfile.lock
└── README.md                  # This file
```

## 🚀 Getting Started

### Prerequisites

- **Xcode**: 15.0 or later
- **iOS**: 16.0+ (deployment target)
- **CocoaPods**: Latest version
- **macOS**: 13.0+ (for Xcode)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/itsdoapp/do-ios.git
   cd do-ios
   ```

2. **Install CocoaPods dependencies**
   ```bash
   cd Do
   pod install
   ```

3. **Configure AWS credentials**
   - Open `Do/Core/Utilities/Helpers/Constants.swift`
   - Verify Cognito configuration (already configured for production)

4. **Add Google Sign-In configuration**
   - Download `GoogleService-Info.plist` from Firebase Console
   - Add it to `Do/` directory

5. **Open workspace**
   ```bash
   open Do.xcworkspace
   ```

6. **Build and run**
   - Select a simulator or device
   - Press `Cmd + R` to build and run

### Watch App Setup

The watch app is automatically included in the workspace. To run on a watch simulator:

1. Pair watch simulator with iPhone simulator
2. Select "Do Watch App" scheme
3. Build and run

## 🔐 Authentication

### Supported Methods

- ✅ **Email/Password** - AWS Cognito
- ✅ **Apple Sign In** - Native Apple authentication
- ✅ **Google Sign In** - Google OAuth

### Authentication Flow

1. User enters credentials or selects social login
2. Cognito validates and returns tokens
3. Tokens stored securely in Keychain
4. User profile fetched from AWS API
5. Main app loads with authenticated state

### Cross-Device Authentication

The iOS app syncs authentication tokens to Apple Watch via WatchConnectivity:

- Tokens automatically synced when user logs in
- Watch app can request auth status from iPhone
- Seamless authentication across devices

## 📡 API Integration

### Endpoints

- **Main API**: `https://da8pzl5lu9.execute-api.us-east-1.amazonaws.com/prod`
- **Genie API**: `https://fylggf6z63.execute-api.us-east-1.amazonaws.com/prod`
- **WebSocket**: `wss://sxu6zkh5vb.execute-api.us-east-1.amazonaws.com/prod`
- **Media Storage**: `https://do-app-media-prod-201409139361.s3.amazonaws.com`

### API Services

- `APIClient` - Base networking layer
- `FeedAPIService` - Social feed posts
- `ProfileAPIService` - User profiles
- `GenieAPIService` - AI assistant
- `InteractionAPIService` - Likes, comments, follows
- `UserService` - User management

## 🎨 Design System

### Brand Colors

- **Primary Blue**: `#0F163E` - Main background
- **Accent Orange**: `#F7931F` - CTAs and highlights
- **White**: `#FFFFFF` - Text and cards
- **Dark Gray**: `#1A1A1A` - Secondary backgrounds

### Typography

- **System Font** - SF Pro (iOS default)
- **Weights**: Light, Regular, Medium, Semibold, Bold
- **Sizes**: 12pt - 34pt

### UI Components

- **Cards** - Rounded corners, shadows, gradients
- **Buttons** - Brand orange with white text
- **Navigation** - Custom tab bar with brand colors
- **Modals** - Full-screen presentations

## 🏃 Features

### ✅ Implemented

- **Authentication** - Email, Apple, Google sign-in
- **User Profiles** - Profile management, settings
- **Social Feed** - Posts, likes, comments, follows
- **Activity Tracking** - Running, biking, walking, sports, gym, meditation
- **Apple Watch** - Full workout tracking on watch
- **Genie AI** - AI-powered wellness assistant
- **Challenges** - Fitness competitions
- **Messaging** - Direct messages
- **HealthKit** - Integration with Apple Health
- **Location Services** - GPS tracking, routes, weather

### 🚧 In Progress

- Enhanced analytics
- Social features improvements
- Performance optimizations

## 📦 Dependencies

### Core Dependencies

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
pod 'SnapKit'
pod 'MessageKit'

# Monitoring
pod 'Bugsnag'
pod 'BugsnagPerformance'

# Charts
pod 'DGCharts'
```

See `Podfile` for complete list.

## 🧪 Testing

### Running Tests

```bash
# Run all tests
xcodebuild test -workspace Do.xcworkspace -scheme Do -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run specific test suite
xcodebuild test -workspace Do.xcworkspace -scheme Do -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DoTests/YourTestClass
```

### Test Structure

- **Unit Tests**: `DoTests/` - Business logic tests
- **UI Tests**: `DoUITests/` - User interface tests
- **Integration Tests**: API integration tests

## 📱 App Store

### Configuration

- **Bundle ID**: `com.do.fitness`
- **Display Name**: Do
- **Version**: 2.0.0
- **Minimum iOS**: 16.0
- **Watch App**: Included

### Submission

1. Archive the app in Xcode
2. Upload to App Store Connect
3. Submit for review

## 🔧 Configuration

### Info.plist Permissions

- **Location** - For activity tracking
- **Motion** - For activity detection
- **Health** - For HealthKit integration
- **Camera** - For posts
- **Photo Library** - For sharing
- **Microphone** - For videos

### Background Modes

- **Location updates** - For workout tracking
- **Background fetch** - For data updates

## 🐛 Debugging

### Logging

The app uses print statements with emoji prefixes for easy filtering:

- 🔐 Authentication
- 🌐 Network requests
- 📍 Location services
- 🏃 Activity tracking
- ⌚️ Watch connectivity
- 🧞 Genie AI

### Common Issues

1. **CocoaPods issues**: Run `pod deintegrate && pod install`
2. **Watch connectivity**: Ensure watch is paired and reachable
3. **Location permissions**: Check Info.plist and permission requests
4. **API errors**: Verify AWS credentials and network connectivity

## 📚 Documentation

- [Architecture Analysis](./AUTH_ARCHITECTURE_ANALYSIS.md)
- [Tracking System](./Do/Features/Track/TRACKING_SYSTEM_ANALYSIS.md)
- [Watch App Setup](./Do/WATCH_APP_SETUP_COMPLETE.md)
- [Feed Architecture](./Do/Features/Feed/FEED_ARCHITECTURE.md)

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Write/update tests
4. Update documentation
5. Submit a pull request

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint for code formatting
- Document public APIs
- Write meaningful commit messages

## 📄 License

Proprietary - All rights reserved

## 🔗 Related Repositories

- [Do Android](https://github.com/itsdoapp/do-android)
- [Do Web](https://github.com/itsdoapp/do-web)
- [Do Backend](https://github.com/itsdoapp/do-backend)

---

**Built with ❤️ using Swift, SwiftUI, and AWS**

