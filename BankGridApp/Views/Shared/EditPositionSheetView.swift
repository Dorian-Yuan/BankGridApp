import SwiftUI

struct EditPositionSheetView: View {
    let position: Position
    let persistence: DataPersistence
    let onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var basePrice: Double = 0
    @State private var shares: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("基准价")
                        .font(.system(size: 13))
                        .foregroundColor(.themeText2)
                    TextField("", value: $basePrice, format: .number.precision(.fractionLength(3)))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(CustomTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("持仓股数")
                        .font(.system(size: 13))
                        .foregroundColor(.themeText2)
                    TextField("", value: $shares, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(CustomTextFieldStyle())
                }

                Button(action: saveChanges) {
                    Text("保存修改")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.themeAccent)
                        .cornerRadius(10)
                }
            }
            .padding(20)
            .background(Color.themeBg)
            .navigationTitle("编辑持仓")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear {
            basePrice = position.basePrice
            shares = Int(position.shares)
        }
    }

    private func saveChanges() {
        position.basePrice = basePrice
        position.shares = Int32(shares)
        persistence.save()
        onCompleted()
        dismiss()
    }
}
