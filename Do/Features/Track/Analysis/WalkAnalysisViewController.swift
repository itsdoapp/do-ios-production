import UIKit
import SwiftUI
import MapKit
import Charts
import CoreLocation


class WalkAnalysisViewController: UIViewController {
    private var hostingController: UIHostingController<WalkAnalysisView>?
    var walk: WalkLog?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHostingController()
    }

    private func setupHostingController() {
        guard let walk = walk else { return }
        let analysisView = WalkAnalysisView(walk: walk, onDismiss: { [weak self] in self?.dismiss(animated: true) })
        hostingController = UIHostingController(rootView: analysisView)
        if let hostingController = hostingController {
            addChild(hostingController)
            view.addSubview(hostingController.view)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            hostingController.didMove(toParent: self)
        }
    }
}

struct WalkAnalysisView: View {
    let walk: WalkLog
    let onDismiss: () -> Void
    @State private var selectedTab = 0
    @State private var routeLocations: [CLLocation] = []
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    struct RoutePoint: Identifiable { 
        let id = UUID()
        let coordinate: CLLocationCoordinate2D 
    }
    @State private var routePoints: [RoutePoint] = []

    var body: some View {
        ZStack {
            // Use the same background as bike/run for consistency
            Color(UIColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0))
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                headerView
                summaryCardsView
                tabSelectorView
                tabContentView
                Spacer()
            }
            .padding(.top, 8)
        }
        .onAppear { setupData() }
    }

    private var headerView: some View {
        VStack(spacing: 16) {
        HStack {
                Button(action: { onDismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(10)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
            }
            Spacer()
                Text("Walk Analysis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            Spacer()
                Button(action: { /* share walk analysis */ }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(10)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var summaryCardsView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDate())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Text(formatTimeOfDay())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)).shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4))
            HStack(spacing: 8) {
                metricCard(title: "DISTANCE", value: getDistance(), icon: "figure.walk", color: Color(hex: 0x4CD964))
                metricCard(title: "TIME", value: getDuration(), icon: "clock", color: Color(hex: 0xFF9500))
                metricCard(title: "AVG PACE", value: getAvgPaceFromHistory(), icon: "speedometer", color: Color(hex: 0x007AFF))
            }
        }
        .padding(.horizontal, 16)
    }

    // Formatters matching Bike's helpers
    private func getDistance() -> String {
        let useMetric = UserPreferences.shared.useMetricSystem
        let raw = (walk.distance ?? "").replacingOccurrences(of: "[^0-9\\.]", with: "", options: .regularExpression)
        let km = Double(raw) ?? 0
        let value = useMetric ? km : km/1.60934
        return String(format: useMetric ? "%.2f km" : "%.2f mi", value)
    }
    private func getDuration() -> String { walk.duration ?? "--:--" }
    private func getAvgPaceFromHistory() -> String {
        if let p = walk.avgPace, !p.isEmpty { return p }
        // Fallback compute
        let raw = (walk.distance ?? "").replacingOccurrences(of: "[^0-9\\.]", with: "", options: .regularExpression)
        let km = Double(raw) ?? 0
        let secs: Double = {
            guard let d = walk.duration else { return 0 }
            let comps = d.split(separator: ":").map { Int($0) ?? 0 }
            if comps.count == 3 { return Double(comps[0]*3600 + comps[1]*60 + comps[2]) }
            if comps.count == 2 { return Double(comps[0]*60 + comps[1]) }
            return Double(d) ?? 0
        }()
        guard km > 0, secs > 0 else { return UserPreferences.shared.useMetricSystem ? "0:00 /km" : "0:00 /mi" }
        let useMetric = UserPreferences.shared.useMetricSystem
        let paceSecondsPerKm = secs / km
        if useMetric {
            let m = Int(paceSecondsPerKm) / 60, s = Int(paceSecondsPerKm) % 60
            return String(format: "%d:%02d /km", m, s)
        } else {
            let paceSecondsPerMi = paceSecondsPerKm * 1.60934
            let m = Int(paceSecondsPerMi) / 60, s = Int(paceSecondsPerMi) % 60
            return String(format: "%d:%02d /mi", m, s)
        }
    }
    private func formatDate() -> String {
        guard let date = walk.createdAt else { return "" }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d, yyyy"; return f.string(from: date)
    }
    private func formatTimeOfDay() -> String {
        guard let date = walk.createdAt else { return "" }
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: date)
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    var tabSelectorView: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = index } }) {
                    VStack(spacing: 8) {
                        Text(["ROUTE","STATS","CHARTS"][index])
                            .font(.system(size: 14, weight: selectedTab == index ? .semibold : .medium))
                            .foregroundColor(selectedTab == index ? .white : .white.opacity(0.6))
                        Rectangle()
                            .fill(selectedTab == index ? Color(hex: 0x4CD964) : Color.clear)
                            .frame(height: 3)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    var tabContentView: some View {
        Group {
            if selectedTab == 0 { mapView }
            else if selectedTab == 1 { statsView }
            else { chartsView }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bike-style ROUTE tab content
    @State private var routeProgress: Double = 0.0
    @State private var isPlayingRoute: Bool = false
    private var mapView: some View {
        ZStack {
            MapViewWrapper(locations: routeLocations, region: $mapRegion, progress: $routeProgress)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
            VStack(spacing: 0) {
                Spacer()
                ZStack(alignment: .bottom) {
                    RoutePositionStatsCard(routeLocations: routeLocations, run: convertWalkToRunProxy(), progress: $routeProgress, isPlaying: $isPlayingRoute)
                        .padding(.bottom, 66)
                    RouteSeekSlider(value: $routeProgress, isPlaying: $isPlayingRoute, run: convertWalkToRunProxy(), onPlayPause: { isPlaying in
                        withAnimation { isPlayingRoute = isPlaying }
                    })
                    .offset(y: 22)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .onAppear { setMapRegion() }
    }

    // Create a lightweight proxy to reuse Run's overlay components
    private func convertWalkToRunProxy() -> Any { walk }

    // MARK: - Bike-style STATS tab content
    private var statsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Performance score card
                performanceScoreCard

                // Key stats row (steps, calories)
                HStack(spacing: 12) {
                    statCard(title: "CALORIES", value: caloriesChip(), icon: "flame.fill", color: Color(hex: 0xFF3B30))
                    statCard(title: "HEART RATE", value: heartRateChip(), icon: "heart.fill", color: Color(hex: 0xFF375F))
                }
                HStack(spacing: 12) {
                    statCard(title: "ELEVATION GAIN", value: elevationGainChip(), icon: "arrow.up.right", color: Color(hex: 0x5856D6))
                    statCard(title: "STEPS", value: stepsChip(), icon: "figure.walk", color: Color(hex: 0x34C759))
                }
            }
            .padding(16)
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    private var overviewView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Performance Score Card
                performanceScoreCard
                
                // Walk Performance Metrics
                HStack(spacing: 12) {
                    let stepsText = walk.steps != nil ? String(walk.steps!) : "--"
                    let caloriesText = walk.caloriesBurned != nil ? String(format: "%.0f", walk.caloriesBurned!) : "--"
                    metricCard(title: "Steps", value: stepsText, icon: "figure.walk", color: Color(hex: 0x4CD964))
                    metricCard(title: "Calories", value: caloriesText, icon: "flame", color: Color(hex: 0xFF3B30))
                }
                
                // Map metrics chips
                if !routeLocations.isEmpty {
                    HStack(spacing: 12) {
                        metricChip(title: "Distance", value: formatDistanceForChip())
                        metricChip(title: "Pace", value: formatPaceForChip())
                        metricChip(title: "Duration", value: formatDurationForChip())
                    }
                }
            }
            .padding(.vertical, 20)
        }
    }
    
    private var performanceScoreCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PERFORMANCE")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            
            HStack(spacing: 20) {
                // Overall Score
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(
                                Color.white.opacity(0.1),
                                lineWidth: 8
                            )
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(min(getOverallScore() / 100, 1.0)))
                            .stroke(
                                getScoreGradient(),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.0), value: getOverallScore())
                        
                        VStack(spacing: 0) {
                            Text("\(Int(getOverallScore()))")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("/100")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Text("OVERALL")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Individual Score Metrics
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(getPerformanceMetrics(), id: \._id) { metric in
                        HStack(spacing: 16) {
                            // Metric Name + Icon
                            HStack(spacing: 4) {
                                Image(systemName: metric.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(metric.color)
                                Text(metric.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .frame(width: 100, alignment: .leading)
                            
                            // Score bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(metric.color)
                                        .frame(width: geo.size.width * CGFloat(min(metric.score / 100, 1.0)), height: 6)
                                        .animation(.easeInOut(duration: 0.8), value: metric.score)
                                }
                            }
                            .frame(height: 6)
                            
                            // Score number
                            Text("\(Int(metric.score))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
            
            // Performance score legend
            VStack(alignment: .leading, spacing: 8) {
                Text("SCORING GUIDE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 4)
                Text("• Pace: Consistency of your speed during the walk")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                Text("• Heart Rate: Time spent in optimal training zones")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                Text("• Endurance: Duration relative to your history")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                Text("• Distance: Comparison to your typical walks")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                Text("Higher scores (80-100) indicate excellent performance")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Performance Score Calculations (Walk)
    private func getOverallScore() -> Double {
        let metrics = getPerformanceMetrics()
        if metrics.isEmpty { return 0 }
        let sum = metrics.reduce(0) { $0 + $1.score }
        return sum / Double(metrics.count)
    }
    private func getScoreGradient() -> AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color(hex: 0x4CD964),
                Color(hex: 0x5AC8FA),
                Color(hex: 0xFF9500),
                Color(hex: 0x4CD964)
            ]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }
    private struct PerformanceMetric: Identifiable {
        let id = UUID()
        var _id: UUID { id }
        let name: String
        let score: Double
        let icon: String
        let color: Color
    }
    private func getPerformanceMetrics() -> [PerformanceMetric] {
        var metrics: [PerformanceMetric] = []
        // Pace consistency
        let paceScore = calculatePaceConsistencyScore()
        metrics.append(PerformanceMetric(name: "PACE", score: paceScore, icon: "speedometer", color: Color(hex: 0x4CD964)))
        // Heart Rate zone
        if let hrScore = calculateHeartRateZoneScoreWalk() {
            metrics.append(PerformanceMetric(name: "HEART RATE", score: hrScore, icon: "heart.fill", color: Color(hex: 0xFF375F)))
        }
        // Duration endurance
        metrics.append(PerformanceMetric(name: "ENDURANCE", score: calculateDurationScoreWalk(), icon: "clock", color: Color(hex: 0xFF9500)))
        // Distance
        metrics.append(PerformanceMetric(name: "DISTANCE", score: calculateDistanceScoreWalk(), icon: "figure.walk", color: Color(hex: 0x5AC8FA)))
        return metrics
    }
    private func calculateHeartRateZoneScoreWalk() -> Double? {
        let data = extractHeartRateDataWalk()
        guard !data.isEmpty else { return nil }
        let avgHR = data.reduce(0, +) / Double(data.count)
        let minHR = data.min() ?? avgHR
        let maxHR = data.max() ?? avgHR
        let hrRange = maxHR - minHR
        let estimatedMaxHR = 180.0
        let percent = avgHR / estimatedMaxHR
        var score: Double
        if percent < 0.5 { score = 60.0 + (percent * 20.0) }
        else if percent < 0.6 { score = 70.0 + ((percent - 0.5) * 100) }
        else if percent < 0.85 { score = 80.0 + ((percent - 0.6) * 80) }
        else if percent < 0.95 { score = 90.0 - ((percent - 0.85) * 50) }
        else { score = 85.0 - ((percent - 0.95) * 100) }
        if hrRange > 30 { score += min(10.0, hrRange / 10.0) }
        return max(0, min(100, score))
    }
    private func extractHeartRateDataWalk() -> [Double] {
        if let locs = walk.locationData {
            return locs.compactMap { $0["heartRate"] as? Double }.filter { $0 > 0 }
        }
        return []
    }
    private func calculateDurationScoreWalk() -> Double {
        let target = 45.0 // minutes
        var actual = 0.0
        if let d = walk.duration { actual = convertDurationToMinutesWalk(d) }
        let raw = min(actual / target * 100, 100)
        let bonus = actual > target ? min((actual - target) / 15 * 10, 20) : 0
        return min(100, raw + bonus)
    }
    private func calculateDistanceScoreWalk() -> Double {
        let useMetric = UserPreferences.shared.useMetricSystem
        let target = useMetric ? 5.0 : 3.0 // 5km or 3mi
        var actual = 0.0
        if let s = walk.distance { actual = extractDistanceValueWalk(s) }
        let raw = min(actual / target * 100, 100)
        let bonus = actual > target ? min((actual - target) / (useMetric ? 2.5 : 1.5) * 10, 20) : 0
        return min(100, raw + bonus)
    }
    private func convertDurationToMinutesWalk(_ durationStr: String) -> Double {
        let comps = durationStr.split(separator: ":").map { Double($0) ?? 0 }
        if comps.count == 3 { return comps[0]*60 + comps[1] + comps[2]/60 }
        if comps.count == 2 { return comps[0] + comps[1]/60 }
        return Double(durationStr) ?? 0
    }
    private func extractDistanceValueWalk(_ distanceStr: String) -> Double {
        let useMetric = UserPreferences.shared.useMetricSystem
        let trimmed = distanceStr.trimmingCharacters(in: .whitespaces)
        let value = Double(trimmed.replacingOccurrences(of: "[^0-9\\.]", with: "", options: .regularExpression)) ?? 0
        if distanceStr.lowercased().contains("mi") { return useMetric ? value * 1.60934 : value }
        return useMetric ? value : value / 1.60934
    }

    private func scoreRow(title: String, score: Double) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text("\(Int(score))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var routeMapView: some View {
        VStack(spacing: 16) {
            // Map
            Map(coordinateRegion: $mapRegion, annotationItems: routePoints) { point in
                MapMarker(coordinate: point.coordinate)
            }
            .frame(height: 300)
            .cornerRadius(16)
            
            // Route stats
            if !routeLocations.isEmpty {
                VStack(spacing: 12) {
                    HStack {
                        Text("ROUTE STATS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        metricChip(title: "Distance", value: formatDistanceForChip())
                        metricChip(title: "Pace", value: formatPaceForChip())
                        metricChip(title: "Duration", value: formatDurationForChip())
                    }
                }
            }
        }
    }
    
    private var splitsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Mile/KM Splits
                if !routeLocations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(UserPreferences.shared.useMetricSystem ? "KM SPLITS" : "MILE SPLITS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        
                        let splits = calculateWalkSplits()
                        if !splits.isEmpty {
                            VStack(spacing: 0) {
                                // Header
                                HStack {
                                    Text(UserPreferences.shared.useMetricSystem ? "KM" : "MILE")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 40, alignment: .leading)
                                    
                                    Text("PACE")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 70, alignment: .leading)
                                    
                                    Text("TIME")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 55, alignment: .leading)
                                    
                                    Text("HR")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 50, alignment: .leading)
                                    
                                    Text("DISTANCE")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 12)
                                .padding(.bottom, 8)
                                
                                // Splits
                                ForEach(0..<splits.count, id: \.self) { index in
                                    let split = splits[index]
                                    let useMetric = UserPreferences.shared.useMetricSystem
                                    let unitMeters = useMetric ? 1000.0 : 1609.34
                                    let totalDistance = getTotalDistance()
                                    let completeUnits = Int(floor(totalDistance / unitMeters))
                                    
                                    // Check if this is a partial split (unit number > complete units)
                                    let isPartialSplit = split.unit > completeUnits
                                    
                                    HStack {
                                        // Show unit number or distance for partial split
                                        if isPartialSplit {
                                            let partialDistance = totalDistance - (Double(completeUnits) * unitMeters)
                                            let distanceText = useMetric ? 
                                                String(format: "%.1f", partialDistance / 1000.0) : 
                                                String(format: "%.2f", partialDistance / 1609.34)
                                            Text(distanceText).font(.system(size: 14, weight: .bold)).foregroundColor(.white.opacity(0.8)).frame(width: 40, alignment: .leading)
                                        } else {
                                            Text("\(split.unit)")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 40, alignment: .leading)
                                        }
                                        
                                        Text(formatPaceValue(split.pace))
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .frame(width: 70, alignment: .leading)
                                        
                                        Text(formatWalkSplitTime(split.time))
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .frame(width: 55, alignment: .leading)
                                        
                                        // Heart Rate
                                        Text(split.avgHeartRate != nil ? "\(Int(split.avgHeartRate!))bpm" : "--")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .frame(width: 50, alignment: .leading)
                                        
                                        // Show distance for partial split
                                        if isPartialSplit {
                                            let partialDistance = totalDistance - (Double(completeUnits) * unitMeters)
                                            let distanceText = useMetric ? 
                                                String(format: "%.1f km", partialDistance / 1000.0) : 
                                                String(format: "%.2f mi", partialDistance / 1609.34)
                                            Text(distanceText).font(.system(size: 14)).foregroundColor(.white.opacity(0.8)).frame(maxWidth: .infinity, alignment: .leading)
                                        } else {
                                            Text("--")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.6))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(index % 2 == 0 ? Color.white.opacity(0.05) : Color.clear)
                                    .cornerRadius(8)
                                }
                            }
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(12)
                        } else {
                            Text("No split data available")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .padding()
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.vertical, 20)
        }
    }
    
    private var chartsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Pace Chart (match Run)
                VStack(alignment: .leading, spacing: 8) {
                    Text("PACE VARIATION")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    paceChartView
                        .frame(height: 200)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                }
                
                // Elevation Chart
                if !routeLocations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ELEVATION PROFILE")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        elevationChartView
                            .frame(height: 200)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                    }
                }
                
                // Heart Rate Chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("HEART RATE")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    heartRateChartView
                        .frame(height: 200)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Charts (match Run)
    private var paceChartView: some View {
        let paceDataPoints = !routeLocations.isEmpty ? calculatePaceChartData() : []
        let maxPace = paceDataPoints.map { $0.pace }.max() ?? 12.0
        let domainLower = 0.0
        let domainUpper = min(20.0, max(8.0, ceil(maxPace * 10) / 10 + 0.5))
        return Chart {
            if !paceDataPoints.isEmpty {
                ForEach(Array(paceDataPoints.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value("Distance", point.distance),
                        y: .value("Pace", point.pace)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: 0x4CD964), Color(hex: 0x007AFF)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    AreaMark(
                        x: .value("Distance", point.distance),
                        y: .value("Pace", point.pace)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: 0x4CD964).opacity(0.4), Color(hex: 0x007AFF).opacity(0.1)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    if index % max(1, paceDataPoints.count / 6) == 0 {
                        PointMark(
                            x: .value("Distance", point.distance),
                            y: .value("Pace", point.pace)
                        )
                        .foregroundStyle(Color.white)
                        .symbolSize(30)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(Color.white.opacity(0.3))
                AxisValueLabel() {
                    if let pace = value.as(Double.self) {
                        Text(formatPaceValue(pace)).font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(Color.white.opacity(0.3))
                AxisValueLabel() {
                    if let distance = value.as(Double.self) {
                        Text(formatDistanceValue(distance)).font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .chartYScale(domain: domainLower...domainUpper)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                Text("PACE CHART").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.9))
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: 0x4CD964)).frame(width: 8, height: 8)
                    Text(UserPreferences.shared.useMetricSystem ? "min/km" : "min/mi").font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                }
                if let avg = getPaceAverage() { Text("Avg: \(formatPaceValue(avg))").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.9)) }
            }
            .padding(12)
        }
    }
    
    private var elevationChartView: some View {
        Group {
            if !routeLocations.isEmpty {
                let elevationData = routeLocations.map { $0.altitude }
                Chart {
                    ForEach(Array(elevationData.enumerated()), id: \.offset) { index, elevation in
                        LineMark(
                            x: .value("Distance", Double(index) * getChartDistanceInterval(elevationData.count)),
                            y: .value("Elevation", elevation)
                        )
                        .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color(hex: 0x5856D6), Color(hex: 0x5AC8FA)]), startPoint: .leading, endPoint: .trailing))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        AreaMark(
                            x: .value("Distance", Double(index) * getChartDistanceInterval(elevationData.count)),
                            y: .value("Elevation", elevation)
                        )
                        .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color(hex: 0x5856D6).opacity(0.4), Color(hex: 0x5AC8FA).opacity(0.1)]), startPoint: .top, endPoint: .bottom))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisValueLabel() {
                            if let elevation = value.as(Double.self) {
                                let useMetric = UserPreferences.shared.useMetricSystem
                                if useMetric {
                                    Text("\(Int(elevation))m").font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                                } else {
                                    let feet = elevation * 3.28084
                                    Text("\(Int(feet))ft").font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisValueLabel() {
                            if let distance = value.as(Double.self) {
                                Text(formatDistanceValue(distance)).font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: 0x5AC8FA)).frame(width: 8, height: 8)
                            Text(UserPreferences.shared.useMetricSystem ? "Elevation (m)" : "Elevation (ft)").font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                        }
                        if let g = walk.elevationGain, let l = walk.elevationLoss {
                            HStack(spacing: 8) {
                                Text("Gain: \(g)").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.9))
                                Text("Loss: \(l)").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    .padding(12)
                }
            } else {
                Text("No elevation data available").foregroundColor(.white.opacity(0.7)).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var heartRateChartView: some View {
        Group {
            if let locs = walk.locationData {
                let heartRateData = locs.compactMap { $0["heartRate"] as? Double }.filter { $0 > 0 }
                if !heartRateData.isEmpty {
                    let normalized = heartRateData.map { max(0, min($0, 220)) }
                    let timeInterval = getChartTimeInterval(normalized.count)
                    Chart {
                        ForEach(Array(normalized.enumerated()), id: \.offset) { index, hr in
                            LineMark(x: .value("Time", Double(index) * timeInterval), y: .value("Heart Rate", hr))
                            .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFF375F), Color(hex: 0xFF3B30)]), startPoint: .leading, endPoint: .trailing))
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            AreaMark(x: .value("Time", Double(index) * timeInterval), y: .value("Heart Rate", hr))
                            .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFF375F).opacity(0.4), Color(hex: 0xFF3B30).opacity(0.1)]), startPoint: .top, endPoint: .bottom))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(Color.white.opacity(0.3))
                            AxisValueLabel() { if let v = value.as(Double.self) { Text("\(Int(v)) bpm").font(.system(size: 10)).foregroundColor(.white.opacity(0.7)) } }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(Color.white.opacity(0.3))
                            AxisValueLabel() { if let t = value.as(Double.self) { Text(formatTimeValue(t)).font(.system(size: 10)).foregroundColor(.white.opacity(0.7)) } }
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) { Circle().fill(Color(hex: 0xFF3B30)).frame(width: 8, height: 8); Text("BPM").font(.system(size: 10)).foregroundColor(.white.opacity(0.7)) }
                            if let avg = getHeartRateAverageWalk(heartRateData: heartRateData), let max = heartRateData.max() { HStack(spacing: 8) { Text("Avg: \(avg) bpm").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.9)); Text("Max: \(Int(max)) bpm").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.9)) } }
                        }
                        .padding(12)
                    }
                } else { Text("No heart rate data available").foregroundColor(.white.opacity(0.7)) }
            } else { Text("No heart rate data available").foregroundColor(.white.opacity(0.7)) }
        }
    }

    // Run-parity helpers for charts
    private func calculatePaceChartData() -> [PacePoint] {
        guard routeLocations.count > 1 else { return [] }
        let locations = routeLocations.sorted { $0.timestamp < $1.timestamp }
        let useMetric = UserPreferences.shared.useMetricSystem
        let unitMeters = useMetric ? 1000.0 : 1609.34
        let binSizeMeters = useMetric ? 100.0 : 160.934
        var cumDist: [Double] = [0]
        var cumTime: [Double] = [0]
        for i in 1..<locations.count {
            let d = locations[i].distance(from: locations[i-1])
            let dt = max(0.1, locations[i].timestamp.timeIntervalSince(locations[i-1].timestamp))
            cumDist.append(cumDist.last! + d)
            cumTime.append(cumTime.last! + dt)
        }
        let totalDist = cumDist.last ?? 0
        guard totalDist > 0 else { return [] }
        let numBins = max(1, Int(ceil(totalDist / binSizeMeters)))
        var points: [PacePoint] = []
        func interpolateTime(_ target: Double) -> Double {
            if target <= 0 { return 0 }
            var lo = 0, hi = cumDist.count - 1
            while lo < hi { let mid = (lo + hi)/2; if cumDist[mid] < target { lo = mid + 1 } else { hi = mid } }
            let idx = max(1, lo)
            let d0 = cumDist[idx-1], d1 = cumDist[idx]
            let t0 = cumTime[idx-1], t1 = cumTime[idx]
            if d1 <= d0 { return t1 }
            let ratio = (target - d0) / (d1 - d0)
            return t0 + ratio * (t1 - t0)
        }
        var prev: Double = 0
        for b in 1...numBins {
            let boundary = min(Double(b) * binSizeMeters, totalDist)
            let t0 = interpolateTime(prev)
            let t1 = interpolateTime(boundary)
            let meters = boundary - prev
            let seconds = max(0.1, t1 - t0)
            let mps = meters / seconds
            let paceMinPerUnit = (unitMeters / mps) / 60.0
            let capped = min(20.0, max(3.0, paceMinPerUnit))
            let xUnits = boundary / unitMeters
            points.append(PacePoint(distance: xUnits, pace: capped))
            prev = boundary
        }
        if points.count > 4 {
            var smoothed: [PacePoint] = []
            for i in 0..<points.count { let ids = [max(0,i-2),max(0,i-1),i,min(points.count-1,i+1),min(points.count-1,i+2)]; let vals = ids.map{points[$0].pace}.sorted(); let med = vals[vals.count/2]; smoothed.append(PacePoint(distance: points[i].distance, pace: med)) }
            return smoothed
        }
        return points
    }
    private struct PacePoint { let distance: Double; let pace: Double }
    private func formatPaceValue(_ pace: Double) -> String { let useMetric = UserPreferences.shared.useMetricSystem; let m = Int(pace); let s = Int((pace - Double(m))*60); return String(format: "%d:%02d %@", m, s, useMetric ? "/km" : "/mi") }
    private func formatDistanceValue(_ distance: Double) -> String { let useMetric = UserPreferences.shared.useMetricSystem; let converted = useMetric ? distance*1.60934 : distance; return String(format: "%.1f %@", converted, useMetric ? "km" : "mi") }
    private func getChartDistanceInterval(_ pointCount: Int) -> Double { var meters: Double = 0; for i in 1..<routeLocations.count { meters += routeLocations[i-1].distance(from: routeLocations[i]) }; let useMetric = UserPreferences.shared.useMetricSystem; let units = useMetric ? meters/1000.0 : meters/1609.34; return max(0.01, units/Double(max(1, pointCount-1))) }
    private func getChartTimeInterval(_ pointCount: Int) -> Double { var totalMinutes: Double = 30.0; if let d = walk.duration { totalMinutes = convertDurationToMinutesWalk(d) }; return max(0.5, totalMinutes/Double(max(1, pointCount-1))) }
    private func formatTimeValue(_ time: Double) -> String { if time >= 60 { let h = Int(time)/60; let m = Int(time)%60; return String(format: "%d:%02dh", h, m) } else { return "\(Int(time))m" } }
    private func getPaceAverage() -> Double? { let pts = calculatePaceChartData(); guard !pts.isEmpty else { return nil }; let sum = pts.reduce(0) { $0 + $1.pace }; return sum / Double(pts.count) }
    private func getHeartRateAverageWalk(heartRateData: [Double]) -> Int? { guard !heartRateData.isEmpty else { return nil }; let avg = heartRateData.reduce(0, +) / Double(heartRateData.count); return Int(avg) }
    
    // Speed chart to match Bike/Run style
    private var speedChartView: some View {
        Chart {
            ForEach(Array(routeLocations.enumerated()), id: \.offset) { index, location in
                if index > 0 {
                    let prev = routeLocations[index - 1]
                    let distance = prev.distance(from: location)
                    let dt = location.timestamp.timeIntervalSince(prev.timestamp)
                    if dt > 0 && distance > 0 {
                        let ms = distance / dt
                        let useMetric = UserPreferences.shared.useMetricSystem
                        let speed = useMetric ? ms * 3.6 : ms * 2.23694
                        LineMark(
                            x: .value("Point", Double(index)),
                            y: .value("Speed", speed)
                        )
                        .foregroundStyle(Color(hex: 0xFF9500))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .chartXAxis {
            AxisMarks {
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
    
    // MARK: - Helper Methods

    private func setupData() {
        if let coords = walk.coordinateArray, !coords.isEmpty {
            routePoints = coords.compactMap { coordDict in
                guard let lat = coordDict["latitude"] as? Double,
                      let lon = coordDict["longitude"] as? Double else {
                    return nil
                }
                return RoutePoint(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
            routeLocations = coords.compactMap { coordDict in
                guard let lat = coordDict["latitude"] as? Double,
                      let lon = coordDict["longitude"] as? Double else {
                    return nil
                }
                return CLLocation(latitude: lat, longitude: lon)
            }
            if !routeLocations.isEmpty {
                setMapRegion()
            }
        }
    }

    private func setMapRegion() {
        guard let first = routePoints.first else { return }
        mapRegion = MKCoordinateRegion(
            center: first.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    }
    
    private func calculatePaceConsistencyScore() -> Double {
        guard routeLocations.count > 2 else { return 50.0 }
        
        var paceValues: [Double] = []
        for i in 1..<routeLocations.count {
            let prev = routeLocations[i-1]
            let curr = routeLocations[i]
            let distance = prev.distance(from: curr)
            let time = curr.timestamp.timeIntervalSince(prev.timestamp)
            
            if distance > 10 && time > 0 {
                let pace = time / distance
                paceValues.append(pace)
            }
        }
        
        if paceValues.count > 1 {
            let avg = paceValues.reduce(0, +) / Double(paceValues.count)
            let variance = paceValues.reduce(0) { $0 + pow($1 - avg, 2) } / Double(paceValues.count)
            let stdDev = sqrt(variance)
            let consistencyScore = max(0, 100 - (stdDev * 10))
            return min(100, consistencyScore)
        }
        
        return 50.0
    }
    
    private func calculateDistanceScore() -> Double {
        guard let distanceStr = walk.distance else { return 50.0 }
        // Simple scoring based on distance - can be enhanced
        return min(100, 50 + 25)
    }
    
    private func calculateDurationScore() -> Double {
        guard let durationStr = walk.duration else { return 50.0 }
        // Simple scoring based on duration - can be enhanced
        return min(100, 50 + 25)
    }
    
    private func formatDistanceForChip() -> String {
        guard !routeLocations.isEmpty else { return "--" }
        var d: Double = 0
        for i in 1..<routeLocations.count { 
            d += routeLocations[i-1].distance(from: routeLocations[i]) 
        }
        let useMetric = UserPreferences.shared.useMetricSystem
        let val = useMetric ? d/1000.0 : d/1609.34
        return String(format: useMetric ? "%.2f km" : "%.2f mi", val)
    }
    
    private func formatPaceForChip() -> String {
        guard !routeLocations.isEmpty else { return "--" }
        let totalTime = routeLocations.last!.timestamp.timeIntervalSince(routeLocations.first!.timestamp)
        var totalDistance: Double = 0
        for i in 1..<routeLocations.count { 
            totalDistance += routeLocations[i-1].distance(from: routeLocations[i]) 
        }
        
        if totalTime > 0 && totalDistance > 0 {
            let paceSecondsPerMeter = totalTime / totalDistance
            let useMetric = UserPreferences.shared.useMetricSystem
            let paceValue = useMetric ? paceSecondsPerMeter * 1000 : paceSecondsPerMeter * 1609.34
            let minutes = Int(paceValue) / 60
            let seconds = Int(paceValue) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        return "--"
    }
    
    private func formatDurationForChip() -> String {
        guard !routeLocations.isEmpty else { return "--" }
        let totalTime = routeLocations.last!.timestamp.timeIntervalSince(routeLocations.first!.timestamp)
        let hours = Int(totalTime) / 3600
        let minutes = (Int(totalTime) % 3600) / 60
        let seconds = Int(totalTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // Chips for stats parity with Bike
    private func caloriesChip() -> String {
        if let c = walk.caloriesBurned { return String(format: "%.0f kcal", c) }
        return "-- kcal"
    }
    private func heartRateChip() -> String { return "-- bpm" }
    private func elevationGainChip() -> String { walk.elevationGain ?? "--" }
    private func stepsChip() -> String { walk.steps != nil ? String(walk.steps!) : "--" }
    
    private func metricChip(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
    }
    
    // MARK: - Split Calculation
    
    private struct WalkSplit {
        let unit: Int
        let pace: Double
        let time: Double
        let avgHeartRate: Double?
    }
    
    private func calculateWalkSplits() -> [WalkSplit] {
        guard routeLocations.count > 1 else { return [] }
        
        let useMetric = UserPreferences.shared.useMetricSystem
        let unitDistance: Double = useMetric ? 1000.0 : 1609.34 // 1km or 1mile in meters
        let unitName = useMetric ? "km" : "mile"
        
        // Sort locations by timestamp to ensure chronological order
        let sortedLocations = routeLocations.sorted(by: { $0.timestamp < $1.timestamp })
        
        var splits: [WalkSplit] = []
        var distSplit = Measurement(value: 0, unit: UnitLength.meters)
        var lastSplitTime: TimeInterval = 0
        var totalTime: TimeInterval = 0
        
        // Track heart rate for each split
        var currentSplitHeartRates: [Double] = []
        
        for i in 1..<sortedLocations.count {
            let newLocation = sortedLocations[i]
            let lastLocation = sortedLocations[i-1]
            
            let distance = newLocation.distance(from: lastLocation)
            distSplit = distSplit + Measurement(value: distance, unit: UnitLength.meters)
            
            let timeInterval = newLocation.timestamp.timeIntervalSince(lastLocation.timestamp)
            totalTime += timeInterval
            
            let distanceInUnits = distSplit.converted(to: useMetric ? .kilometers : .miles).value
            let completedUnits = floor(distanceInUnits)
            
            // Handle full units (km or miles)
            if completedUnits > Double(splits.count) {
                let splitTime = totalTime - lastSplitTime
                let pace: TimeInterval = splitTime / 1 // seconds per unit
                
                // Calculate average heart rate for this split (if available)
                let avgHeartRate = currentSplitHeartRates.isEmpty ? nil : currentSplitHeartRates.reduce(0, +) / Double(currentSplitHeartRates.count)
                
                splits.append(WalkSplit(
                    unit: Int(completedUnits),
                    pace: pace,
                    time: splitTime,
                    avgHeartRate: avgHeartRate
                ))
                
                lastSplitTime = totalTime
                
                // Reset for next split
                currentSplitHeartRates.removeAll()
            }
        }
        
        // Calculate the total distance and handle the remaining distance
        let totalDistanceInUnits = distSplit.converted(to: useMetric ? .kilometers : .miles).value
        let remainingDistance = totalDistanceInUnits - floor(totalDistanceInUnits)
        
        // Round up the remaining distance if it's above 0.95 units
        if remainingDistance > 0.95 {
            let finalUnit = Int(ceil(totalDistanceInUnits))
            let splitTime = totalTime - lastSplitTime
            let pace: TimeInterval = splitTime / max(remainingDistance, 0.0001)
            
            // Calculate average heart rate for the final split
            let avgHeartRate = currentSplitHeartRates.isEmpty ? nil : currentSplitHeartRates.reduce(0, +) / Double(currentSplitHeartRates.count)
            
            splits.append(WalkSplit(
                unit: finalUnit,
                pace: pace,
                time: splitTime,
                avgHeartRate: avgHeartRate
            ))
        }
        // Only add the last split if it's not a full unit or if it's the rounded up last unit
        else if remainingDistance > 0.2 && remainingDistance < 0.95 {
            let splitTime = totalTime - lastSplitTime
            let pace: TimeInterval = splitTime / max(remainingDistance, 0.0001)
            
            // Calculate average heart rate for the partial split
            let avgHeartRate = currentSplitHeartRates.isEmpty ? nil : currentSplitHeartRates.reduce(0, +) / Double(currentSplitHeartRates.count)
            
            // Use a special unit number to indicate partial split
            let partialUnit = splits.count + 1
            
            splits.append(WalkSplit(
                unit: partialUnit,
                pace: pace,
                time: splitTime,
                avgHeartRate: avgHeartRate
            ))
        }
        
        return splits
    }
    
    private func getTotalDistance() -> Double {
        guard !routeLocations.isEmpty else { return 0 }
        var total: Double = 0
        for i in 1..<routeLocations.count {
            total += routeLocations[i-1].distance(from: routeLocations[i])
        }
        return total
    }
    
    
    private func formatWalkSplitTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}


