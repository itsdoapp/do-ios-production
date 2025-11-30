//
//  BarcodeScannerView.swift
//  Do
//
//  Barcode scanning for food lookup
//

import SwiftUI
import AVFoundation
import UIKit
import Foundation

struct BarcodeScannerView: View {
    let mealType: FoodMealType
    let onFoodFound: (FoodEntry) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = BarcodeScannerManager()
    @State private var analysisResponse: GenieQueryResponse?
    @State private var showingAnalysis = false
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlue
                    .ignoresSafeArea()
                
                if scanner.isSetup {
                    // Camera preview with barcode overlay
                    CameraPreviewView(session: scanner.session)
                        .ignoresSafeArea()
                        .overlay(
                            // Scanning overlay
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.brandOrange, lineWidth: 3)
                                .frame(width: 250, height: 150)
                                .padding()
                        )
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Setting up barcode scanner...")
                            .foregroundColor(.gray)
                    }
                }
                
                VStack {
                    Spacer()
                    
                    // Bottom sheet with instructions
                    VStack(spacing: 16) {
                        Text("Position barcode within the frame")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("The barcode will be scanned automatically")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        if isSearching {
                            ProgressView()
                                .tint(.white)
                            Text("Looking up product...")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.8))
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            scanner.setupScanner()
        }
        .onChange(of: scanner.scannedCode) { code in
            if let code = code, !isSearching {
                lookupBarcode(code)
            }
        }
        .fullScreenCover(isPresented: $showingAnalysis, onDismiss: {
            // Reset scanner when analysis view is dismissed
            scanner.reset()
            analysisResponse = nil
        }) {
            if let analysis = analysisResponse {
                BarcodeAnalysisView(
                    barcode: scanner.scannedCode ?? "",
                    analysis: analysis,
                    mealType: mealType,
                    onSave: {
                        onFoodFound(FoodEntry(
                            id: UUID().uuidString,
                            userId: CurrentUserService.shared.userID ?? "",
                            name: "",
                            mealType: mealType,
                            calories: 0,
                            protein: 0,
                            carbs: 0,
                            fat: 0,
                            servingSize: nil,
                            notes: nil,
                            timestamp: Date(),
                            source: .barcode
                        ))
                        dismiss()
                    }
                )
            }
        }
    }
    
    private func lookupBarcode(_ code: String) {
        guard !isSearching else { return }
        isSearching = true
        
        Task {
            do {
                // Use BarcodeService to lookup product
                let barcodeService = BarcodeService.shared
                let product = try await barcodeService.lookupBarcode(code)
                
                // Find alternatives
                let alternatives = try await barcodeService.findAlternatives(for: product, limit: 5)
                
                // Analyze product
                let analysis = barcodeService.analyzeProduct(product, alternatives: alternatives)
                
                // Convert to GenieQueryResponse format for compatibility with existing view
                let response = createGenieResponse(from: product, alternatives: alternatives, analysis: analysis)
                
                await MainActor.run {
                    analysisResponse = response
                    isSearching = false
                    showingAnalysis = true
                }
            } catch {
                print("❌ [Barcode] Error: \(error)")
                await MainActor.run {
                    isSearching = false
                    // Show error to user
                    // TODO: Add error state UI
                }
            }
        }
    }
    
    private func createGenieResponse(from product: BarcodeProduct, alternatives: [BarcodeProduct], analysis: ProductAnalysis) -> GenieQueryResponse {
        // Convert alternatives to the format expected by BarcodeAnalysisView
        let alternativeActions = alternatives.map { alt -> [String: Any] in
            var dict: [String: Any] = [
                "name": alt.productName ?? "Unknown Product",
                "calories": alt.nutrition?.calories ?? 0,
                "protein": alt.nutrition?.protein ?? 0,
                "carbs": alt.nutrition?.carbs ?? 0,
                "fat": alt.nutrition?.fat ?? 0
            ]
            if let brand = alt.brand {
                dict["brand"] = brand
            }
            // Add reason based on comparison
            if let currentCalories = product.nutrition?.calories,
               let altCalories = alt.nutrition?.calories,
               altCalories < currentCalories {
                dict["reason"] = "Lower calories (\(Int(altCalories)) vs \(Int(currentCalories)))"
                dict["savings"] = "Saves \(Int(currentCalories - altCalories)) calories"
            }
            return dict
        }
        
        // Build nutrition_data action - need to convert nested structures properly
        let macrosDict: [String: Any] = [
            "protein": product.nutrition?.protein ?? product.nutritionPerServing?.protein ?? 0,
            "carbs": product.nutrition?.carbs ?? product.nutritionPerServing?.carbs ?? 0,
            "fat": product.nutrition?.fat ?? product.nutritionPerServing?.fat ?? 0
        ]
        
        let nutritionData: [String: Any] = [
            "calories": product.nutrition?.calories ?? product.nutritionPerServing?.calories ?? 0,
            "macros": macrosDict,
            "foods": [product.productName ?? "Scanned Product"],
            "servingSize": product.servingSize ?? "100g",
            "brand": product.brand ?? "",
            "productName": product.productName ?? "Scanned Product",
            "barcode": product.barcode,
            "insights": analysis.insights,
            "alternatives": alternativeActions,
            "recommendations": analysis.recommendations,
            "confidence": analysis.isHealthy ? 0.9 : 0.7
        ]
        
        // Convert to AnyCodable format
        var actionData: [String: AnyCodable] = [:]
        for (key, value) in nutritionData {
            actionData[key] = AnyCodable(value)
        }
        
        let action = GenieAction(
            type: "nutrition_data",
            data: actionData
        )
        
        return GenieQueryResponse(
            response: "Product found: \(product.productName ?? "Unknown")",
            tokensUsed: 0,
            tokensRemaining: 0,
            tier: 1,
            handler: nil,
            balanceWarning: nil,
            contextUsed: nil,
            thinking: nil,
            structuredAnalysis: nil,
            actions: [action],
            title: product.productName
        )
    }
    
}

// MARK: - Barcode Scanner Manager

@MainActor
class BarcodeScannerManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isSetup = false
    @Published var scannedCode: String?
    
    private let metadataOutput = AVCaptureMetadataOutput()
    
    override init() {
        super.init()
    }
    
    func setupScanner() {
        checkPermission { [weak self] granted in
            guard granted, let self = self else { return }
            
            self.session.sessionPreset = .high
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("❌ Camera not available")
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                if self.session.canAddOutput(self.metadataOutput) {
                    self.session.addOutput(self.metadataOutput)
                    self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                    self.metadataOutput.metadataObjectTypes = [
                        .ean8, .ean13, .pdf417, .qr, .upce, .code128
                    ]
                }
                
                DispatchQueue.global(qos: .userInitiated).async {
                    self.session.startRunning()
                }
                
                DispatchQueue.main.async {
                    self.isSetup = true
                }
            } catch {
                print("❌ Scanner setup error: \(error)")
            }
        }
    }
    
    private func checkPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }
}

extension BarcodeScannerManager: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadataObject.stringValue else {
            return
        }
        
        // Only scan once per code
        if scannedCode != code {
            scannedCode = code
            // Don't stop the session - let it continue for potential re-scans
        }
    }
    
    func reset() {
        scannedCode = nil
    }
}


