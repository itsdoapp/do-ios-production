//
//  FridgeCameraView.swift
//  Do
//
//  Camera view for scanning fridge contents and identifying ingredients
//

import SwiftUI
import AVFoundation
import UIKit

struct FridgeCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = FoodCameraManager()
    @State private var capturedImage: UIImage?
    @State private var showingIngredients = false
    @State private var isAnalyzing = false
    @State private var detectedIngredients: [String] = []
    
    var body: some View {
        ZStack {
            // Camera preview
            if cameraManager.isSetup {
                ZStack {
                    CameraPreviewView(session: cameraManager.session)
                        .ignoresSafeArea()
                }
                
                // UI overlay
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Top bar
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Spacer()
                            
                            // Title
                            Text("Scan Your Fridge")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Spacer for balance
                            Circle()
                                .fill(.clear)
                                .frame(width: 44, height: 44)
                        }
                        .padding(.horizontal)
                        .padding(.top, geometry.safeAreaInsets.top + 50)
                        
                        Spacer()
                        
                        // Bottom controls
                        VStack(spacing: 20) {
                            if isAnalyzing {
                                AnalysisProgressView()
                            }
                            
                            HStack(spacing: 40) {
                                // Photo library button
                                ModernCameraButton(
                                    icon: "photo.on.rectangle",
                                    action: { cameraManager.showImagePicker = true }
                                )
                                
                                // Capture button
                                Button {
                                    cameraManager.capturePhoto()
                                } label: {
                                    ZStack {
                                        // Outer pulse ring
                                        Circle()
                                            .stroke(Color.brandOrange, lineWidth: 3)
                                            .frame(width: 80, height: 80)
                                        
                                        // Main button
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.brandOrange, Color("FF6B35")],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 70, height: 70)
                                            .shadow(color: Color.brandOrange.opacity(0.5), radius: 20)
                                        
                                        // Inner highlight
                                        Circle()
                                            .fill(Color.white.opacity(0.3))
                                            .frame(width: 50, height: 50)
                                    }
                                }
                                .disabled(isAnalyzing)
                                
                                // Spacer for balance
                                ModernCameraButton(
                                    icon: "photo.on.rectangle",
                                    action: { }
                                )
                                .opacity(0)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            } else {
                // Setup view
                VStack(spacing: 20) {
                    ProgressView()
                        .tint(Color.brandOrange)
                    Text("Initializing Camera...")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .background(Color.black)
        .onAppear {
            print("📸 [FridgeCamera] View appeared")
            Task {
                print("📸 [FridgeCamera] Setting up camera...")
                await MainActor.run {
                    cameraManager.setupCamera()
                }
            }
        }
        .onDisappear {
            Task {
                await MainActor.run {
                    cameraManager.session.stopRunning()
                }
            }
        }
        .onChange(of: cameraManager.capturedImage) { image in
            if let image = image {
                capturedImage = image
                analyzeFridge(image: image)
            }
        }
        .sheet(isPresented: $cameraManager.showImagePicker) {
            ImagePicker(image: Binding(
                get: { capturedImage },
                set: { newImage in
                    if let newImage = newImage {
                        capturedImage = newImage
                        analyzeFridge(image: newImage)
                    }
                }
            ))
        }
        .fullScreenCover(isPresented: $showingIngredients) {
            if !detectedIngredients.isEmpty {
                FridgeIngredientsView(
                    initialIngredients: detectedIngredients,
                    capturedImage: capturedImage
                )
            }
        }
    }
    
    private func analyzeFridge(image: UIImage) {
        isAnalyzing = true
        
        // Stop camera feed when analyzing
        Task { @MainActor in
            cameraManager.session.stopRunning()
            print("📸 [FridgeCamera] Stopped camera session for analysis")
        }
        
        Task {
            do {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    await MainActor.run {
                        isAnalyzing = false
                    }
                    return
                }
                let base64 = imageData.base64EncodedString()
                
                // Get current conversation ID for context
                let conversationId = GenieConversationManager.shared.currentConversationId ?? UUID().uuidString
                
                let response = try await GenieAPIService.shared.queryWithImage(
                    """
                    Identify all food items and ingredients visible in this fridge image. 
                    
                    Return ONLY a comma-separated list of specific ingredient names. 
                    For example: "chicken breast, tomatoes, lettuce, eggs, milk, cheese, carrots, onions"
                    
                    Requirements:
                    1. Only list items you can clearly see in the image
                    2. Use simple, clear ingredient names (e.g., "chicken breast" not "raw chicken breast")
                    3. Do not include quantities or amounts
                    4. Do not include any other text, just the comma-separated list
                    5. If you cannot clearly identify items, return fewer items rather than guessing
                    
                    Return format: ingredient1, ingredient2, ingredient3, ...
                    """,
                    imageBase64: base64,
                    sessionId: conversationId
                )
                
                await MainActor.run {
                    // Parse ingredients from response
                    let ingredients = parseIngredients(from: response.response)
                    print("📋 [FridgeCamera] Detected ingredients: \(ingredients)")
                    
                    detectedIngredients = ingredients
                    isAnalyzing = false
                    showingIngredients = true
                }
            } catch {
                print("❌ [FridgeCamera] Error analyzing fridge: \(error)")
                await MainActor.run {
                    isAnalyzing = false
                }
            }
        }
    }
    
    private func parseIngredients(from text: String) -> [String] {
        // Clean the text - remove markdown, extra whitespace, etc.
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common prefixes/suffixes
        let prefixes = ["Ingredients:", "I can see:", "The fridge contains:", "Detected ingredients:"]
        for prefix in prefixes {
            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Split by comma
        let items = cleaned.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Remove duplicates and clean up
        var uniqueItems: [String] = []
        var seen = Set<String>()
        
        for item in items {
            let lowercased = item.lowercased()
            if !seen.contains(lowercased) && item.count > 1 {
                seen.insert(lowercased)
                uniqueItems.append(item)
            }
        }
        
        return uniqueItems
    }
}


