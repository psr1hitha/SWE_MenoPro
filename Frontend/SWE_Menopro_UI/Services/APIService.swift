//
//  APIService.swift
//  SWE_Menopro_UI
//

import Foundation

class APIService {
    static let shared = APIService()

    // Local testing: 127.0.0.1:8000
    // Replace with your deployed server URL in production
    let baseURL = "http://127.0.0.1:8000"

    // ── Token storage (UserDefaults — suitable for prototype) ──
    // For production, replace with Keychain storage
    var authToken: String? {
        get { UserDefaults.standard.string(forKey: "auth_token") }
        set { UserDefaults.standard.set(newValue, forKey: "auth_token") }
    }

    var isLoggedIn: Bool { authToken != nil }

    func logout() {
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }

    // ── Build an authorized URLRequest with JWT header ────
    private func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // ── Parse error detail from server response ───────────
    private func parseErrorMessage(from data: Data?) -> String {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = json["detail"] as? String else {
            return "An unknown error occurred."
        }
        return detail
    }

    // ── Sign up ───────────────────────────────────────────
    func signUp(
        firstName: String,
        lastName: String,
        email: String,
        password: String,
        age: Int,
        bmi: Double,
        isSmoker: Bool,
        alcoholPerWeek: Int,
        caffeinePerWeek: Int,
        race: String,
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
            "bmi": bmi,
            "is_smoker": isSmoker,
            "alcohol_per_week": alcoholPerWeek,
            "caffeine_per_week": caffeinePerWeek,
            "race": race
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
                // Save JWT token returned from server
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["token"] as? String {
                    self?.authToken = token
                }
                completion(true, "Sign up successful.")
            } else {
                completion(false, self?.parseErrorMessage(from: data) ?? "Sign up failed.")
            }
        }.resume()
    }

    // ── Login ─────────────────────────────────────────────
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
                // Save JWT token returned from server
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["token"] as? String {
                    self?.authToken = token
                }
                completion(true, "Login successful.")
            } else {
                completion(false, self?.parseErrorMessage(from: data) ?? "Login failed.")
            }
        }.resume()
    }

    // ── Get profile ───────────────────────────────────────
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

    // ── Update profile ────────────────────────────────────
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

    // ── Change password ───────────────────────────────────
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
}
