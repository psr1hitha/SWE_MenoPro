//
//  PostDetailView.swift
//  SWE_Menopro_UI
//
//  Full post detail with inline comments, like toggle, edit/delete (owner),
//  report (non-owner), and a fixed comment composer at the bottom.
//

import SwiftUI

struct PostDetailView: View {
    // @State so the view can reflect edits (title, body, anonymous flag) without dismissing
    @State private var post: CommunityPost
    var onDeleted: (() -> Void)?

    @Environment(\.presentationMode) var presentationMode

    // Mutable like state
    @State private var liked: Bool
    @State private var likeCount: Int

    // Comments
    @State private var comments: [CommunityComment] = []
    @State private var isLoadingComments = false

    // Comment composer
    @State private var commentText = ""
    @State private var commentAnonymous = false
    @State private var isSubmittingComment = false

    // Sheets / alerts
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showReportAlert = false
    @State private var reportTargetId = ""
    @State private var reportTargetType = ""

    @State private var feedbackMessage = ""

    init(post: CommunityPost, onDeleted: (() -> Void)? = nil) {
        _post      = State(initialValue: post)
        self.onDeleted = onDeleted
        _liked     = State(initialValue: post.likedByViewer)
        _likeCount = State(initialValue: post.likeCount)
    }

    var body: some View {
        ZStack {
            Color.menoCream.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        postSection
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        commentsDivider

                        commentsSection
                            .padding(.horizontal, 16)

                        Spacer(minLength: 100)
                    }
                }

