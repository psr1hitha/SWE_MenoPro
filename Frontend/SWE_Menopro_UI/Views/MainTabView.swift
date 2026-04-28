//
//  MainTabView.swift
//  SWE_Menopro_UI
//
//  Three tabs: Home / Calendar / Communities.
//  Settings is removed from the tab bar — accessed via avatar tap on Home.
//

import SwiftUI

struct MainTabView: View {
    @Binding var isLoggedIn: Bool

    init(isLoggedIn: Binding<Bool>) {
        self._isLoggedIn = isLoggedIn

        // Tab bar styling — cream background, magenta accent
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.98, green: 0.95, blue: 0.91, alpha: 1.0) // menoCream
        appearance.shadowColor = .clear

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some View {
        TabView {
            HomeView(isLoggedIn: $isLoggedIn)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }

            CommunitiesView()
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Community")
                }
        }
        .accentColor(.menoMagenta)
    }
}
