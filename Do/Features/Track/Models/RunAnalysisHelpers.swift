//
//  RunAnalysisHelpers.swift
//  Do
//
//  Helper types for run analysis and visualization
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import MapKit
import UIKit

// MARK: - TreadmillImageData

/// Data extracted from treadmill display image using OCR/ML
struct TreadmillImageData {
    var distance: Double // in meters
    var duration: TimeInterval // in seconds
    var pace: Double? // seconds per meter
    var calories: Double?
    var incline: Double? // percentage
    var speed: Double? // meters per second
    var confidence: Double // 0.0 to 1.0
    var rawExtractedText: String?
    var distanceInMiles: Bool // true if original distance was in miles
    var speedInMph: Bool? // true if original speed was in mph
    
    init(distance: Double,
         duration: TimeInterval,
         pace: Double? = nil,
         calories: Double? = nil,
         incline: Double? = nil,
         speed: Double? = nil,
         confidence: Double = 0.0,
         rawExtractedText: String? = nil,
         distanceInMiles: Bool = false,
         speedInMph: Bool? = nil) {
        self.distance = distance
        self.duration = duration
        self.pace = pace
        self.calories = calories
        self.incline = incline
        self.speed = speed
        self.confidence = confidence
        self.rawExtractedText = rawExtractedText
        self.distanceInMiles = distanceInMiles
        self.speedInMph = speedInMph
    }
    
    /// Returns distance in meters
    func distanceInMeters() -> Double {
        if distanceInMiles {
            return distance // Already converted to meters in initializer
        }
        return distance
    }
    
    /// Returns distance in miles
    func distanceInMilesValue() -> Double {
        return distanceInMeters() / 1609.34
    }
    
    /// Returns speed in mph if available
    func speedInMphValue() -> Double? {
        guard let speed = speed else { return nil }
        if speedInMph == true {
            return speed
        }
        // Convert m/s to mph
        return speed * 2.23694
    }
}

// MARK: - MulticolorPolyline

/// Custom MKPolyline subclass that supports per-segment coloring for speed visualization
class MulticolorPolyline: MKPolyline {
    var color: UIColor = .orange
    
    convenience init(coordinates: [CLLocationCoordinate2D], count: Int, color: UIColor = .orange) {
        var coords = coordinates
        self.init(coordinates: &coords, count: count)
        self.color = color
    }
}

// MARK: - RunRoutePolyline

/// Custom MKPolyline subclass for route visualization with color, width, and glow support
class RunRoutePolyline: MKPolyline {
    var color = UIColor.black
    var lineWidth: CGFloat = 4.0  // Default line width
    var glowRadius: CGFloat = 0.0 // Default glow radius (0 = no glow)
    var glowColor = UIColor.white.withAlphaComponent(0.5)
}

// MARK: - RunVideoPreviewViewController

/// View controller for displaying run video preview/animation
class RunVideoPreviewViewController: UIViewController {
    
    // MARK: - Properties
    
    private let runData: RunLog
    private var mapView: MKMapView!
    private var playButton: UIButton!
    private var progressSlider: UISlider!
    private var isPlaying = false
    private var animationTimer: Timer?
    private var currentProgress: Double = 0.0
    
    // MARK: - Initialization
    
    init(runData: RunLog) {
        self.runData = runData
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMapView()
        loadRouteData()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup map view
        mapView = MKMapView()
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.mapType = .mutedStandard
        mapView.showsUserLocation = false
        view.addSubview(mapView)
        
        // Setup play button
        playButton = UIButton(type: .system)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.setTitle("▶️ Play", for: .normal)
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        view.addSubview(playButton)
        
        // Setup progress slider
        progressSlider = UISlider()
        progressSlider.translatesAutoresizingMaskIntoConstraints = false
        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        progressSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        view.addSubview(progressSlider)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: playButton.topAnchor, constant: -20),
            
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.bottomAnchor.constraint(equalTo: progressSlider.topAnchor, constant: -10),
            playButton.widthAnchor.constraint(equalToConstant: 100),
            playButton.heightAnchor.constraint(equalToConstant: 44),
            
            progressSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressSlider.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupMapView() {
        mapView.delegate = self
    }
    
