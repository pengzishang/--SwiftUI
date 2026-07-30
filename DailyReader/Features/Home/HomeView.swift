import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject private var aiCoordinator: AIChatCoordinator

    var body: some View {
        List {
            if let bannerMessage = viewModel.bannerMessage {
                OfflineBanner(message: bannerMessage)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            switch viewModel.phase {
            case .idle, .loading:
                LoadingView(message: "正在加载日报")
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            case .failed(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.refresh() }
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            case .empty:
                ContentUnavailableView("今日暂无内容", systemImage: "newspaper", description: Text("稍后再试，或者下拉刷新。"))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            case .loaded:
                ForEach(viewModel.visibleSections) { section in
                    // 每一天是一期：分节头做成带文武线的日期刊头
                    Section {
                        ForEach(section.stories) { story in
                            NavigationLink {
                                ArticleDetailView(story: story, homeViewModel: viewModel, source: .daily, date: section.date)
                                    .onAppear {
                                        viewModel.markStoryRead(story, date: section.date)
                                    }
                            } label: {
                                StoryRowView(
                                    story: story,
                                    isRead: viewModel.isStoryRead(story.id),
                                    displaysMetrics: true
                                )
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(DS.hairline)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.hideStory(story, date: section.date)
                                } label: {
                                    Label("不感兴趣", systemImage: "eye.slash")
                                }
                                .tint(DS.cinnabar)
                            }
                            .onAppear {
                                if story.id == viewModel.thresholdStoryID {
                                    Task {
                                        await viewModel.loadMore()
                                    }
                                }
                            }
                        }
                    } header: {
                        DatelineHeader(date: section.date, storyCount: section.stories.count)
                            .textCase(nil)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 4, trailing: 20))
                    }
                }

                HistoryPaginationFooter(state: viewModel.historyLoadState) {
                    Task { await viewModel.loadMore() }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .paperListBackground()
        .navigationTitle("日报阅读器")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    aiCoordinator.openIndependentChat()
                } label: {
                    Text("知")
                        .font(DS.songBlack(16))
                        .foregroundStyle(DS.indigo)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("AI 搜索")
                .accessibilityHint("打开独立 AI 对话")
                .accessibilityIdentifier("home.aiButton")
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.load()
        }
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
                        .tint(DS.inkSecondary)
                    Text("正在加载更早日报")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.inkSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            case .failed(let message):
                VStack(spacing: 10) {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(DS.inkSecondary)
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
