//
//  CommunitiesView.swift
//  SWE_Menopro_UI
//
//  Placeholder for community chat. Real chat rooms come in a later phase.
//

import SwiftUI

struct CommunitiesView: View {
    var body: some View {
        ZStack {
            Color.menoCream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header

                    placeholderCard

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("communities")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.menoMagenta)
                Text("Talk it out")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.menoTextPrimary)
            }
            Spacer()
        }
    }

    private var placeholderCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.menoMagentaSoft).frame(width: 64, height: 64)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.menoMagentaDark)
            }

            Text("Coming soon")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.menoTextPrimary)

            Text("Chat rooms by topic — Hot flashes, Sleep, Diet, and more — where you can connect with others going through the same thing.")
                .font(.system(size: 13))
                .foregroundColor(.menoTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .menoCard(radius: MenoRadius.large, padding: 18)
    }
}

#Preview {
    CommunitiesView()
}
