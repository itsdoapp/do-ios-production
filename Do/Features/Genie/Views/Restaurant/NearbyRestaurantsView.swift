//
//  NearbyRestaurantsView.swift
//  Do
//
//  Nearby restaurants finder
//

import SwiftUI
import CoreLocation

struct NearbyRestaurantsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var restaurantService = RestaurantTrackingService.shared
    @StateObject private var locationManager = RestaurantLocationManager()
    
    @State private var restaurants: [RestaurantInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var searchQuery = ""
    
    let onRestaurantSelected: (RestaurantInfo) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.brandBlue,
                        Color("1A2148")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Search restaurants...", text: $searchQuery)
                            .foregroundColor(.white)
                            .onSubmit {
                                searchRestaurants()
                            }
                        
                        if !searchQuery.isEmpty {
                            Button(action: {
                                searchQuery = ""
                                searchRestaurants()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.red.opacity(0.7))
                            
                            Text(error)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Try Again") {
                                searchRestaurants()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Spacer()
                    } else if restaurants.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "location.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("No restaurants found")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Try searching for a restaurant name or cuisine type")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredRestaurants, id: \.name) { restaurant in
                                    NearbyRestaurantCard(restaurant: restaurant) {
                                        onRestaurantSelected(restaurant)
                                        dismiss()
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Nearby Restaurants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                if restaurants.isEmpty {
                    searchRestaurants()
                }
            }
        }
    }
    
    private var filteredRestaurants: [RestaurantInfo] {
        if searchQuery.isEmpty {
            return restaurants
        }
        return restaurants.filter { restaurant in
            restaurant.name.localizedCaseInsensitiveContains(searchQuery) ||
            restaurant.address.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    private func searchRestaurants() {
        guard let location = locationManager.location else {
            errorMessage = "Location access required. Please enable location services."
            locationManager.requestLocation()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let found = try await restaurantService.findNearbyRestaurants(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    radius: 2000
                )
                
                await MainActor.run {
                    restaurants = found
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to find restaurants: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct NearbyRestaurantCard: View {
    let restaurant: RestaurantInfo
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.brandOrange,
                                    Color.brandOrange.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "fork.knife")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(restaurant.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(restaurant.address)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        if let distance = restaurant.distance {
                            Label("\(Int(distance))m", systemImage: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        if let rating = restaurant.rating {
                            Label(String(format: "%.1f", rating), systemImage: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.brandOrange)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
}

