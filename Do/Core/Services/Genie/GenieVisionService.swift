//
//  GenieVisionService.swift
//  Do
//
//  Image capture and analysis service for Genie
//

import Foundation
import UIKit
import AVFoundation

@MainActor
class GenieVisionService: ObservableObject {
    static let shared = GenieVisionService()
    
    @Published var capturedImage: UIImage?
    @Published var capturedVideo: URL?
    @Published var isAnalyzing = false
    @Published var analysisResult: VisionAnalysisResult?
    @Published var identifiedEquipment: Equipment?
    
    private init() {}
    
    // MARK: - Image Capture
    
    func captureImage(from viewController: UIViewController) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.cameraDevice = .rear
            picker.cameraCaptureMode = .photo
            
            let coordinator = ImagePickerCoordinator { image in
                continuation.resume(returning: image)
            }
            
            picker.delegate = coordinator
            
            // Keep coordinator alive
            objc_setAssociatedObject(picker, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)
            
            viewController.present(picker, animated: true)
        }
    }
    
    func selectImageFromLibrary(from viewController: UIViewController) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            
            let coordinator = ImagePickerCoordinator { image in
                continuation.resume(returning: image)
            }
            
            picker.delegate = coordinator
            
            // Keep coordinator alive
            objc_setAssociatedObject(picker, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)
            
            viewController.present(picker, animated: true)
        }
    }
    
    // MARK: - Video Capture
    
    func captureVideo(from viewController: UIViewController) async -> URL? {
        return await withCheckedContinuation { continuation in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeHigh
            picker.videoMaximumDuration = 60 // 1 minute max
            
            let coordinator = VideoPickerCoordinator { url in
                continuation.resume(returning: url)
            }
            
            picker.delegate = coordinator
            objc_setAssociatedObject(picker, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)
            
            viewController.present(picker, animated: true)
        }
    }
    
    func selectVideoFromLibrary(from viewController: UIViewController) async -> URL? {
        return await withCheckedContinuation { continuation in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.mediaTypes = ["public.movie"]
            
            let coordinator = VideoPickerCoordinator { url in
                continuation.resume(returning: url)
            }
            
            picker.delegate = coordinator
            objc_setAssociatedObject(picker, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)
            
            viewController.present(picker, animated: true)
        }
    }
    
    // MARK: - Image Analysis
    
    func analyzeImage(_ image: UIImage, query: String) async throws -> VisionAnalysisResult {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw VisionError.imageConversionFailed
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // Send to Genie API with image
        let response = try await GenieAPIService.shared.queryWithImage(
            query,
            imageBase64: base64Image
        )
        
        // Parse response to determine analysis type
        let result = parseAnalysisResponse(response.response, image: image)
        analysisResult = result
        
        return result
    }
    
    // MARK: - Video Analysis
    
    func analyzeVideo(_ videoURL: URL, query: String) async throws -> VisionAnalysisResult {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        // Extract key frames from video
        let frames = try await extractKeyFrames(from: videoURL, count: 5)
        
        // Convert frames to base64
        let frameData = try frames.map { frame in
            guard let data = frame.jpegData(compressionQuality: 0.7) else {
                throw VisionError.imageConversionFailed
            }
            return data.base64EncodedString()
        }
        
        // Send to Genie API with video frames
        let response = try await GenieAPIService.shared.queryWithVideo(
            query,
            frames: frameData
        )
        
        let result = parseAnalysisResponse(response.response, video: videoURL)
        analysisResult = result
        
        return result
    }
    
    // MARK: - Equipment Identification
    
    func identifyEquipment(_ image: UIImage) async throws -> Equipment {
        // Use a more specific query to get structured equipment data
        let query = """
        Identify this gym equipment. Provide:
        1. Equipment name (be specific, e.g., "Smith Machine" not just "machine")
        2. What muscle groups it targets
        3. Brief description of what it's used for
        
        Format your response clearly with the equipment name first, then the details.
        """
        
        let result = try await analyzeImage(image, query: query)
        
        guard case .equipment(let equipment) = result else {
            throw VisionError.analysisError("Could not identify equipment")
        }
        
        identifiedEquipment = equipment
        return equipment
    }
    
    // MARK: - Form Analysis
    
    func analyzeForm(_ videoURL: URL, exercise: String) async throws -> FormAnalysis {
        let result = try await analyzeVideo(
            videoURL,
            query: "Analyze my \(exercise) form. Check my posture, range of motion, and technique. Provide specific feedback on what I'm doing well and what needs improvement."
        )
        
        guard case .formAnalysis(let analysis) = result else {
            throw VisionError.analysisError("Could not analyze form")
        }
        
        // Save to history
        await saveFormAnalysis(analysis)
        
        return analysis
    }
    
    // MARK: - Helper Methods
    
    func compressImage(_ image: UIImage, maxSizeKB: Int = 500) -> Data? {
        var compression: CGFloat = 0.9
        var imageData = image.jpegData(compressionQuality: compression)
        
        while let data = imageData, data.count > maxSizeKB * 1024 && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        return imageData
    }
    
    func extractKeyFrames(from videoURL: URL, count: Int) async throws -> [UIImage] {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        var frames: [UIImage] = []
        let interval = durationSeconds / Double(count)
        
        for i in 0..<count {
            let time = CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                frames.append(UIImage(cgImage: cgImage))
            }
        }
        
        return frames
    }
    
    private func parseAnalysisResponse(_ response: String, image: UIImage? = nil, video: URL? = nil) -> VisionAnalysisResult {
        let lowercased = response.lowercased()
        
        // Check if it's equipment identification
        if lowercased.contains("equipment") || lowercased.contains("machine") || lowercased.contains("targets") {
            let equipment = parseEquipmentInfo(response, image: image)
            return .equipment(equipment)
        }
        
        // Check if it's form analysis
        if lowercased.contains("form") || lowercased.contains("posture") || lowercased.contains("technique") {
            let analysis = parseFormAnalysis(response, video: video)
            return .formAnalysis(analysis)
        }
        
        // Default to general analysis
        return .general(response)
    }
    
    private func parseEquipmentInfo(_ response: String, image: UIImage?) -> Equipment {
        // Clean markdown from response
        let cleanedResponse = MarkdownFormatter.cleanMarkdown(response)
        
        // Extract equipment name - look for bold text or first significant line
        var name = "Unknown Equipment"
        let lines = cleanedResponse.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        // Look for equipment name patterns
        for line in lines {
            // Skip common prefixes
            if line.lowercased().hasPrefix("this is") || 
               line.lowercased().hasPrefix("i can see") ||
               line.lowercased().hasPrefix("this appears") {
                // Extract name from sentence
                if let match = line.range(of: #"a\s+([A-Z][a-z]+(?:\s+[a-z]+)*)"#, options: .regularExpression) {
                    name = String(line[match]).replacingOccurrences(of: "a ", with: "").capitalized
                    break
                } else if let match = line.range(of: #"an\s+([A-Z][a-z]+(?:\s+[a-z]+)*)"#, options: .regularExpression) {
                    name = String(line[match]).replacingOccurrences(of: "an ", with: "").capitalized
                    break
                }
            } else if line.count > 3 && line.count < 50 && !line.lowercased().contains("muscle") && !line.lowercased().contains("target") {
                // First significant line that's not about muscles
                name = line
                break
            }
        }
        
        // Extract muscle groups more accurately
        let muscleGroups = extractMuscleGroups(from: cleanedResponse)
        
        // Build description from response (excluding name line)
        let description = lines.filter { !$0.lowercased().hasPrefix(name.lowercased()) }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        
        return Equipment(
            id: UUID().uuidString,
            name: name,
            description: description.isEmpty ? cleanedResponse : description,
            muscleGroups: muscleGroups,
            image: image,
            suggestedWorkouts: []
        )
    }
    
    private func parseFormAnalysis(_ response: String, video: URL?) -> FormAnalysis {
        return FormAnalysis(
            id: UUID().uuidString,
            exercise: "Exercise",
            date: Date(),
            videoURL: video,
            feedback: response,
            score: extractScore(from: response),
            improvements: extractImprovements(from: response)
        )
    }
    
    private func extractMuscleGroups(from text: String) -> [String] {
        let muscles = ["chest", "back", "legs", "shoulders", "arms", "core", "glutes", "hamstrings", "quads", "calves"]
        return muscles.filter { text.lowercased().contains($0) }
    }
    
    private func extractScore(from text: String) -> Double {
        // Look for percentage or score in text
        let pattern = #"(\d+)%|\bscore[:\s]+(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            for i in 1..<match.numberOfRanges {
                if let range = Range(match.range(at: i), in: text),
                   let score = Double(text[range]) {
                    return score / 100.0
                }
            }
        }
        return 0.75 // Default score
    }
    
    private func extractImprovements(from text: String) -> [String] {
        // Extract bullet points or numbered lists
        let lines = text.components(separatedBy: .newlines)
        return lines.filter { line in
            line.trimmingCharacters(in: .whitespaces).starts(with: "-") ||
            line.trimmingCharacters(in: .whitespaces).starts(with: "•") ||
            line.range(of: #"^\d+\."#, options: .regularExpression) != nil
        }.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-•").union(.whitespaces)) }
    }
    
    private func saveFormAnalysis(_ analysis: FormAnalysis) async {
        // Save to local storage or database
        let key = "formAnalysisHistory"
        var history = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        
        let dict: [String: Any] = [
            "id": analysis.id,
            "exercise": analysis.exercise,
            "date": analysis.date.timeIntervalSince1970,
            "feedback": analysis.feedback,
            "score": analysis.score
        ]
        
        history.insert(dict, at: 0)
        
        // Keep only last 50 analyses
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        
        UserDefaults.standard.set(history, forKey: key)
    }
}

