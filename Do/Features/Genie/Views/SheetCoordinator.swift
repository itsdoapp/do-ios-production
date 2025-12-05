import SwiftUI

/// Coordinates all sheets in GenieView to prevent evaluating all sheets on every body evaluation
/// This eliminates 3-8 second hangs by only creating sheets when actually needed
class SheetCoordinator: ObservableObject {
    @Published var activeSheet: SheetItem?
    
    enum SheetItem: Identifiable {
        case upsell
        case tokenPurchase
        case videoResults
        case meditation
        case mealPlan
        case mealSuggestions
        case restaurantSearch
        case cameraOptions
        case equipmentScanner
        case visionBoard
        case manifestation
        case affirmation
        case bedtimeStory
        case motivation
        case groceryList
        case cookbook
        case movementPreview
        case sessionPreview
        case planPreview
        
        var id: String {
            switch self {
            case .upsell: return "upsell"
            case .tokenPurchase: return "tokenPurchase"
            case .videoResults: return "videoResults"
            case .meditation: return "meditation"
            case .mealPlan: return "mealPlan"
            case .mealSuggestions: return "mealSuggestions"
            case .restaurantSearch: return "restaurantSearch"
            case .cameraOptions: return "cameraOptions"
            case .equipmentScanner: return "equipmentScanner"
        case .visionBoard: return "visionBoard"
        case .manifestation: return "manifestation"
        case .affirmation: return "affirmation"
        case .bedtimeStory: return "bedtimeStory"
        case .motivation: return "motivation"
        case .groceryList: return "groceryList"
        case .cookbook: return "cookbook"
        case .movementPreview: return "movementPreview"
        case .sessionPreview: return "sessionPreview"
        case .planPreview: return "planPreview"
            }
        }
    }
    
    @MainActor
    func view(for item: SheetItem, 
              upsellData: UpsellData?,
              onPhotoCapture: @escaping (UIImage) -> Void,
              onVideoCapture: @escaping (URL) -> Void) -> AnyView {
        switch item {
        case .upsell:
            if let upsell = upsellData {
                // Normalize recommendation: backend uses "token_pack" or "subscription"
                let normalizedRecommendation: String = {
                    if let rec = upsell.upsell.recommendation {
                        // Map backend values to SmartTokenUpsellView expected values
                        return rec == "subscription" ? "subscription" : "token_pack"
                    } else {
                        // Default based on hasSubscription
                        return upsell.upsell.hasSubscription ? "token_pack" : "subscription"
                    }
                }()
                
                return AnyView(SmartTokenUpsellView(
                    required: upsell.required,
                    balance: upsell.balance,
                    queryType: upsell.queryType,
                    tier: upsell.tier,
                    hasSubscription: upsell.upsell.hasSubscription,
                    recommendation: normalizedRecommendation,
                    tokenPacks: upsell.upsell.tokenPacks.map { TokenPack(id: $0.id, name: $0.name, tokens: $0.tokens, bonus: $0.bonus, price: $0.price, popular: $0.popular) },
                    subscriptions: upsell.upsell.subscriptions.map { UpsellSubscriptionPlan(id: $0.id, name: $0.name, tokens: $0.tokens, price: $0.price, perDay: $0.perDay) }
                ))
            } else {
                return AnyView(EmptyView())
            }
        case .tokenPurchase:
            // Use SmartTokenUpsellView for unified experience
            // Get actual balance from cache for accurate display
            let actualBalance = GenieAPIService.shared.getCachedBalance() ?? 0
            return AnyView(SmartTokenUpsellView(
                required: 100,
                balance: actualBalance, // Use actual cached balance
                queryType: "general",
                tier: 0,
                hasSubscription: false,
                recommendation: "token_pack",
                tokenPacks: [],
                subscriptions: []
            ))
        case .videoResults:
            if let videos = GenieActionHandler.shared.currentVideos {
                return AnyView(VideoResultsView(videos: videos.videos, query: videos.query))
            } else {
                return AnyView(EmptyView())
            }
        case .meditation:
            if let meditation = GenieActionHandler.shared.currentMeditation {
                return AnyView(MeditationPlayerView(meditation: meditation))
            } else {
                return AnyView(EmptyView())
            }
        case .mealPlan:
            if let mealPlan = GenieActionHandler.shared.currentMealPlan {
                return AnyView(EnhancedMealPlanView(mealPlan: mealPlan))
            } else {
                return AnyView(EmptyView())
            }
        case .mealSuggestions:
            if let suggestions = GenieActionHandler.shared.currentMealSuggestions {
                return AnyView(MealSuggestionsView(suggestions: suggestions))
            } else {
                return AnyView(EmptyView())
            }
        case .restaurantSearch:
            if let search = GenieActionHandler.shared.currentRestaurantSearch {
                return AnyView(RestaurantSearchView(restaurantSearch: search))
            } else {
                return AnyView(EmptyView())
            }
        case .cameraOptions:
            return AnyView(CameraOptionsSheet(
                onPhotoCapture: onPhotoCapture,
                onVideoCapture: onVideoCapture
            ))
        case .equipmentScanner:
            return AnyView(EquipmentScannerView())
        case .visionBoard:
            if let visionBoard = GenieActionHandler.shared.currentVisionBoard {
                return AnyView(VisionBoardView(visionBoard: visionBoard))
            } else {
                return AnyView(EmptyView())
            }
        case .manifestation:
            if let manifestation = GenieActionHandler.shared.currentManifestation {
                return AnyView(ManifestationView(manifestation: manifestation))
            } else {
                return AnyView(EmptyView())
            }
        case .affirmation:
            if let affirmation = GenieActionHandler.shared.currentAffirmation {
                return AnyView(AffirmationView(affirmation: affirmation))
            } else {
                return AnyView(EmptyView())
            }
        case .bedtimeStory:
            if let story = GenieActionHandler.shared.currentBedtimeStory {
                return AnyView(BedtimeStoryView(story: story))
            } else {
                return AnyView(EmptyView())
            }
        case .motivation:
            if let motivation = GenieActionHandler.shared.currentMotivation {
                return AnyView(MotivationView(motivation: motivation))
            } else {
                return AnyView(EmptyView())
            }
        case .groceryList:
            if let groceryList = GenieActionHandler.shared.currentGroceryList {
                return AnyView(GroceryListView(groceryList: groceryList))
            } else {
                return AnyView(EmptyView())
            }
        case .cookbook:
            return AnyView(ModernCookbookView())
        case .movementPreview:
            if let movement = GenieActionHandler.shared.currentMovement {
                return AnyView(GenieWorkoutPreviewView(workoutAction: movement))
            } else {
                return AnyView(EmptyView())
            }
        case .sessionPreview:
            if let session = GenieActionHandler.shared.currentSession {
                return AnyView(GenieWorkoutPreviewView(workoutAction: session))
            } else {
                return AnyView(EmptyView())
            }
        case .planPreview:
            if let plan = GenieActionHandler.shared.currentPlan {
                return AnyView(GenieWorkoutPreviewView(workoutAction: plan))
            } else {
                return AnyView(EmptyView())
            }
        }
    }
}


