import Foundation

/// Service for generating high-quality meditation audio using Amazon Polly Neural TTS (via Lambda)
/// AWS-native solution with no external API keys needed
/// Supports streaming and provides much better quality than iOS TTS
class OpenAITTSService {
    static let shared = OpenAITTSService()
    
    private init() {}
    
    /// Generate audio URL for meditation script using Amazon Polly Neural TTS
    /// - Parameters:
    ///   - script: The meditation script text
    ///   - voice: Voice preference (female, male, or Polly voice ID - default: female for calming voice)
    /// - Returns: URL to the generated audio file on S3, or nil if generation fails
    func generateAudioURL(
        script: String,
        voice: String = "female"
    ) async -> String? {
        print("🎙️ [Polly TTS] Generating audio for script (\(script.count) chars)")
        
        // Use Lambda function that handles Polly Neural TTS + S3 upload
        // AWS-native, no external API keys needed
        guard let lambdaURL = getLambdaURL() else {
            print("❌ [Polly TTS] No Lambda URL configured")
            return nil
        }
        
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("❌ [Polly TTS] No userId available")
            return nil
        }
        
        do {
            var request = URLRequest(url: lambdaURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Add auth header if available (Lambda Function URL with AWS_IAM auth)
            if let idToken = AWSCognitoAuth.shared.getIdToken() {
                request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }
            
            let requestBody: [String: Any] = [
                "script": script,
                "voice": voice,
                "userId": userId
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [Polly TTS] Invalid response type")
                return nil
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                print("❌ [Polly TTS] HTTP \(httpResponse.statusCode): \(errorBody)")
                return nil
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let audioUrl = json["audioUrl"] as? String else {
                print("❌ [Polly TTS] Invalid response format")
                return nil
            }
            
            print("✅ [Polly TTS] Audio generated successfully: \(audioUrl)")
            return audioUrl
            
        } catch {
            print("❌ [Polly TTS] Error generating audio: \(error)")
            return nil
        }
    }
    
    /// Get Lambda function URL from UserDefaults or environment
    private func getLambdaURL() -> URL? {
        // Try UserDefaults first (set after deployment)
        if let urlString = UserDefaults.standard.string(forKey: "polly_tts_lambda_url"),
           let url = URL(string: urlString) {
            return url
        }
        
        // Fallback: Use hardcoded deployed URL
        if let url = URL(string: "https://ll24yy5ztotwk7i6uztia4kkqm0jhnva.lambda-url.us-east-1.on.aws/") {
            return url
        }
        
        return nil
    }
}

