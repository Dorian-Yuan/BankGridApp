import SwiftUI
import CoreData

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var positions: [Position] = []
    @Published var totalRealValue: Double = 0
    @Published var totalPnL: Double = 0
    @Published var diffPct: Double = 0
    @Published var todayPnL: Double = 0
    @Published var todayPct: Double = 0

    private let persistence: DataPersistence

    init(persistence: DataPersistence = DataPersistence()) {
        self.persistence = persistence
    }

    func loadData(prices: [String: PriceData], netCashFlow: Double) {
        positions = persistence.fetchPositions()
        var totalBaseValue: Double = 0
        totalRealValue = 0
        todayPnL = 0
        var totalYCloseValue: Double = 0

        for pos in positions {
            let rtp = prices[pos.code ?? ""]?.current ?? pos.basePrice
            let yClose = prices[pos.code ?? ""]?.yClose ?? pos.basePrice
            totalBaseValue += Double(pos.shares) * pos.basePrice
            totalRealValue += Double(pos.shares) * rtp
            todayPnL += Double(pos.shares) * (rtp - yClose)
            totalYCloseValue += Double(pos.shares) * yClose
        }

        totalPnL = totalRealValue + netCashFlow
        diffPct = totalBaseValue > 0 ? (totalRealValue - totalBaseValue) / totalBaseValue * 100 : 0
        todayPct = totalYCloseValue > 0 ? todayPnL / totalYCloseValue * 100 : 0
    }
}
