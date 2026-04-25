import Foundation
import SwiftUI

enum ChartMode: String, CaseIterable {
    case trend = "trend"
    case tech = "tech"
    var label: String {
        switch self {
        case .trend: return "走势对比"
        case .tech: return "指标诊断"
        }
    }
}

enum TimeRange: String, CaseIterable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "ALL"
    var label: String {
        switch self {
        case .oneMonth: return "1月"
        case .threeMonths: return "3月"
        case .sixMonths: return "半年"
        case .oneYear: return "1年"
        case .all: return "全部"
        }
    }
}

struct TechDataPoint {
    let k: [Double]
    let macd: Double
    let dif: Double
    let dea: Double
    let rsi6: Double?
    let rsi14: Double?
}

struct MACDAnalysis {
    let text: String
    let colorHex: String
    let detail: String
    let dif: Double
    let dea: Double
    let macd: Double
}

struct RSIAnalysis {
    let text: String
    let colorHex: String
    let detail: String
    let rsi6: Double?
    let rsi14: Double?
}

@MainActor
class ChartViewModel: ObservableObject {
    @Published var chartMode: ChartMode = .trend
    @Published var selectedBanks: Set<String> = Set(BANKS.map { $0.code })
    @Published var selectedTechCode: String = BANKS.first?.code ?? "601398"
    @Published var timeRange: TimeRange = .threeMonths
    @Published var filterStartDate: String = ""
    @Published var filterEndDate: String = ""
    @Published var macdAnalysis: MACDAnalysis?
    @Published var rsiAnalysis: RSIAnalysis?
    @Published var isDataReady: Bool = false

    private var allDates: [String] = []
    private var closeMap: [String: [String: Double]] = [:]
    private var fullTechData: [String: [String: TechDataPoint]] = [:]

    let csvService: CSVDataService

    init(csvService: CSVDataService) {
        self.csvService = csvService
    }

    func prepareData() {
        let allData = csvService.allData
        var dateSet = Set<String>()
        for (_, points) in allData {
            for p in points { dateSet.insert(p.date) }
        }
        allDates = dateSet.sorted()

        closeMap = [:]
        fullTechData = [:]

        for (code, points) in allData {
            var cMap: [String: Double] = [:]
            var closesForTech: [(date: String, val: Double, k: [Double])] = []
            for p in points {
                cMap[p.date] = p.close
                closesForTech.append((date: p.date, val: p.close, k: [p.open, p.close, p.low, p.high]))
            }
            closeMap[code] = cMap

            let closeArr = closesForTech.map { $0.val }
            let macdRes = calcMACD(closes: closeArr)
            let rsi6Res = calcRSI(closes: closeArr, n: 6)
            let rsi14Res = calcRSI(closes: closeArr, n: 14)

            var tData: [String: TechDataPoint] = [:]
            for (idx, item) in closesForTech.enumerated() {
                tData[item.date] = TechDataPoint(
                    k: item.k,
                    macd: macdRes.macd[idx],
                    dif: macdRes.dif[idx],
                    dea: macdRes.dea[idx],
                    rsi6: rsi6Res[idx],
                    rsi14: rsi14Res[idx]
                )
            }
            fullTechData[code] = tData
        }

        if allDates.isEmpty {
            isDataReady = false
            return
        }

        filterEndDate = allDates.last ?? ""
        let endStr = filterEndDate
        if let end = dateFromString(endStr) {
            let start = Calendar.current.date(byAdding: .month, value: -3, to: end) ?? end
            let sStr = stringFromDate(start)
            filterStartDate = allDates.first { $0 >= sStr } ?? allDates.first ?? ""
        }

        isDataReady = true
    }

    func filteredDates() -> [String] {
        allDates.filter { $0 >= filterStartDate && $0 <= filterEndDate }
    }

    func setTimeRange(_ range: TimeRange) {
        timeRange = range
        guard !allDates.isEmpty else { return }
        let endStr = allDates.last ?? ""
        guard let end = dateFromString(endStr) else { return }
        var start: Date
        switch range {
        case .oneMonth:
            start = Calendar.current.date(byAdding: .month, value: -1, to: end) ?? end
        case .threeMonths:
            start = Calendar.current.date(byAdding: .month, value: -3, to: end) ?? end
        case .sixMonths:
            start = Calendar.current.date(byAdding: .month, value: -6, to: end) ?? end
        case .oneYear:
            start = Calendar.current.date(byAdding: .year, value: -1, to: end) ?? end
        case .all:
            filterStartDate = allDates.first ?? ""
            filterEndDate = endStr
            return
        }
        let sStr = stringFromDate(start)
        filterStartDate = allDates.first { $0 >= sStr } ?? allDates.first ?? ""
        filterEndDate = endStr
    }

