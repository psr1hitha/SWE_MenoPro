//
//  CommunityModels.swift
//  SWE_Menopro_UI
//
//  Community data models, APIService extension, and shared date helper.
//

import Foundation

// MARK: - Post model

struct CommunityPost: Identifiable, Decodable {
    let id: String
    let title: String
    let body: String
    let isAnonymous: Bool
    let authorEmail: String?
    let authorName: String
    let likeCount: Int
    let commentCount: Int
    let likedByViewer: Bool
    let isOwner: Bool
    let createdAt: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case isAnonymous   = "is_anonymous"
        case authorEmail   = "author_email"
        case authorName    = "author_name"
        case likeCount     = "like_count"
        case commentCount  = "comment_count"
        case likedByViewer = "liked_by_viewer"
        case isOwner       = "is_owner"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }
}

// MARK: - Comment model

struct CommunityComment: Identifiable, Decodable {
    let id: String
    let postId: String
    let body: String
    let isAnonymous: Bool
    let authorEmail: String?
    let authorName: String
    let isOwner: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, body
        case postId      = "post_id"
        case isAnonymous = "is_anonymous"
        case authorEmail = "author_email"
        case authorName  = "author_name"
        case isOwner     = "is_owner"
        case createdAt   = "created_at"
    }
}

// MARK: - Shared date helper

/// Returns a human-readable relative time string from an ISO8601 date string.
func relativeTime(_ isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var date = formatter.date(from: isoString)
    if date == nil {
        formatter.formatOptions = [.withInternetDateTime]
        date = formatter.date(from: isoString)
    }
    guard let date = date else { return "" }
    let diff = Int(Date().timeIntervalSince(date))
    switch diff {
    case ..<60:    return "just now"
    case ..<3600:  return "\(diff / 60)m ago"
    case ..<86400: return "\(diff / 3600)h ago"
    default:       return "\(diff / 86400)d ago"
    }
}

// MARK: - APIService community extension

extension APIService {

