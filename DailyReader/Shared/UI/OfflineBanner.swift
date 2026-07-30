import SwiftUI

struct OfflineBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DS.cinnabar)
            Text(message)
                .font(.footnote)
                .foregroundStyle(DS.ink)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DS.cinnabar.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(DS.cinnabar.opacity(0.28), lineWidth: 0.7)
        )
        .accessibilityIdentifier("offlineBanner")
    }
}
