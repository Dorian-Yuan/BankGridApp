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
                        Text("成交价（系统现价: ¥\(rtp > 0 ? rtp.toFixed(3) : "--")）")
                            .font(.system(size: 13))
                            .foregroundColor(.themeText2)
                        TextField("", value: $tradePrice, format: .number.precision(.fractional(3)))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("成交股数（策略建议 \(suggestedShares)股）")
                            .font(.system(size: 13))
                            .foregroundColor(.themeText2)
                        TextField("", value: $tradeShares, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("代扣红利税 (元，若有)")
                            .font(.system(size: 13))
                            .foregroundColor(.themeText2)
                        TextField("0", value: $divTax, format: .number.precision(.fractional(2)))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    tradePreviewCard

                    if side == "sell" {
                        Button(action: executeSell) {
                            Text("确认卖出并更新P点")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.themeRed.opacity(0.85))
                                .cornerRadius(10)
                        }
                    } else {
                        Button(action: executeBuy) {
                            Text("确认买入并更新P点")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.themeGreen.opacity(0.85))
                                .cornerRadius(10)
                        }
                    }

                    Button(action: { dismiss() }) {
                        Text("取消")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.themeAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.themeAccent.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
                .padding(20)
            }
            .background(Color.themeBg)
            .navigationTitle("\(side == "sell" ? "卖出" : "买入") \(position.name ?? "")")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            let trigP = side == "sell"
                ? calculator.sellPrice(basePrice: position.basePrice)
                : calculator.buyPrice(basePrice: position.basePrice)
            tradePrice = rtp > 0 ? rtp : trigP
            tradeShares = suggestedShares
        }
    }

    private var tradePreviewCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(side == "sell" ? "实收" : "实付")：¥\(netAmount.toFixed(2))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.themeText)

            HStack(spacing: 0) {
                Text("预估费用(¥\(totalFee.toFixed(2)))：佣金¥\(feeDetail.comm.toFixed(2)) / 过户费¥\(feeDetail.transfer.toFixed(3))")
                if side == "sell" {
                    Text(" / 印花税¥\(feeDetail.stamp.toFixed(2))")
                }
                if divTax > 0 {
                    Text(" / 红利税¥\(divTax.toFixed(2))")
                }
            }
            .font(.system(size: 11))
            .foregroundColor(.themeText2)
            .padding(8)
            .background(Color.themeAccent.opacity(0.05))
            .cornerRadius(6)

            Text("交易后持仓：\(newShares)股")
                .font(.system(size: 13))
                .foregroundColor(.themeText)

            HStack(spacing: 4) {
                Text("新基准价 P 更新为：")
                    .font(.system(size: 13))
                    .foregroundColor(.themeText2)
                Text("¥\(tradePrice.toFixed(3))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.themeAccent)
            }
        }
        .padding(12)
        .background(Color.themeCard2)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.themeBorder, lineWidth: 1)
        )
    }

    private func executeSell() {
        guard tradePrice > 0, tradeShares > 0 else { return }
        guard tradeShares <= Int(position.shares) else { return }

        let execShares = calculator.roundLot(tradeShares)
        let amount = tradePrice * Double(execShares)
        let fee = totalFee

        position.shares -= Int32(execShares)
        position.basePrice = tradePrice
        appData.netCashFlow += (amount - fee)
        persistence.save()
        persistence.addTradeLog(
            action: "网格卖出",
            bank: position.name ?? "",
            price: tradePrice,
            shares: Int32(execShares),
            amount: amount,
            fee: fee,
            divTax: divTax,
            newBase: tradePrice,
            remainShares: position.shares
        )
        onCompleted()
        dismiss()
    }

    private func executeBuy() {
        guard tradePrice > 0, tradeShares > 0 else { return }

        let execShares = calculator.roundLot(tradeShares)
        let amount = tradePrice * Double(execShares)
        let fee = totalFee

        position.shares += Int32(execShares)
        position.basePrice = tradePrice
        appData.netCashFlow -= (amount + fee)
        persistence.save()
        persistence.addTradeLog(
            action: "网格买入",
            bank: position.name ?? "",
            price: tradePrice,
            shares: Int32(execShares),
            amount: amount,
            fee: fee,
            newBase: tradePrice,
            totalShares: position.shares
        )
        onCompleted()
        dismiss()
    }
}
