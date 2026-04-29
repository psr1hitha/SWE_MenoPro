//
//  MainTabView.swift
//  SWE_Menopro_UI
//
//  Three tabs: Home / Calendar / Communities.
//  Home and Calendar already manage their own navigation internally.
//  Only the Community tab needs a NavigationView here.
//

import SwiftUI

struct MainTabView: View {
    @Binding var isLoggedIn: Bool

    init(isLoggedIn: Binding<Bool>) {
        self._isLoggedIn = isLoggedIn

        // Tab bar styling — cream background, magenta accent
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.98, green: 0.95, blue: 0.91, alpha: 1.0)
        appearance.shadowColor = .clear

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some View {
        TabView {
            // ── Home — has its own NavigationView internally ──
            HomeView(isLoggedIn: $isLoggedIn)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

            // ── Calendar — no navigation push needed ──
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }

            // ── Community — needs NavigationView for push to PostDetailView ──
            NavigationView {
                CommunitiesView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                Text("Community")
            }
        }
        .accentColor(.menoMagenta)
    }
}
