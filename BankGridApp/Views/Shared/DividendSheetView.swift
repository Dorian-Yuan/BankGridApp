import SwiftUI

struct DividendSheetView: View {
    let position: Position
    let calculator: GridCalculator
    let persistence: DataPersistence
    let appData: AppData
    let onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var dividendPerShare: Double = 0

    private var divAmount: Double {
        dividendPerShare * Double(position.shares)
    }

    private var newBase: Double {
        position.basePrice - dividendPerShare
    }

    private var divTax: Double {
        calculator.calcDivTax(dividendPerShare: dividendPerShare, shares: Int(position.shares))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("每股分红（元）")
                            .font(.system(size: 13))
                            .foregroundColor(.themeText2)
                        TextField("例: 0.175", value: $dividendPerShare, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    dividendPreviewCard

                    Button(action: executeDividend) {
                        Text("确认除息")
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
            .navigationTitle("除息调整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var dividendPreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("除息预览")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.themeText)

            HStack {
                Text("分红总额")
                    .foregroundColor(.themeText2)
                Spacer()
                Text("¥\(String(format: "%.2f", divAmount))")
                    .foregroundColor(.themeText)
            }

            HStack {
                Text("红利税")
                    .foregroundColor(.themeText2)
                Spacer()
                Text("¥\(String(format: "%.2f", divTax))")
                    .foregroundColor(.themeText)
            }

            HStack {
                Text("净分红")
                    .foregroundColor(.themeText2)
                Spacer()
                Text("¥\(String(format: "%.2f", divAmount - divTax))")
                    .foregroundColor(.green)
            }

            Divider()

            HStack {
                Text("旧基准价")
                    .foregroundColor(.themeText2)
                Spacer()
                Text("¥\(String(format: "%.3f", position.basePrice))")
                    .foregroundColor(.themeText)
            }

            HStack {
                Text("新基准价")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.themeText)
                Spacer()
                Text("¥\(String(format: "%.3f", newBase))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.themeAccent)
            }
        }
        .padding(12)
        .background(Color.themeCard)
        .cornerRadius(10)
    }

    private func executeDividend() {
        guard dividendPerShare > 0 else { return }

        let oldBase = position.basePrice
        position.basePrice = newBase

        persistence.addTradeLog(
            action: "除息调整",
            bank: position.name ?? "",
            price: dividendPerShare,
            shares: position.shares,
            amount: divAmount,
            dividend: dividendPerShare,
            divTax: divTax,
            oldBase: oldBase,
            newBase: newBase,
            remainShares: position.shares,
            totalShares: position.shares,
            totalValue: Double(position.shares) * newBase
        )

        persistence.save()
        onCompleted()
        dismiss()
    }
}
