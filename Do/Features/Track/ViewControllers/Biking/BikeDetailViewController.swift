//
//  BikeDetailViewController.swift
//  Do
//
//  View controller for displaying bike ride details
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import SwiftUI

class BikeDetailViewController: RunAnalysisViewController {
    
    // MARK: - Configuration
    
    func configure(with bikeRide: BikeRideLog) {
        // Set the run property (RunAnalysisViewController can handle BikeRideLog as well)
        self.run = bikeRide
        
        // If view has already loaded, we need to recreate the hosting controller
        if isViewLoaded {
            // Remove existing hosting controller
            children.forEach { $0.removeFromParent() }
            children.forEach { $0.view.removeFromSuperview() }
            
            // Create new hosting controller with the bike ride
            guard self.run != nil else { return }
            let analysisView = RunAnalysisView(run: self.run!, onDismiss: { [weak self] in
                self?.dismiss(animated: true)
            })
            
            let hostingController = UIHostingController(rootView: analysisView)
            addChild(hostingController)
            view.addSubview(hostingController.view)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            hostingController.didMove(toParent: self)
        }
    }
}

