import SwiftUI

struct AccountCardView: View {
    @ObservedObject var viewModel: AuthenticationViewModel

    var body: some View {
        Group {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 14) { content }
                VStack(alignment: .leading, spacing: 12) { content }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(DS.paperElevated))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(DS.hairline, lineWidth: 0.7))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("auth.card")
        .confirmationDialog(
            "退出知乎账号？",
            isPresented: $viewModel.isShowingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("退出登录", role: .destructive) { viewModel.confirmSignOut() }
                .accessibilityIdentifier("auth.signOut.confirm")
            Button("取消", role: .cancel) { viewModel.cancelSignOut() }
                .accessibilityIdentifier("auth.signOut.cancel")
        } message: {
            Text("退出后将清除本机知乎登录状态，收藏和已读不会删除。")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .unconfigured:
            icon(systemName: "person.crop.circle.badge.exclamationmark")
            textBlock(title: "登录知乎账号", status: "知乎登录暂不可用")
            Button("知乎登录暂不可用") {}
                .buttonStyle(AuthPrimaryButtonStyle())
                .disabled(true)
                .accessibilityIdentifier("auth.signInButton")
        case let .signedOut(notice):
            icon(systemName: "person.crop.circle")
            textBlock(
                title: "登录知乎账号",
                status: notice ?? "授权后仅显示昵称与头像，不会改变本地收藏和已读。"
            )
            Button("使用知乎登录") { viewModel.signIn() }
                .buttonStyle(AuthPrimaryButtonStyle())
                .accessibilityIdentifier("auth.signInButton")
        case .preparingAuthorization, .authorizing, .processingCallback, .loadingProfile, .restoring:
            ProgressView().controlSize(.regular).accessibilityHidden(true)
            textBlock(title: "登录知乎账号", status: progressText)
        case let .signedIn(profile):
            avatar(profile: profile)
            textBlock(title: profile.displayName, status: "已登录知乎账号", displayNameIdentifier: true)
            Button("退出登录") { viewModel.requestSignOut() }
                .buttonStyle(AuthSecondaryButtonStyle())
                .accessibilityIdentifier("auth.signOutButton")
        case let .signingOut(profile):
            avatar(profile: profile)
            textBlock(title: profile.displayName, status: "正在退出…", displayNameIdentifier: true)
            ProgressView().accessibilityHidden(true)
        case let .retryableFailure(failure):
            icon(systemName: "exclamationmark.circle")
            textBlock(title: "登录遇到问题", status: failure.message, isError: true)
            Button("重试") { viewModel.retry() }
                .buttonStyle(AuthPrimaryButtonStyle())
                .accessibilityIdentifier("auth.retryButton")
        case let .invalidCallback(message), let .sessionExpired(message):
            icon(systemName: "exclamationmark.shield")
            textBlock(title: "需要重新登录", status: message, isError: true)
            Button("重新登录") { viewModel.signIn() }
                .buttonStyle(AuthPrimaryButtonStyle())
                .accessibilityIdentifier("auth.retryButton")
        }
    }

    private var progressText: String {
        switch viewModel.state {
        case .preparingAuthorization: return "正在准备安全登录…"
        case .authorizing: return "正在等待授权…"
        case .processingCallback: return "正在验证登录回调…"
        case .loadingProfile: return "正在获取账号资料…"
        case .restoring: return "正在恢复登录…"
        default: return ""
        }
    }

    private func textBlock(title: String, status: String, isError: Bool = false, displayNameIdentifier: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(DS.songBold(18))
                .foregroundStyle(DS.ink)
                .accessibilityIdentifier(displayNameIdentifier ? "auth.displayName" : "auth.title")
            Text(status)
                .font(.system(size: 14))
                .foregroundStyle(isError ? DS.cinnabar : DS.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(isError ? "auth.error" : "auth.status")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func icon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 38))
            .foregroundStyle(DS.indigo)
            .frame(width: 52, height: 52)
            .accessibilityHidden(true)
    }

    private func avatar(profile: AuthUserProfile) -> some View {
        AsyncImage(url: profile.avatarURL) { phase in
            if case let .success(image) = phase {
                image.resizable().scaledToFill()
            } else {
                Image(systemName: "person.fill").resizable().scaledToFit().padding(12).foregroundStyle(DS.indigo)
            }
        }
        .frame(width: 56, height: 56)
        .background(DS.paper)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(DS.hairline, lineWidth: 0.7))
        .accessibilityLabel("\(profile.displayName)的头像")
        .accessibilityIdentifier("auth.avatar")
    }
}

private struct AuthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DS.paper)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(DS.indigo.opacity(configuration.isPressed ? 0.78 : 1)))
    }
}

private struct AuthSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DS.indigo)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(DS.indigo, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
