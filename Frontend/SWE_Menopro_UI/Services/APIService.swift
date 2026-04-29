//
//  APIService.swift
//  SWE_Menopro_UI
//

import Foundation

// Prediction result model returned from /predict endpoint
struct PredictionResult {
    let riskPercent: Int
    let riskLevel: String       // "Imminent", "Soon", "Moderate", "Low Risk"
    let message: String
    let skinTempC: Double
    let heartRate: Int
}

// History entry model returned from /history endpoint
struct PredictionHistory: Identifiable {
    let id = UUID()
    let riskPercent: Int
    let riskLevel: String
    let skinTempC: Double
    let heartRate: Int
    let timestamp: String
}

class APIService {
    static let shared = APIService()

    // Local testing — update to your Mac's current LAN IP
    // Find with: ifconfig | grep "inet " | grep -v 127.0.0.1
    let baseURL = "http://localhost:8000"

    // ── Token storage (UserDefaults — suitable for prototype) ──
    var authToken: String? {
        get { UserDefaults.standard.string(forKey: "auth_token") }
        set { UserDefaults.standard.set(newValue, forKey: "auth_token") }
    }

    var userEmail: String? {
        get { UserDefaults.standard.string(forKey: "user_email") }
        set { UserDefaults.standard.set(newValue, forKey: "user_email") }
    }

    var isLoggedIn: Bool { authToken != nil }

