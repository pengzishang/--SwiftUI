import SwiftUI

struct PlaceholderImageView: View {
    let urlString: String?
    var thumbnailURLString: String? = nil
    var targetSize: CGSize? = nil

    var body: some View {
        let isSame = RemoteImageSource.isDuplicate(urlString, thumbnailURLString)

        ZStack {
            placeholder

            if !isSame, thumbnailURLString != nil {
                RemoteImageView(
                    urlString: thumbnailURLString,
                    targetSize: targetSize
                )
            }

            RemoteImageView(
                urlString: urlString,
                targetSize: targetSize
            )
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(DS.paperElevated)
            // 宋体「日」字水印，占位时也像一枚小小的报头
            Text("日")
                .font(DS.songBlack(26))
                .foregroundStyle(DS.inkSecondary.opacity(0.38))
        }
    }
}
