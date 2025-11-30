//
//  TrackView.swift
//  Do
//

import SwiftUI
import UIKit

struct TrackView: View {
    var body: some View {
        TrackViewControllerRepresentable()
            .ignoresSafeArea(.all, edges: .all)
    }
}

// MARK: - UIViewControllerRepresentable Wrapper
struct TrackViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Track {
        let trackVC = Track()
        return trackVC
    }
    
    func updateUIViewController(_ uiViewController: Track, context: Context) {
        // No updates needed
    }
}
