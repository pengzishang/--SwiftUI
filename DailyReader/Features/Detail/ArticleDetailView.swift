import SwiftUI

enum ArticleDetailSource {
    case daily
    case coldPalace
    case favorites
    case read
}

struct ArticleDetailView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    let source: ArticleDetailSource
    let date: String

    @StateObject private var viewModel: ArticleDetailViewModel
    @State private var isShowingShareSheet = false
    @State private var htmlContentHeight: CGFloat = 520
    @State private var htmlReloadToken = 0
    @State private var htmlErrorMessage: String?

    @MainActor
    init(story: StorySummary, homeViewModel: HomeViewModel, source: ArticleDetailSource, date: String) {
        self.homeViewModel = homeViewModel
        self.source = source
        self.date = date
        _viewModel = StateObject(wrappedValue: AppEnvironment.makeDetailViewModel(story: story))
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .idle, .loading:
                LoadingView(message: "正在加载文章")
            case .failed(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.reload() }
                }
            case .loaded(let detail, _):
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let bannerMessage = viewModel.bannerMessage {
                            OfflineBanner(message: bannerMessage)
                        }
                        if let image = detail.image ?? detail.images.first {
                            PlaceholderImageView(urlString: image)
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        Text(detail.title.isEmpty ? viewModel.story.title : detail.title)
                            .font(.largeTitle.bold())
                            .lineLimit(nil)

                        if let body = detail.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            if let htmlErrorMessage {
                                ErrorStateView(message: htmlErrorMessage) {
                                    self.htmlErrorMessage = nil
                                    htmlReloadToken += 1
                                }
                                .frame(maxWidth: .infinity, minHeight: 240)
                            } else {
                                HTMLWebView(
                                    htmlBody: body,
                                    cssLinks: detail.css,
                                    reloadToken: htmlReloadToken,
                                    contentHeight: $htmlContentHeight
                                ) { message in
                                    htmlErrorMessage = message
                                }
                                .frame(minHeight: htmlContentHeight)
                                .accessibilityIdentifier("articleHTMLContent")
                            }
                        } else {
                            ContentUnavailableView("文章内容暂不可用", systemImage: "doc.text.magnifyingglass")
                                .frame(maxWidth: .infinity, minHeight: 240)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("文章详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: {
                        isShowingShareSheet = true
                    }) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.shareURL == nil)

                    if homeViewModel.isStoryFavorited(viewModel.story.id) {
                        Button(action: {
                            homeViewModel.toggleFavorite(viewModel.story, date: date)
                        }) {
                            Label("取消收藏", systemImage: "star.fill")
                        }
                    } else {
                        Button(action: {
                            homeViewModel.toggleFavorite(viewModel.story, date: date)
                        }) {
                            Label("收藏", systemImage: "star")
                        }
                    }

                    if homeViewModel.isStoryRead(viewModel.story.id) {
                        Button(action: {
                            homeViewModel.toggleRead(viewModel.story, date: date)
                        }) {
                            Label("设为未读", systemImage: "envelope.badge")
                        }
                    } else {
                        Button(action: {
                            homeViewModel.toggleRead(viewModel.story, date: date)
                        }) {
                            Label("设为已读", systemImage: "checkmark.circle")
                        }
                    }

                    if source == .coldPalace {
                        Button(action: {
                            homeViewModel.restoreStory(viewModel.story.id)
                        }) {
                            Label("恢复到日报", systemImage: "arrow.uturn.backward")
                        }
                    } else {
                        Button(action: {
                            homeViewModel.hideStory(viewModel.story, date: date)
                        }) {
                            Label("不感兴趣", systemImage: "eye.slash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("操作")
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let shareURL = viewModel.shareURL {
                ShareSheet(items: [viewModel.shareTitle, shareURL])
            }
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.loadedDetailID) { _, _ in
            htmlContentHeight = 520
            htmlErrorMessage = nil
        }
    }
}
