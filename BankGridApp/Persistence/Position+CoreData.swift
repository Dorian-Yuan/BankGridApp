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

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Position> {
        return NSFetchRequest<Position>(entityName: "Position")
    }
}
