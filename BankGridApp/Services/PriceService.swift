import Foundation

@MainActor
class PriceService: ObservableObject {
    @Published var prices: [String: PriceData] = [:]
    @Published var idxPct: Double = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var timer: Timer?
    private var settings: GridSettings

    init(settings: GridSettings = GridSettings()) {
        self.settings = settings
    }

    func updateSettings(_ settings: GridSettings) {
        self.settings = settings
        restartAutoRefresh()
    }

    func fetchPrices(silent: Bool = false) async {
        if !silent { isLoading = true }
        errorMessage = nil

        let codes = BANKS.map { $0.qtCode }.joined(separator: ",") + ",sz399986"
        let urlString = "https://qt.gtimg.cn/q=\(codes)"

        guard let url = URL(string: urlString) else {
            if !silent { isLoading = false; errorMessage = "无效URL" }
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let text = String(data: data, encoding: .utf8) else {
                if !silent { isLoading = false; errorMessage = "编码错误" }
                return
            }

            parsePriceResponse(text)
            if !silent { isLoading = false }
        } catch {
            if !silent {
                isLoading = false
                errorMessage = "网络错误: \(error.localizedDescription)"
            }
        }
    }

    private func parsePriceResponse(_ text: String) {
        let lines = text.split(separator: ";")
        for line in lines {
            guard line.contains("=") else { continue }
            let parts = line.split(separator: "~").map { String($0) }
            guard parts.count > 32 else { continue }

            let codeMatch = line.range(of: "v_(s[hz]\\d{6})", options: .regularExpression)
            guard let match = codeMatch else { continue }
            let codeWithPrefix = String(line[match]).replacingOccurrences(of: "v_", with: "")
            let code = codeWithPrefix.replacingOccurrences(of: "sh", with: "").replacingOccurrences(of: "sz", with: "")

            if code == "399986" {
                idxPct = Double(parts[32]) ?? 0
            } else {
                var pd = PriceData()
                pd.current = Double(parts[3]) ?? 0
                pd.yClose = Double(parts[4]) ?? 0
                pd.open = Double(parts[5]) ?? 0
                pd.high = Double(parts[33]) ?? 0
                pd.low = Double(parts[34]) ?? 0
                pd.pct = Double(parts[32]) ?? 0
                prices[code] = pd
            }
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        let interval = settings.refreshInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.fetchPrices(silent: true) }
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    func restartAutoRefresh() {
        startAutoRefresh()
    }

    func price(for code: String) -> Double {
        prices[code]?.current ?? 0
    }

    func priceData(for code: String) -> PriceData {
        prices[code] ?? PriceData()
    }
}