                commentInputBar
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadComments)
        .sheet(isPresented: $showEditSheet) {
            // Pass the current (possibly already-edited) post so toggle/text values are correct
            WritePostView(existingPost: post) {
                showEditSheet = false
                // Re-fetch the post from the server so author name, title, and body
                // all reflect the saved changes without popping back to the feed
                refreshPost()
            }
        }
        .alert("Delete this post?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deletePost() }
        } message: {
            Text("This will also remove all comments.")
        }
        .alert("Report this content?", isPresented: $showReportAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Report", role: .destructive) { submitReport() }
        } message: {
            Text("We'll review it and take appropriate action.")
        }
    }

    // MARK: - Post section

    private var postSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Navigation bar row
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
                Menu {
                    if post.isOwner {
                        Button(action: { showEditSheet = true }) {
                            Label("Edit post", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: { showDeleteAlert = true }) {
                            Label("Delete post", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive, action: {
                            reportTargetId = post.id
                            reportTargetType = "post"
                            showReportAlert = true
                        }) {
                            Label("Report post", systemImage: "flag")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.menoTextSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.menoCard)
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 4)

            // Author row
            HStack(spacing: 8) {
                avatarCircle(name: post.authorName, isAnonymous: post.isAnonymous, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(post.authorName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.menoTextPrimary)
                    Text(relativeTime(post.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(.menoTextTertiary)
                }
            }

            // Title
            Text(post.title)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.menoTextPrimary)

            // Body
            Text(post.body)
                .font(.system(size: 14))
                .foregroundColor(.menoTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Like + comment count row
            HStack(spacing: 16) {
                Button(action: handleLike) {
                    HStack(spacing: 5) {
                        Image(systemName: liked ? "heart.fill" : "heart")
                            .font(.system(size: 15))
                            .foregroundColor(liked ? .menoMagenta : .menoTextTertiary)
                        Text("\(likeCount)")
                            .font(.system(size: 13))
                            .foregroundColor(.menoTextTertiary)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 5) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 15))
                        .foregroundColor(.menoTextTertiary)
                    Text("\(comments.count)")
                        .font(.system(size: 13))
                        .foregroundColor(.menoTextTertiary)
                }
                Spacer()
            }
            .padding(.top, 4)

            if !feedbackMessage.isEmpty {
                Text(feedbackMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.menoMagenta)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Comments divider

    private var commentsDivider: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.menoMuted).frame(height: 1)
            Text("Comments")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.menoTextTertiary)
                .fixedSize()
            Rectangle().fill(Color.menoMuted).frame(height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Comments list

    private var commentsSection: some View {
        VStack(spacing: 12) {
            if isLoadingComments {
                ProgressView().tint(.menoMagenta).frame(maxWidth: .infinity).padding()
            } else if comments.isEmpty {
                Text("No comments yet. Be the first!")
                    .font(.system(size: 13))
                    .foregroundColor(.menoTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(comments) { comment in
                    CommentRow(
                        comment: comment,
                        onDelete: { deleteComment(id: comment.id) },
                        onReport: {
                            reportTargetId = comment.id
                            reportTargetType = "comment"
                            showReportAlert = true
                        }
                    )
                }
            }
        }
    }

    // MARK: - Comment input bar

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.menoMuted)

            VStack(spacing: 8) {
                // Anonymous toggle
                HStack {
                    Toggle(isOn: $commentAnonymous) {
                        Text("Post anonymously")
                            .font(.system(size: 12))
                            .foregroundColor(.menoTextSecondary)
                    }
                    .tint(.menoMagenta)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Text field + send button
                HStack(spacing: 10) {
                    TextField("Write a comment...", text: $commentText)
                        .font(.system(size: 14))
                        .foregroundColor(.menoTextPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.menoCard)
                        .cornerRadius(MenoRadius.small)

                    Button(action: submitComment) {
                        if isSubmittingComment {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 40, height: 40)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                        }
                    }
                    .background(
                        commentText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.menoTextTertiary : Color.menoMagentaDark
                    )
                    .clipShape(Circle())
                    .disabled(
                        commentText.trimmingCharacters(in: .whitespaces).isEmpty ||
                        isSubmittingComment
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(Color.menoCream)
        }
    }

    // MARK: - Actions

    private func handleLike() {
        liked.toggle()
        likeCount += liked ? 1 : -1
        APIService.shared.toggleLike(postId: post.id) { success, newLiked, newCount, _ in
            DispatchQueue.main.async {
                if success {
                    liked = newLiked
                    likeCount = newCount
                } else {
                    liked.toggle()
                    likeCount += liked ? 1 : -1
                }
            }
        }
    }

    private func refreshPost() {
        APIService.shared.getCommunityPosts { success, fetched, _ in
            DispatchQueue.main.async {
                if success, let updated = fetched.first(where: { $0.id == post.id }) {
                    post = updated
                }
            }
        }
    }

    private func loadComments() {
        isLoadingComments = true
        APIService.shared.getComments(postId: post.id) { success, fetched, _ in
            DispatchQueue.main.async {
                isLoadingComments = false
                if success { comments = fetched }
            }
        }
    }

    private func submitComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSubmittingComment = true
        APIService.shared.createComment(
            postId: post.id, body: trimmed, isAnonymous: commentAnonymous
        ) { success, _ in
            DispatchQueue.main.async {
                isSubmittingComment = false
                if success {
                    commentText = ""
                    loadComments()
                }
            }
        }
    }

    private func deletePost() {
        APIService.shared.deletePost(postId: post.id) { success, _ in
            DispatchQueue.main.async {
                if success {
                    onDeleted?()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    private func deleteComment(id: String) {
        APIService.shared.deleteComment(commentId: id) { success, _ in
            DispatchQueue.main.async {
                if success { comments.removeAll { $0.id == id } }
            }
        }
    }

    private func submitReport() {
        APIService.shared.reportContent(
            targetId: reportTargetId, targetType: reportTargetType
        ) { success, msg in
            DispatchQueue.main.async {
                feedbackMessage = success ? "Reported. Thank you." : msg
            }
        }
    }
}

// MARK: - Comment row

struct CommentRow: View {
    let comment: CommunityComment
    var onDelete: (() -> Void)?
    var onReport: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                avatarCircle(name: comment.authorName, isAnonymous: comment.isAnonymous, size: 26)

                Text(comment.authorName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.menoTextSecondary)

                Text(relativeTime(comment.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.menoTextTertiary)

                Spacer()

                Menu {
                    if comment.isOwner {
                        Button(role: .destructive, action: { onDelete?() }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive, action: { onReport?() }) {
                            Label("Report", systemImage: "flag")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13))
                        .foregroundColor(.menoTextTertiary)
                        .frame(width: 28, height: 28)
                }
            }

            Text(comment.body)
                .font(.system(size: 13))
                .foregroundColor(.menoTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 34)
        }
        .padding(12)
        .background(Color.menoCard)
        .cornerRadius(MenoRadius.medium)
    }
}

#Preview {
    NavigationStack {
        PostDetailView(post: CommunityPost(
            id: "preview",
            title: "Does anyone else get night sweats?",
            body: "I've been waking up drenched at 3am every night. My doctor suggested HRT but I'm nervous. Has anyone tried it?",
            isAnonymous: false,
            authorEmail: nil,
            authorName: "Sarah K.",
            likeCount: 12,
            commentCount: 4,
            likedByViewer: false,
            isOwner: true,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: nil
        ))
    }
}
