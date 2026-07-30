import SwiftUI

struct StoryMetricLine: View {
    let metrics: DailyStoryMetrics

    var body: some View {
        HStack(spacing: 9) {
            if let popularity = metrics.popularity {
                metricLabel(
                    title: "\(MetricNumberFormatter.compact(popularity)) 热度",
                    systemImage: "chart.bar.xaxis"
                )
            }
            if let comments = metrics.comments {
                metricLabel(
                    title: "\(MetricNumberFormatter.compact(comments)) 评论",
                    systemImage: "bubble.left"
                )
            }
        }
        .font(.caption2)
        .foregroundStyle(DS.inkSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("storyMetrics")
    }

    private func metricLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
            Text(title)
                .monospacedDigit()
        }
    }

    private var accessibilityText: String {
        [
            metrics.popularity.map { "知乎日报热度 \($0)" },
            metrics.comments.map { "评论 \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: "，")
    }
}

struct ArticleMetricByline: View {
    let daily: DailyStoryMetrics?
    let originalAnswer: OriginalAnswerMetrics?

    var body: some View {
        if hasVisibleValues {
            VStack(alignment: .leading, spacing: 7) {
                if let daily, daily.hasVisibleValues {
                    metricRow(
                        source: "日报数据",
                        values: dailyValues(daily),
                        accessibilityText: dailyAccessibilityText(daily)
                    )
                }
                if let originalAnswer, originalAnswer.hasVisibleValues {
                    metricRow(
                        source: "原回答",
                        values: answerValues(originalAnswer),
                        accessibilityText: answerAccessibilityText(originalAnswer)
                    )
                }
            }
            .padding(.vertical, 10)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DS.hairline)
                    .frame(height: 0.7)
            }
        }
    }

    private var hasVisibleValues: Bool {
        daily?.hasVisibleValues == true || originalAnswer?.hasVisibleValues == true
    }

    private func metricRow(
        source: String,
        values: [String],
        accessibilityText: String
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                sourceLabel(source)
                Text(values.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(DS.inkSecondary)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 3) {
                sourceLabel(source)
                Text(values.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(DS.inkSecondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier(
            source == "日报数据" ? "articleMetrics.daily" : "articleMetrics.originalAnswer"
        )
    }

    private func sourceLabel(_ source: String) -> some View {
        Text(source)
            .font(DS.songBold(12))
            .foregroundStyle(DS.ink)
            .frame(minWidth: 48, alignment: .leading)
    }

    private func dailyValues(_ metrics: DailyStoryMetrics) -> [String] {
        [
            metrics.popularity.map { "热度 \(MetricNumberFormatter.precise($0))" },
            metrics.comments.map { "评论 \(MetricNumberFormatter.precise($0))" }
        ]
        .compactMap { $0 }
    }

    private func answerValues(_ metrics: OriginalAnswerMetrics) -> [String] {
        [
            metrics.voteupCount.map { "赞同 \(MetricNumberFormatter.precise($0))" },
            metrics.commentCount.map { "评论 \(MetricNumberFormatter.precise($0))" },
            metrics.favoriteListCount.map { "收藏 \(MetricNumberFormatter.precise($0))" }
        ]
        .compactMap { $0 }
    }

    private func dailyAccessibilityText(_ metrics: DailyStoryMetrics) -> String {
        [
            "日报数据",
            metrics.popularity.map { "热度 \($0)" },
            metrics.comments.map { "评论 \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: "，")
    }

    private func answerAccessibilityText(_ metrics: OriginalAnswerMetrics) -> String {
        [
            "原回答",
            metrics.voteupCount.map { "赞同 \($0)" },
            metrics.commentCount.map { "评论 \($0)" },
            metrics.favoriteListCount.map { "收藏 \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: "，")
    }
}

enum MetricNumberFormatter {
    static func precise(_ value: Int) -> String {
        value.formatted(.number.locale(Locale(identifier: "zh_CN")))
    }

    static func compact(_ value: Int) -> String {
        guard value >= 10_000 else { return precise(value) }
        let unitValue = Double(value) / 10_000
        let formatted = unitValue >= 100 || unitValue.rounded() == unitValue
            ? String(format: "%.0f", unitValue)
            : String(format: "%.1f", unitValue)
        return "\(formatted) 万"
    }
}
