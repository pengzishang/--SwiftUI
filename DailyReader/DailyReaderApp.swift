import SwiftUI

@main
struct DailyReaderApp: App {
    init() {
        // 启动时套用「今日刊」全局外观（导航栏 / 标签栏）
        DS.applyGlobalAppearance()
        ImageCacheService.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
