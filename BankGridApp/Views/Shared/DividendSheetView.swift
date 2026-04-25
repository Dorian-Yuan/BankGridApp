import SwiftUI

struct DividendSheetView: View {
    let position: Position
    let appData: AppData
    let persistence: DataPersistence
    let onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var dividendPerShare: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(position.name ?? "") · P=¥\(position.basePrice.toFixed(3))")
                        .font(.system(size: 14))
                        .foregroundColor(.themeText2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("每股分红（元）")
                            .font(.system(size: 13))
                            .foregroundColor(.themeText2)
                        TextField("例: 0.175", value: $dividendPerShare, format: .number.precision(.fractional(2)))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    if dividendPerShare > 0 {
                        let divAmount = dividendPerShare * Double(position.shares)
                        let newBase = position.basePrice - dividendPerShare
                        VStack(alignment: .leading, spacing: 6) {
                            Text("分红总额：¥\(divAmount.toFixed(2))")
                                .font(.system(size: 13))
                                .foregroundColor(.themeText)
                            Text("新基准价 P：¥\(newBase.toFixed(3))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.themeAccent)
                        }
                        .padding(12)
                        .background(Color.themeCard2)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.themeBorder, lineWidth: 1)
                        )
                    }

                    Button(action: executeDividend) {
                        Text("确认调整基准价 P")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.themeAccent)
                            .cornerRadius(10)
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
            .navigationTitle("除息调整")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func executeDividend() {
        guard dividendPerShare > 0 else { return }

        let oldBase = position.basePrice
        let divAmount = dividendPerShare * Double(position.shares)
        position.basePrice -= dividendPerShare
        appData.netCashFlow += divAmount
        persistence.save()
        persistence.addTradeLog(
            action: "除息调整",
            bank: position.name ?? "",
            dividend: dividendPerShare,
            amount: divAmount,
            oldBase: oldBase,
            newBase: position.basePrice
        )
        onCompleted()
        dismiss()
    }
}
