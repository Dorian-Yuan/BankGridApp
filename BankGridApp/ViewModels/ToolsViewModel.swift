import Foundation
import SwiftUI

struct ProfitBreakdown {
    var gridProfit: Double = 0
    var divProfit: Double = 0
    var floatPnL: Double = 0
    var totalCost: Double = 0

    var totalPnL: Double { gridProfit + divProfit + floatPnL }
    var totalReturnRate: Double { totalCost > 0 ? totalPnL / totalCost * 100 : 0 }
}

struct RebalancePreview {
    var totalPool: Double = 0
    var target: Double = 0
    var availableCash: Double = 0
    var buyNeed: Double = 0
    var sellRelease: Double = 0
    var warning: String = ""
    var deltas: [String: Int] = [:]
    var targetShares: [String: Int] = [:]
}

@MainActor
class ToolsViewModel: ObservableObject {
    @Published var appData: AppData
    @Published var persistence: DataPersistence
    @Published var priceService: PriceService
    @Published var calculator: GridCalculator

    @Published var profitBreakdown = ProfitBreakdown()
    @Published var rebalancePreview: RebalancePreview?

    @Published var showSettingsSheet = false
    @Published var settingsType: SettingsType = .general
    @Published var showProfitBreakdown = false
    @Published var showRebalance = false
    @Published var showResetConfirmation = false
    @Published var resetStep = 0

    @Published var toastMessage: String?
    @Published var showToast = false

    enum SettingsType {
        case general, grid, fees
    }

    init(appData: AppData, persistence: DataPersistence, priceService: PriceService) {
        self.appData = appData
        self.persistence = persistence
        self.priceService = priceService
        self.calculator = GridCalculator(
            gridUp: appData.settings.gridUp,
            gridDown: appData.settings.gridDown,
            tradeRatio: appData.settings.tradeRatio,
            feeRate: appData.settings.feeRate,
            feeMin: appData.settings.feeMin
        )
    }

    func updateCalculator() {
        calculator = GridCalculator(
            gridUp: appData.settings.gridUp,
            gridDown: appData.settings.gridDown,
            tradeRatio: appData.settings.tradeRatio,
            feeRate: appData.settings.feeRate,
            feeMin: appData.settings.feeMin
        )
    }

