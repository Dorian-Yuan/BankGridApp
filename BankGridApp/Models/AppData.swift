import Foundation

@MainActor
class AppData: ObservableObject {
    @Published var netCashFlow: Double {
        didSet { UserDefaults.standard.set(netCashFlow, forKey: "netCashFlow") }
    }
    @Published var initCapital: Double {
        didSet { UserDefaults.standard.set(initCapital, forKey: "initCapital") }
    }
    @Published var settings: GridSettings {
        didSet { settings.save() }
    }

    init() {
        self.netCashFlow = UserDefaults.standard.double(forKey: "netCashFlow")
        self.initCapital = UserDefaults.standard.double(forKey: "initCapital")
        self.settings = GridSettings.load()
    }
}
