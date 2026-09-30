import SwiftUI

extension Color {
    static let ink = Color(hex: 0x07110E)
    static let forest = Color(hex: 0x102920)
    static let pine = Color(hex: 0x1B3D31)
    static let volt = Color(hex: 0xC6F34A)
    static let pulse = Color(hex: 0x3DFF9A)
    static let canvas = Color(hex: 0xF3F5F1)
    static let card = Color.white
    static let hairline = Color(hex: 0xDDE3DC)
    static let mist = Color(hex: 0xE8EEE6)
    static let alert = Color(hex: 0xFF4D3A)
    static let warn = Color(hex: 0xFFB020)
    static let info = Color(hex: 0x4D7CFF)
    static let mute = Color(hex: 0x5C6B64)

    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum AppFont {
    static let largeTitle = Font.custom("ClashDisplay-Bold", size: 40)
    static let section = Font.custom("ClashDisplay-Semibold", size: 24)
    static let cardTitle = Font.custom("ClashDisplay-Semibold", size: 22)
    static let metric = Font.custom("ClashDisplay-Bold", size: 44)
    static let button = Font.custom("Satoshi-Bold", size: 17)
    static let body = Font.custom("Satoshi-Regular", size: 16)
    static let bodyMedium = Font.custom("Satoshi-Medium", size: 16)
    static let label = Font.custom("Satoshi-Medium", size: 13)
    static let caption = Font.custom("Satoshi-Regular", size: 13)
    static let captionMedium = Font.custom("Satoshi-Medium", size: 13)
    static let tab = Font.custom("Satoshi-Medium", size: 10)
    static let chip = Font.custom("Satoshi-Medium", size: 12)
    static let unit = Font.custom("Satoshi-Medium", size: 15)
}

enum AppTracking {
    static let largeTitle: CGFloat = -1.2
    static let section: CGFloat = -0.6
    static let metric: CGFloat = -1.4
}
