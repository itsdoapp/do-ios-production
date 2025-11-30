import SwiftUI
import UIKit

/// View for analyzing food images and displaying nutritional information
struct FoodImageAnalysisView: View {
    // MARK: - Properties
    
    @ObservedObject var viewModel: FoodImageAnalysisViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Init
    
    init() {
        self.viewModel = FoodImageAnalysisViewModel()
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 0) {
                    if viewModel.analysisStatus == .analyzing {
                        processingView
                    } else if let detectionResult = viewModel.analysisResult {
                        ScrollView {
                            VStack(spacing: 20) {
                                // Food image
                                if let analyzedImage = viewModel.currentImage {
                                    Image(uiImage: analyzedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                        .padding(.horizontal)
                                }
                                
                                // Nutrition summary card
                                nutritionSummaryCard(result: detectionResult)
                                
                                // Detected foods card
                                detectedFoodsCard(result: detectionResult)
                                
                                // Nutritional analysis card
                                nutritionalAnalysisCard(result: detectionResult)
                                
                                // Recommendations
                                recommendationsCard()
                                
                                // Action buttons
                                actionButtons()
                                
                                Spacer()
                            }
                            .padding()
                        }
                    } else if viewModel.errorMessage != nil {
                        errorView
                    } else {
                        initialView
                    }
                }
            }
            .navigationTitle("Food Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.resetAnalysis()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                    }
                    .disabled(viewModel.analysisResult == nil || viewModel.analysisStatus == .analyzing)
                }
            }
            .sheet(isPresented: $viewModel.showImagePicker) {
                FoodImagePicker(selectedImage: Binding<UIImage?>(
                    get: { self.viewModel.currentImage },
                    set: { newImage in
                        if let image = newImage {
                            self.viewModel.setImage(image)
                        }
                    }
                ), sourceType: UIImagePickerController.SourceType.photoLibrary)
            }
            .sheet(isPresented: $viewModel.showCamera) {
                FoodImagePicker(selectedImage: Binding<UIImage?>(
                    get: { self.viewModel.currentImage },
                    set: { newImage in
                        if let image = newImage {
                            self.viewModel.setImage(image)
                        }
                    }
                ), sourceType: UIImagePickerController.SourceType.camera)
            }
        }
    }
    
    // MARK: - Initial View
    
    private var initialView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 70))
                .foregroundColor(.blue)
            
            Text("Take a photo of your meal to analyze")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Get nutritional information, calorie estimates, and macro breakdowns")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            HStack(spacing: 20) {
                Button {
                    viewModel.addImage(from: .camera)
                } label: {
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .padding(.bottom, 5)
                        
                        Text("Take Photo")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button {
                    viewModel.addImage(from: .photoLibrary)
                } label: {
                    VStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .padding(.bottom, 5)
                        
                        Text("Photo Library")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Analyzing your meal...")
                .font(.headline)
            
            Text(String(format: "%.0f%%", viewModel.analysisProgress * 100))
                .font(.title)
                .bold()
            
            ProgressView(value: viewModel.analysisProgress)
                .frame(width: 200)
            
            Text("Identifying foods and calculating nutrition...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Analysis Failed")
                .font(.headline)
            
            Text(viewModel.errorMessage ?? "Unable to analyze the image")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                viewModel.resetAnalysis()
            } label: {
                Text("Try Again")
                    .bold()
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top)
        }
    }
    
    // MARK: - Nutrition Summary Card
    
    private func nutritionSummaryCard(result: FoodDetectionResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Label("Nutrition Summary", systemImage: "chart.pie.fill")
                .font(.headline)
            
            Divider()
            
            // Summary
            HStack(spacing: 30) {
                // Calories
                VStack {
                    Text("\(Int(result.totalCalories))")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Macros
                HStack(spacing: 20) {
                    macroNutrientView(value: result.totalProtein, label: "Protein", color: .blue)
                    macroNutrientView(value: result.totalCarbs, label: "Carbs", color: .green)
                    macroNutrientView(value: result.totalFat, label: "Fat", color: .orange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Detected Foods Card
    
    private func detectedFoodsCard(result: FoodDetectionResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Label("Detected Foods", systemImage: "checklist")
                .font(.headline)
            
            Divider()
            
            // Food items
            ForEach(result.detectedFoods, id: \.name) { food in
                foodItemRow(food)
                
                if food.name != result.detectedFoods.last?.name {
                    Divider()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Nutritional Analysis Card
    
    private func nutritionalAnalysisCard(result: FoodDetectionResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Label("Nutritional Analysis", systemImage: "chart.bar.fill")
                .font(.headline)
            
            Divider()
            
            // Analysis content
            VStack(alignment: .leading, spacing: 16) {
                Text("Macronutrient Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Macro chart
                HStack(alignment: .bottom, spacing: 0) {
                    let totalCalories = max(result.totalCalories, 1) // Prevent division by zero
                    let proteinPercentage = min(result.totalProtein * 4 / totalCalories, 1.0)
                    let carbsPercentage = min(result.totalCarbs * 4 / totalCalories, 1.0)
                    let fatPercentage = min(result.totalFat * 9 / totalCalories, 1.0)
                    
                    // Protein bar
                    VStack {
                        Text("\(Int(proteinPercentage * 100))%")
                            .font(.caption)
                            .padding(.bottom, 5)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 40, height: 100 * proteinPercentage)
                        
                        Text("Protein")
                            .font(.caption)
                            .padding(.top, 5)
                    }
                    
                    // Carbs bar
                    VStack {
                        Text("\(Int(carbsPercentage * 100))%")
                            .font(.caption)
                            .padding(.bottom, 5)
                        
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 40, height: 100 * carbsPercentage)
                        
                        Text("Carbs")
                            .font(.caption)
                            .padding(.top, 5)
                    }
                    
                    // Fat bar
                    VStack {
                        Text("\(Int(fatPercentage * 100))%")
                            .font(.caption)
                            .padding(.bottom, 5)
                        
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: 40, height: 100 * fatPercentage)
                        
                        Text("Fat")
                            .font(.caption)
                            .padding(.top, 5)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                
                // Analysis text
                Text(macroAnalysisText(protein: result.totalProtein, carbs: result.totalCarbs, fat: result.totalFat))
                    .font(.callout)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Recommendations Card
    
    private func recommendationsCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Label("Recommendations", systemImage: "lightbulb.fill")
                .font(.headline)
            
            Divider()
            
            // Recommendations
            VStack(alignment: .leading, spacing: 10) {
                recommendationRow(
                    icon: "plus.circle.fill",
                    color: .green,
                    text: "Consider adding more vegetables to increase fiber intake."
                )
                
                recommendationRow(
                    icon: "minus.circle.fill",
                    color: .red,
                    text: "Try to reduce added sugars for better overall health."
                )
                
                recommendationRow(
                    icon: "arrow.triangle.2.circlepath",
                    color: .blue,
                    text: "Balance your meal with a mix of protein, complex carbs, and healthy fats."
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Action Buttons
    
    private func actionButtons() -> some View {
        HStack(spacing: 16) {
            Button {
                // Log meal action
            } label: {
                Label("Log Meal", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button {
                // Share meal analysis action
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func macroNutrientView(value: Double, label: String, color: Color) -> some View {
        VStack {
            Text("\(Int(value))g")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func foodItemRow(_ food: DetectedFood) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(food.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(Int(food.nutritionalInfo.calories)) cal")
                        .font(.subheadline)
                        .bold()
                }
                
                HStack {
                    Text(food.confidenceFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("P: \(Int(food.nutritionalInfo.protein))g  C: \(Int(food.nutritionalInfo.carbs))g  F: \(Int(food.nutritionalInfo.fat))g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    
    private func recommendationRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Methods
    
    private func confidenceColor(for confidence: Double) -> Color {
        if confidence > 0.8 {
            return .green
        } else if confidence > 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func macroAnalysisText(protein: Double, carbs: Double, fat: Double) -> String {
        let totalCalories = max(protein * 4 + carbs * 4 + fat * 9, 1) // Prevent division by zero
        let proteinPercentage = (protein * 4 / totalCalories) * 100
        let carbsPercentage = (carbs * 4 / totalCalories) * 100
        let fatPercentage = (fat * 9 / totalCalories) * 100
        
        var analysis = "This meal is "
        
        if proteinPercentage > 30 {
            analysis += "high in protein, "
        } else if proteinPercentage < 15 {
            analysis += "low in protein, "
        } else {
            analysis += "moderate in protein, "
        }
        
        if carbsPercentage > 60 {
            analysis += "high in carbohydrates, "
        } else if carbsPercentage < 30 {
            analysis += "low in carbohydrates, "
        } else {
            analysis += "moderate in carbohydrates, "
        }
        
        if fatPercentage > 40 {
            analysis += "and high in fat."
        } else if fatPercentage < 20 {
            analysis += "and low in fat."
        } else {
            analysis += "and moderate in fat."
        }
        
        // Add recommendation
        if proteinPercentage < 20 && totalCalories > 300 {
            analysis += " Consider adding a protein source to balance this meal."
        } else if carbsPercentage > 65 {
            analysis += " This meal is carb-heavy, which may cause rapid blood sugar changes."
        } else if fatPercentage > 40 {
            analysis += " The high fat content might slow digestion and keep you feeling full longer."
        }
        
        return analysis
    }
}

struct FoodImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No need to update the view controller
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: FoodImagePicker

        init(_ parent: FoodImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
} 
