import Foundation

struct PriceData {
    var current: Double = 0
    var yClose: Double = 0
    var open: Double = 0
    var high: Double = 0
    var low: Double = 0
    var pct: Double = 0
}

struct CSVDataPoint: Identifiable {
    var id: String { date }
    let date: String
    let open: Double
    let close: Double
    let high: Double
    let low: Double
}
