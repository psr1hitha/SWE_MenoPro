//
//  CommunitiesView.swift
//  SWE_Menopro_UI
//
//  Community feed — post list, pull-to-refresh, floating write button.
//  Uses @State-driven navigation instead of NavigationLink(value:) for
//  reliable push inside a TabView NavigationStack.
//

import SwiftUI

// MARK: - CommunityPost: Hashable

extension CommunityPost: Hashable {
    static func == (lhs: CommunityPost, rhs: CommunityPost) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - CommunitiesView

struct CommunitiesView: View {
    @State private var posts: [CommunityPost] = []
    @State private var isLoading = false
    @State private var showWriteSheet = false

    // State-driven navigation to PostDetailView
    @State private var selectedPost: CommunityPost? = nil
    @State private var navigateToDetail = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.menoCream.ignoresSafeArea()

            List {
                VStack(spacing: 14) {
                    headerSection.padding(.top, 8)

                    if isLoading && posts.isEmpty {
                        loadingPlaceholder
                    } else if posts.isEmpty {
                        emptyState
                    } else {
                        postList
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
            .background(Color.menoCream)
            .refreshable { loadPosts() }

            writeButton
                .padding(.trailing, 20)
                .padding(.bottom, 24)

            // Hidden NavigationLink triggered by navigateToDetail flag
            NavigationLink(
                destination: Group {
                    if let post = selectedPost {
                        PostDetailView(post: post, onDeleted: {
                            navigateToDetail = false
                            selectedPost = nil
                            loadPosts()
                        })
                    }
                },
                isActive: $navigateToDetail
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadPosts)
        .onChange(of: navigateToDetail) { isActive in
            if !isActive { loadPosts() }
        }
        .sheet(isPresented: $showWriteSheet) {
            WritePostView(existingPost: nil) {
                showWriteSheet = false
                loadPosts()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("communities")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.menoMagenta)
                Text("Talk it out")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.menoTextPrimary)
            }
            Spacer()
        }
    }

    // MARK: - Post list

    private var postList: some View {
        VStack(spacing: 10) {
            ForEach(posts) { post in
                Button(action: {
                    selectedPost = post
                    navigateToDetail = true
                }) {
                    PostCard(
                        post: post,
                        onLikeToggled: { liked, count in
                            updateLike(postId: post.id, liked: liked, count: count)
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.menoMagentaSoft).frame(width: 64, height: 64)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.menoMagentaDark)
            }
            Text("No posts yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.menoTextPrimary)
            Text("Be the first to share something with the community.")
                .font(.system(size: 13))
                .foregroundColor(.menoTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .menoCard(radius: MenoRadius.large, padding: 18)
    }

    // MARK: - Loading skeleton

    private var loadingPlaceholder: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: MenoRadius.medium)
                    .fill(Color.menoCard)
                    .frame(height: 96)
                    .shimmering()
            }
        }
    }

    // MARK: - Floating write button

    private var writeButton: some View {
        Button(action: { showWriteSheet = true }) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Write")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.menoMagentaDark)
            .cornerRadius(24)
            .shadow(color: Color.menoMagentaDark.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Helpers

    private func updateLike(postId: String, liked: Bool, count: Int) {
        guard let idx = posts.firstIndex(where: { $0.id == postId }) else { return }
        let old = posts[idx]
        posts[idx] = CommunityPost(
            id: old.id, title: old.title, body: old.body,
            isAnonymous: old.isAnonymous, authorEmail: old.authorEmail,
            authorName: old.authorName, likeCount: count,
            commentCount: old.commentCount, likedByViewer: liked,
            isOwner: old.isOwner, createdAt: old.createdAt, updatedAt: old.updatedAt
        )
    }

    private func loadPosts() {
        isLoading = true
        APIService.shared.getCommunityPosts { success, fetched, _ in
            DispatchQueue.main.async {
                isLoading = false
                if success { posts = fetched }
            }
        }
    }
}

// MARK: - Post card

struct PostCard: View {
    let post: CommunityPost
    var onLikeToggled: ((Bool, Int) -> Void)?

    @State private var liked: Bool
    @State private var likeCount: Int

    init(post: CommunityPost, onLikeToggled: ((Bool, Int) -> Void)? = nil) {
        self.post = post
        self.onLikeToggled = onLikeToggled
        _liked     = State(initialValue: post.likedByViewer)
        _likeCount = State(initialValue: post.likeCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                avatarCircle(name: post.authorName, isAnonymous: post.isAnonymous, size: 24)
                Text(post.authorName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.menoTextSecondary)
                Spacer()
                Text(relativeTime(post.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.menoTextTertiary)
            }

            Text(post.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.menoTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(post.body)
                .font(.system(size: 13))
                .foregroundColor(.menoTextSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 16) {
                Button(action: handleLike) {
                    HStack(spacing: 4) {
                        Image(systemName: liked ? "heart.fill" : "heart")
                            .font(.system(size: 13))
                            .foregroundColor(liked ? .menoMagenta : .menoTextTertiary)
                        Text("\(likeCount)")
                            .font(.system(size: 12))
                            .foregroundColor(.menoTextTertiary)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 13))
                        .foregroundColor(.menoTextTertiary)
                    Text("\(post.commentCount)")
                        .font(.system(size: 12))
                        .foregroundColor(.menoTextTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.menoTextTertiary)
            }
        }
        .padding(14)
        .background(Color.menoCard)
        .cornerRadius(MenoRadius.medium)
    }

    private func handleLike() {
        liked.toggle()
        likeCount += liked ? 1 : -1
        APIService.shared.toggleLike(postId: post.id) { success, newLiked, newCount, _ in
            DispatchQueue.main.async {
                if success {
                    liked = newLiked
                    likeCount = newCount
                    onLikeToggled?(newLiked, newCount)
                } else {
                    liked.toggle()
                    likeCount += liked ? 1 : -1
                }
            }
        }
    }
}

// MARK: - Shared avatar helper

func avatarCircle(name: String, isAnonymous: Bool, size: CGFloat) -> some View {
    ZStack {
        Circle()
            .fill(isAnonymous ? Color.menoMuted : Color.menoMagentaSoft)
            .frame(width: size, height: size)
        Text(name.prefix(1).uppercased())
            .font(.system(size: size * 0.38, weight: .medium))
            .foregroundColor(isAnonymous ? .menoTextTertiary : .menoMagentaDark)
    }
}

// MARK: - Shimmer modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.35),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: phase * geo.size.width * 2 - geo.size.width)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}

#Preview {
    NavigationStack {
        CommunitiesView()
    }
}