    func logout() {
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "user_email")
    }

    // ── Build an authorized URLRequest with JWT header ──
    func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // ── Parse error detail from server response ──
    func parseErrorMessage(from data: Data?) -> String {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = json["detail"] as? String else {
            return "An unknown error occurred."
        }
        return detail
    }

    // ── Sign up ──
    func signUp(
        firstName: String,
        lastName: String,
        email: String,
        password: String,
        age: Int,
        height: Double,
        weight: Double,
        bmi: Double,
        isSmoker: Bool,
        alcoholPerWeek: Int,
        caffeinePerWeek: Int,
        race: String,
        menopauseStage: Int,
        stressLevel: Int,
        medication: Int,
        exerciseLevel: Int,
        thyroid: Bool,
        diabetes: Bool,
        cardiovascular: Bool,
        mentalHealth: Bool,
        surgical: Bool,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/signup") else {
            completion(false, "Invalid server address.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "first_name": firstName,
            "last_name": lastName,
            "email": email,
            "password": password,
            "age": age,
            "height": height,
            "weight": weight,
            "bmi": bmi,
            "is_smoker": isSmoker,
            "alcohol_per_week": alcoholPerWeek,
            "caffeine_per_week": caffeinePerWeek,
            "race": race,
            "menopause_stage": menopauseStage,
            "stress_level": stressLevel,
            "medication": medication,
            "exercise_level": exerciseLevel,
            "thyroid": thyroid,
            "diabetes": diabetes,
            "cardiovascular": cardiovascular,
            "mental_health": mentalHealth,
            "surgical": surgical
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid server response.")
                return
            }
            if httpResponse.statusCode == 200 {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["token"] as? String {
                    self?.authToken = token
                    self?.userEmail = email
                }
                completion(true, "Sign up successful.")
            } else {
                completion(false, self?.parseErrorMessage(from: data) ?? "Sign up failed.")
            }
        }.resume()
    }

    // ── Login ──
    func login(
        email: String,
        password: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/login") else {
            completion(false, "Invalid server address.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid server response.")
                return
            }
            if httpResponse.statusCode == 200 {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["token"] as? String {
                    self?.authToken = token
                    self?.userEmail = email
                }
                completion(true, "Login successful.")
            } else {
                completion(false, self?.parseErrorMessage(from: data) ?? "Login failed.")
            }
        }.resume()
    }

    // ── Get profile ──
    func getProfile(completion: @escaping (Bool, [String: Any]?, String) -> Void) {
        guard let url = URL(string: "\(baseURL)/profile") else {
            completion(false, nil, "Invalid server address.")
            return
        }

        let request = authorizedRequest(url: url, method: "GET")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(false, nil, "Network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, nil, "Invalid server response.")
                return
            }
            if httpResponse.statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completion(true, json, "")
            } else {
                completion(false, nil, self?.parseErrorMessage(from: data) ?? "Failed to load profile.")
            }
        }.resume()
    }

    // ── Update profile ──
    func updateProfile(
        fields: [String: Any],
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/profile") else {
            completion(false, "Invalid server address.")
            return
        }

        var request = authorizedRequest(url: url, method: "PATCH")
        request.httpBody = try? JSONSerialization.data(withJSONObject: fields)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid server response.")
                return
            }
            if httpResponse.statusCode == 200 {
                completion(true, "Profile updated successfully.")
            } else {
                completion(false, self?.parseErrorMessage(from: data) ?? "Failed to update profile.")
            }
        }.resume()
    }

    // ── Predict hot flash ──
    func predict(completion: @escaping (Bool, PredictionResult?, String) -> Void) {
        guard let url = URL(string: "\(baseURL)/predict") else {
            completion(false, nil, "Invalid server address.")
            return
        }

        guard let email = userEmail else {
            completion(false, nil, "User email not found. Please log in again.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["user_email": email]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(false, nil, "Network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, nil, "Invalid server response.")
                return
            }
            if httpResponse.statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                if let status = json["status"] as? String, status == "calibrating" {
                    let msg = json["message"] as? String ?? "Calibrating sensors..."
                    completion(false, nil, msg)
                    return
                }

                let result = PredictionResult(
                    riskPercent: json["risk_percent"] as? Int ?? 0,
                    riskLevel: json["risk_level"] as? String ?? "Low Risk",
                    message: json["message"] as? String ?? "",
                    skinTempC: json["skin_temp_c"] as? Double ?? 0.0,
                    heartRate: json["heart_rate"] as? Int ?? 0
                )
                completion(true, result, "")
            } else {
                completion(false, nil, self?.parseErrorMessage(from: data) ?? "Prediction failed.")
            }
        }.resume()
    }

    // ── Get prediction history ──
    func getHistory(completion: @escaping (Bool, [PredictionHistory], String) -> Void) {
        guard let url = URL(string: "\(baseURL)/history") else {
            completion(false, [], "Invalid server address.")
            return
        }

        let request = authorizedRequest(url: url, method: "GET")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(false, [], "Network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, [], "Invalid server response.")
                return
            }
            if httpResponse.statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let predictions = json["predictions"] as? [[String: Any]] {

                let history = predictions.compactMap { entry -> PredictionHistory? in
                    guard let riskPercent = entry["risk_percent"] as? Int,
                          let riskLevel = entry["risk_level"] as? String,
                          let temp = entry["skin_temp_c"] as? Double,
                          let hr = entry["heart_rate"] as? Int,
                          let ts = entry["timestamp"] as? String else { return nil }
                    return PredictionHistory(
                        riskPercent: riskPercent,
                        riskLevel: riskLevel,
                        skinTempC: temp,
                        heartRate: hr,
                        timestamp: ts
                    )
                }
                completion(true, history, "")
            } else {
                completion(false, [], self?.parseErrorMessage(from: data) ?? "Failed to load history.")
            }
        }.resume()
    }

    // ── Change password ──
    func changePassword(
        currentPassword: String,
        newPassword: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/change-password") else {
            completion(false, "Invalid server address.")
            return
        }

        var request = authorizedRequest(url: url, method: "POST")
        let body: [String: Any] = [
            "current_password": currentPassword,
            "new_password": newPassword
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid server response.")
                return
            }
            if httpResponse.statusCode == 200 {
                completion(true, "Password changed successfully.")
            } else {
                completion(false, self?.parseErrorMessage(from: data) ?? "Failed to change password.")
            }
        }.resume()
    }

    // ═══════════════════════════════════════════════════
    //  HOT FLASH EVENTS (Calendar)
    // ═══════════════════════════════════════════════════

    // ── Get all dates with hot flashes (auto + manual) ──
    func getHotFlashDates(completion: @escaping (Bool, [String], String) -> Void) {
        guard let url = URL(string: "\(baseURL)/hot-flash-events") else {
            completion(false, [], "Invalid server address.")
            return
        }
        let request = authorizedRequest(url: url, method: "GET")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(false, [], "Network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, [], "Invalid server response.")
                return
            }
            if httpResponse.statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dates = json["dates"] as? [String] {
                completion(true, dates, "")
            } else {
                completion(false, [], self?.parseErrorMessage(from: data) ?? "Failed to load events.")
            }
        }.resume()
    }

    // ── Log a hot flash for a given date (or today if nil) ──
    func logHotFlash(date: String? = nil,
                     note: String? = nil,
                     completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(baseURL)/hot-flash-events") else {
            completion(false, "Invalid server address.")
            return
        }
        guard let email = userEmail else {
            completion(false, "Not logged in.")
            return
        }

        var request = authorizedRequest(url: url, method: "POST")
        var body: [String: Any] = ["user_email": email]
        if let date = date { body["date"] = date }
        if let note = note { body["note"] = note }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid server response.")
                return
            }
            if httpResponse.statusCode == 200 {
                completion(true, "Logged.")
            } else {
                completion(false, self?.parseErrorMessage(from: data) ?? "Failed to log.")
            }
        }.resume()
    }

    // ── Unlog a hot flash for a given date ──
    func unlogHotFlash(date: String, completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(baseURL)/hot-flash-events/\(date)") else {
            completion(false, "Invalid server address.")
            return
        }
        let request = authorizedRequest(url: url, method: "DELETE")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid server response.")
                return
            }
            if httpResponse.statusCode == 200 {
                completion(true, "Unlogged.")
            } else {
                completion(false, self?.parseErrorMessage(from: data) ?? "Failed to unlog.")
            }
        }.resume()
    }
}
