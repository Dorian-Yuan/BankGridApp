import CoreData

extension Position {
    convenience init(context: NSManagedObjectContext, code: String, name: String, short: String, shares: Int32, basePrice: Double, avgCost: Double, totalCost: Double) {
        self.init(context: context)
        self.code = code
        self.name = name
        self.short = short
        self.shares = shares
        self.basePrice = basePrice
        self.avgCost = avgCost
        self.totalCost = totalCost
    }
}