    private func loadRouteData() {
        // Load route from run data
        guard let locationData = runData.locationData else { return }
        
        var locations: [CLLocation] = []
        for dict in locationData {
            if let lat = dict["latitude"] as? Double,
               let lon = dict["longitude"] as? Double {
                let location = CLLocation(latitude: lat, longitude: lon)
                locations.append(location)
            }
        }
        
        // Add route polyline
        if locations.count > 1 {
            let polylines = createMulticolorPolylines(from: locations)
            for polyline in polylines {
                mapView.addOverlay(polyline)
            }
            
            // Set map region to show entire route
            if let first = locations.first?.coordinate, let last = locations.last?.coordinate {
                let center = CLLocationCoordinate2D(
                    latitude: (first.latitude + last.latitude) / 2,
                    longitude: (first.longitude + last.longitude) / 2
                )
                let span = MKCoordinateSpan(
                    latitudeDelta: abs(first.latitude - last.latitude) * 1.5,
                    longitudeDelta: abs(first.longitude - last.longitude) * 1.5
                )
                mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: true)
            }
        }
    }
    
    private func createMulticolorPolylines(from locations: [CLLocation]) -> [MulticolorPolyline] {
        var coordinates: [(CLLocation, CLLocation)] = []
        var speeds: [Double] = []
        var minSpeed = Double.greatestFiniteMagnitude
        var maxSpeed = 0.0
        
        for i in 0..<(locations.count - 1) {
            let start = locations[i]
            let end = locations[i + 1]
            coordinates.append((start, end))
            
            let distance = start.distance(from: end)
            let timeInterval = end.timestamp.timeIntervalSince(start.timestamp)
            let speed = timeInterval > 0 ? distance / timeInterval : 0
            speeds.append(speed)
            minSpeed = min(minSpeed, speed)
            maxSpeed = max(maxSpeed, speed)
        }
        
        let midSpeed = speeds.reduce(0, +) / Double(max(speeds.count, 1))
        
        var segments: [MulticolorPolyline] = []
        for ((start, end), speed) in zip(coordinates, speeds) {
            let coords = [start.coordinate, end.coordinate]
            let color = getSegmentColor(speed: speed, midSpeed: midSpeed, slowestSpeed: minSpeed, fastestSpeed: maxSpeed)
            let segment = MulticolorPolyline(coordinates: coords, count: coords.count, color: color)
            segments.append(segment)
        }
        
        return segments
    }
    
    private func getSegmentColor(speed: Double, midSpeed: Double, slowestSpeed: Double, fastestSpeed: Double) -> UIColor {
        if speed >= midSpeed {
            // Fast: orange to red
            let ratio = (speed - midSpeed) / max(fastestSpeed - midSpeed, 0.1)
            return UIColor(red: 1.0, green: CGFloat(0.6 * (1 - ratio)), blue: 0.0, alpha: 1.0)
        } else {
            // Slow: yellow to orange
            let ratio = (speed - slowestSpeed) / max(midSpeed - slowestSpeed, 0.1)
            return UIColor(red: 1.0, green: CGFloat(0.8 + 0.2 * ratio), blue: 0.0, alpha: 1.0)
        }
    }
    
    // MARK: - Actions
    
    @objc private func playButtonTapped() {
        isPlaying.toggle()
        if isPlaying {
            playButton.setTitle("⏸ Pause", for: .normal)
            startAnimation()
        } else {
            playButton.setTitle("▶️ Play", for: .normal)
            stopAnimation()
        }
    }
    
    @objc private func sliderChanged() {
        currentProgress = Double(progressSlider.value)
        updateMapForProgress(currentProgress)
    }
    
    // MARK: - Animation
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentProgress += 0.01
            if self.currentProgress >= 1.0 {
                self.currentProgress = 1.0
                self.stopAnimation()
            }
            self.progressSlider.value = Float(self.currentProgress)
            self.updateMapForProgress(self.currentProgress)
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        isPlaying = false
        playButton.setTitle("▶️ Play", for: .normal)
    }
    
    private func updateMapForProgress(_ progress: Double) {
        // Update map to show progress along route
        // This can be enhanced with marker animation, etc.
    }
}

// MARK: - MKMapViewDelegate

extension RunVideoPreviewViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MulticolorPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = polyline.color
            renderer.lineWidth = 5.0
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }
        
        // Fallback
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = .orange
        renderer.lineWidth = 4
        return renderer
    }
}


