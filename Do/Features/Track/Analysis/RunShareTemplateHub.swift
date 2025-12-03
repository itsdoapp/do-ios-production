//
//  RunShareTemplateHub.swift
//  Do
//
//  Share template hub for running and hiking workouts
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct RunShareTemplateHub: View {
    let run: Any
    let isOutdoorRun: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        // For now, use a simple share sheet
        // This can be enhanced later with multiple template options
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0x0F0F23),
                    Color(hex: 0x16213E),
                    Color(hex: 0x1A1A2E)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Share Workout")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                Spacer()
                
                // Share button
                Button(action: {
                    shareWorkout()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: 0x3B82F6), Color(hex: 0x60A5FA)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func shareWorkout() {
        // Create share text based on workout type
        var shareText = ""
        
        if let runLog = run as? RunLog {
            shareText = createRunShareText(run: runLog)
        } else if let hikeLog = run as? HikeLog {
            shareText = createHikeShareText(hike: hikeLog)
        } else {
            shareText = "Just completed a workout! 🏃‍♂️"
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func createRunShareText(run: RunLog) -> String {
        var text = "🏃‍♂️ Run Workout\n\n"
        
        if let distance = run.distance {
            text += "Distance: \(distance)\n"
        }
        
        if let duration = run.duration {
            text += "Time: \(duration)\n"
        }
        
        if let pace = run.avgPace {
            text += "Pace: \(pace)\n"
        }
        
        if let calories = run.caloriesBurned {
            text += "Calories: \(Int(calories))\n"
        }
        
        return text
    }
    
    private func createHikeShareText(hike: HikeLog) -> String {
        var text = "🥾 Hike Workout\n\n"
        
        if let distance = hike.distance {
            text += "Distance: \(distance)\n"
        }
        
        if let duration = hike.duration {
            text += "Time: \(duration)\n"
        }
        
        if let elevation = hike.elevationGain {
            text += "Elevation Gain: \(elevation)\n"
        }
        
        return text
    }
}





