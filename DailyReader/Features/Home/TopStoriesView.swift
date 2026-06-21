import SwiftUI

struct TopStoriesView: View {
    let topStories: [TopStory]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(topStories) { story in
                    VStack(alignment: .leading, spacing: 10) {
                        PlaceholderImageView(urlString: story.image)
                            .frame(width: 240, height: 132)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text(story.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    .frame(width: 240, alignment: .leading)
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
        .accessibilityIdentifier("topStories")
    }
}
