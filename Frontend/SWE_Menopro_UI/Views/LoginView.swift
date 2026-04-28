//
//  LoginView.swift
//  SWE_Menopro_UI
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggedIn = false
    @State private var errorMessage = ""
    @State private var infoMessage = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.menoLoginPink
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 4) {
                            Text("Hello!")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.menoHeartPink)
                                .tracking(0.5)
                            Text("MenoPro")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundColor(.menoMagentaDark)
                                .tracking(-0.5)
                        }
                        .padding(.top, 30)

                        // Heart character
                        HeartCharacter()
                            .frame(width: 200, height: 180)
                            .padding(.top, 20)
                            .padding(.bottom, 24)

                        // Form
                        VStack(spacing: 12) {
                            FloatingLabelField(
                                label: "EMAIL",
                                text: $email,
                                isSecure: false,
                                keyboard: .emailAddress
                            )

                            FloatingLabelField(
                                label: "PASSWORD",
                                text: $password,
                                isSecure: true
                            )

                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.system(size: 12))
                                    .foregroundColor(.menoRiskImminent)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            }

                            if !infoMessage.isEmpty {
                                Text(infoMessage)
                                    .font(.system(size: 12))
                                    .foregroundColor(.menoMagentaDark)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            }

                            // Login button
                            Button(action: handleLogin) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 15)
                                } else {
                                    Text("Login")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 15)
                                }
                            }
                            .background(Color.menoHeartPink)
                            .cornerRadius(22)
                            .disabled(isLoading || email.isEmpty || password.isEmpty)
                            .opacity((isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                            .padding(.top, 4)

                            // Divider with "or"
                            HStack(spacing: 10) {
                                Rectangle()
                                    .fill(Color.menoHeartPink.opacity(0.25))
                                    .frame(height: 1)
                                Text("or")
                                    .font(.system(size: 11))
                                    .foregroundColor(.menoMagentaDark.opacity(0.6))
                                Rectangle()
                                    .fill(Color.menoHeartPink.opacity(0.25))
                                    .frame(height: 1)
                            }
                            .padding(.vertical, 6)

                            // Google sign-in button
                            Button(action: handleGoogleSignIn) {
                                HStack(spacing: 10) {
                                    Image(systemName: "g.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(red: 0.259, green: 0.522, blue: 0.957))
                                    Text("Continue with Google")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.menoMagentaDark)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22)
                                        .stroke(Color.menoHeartPink.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(22)
                            }

                            // Sign up link
                            HStack(spacing: 4) {
                                Text("Don't have an account?")
                                    .font(.system(size: 13))
                                    .foregroundColor(.menoMagentaDark)
                                NavigationLink(destination: SignUpView()) {
                                    Text("Sign up")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.menoHeartPink)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 22)

                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationDestination(isPresented: $isLoggedIn) {
                MainTabView(isLoggedIn: $isLoggedIn)
                    .navigationBarBackButtonHidden(true)
            }
        }
    }

    // MARK: - Actions

    private func handleLogin() {
        errorMessage = ""
        infoMessage = ""
        isLoading = true

        APIService.shared.login(email: email, password: password) { success, message in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    isLoggedIn = true
                } else {
                    errorMessage = message
                }
            }
        }
    }

    private func handleGoogleSignIn() {
        errorMessage = ""
        infoMessage = "Google sign-in coming soon!"
    }
}

// MARK: - Floating-label input field

private struct FloatingLabelField: View {
    let label: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.menoHeartPink)

            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboard)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .font(.system(size: 14))
            .foregroundColor(.menoMagentaDark)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(22)
    }
}

// MARK: - Heart character

private struct HeartCharacter: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                CartoonHeart()
                    .fill(Color.menoHeartPink)

                // Eyes
                HStack(spacing: w * 0.25) {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: w * 0.07, height: h * 0.11)
                    Capsule()
                        .fill(Color.black)
                        .frame(width: w * 0.07, height: h * 0.11)
                }
                .position(x: w * 0.5, y: h * 0.45)

                // Smile
                SmileShape()
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: w * 0.20, height: h * 0.08)
                    .position(x: w * 0.5, y: h * 0.62)
            }
        }
    }
}

// MARK: - Cartoon heart shape

private struct CartoonHeart: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height

        p.move(to: CGPoint(x: w * 0.5, y: h * 0.28))

        p.addCurve(
            to: CGPoint(x: w * 0.10, y: h * 0.39),
            control1: CGPoint(x: w * 0.40, y: h * 0.14),
            control2: CGPoint(x: w * 0.10, y: h * 0.14)
        )

        p.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.92),
            control1: CGPoint(x: w * 0.10, y: h * 0.55),
            control2: CGPoint(x: w * 0.25, y: h * 0.72)
        )

        p.addCurve(
            to: CGPoint(x: w * 0.90, y: h * 0.39),
            control1: CGPoint(x: w * 0.75, y: h * 0.72),
            control2: CGPoint(x: w * 0.90, y: h * 0.55)
        )

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
    LoginView()
}
