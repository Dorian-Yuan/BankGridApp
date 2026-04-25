import SwiftUI

struct InitPositionView: View {
    let calculator: GridCalculator
    let appData: AppData
    let persistence: DataPersistence
    let priceService: PriceService
    let onCompleted: () -> Void

    @State private var totalCapital: Double = 30000
    @State private var bankPrices: [String: Double] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("首次建仓")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.themeText)

                Text("系统将根据您填写的预算和实际股数，计算出真实建仓成本作为初始资金流水。")
                    .font(.system(size: 13))
                    .foregroundColor(.themeText2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("预算投入总金 (¥)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.themeText2)
                    TextField("例如：30000", value: $totalCapital, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                .padding(14)
                .background(Color.themeCard)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.themeBorder, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("设定建仓基准价（已拉取现价）")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.themeText2)

                    ForEach(BANKS) { bank in
                        HStack(spacing: 12) {
                            Text(bank.short)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.themeText)
                                .frame(minWidth: 40, alignment: .leading)

                            TextField("留空则不建仓", value: bindingFor(code: bank.code), format: .number.precision(.fractional(3)))
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                    }
                }
                .padding(14)
                .background(Color.themeCard)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.themeBorder, lineWidth: 1)
                )

                Button(action: executeInit) {
                    Text("确认按照当前金额建仓")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.themeAccent)
                        .cornerRadius(12)
                }
            }
            .padding(16)
        }
        .background(Color.themeBg)
        .onAppear {
            for bank in BANKS {
                let rtp = priceService.price(for: bank.code)
                bankPrices[bank.code] = rtp > 0 ? rtp : 0
            }
        }
    }

    private func bindingFor(code: String) -> Binding<Double> {
        Binding(
            get: { bankPrices[code] ?? 0 },
            set: { bankPrices[code] = $0 }
        )
    }

    private func executeInit() {
        guard totalCapital > 0 else { return }

        let banks = BANKS.filter { (bankPrices[$0.code] ?? 0) > 0 }
        guard !banks.isEmpty else { return }

        let portionSize = totalCapital / Double(banks.count)
        var totalCost: Double = 0

        for bank in banks {
            let price = bankPrices[bank.code] ?? 0
            guard price > 0 else { continue }

            let shares = calculator.calcInitShares(price: price, budget: portionSize)
            let cost = Double(shares) * price
            let fee = calculator.calcFee(amount: cost, side: "buy")

            let _ = persistence.createPosition(
                code: bank.code,
                name: bank.name,
                short: bank.short,
                shares: Int32(shares),
                basePrice: price,
                avgCost: price,
                totalCost: cost + fee
            )

            persistence.addTradeLog(
                action: "建仓",
                bank: bank.name,
                price: price,
                shares: Int32(shares),
                amount: cost,
                fee: fee
            )

            totalCost += cost + fee
        }

        appData.netCashFlow = -totalCost
        appData.initCapital = totalCost
        onCompleted()
    }
}
