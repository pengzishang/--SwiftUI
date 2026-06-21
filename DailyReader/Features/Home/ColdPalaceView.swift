import SwiftUI

struct ColdPalaceView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        List {
            if viewModel.hiddenStories.isEmpty {
                ContentUnavailableView(
                    "冷宫空空如也",
                    systemImage: "snowflake",
                    description: Text("在日报列表中左滑，点击“不感兴趣”即可将文章移入冷宫。")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.hiddenSections) { section in
                    Section(header: Text(formattedDate(section.date))) {
                        ForEach(section.stories) { story in
                            NavigationLink {
                                ArticleDetailView(story: story, homeViewModel: viewModel, source: .coldPalace, date: section.date)
                                    .onAppear {
                                        viewModel.markStoryRead(story, date: section.date)
                                    }
                            } label: {
                                StoryRowView(story: story, isRead: viewModel.isStoryRead(story.id))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    viewModel.restoreStory(story.id)
                                } label: {
                                    Label("恢复", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("冷宫")
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
