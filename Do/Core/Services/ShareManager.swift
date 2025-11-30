//
//  ShareManager.swift
//  Do
//
//  Service for sharing workouts, sessions, and plans
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import Foundation

// MARK: - Shareable Workout Enum

enum ShareableWorkout {
    case plan(plan)
    case movement(movement)
    case session(workoutSession)
}

class ShareManager {
    static let shared = ShareManager()
    
    private init() {}
    
    // MARK: - Share Workout
    
    func shareWorkout(
        _ workout: ShareableWorkout,
        from viewController: UIViewController,
        sendInMessage: Bool = false,
        completion: ((Bool) -> Void)? = nil
    ) {
        // Determine what to share
        var shareItems: [Any] = []
        var shareText = ""
        
        switch workout {
        case .plan(let plan):
            shareText = generatePlanShareText(plan)
        case .movement(let movement):
            shareText = generateMovementShareText(movement)
        case .session(let session):
            shareText = generateSessionShareText(session)
        }
        
        if !shareText.isEmpty {
            shareItems.append(shareText)
        }
        
        // If sendInMessage is true, use in-app messaging
        if sendInMessage {
            shareWorkoutPost(workout: workout, from: viewController, completion: completion)
            return
        }
        
        // Create activity view controller
        let activityVC = UIActivityViewController(
            activityItems: shareItems,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = viewController.view
            popoverController.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popoverController.permittedArrowDirections = []
        }
        
        viewController.present(activityVC, animated: true) {
            completion?(true)
        }
    }
    
    // MARK: - Share to Social Media
    
    func shareToInstagramStory(
        image: UIImage?,
        from viewController: UIViewController
    ) {
        guard let image = image else { return }
        
        // Instagram Stories URL scheme
        guard let instagramURL = URL(string: "instagram-stories://share") else {
            showError(message: "Instagram is not installed", from: viewController)
            return
        }
        
        if UIApplication.shared.canOpenURL(instagramURL) {
            // Share image to Instagram Stories
            let pasteboard = UIPasteboard.general
            pasteboard.image = image
            
            UIApplication.shared.open(instagramURL) { success in
                if !success {
                    self.showError(message: "Failed to open Instagram", from: viewController)
                }
            }
        } else {
            showError(message: "Instagram is not installed", from: viewController)
        }
    }
    
    func shareToTwitter(
        text: String,
        from viewController: UIViewController
    ) {
        let tweetText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let twitterURL = URL(string: "twitter://post?message=\(tweetText)") else {
            showError(message: "Twitter is not installed", from: viewController)
            return
        }
        
        if UIApplication.shared.canOpenURL(twitterURL) {
            UIApplication.shared.open(twitterURL)
        } else {
            // Fallback to web
            if let webURL = URL(string: "https://twitter.com/intent/tweet?text=\(tweetText)") {
                UIApplication.shared.open(webURL)
            }
        }
    }
    
    // MARK: - Generate Share Text
    
    private func generateMovementShareText(_ movement: movement) -> String {
        let name = movement.movement1Name ?? "Workout"
        return "Just completed \(name)! 💪 #DoApp"
    }
    
    private func generateSessionShareText(_ session: workoutSession) -> String {
        let name = session.name ?? "Workout Session"
        return "Just finished \(name)! 🏋️ #DoApp"
    }
    
    private func generatePlanShareText(_ plan: plan) -> String {
        let name = plan.name.isEmpty ? "Workout Plan" : plan.name
        return "Started \(name)! 📅 #DoApp"
    }
    
    // MARK: - Helper Methods
    
    private func showError(message: String, from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }
    
    // MARK: - Share Workout Post (for in-app sharing)
    
    private func shareWorkoutPost(
        workout: ShareableWorkout,
        from viewController: UIViewController,
        completion: ((Bool) -> Void)? = nil
    ) {
        // TODO: Implement in-app sharing to feed
        // This would create a post in the app's feed
        
        let alert = UIAlertController(
            title: "Share Workout",
            message: "Workout sharing to feed is coming soon!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
        
        completion?(false)
    }
}

