import SwiftUI

// MARK: - Koe Design System
// Aesthetic: Minimalist Japanese stationery meets archival teletype

enum KoeTheme {
    // MARK: - Core Palette
    static let ink        = Color(hexVal: 0x1A1410)   // Sumi-black — primary text
    static let ivory      = Color(hexVal: 0xF8F5F0)   // Ivory parchment — background
    static let ivoryDeep  = Color(hexVal: 0xF0EBE3)   // Deeper parchment — sidebar/panel
    static let vermilion  = Color(hexVal: 0xC0392B)   // Vermilion — accent, recording state
    static let stone      = Color(hexVal: 0x8C7B6A)   // Warm stone — secondary text
    static let stoneL     = Color(hexVal: 0xB8A898)   // Light stone — muted UI
    static let sumi       = Color(hexVal: 0x2C2018)   // Dark sumi — deep ink
    static let cream      = Color(hexVal: 0xFAF7F2)   // Near-white

    // State colors
    static let transcribingColor = Color(hexVal: 0x4B6BC8)  // Indigo
    static let doneColor         = Color(hexVal: 0x508C5A)  // Moss
    static let errorColor        = Color(hexVal: 0xB85A3C)  // Terracotta

    // MARK: - Typography
    static let monoFont    = Font.system(.body, design: .monospaced)
    static let monoCaption = Font.system(.caption, design: .monospaced)
    static let monoSmall   = Font.system(size: 10, design: .monospaced)
    static let monoTiny    = Font.system(size: 9, design: .monospaced)

    static let serifTitle  = Font.custom("HiraMinProN-W3", size: 13)
    static let serifSmall  = Font.custom("HiraMinProN-W3", size: 11)
    static let serifTiny   = Font.custom("HiraMinProN-W3", size: 9)

    // MARK: - Animations
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7)
    static let ease   = Animation.easeInOut(duration: 0.25)
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

// MARK: - Dot Grid Background
struct DotGridBackground: View {
    var dotColor: Color  = KoeTheme.vermilion.opacity(0.13)
    var spacing: CGFloat = 18
    var dotSize: CGFloat = 1.4

    var body: some View {
        Canvas { ctx, size in
            let cols = Int(size.width  / spacing) + 2
            let rows = Int(size.height / spacing) + 2
            for col in 0..<cols {
                for row in 0..<rows {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    let rect = CGRect(
                        x: x - dotSize / 2, y: y - dotSize / 2,
                        width: dotSize, height: dotSize
                    )
                    ctx.fill(Path(ellipseIn: rect), with: .color(dotColor))
                }
            }
        }
    }
}

// MARK: - Tape Mark Decoration
struct TapeMarks: View {
    var body: some View {
        HStack(spacing: 0) {
            TapeMark()
            Spacer()
            TapeMark()
            Spacer()
            TapeMark()
        }
        .padding(.horizontal, 56)
    }
}

private struct TapeMark: View {
    var body: some View {
        Rectangle()
            .fill(KoeTheme.stoneL.opacity(0.48))
            .frame(width: 34, height: 10)
            .overlay(
                VStack(spacing: 0) {
                    Rectangle().fill(KoeTheme.stoneL.opacity(0.28)).frame(height: 1)
                    Spacer()
                    Rectangle().fill(KoeTheme.stoneL.opacity(0.28)).frame(height: 1)
                }
            )
    }
}

// MARK: - Inkan Stamp  (声, koe in hiragana — black square, upright)
struct InkanStamp: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Rectangle()
                .fill(KoeTheme.ink)
                .frame(width: size, height: size)

            Text("こ\nえ")
                .font(.custom("HiraMinProN-W6", size: size * 0.34))
                .foregroundColor(KoeTheme.ivory)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
        }
    }
}

// MARK: - Archival Section Divider
struct ArchivalDivider: View {
    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(KoeTheme.vermilion.opacity(0.5))
                .frame(height: 1)
            Rectangle()
                .fill(KoeTheme.vermilion.opacity(0.25))
                .frame(width: 4, height: 1)
        }
    }
}

// MARK: - Terminal Metadata Row
struct TerminalRow: View {
    let key: String
    let value: String
    var valueColor: Color = KoeTheme.vermilion

    var body: some View {
        HStack(spacing: 0) {
            Text(key)
                .font(KoeTheme.monoTiny)
                .foregroundColor(KoeTheme.stone)
                .frame(width: 88, alignment: .leading)

            Text(": ")
                .font(KoeTheme.monoTiny)
                .foregroundColor(KoeTheme.stoneL)

            Text(value)
                .font(KoeTheme.monoTiny)
                .foregroundColor(valueColor)

            Spacer()
        }
    }
}

// MARK: - Dotted Leader Row  (Settings typewriter entry)
struct DottedLeaderRow<Value: View>: View {
    let label: String
    @ViewBuilder let value: () -> Value

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(label)
                .font(KoeTheme.monoSmall)
                .foregroundColor(KoeTheme.ink)

            // Dotted leader
            GeometryReader { geo in
                Path { path in
                    let y = geo.size.height / 2
                    var x: CGFloat = 0
                    while x < geo.size.width {
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + 2, y: y))
                        x += 5
                    }
                }
                .stroke(KoeTheme.vermilion.opacity(0.25), lineWidth: 0.8)
            }
            .frame(height: 1)

            value()
        }
        .padding(.vertical, 7)
        .overlay(
            Rectangle()
                .fill(KoeTheme.vermilion.opacity(0.12))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
