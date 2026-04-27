import SwiftUI

// MARK: - Koe Design System
// Aesthetic: Dark Japanese Stationery (Sumi-ink and Washi-paper)

enum KoeTheme {
    // MARK: - Core Palette
    static let sumiInk      = Color(hexVal: 0x1A1A1A)   // Deep Sumi Ink — Background
    static let sumiInkLight = Color(hexVal: 0x2A2A2A)   // Lighter Charcoal — Hovered cards
    static let washiPaper   = Color(hexVal: 0xF5F5F0)   // Warm Washi Paper — Primary text
    static let washiMuted   = Color(hexVal: 0xC0C0BA)   // Muted Washi — Secondary text/Timestamps
    static let vermilion    = Color(hexVal: 0xD35400)   // Vermilion — Accent
    static let gold         = Color(hexVal: 0xD4AF37)   // Subtle gold — Highlights

    // State colors
    static let transcribingColor = Color(hexVal: 0x5D8AA8)  // Indigo-ish
    static let doneColor         = Color(hexVal: 0x4F7942)  // Moss Green
    static let errorColor        = Color(hexVal: 0x8B0000)  // Deep Red

    // MARK: - Typography
    static let monoCaption = Font.system(.caption, design: .monospaced)
    static let monoSmall   = Font.system(size: 13, design: .monospaced)
    static let monoTiny    = Font.system(size: 12, design: .monospaced)

    static let mainText    = Font.system(.body, design: .default)
    static let mainSmall   = Font.system(.subheadline, design: .default)

    // MARK: - Animations
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let ease   = Animation.easeInOut(duration: 0.2)
}

// MARK: - Color from UInt32
extension Color {
    init(hexVal: UInt32) {
        let r = Double((hexVal >> 16) & 0xFF) / 255
        let g = Double((hexVal >> 8)  & 0xFF) / 255
        let b = Double(hexVal         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Continuous Rounded Rect
struct ContinuousRoundedRectangle: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let roundedRect = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return roundedRect.path(in: rect)
    }
}

// MARK: - Inkan Stamp (声, koe in hiragana)
struct InkanStamp: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            ContinuousRoundedRectangle(cornerRadius: size * 0.2)
                .fill(KoeTheme.vermilion)
                .frame(width: size, height: size)

            Text("こ\nえ")
                .font(.custom("HiraMinProN-W6", size: size * 0.34))
                .foregroundColor(KoeTheme.washiPaper)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
        }
    }
}
