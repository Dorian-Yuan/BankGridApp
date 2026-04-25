import SwiftUI

struct DashboardView: View {
    @ObservedObject var priceService: PriceService
    @ObservedObject var appData: AppData
    let calculator: GridCalculator

    @StateObject private var viewModel = DashboardViewModel()

    @State private var showSellSheet = false
    @State private var showBuySheet = false
    @State private var showDividendSheet = false
    @State private var showEditSheet = false
    @State private var selectedPosition: Position?

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
                TradeSheetView(position: pos, side: "sell", calculator: calculator, priceService: priceService, appData: appData)
            }
        }
        .sheet(isPresented: $showBuySheet) {
            if let pos = selectedPosition {
                TradeSheetView(position: pos, side: "buy", calculator: calculator, priceService: priceService, appData: appData)
            }
        }
        .sheet(isPresented: $showDividendSheet) {
            if let pos = selectedPosition {
                DividendSheetView(position: pos, appData: appData)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let pos = selectedPosition {
                EditSheetView(position: pos, appData: appData)
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 6) {
            summaryItem(
                value: viewModel.totalRealValue > 0 ? String(format: "¥%.2f万", viewModel.totalRealValue / 10000) : "--",
                label: "总估值",
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
                    Text("持仓与市值")
                        .font(.system(size: 10))
                        .foregroundColor(Color.themeText2)
                    Text("\(pos.shares)股 / ¥\(Int(mv))")
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
                    label: String(format: "卖出线 +%.1f%%", appData.settings.gridUp * 100),
                    price: String(format: "¥%.3f", sellP),
                    isSell: true,
                    isActive: hitSell
                )
                gridTag(
                    label: String(format: "买入线 -%.1f%%", appData.settings.gridDown * 100),
                    price: String(format: "¥%.3f", buyP),
                    isSell: false,
                    isActive: hitBuy
                )
            }

            HStack(spacing: 6) {
                actionButton(title: "触发卖", isSell: true) {
                    selectedPosition = pos
                    showSellSheet = true
                }
                actionButton(title: "触发买", isSell: false) {
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

struct TradeSheetView: View {
    let position: Position
    let side: String
    let calculator: GridCalculator
    @ObservedObject var priceService: PriceService
    @ObservedObject var appData: AppData

    @State private var tradePrice: String = ""
    @State private var tradeShares: String = ""
    @State private var divTax: String = "0"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(side == "sell" ? "卖出 \(position.name ?? "")" : "买入 \(position.name ?? "")")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("成交价（系统现价: ¥\(currentPriceStr)）")
                            .font(.system(size: 13))
                            .foregroundColor(Color.themeText2)
                        TextField("成交价", text: $tradePrice)
                            .keyboardType(.decimalPad)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("成交股数（策略建议 \(suggestedShares)股）")
                            .font(.system(size: 13))
                            .foregroundColor(Color.themeText2)
                        TextField("股数", text: $tradeShares)
                            .keyboardType(.numberPad)
                    }

                    if side == "sell" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("代扣红利税 (元)")
                                .font(.system(size: 13))
                                .foregroundColor(Color.themeText2)
                            TextField("红利税", text: $divTax)
                                .keyboardType(.decimalPad)
                        }
                    }
                }

                Section {
                    tradePreview
                }

                Section {
                    Button(action: { dismiss() }) {
                        Text(side == "sell" ? "确认卖出并更新P点" : "确认买入并更新P点")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(side == "sell" ? Color.themeRed : Color.themeGreen)
                            .cornerRadius(10)
                    }
                    Button(action: { dismiss() }) {
                        Text("取消")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.themeAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.themeAccent.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
        }
        .onAppear {
            let rtp = priceService.prices[position.code ?? ""]?.current ?? 0
            let trigP = side == "sell" ? calculator.sellPrice(basePrice: position.basePrice) : calculator.buyPrice(basePrice: position.basePrice)
            let defaultPrice = rtp > 0 ? rtp : trigP
            tradePrice = String(format: "%.3f", defaultPrice)
            tradeShares = "\(suggestedShares)"
        }
    }

    private var currentPriceStr: String {
        let rtp = priceService.prices[position.code ?? ""]?.current ?? 0
        return rtp > 0 ? String(format: "%.3f", rtp) : "--"
    }

    private var suggestedShares: Int {
        calculator.calcGridShares(currentShares: Int(position.shares))
    }

    private var tradePreview: some View {
        let price = Double(tradePrice) ?? 0
        let shares = Int(tradeShares) ?? 0
        let amount = price * Double(shares)
        let fees = calculator.calcFeeDetail(amount: amount, side: side)
        let totalFee = fees.total + (Double(divTax) ?? 0)
        let net = side == "sell" ? amount - totalFee : amount + totalFee
        let newShares = side == "sell" ? Int(position.shares) - shares : Int(position.shares) + shares

        return VStack(alignment: .leading, spacing: 6) {
            Text(side == "sell" ? "实收：" : "实付：")
                .font(.system(size: 13))
                .foregroundColor(Color.themeText2) +
            Text(String(format: "¥%.2f", net))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.themeText)

            Text(String(format: "预估费用(¥%.2f)：佣金¥%.2f / 过户费¥%.3f", totalFee, fees.comm, fees.transfer) +
                 (side == "sell" ? String(format: " / 印花税¥%.2f", fees.stamp) : "") +
                 ((Double(divTax) ?? 0) > 0 ? String(format: " / 红利税¥%.2f", Double(divTax) ?? 0) : ""))
                .font(.system(size: 11))
                .foregroundColor(Color.themeText2)
                .padding(8)
                .background(Color.themeCard2.opacity(0.5))
                .cornerRadius(6)

            Text("交易后持仓：\(newShares)股")
                .font(.system(size: 13))
                .foregroundColor(Color.themeText2) +
            Text("  新基准价 P 更新为：")
                .font(.system(size: 13))
                .foregroundColor(Color.themeText2) +
            Text(String(format: "¥%.3f", price))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.themeAccent)
        }
        .font(.system(size: 13))
    }
}

struct DividendSheetView: View {
    let position: Position
    @ObservedObject var appData: AppData

    @State private var dividendAmount: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("除息调整")) {
                    Text("\(position.name ?? "") · P=¥\(String(format: "%.3f", position.basePrice))")
                        .font(.system(size: 14))
                        .foregroundColor(Color.themeText2)

                    TextField("每股分红（元）", text: $dividendAmount)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button(action: { dismiss() }) {
                        Text("确认调整基准价 P")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.themeAccent)
                            .cornerRadius(10)
                    }
                    Button(action: { dismiss() }) {
                        Text("取消")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.themeAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.themeAccent.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
        }
    }
}

struct EditSheetView: View {
    let position: Position
    @ObservedObject var appData: AppData

    @State private var editShares: String = ""
    @State private var editBasePrice: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("编辑持仓")) {
                    Text(position.name ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(Color.themeText2)

                    TextField("持仓股数", text: $editShares)
                        .keyboardType(.numberPad)

                    TextField("基准价 P", text: $editBasePrice)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button(action: { dismiss() }) {
                        Text("保存修正")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.themeAccent)
                            .cornerRadius(10)
                    }
                    Button(action: { dismiss() }) {
                        Text("取消")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.themeAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.themeAccent.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
        }
        .onAppear {
            editShares = "\(position.shares)"
            editBasePrice = String(format: "%.3f", position.basePrice)
        }
    }
}