    func toggleBank(_ code: String) {
        if chartMode == .trend {
            if selectedBanks.contains(code) {
                selectedBanks.remove(code)
            } else {
                selectedBanks.insert(code)
            }
        } else {
            selectedTechCode = code
        }
    }

    func isSelected(_ code: String) -> Bool {
        chartMode == .trend ? selectedBanks.contains(code) : code == selectedTechCode
    }

    func buildTrendJSON() -> String {
        let dates = filteredDates()
        let selectedCodes = BANKS.filter { selectedBanks.contains($0.code) }
        var seriesArr: [[String: Any]] = []

        for bank in selectedCodes {
            guard let cMap = closeMap[bank.code] else { continue }
            let data = dates.map { cMap[$0] as Any }
            seriesArr.append([
                "name": bank.short,
                "type": "line",
                "showSymbol": false,
                "smooth": true,
                "lineStyle": ["width": 2, "color": bank.colorHex],
                "itemStyle": ["color": bank.colorHex],
                "data": data
            ])
        }

        if let idxMap = closeMap["399986"] {
            let idxData = dates.map { d -> Any in
                if let v = idxMap[d] { return v / 1000.0 }
                return NSNull()
            }
            seriesArr.append([
                "name": "中证(÷1000)",
                "type": "line",
                "showSymbol": false,
                "smooth": true,
                "lineStyle": ["width": 1.5, "type": "dashed", "color": IDX_COLOR_HEX],
                "itemStyle": ["color": IDX_COLOR_HEX],
                "yAxisIndex": 0,
                "data": idxData
            ])
        }

        let payload: [String: Any] = [
            "mode": "trend",
            "dates": dates,
            "series": seriesArr
        ]
        return jsonString(from: payload)
    }

    func buildTechJSON() -> String {
        let code = selectedTechCode
        let dates = filteredDates()
        guard let tData = fullTechData[code] else {
            return "{\"mode\":\"tech\",\"dates\":[],\"kData\":[],\"macdBar\":[],\"difLine\":[],\"deaLine\":[],\"rsi6Line\":[],\"rsi14Line\":[],\"crossPoints\":[]}"
        }

        var kData: [Any] = []
        var macdBar: [Any] = []
        var difLine: [Any] = []
        var deaLine: [Any] = []
        var rsi6Line: [Any] = []
        var rsi14Line: [Any] = []
        var lastInfo: TechDataPoint?

        for d in dates {
            if let tp = tData[d] {
                kData.append(tp.k)
                macdBar.append([
                    "value": tp.macd,
                    "itemStyle": ["color": tp.macd > 0 ? "#ff3b30" : "#34c759"]
                ] as [String: Any])
                difLine.append(tp.dif)
                deaLine.append(tp.dea)
                rsi6Line.append(tp.rsi6 as Any)
                rsi14Line.append(tp.rsi14 as Any)
                lastInfo = tp
            } else {
                kData.append([])
                macdBar.append(NSNull())
                difLine.append(NSNull())
                deaLine.append(NSNull())
                rsi6Line.append(NSNull())
                rsi14Line.append(NSNull())
            }
        }

        var crossPoints: [[String: Any]] = []
        for i in 1..<difLine.count {
            guard let curDif = difLine[i] as? Double,
                  let curDea = deaLine[i] as? Double,
                  let prevDif = difLine[i - 1] as? Double,
                  let prevDea = deaLine[i - 1] as? Double else { continue }
            let prevDiff = prevDif - prevDea
            let currDiff = curDif - curDea
            if (prevDiff <= 0 && currDiff > 0) || (prevDiff >= 0 && currDiff < 0) {
                crossPoints.append([
                    "idx": i,
                    "date": dates[i],
                    "value": curDif,
                    "type": currDiff > 0 ? "金叉" : "死叉"
                ])
            }
        }
        if crossPoints.count > 5 {
            crossPoints = Array(crossPoints.suffix(5))
        }

        updateAnalysis(code: code, lastInfo: lastInfo, dates: dates, tData: tData)

        let payload: [String: Any] = [
            "mode": "tech",
            "dates": dates,
            "kData": kData,
            "macdBar": macdBar,
            "difLine": difLine,
            "deaLine": deaLine,
            "rsi6Line": rsi6Line,
            "rsi14Line": rsi14Line,
            "crossPoints": crossPoints
        ]
        return jsonString(from: payload)
    }

