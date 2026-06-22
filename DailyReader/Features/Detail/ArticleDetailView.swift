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

    @AppStorage("DailyReader.fontSize") private var fontSize: Double = 16.0
    @State private var selectedImage: IdentifiableImageURL?

    @MainActor
    init(story: StorySummary, homeViewModel: HomeViewModel, source: ArticleDetailSource, date: String) {
        self.homeViewModel = homeViewModel
        self.source = source
        self.date = date
        _viewModel = StateObject(wrappedValue: AppEnvironment.makeDetailViewModel(story: story))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let bannerMessage = viewModel.bannerMessage {
                    OfflineBanner(message: bannerMessage)
                }

                // 1. Cover Image (Instant from story summary, fallback to loaded detail cover)
                if let imageURL = detailImageURL {
                    PlaceholderImageView(urlString: imageURL)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    // 2. Title (Instant from story summary, fallback to loaded detail title)
                    Text(detailTitle)
                        .font(.largeTitle.bold())
                        .lineLimit(nil)

                    // 3. Body loading/loaded/failed phases
                    switch viewModel.phase {
                    case .idle, .loading:
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("正在加载内容...")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 40)
                            Spacer()
                        }
                    case .failed(let message):
                        ErrorStateView(message: message) {
                            Task { await viewModel.reload() }
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                    case .loaded(let detail, _):
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
                                    fontSize: fontSize,
                                    contentHeight: $htmlContentHeight,
                                    onImageTap: { url in
                                        selectedImage = IdentifiableImageURL(url: url)
                                    },
                                    onError: { message in
                                        htmlErrorMessage = message
                                    }
                                )
                                .frame(minHeight: htmlContentHeight)
                                .accessibilityIdentifier("articleHTMLContent")
                            }
                        } else {
                            ContentUnavailableView("文章内容暂不可用", systemImage: "doc.text.magnifyingglass")
                                .frame(maxWidth: .infinity, minHeight: 240)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.shareTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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

                    if source == .read {
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
                    } else {
                        Button(action: {
                            homeViewModel.markStoryRead(viewModel.story, date: date)
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
        .fullScreenCover(item: $selectedImage) { item in
            FullScreenImageViewer(urlString: item.url)
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.loadedDetailID) { _, _ in
            htmlContentHeight = 520
            htmlErrorMessage = nil
        }
    }

    private var detailImageURL: String? {
        if case .loaded(let detail, _) = viewModel.phase {
            return detail.image ?? detail.images.first ?? viewModel.story.images.first
        }
        return viewModel.story.images.first
    }

    private var detailTitle: String {
        if case .loaded(let detail, _) = viewModel.phase, !detail.title.isEmpty {
            return detail.title
        }
        return viewModel.story.title
    }
}

struct IdentifiableImageURL: Identifiable {
    var id: String { url }
    let url: String
}

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        // Add double tap gesture
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            hostingController.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.hostingController = hostingController
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController?.view
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: hostingController?.view)
                let zoomRect = calculateZoomRect(for: scrollView, at: point, with: 3.0)
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }

        private func calculateZoomRect(for scrollView: UIScrollView, at point: CGPoint, with scale: CGFloat) -> CGRect {
            let size = CGSize(
                width: scrollView.frame.size.width / scale,
                height: scrollView.frame.size.height / scale
            )
            let origin = CGPoint(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2
            )
            return CGRect(origin: origin, size: size)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Center the image view as it zooms
            guard let subView = hostingController?.view else { return }
            let offsetX = max((scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5, 0.0)
            let offsetY = max((scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5, 0.0)
            subView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX, y: scrollView.contentSize.height * 0.5 + offsetY)
        }
    }
}

struct FullScreenImageViewer: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ZoomableScrollView {
                AsyncImage(url: URL(string: urlString)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .failure:
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("图片加载失败")
                                .foregroundStyle(.secondary)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .ignoresSafeArea()

            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
    }
}
