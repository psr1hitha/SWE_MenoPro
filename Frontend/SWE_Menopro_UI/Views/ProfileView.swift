//
//  ProfileView.swift
//  SWE_Menopro_UI
//
//  Personal settings + editable profile data + logout.
//  Accessed by tapping the avatar on Home.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isLoggedIn: Bool

    // Profile fields
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var displayName = ""
    @State private var age = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var isSmoker = false
    @State private var alcoholPerWeek = 0
    @State private var caffeinePerWeek = 0
    @State private var selectedRace = "Prefer not to say"

    // UI state
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var feedback = ""
    @State private var feedbackIsError = false

    @State private var showChangePasswordSheet = false
    @State private var showLogoutConfirm = false

    private let races = [
        "Prefer not to say", "White", "Black or African American", "Asian",
        "Hispanic or Latino", "Native American", "Pacific Islander",
        "Middle Eastern", "Mixed", "Other"
    ]
    private let timesPerWeek = Array(0...7)

    var body: some View {
        ZStack {
            Color.menoCream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {

                    profileHeader
                        .padding(.top, 8)

                    if isLoading {
                        ProgressView().tint(.menoMagenta).padding(40)
                    } else {
                        accountCard
                        displayNameCard
                        basicInfoCard
                        lifestyleCard
                        raceCard
                        actionsCard

                        if !feedback.isEmpty {
                            Text(feedback)
                                .font(.system(size: 12))
                                .foregroundColor(feedbackIsError ? .menoRiskImminent : .menoMagenta)
                                .multilineTextAlignment(.center)
                        }

                        saveButton
                            .padding(.top, 8)

                        Spacer(minLength: 60)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadProfile)
        .sheet(isPresented: $showChangePasswordSheet) {
            ChangePasswordSheet(onClose: { showChangePasswordSheet = false })
        }
        .alert("Log out?", isPresented: $showLogoutConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Log out", role: .destructive) {
                APIService.shared.logout()
                isLoggedIn = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: 14) {
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.menoMagenta)
                        .frame(width: 36, height: 36)
                        .background(Color.menoCard)
                        .clipShape(Circle())
                }
                Spacer()
                Text("Profile")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.menoTextPrimary)
                Spacer()
                Color.clear.frame(width: 36, height: 36) // balance
            }

            ZStack {
                Circle()
                    .fill(Color.menoMagentaSoft)
                    .frame(width: 80, height: 80)
                Text(firstName.first.map { String($0).uppercased() } ?? "•")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.menoMagentaDark)
            }
            .padding(.top, 4)

            VStack(spacing: 2) {
                Text("\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.menoTextPrimary)
                Text(email)
                    .font(.system(size: 13))
                    .foregroundColor(.menoTextSecondary)
            }
        }
    }

    // MARK: - Cards

    private var accountCard: some View {
        sectionCard(title: "ACCOUNT") {
            labeledRow(label: "First name") {
                TextField("", text: $firstName).fieldStyle()
            }
            divider
            labeledRow(label: "Last name") {
                TextField("", text: $lastName).fieldStyle()
            }
        }
    }

    private var displayNameCard: some View {
        sectionCard(title: "COMMUNITY DISPLAY NAME") {
            labeledRow(label: "Display name") {
                TextField("How others see you", text: $displayName).fieldStyle()
            }
            Text("This is how you appear in community chats.")
                .font(.system(size: 11))
                .foregroundColor(.menoTextTertiary)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var basicInfoCard: some View {
        sectionCard(title: "BASIC INFO") {
            labeledRow(label: "Age") {
                TextField("", text: $age)
                    .keyboardType(.numberPad)
                    .fieldStyle()
            }
            divider
            labeledRow(label: "Height (cm)") {
                TextField("", text: $height)
                    .keyboardType(.decimalPad)
                    .fieldStyle()
            }
            divider
            labeledRow(label: "Weight (kg)") {
                TextField("", text: $weight)
                    .keyboardType(.decimalPad)
                    .fieldStyle()
            }
            divider
            HStack {
                Text("BMI")
                    .font(.system(size: 14))
                    .foregroundColor(.menoTextPrimary)
                Spacer()
                Text(computedBMI)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.menoTextSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var lifestyleCard: some View {
        sectionCard(title: "LIFESTYLE") {
            HStack {
                Text("Smoker")
                    .font(.system(size: 14))
                    .foregroundColor(.menoTextPrimary)
                Spacer()
                Toggle("", isOn: $isSmoker).labelsHidden().tint(.menoMagenta)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            divider
            HStack {
                Text("Alcohol / week")
                    .font(.system(size: 14))
                    .foregroundColor(.menoTextPrimary)
                Spacer()
                Picker("", selection: $alcoholPerWeek) {
                    ForEach(timesPerWeek, id: \.self) { Text("\($0)") }
                }
                .tint(.menoMagenta)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            divider
            HStack {
                Text("Caffeine / week")
                    .font(.system(size: 14))
                    .foregroundColor(.menoTextPrimary)
                Spacer()
                Picker("", selection: $caffeinePerWeek) {
                    ForEach(timesPerWeek, id: \.self) { Text("\($0)") }
                }
                .tint(.menoMagenta)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
        }
    }

    private var raceCard: some View {
        sectionCard(title: "RACE") {
            HStack {
                Text("Race")
                    .font(.system(size: 14))
                    .foregroundColor(.menoTextPrimary)
                Spacer()
                Picker("", selection: $selectedRace) {
                    ForEach(races, id: \.self) { Text($0) }
                }
                .tint(.menoMagenta)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
        }
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            Button(action: { showChangePasswordSheet = true }) {
                actionRow(label: "Change password", isDestructive: false)
            }
            Divider().background(Color.menoMuted).padding(.leading, 14)
            Button(action: { showLogoutConfirm = true }) {
                actionRow(label: "Log out", isDestructive: true)
            }
        }
        .background(Color.menoCard)
        .cornerRadius(MenoRadius.medium)
    }

    private func actionRow(label: String, isDestructive: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isDestructive ? .menoRiskImminent : .menoTextPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.menoTextTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private var saveButton: some View {
        Button(action: saveProfile) {
            if isSaving {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                Text("Save changes")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .background(Color.menoMagentaDark)
        .cornerRadius(MenoRadius.medium)
        .disabled(isSaving)
    }

    // MARK: - Reusable bits

    private func sectionCard<Content: View>(title: String,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.menoTextSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) { content() }
                .background(Color.menoCard)
                .cornerRadius(MenoRadius.medium)
        }
    }

    private func labeledRow<Content: View>(label: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.menoTextPrimary)
            Spacer()
            content()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 180)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Divider().background(Color.menoMuted).padding(.leading, 14)
    }

    private var computedBMI: String {
        guard let h = Double(height), let w = Double(weight), h > 0 else { return "—" }
        let m = h / 100
        return String(format: "%.1f", w / (m * m))
    }

    // MARK: - Networking

    private func loadProfile() {
        APIService.shared.getProfile { success, data, _ in
            DispatchQueue.main.async {
                isLoading = false
                guard success, let data = data else { return }
                firstName = data["first_name"] as? String ?? ""
                lastName = data["last_name"] as? String ?? ""
                email = data["email"] as? String ?? ""
                displayName = data["display_name"] as? String ?? firstName
                if let a = data["age"] as? Int { age = "\(a)" }
                if let h = data["height"] as? Double { height = String(format: "%.0f", h) }
                if let w = data["weight"] as? Double { weight = String(format: "%.0f", w) }
                isSmoker = data["is_smoker"] as? Bool ?? false
                alcoholPerWeek = data["alcohol_per_week"] as? Int ?? 0
                caffeinePerWeek = data["caffeine_per_week"] as? Int ?? 0
                selectedRace = data["race"] as? String ?? "Prefer not to say"
            }
        }
    }

    private func saveProfile() {
        feedback = ""
        feedbackIsError = false
        isSaving = true

        var fields: [String: Any] = [
            "first_name": firstName,
            "last_name": lastName,
            "is_smoker": isSmoker,
            "alcohol_per_week": alcoholPerWeek,
            "caffeine_per_week": caffeinePerWeek,
            "race": selectedRace,
            "display_name": displayName.isEmpty ? firstName : displayName
        ]
        if let a = Int(age) { fields["age"] = a }
        if let h = Double(height) { fields["height"] = h }
        if let w = Double(weight) {
            fields["weight"] = w
            if let h = Double(height), h > 0 {
                let m = h / 100
                fields["bmi"] = w / (m * m)
            }
        }

        APIService.shared.updateProfile(fields: fields) { success, message in
            DispatchQueue.main.async {
                isSaving = false
                feedback = success ? "Saved." : message
                feedbackIsError = !success
            }
        }
    }
}

// MARK: - Change password sheet

struct ChangePasswordSheet: View {
    var onClose: () -> Void
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var feedback = ""
    @State private var feedbackIsError = false
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            Color.menoCream.ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    Text("Change password")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.menoTextPrimary)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.menoMagenta)
                    }
                }
                .padding(.top, 16)

                VStack(spacing: 0) {
                    SecureField("Current password", text: $currentPassword)
                        .padding(14)
                    Divider().background(Color.menoMuted)
                    SecureField("New password (min. 7 characters)", text: $newPassword)
                        .padding(14)
                    Divider().background(Color.menoMuted)
                    SecureField("Confirm new password", text: $confirmPassword)
                        .padding(14)
                }
                .background(Color.menoCard)
                .cornerRadius(MenoRadius.medium)

                if !feedback.isEmpty {
                    Text(feedback)
                        .font(.system(size: 12))
                        .foregroundColor(feedbackIsError ? .menoRiskImminent : .menoMagenta)
                }

                Button(action: submit) {
                    if isSubmitting {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                    } else {
                        Text("Update password")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                }
                .background(canSubmit ? Color.menoMagentaDark : Color.menoTextTertiary)
                .cornerRadius(MenoRadius.medium)
                .disabled(!canSubmit || isSubmitting)

                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }

    private var canSubmit: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 7 &&
        newPassword == confirmPassword
    }

    private func submit() {
        feedback = ""
        feedbackIsError = false
        isSubmitting = true
        APIService.shared.changePassword(currentPassword: currentPassword,
                                          newPassword: newPassword) { success, message in
            DispatchQueue.main.async {
                isSubmitting = false
                feedback = message
                feedbackIsError = !success
                if success {
                    currentPassword = ""
                    newPassword = ""
                    confirmPassword = ""
                }
            }
        }
    }
}

// MARK: - TextField helper

private extension View {
    func fieldStyle() -> some View {
        self.font(.system(size: 14))
            .foregroundColor(.menoTextPrimary)
            .multilineTextAlignment(.trailing)
    }
}
