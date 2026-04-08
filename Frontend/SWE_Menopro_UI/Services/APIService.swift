//
//  APIService.swift
//  SWE_Menopro_UI
//
//  Created by Jenna's MacBook Pro on 4/8/26.
//


import Foundation

class APIService {
    static let shared = APIService()
    let baseURL = "http://127.0.0.1:8001"
    
    // Sign Up
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
        guard let url = URL(string: "\(baseURL)/signup") else { return }
        
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
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    completion(true, "Signup successful")
                } else {
                    completion(false, "Signup failed")
                }
            }
        }.resume()
    }
    
    // Login
    func login(
        email: String,
        password: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/login") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    completion(true, "Login successful")
                } else {
                    completion(false, "Invalid email or password")
                }
            }
        }.resume()
    }
}
