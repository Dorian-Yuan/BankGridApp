import SwiftUI

struct ChartView: View {
    @StateObject private var viewModel: ChartViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(csvService: CSVDataService) {
        _viewModel = StateObject(wrappedValue: ChartViewModel(csvService: csvService))
    }

    var body: some View {
        VStack(spacing: 0) {
            modeBar
            bankTagSelector
            if viewModel.chartMode == .tech {
                analysisBox
            }
            chartContainer
            timeRangeBar
            dateRangeRow
        }
        .background(Color.themeBg)
        .task {
            viewModel.prepareData()
        }
        .onChange(of: viewModel.chartMode) { _ in refreshChart() }
        .onChange(of: viewModel.selectedBanks) { _ in if viewModel.chartMode == .trend { refreshChart() } }
        .onChange(of: viewModel.selectedTechCode) { _ in if viewModel.chartMode == .tech { refreshChart() } }
        .onChange(of: viewModel.filterStartDate) { _ in refreshChart() }
        .onChange(of: viewModel.filterEndDate) { _ in refreshChart() }
    }

    private var modeBar: some View {
        HStack(spacing: 0) {
            ForEach(ChartMode.allCases, id: \.self) { mode in
                Button(action: { viewModel.chartMode = mode }) {
                    Text(mode.label)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(viewModel.chartMode == mode ? .white : .themeText2)
                        .background(viewModel.chartMode == mode ? Color.themeAccent : Color.clear)
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(Color.themeCard2)
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var bankTagSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BANKS) { bank in
                    Button(action: { viewModel.toggleBank(bank.code) }) {
                        Text(bank.short)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundColor(viewModel.isSelected(bank.code) ? .white : Color(hex: bank.colorHex))
                            .background(
                                viewModel.isSelected(bank.code)
                                    ? Color(hex: bank.colorHex)
                                    : Color.themeCard2
                            )
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: bank.colorHex), lineWidth: viewModel.isSelected(bank.code) ? 0 : 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }

    private var analysisBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let macd = viewModel.macdAnalysis {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#FF9F0A"))
                        .frame(width: 6, height: 6)
                    Text("MACD")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.themeText)
                    Text(macd.text)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: macd.colorHex))
                }
            }
            if let rsi = viewModel.rsiAnalysis {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#BF5AF2"))
                        .frame(width: 6, height: 6)
                    Text("RSI")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.themeText)
                    Text(rsi.text)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: rsi.colorHex))
                    if let r6 = rsi.rsi6, let r14 = rsi.rsi14 {
                        Text("(\(String(format: "%.1f", r6))/\(String(format: "%.1f", r14)))")
                            .font(.system(size: 11))
                            .foregroundColor(.themeText2)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.themeCard)
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }

    private var chartContainer: some View {
        EChartsBridge(jsonData: currentJSON, isDark: colorScheme == .dark)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 300)
    }

    private var timeRangeBar: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: { viewModel.setTimeRange(range) }) {
                    Text(range.label)
                        .font(.system(size: 13, weight: viewModel.timeRange == range ? .semibold : .regular))
                        .foregroundColor(viewModel.timeRange == range ? .themeAccent : .themeText2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var dateRangeRow: some View {
        HStack(spacing: 8) {
            DatePicker("", selection: Binding(
                get: { viewModel.filterStartDate.toDate() ?? Date() },
                set: { viewModel.filterStartDate = $0.toString() }
            ), displayedComponents: .date)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "zh_CN"))

            Text("�?)
                .font(.system(size: 13))
                .foregroundColor(.themeText2)

            DatePicker("", selection: Binding(
                get: { viewModel.filterEndDate.toDate() ?? Date() },
                set: { viewModel.filterEndDate = $0.toString() }
            ), displayedComponents: .date)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "zh_CN"))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var currentJSON: String {
        if viewModel.chartMode == .trend {
            return viewModel.buildTrendJSON()
        } else {
            return viewModel.buildTechJSON()
        }
    }

    private func refreshChart() {
        viewModel.objectWillChange.send()
    }
}

extension String {
    func toDate() -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: self)
    }
}

extension Date {
    func toString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: self)
    }
}
