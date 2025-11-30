import Foundation
import UIKit
import SwiftUI
import Combine

/// ViewModel for food image analysis functionality
class FoodImageAnalysisViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The current image being analyzed
    @Published var currentImage: UIImage?
    
    /// The status of the analysis process
    @Published var analysisStatus: AnalysisStatus = .idle
    
    /// The progress of the analysis (0.0 to 1.0)
    @Published var analysisProgress: Double = 0.0
    
    /// The result of the analysis, if available
    @Published var analysisResult: FoodDetectionResult?
    
    /// Whether the image picker is showing
    @Published var showImagePicker: Bool = false
    
    /// Whether the camera is showing
    @Published var showCamera: Bool = false
    
    /// Error message if analysis fails
    @Published var errorMessage: String?
    
    /// Current meal type selection
    @Published var selectedMealType: FoodMealType = .lunch
    
    /// Food logs for the current day
    @Published var todayFoodLogs: [FoodDetectionResult] = []
    
    // MARK: - Services
    
    /// Service for food image analysis
    private let analysisService = FoodImageAnalysisService.shared
    
    /// Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadSavedFoodLogs()
    }
    
    // MARK: - Public Methods
    
    /// Start the analysis of the current image
    func analyzeCurrentImage() {
        guard let image = currentImage else {
            errorMessage = "No image selected for analysis"
            return
        }
        
        analysisStatus = .analyzing
        analysisProgress = 0.0
        
        analysisService.analyzeFoodImage(
            image,
            progressHandler: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.analysisProgress = progress
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(var foodResult):
                        self?.analysisResult = foodResult
                        self?.analysisStatus = .completed
                        self?.saveFoodLog(foodResult)
                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                        self?.analysisStatus = .failed
                    }
                }
            }
        )
    }
    
    /// Reset the analysis state
    func resetAnalysis() {
        currentImage = nil
        analysisResult = nil
        analysisStatus = .idle
        analysisProgress = 0.0
        errorMessage = nil
    }
    
    /// Take photo or select from library
    func addImage(from source: ImageSource) {
        if source == .camera {
            showCamera = true
        } else {
            showImagePicker = true
        }
    }
    
    /// Set the current image and prepare for analysis
    func setImage(_ image: UIImage) {
        currentImage = image
        analysisStatus = .ready
    }
    
    // MARK: - Private Methods
    
    private func loadSavedFoodLogs() {
        // In a real app, this would load from Core Data or another persistence solution
        // For demo purposes, we'll create some sample data
        todayFoodLogs = createSampleFoodLogs()
    }
    
    private func saveFoodLog(_ result: FoodDetectionResult) {
        // In a real app, this would save to Core Data or another persistence solution
        // For demo purposes, we'll just add it to our array
        todayFoodLogs.append(result)
    }
    
    private func createSampleFoodLogs() -> [FoodDetectionResult] {
        // Create some sample food logs for demonstration
        let breakfast = FoodDetectionResult(
            originalImage: UIImage(systemName: "fork.knife")!,
            detectedFoods: [
                DetectedFood(
                    name: "Oatmeal",
                    confidence: 0.92,
                    boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.4),
                    nutritionalInfo: NutritionalInfo(
                        name: "Oatmeal",
                        calories: 150,
                        protein: 5,
                        carbs: 27,
                        fat: 3,
                        fiber: 4,
                        sugar: 1,
                        sodium: 0,
                        vitamins: ["B1", "B5"],
                        minerals: ["Iron", "Magnesium"],
                        portion: "1 cup cooked"
                    )
                ),
                DetectedFood(
                    name: "Banana",
                    confidence: 0.89,
                    boundingBox: CGRect(x: 0.6, y: 0.4, width: 0.3, height: 0.3),
                    nutritionalInfo: NutritionalInfo(
                        name: "Banana",
                        calories: 105,
                        protein: 1.3,
                        carbs: 27,
                        fat: 0.4,
                        fiber: 3.1,
                        sugar: 14,
                        sodium: 1,
                        vitamins: ["C", "B6"],
                        minerals: ["Potassium"],
                        portion: "1 medium banana"
                    )
                )
            ],
            mealType: .breakfast,
            totalCalories: 255,
            totalProtein: 6.3,
            totalCarbs: 54,
            totalFat: 3.4,
            proteinPercentage: 10,
            carbsPercentage: 72,
            fatPercentage: 18,
            analysisDate: Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date())!
        )
        
        return [breakfast]
    }
}

// MARK: - Supporting Types

extension FoodImageAnalysisViewModel {
    /// Status of the food image analysis process
    enum AnalysisStatus {
        case idle
        case ready
        case analyzing
        case completed
        case failed
    }
    
    /// Source of the image for analysis
    enum ImageSource {
        case camera
        case photoLibrary
    }
}

// For SwiftUI preview compatibility

extension FoodImageAnalysisViewModel {
    static var preview: FoodImageAnalysisViewModel {
        let viewModel = FoodImageAnalysisViewModel()
        viewModel.analysisResult = viewModel.createSampleFoodLogs().first
        return viewModel
    }
}
