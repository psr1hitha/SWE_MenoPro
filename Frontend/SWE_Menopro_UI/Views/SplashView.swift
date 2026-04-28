//
//  SplashView.swift
//  SWE_Menopro_UI
//

import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void

    @State private var eyesOpen = true
    @State private var smileScale: CGFloat = 1.0
    @State private var dotOpacity: [Double] = [0.3, 0.3, 0.3]

    var body: some View {
        ZStack {
            Color.menoLoginPink.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 4) {
                    Text("Hello!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.menoHeartPink)
                        .tracking(0.5)
                    Text("MenoPro")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(.menoMagentaDark)
                        .tracking(-0.5)
                }

                AnimatedHeart(eyesOpen: eyesOpen, smileScale: smileScale)
                    .frame(width: 220, height: 200)
                    .padding(.top, 36)

                Spacer()

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.menoHeartPink)
                            .frame(width: 6, height: 6)
                            .opacity(dotOpacity[i])
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                onFinished()
            }
        }
    }

    private func startAnimations() {
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.12)) { eyesOpen = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.easeInOut(duration: 0.12)) { eyesOpen = true }
            }
        }

        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            smileScale = 1.15
        }

        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    dotOpacity[i] = 1.0
                }
            }
        }
    }
}

// MARK: - Animated heart character

private struct AnimatedHeart: View {
    var eyesOpen: Bool
    var smileScale: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Heart fill
                CartoonHeart()
                    .fill(Color.menoHeartPink)

                // Eyes — vertical ovals, positioned ~40% down, ~25% from each side
                HStack(spacing: w * 0.25) {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: w * 0.07, height: h * 0.11)
                        .scaleEffect(x: 1, y: eyesOpen ? 1.0 : 0.05)
                    Capsule()
                        .fill(Color.black)
                        .frame(width: w * 0.07, height: h * 0.11)
                        .scaleEffect(x: 1, y: eyesOpen ? 1.0 : 0.05)
                }
                .position(x: w * 0.5, y: h * 0.45)

                // Smile — curved line below the eyes
                SmileShape()
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: w * 0.20, height: h * 0.08)
                    .scaleEffect(smileScale)
                    .position(x: w * 0.5, y: h * 0.62)
            }
        }
    }
}

// MARK: - Heart shape (proper cartoon proportions)

private struct CartoonHeart: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height

        // Start at top-center dip between the two lobes
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.28))

        // Left lobe — curve up and around
        p.addCurve(
            to: CGPoint(x: w * 0.10, y: h * 0.39),
            control1: CGPoint(x: w * 0.40, y: h * 0.14),
            control2: CGPoint(x: w * 0.10, y: h * 0.14)
        )

        // Left side — curve down to the bottom point
        p.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.92),
            control1: CGPoint(x: w * 0.10, y: h * 0.55),
            control2: CGPoint(x: w * 0.25, y: h * 0.72)
        )

        // Right side — curve up from bottom point to right lobe
        p.addCurve(
            to: CGPoint(x: w * 0.90, y: h * 0.39),
            control1: CGPoint(x: w * 0.75, y: h * 0.72),
            control2: CGPoint(x: w * 0.90, y: h * 0.55)
        )

        // Right lobe — curve over the top back to center
        p.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.28),
            control1: CGPoint(x: w * 0.90, y: h * 0.14),
            control2: CGPoint(x: w * 0.60, y: h * 0.14)
        )

        p.closeSubpath()
        return p
    }
}

// MARK: - Smile shape

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(
            to: CGPoint(x: rect.width, y: 0),
            control: CGPoint(x: rect.width / 2, y: rect.height * 1.8)
        )
        return p
    }
}

#Preview {
    SplashView(onFinished: {})
}
