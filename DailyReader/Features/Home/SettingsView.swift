import SwiftUI

struct SettingsView: View {
    @AppStorage("DailyReader.fontSize") private var fontSize: Double = 16.0

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
                        Text("字体大小")
                    } minimumValueLabel: {
                        Text("A").font(.system(size: 14))
                    } maximumValueLabel: {
                        Text("A").font(.system(size: 22))
                    }
                }
                .padding(.vertical, 4)
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
        switch Int(fontSize) {
        case 14: return "较小"
        case 16: return "标准"
        case 18: return "中"
        case 20: return "较大"
        case 22: return "特大"
        default: return "标准"
        }
    }
}
