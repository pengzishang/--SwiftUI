import SwiftUI

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(DS.inkSecondary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DS.inkSecondary)
        }
        .padding(32)
        .accessibilityIdentifier("loadingView")
    }
}
