import SwiftUI

struct StoryRowView: View {
    let story: StorySummary
    let isRead: Bool

    @AppStorage("DailyReader.listFontSize") private var listFontSize: Double = 16.0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(story.title)
                    .font(.system(size: listFontSize, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                if let hint = story.hint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: max(10, listFontSize - 3)))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            PlaceholderImageView(urlString: story.images.first)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("storyRow-\(story.id)")
    }
}
