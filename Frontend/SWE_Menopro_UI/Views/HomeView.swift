//
//  HomeView.swift
//  SWE_Menopro_UI
//

import SwiftUI

struct HomeView: View {
    @State private var selectedDate = Date()

    // Prediction state
    @State private var isLoading = false
    @State private var predictionResult: PredictionResult? = nil
    @State private var errorMessage = ""

    // History state
    @State private var history: [PredictionHistory] = []
    @State private var isLoadingHistory = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // ── Calendar ──
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(.appPoint)
                            .padding(.horizontal, 16)

                        // ── Hot Flash Risk Card ──
                        VStack(spacing: 12) {
                            Text("Hot Flash Risk")
                                .font(.headline)
                                .foregroundColor(.appPoint)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let result = predictionResult {
                                // Show prediction result
                                HStack(spacing: 16) {
                                    // Risk level color indicator
                                    Circle()
                                        .fill(riskColor(result.riskLevel))
                                        .frame(width: 20, height: 20)

                                    VStack(alignment: .leading, spacing: 4) {
                                        // Risk level label
                                        Text(result.riskLevel)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(riskColor(result.riskLevel))
                                        // Human-readable time estimate
                                        Text(timeLabel(result.timeToNextHf))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    // Sensor readings
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("🌡 \(String(format: "%.1f", result.skinTempC))°C")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("❤️ \(result.heartRate) BPM")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(12)

                            } else {
                                // Placeholder before first prediction
                                Text("Tap 'Check Now' to predict your hot flash risk using sensor data.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(12)
                            }

                            // Error message
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }

                            // Check Now button
                            Button(action: runPrediction) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else {
                                    Text("Check Now")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                }
                            }
                            .background(Color.appPoint)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .disabled(isLoading)
                        }
                        .padding(.horizontal, 16)

                        // ── Recent History ──
                        VStack(spacing: 8) {
                            Text("Recent History")
                                .font(.headline)
                                .foregroundColor(.appPoint)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if isLoadingHistory {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else if history.isEmpty {
                                Text("No history yet.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(12)
                            } else {
                                // Show last 5 entries
                                ForEach(history.prefix(5)) { entry in
                                    HStack {
                                        Circle()
                                            .fill(riskColor(entry.riskLevel))
                                            .frame(width: 10, height: 10)
                                        Text(entry.riskLevel)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(timeLabel(entry.timeToNextHf))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(formatTimestamp(entry.timestamp))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Menopro")
            .navigationBarTitleDisplayMode(.large)
            .onAppear(perform: loadHistory)
        }
    }

    // ── Run prediction using latest sensor data from Firebase ──
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

    // ── Load prediction history from backend ──
    private func loadHistory() {
        isLoadingHistory = true

        APIService.shared.getHistory { success, entries, _ in
            DispatchQueue.main.async {
                isLoadingHistory = false
                if success {
                    history = entries
                }
            }
        }
    }

    // ── Convert risk level string to color ──
    private func riskColor(_ level: String) -> Color {
        switch level {
        case "Imminent": return .red
        case "Soon":     return .orange
        case "Moderate": return .yellow
        default:         return .green  // Low Risk
        }
    }

    // ── Convert seconds to human-readable time label ──
    private func timeLabel(_ seconds: Int) -> String {
        switch seconds {
        case ...300:  return "Within 5 minutes"
        case ...900:  return "Within 15 minutes"
        case ...1800: return "Within 30 minutes"
        default:      return "Not expected soon"
        }
    }

    // ── Format ISO timestamp to readable short format ──
    private func formatTimestamp(_ raw: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) {
            let display = DateFormatter()
            display.dateFormat = "MM/dd HH:mm"
            return display.string(from: date)
        }
        return raw
    }
}
