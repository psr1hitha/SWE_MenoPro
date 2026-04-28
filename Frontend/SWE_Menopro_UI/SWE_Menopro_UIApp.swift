//
//  SWE_Menopro_UIApp.swift
//  SWE_Menopro_UI
//
//  Created by Jenna's MacBook Pro on 4/7/26.
//

import SwiftUI

@main
struct SWE_Menopro_UIApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView(onFinished: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showSplash = false
                        }
                    })
                    .transition(.opacity)
                } else {
                    LoginView()
                        .transition(.opacity)
                }
            }
        }
    }
}
