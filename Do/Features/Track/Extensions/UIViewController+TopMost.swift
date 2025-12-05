//
//  UIViewController+TopMost.swift
//  Do
//
//  Extension to get the topmost view controller in the hierarchy
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit

extension UIViewController {
    /// Returns the topmost view controller in the view hierarchy starting from this view controller
    /// - Returns: The topmost presented view controller, or self if no presented view controller exists
    func topMostViewController() -> UIViewController {
        // If this is a navigation controller, get the visible view controller
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?.topMostViewController() ?? navigationController
        }
        
        // If this is a tab bar controller, get the selected view controller
        if let tabBarController = self as? UITabBarController {
            if let selectedViewController = tabBarController.selectedViewController {
                return selectedViewController.topMostViewController()
            }
            return tabBarController
        }
        
        // If there's a presented view controller, recurse to find the topmost
        if let presentedViewController = self.presentedViewController {
            return presentedViewController.topMostViewController()
        }
        
        // If this is a container view controller with child view controllers, check them
        if let childViewController = children.last {
            return childViewController.topMostViewController()
        }
        
        // This is the topmost view controller
        return self
    }
}








