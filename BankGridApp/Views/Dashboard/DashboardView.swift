import SwiftUI

struct DashboardView: View {
    @ObservedObject var priceService: PriceService
    @ObservedObject var appData: AppData
    let calculator: GridCalculator

    @StateObject private var viewModel: DashboardViewModel

    @State private var showSellSheet = false
    @State private var showBuySheet = false
    @State private var showDividendSheet = false
    @State private var showEditSheet = false
    @State private var selectedPosition: Position?

    init(priceService: PriceService, appData: AppData, calculator: GridCalculator) {
        self._priceService = ObservedObject(wrappedValue: priceService)
        self._appData = ObservedObject(wrappedValue: appData)
        self.calculator = calculator
        let p = DataPersistence()
        _viewModel = StateObject(wrappedValue: DashboardViewModel(persistence: p))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                summaryBar
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                ForEach(viewModel.positions, id: \.code) { pos in
                    stockCard(for: pos)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                Button(action: { Task { await priceService.fetchPrices() } }) {
                    Text("刷新实时数据")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.themeAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.themeAccent.opacity(0.15))
                        .cornerRadius(10)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
        .background(Color.themeBg)
        .onAppear {
            viewModel.loadData(prices: priceService.prices, netCashFlow: appData.netCashFlow)
        }
        .onChange(of: priceService.prices) { _ in
            viewModel.loadData(prices: priceService.prices, netCashFlow: appData.netCashFlow)
        }
        .onChange(of: appData.netCashFlow) { _ in
            viewModel.loadData(prices: priceService.prices, netCashFlow: appData.netCashFlow)
        }
        .sheet(isPresented: $showSellSheet) {
            if let pos = selectedPosition {
                TradeSheetView(side: "sell", position: pos, calculator: calculator, priceService: priceService, appData: appData, persistence: DataPersistence(), onCompleted: { viewModel.loadData(prices: priceService.prices, netCashFlow: appData.netCashFlow) })
            }
        }
        .sheet(isPresented: $showBuySheet) {
            if let pos = selectedPosition {
                TradeSheetView(side: "buy", position: pos, calculator: calculator, priceService: priceService, appData: appData, persistence: DataPersistence(), onCompleted: { viewModel.loadData(prices: priceService.prices, netCashFlow: appData.netCashFlow) })
            }
        }
        .sheet(isPresented: $showDividendSheet) {
            if let pos = selectedPosition {
                DividendSheetView(position: pos, calculator: calculator, persistence: DataPersistence(), appData: appData, onCompleted: { viewModel.loadData(prices: priceService.prices, netCashFlow: appData.netCashFlow) })
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let pos = selectedPosition {
                EditPositionSheetView(position: pos, persistence: DataPersistence(), onCompleted: { viewModel.loadData(prices: priceService.prices, netCashFlow: appData.netCashFlow) })
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 6) {
            summaryItem(
                value: viewModel.totalRealValue > 0 ? String(format: "¥%.2f�?, viewModel.totalRealValue / 10000) : "--",
                label: "总估�?,
                color: Color.themeText
            )
            summaryItem(
                value: formatPnL(viewModel.totalPnL),
                label: "累计收益",
                color: pnlColor(viewModel.totalPnL)
            )
            summaryItem(
                value: formatPct(viewModel.diffPct),
                label: "偏离基准",
                color: pnlColor(viewModel.diffPct)
            )
            summaryItem(
                value: String(format: "%@%.0f", viewModel.todayPnL >= 0 ? "+" : "", viewModel.todayPnL),
                label: String(format: "盈亏 %.2f%%", viewModel.todayPct),
                color: pnlColor(viewModel.todayPnL)
            )
        }
    }

    private func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color.themeText2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 2)
        .background(Color.themeCard)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.themeBorder, lineWidth: 1)
        )
    }

