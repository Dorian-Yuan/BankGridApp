import SwiftUI

struct RebalanceSheetView: View {
    @ObservedObject var viewModel: ToolsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var remainCash: Double = 0
    @State private var extraCash: Double = 0
    @State private var bankPrices: [String: Double] = [:]
    @State private var confirmStep = 0

    private var positions: [Position] {
        viewModel.persistence.fetchPositions()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("系统将根据现价和持仓计算总估值，并结合可用资金给出平分调整参考。")
                        .font(.system(size: 13))
                        .foregroundColor(.themeText2)
                    + Text("\n资金不足时将自动缩减买入量，不会凭空加仓。")
                        .font(.system(size: 13))
                        .foregroundColor(.themeAccent)

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("账户剩余资金(¥)")
                                .font(.system(size: 13))
                                .foregroundColor(.themeText)
                            TextField("0", value: $remainCash, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: remainCash) { _ in updatePreview() }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("追加投入资金(¥)")
                                .font(.system(size: 13))
                                .foregroundColor(.themeText)
                            TextField("0", value: $extraCash, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: extraCash) { _ in updatePreview() }
                        }
                    }

                    if let preview = viewModel.rebalancePreview {
                        previewSection(preview)
                    }

                    ForEach(positions, id: \.code) { pos in
                        let code = pos.code ?? ""
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(pos.name ?? "")
                                    .font(.system(size: 13))
                                    .foregroundColor(.themeText)
                                Spacer()
                                Text("当前基准价 P=¥\(pos.basePrice.toFixed(3))")
                                    .font(.system(size: 13))
                                    .foregroundColor(.themeAccent)
                            }
                            TextField("收盘价", value: bindingFor(code: code), format: .number.precision(.fractional(3)))
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: bankPrices[code]) { _ in updatePreview() }
                        }
                    }

                    if confirmStep == 0 {
                        Button(action: {
                            updatePreview()
                            confirmStep = 1
                        }) {
                            Text("预执行平准")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.themeAccent)
                                .cornerRadius(10)
                        }
                    } else {
                        Button(action: {
                            viewModel.executeRebalance(
                                prices: bankPrices,
                                remainCash: remainCash,
                                extraCash: extraCash
                            )
                            dismiss()
                        }) {
                            Text("⚠️ 二次确认：执行平准并重置基准价 P")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.themeRed.opacity(0.85))
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
            .navigationTitle("月度平准再平衡")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            initializePrices()
        }
    }

    private func bindingFor(code: String) -> Binding<Double> {
        Binding(
            get: { bankPrices[code] ?? 0 },
            set: { bankPrices[code] = $0 }
        )
    }

    private func initializePrices() {
        for pos in positions {
            let code = pos.code ?? ""
            let rtp = viewModel.priceService.price(for: code)
            bankPrices[code] = rtp > 0 ? rtp : pos.basePrice
        }
        updatePreview()
    }

    private func updatePreview() {
        viewModel.calculateRebalance(
            remainCash: remainCash,
            extraCash: extraCash,
            prices: bankPrices
        )
    }

    private func previewSection(_ preview: RebalancePreview) -> some View {
        VStack(spacing: 10) {
            Text("平分总资金池: ¥\(preview.totalPool.toFixed(2))")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.themeText)
                .frame(maxWidth: .infinity)

            if !preview.warning.isEmpty {
                Text(preview.warning)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(preview.warning.hasPrefix("❌") ? .themeRed : .themeYellow)
            }

            HStack(spacing: 8) {
                miniStat(title: "可用资金", value: "¥\(Int(preview.availableCash))", color: .themeText)
                miniStat(title: "需买入", value: "¥\(Int(preview.buyNeed))", color: .themeGreen)
                miniStat(title: "卖出释放", value: "¥\(Int(preview.sellRelease))", color: .themeRed)
            }

            ForEach(positions, id: \.code) { pos in
                let code = pos.code ?? ""
                let diff = preview.deltas[code] ?? 0
                let ts = preview.targetShares[code] ?? Int(pos.shares)
                HStack {
                    Text(pos.name ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.themeText)
                    Spacer()
                    Text("\(pos.shares)股 →")
                        .font(.system(size: 13))
                        .foregroundColor(.themeText2)
                    Text("\(ts)股")
                        .font(.system(size: 13))
                        .foregroundColor(.themeText)
                    Text("(\(diff > 0 ? "+" : "")\(diff))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(diff > 0 ? .themeGreen : (diff < 0 ? .themeRed : .themeText2))
                }
            }

            HStack {
                Spacer()
                Text("平分目标单仓: ¥\(preview.target.toFixed(2))")
                    .font(.system(size: 11))
                    .foregroundColor(.themeText2)
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

    private func miniStat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.themeText2)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.themeCard)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.themeBorder, lineWidth: 1)
        )
    }
}