    // ── Fetch a single post by ID (used to refresh PostDetailView after edit) ──
    // NOTE: GET /community/posts/{id} returns the post dict directly — no wrapper key.
    func getPost(
        postId: String,
        completion: @escaping (Bool, CommunityPost?, String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/community/posts/\(postId)") else {
            completion(false, nil, "Invalid URL"); return
        }
        let request = authorizedRequest(url: url)
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            if let error = error { completion(false, nil, error.localizedDescription); return }
            // Backend returns the post dict directly (no {"post": ...} wrapper)
            guard let data = data,
                  let post = try? JSONDecoder().decode(CommunityPost.self, from: data)
            else {
                completion(false, nil, self?.parseErrorMessage(from: data) ?? "Parse error"); return
            }
            completion(true, post, "")
        }.resume()
    }

    // ── Fetch feed ──
    func getCommunityPosts(
        authorMe: Bool = false,
        completion: @escaping (Bool, [CommunityPost], String) -> Void
    ) {
        var urlStr = "\(baseURL)/community/posts"
        if authorMe { urlStr += "?author_me=true" }
        guard let url = URL(string: urlStr) else {
            completion(false, [], "Invalid URL"); return
        }
        let request = authorizedRequest(url: url)
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            if let error = error { completion(false, [], error.localizedDescription); return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawPosts = json["posts"] as? [[String: Any]] else {
                completion(false, [], self?.parseErrorMessage(from: data) ?? "Parse error"); return
            }
            let posts: [CommunityPost] = rawPosts.compactMap { dict in
                guard let d = try? JSONSerialization.data(withJSONObject: dict),
                      let post = try? JSONDecoder().decode(CommunityPost.self, from: d)
                else { return nil }
                return post
            }
            completion(true, posts, "")
        }.resume()
    }

    // ── Create post ──
    func createPost(
        title: String,
        body: String,
        isAnonymous: Bool,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/community/posts") else {
            completion(false, "Invalid URL"); return
        }
        var request = authorizedRequest(url: url, method: "POST")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "title": title, "body": body, "is_anonymous": isAnonymous
        ])
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error { completion(false, error.localizedDescription); return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            completion(status == 200, status == 200 ? "" : (self?.parseErrorMessage(from: data) ?? "Error"))
        }.resume()
    }

    // ── Update post — includes isAnonymous so author_name updates too ──
    func updatePost(
        postId: String,
        title: String,
        body: String,
        isAnonymous: Bool,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/community/posts/\(postId)") else {
            completion(false, "Invalid URL"); return
        }
        var request = authorizedRequest(url: url, method: "PATCH")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "title": title,
            "body": body,
            "is_anonymous": isAnonymous
        ])
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error { completion(false, error.localizedDescription); return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            completion(status == 200, status == 200 ? "" : (self?.parseErrorMessage(from: data) ?? "Error"))
        }.resume()
    }

    // ── Delete post ──
    func deletePost(
        postId: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/community/posts/\(postId)") else {
            completion(false, "Invalid URL"); return
        }
        let request = authorizedRequest(url: url, method: "DELETE")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error { completion(false, error.localizedDescription); return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            completion(status == 200, status == 200 ? "" : (self?.parseErrorMessage(from: data) ?? "Error"))
        }.resume()
    }

    // ── Like toggle ──
    func toggleLike(
        postId: String,
        completion: @escaping (Bool, Bool, Int, String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/community/posts/\(postId)/like") else {
            completion(false, false, 0, "Invalid URL"); return
        }
        let request = authorizedRequest(url: url, method: "POST")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            if let error = error { completion(false, false, 0, error.localizedDescription); return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let liked = json["liked"] as? Bool,
                  let count = json["like_count"] as? Int
            else {
                completion(false, false, 0, self?.parseErrorMessage(from: data) ?? "Error"); return
            }
            completion(true, liked, count, "")
        }.resume()
    }

    // ── Get comments ──
    func getComments(
        postId: String,
        completion: @escaping (Bool, [CommunityComment], String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/community/posts/\(postId)/comments") else {
            completion(false, [], "Invalid URL"); return
        }
        let request = authorizedRequest(url: url)
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            if let error = error { completion(false, [], error.localizedDescription); return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawComments = json["comments"] as? [[String: Any]]
            else {
                completion(false, [], self?.parseErrorMessage(from: data) ?? "Parse error"); return
            }
            let comments: [CommunityComment] = rawComments.compactMap { dict in
                guard let d = try? JSONSerialization.data(withJSONObject: dict),
                      let c = try? JSONDecoder().decode(CommunityComment.self, from: d)
                else { return nil }
                return c
            }
            completion(true, comments, "")
        }.resume()
    }

    // ── Create comment ──
    func createComment(
        postId: String,
        body: String,
        isAnonymous: Bool,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/community/posts/\(postId)/comments") else {
            completion(false, "Invalid URL"); return
        }
        var request = authorizedRequest(url: url, method: "POST")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "post_id": postId, "body": body, "is_anonymous": isAnonymous
        ])
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error { completion(false, error.localizedDescription); return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            completion(status == 200, status == 200 ? "" : (self?.parseErrorMessage(from: data) ?? "Error"))
        }.resume()
    }

    // ── Delete comment ──
    func deleteComment(
        commentId: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/community/comments/\(commentId)") else {
            completion(false, "Invalid URL"); return
        }
        let request = authorizedRequest(url: url, method: "DELETE")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error { completion(false, error.localizedDescription); return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            completion(status == 200, status == 200 ? "" : (self?.parseErrorMessage(from: data) ?? "Error"))
        }.resume()
    }

    // ── Report ──
    func reportContent(
        targetId: String,
        targetType: String,
        reason: String? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/community/reports") else {
            completion(false, "Invalid URL"); return
        }
        var request = authorizedRequest(url: url, method: "POST")
        var payload: [String: Any] = ["target_id": targetId, "target_type": targetType]
        if let r = reason { payload["reason"] = r }
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error { completion(false, error.localizedDescription); return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            completion(status == 200, status == 200 ? "" : (self?.parseErrorMessage(from: data) ?? "Error"))
        }.resume()
    }
}