    private func stockCard(for pos: Position) -> some View {
        let code = pos.code ?? ""
        let rtp = priceService.prices[code]?.current ?? pos.basePrice
        let sellP = calculator.sellPrice(basePrice: pos.basePrice)
        let buyP = calculator.buyPrice(basePrice: pos.basePrice)
        let hitSell = calculator.isHitSell(basePrice: pos.basePrice, currentPrice: rtp)
        let hitBuy = calculator.isHitBuy(basePrice: pos.basePrice, currentPrice: rtp)
        let mv = Double(pos.shares) * rtp
        let priceColor = hitSell ? Color.themeRed : (hitBuy ? Color.themeGreen : (rtp > pos.basePrice ? Color.themeRed.opacity(0.6) : (rtp < pos.basePrice ? Color.themeGreen.opacity(0.6) : Color.themeText)))

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pos.name ?? "")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.themeText)
                Text(code)
                    .font(.system(size: 11))
                    .foregroundColor(Color.themeText2)
                    .padding(.leading, 6)
                Spacer()
            }

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("持仓与市�?)
                        .font(.system(size: 10))
                        .foregroundColor(Color.themeText2)
                    Text("\(pos.shares)�?/ ¥\(Int(mv))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.themeText)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("现价/基准价P")
                        .font(.system(size: 10))
                        .foregroundColor(Color.themeText2)
                    HStack(spacing: 4) {
                        Text(String(format: "%.3f", rtp))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(priceColor)
                        Text("/")
                            .font(.system(size: 11))
                            .foregroundColor(Color.themeText2)
                        Text(String(format: "%.3f", pos.basePrice))
                            .font(.system(size: 11))
                            .foregroundColor(Color.themeText2)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 6) {
                gridTag(
                    label: String(format: "卖出�?+%.1f%%", appData.settings.gridUp * 100),
                    price: String(format: "¥%.3f", sellP),
                    isSell: true,
                    isActive: hitSell
                )
                gridTag(
                    label: String(format: "买入�?-%.1f%%", appData.settings.gridDown * 100),
                    price: String(format: "¥%.3f", buyP),
                    isSell: false,
                    isActive: hitBuy
                )
            }

            HStack(spacing: 6) {
                actionButton(title: "触发�?, isSell: true) {
                    selectedPosition = pos
                    showSellSheet = true
                }
                actionButton(title: "触发�?, isSell: false) {
                    selectedPosition = pos
                    showBuySheet = true
                }
                actionButton(title: "除息", isSell: nil) {
                    selectedPosition = pos
                    showDividendSheet = true
                }
                actionButton(title: "修正", isSell: nil) {
                    selectedPosition = pos
                    showEditSheet = true
                }
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.themeCard, Color.themeCard2]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.themeBorder, lineWidth: 1)
        )
        .overlay(
            Circle()
                .fill(Color.themeAccent.opacity(0.08))
                .frame(width: 60, height: 60),
            alignment: .topTrailing
        )
    }

    private func gridTag(label: String, price: String, isSell: Bool, isActive: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .opacity(0.8)
            Text(price)
                .font(.system(size: 12, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            Group {
                if isActive {
                    if isSell {
                        Color.themeRed
                    } else {
                        Color.themeGreen
                    }
                } else {
                    if isSell {
                        Color.themeRed.opacity(0.12)
                    } else {
                        Color.themeGreen.opacity(0.12)
                    }
                }
            }
        )
        .foregroundColor(isActive ? .white : (isSell ? Color.themeRed : Color.themeGreen))
        .cornerRadius(8)
        .shadow(
            color: isActive ? (isSell ? Color.themeRed.opacity(0.4) : Color.themeGreen.opacity(0.4)) : .clear,
            radius: 10, x: 0, y: 0
        )
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    private func actionButton(title: String, isSell: Bool?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    Group {
                        if isSell == true {
                            Color.themeRed.opacity(0.15)
                        } else if isSell == false {
                            Color.themeGreen.opacity(0.15)
                        } else {
                            Color.themeAccent.opacity(0.1)
                        }
                    }
                )
                .foregroundColor(
                    isSell == true ? Color.themeRed : (isSell == false ? Color.themeGreen : Color.themeAccent)
                )
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatPnL(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return String(format: "%@%.2f", prefix, value)
    }

    private func formatPct(_ value: Double) -> String {
        if value == 0 { return "0.00%" }
        let prefix = value > 0 ? "+" : ""
        return String(format: "%@%.2f%%", prefix, value)
    }

    private func pnlColor(_ value: Double) -> Color {
        value > 0 ? Color.themeRed : (value < 0 ? Color.themeGreen : Color.themeText)
    }
}
