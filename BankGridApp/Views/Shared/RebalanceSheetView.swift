import SwiftUI

struct RebalanceSheetView: View {
    let positions: [Position]
    let calculator: GridCalculator
    let priceService: PriceService
    let persistence: DataPersistence
    let appData: AppData
    let onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var remainCash: Double = 0
    @State private var extraCash: Double = 0
    @State private var manualPrices: [String: Double] = [:]
    @State private var fetchedPrices: [String: Double] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("账户剩余资金（元）")
                            .font(.system(size: 13))
                            .foregroundColor(.themeText2)
                        TextField("", value: $remainCash, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("额外注入资金（元）")
                            .font(.system(size: 13))
                            .foregroundColor(.themeText2)
                        TextField("", value: $extraCash, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    ForEach(positions, id: \.code) { pos in
                        if let code = pos.code {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(pos.name ?? code) 收盘价")
                                    .font(.system(size: 13))
                                    .foregroundColor(.themeText2)
                                TextField("收盘价", value: bindingFor(code: code), format: .number.precision(.fractionLength(3)))
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                        }
                    }

                    Button(action: executeRebalance) {
                        Text("确认平准")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.themeAccent)
                            .cornerRadius(10)
                    }
                }
                .padding(20)
            }
            .background(Color.themeBg)
            .navigationTitle("月度平准")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear {
            for pos in positions {
                if let code = pos.code {
                    fetchedPrices[code] = priceService.price(for: code)
                }
            }
        }
    }

    private func bindingFor(code: String) -> Binding<Double> {
        Binding(
            get: { manualPrices[code] ?? 0 },
            set: { manualPrices[code] = $0 }
        )
    }

    @MainActor
    private func executeRebalance() {
        var prices: [String: Double] = [:]
        for pos in positions {
            if let code = pos.code {
                let mp = manualPrices[code] ?? 0
                prices[code] = mp > 0 ? mp : (fetchedPrices[code] ?? 0)
            }
        }

        let toolsVM = ToolsViewModel(
            appData: appData,
            persistence: persistence,
            priceService: priceService
        )
        toolsVM.calculateRebalance(remainCash: remainCash, extraCash: extraCash, prices: prices)
        if toolsVM.rebalancePreview != nil {
            toolsVM.executeRebalance(prices: prices, remainCash: remainCash, extraCash: extraCash)
        }

        onCompleted()
        dismiss()
    }
}
