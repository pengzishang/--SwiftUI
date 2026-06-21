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
                ForEach(viewModel.sections) { section in
                    Section(header: Text(formattedDate(section.date))) {
                        ForEach(section.stories) { story in
                            NavigationLink {
                                ArticleDetailView(story: story)
                                    .onAppear {
                                        viewModel.markStoryRead(story.id)
                                    }
                            } label: {
                                StoryRowView(story: story, isRead: viewModel.isStoryRead(story.id))
                            }
                        }
                    }
                }

                HistoryPaginationFooter(state: viewModel.historyLoadState) {
                    Task { await viewModel.loadMore() }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .id("footer-\(viewModel.sections.count)")
                .task {
                    await viewModel.loadMore()
                }
            }
        }
        .navigationTitle("日报阅读器")
        .navigationBarTitleDisplayMode(.inline)
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

private struct HistoryPaginationFooter: View {
    let state: HistoryLoadState
    let loadMore: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            switch state {
            case .idle:
                Color.clear
                    .frame(height: 1)
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
