//
//  Track.swift
//  Track Infrastructure
//
//  Copied and updated from Do./ViewControllers/Main/Hosting ViewControllers/Track.swift
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import CoreLocation
import SwiftUI

class Track: UIViewController, CategorySelectionDelegate, CLLocationManagerDelegate {

    // MARK: Variable init
    var currentViewController: UIViewController?
    
    // Lazy-loaded view controllers (created only when needed)
    private lazy var trackingCategories: [UIViewController] = []
    private var categoryCache: [Int: UIViewController] = [:]
    
    // Data - Using CategoryData for consistency
    private var categories = CategoryData.titles
    private var currentCategoryIndex = 0
    
    var selectedCategoryType = 0
    
    var categoryTypeImages = CategoryData.icons

    let categoryTypeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "AvenirNext-DemiBold", size: 15 )
        label.textAlignment = .right
        label.textColor = .white
        return label
    }()
    
 
    // MARK: - init
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = uicolorFromHex(rgbValue: 0x0F163E)
        
        print("⚡️ Track viewDidLoad - Fast loading with lazy initialization")
        PerformanceLogger.start("Track:initialLoad")
        
        // Setup notification observers for direct category selection
        setupDirectCategorySelectionObserver()

        // Restore previously selected category or default to 0 (Running)
        let savedIndex = UserDefaults.standard.object(forKey: UserDefaults.selectedCategoryIndexKey) as? Int
        let initialIndex = min(max(savedIndex ?? selectedCategoryType, 0), CategoryData.count - 1)
        selectedCategoryType = initialIndex
        currentCategoryIndex = initialIndex
        
        // Set delegate to receive authorization callbacks BEFORE requesting permission
        ModernLocationManager.shared.manager.delegate = self
        
        // Request location permission early for weather and routes
        requestLocationPermissionIfNeeded()
        
        // Lazy load only the initial view controller
        let initialVC = getViewController(for: initialIndex)
        currentViewController = initialVC
        add(asChildViewController: initialVC)
    }
    
    // MARK: - Location Permission
    
    private func requestLocationPermissionIfNeeded() {
        let status = CLLocationManager.authorizationStatus()
        print("📍 Track viewDidLoad - Location status: \(status.rawValue)")
        
        switch status {
        case .notDetermined:
            print("📍 Requesting location permission for weather and routes...")
            // Use ModernLocationManager to request permission
            ModernLocationManager.shared.requestWhenInUseAuthorization()
            // Set delegate to receive authorization callback
            ModernLocationManager.shared.manager.delegate = self
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location permission already granted - starting location updates")
            // Start location updates to get current location for weather and routes
            ModernLocationManager.shared.requestLocation(for: .routeDisplay)
        case .denied, .restricted:
            print("⚠️ Location permission denied/restricted - weather and routes may not work")
        @unknown default:
            break
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Ensure navigation bar is hidden for the track screen
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Restore navigation bar when leaving track screen
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Lazy View Controller Loading
    
    private func getViewController(for index: Int) -> UIViewController {
        // Return cached VC if available
        if let cached = categoryCache[index] {
            print("♻️ Returning cached VC for category \(index)")
            return cached
        }
        
        print("🆕 Creating new VC for category \(index): \(categories[index])")
        
        let vc: UIViewController
        switch index {
        case 0: // Running
            let runningVC = ModernRunTrackerViewController()
            runningVC.categoryDelegate = self
            vc = runningVC
        case 1: // Gym
            let gymVC = ModernGymTrackerViewController()
            gymVC.categoryDelegate = self
            vc = gymVC
        case 2: // Cycling
            let bikingVC = ModernBikeTrackerViewController()
            bikingVC.categoryDelegate = self
            vc = bikingVC
        case 3: // Hiking
            let hikingVC = ModernHikeTrackerViewController()
            hikingVC.categoryDelegate = self
            vc = hikingVC
        case 4: // Walking
            let walkingVC = ModernWalkingTrackerViewController()
            walkingVC.categoryDelegate = self
            vc = walkingVC
        case 5: // Swimming
            let swimmingVC = ModernSwimmingTrackerViewController()
            swimmingVC.categoryDelegate = self
            vc = swimmingVC
        case 6: // Food
            let foodVC = ModernFoodTrackerViewController()
            foodVC.categoryDelegate = self
            vc = foodVC
        case 7: // Meditation
            let meditationVC = ModernMeditationTrackerViewController()
            meditationVC.categoryDelegate = self
            vc = meditationVC
        case 8: // Sports
            let sportsVC = ModernSportsTrackerViewController()
            sportsVC.categoryDelegate = self
            vc = sportsVC
        default:
            // Fallback to running
            let runningVC = ModernRunTrackerViewController()
            runningVC.categoryDelegate = self
            vc = runningVC
        }
        
        // Cache the VC for future use
        categoryCache[index] = vc
        return vc
    }
    

    private func setupGradientBackground(for view: UIView) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.9).cgColor,
                                UIColor(red: 0.0, green: 0.7, blue: 0.9, alpha: 0.9).cgColor]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    @objc func changeCategoryTapped() {
        // NOTE: changeCategoryVC() is deprecated - use CategorySelectorView instead
        // This method is kept for backward compatibility
        // Modern implementations should use CategorySelectorView (SwiftUI)
        print("⚠️ changeCategoryTapped() called - consider migrating to CategorySelectorView")
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
   
    private func updateView(removeCurrentVC: UIViewController?, addViewController: UIViewController) {
        // Remove current VC if exists
        removeCurrentVC?.willMove(toParent: nil)
        removeCurrentVC?.view.removeFromSuperview()
        removeCurrentVC?.removeFromParent()
        
        // Add new VC
        self.add(asChildViewController: addViewController)
        currentViewController = addViewController
    }
    
    private func add(asChildViewController viewController: UIViewController) {
        addChild(viewController)
        view.addSubview(viewController.view)
        viewController.view.frame = view.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Set category delegate if supported
        if let vc = viewController as? ModernRunTrackerViewController {
            vc.categoryDelegate = self
        } else if let vc = viewController as? ModernGymTrackerViewController {
            vc.categoryDelegate = self
        } else if let vc = viewController as? ModernBikeTrackerViewController {
            vc.categoryDelegate = self
        } else if let vc = viewController as? ModernHikeTrackerViewController {
            vc.categoryDelegate = self
        } else if let vc = viewController as? ModernWalkingTrackerViewController {
            vc.categoryDelegate = self
        } else if let vc = viewController as? ModernSwimmingTrackerViewController {
            vc.categoryDelegate = self
        } else if let vc = viewController as? ModernFoodTrackerViewController {
            vc.categoryDelegate = self
        } else if let vc = viewController as? ModernMeditationTrackerViewController {
            vc.categoryDelegate = self
        } else if let vc = viewController as? ModernSportsTrackerViewController {
            vc.categoryDelegate = self
        }
        
        viewController.didMove(toParent: self)
    }
    
    // MARK: - CategorySelectionDelegate
    
    func didSelectCategory(at index: Int) {
        print("🔄 Track.didSelectCategory called with index: \(index)")
        
        if index >= 0 && index < categories.count {
            // Update the current category index
            print("🔄 Track: Updating category from \(currentCategoryIndex) to \(index)")
            currentCategoryIndex = index
            selectedCategoryType = index
            
            // Save the selection to UserDefaults
            UserDefaults.standard.set(index, forKey: UserDefaults.selectedCategoryIndexKey)
         
            // Add a small delay to ensure UI transitions and animations complete properly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                
                // Lazy load the new VC
                let newVC = self.getViewController(for: index)
                
                // Update the view
                print("🔄 Track: Updating view to show \(type(of: newVC))")
                self.updateView(removeCurrentVC: self.currentViewController, addViewController: newVC)
                
                // PERMISSIONS: Let the VC handle its own permissions when needed
                // No automatic permission requests here
                
                // Post notification for observers
                NotificationCenter.default.post(
                    name: .categoryDidChange,
                    object: nil,
                    userInfo: ["index": index]
                )
                
                print("✅ Track: Category selection complete")
            }
        } else {
            print("❌ Track: Invalid category index: \(index), must be between 0 and \(categories.count-1)")
        }
    }

    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            print("📍 Track: Location authorization changed to: \(status.rawValue)")
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                print("✅ Track: Location permission granted - starting location updates for weather and routes")
                // Start location updates to get current location
                ModernLocationManager.shared.requestLocation(for: .routeDisplay)
                // Notify child view controllers that location is available
                NotificationCenter.default.post(
                    name: NSNotification.Name("LocationPermissionGranted"),
                    object: nil
                )
            case .denied, .restricted:
                print("⚠️ Track: Location permission denied - weather and routes may not work")
            case .notDetermined:
                print("📍 Track: Location permission not yet determined")
            @unknown default:
                break
            }
        }
    }
    
    // MARK: - Notification Handling
    private func setupDirectCategorySelectionObserver() {
        // Listen for direct category selection notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDirectCategorySelection(_:)),
            name: .directCategorySelection,
            object: nil
        )
    }

    @objc private func handleDirectCategorySelection(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let index = userInfo["index"] as? Int {
            print("📣 Track: Received DirectCategorySelection notification with index: \(index)")
            
            // Add a small delay to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                // Call our didSelectCategory method directly
                self.didSelectCategory(at: index)
            }
        }
    }
}

