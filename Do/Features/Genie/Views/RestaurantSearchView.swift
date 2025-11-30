//
//  RestaurantSearchView.swift
//  Do
//
//  Display restaurant search results
//

import SwiftUI
import MapKit

struct RestaurantSearchView: View {
    let restaurantSearch: RestaurantSearchAction
    @Environment(\.dismiss) private var dismiss
    let locationManager = LocationManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlue
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Restaurant Search")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            if restaurantSearch.requiresLocation {
                                Text("Location needed for nearby results")
                                    .font(.system(size: 16))
                                    .foregroundColor(.orange)
                            } else {
                                Text("Matching your goals and preferences")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Location request if needed
                        if restaurantSearch.requiresLocation {
                            locationRequestCard
                        }
                        
                        // Suggestions
                        if !restaurantSearch.suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Suggestions")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                ForEach(Array(restaurantSearch.suggestions.enumerated()), id: \.offset) { index, suggestion in
                                    RestaurantCard(text: suggestion, index: index + 1)
                                }
                            }
                        } else {
                            noResultsCard
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private var locationRequestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.orange)
                Text("Location Required")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text("To find nearby restaurants that match your goals, we need your location. You can share it when asking Genie again.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            if let location = locationManager.location {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Location available: \(String(format: "%.4f", location.coordinate.latitude)), \(String(format: "%.4f", location.coordinate.longitude))")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.2))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var noResultsCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No restaurants found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Try asking Genie again with more specific preferences or location details.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct RestaurantCard: View {
    let text: String
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

