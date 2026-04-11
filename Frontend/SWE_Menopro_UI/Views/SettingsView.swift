//
//  SettingsView.swift
//  SWE_Menopro_UI
//

import SwiftUI

// MARK: - Settings root
struct SettingsView: View {
    @State private var isLoggedOut = false

    var body: some View {
        // No NavigationView here — MainTabView's parent NavigationView handles navigation
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            List {
                // MARK: Account
                Section(header: Text("Account")) {
                    NavigationLink(destination: EditProfileView()) {
                        SettingsRow(icon: "person.fill", label: "Edit Profile")
                    }
                    NavigationLink(destination: ChangePasswordView()) {
                        SettingsRow(icon: "lock.fill", label: "Change Password")
                    }
                    Button(action: handleLogout) {
                        SettingsRow(icon: "rectangle.portrait.and.arrow.right",
                                    label: "Log Out",
                                    isDestructive: true)
                    }
                }

                // MARK: My Data
                Section(header: Text("My Data")) {
                    NavigationLink(destination: MyDataView()) {
                        SettingsRow(icon: "chart.bar.fill", label: "My Health Info")
                    }
                }

                // MARK: App Info
                Section(header: Text("App Info")) {
                    SettingsRow(icon: "info.circle.fill", label: "Version", value: "1.0.0")
                    NavigationLink(destination: PrivacyPolicyView()) {
                        SettingsRow(icon: "hand.raised.fill", label: "Privacy Policy")
                    }
                    NavigationLink(destination: AboutView()) {
                        SettingsRow(icon: "heart.fill", label: "About Menopro")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        // Navigate back to login on logout
        .navigationDestination(isPresented: $isLoggedOut) {
            LoginView().navigationBarBackButtonHidden(true)
        }
    }

    private func handleLogout() {
        APIService.shared.logout()
        isLoggedOut = true
    }
}

// MARK: - Reusable settings row
struct SettingsRow: View {
    let icon: String
    let label: String
    var value: String? = nil
    var isDestructive: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isDestructive ? .red : .appPoint)
                .frame(width: 24)
            Text(label)
                .foregroundColor(isDestructive ? .red : .primary)
            Spacer()
            if let value = value {
                Text(value)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - My Data View
struct MyDataView: View {
    @State private var isLoading = true
    @State private var errorMessage = ""

    @State private var age = ""
    @State private var bmi = ""
    @State private var isSmoker = ""
    @State private var alcoholPerWeek = ""
    @State private var caffeinePerWeek = ""
    @State private var race = ""

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            if isLoading {
                ProgressView("Loading...")
                    .foregroundColor(.secondary)
            } else if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else {
                List {
                    Section(header: Text("Basic Info")) {
                        DataRow(label: "Age", value: age)
                        DataRow(label: "BMI", value: bmi)
                    }
                    Section(header: Text("Lifestyle")) {
                        DataRow(label: "Smoker", value: isSmoker)
                        DataRow(label: "Alcohol / week", value: alcoholPerWeek)
                        DataRow(label: "Caffeine / week", value: caffeinePerWeek)
                    }
                    Section(header: Text("Background")) {
                        DataRow(label: "Race", value: race)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("My Health Info")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadProfile)
    }

    private func loadProfile() {
        isLoading = true
        APIService.shared.getProfile { success, data, message in
            DispatchQueue.main.async {
                isLoading = false
                if success, let data = data {
                    age             = "\(data["age"] ?? "—")"
                    bmi             = String(format: "%.1f", (data["bmi"] as? Double) ?? 0)
                    isSmoker        = (data["is_smoker"] as? Bool == true) ? "Yes" : "No"
                    alcoholPerWeek  = "\(data["alcohol_per_week"] ?? "—") times / week"
                    caffeinePerWeek = "\(data["caffeine_per_week"] ?? "—") times / week"
                    race            = "\(data["race"] ?? "—")"
                } else {
                    errorMessage = message
                }
            }
        }
    }
}

// Reusable label-value row
struct DataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundColor(.primary)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.presentationMode) var presentationMode

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var age = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var heightUnit = "cm"
    @State private var weightUnit = "kg"
    @State private var isSmoker = false
    @State private var alcoholPerWeek = 0
    @State private var caffeinePerWeek = 0
    @State private var selectedRace = "Prefer not to say"

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    let races = ["Prefer not to say","White","Black or African American","Asian",
                 "Hispanic or Latino","Native American","Pacific Islander",
                 "Middle Eastern","Mixed","Other"]
    let timesPerWeek = Array(0...7)
    let heightUnits = ["cm", "ft"]
    let weightUnits = ["kg", "lbs"]

    var computedBMI: Double? {
        guard let h = Double(height), let w = Double(weight), h > 0 else { return nil }
        let hM = heightUnit == "cm" ? h / 100 : h * 0.3048
        let wKg = weightUnit == "kg" ? w : w * 0.453592
        return wKg / (hM * hM)
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            if isLoading {
                ProgressView("Loading...")
            } else {
                ScrollView {
                    VStack(spacing: 0) {

                        sectionHeader("NAME")
                        inputCard {
                            TextField("First Name", text: $firstName)
                                .padding(.horizontal, 16).padding(.vertical, 12)
                            rowDivider()
                            TextField("Last Name", text: $lastName)
                                .padding(.horizontal, 16).padding(.vertical, 12)
                        }

                        sectionHeader("BASIC INFO")
                        inputCard {
                            TextField("Age", text: $age)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 16).padding(.vertical, 12)
                            rowDivider()
                            HStack {
                                TextField("Height", text: $height).keyboardType(.decimalPad)
                                Picker("", selection: $heightUnit) {
                                    ForEach(heightUnits, id: \.self) { Text($0) }
                                }
                                .pickerStyle(.segmented).frame(width: 100)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            rowDivider()
                            HStack {
                                TextField("Weight", text: $weight).keyboardType(.decimalPad)
                                Picker("", selection: $weightUnit) {
                                    ForEach(weightUnits, id: \.self) { Text($0) }
                                }
                                .pickerStyle(.segmented).frame(width: 100)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            rowDivider()
                            HStack {
                                Text("BMI")
                                Spacer()
                                Text(computedBMI.map { String(format: "%.1f", $0) } ?? "—")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }

                        sectionHeader("LIFESTYLE")
                        inputCard {
                            Toggle("Smoker", isOn: $isSmoker)
                                .tint(.appPoint)
                                .padding(.horizontal, 16).padding(.vertical, 12)
                            rowDivider()
                            HStack {
                                Text("Alcohol")
                                Spacer()
                                Picker("", selection: $alcoholPerWeek) {
                                    ForEach(timesPerWeek, id: \.self) { Text("\($0)x / week") }
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            rowDivider()
                            HStack {
                                Text("Caffeine")
                                Spacer()
                                Picker("", selection: $caffeinePerWeek) {
                                    ForEach(timesPerWeek, id: \.self) { Text("\($0)x / week") }
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }

                        sectionHeader("RACE")
                        inputCard {
                            Picker("Race", selection: $selectedRace) {
                                ForEach(races, id: \.self) { Text($0) }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }

                        if !errorMessage.isEmpty {
                            Text(errorMessage).font(.caption).foregroundColor(.red)
                                .padding(.top, 12)
                        }
                        if !successMessage.isEmpty {
                            Text(successMessage).font(.caption).foregroundColor(.green)
                                .padding(.top, 12)
                        }

                        Button(action: saveProfile) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity).padding()
                            } else {
                                Text("Save Changes")
                                    .frame(maxWidth: .infinity).padding()
                            }
                        }
                        .background(Color.appPoint)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(isSaving)
                        .padding(.horizontal, 16)
                        .padding(.top, 30)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadProfile)
    }

    private func loadProfile() {
        isLoading = true
        APIService.shared.getProfile { success, data, message in
            DispatchQueue.main.async {
                isLoading = false
                print("✅ success: \(success)")
                print("✅ data: \(String(describing: data))")
                print("❌ message: \(message)")
                guard success, let data = data else {
                    errorMessage = message
                    return
                }
                firstName       = data["first_name"] as? String ?? ""
                lastName        = data["last_name"] as? String ?? ""
                age             = "\(data["age"] ?? "")"
                isSmoker        = data["is_smoker"] as? Bool ?? false
                alcoholPerWeek  = data["alcohol_per_week"] as? Int ?? 0
                caffeinePerWeek = data["caffeine_per_week"] as? Int ?? 0
                selectedRace    = data["race"] as? String ?? "Prefer not to say"
            }
        }
    }

    private func saveProfile() {
        errorMessage = ""
        successMessage = ""
        isSaving = true

        var fields: [String: Any] = [
            "first_name": firstName,
            "last_name": lastName,
            "is_smoker": isSmoker,
            "alcohol_per_week": alcoholPerWeek,
            "caffeine_per_week": caffeinePerWeek,
            "race": selectedRace
        ]
        if let ageInt = Int(age)   { fields["age"] = ageInt }
        if let bmi = computedBMI   { fields["bmi"] = bmi }

        APIService.shared.updateProfile(fields: fields) { success, message in
            DispatchQueue.main.async {
                isSaving = false
                if success {
                    successMessage = "Saved!"
                } else {
                    errorMessage = message
                }
            }
        }
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 4)
    }

    func inputCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(10)
            .padding(.horizontal, 16)
    }

    func rowDivider() -> some View {
        Divider().padding(.leading, 16)
    }
}

// MARK: - Change Password View
struct ChangePasswordView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    var isFormValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 7 &&
        newPassword == confirmPassword
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                SecureField("Current Password", text: $currentPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.none)
                SecureField("New Password (min. 7 characters)", text: $newPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.none)
                SecureField("Confirm New Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.none)

                if !newPassword.isEmpty && newPassword.count < 7 {
                    Text("Password must be at least 7 characters.")
                        .font(.caption).foregroundColor(.red)
                }
                if !confirmPassword.isEmpty && newPassword != confirmPassword {
                    Text("Passwords do not match.")
                        .font(.caption).foregroundColor(.red)
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.caption).foregroundColor(.red)
                }
                if !successMessage.isEmpty {
                    Text(successMessage).font(.caption).foregroundColor(.green)
                }

                Button(action: handleChangePassword) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity).padding()
                    } else {
                        Text("Update Password")
                            .frame(maxWidth: .infinity).padding()
                    }
                }
                .background(isFormValid ? Color.appPoint : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!isFormValid || isLoading)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handleChangePassword() {
        errorMessage = ""
        successMessage = ""
        isLoading = true

        APIService.shared.changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword
        ) { success, message in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    successMessage = message
                    currentPassword = ""
                    newPassword = ""
                    confirmPassword = ""
                } else {
                    errorMessage = message
                }
            }
        }
    }
}

// MARK: - Privacy Policy
struct PrivacyPolicyView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                Text("Privacy policy content goes here.")
                    .foregroundColor(.secondary)
                    .padding(24)
            }
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About
struct AboutView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.appPoint)
                Text("Menopro")
                    .font(.title).fontWeight(.bold).foregroundColor(.appPoint)
                Text("Empowering women through menopause\nwith data-driven insights.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                Spacer()
            }
            .padding(.top, 60)
        }
        .navigationTitle("About Menopro")
        .navigationBarTitleDisplayMode(.inline)
    }
}
