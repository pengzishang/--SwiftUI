import SwiftUI

struct StoryRowView: View {
    let story: StorySummary
    let isRead: Bool
    let displaysMetrics: Bool

    @StateObject private var metricsViewModel: StoryMetricsViewModel
    @AppStorage("DailyReader.listFontSize") private var listFontSize: Double = 16.0

    @MainActor
    init(story: StorySummary, isRead: Bool, displaysMetrics: Bool = false) {
        self.story = story
        self.isRead = isRead
        self.displaysMetrics = displaysMetrics
        _metricsViewModel = StateObject(
            wrappedValue: AppEnvironment.makeStoryMetricsViewModel(storyID: story.id)
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                // 标题用宋体，读起来像报纸版面；已读退为淡墨
                Text(story.title)
                    .font(DS.songBold(listFontSize + 1))
                    .foregroundStyle(isRead ? DS.inkSecondary : DS.ink)
                    .lineLimit(3)
                    .lineSpacing(3)

                if hasHint {
                    hintView
                        .padding(.top, 10)
                }

                if hasMetrics {
                    metricsView
                        .padding(.top, hasHint ? 8 : 14)
                        .transition(.opacity)
                }
            }
            Spacer(minLength: 10)
            // 缩略图压一圈髮丝线，像印刷品里的配图
            PlaceholderImageView(
                urlString: story.images.first,
                targetSize: CGSize(width: 72, height: 72)
            )
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(DS.hairline, lineWidth: 0.7)
                )
                .opacity(isRead ? 0.62 : 1)
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("storyRow-\(story.id)")
        .task(id: story.id) {
            guard displaysMetrics else { return }
            await metricsViewModel.load()
        }
    }

    private var hasHint: Bool {
        story.hint?.isEmpty == false
    }

    private var hasMetrics: Bool {
        displaysMetrics && metricsViewModel.metrics?.hasVisibleValues == true
    }

    @ViewBuilder
    private var hintView: some View {
        if let hint = story.hint, !hint.isEmpty {
            Text(hint)
                .font(.system(size: max(11, listFontSize - 4)))
                .foregroundStyle(DS.inkSecondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var metricsView: some View {
        if displaysMetrics,
           let metrics = metricsViewModel.metrics,
           metrics.hasVisibleValues {
            StoryMetricLine(metrics: metrics)
        }
    }
}
