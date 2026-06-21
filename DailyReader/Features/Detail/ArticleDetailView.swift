import SwiftUI

struct ArticleDetailView: View {
    @ObservedObject var viewModel: ArticleDetailViewModel
    @State private var isShowingShareSheet = false

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
                            HTMLWebView(htmlBody: body, cssLinks: detail.css)
                                .frame(minHeight: 520)
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
                Button {
                    isShowingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(viewModel.shareURL == nil)
                .accessibilityLabel("分享")
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
    }
}
