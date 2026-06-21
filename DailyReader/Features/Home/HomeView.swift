import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        List {
            if let bannerMessage = viewModel.bannerMessage {
                OfflineBanner(message: bannerMessage)
                    .listRowSeparator(.hidden)
            }

            switch viewModel.phase {
            case .idle, .loading:
                LoadingView(message: "正在加载日报")
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            case .failed(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.refresh() }
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
            case .empty:
                ContentUnavailableView("今日暂无内容", systemImage: "newspaper", description: Text("稍后再试，或者下拉刷新。"))
                    .listRowSeparator(.hidden)
            case .loaded:
                HomeStatusHeaderView(
                    date: viewModel.sections.first?.date,
                    source: viewModel.loadedContentSource
                )
                .listRowSeparator(.hidden)

                if !viewModel.topStories.isEmpty {
                    Section {
                        TopStoriesView(topStories: viewModel.topStories)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                    }
                }

                ForEach(viewModel.sections) { section in
                    Section(header: Text(formattedDate(section.date))) {
                        ForEach(section.stories) { story in
                            NavigationLink {
                                ArticleDetailView(viewModel: AppEnvironment.makeDetailViewModel(story: story))
                            } label: {
                                StoryRowView(story: story)
                            }
                        }
                    }
                }

                HistoryPaginationFooter(state: viewModel.historyLoadState) {
                    Task { await viewModel.loadMore() }
                }
                .listRowSeparator(.hidden)
            }
        }
        .navigationTitle("日报阅读器")
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.load()
        }
    }

    private func formattedDate(_ date: String) -> String {
        guard date.count == 8 else { return date.isEmpty ? "今日" : date }
        let year = date.prefix(4)
        let month = date.dropFirst(4).prefix(2)
        let day = date.suffix(2)
        return "\(year)年\(month)月\(day)日"
    }
}

private extension HomeViewModel {
    var loadedContentSource: ContentSource? {
        if case .loaded(let source) = phase {
            return source
        }
        return nil
    }
}

private struct HomeStatusHeaderView: View {
    let date: String?
    let source: ContentSource?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dateLabel)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            HStack(spacing: 8) {
                Label(sourceLabel, systemImage: sourceIcon)
                    .font(.caption)
                    .foregroundStyle(sourceColor)
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("homeStatusHeader")
    }

    private var dateLabel: String {
        guard let date, date.count == 8 else { return "今日日报" }
        let month = date.dropFirst(4).prefix(2)
        let day = date.suffix(2)
        return "\(month)月\(day)日 · 今日日报"
    }

    private var sourceLabel: String {
        guard let source else { return "正在准备内容" }
        switch source {
        case .network:
            return "实时内容"
        case .cache(let cachedAt):
            if let cachedAt {
                return "缓存内容 · \(cachedAt.formatted(date: .omitted, time: .shortened))"
            }
            return "缓存内容"
        }
    }

    private var sourceIcon: String {
        source?.isCache == true ? "externaldrive" : "bolt.horizontal.circle"
    }

    private var sourceColor: Color {
        source?.isCache == true ? .orange : .secondary
    }
}

private struct HistoryPaginationFooter: View {
    let state: HistoryLoadState
    let loadMore: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            switch state {
            case .idle:
                Button(action: loadMore) {
                    Label("加载更早日报", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("正在加载更早日报")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            case .failed(let message):
                VStack(spacing: 8) {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("重试加载历史", action: loadMore)
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .accessibilityIdentifier("historyPaginationFooter")
    }
}
