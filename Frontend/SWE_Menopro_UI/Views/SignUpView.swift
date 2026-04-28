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
    @State private var hasAgreedToTerms = false
    @State private var menopauseStage = 2
    @State private var stressLevel = 1
    @State private var medication = 0
    @State private var exerciseLevel = 2
    @State private var hasThyroid = false
    @State private var hasDiabetes = false
    @State private var hasCardiovascular = false
    @State private var hasMentalHealth = false
    @State private var hasSurgical = false

    // Submission state
    @State private var isSubmitting = false
    @State private var errorMessage = ""

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
    
    let menopauseStages = ["Early Perimenopause", "Late Perimenopause", "Early Postmenopause (0-2y)", "Late Postmenopause (2-5y)", "Late Postmenopause (5y+)"]
    let stressLevels = ["Low", "Moderate", "High"]
    let medications = ["None", "SSRIs/SNRIs", "Tamoxifen", "Aromatase Inhibitors", "GnRH Agonists", "Beta Blockers", "Opioids", "Anticholinergics", "HRT (Estrogen)", "Fezolinetant"]
    let exerciseLevels = ["Sedentary", "Light", "Moderate", "High"]

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
        hasAgreedToTerms
    }

    // Section header style
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

    // Input card style
    func inputCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }

    // Row divider style
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
                            .textContentType(.oneTimeCode)
                            .autocorrectionDisabled()
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
                            .textContentType(.oneTimeCode)
                            .autocorrectionDisabled()
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
                            .tint(.appPoint)
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

                    // MARK: - Health Profile
                    sectionHeader("HEALTH PROFILE")
                    inputCard {
                        HStack {
                            Text("Menopause Stage")
                            Spacer()
                            Picker("", selection: $menopauseStage) {
                                ForEach(0..<menopauseStages.count, id: \.self) { i in
                                    Text(menopauseStages[i]).tag(i)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        rowDivider()
                        HStack {
                            Text("Stress Level")
                            Spacer()
                            Picker("", selection: $stressLevel) {
                                ForEach(0..<stressLevels.count, id: \.self) { i in
                                    Text(stressLevels[i]).tag(i)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        rowDivider()
                        HStack {
                            Text("Medication")
                            Spacer()
                            Picker("", selection: $medication) {
                                ForEach(0..<medications.count, id: \.self) { i in
                                    Text(medications[i]).tag(i)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        rowDivider()
                        HStack {
                            Text("Exercise Level")
                            Spacer()
                            Picker("", selection: $exerciseLevel) {
                                ForEach(0..<exerciseLevels.count, id: \.self) { i in
                                    Text(exerciseLevels[i]).tag(i)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        rowDivider()
                        Toggle("Thyroid Condition", isOn: $hasThyroid)
                            .tint(.appPoint)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        rowDivider()
                        Toggle("Diabetes", isOn: $hasDiabetes)
                            .tint(.appPoint)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        rowDivider()
                        Toggle("Cardiovascular Condition", isOn: $hasCardiovascular)
                            .tint(.appPoint)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        rowDivider()
                        Toggle("Mental Health Condition", isOn: $hasMentalHealth)
                            .tint(.appPoint)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        rowDivider()
                        Toggle("Surgical Menopause", isOn: $hasSurgical)
                            .tint(.appPoint)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                
                    // MARK: - Privacy Disclaimer
                    VStack(alignment: .leading, spacing: 10) {
                        Text("⚠️ Entering inaccurate information may result in less accurate predictions.")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.appPoint)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        Text("Your health information is used solely for symptom prediction and personalized services, and will not be shared with third parties.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)

                        HStack(alignment: .top, spacing: 10) {
                            Button(action: {
                                hasAgreedToTerms.toggle()
                            }) {
                                Image(systemName: hasAgreedToTerms ? "checkmark.square.fill" : "square")
                                    .foregroundColor(hasAgreedToTerms ? .appPoint : .secondary)
                                    .font(.system(size: 20))
                            }
                            Text("I have read the above and understand that entering inaccurate information may reduce prediction accuracy.")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }

                    // MARK: - Error Message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }

                    // MARK: - Sign Up Button
                    Button(action: submitSignup) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Sign Up")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(isFormValid && !isSubmitting ? Color.appPoint : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(!isFormValid || isSubmitting)
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
            .accentColor(.appPoint)
        }
    }

    // MARK: - Submit Signup
    private func submitSignup() {
        guard let ageInt = Int(age),
              let heightDouble = Double(height),
              let weightDouble = Double(weight) else {
            errorMessage = "Please check your age, height, and weight."
            return
        }

        // Convert to metric for backend (which expects cm and kg)
        let heightInCm = heightUnit == "cm" ? heightDouble : heightDouble * 30.48
        let weightInKg = weightUnit == "kg" ? weightDouble : weightDouble * 0.453592

        // Compute BMI in metric
        let heightInMeters = heightInCm / 100
        let bmiValue = weightInKg / (heightInMeters * heightInMeters)

        errorMessage = ""
        isSubmitting = true

        APIService.shared.signUp(
            firstName: firstName,
            lastName: lastName,
            email: email,
            password: password,
            age: ageInt,
            height: heightInCm,
            weight: weightInKg,
            bmi: bmiValue,
            isSmoker: isSmoker,
            alcoholPerWeek: alcoholPerWeek,
            caffeinePerWeek: caffeinePerWeek,
            race: selectedRace,
            menopauseStage: menopauseStage,
            stressLevel: stressLevel,
            medication: medication,
            exerciseLevel: exerciseLevel,
            thyroid: hasThyroid,
            diabetes: hasDiabetes,
            cardiovascular: hasCardiovascular,
            mentalHealth: hasMentalHealth,
            surgical: hasSurgical
        ){ success, message in
            DispatchQueue.main.async {
                isSubmitting = false
                if success {
                    print("Signup successful!")
                    presentationMode.wrappedValue.dismiss()
                } else {
                    errorMessage = message
                    print("Signup failed: \(message)")
                }
            }
        }
    }
}

#Preview {
    SignUpView()
}
