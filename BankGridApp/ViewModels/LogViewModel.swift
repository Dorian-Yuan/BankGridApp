import Foundation
import SwiftUI

struct LogItem: Identifiable {
    let id = UUID()
    let action: String
    let bank: String
    let detail: String
    let time: String
    let color: Color

    static func from(_ log: TradeLog) -> LogItem {
        let action = log.action ?? ""
        let bank = log.bank ?? ""

        let color: Color
        if action.contains("买") {
            color = .themeGreen
        } else if action.contains("卖") {
            color = .themeRed
        } else if action.contains("除息") {
            color = .themeYellow
        } else {
            color = .themeAccent
        }

        var detail = ""
        if log.shares > 0 && log.price > 0 {
            detail = "\(bank) \(log.shares)股 × ¥\(log.price.toFixed(2)) | 费 ¥\(log.fee.toFixed(2))"
            if log.divTax > 0 {
                detail += " (含红利税¥\(log.divTax.toFixed(2)))"
            }
        } else if log.dividend > 0 {
            detail = "\(bank) 分红 ¥\(log.dividend.toFixed(3)) | P: \(log.oldBase.toFixed(3))→\(log.newBase.toFixed(3))"
        } else if action == "月度平准" {
            detail = "总市 ¥\(Int(log.totalValue)) 目标每只 ¥\(Int(log.target))"
        } else if action == "手动编辑" {
            detail = "\(bank) \(log.shares)股 P=¥\(log.newBase.toFixed(3))"
        } else {
            detail = "\(bank) \(log.shares)股 ¥\(log.price.toFixed(2))"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d HH:mm:ss"
        let timeStr = log.timestamp != nil ? formatter.string(from: log.timestamp!) : ""

        return LogItem(action: action, bank: bank, detail: detail, time: timeStr, color: color)
    }
}

class LogViewModel: ObservableObject {
    @Published var logs: [LogItem] = []
    @Published var persistence: DataPersistence

    init(persistence: DataPersistence) {
        self.persistence = persistence
        loadLogs()
    }

    func loadLogs() {
        let tradeLogs = persistence.fetchTradeLogs(limit: 80)
        logs = tradeLogs.map { LogItem.from($0) }
    }
}
