//
//  UnitSpeedExtensions.swift
//  Do
//
//  Custom pace units for tracking activities
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

extension UnitSpeed {
    /// Minutes per kilometer - useful for running/walking/hiking pace
    static let minutesPerKilometer = UnitSpeed(
        symbol: "min/km",
        converter: UnitConverterPace(coefficient: 16.6667) // 1000m / 60s
    )
    
    /// Minutes per mile - useful for imperial pace measurements
    static let minutesPerMile = UnitSpeed(
        symbol: "min/mi",
        converter: UnitConverterPace(coefficient: 26.8224) // 1609.34m / 60s
    )
}

/// Custom converter for pace units (inverted speed)
private class UnitConverterPace: UnitConverter {
    private let coefficient: Double
    
    init(coefficient: Double) {
        self.coefficient = coefficient
        super.init()
    }
    
    // UnitConverter doesn't conform to NSCoding, so we don't need init?(coder:)
    // If NSCoding support is needed in the future, implement it properly
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented - UnitConverter doesn't support NSCoding")
    }
    
    override func baseUnitValue(fromValue value: Double) -> Double {
        if value == 0 { return 0 }
        return coefficient / value
    }
    
    override func value(fromBaseUnitValue baseUnitValue: Double) -> Double {
        if baseUnitValue == 0 { return 0 }
        return coefficient / baseUnitValue
    }
}