    func updateAnalysis(code: String, lastInfo: TechDataPoint?, dates: [String], tData: [String: TechDataPoint]) {
        guard let info = lastInfo, let rsi14 = info.rsi14, let rsi6 = info.rsi6 else {
            macdAnalysis = nil
            rsiAnalysis = nil
            return
        }

        var prevMacd: Double? = nil
        for i in stride(from: dates.count - 1, through: 1, by: -1) {
            if let tp = tData[dates[i]], tp.macd == info.macd {
                if let prev = tData[dates[i - 1]] {
                    prevMacd = prev.macd
                    break
                }
            }
        }

        let macdIncreasing = prevMacd != nil ? info.macd > prevMacd! : true

        let macdA = analyzeMACD(dif: info.dif, macd: info.macd, macdIncreasing: macdIncreasing)
        macdAnalysis = MACDAnalysis(
            text: macdA.text,
            colorHex: macdA.colorHex,
            detail: macdA.detail,
            dif: info.dif,
            dea: info.dea,
            macd: info.macd
        )

        let rsiA = analyzeRSI(rsi6: rsi6, rsi14: rsi14)
        rsiAnalysis = RSIAnalysis(
            text: rsiA.text,
            colorHex: rsiA.colorHex,
            detail: rsiA.detail,
            rsi6: rsi6,
            rsi14: rsi14
        )
    }

    func calcEMA(data: [Double], n: Int) -> [Double] {
        guard !data.isEmpty else { return [] }
        let alpha = 2.0 / Double(n + 1)
        var ema = [data[0]]
        for i in 1..<data.count {
            ema.append(alpha * data[i] + (1 - alpha) * ema[i - 1])
        }
        return ema
    }

    func calcMACD(closes: [Double]) -> (dif: [Double], dea: [Double], macd: [Double]) {
        let ema12 = calcEMA(data: closes, n: 12)
        let ema26 = calcEMA(data: closes, n: 26)
        var dif = [Double]()
        for i in 0..<closes.count { dif.append(ema12[i] - ema26[i]) }
        let dea = calcEMA(data: dif, n: 9)
        var macd = [Double]()
        for i in 0..<closes.count { macd.append((dif[i] - dea[i]) * 2) }
        return (dif, dea, macd)
    }

