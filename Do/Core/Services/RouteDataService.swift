//
//  RouteDataService.swift
//  Do
//
//  Service for fetching route/location data from S3
//

import Foundation
import CoreLocation

class RouteDataService {
    static let shared = RouteDataService()
    
    private let session: URLSession
    private var cache: [String: [CLLocationCoordinate2D]] = [:]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
        self.session = URLSession(configuration: config)
    }
    
    /// Fetch route coordinates from S3 URL
    func fetchRouteData(from url: String) async throws -> [CLLocationCoordinate2D] {
        // Check cache first
        if let cached = cache[url] {
            print("📍 [RouteData] Using cached route data for \(url)")
            return cached
        }
        
        guard let requestUrl = URL(string: url) else {
            throw RouteDataError.invalidURL
        }
        
        print("📍 [RouteData] Fetching route data from S3: \(url)")
        
        let (data, response) = try await session.data(from: requestUrl)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RouteDataError.fetchFailed
        }
        
        // Parse JSON route data
        let coordinates = try parseRouteData(data)
        
        // Cache the result
        cache[url] = coordinates
        
        print("✅ [RouteData] Fetched \(coordinates.count) route points")
        
        return coordinates
    }
    
    /// Parse route data from JSON
    private func parseRouteData(_ data: Data) throws -> [CLLocationCoordinate2D] {
        let decoder = JSONDecoder()
        
        // Try parsing as array of coordinate objects
        if let coordinateArray = try? decoder.decode([RouteCoordinate].self, from: data) {
            return coordinateArray.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
        
        // Try parsing as wrapper object
        if let wrapper = try? decoder.decode(RouteDataWrapper.self, from: data) {
            return wrapper.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
        
        throw RouteDataError.invalidFormat
    }
    
    /// Decode polyline string to coordinates
    func decodePolyline(_ encodedPolyline: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encodedPolyline.startIndex
        var lat = 0
        var lng = 0
        
        while index < encodedPolyline.endIndex {
            var b: Int
            var shift = 0
            var result = 0
            
            repeat {
                b = Int(encodedPolyline[index].asciiValue! - 63)
                index = encodedPolyline.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20
            
            let dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lat += dlat
            
            shift = 0
            result = 0
            
            repeat {
                b = Int(encodedPolyline[index].asciiValue! - 63)
                index = encodedPolyline.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20
            
            let dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lng += dlng
            
            let latitude = Double(lat) / 1e5
            let longitude = Double(lng) / 1e5
            
            coordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
        
        return coordinates
    }
    
    /// Clear cache
    func clearCache() {
        cache.removeAll()
        print("🗑 [RouteData] Cache cleared")
    }
}

// MARK: - Models

struct RouteCoordinate: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let timestamp: String?
}

struct RouteDataWrapper: Codable {
    let coordinates: [RouteCoordinate]
    let metadata: RouteMetadata?
}

struct RouteMetadata: Codable {
    let distance: Double?
    let duration: Double?
    let elevationGain: Double?
    let elevationLoss: Double?
}

// MARK: - Errors

enum RouteDataError: Error {
    case invalidURL
    case fetchFailed
    case invalidFormat
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid route data URL"
        case .fetchFailed:
            return "Failed to fetch route data from S3"
        case .invalidFormat:
            return "Invalid route data format"
        }
    }
}
