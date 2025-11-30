import Foundation
import Combine

/// Service for fetching and caching running history from AWS
/// Handles S3 route data fetching and provides cached data to views
class RunHistoryService: ObservableObject {
    static let shared = RunHistoryService()
    
    // Published properties for SwiftUI observation
    @Published var outdoorRuns: [RunLog] = [] {
        didSet {
            // Notify observers when runs update (for progressive updates)
            print("📊 [RunHistoryService] outdoorRuns updated: \(outdoorRuns.count) runs")
        }
    }
    @Published var indoorRuns: [IndoorRunLog] = [] {
        didSet {
            // Notify observers when runs update (for progressive updates)
            print("📊 [RunHistoryService] indoorRuns updated: \(indoorRuns.count) runs")
        }
    }
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date?
    
    // Cache timestamp for freshness checking
    private var cacheTimestamp: Date?
    private let cacheExpirationInterval: TimeInterval = 86400 // 24 hours - cache is long-lived
    
    // Loading state
    private var isLoadingRuns = false
    private var loadStartTime: Date?
    
    private init() {
        // Load from cache if available
        loadFromCache()
    }
    
    // MARK: - Public Methods
    
    /// Load runs from cache or fetch if needed
    func loadRuns(forceRefresh: Bool = false, completion: ((Error?) -> Void)? = nil) {
        // Check if we should use cache
        if !forceRefresh && !outdoorRuns.isEmpty && !indoorRuns.isEmpty {
            let isCacheStale = cacheTimestamp.map { Date().timeIntervalSince($0) > cacheExpirationInterval } ?? true
            
            if !isCacheStale {
                print("✅ [RunHistoryService] Using fresh cache - \(outdoorRuns.count) outdoor, \(indoorRuns.count) indoor")
                completion?(nil)
                return
            }
        }
        
        // Prevent overlapping requests
        if isLoadingRuns {
            if let started = loadStartTime, Date().timeIntervalSince(started) > 30 {
                print("⚠️ [RunHistoryService] Previous load timed out, resetting...")
                isLoadingRuns = false
            } else {
                print("⚠️ [RunHistoryService] Already loading, skipping request")
                completion?(NSError(domain: "RunHistoryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Already loading"]))
                return
            }
        }
        
        isLoadingRuns = true
        isLoading = true
        loadStartTime = Date()
        
