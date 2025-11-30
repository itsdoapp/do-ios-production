//
//  FoodCameraView.swift
//  Do
//
//  Beautiful camera view for food snapping with Genie AI analysis
//

import SwiftUI
import AVFoundation
import UIKit
import Vision

struct FoodCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = FoodCameraManager()
    @State private var capturedImage: UIImage?
    @State private var showingAnalysis = false
    @State private var isAnalyzing = false
    @State private var analysisResult: GenieQueryResponse?
    @State private var selectedMealType: FoodMealType = .breakfast
    @State private var detectedRegions: [DetectionRegion] = []
    @State private var isDetecting = false
    @State private var scanAnimationProgress: CGFloat = 0
    @State private var showingUpsell = false
    @State private var upsellData: UpsellData?
    @State private var errorMessage: String?
    @State private var isDismissingAnalysis = false
    
    var onFoodLogged: (() -> Void)?
    
    struct DetectionRegion: Identifiable {
        let id = UUID()
        let rect: CGRect
        let label: String
        let confidence: Float
    }
    
    var body: some View {
        ZStack {
            // Camera preview with detection overlay
            if cameraManager.isSetup {
                ZStack {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
                    
                    // Real-time detection overlay - only show when detecting
                    if isDetecting && !isAnalyzing {
                        DetectionOverlayView(
                            regions: detectedRegions,
                            scanProgress: scanAnimationProgress,
                            isDetecting: isDetecting
                        )
                    }
                }
                
                // Futuristic UI overlay - properly positioned with safe area handling
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Bottom controls with modern design
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
                            
                            // Capture button with pulse animation
                            Button {
                                cameraManager.capturePhoto()
                            } label: {
                                ZStack {
                                    // Outer pulse ring
                                    Circle()
                                        .stroke(Color.brandOrange, lineWidth: 3)
                                        .frame(width: 80, height: 80)
                                        .scaleEffect(scanAnimationProgress > 0 ? 1.2 : 1.0)
                                        .opacity(scanAnimationProgress > 0 ? 0 : 0.6)
                                    
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
                            
                            // Barcode scanner button
                            ModernCameraButton(
                                icon: "barcode.viewfinder",
                                action: { cameraManager.showBarcodeScanner = true }
                            )
                        }
                    }
                    .padding(.bottom, 40)
                }
                .overlay(alignment: .topLeading) {
                    // Dismiss button - positioned consistently at top-left with safe area
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
                        .padding(.leading, 20)
                        .padding(.top, 16)
                        
                        Spacer()
                        
                        // AI Status indicator
                        if isDetecting && !isAnalyzing {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.brandOrange)
                                    .frame(width: 8, height: 8)
                                    .opacity(scanAnimationProgress > 0 ? 1 : 0.3)
                                    .animation(
                                        Animation.easeInOut(duration: 0.8)
                                            .repeatForever(autoreverses: true),
                                        value: scanAnimationProgress
                                    )
                                
                                Text("AI Detecting...")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.trailing, 20)
                            .padding(.top, 16)
                        }
                    }
                }
            } else {
                // Setup view
                VStack(spacing: 20) {
                    ProgressView()
                        .tint(Color.brandOrange)
                    Text("Initializing AI Camera...")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .onAppear {
            print("📸 [FoodCamera] View appeared")
            // Setup camera when view appears
            Task {
                print("📸 [FoodCamera] Setting up camera...")
                await MainActor.run {
            cameraManager.setupCamera()
                }
                // Wait a bit for camera to initialize
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                print("📸 [FoodCamera] Starting real-time detection")
                startRealTimeDetection()
            }
        }
        .onDisappear {
            // Stop camera when view disappears
            print("📸 [FoodCamera] View disappearing")
            Task {
                await MainActor.run {
                    cameraManager.session.stopRunning()
                }
            }
        }
        .onChange(of: cameraManager.capturedImage) { image in
            if let image = image {
                capturedImage = image
                analyzeFood(image: image)
            }
        }
        .sheet(isPresented: $cameraManager.showImagePicker) {
            ImagePicker(image: Binding(
                get: { capturedImage },
                set: { newImage in
                    if let newImage = newImage {
                        capturedImage = newImage
                        analyzeFood(image: newImage)
                    }
                }
            ))
        }
        .sheet(isPresented: $showingAnalysis, onDismiss: {
            // Restart camera when returning from analysis
            Task { @MainActor in
                // Reset analyzing state
                isAnalyzing = false
                capturedImage = nil
                analysisResult = nil
                isDismissingAnalysis = false
                
                if cameraManager.isSetup {
                    cameraManager.session.startRunning()
                    print("📸 [FoodCamera] Restarted camera session after analysis")
                    // Restart detection after a brief delay
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    startRealTimeDetection()
                }
            }
        }) {
            if let analysis = analysisResult {
                EnhancedFoodAnalysisView(
                    image: capturedImage,
                    analysis: analysis,
                    mealType: selectedMealType,
                    onSave: {
                        onFoodLogged?()
                        dismiss()
                    }
                )
            }
        }
        .sheet(isPresented: $cameraManager.showBarcodeScanner) {
            BarcodeScannerView(
                mealType: selectedMealType,
                onFoodFound: { entry in
                    dismiss()
                    onFoodLogged?()
                }
            )
        }
        .overlay {
            if showingUpsell, let upsell = upsellData {
                ZStack {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Don't dismiss on background tap - user needs to see upsell
                        }
                    
                    VStack {
                        Spacer()
                        
                        SmartTokenUpsellView(
                            required: upsell.required,
                            balance: upsell.balance,
                            queryType: upsell.queryType,
                            tier: upsell.tier,
                            hasSubscription: upsell.upsell.hasSubscription,
                            recommendation: {
                                // Normalize recommendation: backend uses "token_pack" or "subscription"
                                if let rec = upsell.upsell.recommendation {
                                    return rec == "subscription" ? "subscription" : "token_pack"
                                } else {
                                    // Default based on hasSubscription
                                    return upsell.upsell.hasSubscription ? "token_pack" : "subscription"
                                }
                            }(),
                            tokenPacks: upsell.upsell.tokenPacks.map { pack in
                                TokenPack(
                                    id: pack.id,
                                    name: pack.name,
                                    tokens: pack.tokens,
                                    bonus: pack.bonus,
                                    price: pack.price,
                                    popular: pack.popular
                                )
                            },
                            subscriptions: upsell.upsell.subscriptions.map { sub in
                                UpsellSubscriptionPlan(
                                    id: sub.id,
                                    name: sub.name,
                                    tokens: sub.tokens,
                                    price: sub.price,
                                    perDay: sub.perDay
                                )
                            }
                        )
                        .onDisappear {
                            // When upsell is dismissed after purchase, refresh balance
                            Task {
                                // Wait a bit for webhook to process
                                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                                // Balance will be updated via notification, but we can also reload here
                                print("💰 [Food] Upsell dismissed - balance should refresh via notification")
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .padding()
                        .shadow(radius: 20)
                        
                        Spacer()
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut, value: showingUpsell)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
        .onChange(of: showingUpsell) { newValue in
            print("💰 [Food] onChange - showingUpsell changed to: \(newValue)")
            print("💰 [Food] onChange - upsellData is: \(upsellData != nil ? "present" : "nil")")
        }
        .onChange(of: upsellData) { newValue in
            print("💰 [Food] onChange - upsellData changed: \(newValue != nil ? "present" : "nil")")
        }
        .task {
            // Listen for token purchase notifications to refresh balance
            for await _ in NotificationCenter.default.notifications(named: NSNotification.Name("TokensPurchased")) {
                print("💰 [Food] TokensPurchased notification - dismissing upsell and refreshing")
                await MainActor.run {
                    showingUpsell = false
                    upsellData = nil
                }
                // Balance will refresh via webhook, but we can also reload if needed
            }
        }
        .task {
            // Listen for subscription updates
            for await _ in NotificationCenter.default.notifications(named: NSNotification.Name("SubscriptionUpdated")) {
                print("💰 [Food] SubscriptionUpdated notification - dismissing upsell")
                await MainActor.run {
                    showingUpsell = false
                    upsellData = nil
                }
            }
        }
    }
    
    private func startRealTimeDetection() {
        guard cameraManager.isSetup else { return }
        
        // Start continuous detection
        Task {
            // Start with scanning animation
            await MainActor.run {
                isDetecting = true
                scanAnimationProgress = 0.0
                // Start continuous scanning animation
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    scanAnimationProgress = 1.0
                }
            }
        }
    }
    
    private func analyzeFood(image: UIImage) {
        isAnalyzing = true
        isDetecting = false
        
        // Stop camera feed when analyzing to avoid confusion
        Task { @MainActor in
            cameraManager.session.stopRunning()
            print("📸 [FoodCamera] Stopped camera session for analysis")
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
                    Analyze this food image and return a nutrition_data action with the following structure:
                    {
                      "type": "nutrition_data",
                      "data": {
                        "calories": <number>,
                        "macros": {
                          "protein": <number in grams>,
                          "carbs": <number in grams>,
                          "fat": <number in grams>
                        },
                        "foods": ["<specific food item 1>", "<specific food item 2>", ...],
                        "servingSize": "<estimated serving size>",
                        "analysis": "<detailed analysis text>",
                        "insights": ["<insight 1>", "<insight 2>", ...],
                        "confidence": <0.0-1.0>
                      }
                    }
                    
                    CRITICAL REQUIREMENTS:
                    1. You MUST return a nutrition_data action (not just text).
                    2. The "foods" array MUST contain the specific food items identified in the image (e.g., ["grapes"], ["chicken breast", "rice"], ["apple", "banana"]).
                    3. Each food item in the "foods" array should be a simple, clear name (e.g., "grapes", not "bunch of grapes").
                    4. PORTION SIZE ESTIMATION (CRITICAL):
                       - Estimate the portion size by analyzing visual cues in the image:
                         * Compare food size to common reference objects (plate size, utensils, hand size, etc.)
                         * Estimate weight/volume when possible (e.g., "150g", "1.5 cups", "6oz")
                         * Use multipliers for standard servings (e.g., "2x standard serving", "0.75x serving")
                         * For multiple items, estimate each separately (e.g., "1 large chicken breast (~200g)", "1 cup rice")
                       - The "servingSize" field should be descriptive and specific (e.g., "1.5 cups rice (~300g)", "1 large chicken breast (~200g)", "2 medium apples (~300g)")
                       - Base your calorie and macro estimates on the ACTUAL portion size visible, not standard serving sizes
                       - If you see multiple portions, estimate the total (e.g., "2 servings" or "~400g total")
                    5. CALORIE ESTIMATION:
                       - Calculate calories based on the ESTIMATED PORTION SIZE, not standard serving sizes
                       - Use the portion size multiplier to adjust calories (e.g., if standard serving is 100g at 200 cal, and you see 150g, estimate 300 cal)
                       - For multiple food items, sum the calories from each item based on their estimated portions
                    6. Include a confidence score (0.0-1.0) based on how certain you are about the analysis and portion estimation.
                    7. The "analysis" field should explain what you see, the estimated portion sizes, and how you calculated the nutrition values.
                    8. The "insights" array should contain 2-5 nutritional insights or recommendations based on the actual portions.
                    
                    EXAMPLE:
                    If you see a large chicken breast that appears to be 1.5x a standard serving:
                    - servingSize: "1 large chicken breast (~225g, ~1.5x standard serving)"
                    - calories: 330 (220 cal per 150g standard × 1.5)
                    - protein: 67.5g (45g per standard × 1.5)
                    """,
                    imageBase64: base64,
                    sessionId: conversationId
                )
                
                await MainActor.run {
                    // Log full response for debugging
                    print("📋 [FoodCamera] ========== FULL AGENT RESPONSE ==========")
                    print("📋 [FoodCamera] Response text: \(response.response)")
                    print("📋 [FoodCamera] Actions count: \(response.actions?.count ?? 0)")
                    if let actions = response.actions {
                        for (index, action) in actions.enumerated() {
                            print("📋 [FoodCamera] Action \(index + 1):")
                            print("📋 [FoodCamera]   Type: \(action.type)")
                            print("📋 [FoodCamera]   Data keys: \(action.data.keys.sorted())")
                            for (key, value) in action.data {
                                if let arrayValue = value.arrayValue {
                                    print("📋 [FoodCamera]   \(key): [Array with \(arrayValue.count) items]")
                                    for (idx, item) in arrayValue.enumerated() {
                                        print("📋 [FoodCamera]     [\(idx)]: \(item)")
                                    }
                                } else if let dictValue = value.dictValue {
                                    print("📋 [FoodCamera]   \(key): [Dictionary with \(dictValue.count) keys]")
                                    for (dictKey, dictVal) in dictValue {
                                        print("📋 [FoodCamera]     \(dictKey): \(dictVal)")
                                    }
                                } else {
                                    print("📋 [FoodCamera]   \(key): \(value)")
                                }
                            }
                        }
                    }
                    print("📋 [FoodCamera] ==========================================")
                    
                    analysisResult = response
                    isAnalyzing = false
                    // Camera already stopped, show analysis view
                    showingAnalysis = true
                }
            } catch let error as GenieError {
                print("❌ [Food] GenieError: \(error)")
                await MainActor.run {
                    isAnalyzing = false
                    
                    // Handle insufficient tokens with upsell
                    if case .insufficientTokens(let data) = error {
                        print("💰 [Food] Insufficient tokens - showing upsell")
                        print("💰 [Food] Upsell data: required=\(data.required), balance=\(data.balance)")
                        print("💰 [Food] Current state - showingAnalysis: \(showingAnalysis), showingUpsell: \(showingUpsell)")
                        
                        // Ensure analysis sheet is dismissed first
                        showingAnalysis = false
                        analysisResult = nil
                        capturedImage = nil
                        isDismissingAnalysis = false
                        
                        // Store upsell data FIRST
                        upsellData = data
                        print("💰 [Food] Upsell data stored: \(upsellData != nil)")
                        
                        // Show upsell - use async to ensure it happens after state updates
                        // The view should stay open so user can get tokens and retry
                        print("💰 [Food] Preparing to show upsell")
                        
                        // Use asyncAfter to ensure it happens on the next run loop
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                            print("💰 [Food] DispatchQueue - Setting showingUpsell = true")
                            self.showingUpsell = true
                            print("💰 [Food] DispatchQueue - showingUpsell is now: \(self.showingUpsell)")
                            print("💰 [Food] DispatchQueue - upsellData is: \(self.upsellData != nil ? "present" : "nil")")
                        }
                        
                        // Don't set errorMessage - we're showing the upsell UI instead
                        // Don't call dismiss() - keep the camera view open
                    } else {
                        // Handle other errors - ensure analysis sheet is dismissed
                        showingAnalysis = false
                        analysisResult = nil
                        capturedImage = nil
                        
                        switch error {
                        case .serverError(let code):
                            errorMessage = "Server error (\(code)). Please try again."
                        case .invalidRequest(let message):
                            errorMessage = message
                        case .notAuthenticated:
                            errorMessage = "Authentication failed. Please sign out and sign in again."
                        case .invalidResponse:
                            errorMessage = "Invalid response from server. Please try again."
                        case .invalidURL:
                            errorMessage = "Configuration error. Please contact support."
                        case .insufficientTokens:
                            errorMessage = "You're out of tokens! Get more to continue."
                        }
                    }
                }
            } catch {
                print("❌ [Food] Unexpected error: \(error)")
                await MainActor.run {
                    isAnalyzing = false
                    showingAnalysis = false
                    analysisResult = nil
                    capturedImage = nil
                    errorMessage = "Failed to analyze food: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewContainerView {
        let containerView = CameraPreviewContainerView()
        containerView.session = session
        context.coordinator.containerView = containerView
        return containerView
    }
    
    func updateUIView(_ uiView: CameraPreviewContainerView, context: Context) {
        if uiView.session != session {
            uiView.session = session
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var containerView: CameraPreviewContainerView?
    }
}

class CameraPreviewContainerView: UIView {
    var session: AVCaptureSession? {
        didSet {
            setupPreviewLayer()
        }
    }
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    private func setupPreviewLayer() {
        guard let session = session else { return }
        
        // Remove old preview layer
        previewLayer?.removeFromSuperlayer()
        
        // Create new preview layer
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.videoOrientation = .portrait
        layer.frame = bounds
        
        self.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        
        print("📸 [CameraPreview] Preview layer setup, frame: \(bounds)")
    }
}

// MARK: - Detection Overlay View

struct DetectionOverlayView: View {
    let regions: [FoodCameraView.DetectionRegion]
    let scanProgress: CGFloat
    let isDetecting: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Scanning line animation - full width across screen, goes from top to bottom
                if isDetecting {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.brandOrange.opacity(0),
                                    Color.brandOrange.opacity(0.8),
                                    Color.brandOrange.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width, height: 4)
                        .offset(y: geometry.size.height * scanProgress)
                        .animation(
                            Animation.linear(duration: 2.0)
                                .repeatForever(autoreverses: false),
                            value: scanProgress
                        )
                }
            }
        }
    }
}

struct DetectionBoxView: View {
    let region: FoodCameraView.DetectionRegion
    let geometry: GeometryProxy
    
    var body: some View {
        // Vision framework uses normalized coordinates (0.0-1.0) with origin at bottom-left
        // SwiftUI uses top-left origin, so we need to flip Y
        let normalizedRect = region.rect
        let rect = CGRect(
            x: normalizedRect.minX * geometry.size.width,
            y: (1.0 - normalizedRect.maxY) * geometry.size.height, // Flip Y: Vision bottom-left -> SwiftUI top-left
            width: normalizedRect.width * geometry.size.width,
            height: normalizedRect.height * geometry.size.height
        )
        
        // Only render if rect is valid and visible
        guard rect.width > 10 && rect.height > 10,
              rect.minX >= 0 && rect.minY >= 0,
              rect.maxX <= geometry.size.width && rect.maxY <= geometry.size.height else {
            return AnyView(EmptyView())
        }
        
        // Make the box more square by using the larger dimension
        let maxDimension = max(rect.width, rect.height)
        let squareSize = maxDimension
        let squareRect = CGRect(
            x: rect.midX - squareSize / 2,
            y: rect.midY - squareSize / 2,
            width: squareSize,
            height: squareSize
        )
        
        // Ensure the square box stays within bounds
        let clampedRect = CGRect(
            x: max(0, min(squareRect.minX, geometry.size.width - squareSize)),
            y: max(0, min(squareRect.minY, geometry.size.height - squareSize)),
            width: min(squareSize, geometry.size.width),
            height: min(squareSize, geometry.size.height)
        )
        
        return AnyView(
            ZStack {
                // Main border around detected region - square box
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.brandOrange, lineWidth: 4)
                    .frame(width: clampedRect.width, height: clampedRect.height)
                    .position(x: clampedRect.midX, y: clampedRect.midY)
                    .shadow(color: Color.brandOrange.opacity(0.9), radius: 12)
                
                // Corner brackets for emphasis - larger for square box
                Path { path in
                    let cornerLength: CGFloat = 40
                    let padding: CGFloat = 4
                    
                    // Top-left corner
                    path.move(to: CGPoint(x: clampedRect.minX + padding, y: clampedRect.minY + cornerLength + padding))
                    path.addLine(to: CGPoint(x: clampedRect.minX + padding, y: clampedRect.minY + padding))
                    path.addLine(to: CGPoint(x: clampedRect.minX + cornerLength + padding, y: clampedRect.minY + padding))
                    
                    // Top-right corner
                    path.move(to: CGPoint(x: clampedRect.maxX - cornerLength - padding, y: clampedRect.minY + padding))
                    path.addLine(to: CGPoint(x: clampedRect.maxX - padding, y: clampedRect.minY + padding))
                    path.addLine(to: CGPoint(x: clampedRect.maxX - padding, y: clampedRect.minY + cornerLength + padding))
                    
                    // Bottom-right corner
                    path.move(to: CGPoint(x: clampedRect.maxX - padding, y: clampedRect.maxY - cornerLength - padding))
                    path.addLine(to: CGPoint(x: clampedRect.maxX - padding, y: clampedRect.maxY - padding))
                    path.addLine(to: CGPoint(x: clampedRect.maxX - cornerLength - padding, y: clampedRect.maxY - padding))
                    
                    // Bottom-left corner
                    path.move(to: CGPoint(x: clampedRect.minX + cornerLength + padding, y: clampedRect.maxY - padding))
                    path.addLine(to: CGPoint(x: clampedRect.minX + padding, y: clampedRect.maxY - padding))
                    path.addLine(to: CGPoint(x: clampedRect.minX + padding, y: clampedRect.maxY - cornerLength - padding))
                }
                .stroke(Color.brandOrange, lineWidth: 5)
                .shadow(color: Color.brandOrange.opacity(0.9), radius: 12)
                
                // Label badge at top of detection - positioned better
                if clampedRect.minY > 60 { // Only show label if there's space above
                    VStack {
                        HStack {
                            Text(region.label)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.brandOrange)
                                        .shadow(color: .black.opacity(0.5), radius: 8)
                                )
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    .offset(x: clampedRect.minX, y: clampedRect.minY - 50)
                }
            }
        )
    }
}

// MARK: - Modern Camera Button

struct ModernCameraButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Analysis Progress View

struct AnalysisProgressView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Orbiting particles
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(Color.brandOrange)
                        .frame(width: 6, height: 6)
                        .offset(x: 30)
                        .rotationEffect(.degrees(rotation + Double(index) * 45))
                }
                
                // Center pulse
                Circle()
                    .fill(Color.brandOrange.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .scaleEffect(1.0 + sin(rotation * .pi / 180) * 0.2)
            }
            
            Text("Analyzing with Genie AI...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Camera Manager

@MainActor
class FoodCameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isSetup = false
    @Published var capturedImage: UIImage?
    @Published var showImagePicker = false
    @Published var showBarcodeScanner = false
    
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var currentFrame: CVPixelBuffer?
    
    override init() {
        super.init()
    }
    
    func setupCamera() {
        print("📸 [FoodCamera] Starting camera setup...")
        checkPermission { [weak self] granted in
            guard granted, let self = self else {
                print("❌ [FoodCamera] Camera permission denied")
                return
            }
            
            print("📸 [FoodCamera] Permission granted, configuring camera...")
            
            // Configure session on main thread
            DispatchQueue.main.async {
            self.session.sessionPreset = .photo
                
                // Remove existing inputs/outputs
                self.session.beginConfiguration()
                
                // Remove existing inputs
                for input in self.session.inputs {
                    self.session.removeInput(input)
                }
                
                // Remove existing outputs
                for output in self.session.outputs {
                    self.session.removeOutput(output)
                }
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    print("❌ [FoodCamera] Camera not available")
                    self.session.commitConfiguration()
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                        print("✅ [FoodCamera] Added camera input")
                }
                
                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                        print("✅ [FoodCamera] Added photo output")
                    }
                    
                    // Setup video output for real-time detection
                    self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
                    self.videoOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    
                    if self.session.canAddOutput(self.videoOutput) {
                        self.session.addOutput(self.videoOutput)
                        print("✅ [FoodCamera] Added video output")
                    }
                    
                    self.session.commitConfiguration()
                    print("✅ [FoodCamera] Session configuration committed")
                    
                    // Update UI on main thread first
                    self.isSetup = true
                    print("✅ [FoodCamera] Camera setup complete, isSetup = true")
                    
                    // Start session on background thread AFTER configuration is committed
                    DispatchQueue.global(qos: .userInitiated).async {
                        // Small delay to ensure configuration is fully committed
                        Thread.sleep(forTimeInterval: 0.1)
                        
                        if !self.session.isRunning {
                            print("📸 [FoodCamera] Starting camera session...")
                            self.session.startRunning()
                            print("✅ [FoodCamera] Camera session started")
                        }
                    }
                } catch {
                    print("❌ [FoodCamera] Camera setup error: \(error)")
                    self.session.commitConfiguration()
                }
            }
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
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

extension FoodCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("❌ Failed to capture image")
            return
        }
        
        capturedImage = image
    }
}

extension FoodCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        currentFrame = pixelBuffer
    }
    
    func getCurrentFrame() async -> CVPixelBuffer? {
        return currentFrame
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}








