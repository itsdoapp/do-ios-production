import Foundation

// MARK: - Premium Tier

enum PremiumTier: String, CaseIterable, Codable, Hashable {
    case free = "Free"
    case athlete = "Athlete"
    case champion = "Champion"
    case legend = "Legend"
    
    var name: String {
        rawValue
    }
    
    var monthlyTokens: Int {
        switch self {
        case .free: return 10
        case .athlete: return 500  // Fixed: was 100, should be 500 to match backend
        case .champion: return 1500  // Fixed: was 250, should be 1500 to match backend
        case .legend: return 5000  // Fixed: was 500, should be 5000 to match backend
        }
    }
    
    var monthlyPrice: Double {
        switch self {
        case .free: return 0
        case .athlete: return 9.99
        case .champion: return 19.99
        case .legend: return 49.99  // Fixed: was 39.99, should be 49.99 to match backend
        }
    }
    
    var annualPrice: Double {
        switch self {
        case .free: return 0
        case .athlete: return 99.90  // Fixed: was 99.99, should be 99.90 to match backend
        case .champion: return 199.90  // Fixed: was 199.99, should be 199.90 to match backend
        case .legend: return 499.90  // Fixed: was 399.99, should be 499.90 to match backend
        }
    }
    
    func price(for period: SubscriptionPeriod) -> Double {
        switch period {
        case .monthly: return monthlyPrice
        case .annual: return annualPrice
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "10 tokens/month",
                "Basic AI responses",
                "Limited features"
            ]
        case .athlete:
            return [
                "100 tokens/month",
                "Enhanced AI responses",
                "Food tracking",
                "Meal planning",
                "Basic workout generation"
            ]
        case .champion:
            return [
                "250 tokens/month",
                "Priority AI responses",
                "Advanced food tracking",
                "Custom meal plans",
                "Advanced workout generation",
                "Recipe recommendations"
            ]
        case .legend:
            return [
                "500 tokens/month",
                "Unlimited AI priority",
                "Premium food analysis",
                "Personalized meal plans",
                "Elite workout generation",
                "Restaurant recommendations",
                "Meditation sessions",
                "Priority support"
            ]
        }
    }
    
    var color: String {
        switch self {
        case .free: return "gray"
        case .athlete: return "blue"
        case .champion: return "purple"
        case .legend: return "orange"
        }
    }
    
    var gradientColors: [String] {
        switch self {
        case .free: return ["gray", "gray"]
        case .athlete: return ["blue", "cyan"]
        case .champion: return ["purple", "pink"]
        case .legend: return ["orange", "yellow"]
        }
    }
    
    /// Stripe Price ID for monthly subscription
    var stripeMonthlyPriceId: String {
        switch self {
        case .free: return ""
        case .athlete: return "price_athlete_monthly" // TODO: Replace with actual Stripe price ID
        case .champion: return "price_champion_monthly" // TODO: Replace with actual Stripe price ID
        case .legend: return "price_legend_monthly" // TODO: Replace with actual Stripe price ID
        }
    }
    
    /// Stripe Price ID for annual subscription
    var stripeAnnualPriceId: String {
        switch self {
        case .free: return ""
        case .athlete: return "price_athlete_annual" // TODO: Replace with actual Stripe price ID
        case .champion: return "price_champion_annual" // TODO: Replace with actual Stripe price ID
        case .legend: return "price_legend_annual" // TODO: Replace with actual Stripe price ID
        }
    }
    
    /// Optional badge text for the tier (e.g., "Popular", "Best Value")
    var badge: String? {
        switch self {
        case .free: return nil
        case .athlete: return nil
        case .champion: return "Popular"
        case .legend: return "Best Value"
        }
    }
}

// MARK: - Subscription Period

enum SubscriptionPeriod: String, CaseIterable, Codable, Hashable {
    case monthly = "Monthly"
    case annual = "Annual"
    
    var displayName: String {
        rawValue
    }
    
    var savingsText: String? {
        switch self {
        case .monthly: return nil
        case .annual: return "Save 17%"
        }
    }
    
    var billingDescription: String {
        switch self {
        case .monthly: return "Billed monthly"
        case .annual: return "Billed annually"
        }
    }
}

// MARK: - Subscription Info

struct SubscriptionInfo: Codable {
    let tier: PremiumTier
    let period: SubscriptionPeriod
    let tokensRemaining: Int
    let renewalDate: Date?
    let isActive: Bool
    
    init(
        tier: PremiumTier = .free,
        period: SubscriptionPeriod = .monthly,
        tokensRemaining: Int = 10,
        renewalDate: Date? = nil,
        isActive: Bool = false
    ) {
        self.tier = tier
        self.period = period
        self.tokensRemaining = tokensRemaining
        self.renewalDate = renewalDate
        self.isActive = isActive
    }
}

struct UserSubscription: Codable {
    let tier: PremiumTier
    let period: SubscriptionPeriod
    let tokensRemaining: Int
    let tokensUsedThisMonth: Int
    let renewalDate: Date?
    let stripeSubscriptionId: String?
    let isActive: Bool
    
    var monthlyAllowance: Int {
        tier.monthlyTokens
    }
    
    var tokensRemainingThisMonth: Int {
        max(0, monthlyAllowance - tokensUsedThisMonth)
    }
}

struct SubscriptionStatusResponse: Codable {
    let success: Bool
    let tier: PremiumTier?
    let period: SubscriptionPeriod?
    let monthlyAllowance: Int?
    let tokensUsedThisMonth: Int?
    let tokensRemainingThisMonth: Int?
    let nextRenewalDate: Date?
}

