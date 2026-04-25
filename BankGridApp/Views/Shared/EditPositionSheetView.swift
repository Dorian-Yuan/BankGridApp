import SwiftUI

struct EditPositionSheetView: View {
    let position: Position
    let calculator: GridCalculator
    let appData: AppData
    let persistence: DataPersistence
    let onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var shares: Int = 0
    @State private var basePrice: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(position.name ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(.themeText2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("持仓股数")
                            .font(.system(size: 13))
                            .foregroundColor(.themeText2)
                        TextField("", value: $shares, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("基准价 P")
                            .font(.system(size: 13))
                            .foregroundColor(.themeText2)
                        TextField("", value: $basePrice, format: .number.precision(.fractional(3)))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    Button(action: executeEdit) {
                        Text("保存修正")
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
            .navigationTitle("编辑持仓")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            shares = Int(position.shares)
            basePrice = position.basePrice
        }
    }

    private func executeEdit() {
        let roundedShares = calculator.roundLot(shares)
        let diffShares = roundedShares - Int(position.shares)
        appData.netCashFlow -= Double(diffShares) * (basePrice > 0 ? basePrice : position.basePrice)
        position.shares = Int32(roundedShares)
        if basePrice > 0 {
            position.basePrice = basePrice
        }
        persistence.save()
        persistence.addTradeLog(
            action: "手动编辑",
            bank: position.name ?? "",
            shares: Int32(roundedShares),
            newBase: position.basePrice
        )
        onCompleted()
        dismiss()
    }
}
