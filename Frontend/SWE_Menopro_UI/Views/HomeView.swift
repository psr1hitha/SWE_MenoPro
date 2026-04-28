//
//  HomeView.swift
//  SWE_Menopro_UI
//

import SwiftUI

struct HomeView: View {
    @Binding var isLoggedIn: Bool

    // Prediction state
    @State private var isLoading = false
    @State private var predictionResult: PredictionResult? = nil
    @State private var errorMessage = ""

    // History state
    @State private var history: [PredictionHistory] = []
    @State private var isLoadingHistory = false

    // User profile (for greeting)
    @State private var firstName: String = ""

    // Navigation
    @State private var showProfile = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.menoCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {

                        greetingHeader.padding(.top, 8)
                        riskHeroCard
                        sensorStatsRow
                        checkNowButton.padding(.top, 4)
                        recentActivitySection.padding(.top, 8)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                }

                // Hidden NavigationLink driven by showProfile
                NavigationLink(
                    destination: ProfileView(isLoggedIn: $isLoggedIn),
                    isActive: $showProfile,
                    label: { EmptyView() }
                )
                .hidden()
            }
            .navigationBarHidden(true)
            .onAppear {
                loadProfile()
                loadHistory()
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Greeting header (with date chip + tappable avatar)

    private var greetingHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .semibold))
                    Text(todayString)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.menoMagenta)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.menoMagentaSoft)
                .cornerRadius(MenoRadius.small)

                Text(greetingText + (firstName.isEmpty ? "" : ", \(firstName)"))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.menoTextPrimary)
                    .padding(.top, 2)
            }
            Spacer()

            Button(action: { showProfile = true }) {
                Circle()
                    .fill(Color.menoMagentaSoft)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(initial)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.menoTextPrimary)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<18: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var initial: String {
        firstName.first.map { String($0).uppercased() } ?? "•"
    }

    // MARK: - Risk hero card

    private var riskHeroCard: some View {
        let percent = predictionResult?.riskPercent ?? 0
        let level = predictionResult?.riskLevel ?? "—"
        let message = predictionResult?.message ?? "Tap Check Now to get your risk."

        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text("hot flash risk")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(predictionResult == nil ? "—" : "\(percent)")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundColor(.white)
                    Text("%")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.top, 6)

                Text(level)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.top, 6)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.top, 1)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            ZStack {
                Circle().fill(Color.white.opacity(0.15)).frame(width: 56, height: 56)
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.menoMagenta)
        .cornerRadius(MenoRadius.large)
    }

    // MARK: - Sensor stats row

    private var sensorStatsRow: some View {
        HStack(spacing: 10) {
            sensorStatCard(
                label: "skin temp",
                value: predictionResult.map { String(format: "%.1f", $0.skinTempC) + "°" } ?? "—",
                unit: "C",
                iconName: "thermometer",
                iconBg: Color(red: 0.98, green: 0.93, blue: 0.85),
                iconFg: Color(red: 0.522, green: 0.310, blue: 0.043)
            )
            sensorStatCard(
                label: "heart rate",
                value: predictionResult.map { "\($0.heartRate)" } ?? "—",
                unit: "bpm",
                iconName: "heart.fill",
                iconBg: Color(red: 0.984, green: 0.918, blue: 0.941),
                iconFg: .menoMagenta
            )
        }
    }

    private func sensorStatCard(label: String,
                                value: String,
                                unit: String,
                                iconName: String,
                                iconBg: Color,
                                iconFg: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(iconBg).frame(width: 22, height: 22)
                    Image(systemName: iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(iconFg)
                }
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.menoTextSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.menoTextPrimary)
                Text(unit)
                    .font(.system(size: 13))
                    .foregroundColor(.menoTextTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .menoCard(radius: MenoRadius.medium, padding: 14)
    }

    // MARK: - Check Now button

    private var checkNowButton: some View {
        VStack(spacing: 8) {
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.menoRiskImminent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }

            Button(action: runPrediction) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    Text("Check now")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .background(Color.menoMagentaDark)
            .cornerRadius(MenoRadius.medium)
            .disabled(isLoading)
        }
    }

    // MARK: - Recent activity

    private var recentActivitySection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Recent activity")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.menoTextPrimary)
                Spacer()
                if !history.isEmpty {
                    Text("view all")
                        .font(.system(size: 12))
                        .foregroundColor(.menoMagenta)
                }
            }

            if isLoadingHistory {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if history.isEmpty {
                Text("No history yet.")
                    .font(.system(size: 13))
                    .foregroundColor(.menoTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.menoCard)
                    .cornerRadius(MenoRadius.medium)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(history.prefix(5).enumerated()), id: \.element.id) { index, entry in
                        historyRow(entry: entry, isLast: index == min(history.count, 5) - 1)
                    }
                }
                .padding(.horizontal, 12)
                .background(Color.menoCard)
                .cornerRadius(MenoRadius.medium)
            }
        }
    }

    private func historyRow(entry: PredictionHistory, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.forRiskLevel(entry.riskLevel))
                    .frame(width: 8, height: 8)
                Text(entry.riskLevel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.menoTextPrimary)
                Spacer()
                Text("\(entry.riskPercent)%")
                    .font(.system(size: 12))
                    .foregroundColor(.menoTextSecondary)
                Text(formatTimestamp(entry.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.menoTextTertiary)
            }
            .padding(.vertical, 12)

            if !isLast {
                Divider().background(Color.menoMuted)
            }
        }
    }

    // MARK: - Networking

    private func runPrediction() {
        errorMessage = ""
        isLoading = true

        APIService.shared.predict { success, result, message in
            DispatchQueue.main.async {
                isLoading = false
                if success, let result = result {
                    predictionResult = result
                    loadHistory()
                } else {
                    errorMessage = message
                }
            }
        }
    }

    private func loadHistory() {
        isLoadingHistory = true
        APIService.shared.getHistory { success, entries, _ in
            DispatchQueue.main.async {
                isLoadingHistory = false
                if success { history = entries }
            }
        }
    }

    private func loadProfile() {
        APIService.shared.getProfile { success, data, _ in
            DispatchQueue.main.async {
                if success, let data = data, let name = data["first_name"] as? String {
                    firstName = name
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatTimestamp(_ raw: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) {
            let display = DateFormatter()
            display.dateFormat = "HH:mm"
            return display.string(from: date)
        }
        return raw
    }
}

#Preview {
    HomeView(isLoggedIn: .constant(true))
}
