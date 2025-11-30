# Uncomment the next line to define a global platform for your project

platform :ios, '15.0'
project 'Do/Do.xcodeproj'

target 'Do' do
  use_frameworks!
  
  pod 'Parse'
  pod 'NotificationBannerSwift'
  pod 'MarqueeLabel'
  pod 'MessageKit'
  # Using custom ParseLiveQuery implementation directly in the app instead of a pod
  pod 'SkeletonView'
  pod 'ReachabilitySwift'
  pod 'DGCharts'
  pod 'Alamofire'
  pod 'Starscream', '= 4.0.6'
  pod 'Bugsnag'
  pod 'BugsnagPerformance'
  pod 'lottie-ios'
  
  # AWS Cognito for authentication
  pod 'AWSCognitoIdentityProvider', '~> 2.33.0'
  pod 'AWSCore', '~> 2.33.0'

  # Stripe for payments
  pod 'StripePaymentSheet', '~> 23.0'

  # Firebase pods - using individual pods for better compatibility
  pod 'Firebase/Core'
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Analytics'
   
   # Google Sign-In for modern authentication
   pod 'GoogleSignIn'
  
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    # Update all targets to support latest iOS version to prevent build issues
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end
