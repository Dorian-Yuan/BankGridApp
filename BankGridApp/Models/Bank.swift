import SwiftUI

struct BankInfo: Identifiable, Codable {
    var id: String { code }
    let code: String
    let name: String
    let short: String
    let qtCode: String
    let colorHex: String

    var color: Color {
        Color(hex: colorHex)
    }
}

let BANKS: [BankInfo] = [
    BankInfo(code: "601398", name: "工商银行", short: "工行", qtCode: "sh601398", colorHex: "#FF9F0A"),
    BankInfo(code: "601939", name: "建设银行", short: "建行", qtCode: "sh601939", colorHex: "#64D2FF"),
    BankInfo(code: "601288", name: "农业银行", short: "农行", qtCode: "sh601288", colorHex: "#FF3B30"),
    BankInfo(code: "601988", name: "中国银行", short: "中行", qtCode: "sh601988", colorHex: "#34C759"),
    BankInfo(code: "601328", name: "交通银�?, short: "交行", qtCode: "sh601328", colorHex: "#BF5AF2"),
    BankInfo(code: "601658", name: "邮储银行", short: "邮储", qtCode: "sh601658", colorHex: "#FF6B8A")
]

let IDX_COLOR_HEX = "#8888aa"
let LOT = 100

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