    func calcRSI(closes: [Double], n: Int) -> [Double?] {
        var rsi = [Double?](repeating: nil, count: closes.count)
        guard closes.count > n else { return rsi }
        var gains = 0.0, losses = 0.0
        for i in 1...n {
            let change = closes[i] - closes[i - 1]
            if change > 0 { gains += change } else { losses -= change }
        }
        var avgGain = gains / Double(n)
        var avgLoss = losses / Double(n)
        rsi[n] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss))
        for i in (n + 1)..<closes.count {
            let change = closes[i] - closes[i - 1]
            let gain = change > 0 ? change : 0
            let loss = change < 0 ? -change : 0
            avgGain = (avgGain * Double(n - 1) + gain) / Double(n)
            avgLoss = (avgLoss * Double(n - 1) + loss) / Double(n)
            rsi[i] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss))
        }
        return rsi
    }

    private func analyzeMACD(dif: Double, macd: Double, macdIncreasing: Bool) -> (text: String, colorHex: String, detail: String) {
        if dif > 0 {
            if macd > 0 {
                if macdIncreasing {
                    return ("强多头(加速)", "#ff3b30", "当前DIF在零轴上方且MACD柱为正并在增大，多头趋势强劲，上涨动能持续加速。此阶段持股为主，但需警惕短期过热。")
                } else {
                    return ("多头衰减", "#FF9F0A", "当前DIF在零轴上方且MACD柱为正但在缩小，多头趋势仍在但动能开始减弱。上涨力度放缓，需关注是否出现死叉信号，可考虑逐步减仓。")
                }
            } else {
                if macdIncreasing {
                    return ("多头蓄力", "#FFD43B", "当前DIF在零轴上方但MACD柱为负并在收敛，多头格局下的回调蓄力阶段。空方力量正在消退，可能即将重新上攻，可关注金叉出现。")
                } else {
                    return ("多头衰竭", "#8B6914", "当前DIF在零轴上方但MACD柱为负且仍在扩大，多头动能严重衰竭。DIF虽在零轴上方但即将下穿DEA形成死叉，需警惕趋势反转，建议做好防守准备。")
                }
            }
        } else {
            if macd < 0 {
                if macdIncreasing {
                    return ("空头衰减", "#64D2FF", "当前DIF在零轴下方且MACD柱为负但在收敛，空头趋势仍在减弱。下跌动能逐步消退，可能即将迎来反弹，可关注DIF上穿DEA的金叉信号。")
                } else {
                    return ("强空头(加速)", "#34C759", "当前DIF在零轴下方且MACD柱为负并在扩大，空头趋势强劲，下跌动能持续加速。此阶段应以观望为主，不宜盲目抄底。")
                }
            } else {
                if macdIncreasing {
                    return ("空头蓄力", "#BF5AF2", "当前DIF在零轴下方但MACD柱为正并在扩大，空头格局下的技术性反弹。多方力量有所增强，但DIF仍在零轴下方，趋势尚未真正反转，需谨慎对待。")
                } else {
                    return ("空头反弹", "#666666", "当前DIF在零轴下方且MACD柱为正但在缩小，空头格局中的反弹动力不足。反弹可能即将结束，有再次下探风险，不宜追涨。")
                }
            }
        }
    }

    private func analyzeRSI(rsi6: Double, rsi14: Double) -> (text: String, colorHex: String, detail: String) {
        if rsi6 > 80 {
            return ("严重超买", "#ff3b30", "RSI(6)超过80，进入严重超买区域。短期涨幅过大，市场极度乐观，随时可能出现大幅回调。建议高度警惕，考虑逐步减仓锁定利润，切勿追高。")
        } else if rsi6 > 70 {
            return ("超买区", "#FF9F0A", "RSI(6)超过70，进入超买区域。短期上涨较快，市场情绪偏热，存在回调压力。建议谨慎追涨，可考虑部分获利了结，等待RSI回落后再考虑介入。")
        } else if rsi6 >= 50 && rsi6 <= 70 && rsi6 > rsi14 {
            return ("多头偏强", "#FF6B8A", "RSI(6)在50-70之间且高于RSI(14)，多头力量占优。短期动能偏强，价格有继续上行的可能。可维持当前仓位，但需关注RSI是否逼近70超买线。")
        } else if rsi6 >= 40 && rsi6 <= 60 {
            return ("中性区间", "#8e8e93", "RSI(6)在40-60之间，多空力量相对均衡，市场处于震荡整理阶段。此区间方向不明，建议观望为主，等待RSI突破50后确认方向再行动。")
        } else if rsi6 >= 30 && rsi6 < 50 && rsi6 < rsi14 {
            return ("空头偏强", "#64D2FF", "RSI(6)在30-50之间且低于RSI(14)，空头力量占优。短期动能偏弱，价格有继续下行的可能。建议谨慎操作，等待RSI回升突破50后再考虑加仓。")
        } else if rsi6 >= 20 && rsi6 < 30 {
            return ("超卖区", "#BF5AF2", "RSI(6)低于30，进入超卖区域。短期跌幅较大，市场情绪偏悲观，但存在技术性反弹的可能。可关注是否出现企稳信号，不宜盲目杀跌。")
        } else if rsi6 < 20 {
            return ("严重超卖", "#34C759", "RSI(6)低于20，进入严重超卖区域。短期跌幅过大，市场极度恐慌，反弹随时可能发生。但需注意，超卖不等于见底，应结合其他指标综合判断。")
        } else {
            if rsi6 > rsi14 {
                return ("偏多", "#8e8e93", "RSI(6)略高于RSI(14)，短期动能略偏多头，但优势不明显。建议结合MACD等其他指标综合判断方向。")
            } else {
                return ("偏空", "#8e8e93", "RSI(6)略低于RSI(14)，短期动能略偏空头，但劣势不明显。建议结合MACD等其他指标综合判断方向。")
            }
        }
    }

    private func dateFromString(_ s: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: s)
    }

    private func stringFromDate(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: d)
    }

    private func jsonString(from dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
