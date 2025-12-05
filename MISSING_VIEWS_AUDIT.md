# Missing Views Audit Report
**Date:** Generated during workspace audit  
**Focus:** ModernGymTrackerViewController.swift and ModernFoodTrackerViewController.swift

---

## Summary

Found **5 missing Views** referenced in `ModernFoodTrackerViewController.swift` and **3 missing ViewControllers** referenced in `ModernGymTrackerViewController.swift`. These are causing compilation errors.

---

## Missing Views in ModernFoodTrackerViewController.swift

### 1. ❌ ManualFoodEntryView
**Referenced at:** Line 330
```swift
.sheet(isPresented: $showingFoodSearch) {
    ManualFoodEntryView(mealType: mapMealType(selectedMealType)) {
        Task {
            await foodService.updateNutritionSummary()
        }
    }
}
```
**Status:** NOT FOUND
**Expected Location:** `Do/Features/Genie/Views/Food/ManualFoodEntryView.swift` or `Do/Features/Track/Views/ManualFoodEntryView.swift`

### 2. ❌ MealTemplatesView
**Referenced at:** Line 347
```swift
.sheet(isPresented: $showingMealTemplates) {
    MealTemplatesView { template in
        Task {
            await foodService.updateNutritionSummary()
        }
    }
}
```
**Status:** NOT FOUND
**Expected Location:** `Do/Features/Genie/Views/Food/MealTemplatesView.swift` or `Do/Features/Track/Views/MealTemplatesView.swift`

### 3. ❌ SavedRecipesView
**Referenced at:** Line 354
```swift
.sheet(isPresented: $showingSavedRecipes) {
    SavedRecipesView()
}
```
**Status:** NOT FOUND
**Expected Location:** `Do/Features/Genie/Views/Food/SavedRecipesView.swift` or `Do/Features/Track/Views/SavedRecipesView.swift`
**Note:** There's a `ModernCookbookView.swift` that might be related, but `SavedRecipesView` is specifically referenced.

### 4. ❌ FoodDetailView
**Referenced at:** Line 364
```swift
.sheet(item: $selectedFoodEntry) { entry in
    FoodDetailView(entry: entry)
}
```
**Status:** NOT FOUND
**Expected Location:** `Do/Features/Genie/Views/Food/FoodDetailView.swift` or `Do/Features/Track/Views/FoodDetailView.swift`

### 5. ❌ TodayMealsBreakdownView
**Referenced at:** Line 367
```swift
.sheet(isPresented: $showingMealsBreakdown) {
    TodayMealsBreakdownView()
}
```
**Status:** NOT FOUND
**Expected Location:** `Do/Features/Genie/Views/Food/TodayMealsBreakdownView.swift` or `Do/Features/Track/Views/TodayMealsBreakdownView.swift`

---

## Missing ViewControllers in ModernGymTrackerViewController.swift

### 1. ❌ NewWorkoutTrackingViewController
**Referenced at:** Line 7643
```swift
let trackingVC = NewWorkoutTrackingViewController(session: session)
trackingVC.isPlanLog = true
```
**Status:** NOT FOUND
**Expected Location:** `Do/Features/Track/ViewControllers/Gym/NewWorkoutTrackingViewController.swift`

### 2. ❌ ViewPlanVC
**Referenced at:** Line 7661
```swift
let planVC = ViewPlanVC()
planVC.thisPlan = plan
```
**Status:** NOT FOUND
**Expected Location:** `Do/Features/Track/ViewControllers/Gym/ViewPlanVC.swift`

### 3. ❌ ShareManager
**Referenced at:** Line 7679
```swift
ShareManager.shareWorkout(.plan(plan), from: rootVC, sendInMessage: true)
```
**Status:** NOT FOUND
**Expected Location:** `Do/Features/Track/Services/ShareManager.swift` or `Do/Core/Services/ShareManager.swift`
**Note:** This is a class/struct, not a ViewController, but it's missing.

---

## Views That Exist (Verified)

### ✅ FoodCameraView
**Location:** `Do/Features/Genie/Views/Food/FoodCameraView.swift`
**Status:** EXISTS

### ✅ BarcodeScannerView
**Location:** `Do/Features/Genie/Views/Food/BarcodeScannerView.swift`
**Status:** EXISTS

### ✅ RestaurantMealLoggingView
**Location:** `Do/Features/Genie/Views/Restaurant/RestaurantMealLoggingView.swift`
**Status:** EXISTS

### ✅ RestaurantAnalyticsView
**Location:** `Do/Features/Genie/Views/Restaurant/RestaurantAnalyticsView.swift`
**Status:** EXISTS

### ✅ CategorySelectorView
**Location:** `Do/Features/Track/UI/CategorySelectorView.swift`
**Status:** EXISTS

---

## Recommended Actions

### Priority 1: Create Missing Food Views
These are actively used in the Food tracker and will cause runtime crashes if not implemented:

1. **ManualFoodEntryView** - For manual food entry
2. **MealTemplatesView** - For meal templates
3. **SavedRecipesView** - For saved recipes (or use ModernCookbookView if appropriate)
4. **FoodDetailView** - For food entry details
5. **TodayMealsBreakdownView** - For today's meals breakdown

### Priority 2: Create Missing Gym ViewControllers
These are used for gym workout tracking:

1. **NewWorkoutTrackingViewController** - For tracking new workouts
2. **ViewPlanVC** - For viewing workout plans
3. **ShareManager** - For sharing workouts

---

## Implementation Notes

### For Food Views:
- All views should follow the same pattern as existing Genie Views
- They should use `FoodTrackingService` for data
- They should integrate with `FoodEntry` model
- Consider placing them in `Do/Features/Genie/Views/Food/` to match existing structure

### For Gym ViewControllers:
- `NewWorkoutTrackingViewController` should handle workout session tracking
- `ViewPlanVC` should display workout plans
- `ShareManager` should be a service class for sharing functionality

---

## Error Count Estimate

Based on the missing Views/ViewControllers:
- **ModernFoodTrackerViewController.swift:** ~5 missing Views = ~50-100 errors (each View reference causes multiple compilation errors)
- **ModernGymTrackerViewController.swift:** ~3 missing ViewControllers = ~30-50 errors

**Total estimated errors:** ~80-150 errors (matches the reported 137 errors)

---

## Next Steps

1. Create stub implementations for all missing Views/ViewControllers
2. Implement basic functionality to resolve compilation errors
3. Add proper error handling and loading states
4. Test each View/ViewController integration
5. Update audit report once all Views are created

---

*End of Missing Views Audit Report*








