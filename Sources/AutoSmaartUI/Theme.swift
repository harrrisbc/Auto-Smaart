import CoreText
import SwiftUI

public enum ThemeMetrics {
    public static let windowWidth: CGFloat = 1440
    public static let windowHeight: CGFloat = 900
    public static let titleBar: CGFloat = 56
    public static let rail: CGFloat = 220
    public static let bottomBar: CGFloat = 64
    public static let row: CGFloat = 36
    public static let pagePadding: CGFloat = 20
    public static let groupGap: CGFloat = 16
}

public enum Theme {
    static let backgroundHex = "0a0a0a"
    static let textHex = "ffffff"
    static let secondaryHex = "a3a3a3"
    static let goldHex = "a78b71"
    static let lightGoldHex = "c9b8a0"
    static let hoverGoldHex = "e8d5b7"
    static let liveHex = "4ade80"
    static let beforeHex = "a78b71"
    static let afterHex = "e8d5b7"

    static let background = Color(hex: 0x0a0a0a)
    static let text = Color(hex: 0xffffff)
    static let secondary = Color(hex: 0xa3a3a3)
    static let dim = Color.white.opacity(0.45)
    static let gold = Color(hex: 0xa78b71)
    static let lightGold = Color(hex: 0xc9b8a0)
    static let hoverGold = Color(hex: 0xe8d5b7)
    static let live = Color(hex: 0x4ade80)
    static let grid = Color.white.opacity(0.12)
    static let selectedRow = Color(hex: 0xa78b71).opacity(0.16)
    static let raised = Color.white.opacity(0.03)
    static let stroke = Color.white.opacity(0.1)
    static let beforeTrace = Color(hex: 0xa78b71).opacity(0.7)
    static let afterTrace = Color(hex: 0xe8d5b7)

    static func registerFonts() {
        for name in ["Inter-VariableFont", "PlayfairDisplay-Italic-VariableFont"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xff) / 255
        let green = Double((hex >> 8) & 0xff) / 255
        let blue = Double(hex & 0xff) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

struct PrimaryButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Inter", size: 13).weight(.medium))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(height: ThemeMetrics.row)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(.plain)
    }
}

struct QuietButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Inter", size: 13))
                .foregroundStyle(Theme.secondary)
        }
        .buttonStyle(.plain)
    }
}
