import SwiftUI

struct TradeSheetView: View {
    let side: String
    let position: Position
    let calculator: GridCalculator
    let priceService: PriceService
    let appData: AppData
    let persistence: DataPersistence
    let onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tradePrice: Double = 0
    @State private var tradeShares: Int = 0
    @State private var divTax: Double = 0

    @MainActor
    private var rtp: Double {
        priceService.price(for: position.code ?? "")
    }

    private var suggestedShares: Int {
        calculator.calcGridShares(currentShares: Int(position.shares))
    }

    private var amount: Double {
        tradePrice * Double(tradeShares)
    }

    private var feeDetail: (comm: Double, transfer: Double, stamp: Double, total: Double) {
        guard tradePrice > 0, tradeShares > 0 else {
            return (0, 0, 0, 0)
        }
        return calculator.calcFeeDetail(amount: amount, side: side)
    }

    private var totalFee: Double {
        feeDetail.total + divTax
    }

    private var netAmount: Double {
        side == "sell" ? amount - totalFee : amount + totalFee
    }

    private var newShares: Int {
        side == "sell" ? Int(position.shares) - tradeShares : Int(position.shares) + tradeShares
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("成交价（系统现价: ¥\(rtp > 0 ? String(format: "%.3f", rtp) : "--")）")
                            .font(.system(size: 13))
                            .foregroundColor(.themeText2)
                        TextField("", value: $tradePrice, format: .number.precision(.fractionLength(3)))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("成交股数（策略建议\(suggestedShares)股）")
                            .font(.system(size: 13))
                            .foregroundColor(.themeText2)
                        TextField("", value: $tradeShares, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("代扣红利税（元，若有）")
                            .font(.system(size: 13))
                            .foregroundColor(.themeText2)
                        TextField("0", value: $divTax, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    tradePreviewCard

                    Button(action: executeTrade) {
                        Text(side == "sell" ? "确认卖出" : "确认买入")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(side == "sell" ? Color.red.opacity(0.8) : Color.themeAccent)
                            .cornerRadius(10)
                    }
                }
                .padding(20)
            }
            .background(Color.themeBg)
            .navigationTitle(side == "sell" ? "网格卖出" : "网格买入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear {
            tradePrice = rtp
            tradeShares = suggestedShares
        }
    }

    private var tradePreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("交易预览")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.themeText)

            HStack {
                Text("成交金额")
                    .foregroundColor(.themeText2)
                Spacer()
                Text("¥\(String(format: "%.2f", amount))")
                    .foregroundColor(.themeText)
            }

            HStack {
                Text("佣金")
                    .foregroundColor(.themeText2)
                Spacer()
                Text("¥\(String(format: "%.2f", feeDetail.comm))")
                    .foregroundColor(.themeText)
            }

            HStack {
                Text("过户费")
                    .foregroundColor(.themeText2)
                Spacer()
                Text("¥\(String(format: "%.2f", feeDetail.transfer))")
                    .foregroundColor(.themeText)
            }

            if side == "sell" {
                HStack {
                    Text("印花税")
                        .foregroundColor(.themeText2)
                    Spacer()
                    Text("¥\(String(format: "%.2f", feeDetail.stamp))")
                        .foregroundColor(.themeText)
                }
            }

            if divTax > 0 {
                HStack {
                    Text("红利税")
                        .foregroundColor(.themeText2)
                    Spacer()
                    Text("¥\(String(format: "%.2f", divTax))")
                        .foregroundColor(.themeText)
                }
            }

            Divider()

            HStack {
                Text("总费用")
                    .foregroundColor(.themeText2)
                Spacer()
                Text("¥\(String(format: "%.2f", totalFee))")
                    .foregroundColor(.themeText)
            }

            HStack {
                Text(side == "sell" ? "净收入" : "净支出")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.themeText)
                Spacer()
                Text("¥\(String(format: "%.2f", netAmount))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(side == "sell" ? .green : .red)
            }
        }
        .padding(12)
        .background(Color.themeCard)
        .cornerRadius(10)
    }

    private func executeTrade() {
        guard tradePrice > 0, tradeShares > 0 else { return }

        let oldBase = position.basePrice
        let newBase = tradePrice

        if side == "sell" {
            position.shares -= Int32(tradeShares)
        } else {
            position.shares += Int32(tradeShares)
        }
        position.basePrice = newBase

        persistence.addTradeLog(
            action: side == "sell" ? "网格卖出" : "网格买入",
            bank: position.name ?? "",
            price: tradePrice,
            shares: Int32(tradeShares),
            amount: amount,
            fee: totalFee,
            divTax: divTax,
            oldBase: oldBase,
            newBase: newBase,
            remainShares: position.shares,
            totalShares: position.shares,
            totalValue: Double(position.shares) * tradePrice
        )

        persistence.save()
        onCompleted()
        dismiss()
    }
}