// MARK: - Image Picker Coordinator

class ImagePickerCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let completion: (UIImage?) -> Void
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) {
            self.completion(image)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.completion(nil)
        }
    }
}

// MARK: - Video Picker Coordinator

class VideoPickerCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let completion: (URL?) -> Void
    
    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let videoURL = info[.mediaURL] as? URL
        picker.dismiss(animated: true) {
            self.completion(videoURL)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.completion(nil)
        }
    }
}

// MARK: - Models

enum VisionAnalysisResult {
    case equipment(Equipment)
    case formAnalysis(FormAnalysis)
    case general(String)
}

struct Equipment: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let muscleGroups: [String]
    var image: UIImage?
    var suggestedWorkouts: [EquipmentWorkout]
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, muscleGroups, suggestedWorkouts
    }
}

struct EquipmentWorkout: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let sets: Int
    let reps: String
    let difficulty: String
    let instructions: [String]
    let videoURL: String?
    let muscleGroups: [String]
}

struct FormAnalysis: Identifiable, Codable {
    let id: String
    let exercise: String
    let date: Date
    var videoURL: URL?
    let feedback: String
    let score: Double // 0.0 to 1.0
    let improvements: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, exercise, date, feedback, score, improvements
    }
}

// MARK: - Errors

enum VisionError: LocalizedError {
    case imageConversionFailed
    case analysisError(String)
    case videoProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image"
        case .analysisError(let message):
            return "Analysis error: \(message)"
        case .videoProcessingFailed:
            return "Failed to process video"
        }
    }
}
