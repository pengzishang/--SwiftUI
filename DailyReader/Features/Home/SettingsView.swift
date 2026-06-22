import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: HomeViewModel
    @AppStorage("DailyReader.fontSize") private var fontSize: Double = 16.0
    @AppStorage("DailyReader.listFontSize") private var listFontSize: Double = 16.0

    var body: some View {
        List {
            Section(header: Text("阅读设置")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("文章字体大小")
                        Spacer()
                        Text(fontSizeLabel)
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: $fontSize, in: 14...22, step: 2) {
                        Text("文章字体大小")
                    } minimumValueLabel: {
                        Text("A").font(.system(size: 14))
                    } maximumValueLabel: {
                        Text("A").font(.system(size: 22))
                    }
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("列表字体大小")
                        Spacer()
                        Text(listFontSizeLabel)
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: $listFontSize, in: 14...22, step: 2) {
                        Text("列表字体大小")
                    } minimumValueLabel: {
                        Text("A").font(.system(size: 14))
                    } maximumValueLabel: {
                        Text("A").font(.system(size: 22))
                    }
                }
                .padding(.vertical, 4)
            }

            Section(header: Text("阅读管理")) {
                NavigationLink(destination: ColdPalaceView(viewModel: viewModel)) {
                    Label("冷宫", systemImage: "snowflake")
                }
            }
            
            Section(header: Text("关于")) {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.1")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("设置")
    }

    private var fontSizeLabel: String {
        label(for: fontSize)
    }

    private var listFontSizeLabel: String {
        label(for: listFontSize)
    }

    private func label(for size: Double) -> String {
        switch Int(size) {
        case 14: return "较小"
        case 16: return "标准"
        case 18: return "中"
        case 20: return "较大"
        case 22: return "特大"
        default: return "标准"
        }
    }
}
