import SwiftUI

struct FavoritesView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        List {
            if viewModel.favoriteStories.isEmpty {
                ContentUnavailableView(
                    "暂无收藏内容",
                    systemImage: "star",
                    description: Text("阅读日报时，可在详情页右上角的菜单中添加收藏。")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.favoriteSections) { section in
                    Section(header: Text(formattedDate(section.date))) {
                        ForEach(section.stories) { story in
                            NavigationLink {
                                ArticleDetailView(story: story, homeViewModel: viewModel, source: .favorites, date: section.date)
                                    .onAppear {
                                        viewModel.markStoryRead(story, date: section.date)
                                    }
                            } label: {
                                StoryRowView(story: story, isRead: viewModel.isStoryRead(story.id))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    viewModel.toggleFavorite(story, date: section.date)
                                } label: {
                                    Label("取消收藏", systemImage: "star.slash")
                                }
                                .tint(.gray)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("收藏")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formattedDate(_ date: String) -> String {
        guard date.count == 8 else { return date.isEmpty ? "今日" : date }
        let year = date.prefix(4)
        let month = date.dropFirst(4).prefix(2)
        let day = date.suffix(2)
        return "\(year)年\(month)月\(day)日"
    }
}
