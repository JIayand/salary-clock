import SwiftUI

struct SalaryProgressBar: View {
    let progress: Double
    let style: ProgressBarStyle
    let trackColor: Color
    let fillColor: Color
    var height: CGFloat = 5

    private var value: Double { min(1, max(0, progress)) }

    var body: some View {
        Group {
            switch style {
            case .rounded:
                // Standard solid capsule: a clear, quiet baseline style.
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(trackColor)
                        Capsule()
                            .fill(fillColor)
                            .frame(width: proxy.size.width * value)
                    }
                }

            case .gradient:
                // Luminous gradient with a soft halo and a distinct endpoint.
                GeometryReader { proxy in
                    let fillWidth = proxy.size.width * value
                    let markerSize = max(4, height * 0.85)
                    let markerOffset = max(0, fillWidth - markerSize / 2)
                    ZStack(alignment: .leading) {
                        Capsule().fill(trackColor)
                        if value > 0 {
                            Capsule()
                                .fill(fillColor.opacity(0.24))
                                .frame(width: fillWidth)
                                .blur(radius: max(2, height * 0.65))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: fillColor.opacity(0.58), location: 0),
                                            .init(color: fillColor, location: 0.72),
                                            .init(color: fillColor.opacity(0.82), location: 1)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: fillWidth)
                            Circle()
                                .fill(fillColor)
                                .frame(width: markerSize, height: markerSize)
                                .shadow(color: fillColor.opacity(0.65), radius: max(2, height * 0.7))
                                .offset(x: markerOffset)
                        }
                    }
                }

            case .segmented:
                GeometryReader { _ in
                    HStack(spacing: max(2, height * 0.45)) {
                        ForEach(0..<12, id: \.self) { index in
                            let segmentProgress = min(1, max(0, value * 12 - Double(index)))
                            GeometryReader { segment in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(trackColor)
                                    Capsule()
                                        .fill(fillColor)
                                        .frame(width: segment.size.width * segmentProgress)
                                }
                            }
                        }
                    }
                }

            case .thin:
                // Hairline track and a thicker moving marker make this visibly lighter.
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(trackColor)
                            .frame(height: max(1, height * 0.22))
                        Capsule()
                            .fill(fillColor)
                            .frame(width: proxy.size.width * value, height: max(2, height * 0.42))
                        if value > 0 {
                            Circle()
                                .fill(fillColor)
                                .frame(width: max(4, height * 0.9), height: max(4, height * 0.9))
                                .offset(x: max(0, proxy.size.width * value - max(2, height * 0.45)))
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("工作进度")
        .accessibilityValue(NumericFormatting.number(value * 100, fractionDigits: 1) + "%")
    }
}
