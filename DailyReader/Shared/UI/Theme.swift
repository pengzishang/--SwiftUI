import SwiftUI
import UIKit

// MARK: - 「今日刊」设计系统
//
// 纸墨刊物设计语言：暖纸作底、浓墨为字，靛蓝如蓝黑墨水作全局强调，
// 朱砂只用于「今日」印章与热榜首位等点睛之处。
// 字体上由宋体承担刊头、标题与大号数字，正文与辅助信息仍用系统黑体保证可读性。
// 所有颜色均为深浅色自适应的动态色。

enum DS {

    // MARK: 色板（UIColor 动态色）

    /// 纸底：页面背景
    static let paperUI = dynamicColor(light: (249, 246, 239), dark: (20, 19, 17))
    /// 纸面浮层：卡片、输入框、分组行背景
    static let paperElevatedUI = dynamicColor(light: (255, 254, 250), dark: (31, 29, 25))
    /// 浓墨：主文字
    static let inkUI = dynamicColor(light: (38, 34, 27), dark: (232, 227, 216))
    /// 淡墨：辅助文字、未选中态
    static let inkSecondaryUI = dynamicColor(light: (112, 107, 94), dark: (162, 156, 140))
    /// 靛蓝（蓝黑墨水）：链接、按钮、选中与强调
    static let indigoUI = dynamicColor(light: (44, 74, 124), dark: (148, 173, 218))
    /// 朱砂：「今日」印章、热榜第一、警示
    static let cinnabarUI = dynamicColor(light: (183, 55, 41), dark: (224, 108, 88))
    /// 赭石：热榜第二
    static let ochreUI = dynamicColor(light: (176, 105, 36), dark: (216, 153, 86))
    /// 藤黄：热榜第三（取印刷可读的暗金，避免纯黄在纸面上失色）
    static let goldUI = dynamicColor(light: (150, 122, 29), dark: (202, 178, 92))
    /// 髮丝线：分隔线与描边
    static let hairlineUI = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 232 / 255, green: 227 / 255, blue: 216 / 255, alpha: 0.16)
            : UIColor(red: 38 / 255, green: 34 / 255, blue: 27 / 255, alpha: 0.14)
    }

    // MARK: 色板（SwiftUI Color）

    static let paper = Color(paperUI)
    static let paperElevated = Color(paperElevatedUI)
    static let ink = Color(inkUI)
    static let inkSecondary = Color(inkSecondaryUI)
    static let indigo = Color(indigoUI)
    static let cinnabar = Color(cinnabarUI)
    static let ochre = Color(ochreUI)
    static let gold = Color(goldUI)
    static let hairline = Color(hairlineUI)

    // MARK: 字体
    // 宋体只用于结构性文字：刊头、标题、日期与大号数字。

    /// 宋体特粗：刊头、热榜数字、详情大标题
    static func songBlack(_ size: CGFloat) -> Font {
        .custom("STSongti-SC-Black", size: size)
    }

    /// 宋体加粗：列表标题、节标题
    static func songBold(_ size: CGFloat) -> Font {
        .custom("STSongti-SC-Bold", size: size)
    }

    static func uiSongBlack(_ size: CGFloat) -> UIFont {
        UIFont(name: "STSongti-SC-Black", size: size) ?? .boldSystemFont(ofSize: size)
    }

    static func uiSongBold(_ size: CGFloat) -> UIFont {
        UIFont(name: "STSongti-SC-Bold", size: size) ?? .boldSystemFont(ofSize: size)
    }

    // MARK: 全局外观（导航栏 / 标签栏）

    /// 在 App 启动时调用一次，让导航栏与标签栏与纸面融为一体。
    static func applyGlobalAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = paperUI
        // 滚动中露出一条髮丝线，与内容区分层
        nav.shadowColor = hairlineUI
        nav.titleTextAttributes = [
            .font: uiSongBold(17),
            .foregroundColor: inkUI
        ]
        nav.largeTitleTextAttributes = [
            .font: uiSongBlack(31),
            .foregroundColor: inkUI
        ]

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        // 刻意不设置 scrollEdgeAppearance：全局覆盖它会让 NavigationStack
        // 在置顶时渲染不出大标题。留空后系统自动从 standardAppearance 派生
        // 置顶样式（透明背景 + 相同文字属性），透出的正是纸色页面。

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = paperUI
        tab.shadowColor = hairlineUI
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.selected.iconColor = inkUI
            item.selected.titleTextAttributes = [.foregroundColor: inkUI]
            item.normal.iconColor = inkSecondaryUI.withAlphaComponent(0.72)
            item.normal.titleTextAttributes = [.foregroundColor: inkSecondaryUI.withAlphaComponent(0.72)]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    // MARK: 私有

    private static func dynamicColor(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> UIColor {
        UIColor { trait in
            let value = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0 / 255, green: value.1 / 255, blue: value.2 / 255, alpha: 1)
        }
    }
}

