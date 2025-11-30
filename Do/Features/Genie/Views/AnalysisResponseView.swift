import SwiftUI

// MARK: - Beautiful Analysis View

struct AnalysisResponseView: View {
    let analysis: AnalysisResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Summary Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Summary")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(Color(hex: "F7931F"))
                
                Text(analysis.summary)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Analysis Sections
            analysisSection(title: "Performance", icon: "bolt.fill", content: analysis.analysis.performance)
            analysisSection(title: "Patterns", icon: "arrow.triangle.2.circlepath", content: analysis.analysis.patterns)
            analysisSection(title: "Recovery", icon: "heart.fill", content: analysis.analysis.recovery)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Recommendations
            if !analysis.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Recommendations")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "F7931F"))
                    
                    ForEach(Array(analysis.recommendations.enumerated()), id: \.offset) { index, rec in
                        recommendationCard(rec)
                    }
                }
            }
            
            // Key Insights
            if !analysis.insights.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Key Insights")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "F7931F"))
                    
                    ForEach(Array(analysis.insights.enumerated()), id: \.offset) { index, insight in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(Color(hex: "F7931F"))
                            Text(insight)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
            }
            
            // Data Used Footer
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack(spacing: 16) {
                dataPoint(icon: "figure.run", label: "\(analysis.dataUsed.runsAnalyzed) runs")
                dataPoint(icon: "calendar", label: analysis.dataUsed.dateRange)
                dataPoint(icon: "map", label: analysis.dataUsed.totalDistance)
            }
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func analysisSection(title: String, icon: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.7))
            
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func recommendationCard(_ rec: AnalysisResponse.Recommendation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: rec.type == "immediate" ? "exclamationmark.circle.fill" : "calendar.badge.clock")
                .font(.system(size: 16))
                .foregroundColor(rec.type == "immediate" ? Color(hex: "F7931F") : .blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rec.type.capitalized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(rec.action)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func dataPoint(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(label)
                .font(.system(size: 11))
        }
    }
}

// Preview
struct AnalysisResponseView_Previews: PreviewProvider {
    static var previews: some View {
        AnalysisResponseView(analysis: AnalysisResponse(
            summary: "Your last run on October 31, 2024, was a 3.00 mile run completed in 36:43.",
            analysis: AnalysisResponse.Analysis(
                performance: "Your pace for this run was 12:14 minutes per mile. This is a solid effort for a general fitness goal.",
                patterns: "You have completed three runs this week with distances ranging from 3.00 to 4.02 miles. Your paces varied, with the fastest being 11:08 minutes per mile.",
                recovery: "Your recovery status is good, and you are ready to train."
            ),
            recommendations: [
                AnalysisResponse.Recommendation(type: "immediate", action: "Consider incorporating a short cooldown session after your runs to enhance recovery."),
                AnalysisResponse.Recommendation(type: "weekly", action: "Aim for at least two more runs this week to build consistency and improve your weekly mileage.")
            ],
            insights: [
                "Your recent runs show a good variety in distance, which can help in building overall fitness.",
                "Focusing on maintaining a consistent pace across your runs can help in improving your overall performance."
            ],
            dataUsed: AnalysisResponse.DataUsed(
                runsAnalyzed: 3,
                dateRange: "Oct 31, 2024",
                totalDistance: "10.13 mi"
            )
        ))
        .padding()
        .background(Color(hex: "0F163E"))
    }
}

