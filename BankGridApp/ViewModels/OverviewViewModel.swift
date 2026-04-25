import SwiftUI
import CoreData

@MainActor
class OverviewViewModel: ObservableObject {
    @Published var positions: [Position] = []
    @Published var buyCount: Int = 0
    @Published var sellCount: Int = 0
    @Published var totalFee: Double = 0
    @Published var totalDiv: Double = 0

    private let persistence: DataPersistence

    init(persistence: DataPersistence = DataPersistence()) {
        self.persistence = persistence
    }

    func loadData() {
        positions = persistence.fetchPositions()
        let logs = persistence.fetchTradeLogs(limit: 500)
        buyCount = 0
        sellCount = 0
        totalFee = 0
        totalDiv = 0
        for e in logs {
            if e.action == "网格买入" || e.action == "建仓" { buyCount += 1 }
            if e.action == "网格卖出" { sellCount += 1 }
            totalFee += e.fee
            if e.action == "月度平准" {
                buyCount += Int(e.buys)
                sellCount += Int(e.sells)
            }
            if e.action == "除息调整" {
                totalDiv += e.dividend * Double(e.shares)
            }
        }
    }
}
