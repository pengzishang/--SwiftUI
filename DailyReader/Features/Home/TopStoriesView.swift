import SwiftUI

struct TopStoriesView: View {
    let topStories: [TopStory]
    let readStoryIDs: Set<Int>
    let markRead: (Int) -> Void
    @ObservedObject var homeViewModel: HomeViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(topStories) { story in
                    NavigationLink {
                        ArticleDetailView(story: story.summary, homeViewModel: homeViewModel, source: .daily, date: "")
                            .onAppear {
                                markRead(story.id)
                            }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            PlaceholderImageView(
                                urlString: story.image,
                                targetSize: CGSize(width: 240, height: 132)
                            )
                                .frame(width: 240, height: 132)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(DS.hairline, lineWidth: 0.7)
                                )
                            Text(story.title)
                                .font(DS.songBold(17))
                                .foregroundStyle(readStoryIDs.contains(story.id) ? DS.inkSecondary : DS.ink)
                                .lineLimit(2)
                        }
                        .frame(width: 240, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DS.paperElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(DS.hairline, lineWidth: 0.7)
                        )
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
