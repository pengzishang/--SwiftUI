import SwiftUI

struct TopStoriesView: View {
    let topStories: [TopStory]
    let readStoryIDs: Set<Int>
    let markRead: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(topStories) { story in
                    NavigationLink {
                        ArticleDetailView(viewModel: AppEnvironment.makeDetailViewModel(story: story.summary))
                            .onAppear {
                                markRead(story.id)
                            }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            PlaceholderImageView(urlString: story.image)
                                .frame(width: 240, height: 132)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            Text(story.title)
                                .font(.headline)
                                .foregroundStyle(readStoryIDs.contains(story.id) ? .secondary : .primary)
                                .lineLimit(2)
                        }
                        .frame(width: 240, alignment: .leading)
                        .padding(12)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .opacity(readStoryIDs.contains(story.id) ? 0.72 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityIdentifier("topStories")
    }
}

private extension TopStory {
    var summary: StorySummary {
        StorySummary(
            id: id,
            title: title,
            images: image.map { [$0] } ?? [],
            hint: "顶部故事",
            url: url
        )
    }
}
