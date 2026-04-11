//
//  FirstLogoView.swift
//  SWE_Menopro_UI
//
//

import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var opacity = 0.5
    
    var body: some View {
        if isActive {
            LoginView()
        } else {
            ZStack {
                // Set the background color
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack {
                    VStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.appPoint) // Updated color
                        Text("Wenopause")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.appPoint) // Updated color
                    }
                    .scaleEffect(opacity == 1.0 ? 1.0 : 0.8)
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 1.2)) {
                            self.opacity = 1.0
                        }
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}
