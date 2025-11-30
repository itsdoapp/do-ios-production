import SwiftUI

struct NutritionBadge: View {
    let label: String
    let value: String
    let color: Color
    
    // Convenience initializer for Int values
    init(label: String, value: Int, unit: String = "") {
        self.label = label
        self.value = "\(value)\(unit)"
        self.color = Color(hex: "F7931F")
    }
    
    // Main initializer for String values with color
    init(label: String, value: String, color: Color) {
        self.label = label
        self.value = value
        self.color = color
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}


