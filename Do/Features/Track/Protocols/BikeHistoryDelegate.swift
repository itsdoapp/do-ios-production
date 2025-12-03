//
//  BikeHistoryDelegate.swift
//  Do
//
//  Delegate protocol for bike history view controller
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

/// Protocol for handling bike history selection events
protocol BikeHistoryDelegate: AnyObject {
    /// Called when a bike ride is selected from history
    /// - Parameter ride: The selected bike ride (typically BikeRideLog)
    func didSelectBikeRide(_ ride: Any)
}





