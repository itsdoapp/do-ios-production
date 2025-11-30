//
//  ChallengesView.swift
//  Do
//

import SwiftUI

struct ChallengesView: View {
    var body: some View {
        ZStack {
            Color.brandBlue
                .ignoresSafeArea(.all, edges: .all)
            
            VStack {
                Text("Challenges")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Coming Soon")
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
