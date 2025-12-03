//
//  DailyBricksWidgetBundle.swift
//  Do
//
//  Widget bundle for iOS Daily Bricks widget
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import WidgetKit
import SwiftUI

// Widget bundle for iOS widgets
struct DailyBricksWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        DailyBricksWidget()
    }
}


