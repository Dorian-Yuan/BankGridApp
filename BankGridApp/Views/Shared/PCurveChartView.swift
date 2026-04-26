import SwiftUI

struct PPoint {
    let time: String
    let p: Double
    let label: String
}

struct PCurveChartView: View {
    let position: Position

    @State private var points: [PPoint] = []
    @State private var selectedIndex: Int? = nil
    @Environment(\.dismiss) private var dismiss

    private let persistence = DataPersistence()
    private let chartPadding: CGFloat = 30
    private let dotRadius: CGFloat = 4

    var body: some View {
        VStack(spacing: 0) {
            header
            if points.count >= 2 {
                chartContent
            } else {
                noDataView
            }
            footer
            closeButton
        }
        .background(Color.themeBg)
        .onAppear {
            loadPHistory()
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("\(position.name ?? "") 基准价曲�?)
                .font(.headline)
                .foregroundColor(.themeText)
            HStack(spacing: 4) {
                Text("当前持仓: \(position.shares)�?)
                    .font(.system(size: 13))
                    .foregroundColor(.themeText2)
                Text("|")
                    .font(.system(size: 13))
                    .foregroundColor(.themeText2)
                Text("现P�? ¥\(String(format: "%.3f", position.basePrice))")
                    .font(.system(size: 13))
                    .foregroundColor(.themeAccent)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var chartContent: some View {
        GeometryReader { geo in
            Canvas { context, size in
                drawChart(context: context, size: size)
            }
            .overlay {
                if let idx = selectedIndex, idx < points.count {
                    let pos = pointPosition(index: idx, in: geo.size)
                    tooltipView(for: idx)
                        .position(x: pos.x, y: max(pos.y - 40, 25))
                        .allowsHitTesting(false)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        selectPoint(at: value.location.x, in: geo.size)
                    }
                    .onEnded { _ in
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            selectedIndex = nil
                        }
                    }
            )
        }
        .frame(height: 260)
        .padding(.horizontal, 16)
    }

    private var noDataView: some View {
        Text("暂无足够的基准价变更记录")
            .font(.system(size: 14))
            .foregroundColor(.themeText2)
            .frame(height: 260)
    }

    private var footer: some View {
        Text("触摸/点击图表查看详细点位")
            .font(.system(size: 11))
            .foregroundColor(.themeText2)
            .padding(.top, 4)
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Text("关闭图表")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.themeAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.themeAccent2.opacity(0.15))
                .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    private func pointX(_ index: Int, width: CGFloat) -> CGFloat {
        chartPadding + (CGFloat(index) / CGFloat(max(points.count - 1, 1))) * (width - chartPadding * 2)
    }

    private func pointY(_ p: Double, height: CGFloat, maxP: Double, minP: Double, range: Double) -> CGFloat {
        height - chartPadding - ((p - minP) / range) * (height - chartPadding * 2.5)
    }

    private func pointPosition(index: Int, in size: CGSize) -> CGPoint {
        let maxP = points.map { $0.p }.max() ?? 0
        let minP = points.map { $0.p }.min() ?? 0
        let range = (maxP - minP) > 0 ? (maxP - minP) : max(maxP * 0.1, 0.01)
        return CGPoint(
            x: pointX(index, width: size.width),
            y: pointY(points[index].p, height: size.height, maxP: maxP, minP: minP, range: range)
        )
    }

    private func selectPoint(at x: CGFloat, in size: CGSize) {
        var closest = 0
        var minDist = CGFloat.infinity
        for i in 0..<points.count {
            let px = pointX(i, width: size.width)
            let dist = abs(x - px)
            if dist < minDist {
                minDist = dist
                closest = i
            }
        }
        selectedIndex = closest
    }

    private func tooltipView(for index: Int) -> some View {
        let pt = points[index]
        return VStack(spacing: 2) {
            Text("\(pt.time) \(pt.label)")
                .font(.system(size: 11))
                .foregroundColor(.themeText2)
            Text("P: ¥\(String(format: "%.3f", pt.p))")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.themeAccent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.themeCard2)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.themeBorder, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    private func drawChart(context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        let maxP = points.map { $0.p }.max() ?? 0
        let minP = points.map { $0.p }.min() ?? 0
        let range = (maxP - minP) > 0 ? (maxP - minP) : max(maxP * 0.1, 0.01)

        let topY = pointY(maxP, height: h, maxP: maxP, minP: minP, range: range)
        let bottomY = pointY(minP, height: h, maxP: maxP, minP: minP, range: range)

        var gridPath = Path()
        gridPath.move(to: CGPoint(x: chartPadding, y: topY))
        gridPath.addLine(to: CGPoint(x: w - chartPadding, y: topY))
        gridPath.move(to: CGPoint(x: chartPadding, y: bottomY))
        gridPath.addLine(to: CGPoint(x: w - chartPadding, y: bottomY))
        context.stroke(gridPath, with: .color(.themeBorder), lineWidth: 1)

        var curvePath = Path()
        for i in 0..<points.count {
            let x = pointX(i, width: w)
            let y = pointY(points[i].p, height: h, maxP: maxP, minP: minP, range: range)
            if i == 0 {
                curvePath.move(to: CGPoint(x: x, y: y))
            } else {
                curvePath.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.stroke(curvePath, with: .color(.themeAccent), style: StrokeStyle(lineWidth: 2, lineJoin: .round))

        for i in 0..<points.count {
            let x = pointX(i, width: w)
            let y = pointY(points[i].p, height: h, maxP: maxP, minP: minP, range: range)
            let dotRect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
            context.fill(Path(ellipseIn: dotRect), with: .color(.themeAccent2))
        }
    }

    private func loadPHistory() {
        var pts: [PPoint] = []
        let df = DateFormatter()
        df.dateFormat = "yy/M/d"
        let todayStr = df.string(from: Date())
        pts.append(PPoint(time: todayStr, p: position.basePrice, label: "当前"))

        let logs = persistence.fetchTradeLogsForBank(position.name ?? "")
        for log in logs {
            let tStr = log.timestamp != nil ? df.string(from: log.timestamp!) : ""
            if log.newBase > 0 {
                pts.append(PPoint(time: tStr, p: log.newBase, label: log.action ?? ""))
            } else if log.action == "建仓" && log.price > 0 {
                pts.append(PPoint(time: tStr, p: log.price, label: log.action ?? ""))
            }
        }

        pts.reverse()
        var res: [PPoint] = []
        for (i, pt) in pts.enumerated() {
            if i == 0 || pt.p != pts[i - 1].p {
                res.append(pt)
            }
        }
        points = Array(res.suffix(15))
    }
}
