import SwiftUI

struct ReadStoriesView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        List {
            if viewModel.readStories.isEmpty {
                ContentUnavailableView(
                    "暂无已读文章",
                    systemImage: "checkmark.circle",
                    description: Text("阅读日报文章后，已读记录将自动呈现在这里。")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.readSections) { section in
                    Section(header: Text(formattedDate(section.date))) {
                        ForEach(section.stories) { story in
                            NavigationLink {
                                ArticleDetailView(story: story, homeViewModel: viewModel, source: .read, date: section.date)
                                    .onAppear {
                                        viewModel.markStoryRead(story, date: section.date)
                                    }
                            } label: {
                                StoryRowView(story: story, isRead: viewModel.isStoryRead(story.id))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    viewModel.toggleRead(story, date: section.date)
                                } label: {
                                    Label("设为未读", systemImage: "envelope.badge")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("已读")
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
