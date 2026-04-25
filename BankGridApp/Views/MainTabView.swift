import SwiftUI

struct MainTabView: View {
    @StateObject private var appData: AppData
    @StateObject private var priceService: PriceService
    @StateObject private var csvService: CSVDataService
    @StateObject private var toolsVM: ToolsViewModel
    @StateObject private var logVM: LogViewModel

    init() {
        let ad = AppData()
        let ps = PriceService(settings: ad.settings)
        let cs = CSVDataService()
        let p = DataPersistence()

        _appData = StateObject(wrappedValue: ad)
        _priceService = StateObject(wrappedValue: ps)
        _csvService = StateObject(wrappedValue: cs)
        _toolsVM = StateObject(wrappedValue: ToolsViewModel(appData: ad, persistence: p, priceService: ps))
        _logVM = StateObject(wrappedValue: LogViewModel(persistence: p))
    }

    var body: some View {
        TabView {
            OverviewView(
                priceService: priceService,
                appData: appData
            )
            .tabItem {
                Label("概览", systemImage: "square.grid.2x2")
            }

            DashboardView(
                priceService: priceService,
                appData: appData,
                calculator: gridCalculator
            )
            .tabItem {
                Label("监控", systemImage: "chart.bar")
            }

            ChartView(
                csvService: csvService
            )
            .tabItem {
                Label("图表", systemImage: "chart.line.uptrend.xyaxis")
            }

            ToolsView(
                viewModel: toolsVM
            )
            .tabItem {
                Label("工具", systemImage: "wrench.and.screwdriver")
            }

            LogView(
                viewModel: logVM
            )
            .tabItem {
                Label("日志", systemImage: "list.clipboard")
            }
        }
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .preferredColorScheme(appData.settings.theme.colorScheme)
        .task {
            await csvService.downloadIfNeeded()
            csvService.loadAllData()
            await priceService.fetchPrices()
            priceService.startAutoRefresh()
        }
    }

    private var gridCalculator: GridCalculator {
        GridCalculator(
            gridUp: appData.settings.gridUp,
            gridDown: appData.settings.gridDown,
            tradeRatio: appData.settings.tradeRatio,
            feeRate: appData.settings.feeRate,
            feeMin: appData.settings.feeMin
        )
    }
}
