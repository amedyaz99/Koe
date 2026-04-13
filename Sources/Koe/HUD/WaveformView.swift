import SwiftUI

struct WaveformView: View {
    var barWidth: CGFloat = 3
    var minHeight: CGFloat = 8
    var maxHeight: CGFloat = 22
    var color: Color = Color(hex: "#C47D3A")

    @State private var phase: Double = 0
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(
                        width: barWidth,
                        height: minHeight + (maxHeight - minHeight) * abs(sin(phase + Double(i) * 0.8))
                    )
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .onReceive(timer) { _ in
            phase += 0.3
        }
    }
}

// Helpfully including the hex extension here or in a shared file
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
