import SwiftUI

struct ReadStoriesView: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var searchText = ""

    var filteredStories: [ReadStory] {
        if searchText.isEmpty {
            return viewModel.visibleReadStories
        } else {
            return viewModel.visibleReadStories.filter {
                $0.story.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        List {
            if viewModel.visibleReadStories.isEmpty {
                ContentUnavailableView(
                    "暂无已读文章",
                    systemImage: "checkmark.circle",
                    description: Text("阅读日报文章后，已读记录将自动呈现在这里。")
                )
                .listRowSeparator(.hidden)
            } else if filteredStories.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(filteredStories) { readStory in
                    let story = readStory.story
                    NavigationLink {
                        ArticleDetailView(story: story, homeViewModel: viewModel, source: .read, date: readStory.date)
                            .onAppear {
                                viewModel.markStoryRead(story, date: readStory.date)
                            }
                    } label: {
                        StoryRowView(story: story, isRead: viewModel.isStoryRead(story.id))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            viewModel.toggleRead(story, date: readStory.date)
                        } label: {
                            Label("设为未读", systemImage: "envelope.badge")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .navigationTitle("已读")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索已读文章")
    }
}
