import SwiftUI

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(DS.inkSecondary)
            Text(message)
                .font(DS.songBold(16))
                .foregroundStyle(DS.ink)
                .multilineTextAlignment(.center)
            Button("重试", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .accessibilityIdentifier("errorStateView")
    }
}
