import SwiftUI

struct StoryRowView: View {
    let story: StorySummary
    let isRead: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(story.title)
                    .font(.headline)
                    .foregroundStyle(isRead ? .secondary : .primary)
                    .lineLimit(3)
                if let hint = story.hint, !hint.isEmpty {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(isRead ? .tertiary : .secondary)
                }
            }
            Spacer(minLength: 8)
            PlaceholderImageView(urlString: story.images.first)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(isRead ? 0.62 : 1)
        }
        .padding(.vertical, 6)
        .opacity(isRead ? 0.72 : 1)
        .accessibilityIdentifier("storyRow-\(story.id)")
    }
}
