import SwiftUI

struct InitPositionView: View {
    let banks: [BankInfo]
    let persistence: DataPersistence
    let appData: AppData
    let onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var prices: [String: Double] = [:]
    @State private var shares: [String: Int] = [:]
    @State private var initCapital: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("初始资金（元）")
                            .font(.system(size: 13))
                            .foregroundColor(.themeText2)
                        TextField("留空则不记录", text: $initCapital)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    ForEach(banks, id: \.code) { bank in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(bank.name) 收盘价 / 股数")
                                .font(.system(size: 13))
                                .foregroundColor(.themeText2)
                            HStack(spacing: 12) {
                                TextField("收盘价", value: bindingFor(code: bank.code), format: .number.precision(.fractionLength(3)))
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(CustomTextFieldStyle())
                                TextField("股数", value: bindingForShares(code: bank.code), format: .number)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                        }
                    }

                    Button(action: savePositions) {
                        Text("确认建仓")
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
            .navigationTitle("初始建仓")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func bindingFor(code: String) -> Binding<Double> {
        Binding(
            get: { prices[code] ?? 0 },
            set: { prices[code] = $0 }
        )
    }

    private func bindingForShares(code: String) -> Binding<Int> {
        Binding(
            get: { shares[code] ?? 0 },
            set: { shares[code] = $0 }
        )
    }

    @MainActor
    private func savePositions() {
        if let capital = Double(initCapital) {
            appData.initCapital = capital
            appData.netCashFlow = -capital
        }

        for bank in banks {
            let price = prices[bank.code] ?? 0
            let shareCount = shares[bank.code] ?? 0
            guard price > 0, shareCount > 0 else { continue }

            let totalCost = price * Double(shareCount)
            persistence.addPosition(
                code: bank.code,
                name: bank.name,
                short: bank.short,
                shares: Int32(shareCount),
                basePrice: price,
                avgCost: price,
                totalCost: totalCost
            )

            persistence.addTradeLog(
                action: "初始建仓",
                bank: bank.name,
                price: price,
                shares: Int32(shareCount),
                amount: totalCost,
                oldBase: price,
                newBase: price,
                remainShares: Int32(shareCount),
                totalShares: Int32(shareCount),
                totalValue: totalCost
            )
        }

        persistence.save()
        onCompleted()
        dismiss()
    }
}
