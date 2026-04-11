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
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Menopro")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.appPoint)
                        .padding(.bottom, 40)

                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)

                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }

                    Button(action: handleLogin) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Login")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(Color.appPoint)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

                    NavigationLink(destination: SignUpView()) {
                        Text("Sign Up")
                            .foregroundColor(.appPoint)
                    }
                }
                .padding(.horizontal, 30)
            }
            .navigationDestination(isPresented: $isLoggedIn) {
                MainTabView().navigationBarBackButtonHidden(true)
            }
        }
    }

    private func handleLogin() {
        errorMessage = ""
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
}
