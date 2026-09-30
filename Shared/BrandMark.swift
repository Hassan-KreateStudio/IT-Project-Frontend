import SwiftUI

struct BrandMark: View {
    var tiled: Bool = false

    var body: some View {
        Canvas { context, size in
            let w = min(size.width, size.height)
            let t = w * 0.22
            let arm = w * 0.72
            let origin = (w - arm) / 2
            let radius = t / 2

            let vertical = CGRect(x: (w - t) / 2, y: origin, width: t, height: arm)
            let horizontal = CGRect(x: origin, y: (w - t) / 2, width: arm, height: t)

            var plus = Path()
            plus.addRoundedRect(in: vertical, cornerSize: CGSize(width: radius, height: radius))
            plus.addRoundedRect(in: horizontal, cornerSize: CGSize(width: radius, height: radius))
            context.fill(plus, with: .color(Color.flare))

            let points: [CGPoint] = [
                CGPoint(x: 0.14, y: 0.70),
                CGPoint(x: 0.34, y: 0.56),
                CGPoint(x: 0.50, y: 0.62),
                CGPoint(x: 0.70, y: 0.36),
                CGPoint(x: 0.88, y: 0.20)
            ].map { CGPoint(x: $0.x * w, y: $0.y * w) }

            var line = Path()
            line.move(to: points[0])
            for point in points.dropFirst() {
                line.addLine(to: point)
            }
            context.stroke(
                line,
                with: .color(Color.acid),
                style: StrokeStyle(lineWidth: w * 0.08, lineCap: .round, lineJoin: .round)
            )

            let dot = w * 0.048
            for point in points {
                let rect = CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)
                context.fill(Path(ellipseIn: rect), with: .color(Color.aurora))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(tiled ? 12 : 0)
        .background(tiled ? Color.ink : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: tiled ? 18 : 0, style: .continuous))
        .accessibilityLabel("Health graph mark")
    }
}

#Preview {
    VStack(spacing: 24) {
        BrandMark()
            .frame(width: 72, height: 72)
            .padding()
            .background(Color.ink)
        BrandMark(tiled: true)
            .frame(width: 72, height: 72)
    }
}