    @MainActor
    func saveGeneralSettings(refreshInterval: Double, theme: AppTheme) {
        guard refreshInterval >= 5 else {
            showErrorMessage("刷新间隔不能低于5�?)
            return
        }
        appData.settings.refreshInterval = refreshInterval
        appData.settings.theme = theme
        priceService.updateSettings(appData.settings)
        updateCalculator()
        showSuccessMessage("设置已保�?)
    }

    func saveGridSettings(gridUp: Double, gridDown: Double, tradeRatio: Double) {
        guard gridUp > 0, gridDown > 0, tradeRatio > 0 else {
            showErrorMessage("请输入合法数�?)
            return
        }
        appData.settings.gridUp = gridUp
        appData.settings.gridDown = gridDown
        appData.settings.tradeRatio = tradeRatio
        updateCalculator()
        showSuccessMessage("参数已保�?)
    }

    func saveFeeSettings(feeRate: Double, feeMin: Double) {
        guard feeRate > 0, feeMin >= 0 else {
            showErrorMessage("请输入合法数�?)
            return
        }
        appData.settings.feeRate = feeRate
        appData.settings.feeMin = feeMin
        updateCalculator()
        showSuccessMessage("手续费设置已保存")
    }

    @MainActor
    func calculateProfitBreakdown() {
        let logs = persistence.fetchTradeLogs(limit: 10000)
        let positions = persistence.fetchPositions()

        var gridProfit: Double = 0
        var divProfit: Double = 0
        var buyQueue: [String: [(price: Double, shares: Int, fee: Double)]] = [:]

        for log in logs {
            if log.action == "网格买入" {
                let bank = log.bank ?? ""
                if buyQueue[bank] == nil { buyQueue[bank] = [] }
                buyQueue[bank]?.append((price: log.price, shares: Int(log.shares), fee: log.fee))
            } else if log.action == "网格卖出" {
                let bank = log.bank ?? ""
                let sellPrice = log.price
                var sellShares = Int(log.shares)
                let sellFee = log.fee

                if let queue = buyQueue[bank], !queue.isEmpty {
                    var mutableQueue = queue
                    while sellShares > 0 && !mutableQueue.isEmpty {
                        var buy = mutableQueue[0]
                        let matchShares = min(sellShares, buy.shares)
                        let buyCost = Double(matchShares) * buy.price
                        let sellRevenue = Double(matchShares) * sellPrice
                        let matchBuyFee = buy.fee * (Double(matchShares) / Double(buy.shares))
                        gridProfit += sellRevenue - buyCost - matchBuyFee - (sellFee * (Double(matchShares) / Double(log.shares)))
                        sellShares -= matchShares
                        buy.shares -= matchShares
                        buy.fee -= matchBuyFee
                        if buy.shares <= 0 {
                            mutableQueue.removeFirst()
                        } else {
                            mutableQueue[0] = buy
                        }
                    }
                    buyQueue[bank] = mutableQueue
                } else {
                    gridProfit += Double(log.shares) * sellPrice - sellFee
                }
            } else if log.action == "除息调整" {
                divProfit += log.amount
            }
        }

        var floatPnL: Double = 0
        var totalCost: Double = 0
        for pos in positions {
            let rtp = priceService.price(for: pos.code ?? "")
            let costBase = pos.avgCost > 0 ? pos.avgCost : pos.basePrice
            floatPnL += (rtp - costBase) * Double(pos.shares)
            totalCost += costBase * Double(pos.shares)
        }

        profitBreakdown = ProfitBreakdown(
            gridProfit: gridProfit,
            divProfit: divProfit,
            floatPnL: floatPnL,
            totalCost: totalCost
        )
    }

    func calculateRebalance(remainCash: Double, extraCash: Double, prices: [String: Double]) {
        let positions = persistence.fetchPositions()
        let codes = positions.map { $0.code ?? "" }

        var oldTotalVal: Double = 0
        for pos in positions {
            let price = prices[pos.code ?? ""] ?? 0
            oldTotalVal += Double(pos.shares) * price
        }

        let totalPool = oldTotalVal + remainCash + extraCash
        let target = codes.isEmpty ? 0 : totalPool / Double(codes.count)

        var targetShares: [String: Int] = [:]
        var deltas: [String: Int] = [:]

        for pos in positions {
            let code = pos.code ?? ""
            let price = prices[code] ?? 0
            let ts = price > 0 ? calculator.nearestLot(target / price) : Int(pos.shares)
            targetShares[code] = ts
            deltas[code] = ts - Int(pos.shares)
        }

        var sellRelease: Double = 0
        var buyNeed: Double = 0

        for pos in positions {
            let code = pos.code ?? ""
            let diff = deltas[code] ?? 0
            let price = prices[code] ?? 0
            if diff < 0 {
                let sellAmt = Double(abs(diff)) * price
                let sellFee = calculator.calcFee(amount: sellAmt, side: "sell")
                sellRelease += sellAmt - sellFee
            } else if diff > 0 {
                let buyAmt = Double(diff) * price
                let buyFee = calculator.calcFee(amount: buyAmt, side: "buy")
                buyNeed += buyAmt + buyFee
            }
        }

        let availableCash = remainCash + extraCash + sellRelease
        var shortFall = buyNeed - availableCash
        var warning = ""

        if shortFall > 0 && buyNeed > 0 {
            var positiveDeltaCodes: [String] = []
            for code in codes {
                let delta = deltas[code] ?? 0
                if delta > 0 {
                    positiveDeltaCodes.append(code)
                }
            }
            let buyItems = positiveDeltaCodes.sorted { code1, code2 in
                let d1 = Double(deltas[code1] ?? 0) * (prices[code1] ?? 0)
                let d2 = Double(deltas[code2] ?? 0) * (prices[code2] ?? 0)
                return d1 < d2
            }

            var adjustedDeltas = deltas
            var adjustedTargetShares = targetShares

            for code in buyItems {
                var diff = adjustedDeltas[code] ?? 0
                let price = prices[code] ?? 0
                while diff > 0 && shortFall > 0.01 {
                    diff -= GridCalculator.lot
                    let oldBuyAmt = Double(diff + GridCalculator.lot) * price
                    let newBuyAmt = Double(diff) * price
                    let oldFee = calculator.calcFee(amount: oldBuyAmt, side: "buy")
                    let newFee = diff > 0 ? calculator.calcFee(amount: newBuyAmt, side: "buy") : 0
                    shortFall -= (oldBuyAmt + oldFee) - (newBuyAmt + newFee)
                }
                adjustedDeltas[code] = max(diff, 0)
                if let pos = positions.first(where: { $0.code == code }) {
                    adjustedTargetShares[code] = Int(pos.shares) + adjustedDeltas[code]!
                }
            }

            deltas = adjustedDeltas
            targetShares = adjustedTargetShares

            if shortFall > 0.01 {
                warning = "�?无可用资金，无法执行再平�?
            } else {
                warning = "⚠️ 资金不足，已自动缩减买入�?
            }
        }

        rebalancePreview = RebalancePreview(
            totalPool: totalPool,
            target: target,
            availableCash: availableCash,
            buyNeed: buyNeed,
            sellRelease: sellRelease,
            warning: warning,
            deltas: deltas,
            targetShares: targetShares
        )
    }

    func executeRebalance(prices: [String: Double], remainCash: Double, extraCash: Double) {
        guard let preview = rebalancePreview else { return }
        let positions = persistence.fetchPositions()

        var newTotal: Double = 0
        var buyC = 0
        var sellC = 0

        for pos in positions {
            let code = pos.code ?? ""
            guard let price = prices[code], price > 0 else { continue }
            let ts = preview.targetShares[code] ?? Int(pos.shares)
            if ts > Int(pos.shares) { buyC += 1 }
            if ts < Int(pos.shares) { sellC += 1 }
            pos.shares = Int32(ts)
            pos.basePrice = price
            newTotal += Double(ts) * price
        }

        var oldTotalVal: Double = 0
        for pos in positions {
            oldTotalVal += Double(pos.shares) * (prices[pos.code ?? ""] ?? 0)
        }
        let actualInjected = newTotal - oldTotalVal
        appData.netCashFlow -= actualInjected

        persistence.save()
        persistence.addTradeLog(
            action: "月度平准",
            bank: "",
            price: 0,
            shares: 0,
            amount: 0,
            fee: 0,
            dividend: 0,
            divTax: 0,
            oldBase: 0,
            newBase: 0,
            remainShares: 0,
            totalShares: 0,
            buys: Int32(buyC),
            sells: Int32(sellC),
            totalValue: newTotal,
            target: preview.target
        )

        showSuccessMessage("平准执行成功")
    }

    func confirmReset() {
        resetStep = 1
        showResetConfirmation = true
    }

    func nextResetStep() {
        if resetStep == 1 {
            resetStep = 2
        }
    }

    func executeReset() {
        let _ = persistence.backupData()
        persistence.deleteAllPositions()
        persistence.deleteAllTradeLogs()
        appData.netCashFlow = 0
        appData.initCapital = 0
        resetStep = 0
        showResetConfirmation = false
        showSuccessMessage("数据已重置并备份")
    }

    func cancelReset() {
        resetStep = 0
        showResetConfirmation = false
    }

    private func showSuccessMessage(_ msg: String) {
        toastMessage = msg
        showToast = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.showToast = false
        }
    }

    private func showErrorMessage(_ msg: String) {
        toastMessage = msg
        showToast = true
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.showToast = false
        }
    }
}