        guard let userId = UserIDHelper.shared.getCurrentUserID(), !userId.isEmpty else {
            let error = NSError(domain: "RunHistoryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user ID"])
            isLoadingRuns = false
            isLoading = false
            completion?(error)
            return
        }
        
        print("📥 [RunHistoryService] Fetching runs from AWS...")
        fetchAllRuns(userId: userId) { [weak self] outdoorRuns, indoorRuns, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoadingRuns = false
                self.isLoading = false
                self.loadStartTime = nil
                
                if let error = error {
                    print("❌ [RunHistoryService] Error fetching runs: \(error.localizedDescription)")
                    completion?(error)
                    return
                }
                
                // Update cache
                self.outdoorRuns = outdoorRuns
                self.indoorRuns = indoorRuns
                self.cacheTimestamp = Date()
                self.lastUpdated = Date()
                
                // Verify locationData is present
                let runsWithLocationData = outdoorRuns.filter { $0.locationData != nil && !($0.locationData?.isEmpty ?? true) }
                print("✅ [RunHistoryService] Loaded \(outdoorRuns.count) outdoor, \(indoorRuns.count) indoor runs")
                print("   📍 \(runsWithLocationData.count) outdoor runs have locationData")
                
                // Log sample run IDs that have locationData
                if !runsWithLocationData.isEmpty {
                    let sampleIds = runsWithLocationData.prefix(3).compactMap { $0.id }
                    print("   Sample runs with locationData: \(sampleIds.joined(separator: ", "))")
                }
                
                // Save to disk cache
                self.saveToCache()
                
                completion?(nil)
            }
        }
    }
    
    /// Get all runs (outdoor + indoor) sorted by date
    func getAllRuns() -> [Any] {
        var all: [Any] = []
        all.append(contentsOf: outdoorRuns)
        all.append(contentsOf: indoorRuns)
        return all.sorted { (first, second) -> Bool in
            let firstDate = self.getDate(from: first)
            let secondDate = self.getDate(from: second)
            guard let firstDate = firstDate, let secondDate = secondDate else { return false }
            return firstDate > secondDate
        }
    }
    
    /// Check if cache is stale (only if very old - 24 hours)
    /// Cache should primarily be updated manually after runs are saved
    func isCacheStale() -> Bool {
        guard let timestamp = cacheTimestamp else { return true }
        let age = Date().timeIntervalSince(timestamp)
        // Only consider stale if older than 24 hours
        return age > cacheExpirationInterval
    }
    
    /// Add a newly saved run to the cache without fetching all runs
    /// Call this after saving a run to update the cache immediately
    func addRunToCache(_ run: RunLog) {
        DispatchQueue.main.async {
            // Add to beginning of array (newest first)
            self.outdoorRuns.insert(run, at: 0)
            self.cacheTimestamp = Date()
            self.lastUpdated = Date()
            self.saveToCache()
            print("✅ [RunHistoryService] Added new run to cache: \(run.id ?? "unknown")")
        }
    }
    
    /// Add a newly saved indoor run to the cache
    func addIndoorRunToCache(_ run: IndoorRunLog) {
        DispatchQueue.main.async {
            // Add to beginning of array (newest first)
            self.indoorRuns.insert(run, at: 0)
            self.cacheTimestamp = Date()
            self.lastUpdated = Date()
            self.saveToCache()
            print("✅ [RunHistoryService] Added new indoor run to cache: \(run.id ?? "unknown")")
        }
    }
    
    /// Refresh cache after saving a run - fetches latest to ensure consistency
    /// Use this after saving a run to get the fully processed version from AWS
    func refreshAfterSave(completion: ((Error?) -> Void)? = nil) {
        // Only refresh if cache exists and is not too recent (avoid redundant calls)
        if let timestamp = cacheTimestamp, Date().timeIntervalSince(timestamp) < 60 {
            // Cache was updated less than a minute ago, skip refresh
            print("📥 [RunHistoryService] Cache recently updated, skipping refresh")
            completion?(nil)
            return
        }
        
        print("🔄 [RunHistoryService] Refreshing cache after run save...")
        loadRuns(forceRefresh: true, completion: completion)
    }
    
    // MARK: - Private Methods
    
    private func fetchAllRuns(userId: String, completion: @escaping ([RunLog], [IndoorRunLog], Error?) -> Void) {
        var allOutdoorRuns: [RunLog] = []
        var allIndoorRuns: [IndoorRunLog] = []
        
        func fetchPage(nextToken: String?) {
            ActivityService.shared.getRuns(
                userId: userId,
                limit: 100,
                nextToken: nextToken,
                includeRouteUrls: true
            ) { result in
                switch result {
                case .success(let response):
                    guard let data = response.data else {
                        completion(allOutdoorRuns, allIndoorRuns, nil)
                        return
                    }
                    
                    // Convert activities
                    var outdoorLogs: [RunLog] = []
                    var indoorLogs: [IndoorRunLog] = []
                    var runsNeedingRouteData: [(pageIndex: Int, runLog: RunLog, routeDataUrl: String)] = []
                    
                    for activity in data.activities {
                        if activity.isIndoorRun {
                            if let indoorLog = self.convertToIndoorRunLog(activity) {
                                indoorLogs.append(indoorLog)
                            }
                        } else {
                            if var runLog = self.convertToRunLog(activity) {
                                // Check if we need to fetch route data
                                let hasLocationData = runLog.locationData != nil && !(runLog.locationData?.isEmpty ?? true)
                                // Log detailed information about route data availability
                                print("🔍 [RunHistoryService] Run \(runLog.id ?? "unknown"):")
                                print("   - routeDataUrl: \(activity.routeDataUrl ?? "nil")")
                                print("   - routeDataS3Key: \(activity.routeDataS3Key ?? "nil")")
                                print("   - hasLocationData: \(hasLocationData)")
                                print("   - locationData count: \(runLog.locationData?.count ?? 0)")
                                
                                if !hasLocationData, let routeDataUrl = activity.routeDataUrl {
                                    // Track page index (relative to current page)
                                    print("📍 [RunHistoryService] Run \(runLog.id ?? "unknown") needs route data from S3: \(routeDataUrl)")
                                    runsNeedingRouteData.append((pageIndex: outdoorLogs.count, runLog: runLog, routeDataUrl: routeDataUrl))
                                } else if hasLocationData {
                                    print("✅ [RunHistoryService] Run \(runLog.id ?? "unknown") already has locationData (\(runLog.locationData?.count ?? 0) points)")
                                } else if activity.routeDataUrl == nil {
                                    print("⚠️ [RunHistoryService] Run \(runLog.id ?? "unknown") has no routeDataUrl - checking if route exists in activityData...")
                                    // Check if route might be in activityData
                                    if let activityDataString = activity.activityData {
                                        print("   - activityData exists (length: \(activityDataString.count))")
                                    }
                                }
                                outdoorLogs.append(runLog)
                            }
                        }
                    }
                    
                    // Append to accumulated arrays
                    let currentOutdoorStartIndex = allOutdoorRuns.count
                    allOutdoorRuns.append(contentsOf: outdoorLogs)
                    allIndoorRuns.append(contentsOf: indoorLogs)
                    
                    // PROGRESSIVE UPDATE: Update published arrays immediately so views can see new data
                    DispatchQueue.main.async {
                        self.outdoorRuns = allOutdoorRuns
                        self.indoorRuns = allIndoorRuns
                        print("📊 [RunHistoryService] Progressive update: \(allOutdoorRuns.count) outdoor, \(allIndoorRuns.count) indoor runs")
                    }
                    
                    // Fetch route data for runs that need it (using global index)
                    if !runsNeedingRouteData.isEmpty {
                        print("📥 [RunHistoryService] Fetching route data for \(runsNeedingRouteData.count) runs from S3...")
                        // Convert page indices to global indices
                        let runsWithGlobalIndices = runsNeedingRouteData.map { (currentOutdoorStartIndex + $0.pageIndex, $0.runLog, $0.routeDataUrl) }
                        
                        self.fetchRouteDataForRuns(runsWithGlobalIndices) { updatedRuns in
                            // Update runs in the accumulated array with route data
                            print("🔄 [RunHistoryService] Updating \(updatedRuns.count) runs with route data...")
                            for (globalIndex, updatedRun) in updatedRuns {
                                if globalIndex < allOutdoorRuns.count {
                                    allOutdoorRuns[globalIndex] = updatedRun
                                    let pointCount = updatedRun.locationData?.count ?? 0
                                    print("✅ [RunHistoryService] Updated run at global index \(globalIndex) (ID: \(updatedRun.id ?? "unknown")) with \(pointCount) location points")
                                } else {
                                    print("⚠️ [RunHistoryService] Index \(globalIndex) out of bounds (array size: \(allOutdoorRuns.count))")
                                }
                            }
                            
                            // PROGRESSIVE UPDATE: Update published arrays with route data
                            DispatchQueue.main.async {
                                self.outdoorRuns = allOutdoorRuns
                                self.indoorRuns = allIndoorRuns
                            }
                            
                            // Verify updates
                            let runsWithLocationData = allOutdoorRuns.filter { $0.locationData != nil && !($0.locationData?.isEmpty ?? true) }
                            print("📊 [RunHistoryService] After route data fetch: \(runsWithLocationData.count) runs have locationData out of \(allOutdoorRuns.count) total")
                            
                            // Continue pagination
                            if data.hasMore, let token = data.nextToken {
                                fetchPage(nextToken: token)
                            } else {
                                // Final update
                                DispatchQueue.main.async {
                                    self.outdoorRuns = allOutdoorRuns
                                    self.indoorRuns = allIndoorRuns
                                }
                                // Final check before completion
                                let finalRunsWithLocationData = allOutdoorRuns.filter { $0.locationData != nil && !($0.locationData?.isEmpty ?? true) }
                                print("✅ [RunHistoryService] Fetch complete: \(allOutdoorRuns.count) outdoor runs, \(finalRunsWithLocationData.count) have locationData")
                                completion(allOutdoorRuns, allIndoorRuns, nil)
                            }
                        }
                    } else {
                        // No route data needed, continue pagination
                        if data.hasMore, let token = data.nextToken {
                            fetchPage(nextToken: token)
                        } else {
                            // Final update
                            DispatchQueue.main.async {
                                self.outdoorRuns = allOutdoorRuns
                                self.indoorRuns = allIndoorRuns
                            }
                            completion(allOutdoorRuns, allIndoorRuns, nil)
                        }
                    }
                    
                case .failure(let error):
                    completion(allOutdoorRuns, allIndoorRuns, error)
                }
            }
        }
        
        fetchPage(nextToken: nil)
    }
    
    private func fetchRouteDataForRuns(_ runs: [(index: Int, runLog: RunLog, routeDataUrl: String)], completion: @escaping ([(Int, RunLog)]) -> Void) {
        let group = DispatchGroup()
        var updatedRuns: [(Int, RunLog)] = []
        let queue = DispatchQueue(label: "com.do.runRouteFetch", attributes: .concurrent)
        
        for (index, runLog, routeDataUrl) in runs {
            group.enter()
            queue.async {
                ActivityService.shared.fetchRouteData(from: routeDataUrl) { result in
                    var updatedRun = runLog
                    
                    switch result {
                    case .success(let routeData):
                        // Convert route data to locationData format
                        let locationData = routeData.points.map { point -> [String: Any] in
                            var location: [String: Any] = [
                                "latitude": point.latitude,
                                "longitude": point.longitude,
                                "altitude": point.altitude ?? 0,
                                "horizontalAccuracy": point.horizontalAccuracy ?? 0,
                                "verticalAccuracy": point.verticalAccuracy ?? 0,
                                "speed": point.speed ?? 0,
                                "course": point.course ?? 0
                            ]
                            
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            if let timestamp = formatter.date(from: point.timestamp) {
                                location["timestamp"] = timestamp.timeIntervalSince1970
                            }
                            
                            if let heartRate = point.heartRate {
                                location["heartRate"] = heartRate
                            }
                            if let cadence = point.cadence {
                                location["cadence"] = cadence
                            }
                            
                            return location
                        }
                        
                        updatedRun.locationData = locationData
                        print("✅ [RunHistoryService] Fetched route data for run \(runLog.id ?? "unknown"): \(locationData.count) points")
                        
                    case .failure(let error):
                        print("⚠️ [RunHistoryService] Failed to fetch route data: \(error.localizedDescription)")
                    }
                    
                    updatedRuns.append((index, updatedRun))
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(updatedRuns)
        }
    }
    
    /// Fetch route data for a single run (used when opening run analysis)
    func fetchRouteDataForSingleRun(_ runLog: RunLog, completion: @escaping (RunLog?) -> Void) {
        guard let routeDataUrl = runLog.routeDataUrl else {
            print("⚠️ [RunHistoryService] No routeDataUrl for run \(runLog.id ?? "unknown")")
            completion(nil)
            return
        }
        
        print("📥 [RunHistoryService] Fetching route data for run \(runLog.id ?? "unknown") from: \(routeDataUrl)")
        
        ActivityService.shared.fetchRouteData(from: routeDataUrl) { result in
            var updatedRun = runLog
            
            switch result {
            case .success(let routeData):
                // Convert route data to locationData format
                let locationData = routeData.points.map { point -> [String: Any] in
                    var location: [String: Any] = [
                        "latitude": point.latitude,
                        "longitude": point.longitude,
                        "altitude": point.altitude ?? 0,
                        "horizontalAccuracy": point.horizontalAccuracy ?? 0,
                        "verticalAccuracy": point.verticalAccuracy ?? 0,
                        "speed": point.speed ?? 0,
                        "course": point.course ?? 0
                    ]
                    
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let timestamp = formatter.date(from: point.timestamp) {
                        location["timestamp"] = timestamp.timeIntervalSince1970
                    }
                    
                    if let heartRate = point.heartRate {
                        location["heartRate"] = heartRate
                    }
                    if let cadence = point.cadence {
                        location["cadence"] = cadence
                    }
                    
                    return location
                }
                
                updatedRun.locationData = locationData
                print("✅ [RunHistoryService] Successfully fetched \(locationData.count) location points for run \(runLog.id ?? "unknown")")
                completion(updatedRun)
                
            case .failure(let error):
                print("❌ [RunHistoryService] Failed to fetch route data for run \(runLog.id ?? "unknown"): \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Conversion Methods
    
    private func convertToRunLog(_ activity: AWSActivity) -> RunLog? {
        guard !activity.isIndoorRun else { return nil }
        
        var runLog = RunLog()
        runLog.id = activity.id
        
        // Convert date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: activity.createdAt) {
            runLog.createdAt = date
        } else {
            dateFormatter.formatOptions = [.withInternetDateTime]
            runLog.createdAt = dateFormatter.date(from: activity.createdAt)
        }
        
        // Format distance
        let distanceMiles = activity.distance / 1609.34
        runLog.distance = String(format: "%.2f mi", distanceMiles)
        
        // Format duration
        let hours = Int(activity.duration) / 3600
        let minutes = (Int(activity.duration) % 3600) / 60
        let seconds = Int(activity.duration) % 60
        if hours > 0 {
            runLog.duration = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            runLog.duration = String(format: "%d:%02d", minutes, seconds)
        }
        
        // Calculate pace
        let minutesPerMile = activity.duration / 60.0 / max(distanceMiles, 0.0001)
        let paceMin = Int(minutesPerMile)
        let paceSec = Int((minutesPerMile - Double(paceMin)) * 60)
        runLog.avgPace = String(format: "%d'%02d\" /mi", paceMin, paceSec)
        
        // Set metrics
        runLog.caloriesBurned = activity.calories
        runLog.avgHeartRate = activity.avgHeartRate
        runLog.maxHeartRate = activity.maxHeartRate
        
        // Handle elevation
        if let elevationGain = activity.elevationGain {
            runLog.elevationGain = String(format: "%.0f", elevationGain * 3.28084)
        }
        if let elevationLoss = activity.elevationLoss {
            runLog.elevationLoss = String(format: "%.0f", elevationLoss * 3.28084)
        }
        
        // Store route data URL
        runLog.routeDataUrl = activity.routeDataUrl
        
        // Parse activityData if available
        if let activityDataString = activity.activityData,
           let data = activityDataString.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let locationsArray = json["locationData"] as? [[String: Any]] {
                        runLog.locationData = locationsArray
                    }
                    if let weather = json["weather"] as? String {
                        runLog.weather = weather
                    }
                    if let temperature = json["temperature"] as? Double {
                        runLog.temperature = temperature
                    }
                }
            } catch {
                print("⚠️ [RunHistoryService] Failed to parse activityData: \(error)")
            }
        }
        
        return runLog
    }
    
    private func convertToIndoorRunLog(_ activity: AWSActivity) -> IndoorRunLog? {
        guard activity.isIndoorRun else { return nil }
        
        // Convert date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var createdAt: Date?
        if let date = dateFormatter.date(from: activity.createdAt) {
            createdAt = date
        } else {
            dateFormatter.formatOptions = [.withInternetDateTime]
            createdAt = dateFormatter.date(from: activity.createdAt)
        }
        
        let dateFormatterString = DateFormatter()
        dateFormatterString.dateFormat = "MMMM d, yyyy"
        let createdAtFormatted = createdAt != nil ? dateFormatterString.string(from: createdAt!) : nil
        
        // Format distance
        let distanceMiles = activity.distance / 1609.34
        let distanceString = String(format: "%.2f mi", distanceMiles)
        
        // Format duration
        let hours = Int(activity.duration) / 3600
        let minutes = (Int(activity.duration) % 3600) / 60
        let seconds = Int(activity.duration) % 60
        let durationString: String
        if hours > 0 {
            durationString = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            durationString = String(format: "%d:%02d", minutes, seconds)
        }
        
        // Calculate pace
        let minutesPerMile = activity.duration / 60.0 / max(distanceMiles, 0.0001)
        let paceMin = Int(minutesPerMile)
        let paceSec = Int((minutesPerMile - Double(paceMin)) * 60)
        let avgPaceString = String(format: "%d'%02d\" /mi", paceMin, paceSec)
        
        // Create IndoorRunLog
        var indoorLog = IndoorRunLog()
        indoorLog.id = activity.id
        indoorLog.createdAt = createdAt
        indoorLog.createdAtFormatted = createdAtFormatted
        indoorLog.distance = distanceString
        indoorLog.duration = durationString
        indoorLog.avgPace = avgPaceString
        indoorLog.caloriesBurned = activity.calories
        indoorLog.createdBy = nil
        indoorLog.runType = activity.runType ?? "treadmill_run"
        indoorLog.avgHeartRate = activity.avgHeartRate
        indoorLog.maxHeartRate = activity.maxHeartRate
        
        return indoorLog
    }
    
    private func getDate(from run: Any) -> Date? {
        if let runLog = run as? RunLog {
            return runLog.createdAt
        } else if let indoorLog = run as? IndoorRunLog {
            return indoorLog.createdAt
        }
        return nil
    }
    
    // MARK: - Cache Management
    
    private func saveToCache() {
        // Save to UserDefaults for persistence
        // Note: We only save IDs and basic info to avoid memory issues
        let cache: [String: Any] = [
            "timestamp": cacheTimestamp?.timeIntervalSince1970 ?? 0,
            "outdoorCount": outdoorRuns.count,
            "indoorCount": indoorRuns.count
        ]
        UserDefaults.standard.set(cache, forKey: "runHistoryCacheMetadata")
    }
    
    private func loadFromCache() {
        // Load metadata to check if we have cached data
        if let metadata = UserDefaults.standard.dictionary(forKey: "runHistoryCacheMetadata"),
           let timestamp = metadata["timestamp"] as? TimeInterval {
            cacheTimestamp = Date(timeIntervalSince1970: timestamp)
            print("📥 [RunHistoryService] Loaded cache metadata")
        }
    }
}

