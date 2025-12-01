//
//  DailyBricksWidgetBundle.swift
//  Do Watch App
//
//  Widget bundle for Daily Bricks complications
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import WidgetKit
import SwiftUI

// Widget bundle for watchOS complications
// Note: For watchOS, widgets are automatically discovered if they conform to Widget protocol
// The bundle groups multiple widgets together (currently just one)
struct DailyBricksWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        DailyBricksWidget()
    }
}

