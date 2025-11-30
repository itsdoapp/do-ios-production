//
//  WeatherService 2.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/14/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//


import Foundation
import CoreLocation
import SwiftUI
import struct Foundation.Date


class WeatherService: ObservableObject {
    // Singleton instance
    static let shared = WeatherService()
    
    @Published var currentWeather: WeatherData?
    @Published var isLoading = false
    @Published var error: Error?
    
    // Store the full weather response for forecast data
    private var currentWeatherResponse: MetNoResponse?
    
    // Cache management
    private var lastWeatherFetchTime: Date?
    private var cachedForecastTemperatures: [Double]?
    private var cachedForecastConditions: [WeatherCondition]?
    private var lastLocation: CLLocation?
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour in seconds
    // Add at top of class
    private var previouslyMappedSymbols: Set<String> = []
    
    // Met.no doesn't require an API key, just proper user agent identification
    private let appIdentifier = "Do-App/1.0 mikiyas@itsdoapp.com"
    
    private init() {
        // Initialize with empty data, fetch happens on demand
    }
    
    // MARK: - Public Methods
    
    /// Fetches current weather for the given location using Met.no API
    /// - Parameter location: The location to get weather for
    /// - Returns: A tuple containing the weather data and an optional error
    func fetchWeather(for location: CLLocation) async -> (WeatherData?, Error?) {
        // Check if we have valid cached data
        PerformanceLogger.start("Weather:fetch")
        if let lastFetchTime = lastWeatherFetchTime,
           let lastLoc = lastLocation,
           let cachedWeather = currentWeather,
           Date().timeIntervalSince(lastFetchTime) < cacheExpirationInterval,
           location.distance(from: lastLoc) < 1000 { // Only use cache if within 1km
            
            PerformanceLogger.end("Weather:fetch", extra: "cache hit (<1km & <1h)")
            return (cachedWeather, nil)
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            PerformanceLogger.start("Weather:network")
            let weatherDataFetched = try await getWeatherFromMetNo(for: location)
            PerformanceLogger.end("Weather:network")
            
            // Update UI state on main thread
            await MainActor.run {
                self.currentWeather = weatherDataFetched
                self.isLoading = false
                self.lastWeatherFetchTime = Date()
                self.lastLocation = location
            }
            
            PerformanceLogger.end("Weather:fetch", extra: "network")
            return (weatherDataFetched, nil)
        } catch {
            print("Weather fetch error: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
            PerformanceLogger.end("Weather:fetch", extra: "error")
            return (nil, error)
        }
    }
    
    // MARK: - Forecast Methods

    /// Gets forecast temperatures for the specified number of hours
    /// - Parameter hours: Number of hours to get forecast for (default 24)
    /// - Returns: Array of temperature values or nil if no forecast data available
    // OPTIMIZATION 1: Fix excessive forecast logging by making cached returns silent
func getForecastTemperatures(hours: Int = 24) -> [Double]? {
    // OPTIMIZATION: Return cached forecast if available and not expired (SILENT)
    if let lastFetchTime = lastWeatherFetchTime,
       let cachedTemps = cachedForecastTemperatures,
       Date().timeIntervalSince(lastFetchTime) < cacheExpirationInterval,
       cachedTemps.count >= hours {
        
        // SILENT RETURN - no logging for cached data to reduce noise
        return Array(cachedTemps.prefix(hours))
    }
    
    guard let weatherResponse = currentWeatherResponse else {
        // Only log when actually no data is available
        return nil
    }
    
    // Only process if we don't have cached data
    let forecasts = Array(weatherResponse.properties.timeseries.prefix(hours + 1))
    
    if forecasts.count > 1 {
        let hourlyTemps = forecasts.dropFirst().map { forecast in
            forecast.data.instant.details.air_temperature
        }
        
            // Cache the forecast temperatures
        self.cachedForecastTemperatures = hourlyTemps
        print("🌡️ Processed and cached \(hourlyTemps.count) hourly temperature forecasts")
        
        return hourlyTemps
    }
    
    return nil
}

func getForecastConditions(hours: Int = 24) -> [WeatherCondition]? {
    // OPTIMIZATION: Return cached conditions if available and not expired (SILENT)
    if let lastFetchTime = lastWeatherFetchTime,
       let cachedConditions = cachedForecastConditions,
       Date().timeIntervalSince(lastFetchTime) < cacheExpirationInterval,
       cachedConditions.count >= hours {
        
        // SILENT RETURN - no logging for cached data to reduce noise
        return Array(cachedConditions.prefix(hours))
    }
    
    guard let weatherResponse = currentWeatherResponse else {
        return nil
    }
    
    // Only process if we don't have cached data
    let forecasts = Array(weatherResponse.properties.timeseries.prefix(hours + 1))
    
    if forecasts.count > 1 {
        let hourlyConditions = forecasts.dropFirst().map { forecast -> WeatherCondition in
            let symbolCode = forecast.data.next_1_hours?.summary.symbol_code ??
                            forecast.data.next_6_hours?.summary.symbol_code ??
                            forecast.data.next_12_hours?.summary.symbol_code ?? "unknown"
            
            return mapToWeatherCondition(from: symbolCode)
        }
        
        // Cache the forecast conditions
        self.cachedForecastConditions = hourlyConditions
        print("🌤️ Processed and cached \(hourlyConditions.count) hourly weather condition forecasts")
        
        return hourlyConditions
    }
    
    return nil
}
    
    /// Clears the weather cache and forces a refresh on the next request
    func clearWeatherCache() {
        lastWeatherFetchTime = nil
        cachedForecastTemperatures = nil
        cachedForecastConditions = nil
        lastLocation = nil
    }
    
    // MARK: - Private Methods
    
    /// Gets weather data from Met.no API
    /// - Parameter location: The location for weather data
    /// - Returns: Weather data in our app's format
    public func getWeatherFromMetNo(for location: CLLocation) async throws -> WeatherData {
        // Log the requested location
        print("🌍 WeatherService: Fetching weather for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Format the URL with compact coordinates (Met.no prefers fewer decimal places)
        let latitude = String(format: "%.4f", location.coordinate.latitude)
        let longitude = String(format: "%.4f", location.coordinate.longitude)
        let urlString = "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=\(latitude)&lon=\(longitude)"
        
        print("🔗 WeatherService: Using URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        var request = URLRequest(url: url)
        // Met.no requires a proper User-Agent header
        request.addValue(appIdentifier, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Disable caching to ensure fresh data
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Print raw response for debugging
            print("📡 WeatherService: Raw response data size: \(data.count) bytes")
            if let jsonString = String(data: data, encoding: .utf8) {
                let preview = String(jsonString.prefix(200))
                print("📡 WeatherService: Response preview: \(preview)...")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WeatherError.invalidResponse
            }
            
            print("📡 WeatherService: Got response with status code: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                break // Success, continue processing
            case 400:
                throw WeatherError.invalidParameters
            case 403:
                throw WeatherError.unauthorized
            case 429:
                throw WeatherError.tooManyRequests
            case 500...599:
                throw WeatherError.serverError
            default:
                throw WeatherError.unexpectedStatusCode(httpResponse.statusCode)
            }
            
            // Parse the Met.no JSON response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let weatherResponse: MetNoResponse
            do {
                weatherResponse = try decoder.decode(MetNoResponse.self, from: data)
                // Store the response for later forecast access
                self.currentWeatherResponse = weatherResponse
                
                // Pre-cache forecast data
                _ = self.getForecastTemperatures(hours: 24)
                _ = self.getForecastConditions(hours: 24)
                
                // Log successful decoding
                print("✅ WeatherService: Successfully decoded weather response")
            } catch {
                print("❌ WeatherService: Decoding error: \(error)")
                throw WeatherError.decodingError(error)
            }
            
            // Get the current weather from the first timeseries
            guard let currentWeather = weatherResponse.properties.timeseries.first else {
                throw WeatherError.noWeatherData
            }
            
            // Get data from the instant details
            let details = currentWeather.data.instant.details
            
            // Get weather symbol from next 1 hour (Met.no provides this for the next periods)
            let symbolCode = currentWeather.data.next_1_hours?.summary.symbol_code ?? "unknown"
            
            // Extract precipitation data
            let precipitationAmount = currentWeather.data.next_1_hours?.details?.precipitation_amount
            
            // Log the actual temperature received from the API
            
            // Calculate precipitation chance based on cloud coverage and conditions
            // This is an approximation since Met.no doesn't provide direct precipitation probability
            var precipChance: Double? = nil
            // Use direct access to cloud_area_fraction since it's not optional
            let cloudCoverage = details.cloud_area_fraction
            // Base chance on cloud coverage
            if cloudCoverage > 80 {
                // High cloud coverage increases precipitation chance
                precipChance = cloudCoverage / 100.0 * 0.8
                
                // Further adjust based on weather condition
                if symbolCode.contains("rain") || symbolCode.contains("sleet") {
                    precipChance = min(1.0, precipChance! * 1.5) // Increase chance for rain conditions
                } else if symbolCode.contains("snow") {
                    precipChance = min(1.0, precipChance! * 1.3) // Slight increase for snow
                }
            } else if cloudCoverage > 50 {
                // Medium cloud coverage has moderate precipitation chance
                precipChance = cloudCoverage / 100.0 * 0.5
            } else if cloudCoverage > 20 {
                // Low cloud coverage has small precipitation chance
                precipChance = cloudCoverage / 100.0 * 0.2
            } else {
                // Very low cloud coverage means very low precipitation chance
                precipChance = 0.0
            }
            
            // If precipitation amount is available but chance isn't calculated, set a default
            if precipitationAmount != nil && precipitationAmount! > 0 && precipChance == nil {
                precipChance = 0.7 // Default probability if we know there's precipitation
            }
            
            // Create the weather data object
            let weatherData = WeatherData(
                temperature: details.air_temperature,
                condition: mapToWeatherCondition(from: symbolCode),
                humidity: details.relative_humidity / 100.0, // Convert from percentage to decimal
                windSpeed: details.wind_speed,
                timestamp: Date(),
                precipitationChance: precipChance,
                precipitationAmount: precipitationAmount
            )
            
            // Log temperature and conditions for debugging
            print("🌡️ WeatherService: Final temperature: \(weatherData.temperature)°C")
            if UserPreferences.shared.useMetricSystem == false {
                // Convert to Fahrenheit for log
                let fahrenheit = (weatherData.temperature * 9/5) + 32
                print("🌡️ WeatherService: Final temperature in Fahrenheit: \(fahrenheit)°F")
            }
            
            return weatherData
        } catch let urlError as URLError {
            print("❌ WeatherService: URL error: \(urlError.localizedDescription)")
            throw WeatherError.networkError(urlError)
        } catch {
            print("❌ WeatherService: General error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Maps Met.no weather symbol code to our app's weather condition
    /// - Parameter symbolCode: The Met.no symbol code
    /// - Returns: A WeatherCondition enum value from CommonTypes
    private func mapToWeatherCondition(from symbolCode: String) -> WeatherCondition {
        // Add debug information to see what symbol code we're receiving
        
        // Remove time of day suffix if present (e.g., "cloudy_day" -> "cloudy")
        let baseCode = symbolCode.replacingOccurrences(of: "_day", with: "")
                                .replacingOccurrences(of: "_night", with: "")
                                .replacingOccurrences(of: "_polartwilight", with: "")
        
        
        switch baseCode {
        // Clear conditions
        case "clearsky", "fair":
            return .clear
        
        // Partly cloudy conditions
        case "partlycloudy", "lightrainshowers", "lightsnowshowers", "lightsleetshowers":
            return .partlyCloudy
        
        // Cloudy conditions
        case "cloudy":
            return .cloudy
        
        // Foggy conditions
        case "fog":
            return .foggy
        
        // Rain conditions - expanded with more variants
        case let code where code.contains("rain") || code.contains("drizzle"):
            return .rainy
        
        // Sleet conditions
        case let code where code.contains("sleet"):
            return .rainy // Map sleet to rainy since we don't have a specific sleet condition
        
        // Snow conditions
        case let code where code.contains("snow"):
            return .snowy
        
        // Thunder conditions
        case let code where code.contains("thunder"):
            return .stormy
        
        // Wind conditions
        case let code where code.contains("wind"):
            return .windy
        
        // Default case with additional logging
        default:
            print("⚠️ WeatherService: Unknown weather symbol code: \(symbolCode)")
            
            // Try to make an educated guess based on the code
            if baseCode.contains("cloud") {
                return .cloudy
            } else if baseCode.contains("sun") || baseCode.contains("clear") {
                return .clear
            } else if baseCode.contains("shower") {
                return .rainy
            }
            
            return .unknown
        }
    }
    
    // MARK: - Weather Error Types
    
    enum WeatherError: LocalizedError {
        case invalidURL
        case invalidResponse
        case invalidParameters
        case unauthorized
        case tooManyRequests
        case serverError
        case networkError(URLError)
        case decodingError(Error)
        case noWeatherData
        case unexpectedStatusCode(Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL for weather data"
            case .invalidResponse:
                return "Invalid response from weather service"
            case .invalidParameters:
                return "Invalid parameters provided"
            case .unauthorized:
                return "Unauthorized access to weather service"
            case .tooManyRequests:
                return "Too many requests to weather service"
            case .serverError:
                return "Weather service server error"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .decodingError(let error):
                return "Failed to decode weather data: \(error.localizedDescription)"
            case .noWeatherData:
                return "No weather data available"
            case .unexpectedStatusCode(let code):
                return "Unexpected response code: \(code)"
            }
        }
    }
}

// MARK: - Met.no API Response Structures

struct MetNoResponse: Codable {
    let type: String
    let geometry: Geometry
    let properties: Properties
}

struct Geometry: Codable {
    let type: String
    let coordinates: [Double]
}

struct Properties: Codable {
    let meta: Meta
    let timeseries: [Timeseries]
}

struct Meta: Codable {
    let updated_at: String
    let units: Units
}

struct Units: Codable {
    let air_pressure_at_sea_level: String
    let air_temperature: String
    let cloud_area_fraction: String
    let relative_humidity: String
    let wind_from_direction: String
    let wind_speed: String
}

struct Timeseries: Codable {
    let time: String
    let data: TimeseriesData
}

struct TimeseriesData: Codable {
    let instant: Instant
    let next_1_hours: NextHours?
    let next_6_hours: NextHours?
    let next_12_hours: NextHours?
}

struct Instant: Codable {
    let details: InstantDetails
}

struct InstantDetails: Codable {
    let air_pressure_at_sea_level: Double?
    let air_temperature: Double
    let cloud_area_fraction: Double
    let relative_humidity: Double
    let wind_from_direction: Double
    let wind_speed: Double
}

struct NextHours: Codable {
    let summary: Summary
    let details: NextHoursDetails?
}

struct Summary: Codable {
    let symbol_code: String
}

struct NextHoursDetails: Codable {
    let precipitation_amount: Double?
}

// OpenWeather API Response Models
struct OpenWeatherResponse: Codable {
    let weather: [Weather]
    let main: Main
    let wind: Wind
}

struct Weather: Codable {
    let main: String
    let description: String
    let icon: String
}

struct Main: Codable {
    let temp: Double
    let humidity: Double
    let pressure: Double
}

struct Wind: Codable {
    let speed: Double
    let deg: Double
}

struct OpenWeatherAirQualityResponse: Codable {
    let list: [AirQualityList]
}

struct AirQualityList: Codable {
    let main: AirQualityMain
}

struct AirQualityMain: Codable {
    let aqi: Int
}

/// Weather conditions that can be used to describe current weather
public enum WeatherCondition: String, Codable, CaseIterable, Equatable {
    case clear = "Clear"
    case cloudy = "Cloudy"
    case partlyCloudy = "Partly Cloudy"
    case rainy = "Rainy"
    case snowy = "Snowy"
    case stormy = "Stormy"
    case foggy = "Foggy"
    case windy = "Windy"
    case unknown = "Unknown"
    
    public var displayName: String { rawValue }
    
    public var icon: String {
        switch self {
        case .clear: return isNight ? "moon.stars.fill" : "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .rainy: return "cloud.rain.fill"
        case .snowy: return "cloud.snow.fill"
        case .stormy: return "cloud.bolt.fill"
        case .foggy: return "cloud.fog.fill"
        case .windy: return "wind"
        case .unknown: return "questionmark.circle"
        }
    }
    
    // Computed property to check if it's night time
    private var isNight: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 19 || hour < 6
    }
    
    public var color: Color {
        switch self {
        case .clear: return isNight ? .indigo : .yellow
        case .cloudy: return .gray
        case .partlyCloudy: return .blue
        case .rainy: return .blue
        case .snowy: return .white
        case .stormy: return .purple
        case .foggy: return .gray
        case .windy: return .cyan
        case .unknown: return .secondary
        }
    }
    
    /// Determines the appropriate weather condition from a string description
    /// - Parameter description: A string describing the weather condition
    /// - Returns: The corresponding WeatherCondition enum case
    public static func determineCondition(from description: String) -> WeatherCondition {
        let lowercased = description.lowercased()
        
        // Check if it's night time
        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = hour >= 19 || hour < 6
        
        if lowercased.contains("sunny") || lowercased.contains("clear") {
            return .clear // Always return clear, day/night is handled by the icon
        } else if lowercased.contains("partly cloudy") || lowercased.contains("mostly sunny") {
            return .partlyCloudy
        } else if lowercased.contains("cloudy") || lowercased.contains("overcast") {
            return .cloudy
        } else if lowercased.contains("rain") || lowercased.contains("shower") {
            return .rainy
        } else if lowercased.contains("snow") || lowercased.contains("flurry") {
            return .snowy
        } else if lowercased.contains("storm") || lowercased.contains("thunder") || lowercased.contains("lightning") {
            return .stormy
        } else if lowercased.contains("fog") || lowercased.contains("mist") {
            return .foggy
        } else if lowercased.contains("wind") || lowercased.contains("breezy") {
            return .windy
        } else {
            return .unknown
        }
    }
}

/// Weather data structure used throughout the app
public struct WeatherData {
    var temperature: Double
    var condition: WeatherCondition
    var humidity: Double
    var windSpeed: Double
    var timestamp: Date
    var precipitationChance: Double? = nil
    var precipitationAmount: Double? = nil
}
