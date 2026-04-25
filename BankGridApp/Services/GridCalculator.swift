import Foundation

struct GridCalculator {
    let gridUp: Double
    let gridDown: Double
    let tradeRatio: Double
    let feeRate: Double
    let feeMin: Double

    static let defaultGridUp: Double = 0.012
    static let defaultGridDown: Double = 0.005
    static let defaultTradeRatio: Double = 0.3
    static let defaultFeeRate: Double = 0.0000854
    static let defaultFeeMin: Double = 0.5
    static let lot: Int = 100

    func roundLot(_ shares: Int) -> Int {
        return Int(round(Double(shares) / Double(GridCalculator.lot))) * GridCalculator.lot
    }

    func nearestLot(_ shares: Double) -> Int {
        let lo = Int(floor(shares / Double(GridCalculator.lot))) * GridCalculator.lot
        let hi = lo + GridCalculator.lot
        return (shares - Double(lo)) <= (Double(hi) - shares) ? lo : hi
    }

    func calcFee(amount: Double, side: String) -> Double {
        let comm = max(amount * feeRate, feeMin)
        let transfer = amount * 0.00001
        let stamp = side == "sell" ? amount * 0.0005 : 0
        return comm + transfer + stamp
    }

    func calcFeeDetail(amount: Double, side: String) -> (comm: Double, transfer: Double, stamp: Double, total: Double) {
        let comm = max(amount * feeRate, feeMin)
        let transfer = amount * 0.00001
        let stamp = side == "sell" ? amount * 0.0005 : 0
        return (comm, transfer, stamp, comm + transfer + stamp)
    }

    func calcInitShares(price: Double, budget: Double) -> Int {
        let exact = budget / price
        let lo = Int(floor(exact / Double(GridCalculator.lot))) * GridCalculator.lot
        let hi = lo + GridCalculator.lot
        if lo == 0 { return hi }
        return abs(Double(lo) * price - budget) <= abs(Double(hi) * price - budget) ? lo : hi
    }

    func calcGridShares(currentShares: Int) -> Int {
        return max(nearestLot(Double(currentShares) * tradeRatio), GridCalculator.lot)
    }

    func sellPrice(basePrice: Double) -> Double {
        return basePrice * (1 + gridUp)
    }

    func buyPrice(basePrice: Double) -> Double {
        return basePrice * (1 - gridDown)
    }

    func isHitSell(basePrice: Double, currentPrice: Double) -> Bool {
        return currentPrice >= sellPrice(basePrice: basePrice)
    }

    func isHitBuy(basePrice: Double, currentPrice: Double) -> Bool {
        return currentPrice <= buyPrice(basePrice: basePrice)
    }
}
