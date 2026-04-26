import SwiftUI

struct SettingsSheetView: View {
    @ObservedObject var viewModel: ToolsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var refreshInterval: Double = 0
    @State private var theme: AppTheme = .system
    @State private var gridUp: Double = 0
    @State private var gridDown: Double = 0
    @State private var tradeRatio: Double = 0
    @State private var feeRate: Double = 0
    @State private var feeMin: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    switch viewModel.settingsType {
                    case .general:
                        generalSettings
                    case .grid:
                        gridSettings
                    case .fees:
                        feesSettings
                    }
                }
                .padding(20)
            }
            .background(Color.themeBg)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear {
            refreshInterval = viewModel.appData.settings.refreshInterval
            theme = viewModel.appData.settings.theme
            gridUp = viewModel.appData.settings.gridUp * 100
            gridDown = viewModel.appData.settings.gridDown * 100
            tradeRatio = viewModel.appData.settings.tradeRatio * 100
            feeRate = viewModel.appData.settings.feeRate * 10000
            feeMin = viewModel.appData.settings.feeMin
        }
    }

    private var navigationTitle: String {
        switch viewModel.settingsType {
        case .general: return "通用设置"
        case .grid: return "网格与仓位设�?
        case .fees: return "交易手续费设�?
        }
    }

    private var generalSettings: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("后台自动刷新频率 (�?")
                    .font(.system(size: 13))
                    .foregroundColor(.themeText2)
                TextField("", value: $refreshInterval, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(CustomTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("外观主题")
                    .font(.system(size: 13))
                    .foregroundColor(.themeText2)
                Picker("外观主题", selection: $theme) {
                    ForEach(AppTheme.allCases, id: \.self) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            }

            Button(action: {
                viewModel.saveGeneralSettings(refreshInterval: refreshInterval, theme: theme)
                dismiss()
            }) {
                Text("保存设置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.themeAccent)
                    .cornerRadius(10)
            }
        }
    }

    private var gridSettings: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("卖出网格比例 (%)")
                    .font(.system(size: 13))
                    .foregroundColor(.themeText2)
                TextField("", value: $gridUp, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(CustomTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("买入网格比例 (%)")
                    .font(.system(size: 13))
                    .foregroundColor(.themeText2)
                TextField("", value: $gridDown, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(CustomTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("单次交易仓位比例 (%)")
                    .font(.system(size: 13))
                    .foregroundColor(.themeText2)
                TextField("", value: $tradeRatio, format: .number.precision(.fractionLength(0)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(CustomTextFieldStyle())
            }

            Button(action: {
                viewModel.saveGridSettings(
                    gridUp: gridUp / 100,
                    gridDown: gridDown / 100,
                    tradeRatio: tradeRatio / 100
                )
                dismiss()
            }) {
                Text("保存参数")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.themeAccent)
                    .cornerRadius(10)
            }
        }
    }

    private var feesSettings: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("佣金费率 (万分�?")
                    .font(.system(size: 13))
                    .foregroundColor(.themeText2)
                TextField("", value: $feeRate, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(CustomTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("单笔最低佣�?(�?")
                    .font(.system(size: 13))
                    .foregroundColor(.themeText2)
                TextField("", value: $feeMin, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(CustomTextFieldStyle())
            }

            Divider()
                .padding(.vertical, 4)

            Text("固定税费（已内置参与计算，不可修改）")
                .font(.system(size: 13))
                .foregroundColor(.themeText2)

            VStack(alignment: .leading, spacing: 4) {
                Text("过户�?)
                    .font(.system(size: 13))
                    .foregroundColor(.themeText2)
                HStack {
                    Text("双向收取，万分之 0.1")
                        .font(.system(size: 14))
                        .foregroundColor(.themeText)
                    Spacer()
                }
                .padding(10)
                .background(Color.themeCard)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.themeBorder, lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("印花�?)
                    .font(.system(size: 13))
                    .foregroundColor(.themeText2)
                HStack {
                    Text("卖出单向收取，万分之 5")
                        .font(.system(size: 14))
                        .foregroundColor(.themeText)
                    Spacer()
                }
                .padding(10)
                .background(Color.themeCard)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.themeBorder, lineWidth: 1)
                )
            }

            Button(action: {
                viewModel.saveFeeSettings(feeRate: feeRate / 10000, feeMin: feeMin)
                dismiss()
            }) {
                Text("保存设置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.themeAccent)
                    .cornerRadius(10)
            }
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10)
            .background(Color.themeCard2)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.themeBorder, lineWidth: 1)
            )
    }
}
