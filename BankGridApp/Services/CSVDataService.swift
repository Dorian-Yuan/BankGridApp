import Foundation

@MainActor
class CSVDataService: ObservableObject {
    @Published var allData: [String: [CSVDataPoint]] = [:]
    @Published var bankMap: [String: String] = [
        "601288": "农行", "601328": "交行", "601398": "工行",
        "601658": "邮储", "601939": "建行", "601988": "中行",
        "399986": "中证"
    ]

    private let baseURL = "https://raw.githubusercontent.com/Dorian-Yuan/cn_banks_quant/main/data/ashare"
    private let fileManager = FileManager.default

    var csvDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("csv_data")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func downloadIfNeeded() async {
        let todayStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)

        for (code, _) in bankMap {
            let fileName = "\(code).csv"
            let localURL = csvDirectory.appendingPathComponent(fileName)

            if fileManager.fileExists(atPath: localURL.path) {
                if let attrs = try? fileManager.attributesOfItem(atPath: localURL.path),
                   let modDate = attrs[.modificationDate] as? Date {
                    let modStr = DateFormatter.localizedString(from: modDate, dateStyle: .short, timeStyle: .none)
                    if modStr == todayStr { continue }
                }
            }

            let urlString = "\(baseURL)/\(fileName)"
            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                try data.write(to: localURL)
            } catch {
                continue
            }
        }
    }

    func loadAllData() {
        var result: [String: [CSVDataPoint]] = [:]
        for (code, _) in bankMap {
            let fileName = "\(code).csv"
            let localURL = csvDirectory.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: localURL.path),
               let text = try? String(contentsOf: localURL, encoding: .utf8) {
                result[code] = parseCSV(text)
            }
        }
        allData = result
    }

    private func parseCSV(_ text: String) -> [CSVDataPoint] {
        let lines = text.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return [] }

        let headers = lines[0].split(separator: ",").map { $0.lowercased() }

        func findCol(_ keys: [String]) -> Int {
            for (i, h) in headers.enumerated() {
                if keys.contains(where: { h.contains($0) }) { return i }
            }
            return -1
        }

        var iDate = findCol(["date", "日期"])
        var iOpen = findCol(["open", "开�?])
        var iClose = findCol(["close", "收盘"])
        var iHigh = findCol(["high", "最�?])
        var iLow = findCol(["low", "最�?])

        if iOpen == -1 { iDate = 0; iOpen = 1; iClose = 2; iHigh = 3; iLow = 4 }

        var data: [CSVDataPoint] = []
        for i in 1..<lines.count {
            let cols = lines[i].split(separator: ",").map { String($0) }
            if cols.count > iLow {
                let date = cols[iDate].replacingOccurrences(of: "/", with: "-")
                let open = Double(cols[iOpen]) ?? 0
                let close = Double(cols[iClose]) ?? 0
                let high = Double(cols[iHigh]) ?? 0
                let low = Double(cols[iLow]) ?? 0
                if open > 0 || close > 0 {
                    data.append(CSVDataPoint(date: date, open: open, close: close, high: high, low: low))
                }
            }
        }
        return data
    }
}
