//
//  HomeView.swift
//  SWE_Menopro_UI
//
//  Created by Jenna's MacBook Pro on 4/7/26.
//
import SwiftUI

struct HomeView: View {
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(.appPoint) // Updated color
                    .padding(.horizontal, 16)
                    
                    Spacer()
                }
            }
            .navigationTitle("Menopro")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
