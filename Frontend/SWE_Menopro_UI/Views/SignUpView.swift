//
//  SignUpView.swift
//  SWE_Menopro_UI
//
//  Created by Jenna's MacBook Pro on 4/7/26.
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    @State private var age = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var heightUnit = "cm"
    @State private var weightUnit = "kg"
    @State private var isSmoker = false
    @State private var alcoholPerWeek = 0
    @State private var caffeinePerWeek = 0
    @State private var selectedRace = "Prefer not to say"
    
    let races = [
        "Prefer not to say",
        "White",
        "Black or African American",
        "Asian",
        "Hispanic or Latino",
        "Native American",
        "Pacific Islander",
        "Middle Eastern",
        "Mixed",
        "Other"
    ]
    
    let timesPerWeek = Array(0...7)
    let heightUnits = ["cm", "ft"]
    let weightUnits = ["kg", "lbs"]
    
    var bmi: String {
        guard let h = Double(height), let w = Double(weight), h > 0 else {
            return "-"
        }
        let heightInMeters: Double
        let weightInKg: Double
        
        if heightUnit == "cm" {
            heightInMeters = h / 100
        } else {
            heightInMeters = h * 0.3048
        }
        
        if weightUnit == "kg" {
            weightInKg = w
        } else {
            weightInKg = w * 0.453592
        }
        
        let bmiValue = weightInKg / (heightInMeters * heightInMeters)
        return String(format: "%.1f", bmiValue)
    }
    
    var isPasswordValid: Bool {
        password.count >= 7
    }
    
    var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        isPasswordValid &&
        !confirmPassword.isEmpty &&
        password == confirmPassword &&
        !age.isEmpty &&
        !height.isEmpty &&
        !weight.isEmpty &&
        selectedRace != "Prefer not to say"
    }
    
    // 섹션 헤더 스타일
    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 4)
    }
    
    // 입력 칸 스타일
    func inputCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }
    
    // 행 스타일
    func rowDivider() -> some View {
        Divider()
            .padding(.leading, 16)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    
                    // MARK: - Account
                    sectionHeader("ACCOUNT")
                    inputCard {
                        TextField("First Name", text: $firstName)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        rowDivider()
                        TextField("Last Name", text: $lastName)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        rowDivider()
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        rowDivider()
                        SecureField("Password (min. 7 characters)", text: $password)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .textContentType(.none)
                        if !password.isEmpty && !isPasswordValid {
                            rowDivider()
                            Text("Password must be at least 7 characters")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        rowDivider()
                        SecureField("Confirm Password", text: $confirmPassword)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .textContentType(.none)
                        if !confirmPassword.isEmpty && password != confirmPassword {
                            rowDivider()
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    
                    // MARK: - Basic Info
                    sectionHeader("BASIC INFO")
                    inputCard {
                        TextField("Age", text: $age)
                            .keyboardType(.numberPad)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        rowDivider()
                        HStack {
                            TextField("Height", text: $height)
                                .keyboardType(.decimalPad)
                            Picker("", selection: $heightUnit) {
                                ForEach(heightUnits, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        rowDivider()
                        HStack {
                            TextField("Weight", text: $weight)
                                .keyboardType(.decimalPad)
                            Picker("", selection: $weightUnit) {
                                ForEach(weightUnits, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        rowDivider()
                        HStack {
                            Text("BMI")
                            Spacer()
                            Text(bmi)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    
                    // MARK: - Lifestyle
                    sectionHeader("LIFESTYLE")
                    inputCard {
                        Toggle("Smoker", isOn: $isSmoker)
                            .tint(.purple)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        rowDivider()
                        HStack {
                            Text("Alcohol")
                                .foregroundColor(.primary)
                            Spacer()
                            Picker("", selection: $alcoholPerWeek) {
                                ForEach(timesPerWeek, id: \.self) { n in
                                    Text("\(n) times a week")
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        rowDivider()
                        HStack {
                            Text("Caffeine")
                                .foregroundColor(.primary)
                            Spacer()
                            Picker("", selection: $caffeinePerWeek) {
                                ForEach(timesPerWeek, id: \.self) { n in
                                    Text("\(n) times a week")
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    
                    // MARK: - Race
                    sectionHeader("RACE")
                    inputCard {
                        Picker("Race", selection: $selectedRace) {
                            ForEach(races, id: \.self) { race in
                                Text(race)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    
                    // MARK: - Sign Up Button
                    Button(action: {
                        guard let ageInt = Int(age),
                              let heightDouble = Double(height),
                              let weightDouble = Double(weight) else { return }
                        
                        let heightInMeters = heightUnit == "cm" ? heightDouble / 100 : heightDouble * 0.3048
                        let weightInKg = weightUnit == "kg" ? weightDouble : weightDouble * 0.453592
                        let bmiValue = weightInKg / (heightInMeters * heightInMeters)
                        
                        APIService.shared.signUp(
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            password: password,
                            age: ageInt,
                            bmi: bmiValue,
                            isSmoker: isSmoker,
                            alcoholPerWeek: alcoholPerWeek,
                            caffeinePerWeek: caffeinePerWeek,
                            race: selectedRace
                        ) { success, message in
                            DispatchQueue.main.async {
                                if success {
                                    print("Signup successful!")
                                    // Navigate back to login
                                    presentationMode.wrappedValue.dismiss()
                                } else {
                                    print("Signup failed: \(message)")
                                }
                            }
                        }
                    }) {
                        Text("Sign Up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.purple : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal, 16)
                    .padding(.top, 30)
                    .padding(.bottom, 40)
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Sign Up")
                        .font(.system(size: 24))
                        .fontWeight(.bold)
                        .offset(x: -120)
                }
            }
            .accentColor(.purple)
        }
    }
}

#Preview {
    SignUpView()
}
