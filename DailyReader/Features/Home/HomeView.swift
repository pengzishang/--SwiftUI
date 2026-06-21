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

                Button {
                    Task { await viewModel.loadMore() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isLoadingMore {
                            ProgressView()
                        } else {
                            Text("加载更早日报")
                        }
                        Spacer()
                    }
                }
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
