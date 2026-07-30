import SwiftUI
import UIKit
import Kingfisher

enum RemoteImageSource: Equatable {
    case remote(URL)
    case dataImage(Data)
    case invalid

    init(_ urlString: String?) {
        guard let value = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            self = .invalid
            return
        }

        if value.lowercased().hasPrefix("data:") {
            self = Self.dataImageSource(from: value)
            return
        }

        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            self = .invalid
            return
        }

        self = .remote(url)
    }

    static func isDuplicate(_ first: String?, _ second: String?) -> Bool {
        guard case .remote(let firstURL) = RemoteImageSource(first),
              case .remote(let secondURL) = RemoteImageSource(second) else {
            return false
        }
        return firstURL == secondURL
    }

    private static func dataImageSource(from value: String) -> RemoteImageSource {
        guard let commaIndex = value.firstIndex(of: ",") else {
            return .invalid
        }

        let metadata = value[value.startIndex..<commaIndex].lowercased()
        guard metadata.hasPrefix("data:image/"),
              metadata.contains(";base64") else {
            return .invalid
        }

        let encodedData = String(value[value.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: encodedData, options: .ignoreUnknownCharacters),
              !data.isEmpty,
              UIImage(data: data) != nil else {
            return .invalid
        }

        return .dataImage(data)
    }
}

enum RemoteImageContentMode {
    case fill
    case fit
}

struct RemoteImageView: View {
    let source: RemoteImageSource
    var targetSize: CGSize?
    var contentMode: RemoteImageContentMode
    var placeholder: AnyView
    var failure: AnyView
    var retryCount: Int

    @Environment(\.displayScale) private var displayScale
    @State private var failedURL: URL?

    init(
        urlString: String?,
        targetSize: CGSize? = nil,
        contentMode: RemoteImageContentMode = .fill,
        placeholder: AnyView = AnyView(EmptyView()),
        failure: AnyView = AnyView(EmptyView()),
        retryCount: Int = 2
    ) {
        source = RemoteImageSource(urlString)
        self.targetSize = targetSize
        self.contentMode = contentMode
        self.placeholder = placeholder
        self.failure = failure
        self.retryCount = retryCount
    }

    var body: some View {
        switch source {
        case .remote(let url):
            remoteImage(url: url)
        case .dataImage(let data):
            if let image = UIImage(data: data) {
                configuredImage(Image(uiImage: image))
            } else {
                failure
            }
        case .invalid:
            failure
        }
    }

    @ViewBuilder
    private func remoteImage(url: URL) -> some View {
        ZStack {
            if failedURL == url {
                failure
            } else if let targetSize {
                configuredImage(
                    KFImage.url(url)
                        .setProcessor(DownsamplingImageProcessor(size: targetSize))
                        .scaleFactor(displayScale)
                        .cacheOriginalImage()
                        .placeholder { placeholder }
                        .retry(maxCount: retryCount, interval: .seconds(1))
                        .cancelOnDisappear(true)
                        .fade(duration: 0.2)
                        .onSuccess { _ in
                            failedURL = nil
                        }
                        .onFailure { error in
                            guard !error.isTaskCancelled else { return }
                            failedURL = url
                        }
                        .resizable()
                )
            } else {
                configuredImage(
                    KFImage.url(url)
                        .placeholder { placeholder }
                        .retry(maxCount: retryCount, interval: .seconds(1))
                        .cancelOnDisappear(true)
                        .fade(duration: 0.2)
                        .onSuccess { _ in
                            failedURL = nil
                        }
                        .onFailure { error in
                            guard !error.isTaskCancelled else { return }
                            failedURL = url
                        }
                        .resizable()
                )
            }
        }
        .onChange(of: url) { _, _ in
            failedURL = nil
        }
    }

    @ViewBuilder
    private func configuredImage<ImageView: View>(_ image: ImageView) -> some View {
        switch contentMode {
        case .fill:
            image.scaledToFill()
        case .fit:
            image.aspectRatio(contentMode: .fit)
        }
    }
}
