//
//  FirstLogoView.swift
//  SWE_Menopro_UI
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
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                    Text("Menopro")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.appPoint)
                }
                .scaleEffect(opacity == 1.0 ? 1.0 : 0.8)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.2)) {
                        self.opacity = 1.0
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
