//
//  WritePostView.swift
//  SWE_Menopro_UI
//
//  Sheet for creating a new post or editing an existing one.
//  Pass existingPost = nil for new, or a CommunityPost to edit.
//

import SwiftUI

struct WritePostView: View {
    let existingPost: CommunityPost?
    var onFinished: () -> Void

    @State private var title: String
    @State private var postBody: String   // named postBody to avoid conflict with SwiftUI's 'body'
    @State private var isAnonymous: Bool

    @State private var isSubmitting = false
    @State private var errorMessage = ""

    private let titleLimit = 100
    private let bodyLimit  = 1000

    init(existingPost: CommunityPost?, onFinished: @escaping () -> Void) {
        self.existingPost = existingPost
        self.onFinished = onFinished
        _title       = State(initialValue: existingPost?.title ?? "")
        _postBody    = State(initialValue: existingPost?.body  ?? "")
        _isAnonymous = State(initialValue: existingPost?.isAnonymous ?? false)
    }

    private var isEditing: Bool { existingPost != nil }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !postBody.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isSubmitting
    }

    var body: some View {
        ZStack {
            Color.menoCream.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider().background(Color.menoMuted)

                ScrollView {
                    VStack(spacing: 16) {
                        anonymousToggle
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        titleField
                            .padding(.horizontal, 16)

                        bodyField
                            .padding(.horizontal, 16)

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.menoRiskImminent)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 40)
                    }
                }

                submitButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button(action: onFinished) {
                Text("Cancel")
                    .font(.system(size: 14))
                    .foregroundColor(.menoTextSecondary)
            }
            Spacer()
            Text(isEditing ? "Edit Post" : "New Post")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.menoTextPrimary)
            Spacer()
            Text("Cancel").opacity(0) // balance
        }
    }

    // MARK: - Anonymous toggle

    private var anonymousToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Post anonymously")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.menoTextPrimary)
                Text("Your name won't be shown to others.")
                    .font(.system(size: 12))
                    .foregroundColor(.menoTextSecondary)
            }
            Spacer()
            Toggle("", isOn: $isAnonymous)
                .labelsHidden()
                .tint(.menoMagenta)
        }
        .padding(14)
        .background(Color.menoCard)
        .cornerRadius(MenoRadius.medium)
    }

    // MARK: - Title field

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TITLE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.menoTextSecondary)

            TextField("What's on your mind?", text: $title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.menoTextPrimary)
                .onChange(of: title) {
                    if title.count > titleLimit {
                        title = String(title.prefix(titleLimit))
                    }
                }

            HStack {
                Spacer()
                Text("\(title.count)/\(titleLimit)")
                    .font(.system(size: 10))
                    .foregroundColor(.menoTextTertiary)
            }
        }
        .padding(14)
        .background(Color.menoCard)
        .cornerRadius(MenoRadius.medium)
    }

    // MARK: - Body field

    private var bodyField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BODY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.menoTextSecondary)

            TextEditor(text: $postBody)
                .font(.system(size: 14))
                .foregroundColor(.menoTextPrimary)
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .onChange(of: postBody) {
                    if postBody.count > bodyLimit {
                        postBody = String(postBody.prefix(bodyLimit))
                    }
                }

            HStack {
                Spacer()
                Text("\(postBody.count)/\(bodyLimit)")
                    .font(.system(size: 10))
                    .foregroundColor(.menoTextTertiary)
            }
        }
        .padding(14)
        .background(Color.menoCard)
        .cornerRadius(MenoRadius.medium)
    }

    // MARK: - Submit button

    private var submitButton: some View {
        Button(action: submit) {
            if isSubmitting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                Text(isEditing ? "Save changes" : "Post")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .background(canSubmit ? Color.menoMagentaDark : Color.menoTextTertiary)
        .cornerRadius(MenoRadius.medium)
        .disabled(!canSubmit)
    }

    // MARK: - Submit

    private func submit() {
        errorMessage = ""
        isSubmitting = true

        if isEditing, let post = existingPost {
            // Pass isAnonymous so the backend can update author_name too
            APIService.shared.updatePost(
                postId: post.id,
                title: title,
                body: postBody,
                isAnonymous: isAnonymous
            ) { success, message in
                DispatchQueue.main.async {
                    isSubmitting = false
                    if success { onFinished() } else { errorMessage = message }
                }
            }
        } else {
            APIService.shared.createPost(
                title: title,
                body: postBody,
                isAnonymous: isAnonymous
            ) { success, message in
                DispatchQueue.main.async {
                    isSubmitting = false
                    if success { onFinished() } else { errorMessage = message }
                }
            }
        }
    }
}

#Preview {
    WritePostView(existingPost: nil) { }
}
