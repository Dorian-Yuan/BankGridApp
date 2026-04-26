import Foundation
import CoreData

@objc(Position)
public class Position: NSManagedObject {
    @NSManaged public var code: String?
    @NSManaged public var name: String?
    @NSManaged public var short: String?
    @NSManaged public var shares: Int32
    @NSManaged public var basePrice: Double
    @NSManaged public var avgCost: Double
    @NSManaged public var totalCost: Double

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
