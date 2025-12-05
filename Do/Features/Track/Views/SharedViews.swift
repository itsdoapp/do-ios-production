//
//  SharedViews.swift
//  Do.
//
//  Shared SwiftUI views used across multiple trackers
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import MapKit

// MARK: - Run Settings View

struct RunSettingsView: View {
    @ObservedObject private var settingsManager = RunSettingsManager.shared
    @ObservedObject private var userPreferences = UserPreferences.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General Preferences")) {
                    Toggle("Use Metric Units", isOn: $userPreferences.useMetricSystem)
                    
                    Picker("Voice Coach", selection: $userPreferences.preferredVoiceType) {
                        ForEach(UserPreferences.VoiceType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section(header: Text("Audio & Announcements")) {
                    Toggle("Announce Intervals", isOn: $settingsManager.currentSettings.announceIntervals)
                    Toggle("Play Audio Cues", isOn: $settingsManager.currentSettings.playAudioCues)
                    
                    Picker("Announcement Frequency", selection: $settingsManager.currentSettings.announcementFrequency) {
                        Text("Off").tag(AnnouncementFrequency.off)
                        Text("Every Kilometer").tag(AnnouncementFrequency.kilometer)
                        Text("Every Mile").tag(AnnouncementFrequency.mile)
                        Text("Every 2 Kilometers").tag(AnnouncementFrequency.twoKilometers)
                        Text("Every 5 Minutes").tag(AnnouncementFrequency.fiveMinutes)
                        Text("Every 10 Minutes").tag(AnnouncementFrequency.tenMinutes)
                    }
                }
                
                Section(header: Text("Display")) {
                    Toggle("Screen Always On", isOn: $settingsManager.currentSettings.screenAlwaysOn)
                    Toggle("Auto Lock Screen", isOn: $settingsManager.currentSettings.autoLockScreen)
                    Toggle("Show Heat Map", isOn: $settingsManager.currentSettings.showHeatMap)
                }
                
                Section(header: Text("Tracking")) {
                    Toggle("Track Elevation", isOn: $settingsManager.currentSettings.trackElevation)
                    Toggle("Record Heart Rate", isOn: $settingsManager.currentSettings.recordHeartRate)
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Vibrate on Milestones", isOn: $settingsManager.currentSettings.vibrateOnMilestones)
                }
            }
            .navigationTitle("Run Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onDisappear {
            settingsManager.saveSettings()
        }
    }
}

// MARK: - Find Routes View

struct FindRoutesView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var routePlanner = RoutePlanner.shared
    @StateObject private var locationManager = ModernLocationManager.shared
    @State private var searchText = ""
    @State private var selectedDistance: Double = 5.0 // km
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.opacity(0.9)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Search and filter section
                    VStack(spacing: 12) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            
                            TextField("Search for routes...", text: $searchText)
                                .foregroundColor(.white)
                                .accentColor(.blue)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        
                        // Distance selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target Distance: \(String(format: "%.1f", selectedDistance)) km")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            Slider(value: $selectedDistance, in: 1...20, step: 0.5)
                                .accentColor(.blue)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Find routes button
                    Button(action: {
                        findRoutes()
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "location.magnifyingglass")
                                Text("Find Routes")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isLoading ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(isLoading)
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Find Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func findRoutes() {
        isLoading = true
        
        // Get current location
        guard let location = locationManager.location else {
            isLoading = false
            return
        }
        
        // Find nearby routes using RoutePlanner
        Task {
            // RoutePlanner will handle finding nearby trails
            // This is a placeholder - actual implementation depends on RoutePlanner API
            await MainActor.run {
                isLoading = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - Route Preview View

struct RoutePreviewView: View {
    let trail: Trail
    let onSelectRoute: () -> Void
    let onDismiss: () -> Void
    
    @State private var mapRegion: MKCoordinateRegion
    
    init(trail: Trail, onSelectRoute: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.trail = trail
        self.onSelectRoute = onSelectRoute
        self.onDismiss = onDismiss
        
        // Calculate initial map region from trail coordinates
        if !trail.coordinates.isEmpty {
            let coordinates = trail.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let minLat = coordinates.map { $0.latitude }.min() ?? 0
            let maxLat = coordinates.map { $0.latitude }.max() ?? 0
            let minLon = coordinates.map { $0.longitude }.min() ?? 0
            let maxLon = coordinates.map { $0.longitude }.max() ?? 0
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
                longitudeDelta: max((maxLon - minLon) * 1.5, 0.01)
            )
            _mapRegion = State(initialValue: MKCoordinateRegion(center: center, span: span))
        } else {
            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with title and close button
                HStack {
                    Text("Route Preview")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        onDismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                // Route header
                VStack(alignment: .leading, spacing: 8) {
                    Text(trail.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if let description = trail.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                
                // Map preview with route
                if !trail.coordinates.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Route Map")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        RoutePreviewMapView(
                            coordinates: trail.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                            region: mapRegion
                        )
                        .frame(height: 250)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                
                // Route stats
                HStack(spacing: 20) {
                    StatCard(
                        icon: "ruler",
                        value: String(format: "%.2f", trail.length),
                        label: "Distance (mi)"
                    )
                    
                    StatCard(
                        icon: "arrow.up.right",
                        value: String(format: "%.0f", trail.elevationGain),
                        label: "Elevation (ft)"
                    )
                    
                    StatCard(
                        icon: "figure.run",
                        value: difficultyText,
                        label: "Difficulty"
                    )
                }
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        onSelectRoute()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Select Route")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        onDismiss()
                    }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
        }
        .background(Color.black.opacity(0.95))
    }
    
    private var difficultyText: String {
        switch trail.difficulty {
        case .easy: return "Easy"
        case .moderate: return "Moderate"
        case .difficult: return "Difficult"
        case .veryDifficult: return "Very Difficult"
        }
    }
}

// MARK: - Stat Card Helper

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Route Preview Map View

struct RoutePreviewMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.isUserInteractionEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.showsCompass = true
        mapView.showsUserLocation = false
        
        // Set initial region
        mapView.setRegion(region, animated: false)
        
        // Add route polyline
        if coordinates.count >= 2 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline, level: .aboveRoads)
        }
        
        // Add start and end markers
        if let start = coordinates.first {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = start
            startAnnotation.title = "Start"
            mapView.addAnnotation(startAnnotation)
        }
        
        if let end = coordinates.last, coordinates.count > 1 {
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = end
            endAnnotation.title = "End"
            mapView.addAnnotation(endAnnotation)
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if needed
        mapView.setRegion(region, animated: false)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "RouteMarker"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            if let markerView = annotationView as? MKMarkerAnnotationView {
                if annotation.title == "Start" {
                    markerView.markerTintColor = .green
                    markerView.glyphImage = UIImage(systemName: "flag.fill")
                } else if annotation.title == "End" {
                    markerView.markerTintColor = .red
                    markerView.glyphImage = UIImage(systemName: "flag.checkered")
                }
            }
            
            return annotationView
        }
    }
}

// MARK: - RunSettingsManager Extension

extension RunSettingsManager {
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(currentSettings) {
            UserDefaults.standard.set(encoded, forKey: "runSettings")
        }
    }
}

