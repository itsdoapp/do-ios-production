//
//  EquipmentCameraView.swift
//  Do
//
//  Full-screen camera view for equipment scanning
//

import SwiftUI
import AVFoundation
import UIKit
import Vision

struct EquipmentCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = EquipmentCameraManager()
    @StateObject private var visionService = GenieVisionService.shared
    @State private var capturedImage: UIImage?
    @State private var analysisResult: GenieQueryResponse?
    @State private var showingAnalysis = false
    @State private var isAnalyzing = false
    @State private var detectedRegions: [DetectionRegion] = []
    @State private var isDetecting = false
    @State private var scanAnimationProgress: CGFloat = 0
    
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
                        .ignoresSafeArea(.all, edges: .bottom)
                    
                    // Real-time detection overlay - only show when detecting
                    if isDetecting && !isAnalyzing {
                        EquipmentDetectionOverlayView(
                            regions: detectedRegions,
                            scanProgress: scanAnimationProgress,
                            isDetecting: isDetecting
                        )
                    }
                }
                
                // Futuristic UI overlay
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Top bar with glassmorphism - positioned below safe area
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
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, geometry.safeAreaInsets.top + 50)
                    
                    Spacer()
                    
                    // Bottom controls
                    VStack(spacing: 20) {
                        // Capture button
                        Button(action: {
                            print("📸 [Equipment] Capture button tapped")
                            cameraManager.capturePhoto()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 72, height: 72)
                                
                                Circle()
                                    .stroke(Color.brandOrange, lineWidth: 4)
                                    .frame(width: 72, height: 72)
                                
                                Circle()
                                    .fill(Color.brandOrange)
                                    .frame(width: 64, height: 64)
                            }
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)
                        
                        if isAnalyzing {
                            AnalysisProgressView()
                                .frame(height: 100)
                        }
                    }
                    .padding(.bottom, 50)
                    }
                }
            } else {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .tint(Color.brandOrange)
                        .scaleEffect(1.5)
                    
                    Text("Setting up camera...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            print("📸 [EquipmentCamera] View appeared")
            // Setup camera when view appears
            Task {
                print("📸 [EquipmentCamera] Setting up camera...")
                await MainActor.run {
                    cameraManager.setupCamera()
                }
                // Wait a bit for camera to initialize
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                print("📸 [EquipmentCamera] Starting real-time detection")
                startRealTimeDetection()
            }
        }
        .onDisappear {
            // Stop camera when view disappears
            Task {
                await MainActor.run {
                    cameraManager.session.stopRunning()
                }
            }
        }
        .onChange(of: cameraManager.capturedImage) { image in
            if let image = image {
                capturedImage = image
                analyzeEquipment(image: image)
            }
        }
        .fullScreenCover(isPresented: $showingAnalysis) {
            if let analysis = analysisResult, let image = capturedImage {
                EquipmentAnalysisView(
                    image: image,
                    analysis: analysis,
                    onSave: {
                        dismiss()
                    }
                )
            }
        }
    }
    
    private func startRealTimeDetection() {
        guard cameraManager.isSetup else { return }
        
        // Start scanning animation only (no rectangle detection)
        Task {
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
    
    private func analyzeEquipment(image: UIImage) {
        isAnalyzing = true
        isDetecting = false
        
        // Stop camera feed when analyzing to avoid confusion
        Task { @MainActor in
            cameraManager.session.stopRunning()
            print("📸 [EquipmentCamera] Stopped camera session for analysis")
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
                    Analyze this image and identify workout equipment OR items that can be used for workouts. Return an equipment_identified action with the following structure:
                    {
                      "type": "equipment_identified",
                      "data": {
                        "equipment": [
                          {
                            "name": "<specific equipment/item name>",
                            "description": "<what it's used for or how to use it for workouts>",
                            "category": "<equipment category>",
                            "muscleGroups": ["<muscle 1>", "<muscle 2>", ...],
                            "suggestedExercises": ["<exercise 1>", "<exercise 2>", ...],
                            "confidence": <0.0-1.0>,
                            "relevanceScore": <0.0-1.0>,
                            "isOfficialEquipment": <true/false>
                          },
                          ...
                        ],
                        "primaryEquipment": {
                          "name": "<most likely item user is asking about>",
                          "description": "<what it's used for or how to use it for workouts>",
                          "category": "<equipment category>",
                          "muscleGroups": ["<muscle 1>", "<muscle 2>", ...],
                          "suggestedExercises": ["<exercise 1>", "<exercise 2>", ...],
                          "confidence": <0.0-1.0>,
                          "isOfficialEquipment": <true/false>
                        }
                      }
                    }
                    
                    CRITICAL REQUIREMENTS:
                    1. Identify ALL visible workout equipment OR items that can be used for workouts (gym equipment, benches, walls, floors, open spaces, etc.).
                    2. If the image shows something that's NOT official gym equipment, STILL identify it and provide workout suggestions.
                    3. For non-official equipment, set "isOfficialEquipment": false and explain how to use it for workouts in the description.
                    4. The "equipment" array should contain ALL identified items, sorted by relevanceScore (highest first).
                    5. The "primaryEquipment" should be the item the user is most likely asking about (highest relevance). NEVER return null for primaryEquipment - always identify at least one workout-usable item based on what's actually visible in the image.
                    6. If no traditional equipment is found, identify the most prominent workout-usable item visible in the image and provide workout suggestions. Do NOT default to any specific item - analyze what's actually shown.
                    7. Relevance score (0.0-1.0) should be based on:
                       - How prominently the item appears in the image
                       - How likely it is the user wants to know about this item
                       - How useful it is for workouts
                    8. Each item should have:
                       - Specific name based on what's actually visible (e.g., "Smith Machine", "Cable Machine", "Dumbbells", "Bench", "Wall", "Floor Space", etc.)
                       - Description explaining what it is and how to use it for workouts
                       - Category (e.g., "Machine", "Free Weights", "Cardio Equipment", "Bodyweight Training", "Improvised Equipment")
                       - Muscle groups targeted based on the actual item
                       - 3-5 specific exercises that can be performed with the actual item shown
                       - Confidence score (0.0-1.0)
                       - isOfficialEquipment (true for gym equipment, false for improvised items)
                    9. You MUST return an equipment_identified action with at least one item in primaryEquipment. Do NOT return null or empty arrays.
                    10. Analyze the image carefully and identify what's actually visible. Do NOT assume or default to any specific equipment - only identify what you can see.
                    """,
                    imageBase64: base64,
                    sessionId: conversationId
                )
                
                await MainActor.run {
                    // Log full response for debugging
                    print("📋 [EquipmentCamera] ========== FULL AGENT RESPONSE ==========")
                    print("📋 [EquipmentCamera] Response text: \(response.response)")
                    print("📋 [EquipmentCamera] Actions count: \(response.actions?.count ?? 0)")
                    if let actions = response.actions {
                        for (index, action) in actions.enumerated() {
                            print("📋 [EquipmentCamera] Action \(index + 1):")
                            print("📋 [EquipmentCamera]   Type: \(action.type)")
                            print("📋 [EquipmentCamera]   Data keys: \(action.data.keys.sorted())")
                            for (key, value) in action.data {
                                if let arrayValue = value.arrayValue {
                                    print("📋 [EquipmentCamera]   \(key): [Array with \(arrayValue.count) items]")
                                    for (idx, item) in arrayValue.enumerated() {
                                        print("📋 [EquipmentCamera]     [\(idx)]: \(item)")
                                    }
                                } else if let dictValue = value.dictValue {
                                    print("📋 [EquipmentCamera]   \(key): [Dictionary with \(dictValue.count) keys]")
                                    for (dictKey, dictVal) in dictValue {
                                        print("📋 [EquipmentCamera]     \(dictKey): \(dictVal)")
                                    }
                                } else {
                                    print("📋 [EquipmentCamera]   \(key): \(value)")
                                }
                            }
                        }
                    }
                    print("📋 [EquipmentCamera] ==========================================")
                    
                    analysisResult = response
                    isAnalyzing = false
                    // Camera already stopped, show analysis view
                    showingAnalysis = true
                }
            } catch {
                print("❌ [Equipment] Error analyzing equipment: \(error)")
                await MainActor.run {
                    isAnalyzing = false
                }
            }
        }
    }
}

// MARK: - Equipment Camera Manager

@MainActor
class EquipmentCameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isSetup = false
    @Published var capturedImage: UIImage?
    
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var currentFrame: CVPixelBuffer?
    
    override init() {
        super.init()
    }
    
    func setupCamera() {
        print("📸 [EquipmentCamera] Starting camera setup...")
        checkPermission { [weak self] granted in
            guard granted, let self = self else {
                print("❌ [EquipmentCamera] Camera permission denied")
                return
            }
            
            print("📸 [EquipmentCamera] Permission granted, configuring camera...")
            
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
                    print("❌ [EquipmentCamera] Camera not available")
                    self.session.commitConfiguration()
                    return
                }
                
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    
                    if self.session.canAddInput(input) {
                        self.session.addInput(input)
                        print("✅ [EquipmentCamera] Added camera input")
                    }
                    
                    if self.session.canAddOutput(self.photoOutput) {
                        self.session.addOutput(self.photoOutput)
                        print("✅ [EquipmentCamera] Added photo output")
                    }
                    
                    // Setup video output for real-time detection
                    self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
                    self.videoOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    
                    if self.session.canAddOutput(self.videoOutput) {
                        self.session.addOutput(self.videoOutput)
                        print("✅ [EquipmentCamera] Added video output")
                    }
                    
                    self.session.commitConfiguration()
                    print("✅ [EquipmentCamera] Session configuration committed")
                    
                    // Update UI on main thread first
                    self.isSetup = true
                    print("✅ [EquipmentCamera] Camera setup complete, isSetup = true")
                    
                    // Start session on background thread AFTER configuration is committed
                    DispatchQueue.global(qos: .userInitiated).async {
                        // Small delay to ensure configuration is fully committed
                        Thread.sleep(forTimeInterval: 0.1)
                        
                        if !self.session.isRunning {
                            print("📸 [EquipmentCamera] Starting camera session...")
                            self.session.startRunning()
                            print("✅ [EquipmentCamera] Camera session started")
                        }
                    }
                } catch {
                    print("❌ [EquipmentCamera] Camera setup error: \(error)")
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

extension EquipmentCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("❌ Failed to capture image")
            return
        }
        
        capturedImage = image
    }
}

extension EquipmentCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        currentFrame = pixelBuffer
    }
    
    func getCurrentFrame() async -> CVPixelBuffer? {
        return currentFrame
    }
}

// MARK: - Equipment Detection Overlay

struct EquipmentDetectionOverlayView: View {
    let regions: [EquipmentCameraView.DetectionRegion]
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