// MARK: - 中文日期工具

enum ChineseDate {
    private static let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
    private static let weekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()

    /// 当前日期的 yyyyMMdd 字符串
    static var todayString: String {
        parser.string(from: Date())
    }

    static func isToday(_ yyyymmdd: String) -> Bool {
        yyyymmdd == todayString
    }

    /// "20260726" → 「七月二十六日」；跨年时带上「二〇二五年」前缀
    static func formatted(_ yyyymmdd: String) -> String? {
        guard yyyymmdd.count == 8,
              let month = Int(yyyymmdd.dropFirst(4).prefix(2)),
              let day = Int(yyyymmdd.suffix(2)),
              (1...12).contains(month), (1...31).contains(day) else {
            return nil
        }
        let year = String(yyyymmdd.prefix(4))
        var result = "\(number(month))月\(number(day))日"
        if year != String(todayString.prefix(4)) {
            let chineseYear = year.compactMap { char in
                char.wholeNumberValue.map { digits[$0] }
            }
            .joined()
            .replacingOccurrences(of: "零", with: "〇")
            result = "\(chineseYear)年" + result
        }
        return result
    }

    /// "20260726" → 「星期日」
    static func weekday(_ yyyymmdd: String) -> String? {
        guard let date = parser.date(from: yyyymmdd) else { return nil }
        let index = Calendar(identifier: .gregorian).component(.weekday, from: date) - 1
        guard weekdays.indices.contains(index) else { return nil }
        return weekdays[index]
    }

    /// 1...31 → 一、十、二十六……
    private static func number(_ value: Int) -> String {
        switch value {
        case 1...9: return digits[value]
        case 10: return "十"
        case 11...19: return "十" + digits[value - 10]
        case 20: return "二十"
        case 21...29: return "二十" + digits[value - 20]
        case 30: return "三十"
        case 31: return "三十一"
        default: return "\(value)"
        }
    }
}

// MARK: - 印章章记
// 朱砂底白字的小方章，圆角刻意压到 3pt，保留「盖上去」的印章感。

struct SealChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DS.songBold(11))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(DS.cinnabar)
            )
    }
}

// MARK: - 文武线
// 报纸报眉惯用的一粗一细双线，是「今日刊」的结构签名。

struct RuleLine: View {
    var body: some View {
        VStack(spacing: 2.5) {
            Rectangle()
                .fill(DS.ink.opacity(0.82))
                .frame(height: 1.4)
            Rectangle()
                .fill(DS.hairline)
                .frame(height: 0.6)
        }
    }
}

// MARK: - 日期刊头
// 列表分节的日期栏：印章（仅今日）+ 宋体中文日期 + 星期 + 篇数，下压文武线。

struct DatelineHeader: View {
    let date: String
    var storyCount: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if ChineseDate.isToday(date) {
                    SealChip(text: "今日")
                }
                Text(title)
                    .font(DS.songBold(19))
                    .foregroundStyle(DS.ink)
                if let weekday = ChineseDate.weekday(date) {
                    Text(weekday)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.inkSecondary)
                }
                Spacer(minLength: 8)
                if let storyCount {
                    Text("\(storyCount) 篇")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.inkSecondary)
                }
            }
            RuleLine()
        }
        .padding(.top, 14)
        .padding(.bottom, 2)
        .background(DS.paper)
    }

    private var title: String {
        if let formatted = ChineseDate.formatted(date) {
            return formatted
        }
        return date.isEmpty ? "今日" : date
    }
}

// MARK: - 通用修饰

extension View {
    /// 列表纸面化：隐藏系统列表背景，铺上纸色
    func paperListBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(DS.paper.ignoresSafeArea())
    }
}
