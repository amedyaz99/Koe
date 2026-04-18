import SwiftUI

struct WaveformView: View {
    var barWidth: CGFloat  = 3
    var minHeight: CGFloat = 8
    var maxHeight: CGFloat = 22
    var color: Color       = KoeTheme.vermilion

    @State private var phase: Double = 0
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(
                        width: barWidth,
                        height: minHeight + (maxHeight - minHeight) * abs(sin(phase + Double(i) * 0.8))
                    )
            }
        }
        .onReceive(timer) { _ in phase += 0.3 }
    }
}
