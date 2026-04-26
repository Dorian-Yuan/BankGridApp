import Foundation
import SwiftUI

struct GridSettings: Codable {
    var gridUp: Double = 0.012
    var gridDown: Double = 0.005
    var tradeRatio: Double = 0.3
    var refreshInterval: Double = 15
    var feeRate: Double = 0.0000854
    var feeMin: Double = 0.5
    var theme: AppTheme = .system

    static func load() -> GridSettings {
        guard let data = UserDefaults.standard.data(forKey: "gridSettings"),
              let settings = try? JSONDecoder().decode(GridSettings.self, from: data) else {
            return GridSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "gridSettings")
        }
    }
}

enum AppTheme: String, Codable, CaseIterable {
    case system = "system"
    case dark = "dark"
    case light = "light"

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .dark: return "深色模式"
        case .light: return "浅色模式"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}
