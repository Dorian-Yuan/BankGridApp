import SwiftUI

struct OverviewView: View {
    @ObservedObject var priceService: PriceService
    @ObservedObject var appData: AppData
    @StateObject private var viewModel = OverviewViewModel()
    @State private var selectedPosition: Position?
    @State private var showSheet = false

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()

            if viewModel.positions.isEmpty {
                initPlaceholder
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        summaryBar
                        bankGrid
                        refreshButton
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            viewModel.loadData()
        }
        .sheet(isPresented: $showSheet) {
            if let pos = selectedPosition {
                PCurveChartView(position: pos)
            }
        }
    }

    private var initPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 48))
                .foregroundColor(.themeText2)
            Text("暂无持仓数据")
                .font(.title3)
                .foregroundColor(.themeText2)
            Text("请先在工具页完成建仓")
                .font(.subheadline)
                .foregroundColor(.themeText2)
            Spacer()
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 0) {
            summaryItem(
                value: idxPctString,
                label: "中证银行",
                color: colorForSign(priceService.idxPct)
            )
            summaryItem(
                value: "\(viewModel.buyCount) / \(viewModel.sellCount)",
                label: "�?卖次�?,
                color: .themeText
            )
            summaryItem(
                value: String(format: "¥%.1f", viewModel.totalFee),
                label: "总手续费",
                color: .themeText
            )
            summaryItem(
                value: String(format: "¥%.0f", viewModel.totalDiv),
                label: "累计分红",
                color: .themeAccent
            )
        }
        .padding(.vertical, 10)
        .background(Color.themeCard)
        .cornerRadius(10)
    }

    private func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.themeText2)
        }
        .frame(maxWidth: .infinity)
    }

    private var idxPctString: String {
        let pct = priceService.idxPct
        let prefix = pct > 0 ? "+" : ""
        return String(format: "%@%.2f%%", prefix, pct)
    }

    private var bankGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(viewModel.positions, id: \.code) { pos in
                bankCard(for: pos)
            }
        }
    }

    private func bankCard(for pos: Position) -> some View {
        let pd = priceService.priceData(for: pos.code ?? "")
        let rtp = pd.current > 0 ? pd.current : pos.basePrice
        let costBase = pos.avgCost > 0 ? pos.avgCost : pos.basePrice
        let dayPnL = (rtp - pd.yClose) * Double(pos.shares)
        let totPnL = (rtp - costBase) * Double(pos.shares)
        let pct = pd.pct
        let triUp = dayPnL > 0
        let triDown = dayPnL < 0

        return Button {
            selectedPosition = pos
            showSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 2) {
                        Text(triUp ? "�?" : (triDown ? "�?" : ""))
                            .font(.system(size: 11))
                            .foregroundColor(triUp ? .themeRed : (triDown ? .themeGreen : .clear))
                        Text(pos.name ?? "")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.themeText)
                    }
                    Spacer()
                    Text(pos.code ?? "")
                        .font(.system(size: 10))
                        .foregroundColor(.themeText2)
                }
                .padding(.bottom, 6)

                VStack(spacing: 3) {
                    detailRow(label: "现价", value: String(format: "%.3f", rtp), valueColor: colorForSign(pct), valueWeight: .bold, valueSize: 14)
                    detailRow(label: "涨跌", value: pctString(pct), valueColor: colorForSign(pct), valueWeight: .bold)
                    detailRow(label: "日盈", value: pnlString(dayPnL), valueColor: colorForSign(dayPnL))
                    detailRow(label: "总盈", value: pnlString(totPnL), valueColor: colorForSign(totPnL))
                }

                Rectangle()
                    .fill(Color.themeBorder)
                    .frame(height: 0.5)
                    .padding(.vertical, 3)

                VStack(spacing: 3) {
                    detailRow(label: "P�?, value: String(format: "%.3f", pos.basePrice))
                    detailRow(label: "持仓", value: "\(pos.shares)")
                    detailRow(label: "今开", value: pd.open > 0 ? String(format: "%.3f", pd.open) : "--")
                    detailRow(label: "昨收", value: pd.yClose > 0 ? String(format: "%.3f", pd.yClose) : "--")
                    detailRow(label: "最�?, value: pd.high > 0 ? String(format: "%.3f", pd.high) : "--")
                    detailRow(label: "最�?, value: pd.low > 0 ? String(format: "%.3f", pd.low) : "--")
                }
            }
            .padding(10)
            .background(Color.themeCard)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.themeBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func detailRow(label: String, value: String, valueColor: Color = .themeText, valueWeight: Font.Weight = .regular, valueSize: CGFloat = 12) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.themeText2)
            Spacer()
            Text(value)
                .font(.system(size: valueSize, weight: valueWeight, design: .monospaced))
                .foregroundColor(valueColor)
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await priceService.fetchPrices() }
        } label: {
            HStack {
                if priceService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .themeAccent))
                        .scaleEffect(0.8)
                }
                Text("刷新实时数据")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.themeAccent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.themeAccent2.opacity(0.15))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 6)
    }

    private func colorForSign(_ value: Double) -> Color {
        if value > 0 { return .themeRed }
        if value < 0 { return .themeGreen }
        return .themeText
    }

    private func pctString(_ pct: Double) -> String {
        let prefix = pct > 0 ? "+" : ""
        return String(format: "%@%.2f%%", prefix, pct)
    }

    private func pnlString(_ pnl: Double) -> String {
        let prefix = pnl > 0 ? "+" : ""
        return String(format: "%@%.0f", prefix, pnl)
    }
}
