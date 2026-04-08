//
//  LoginView.swift
//  SWE_Menopro_UI
//
//  Created by Jenna's MacBook Pro on 4/7/26.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggedIn = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Menopro")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 40)
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Login") {
                    isLoggedIn = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                NavigationLink(destination: SignUpView()) {
                    NavigationLink(destination: HomeView(), isActive: $isLoggedIn) {
                        EmptyView()
                    }
                    Text("Sign Up")
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal, 30)
        }
    }
}

#Preview {
    LoginView()
}
