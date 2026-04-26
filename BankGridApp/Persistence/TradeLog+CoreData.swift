import Foundation
import CoreData

@objc(TradeLog)
public class TradeLog: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var action: String?
    @NSManaged public var bank: String?
    @NSManaged public var price: Double
    @NSManaged public var shares: Int32
    @NSManaged public var amount: Double
    @NSManaged public var fee: Double
    @NSManaged public var dividend: Double
    @NSManaged public var divTax: Double
    @NSManaged public var oldBase: Double
    @NSManaged public var newBase: Double
    @NSManaged public var remainShares: Int32
    @NSManaged public var totalShares: Int32
    @NSManaged public var buys: Int32
    @NSManaged public var sells: Int32
    @NSManaged public var totalValue: Double
    @NSManaged public var target: Double
    @NSManaged public var timestamp: Date?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TradeLog> {
        return NSFetchRequest<TradeLog>(entityName: "TradeLog")
    }
}
