import CoreData

@MainActor
class DataPersistence {
    let persistenceController: PersistenceController

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    func fetchPositions() -> [Position] {
        let request: NSFetchRequest<Position> = Position.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Position.code, ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }

    func fetchPosition(code: String) -> Position? {
        let request: NSFetchRequest<Position> = Position.fetchRequest()
        request.predicate = NSPredicate(format: "code == %@", code)
        request.fetchLimit = 1
        return (try? viewContext.fetch(request))?.first
    }

    func createPosition(code: String, name: String, short: String, shares: Int32, basePrice: Double, avgCost: Double, totalCost: Double) -> Position {
        let pos = Position(context: viewContext)
        pos.code = code
        pos.name = name
        pos.short = short
        pos.shares = shares
        pos.basePrice = basePrice
        pos.avgCost = avgCost
        pos.totalCost = totalCost
        save()
        return pos
    }

    func addPosition(code: String, name: String, short: String, shares: Int32, basePrice: Double, avgCost: Double, totalCost: Double) {
        let _ = createPosition(code: code, name: name, short: short, shares: shares, basePrice: basePrice, avgCost: avgCost, totalCost: totalCost)
    }

    func fetchTradeLogs(limit: Int = 80) -> [TradeLog] {
        let request: NSFetchRequest<TradeLog> = TradeLog.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TradeLog.timestamp, ascending: false)]
        request.fetchLimit = limit
        return (try? viewContext.fetch(request)) ?? []
    }

    func fetchTradeLogsForBank(_ bankName: String) -> [TradeLog] {
        let request: NSFetchRequest<TradeLog> = TradeLog.fetchRequest()
        request.predicate = NSPredicate(format: "bank == %@", bankName)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TradeLog.timestamp, ascending: false)]
        return (try? viewContext.fetch(request)) ?? []
    }

    func addTradeLog(action: String, bank: String, price: Double = 0, shares: Int32 = 0, amount: Double = 0, fee: Double = 0, dividend: Double = 0, divTax: Double = 0, oldBase: Double = 0, newBase: Double = 0, remainShares: Int32 = 0, totalShares: Int32 = 0, buys: Int32 = 0, sells: Int32 = 0, totalValue: Double = 0, target: Double = 0) {
        let log = TradeLog(context: viewContext)
        log.id = UUID()
        log.action = action
        log.bank = bank
        log.price = price
        log.shares = shares
        log.amount = amount
        log.fee = fee
        log.dividend = dividend
        log.divTax = divTax
        log.oldBase = oldBase
        log.newBase = newBase
        log.remainShares = remainShares
        log.totalShares = totalShares
        log.buys = buys
        log.sells = sells
        log.totalValue = totalValue
        log.target = target
        log.timestamp = Date()
        save()
    }

    func deleteAllPositions() {
        let positions = fetchPositions()
        positions.forEach { viewContext.delete($0) }
        save()
    }

    func deleteAllTradeLogs() {
        let logs = fetchTradeLogs(limit: 10000)
        logs.forEach { viewContext.delete($0) }
        save()
    }

    func backupData() -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backupDir = docs.appendingPathComponent("backup")
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmm"
        let ts = formatter.string(from: Date())

        let positions = fetchPositions()
        if !positions.isEmpty {
            let dict = positions.map { pos -> [String: Any] in
                return [
                    "code": pos.code ?? "",
                    "name": pos.name ?? "",
                    "short": pos.short ?? "",
                    "shares": Int(pos.shares),
                    "basePrice": pos.basePrice,
                    "avgCost": pos.avgCost,
                    "totalCost": pos.totalCost
                ]
            }
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) {
                let url = backupDir.appendingPathComponent("positions_\(ts).json")
                try? data.write(to: url)
            }
        }

        return backupDir
    }

    func save() {
        if viewContext.hasChanges {
            try? viewContext.save()
        }
    }
}
