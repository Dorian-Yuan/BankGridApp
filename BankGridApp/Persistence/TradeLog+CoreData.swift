import Foundation
import CoreData

extension TradeLog {
    convenience init(context: NSManagedObjectContext, action: String, bank: String, price: Double = 0, shares: Int32 = 0, amount: Double = 0, fee: Double = 0, dividend: Double = 0, divTax: Double = 0, oldBase: Double = 0, newBase: Double = 0, remainShares: Int32 = 0, totalShares: Int32 = 0, buys: Int32 = 0, sells: Int32 = 0, totalValue: Double = 0, target: Double = 0) {
        self.init(context: context)
        self.id = UUID()
        self.action = action
        self.bank = bank
        self.price = price
        self.shares = shares
        self.amount = amount
        self.fee = fee
        self.dividend = dividend
        self.divTax = divTax
        self.oldBase = oldBase
        self.newBase = newBase
        self.remainShares = remainShares
        self.totalShares = totalShares
        self.buys = buys
        self.sells = sells
        self.totalValue = totalValue
        self.target = target
        self.timestamp = Date()
    }
}
