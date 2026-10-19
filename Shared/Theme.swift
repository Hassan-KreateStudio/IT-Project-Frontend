import SwiftUI
import UIKit

extension Color {
    static let ink = Color(hex: 0x0A0A0A)
    static let night = Color(hex: 0x161616)
    static let dusk = Color(hex: 0x2A2A2A)
    static let flare = Color(hex: 0xFF3DAB)
    static let acid = Color(hex: 0xD8FF3C)
    static let aurora = Color(hex: 0x3DFFE7)
    static let canvas = Color(hex: 0xF6F4F0)
    static let card = Color.white
    static let hairline = Color(hex: 0xE6E2DC)
    static let mist = Color(hex: 0xEFECE6)
    static let alert = Color(hex: 0xFF4D3A)
    static let warn = Color(hex: 0xFFB020)
    static let info = Color(hex: 0x4D7CFF)
    static let mute = Color(hex: 0x6E6E6E)

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
    static let poster = Font.custom("BricolageGrotesque-ExtraBold", size: 128)
    static let slab = Font.custom("BricolageGrotesque-ExtraBold", size: 56)
    static let largeTitle = Font.custom("BricolageGrotesque-ExtraBold", size: 40)
    static let section = Font.custom("BricolageGrotesque-ExtraBold", size: 24)
    static let cardTitle = Font.custom("BricolageGrotesque-SemiBold", size: 22)
    static let metric = Font.custom("BricolageGrotesque-ExtraBold", size: 44)
    static let button = Font.custom("Outfit-Bold", size: 17)
    static let body = Font.custom("Outfit-Regular", size: 16)
    static let bodyMedium = Font.custom("Outfit-Medium", size: 16)
    static let label = Font.custom("Outfit-Medium", size: 13)
    static let caption = Font.custom("Outfit-Regular", size: 13)
    static let captionMedium = Font.custom("Outfit-Medium", size: 13)
    static let tab = Font.custom("Outfit-Medium", size: 10)
    static let chip = Font.custom("Outfit-Medium", size: 12)
    static let unit = Font.custom("Outfit-Medium", size: 15)
}

enum AppTracking {
    static let poster: CGFloat = -3.0
    static let slab: CGFloat = -1.6
    static let largeTitle: CGFloat = -0.8
    static let section: CGFloat = -0.4
    static let metric: CGFloat = -1.0
}

struct DippedStage<Content: View>: View {
    var fill: Color
    var scheme: ColorScheme = .light
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            fill.ignoresSafeArea()
            content()
                .padding(.horizontal, 20)
                .padding(.top, ScreenSafe.top + 12)
                .padding(.bottom, ScreenSafe.bottom + 72)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(fill.ignoresSafeArea())
        .preferredColorScheme(scheme)
    }
}

private enum ScreenSafe {
    static var top: CGFloat { insets.top }
    static var bottom: CGFloat { insets.bottom }

    private static var insets: UIEdgeInsets {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        return window?.safeAreaInsets ?? UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    }
}

extension String {
    var firstName: String {
        split(separator: " ").first.map(String.init) ?? self
    }
}
