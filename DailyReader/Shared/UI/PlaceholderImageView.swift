import SwiftUI

struct PlaceholderImageView: View {
    let urlString: String?
    var thumbnailURLString: String? = nil

    var body: some View {
        let isSame = urlString != nil && urlString == thumbnailURLString
        ZStack {
            // Background/Thumbnail layer
            if !isSame, let thumbnailURLString, let thumbURL = URL(string: thumbnailURLString) {
                AsyncImage(url: thumbURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                    }
                }
            }

            // Main/High-res layer
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        if isSame || thumbnailURLString == nil {
                            placeholder
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        if isSame || thumbnailURLString == nil {
                            placeholder
                        }
                    @unknown default:
                        if isSame || thumbnailURLString == nil {
                            placeholder
                        }
                    }
                }
            } else if !isSame, thumbnailURLString != nil {
                EmptyView()
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.secondary.opacity(0.12))
            Image(systemName: "newspaper")
                .foregroundStyle(.secondary)
        }
    }
}
