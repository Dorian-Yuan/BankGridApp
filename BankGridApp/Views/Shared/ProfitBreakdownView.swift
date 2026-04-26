import SwiftUI

struct ProfitBreakdownView: View {
    let breakdown: ProfitBreakdown
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        breakdownCard(
                            title: "网格利差",
                            value: breakdown.gridProfit,
                            color: breakdown.gridProfit >= 0 ? .themeRed : .themeGreen
                        )
                        breakdownCard(
                            title: "分红收益",
                            value: breakdown.divProfit,
                            color: .themeAccent
                        )
                        breakdownCard(
                            title: "持仓浮盈",
                            value: breakdown.floatPnL,
                            color: breakdown.floatPnL >= 0 ? .themeRed : .themeGreen
                        )
                    }

                    VStack(spacing: 8) {
                        summaryRow(title: "合计收益", value: breakdown.totalPnL, isBold: true) {
                            breakdown.totalPnL >= 0 ? .themeRed : .themeGreen
                        }
                        summaryRow(title: "总投入成�?, value: breakdown.totalCost, isBold: false) {
                            .themeText
                        }
                        summaryRow(title: "总收益率", percentage: breakdown.totalReturnRate, isBold: false) {
                            breakdown.totalPnL >= 0 ? .themeRed : .themeGreen
                        }
                    }
                    .padding(12)
                    .background(Color.themeCard2)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.themeBorder, lineWidth: 1)
                    )

                    Button(action: { dismiss() }) {
                        Text("关闭")
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
            .navigationTitle("网格利润拆解")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func breakdownCard(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.themeText2)
            Text(value >= 0 ? "+\(value.toFixed(2))" : value.toFixed(2))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.themeCard)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.themeBorder, lineWidth: 1)
        )
    }

    private func summaryRow(title: String, value: Double, isBold: Bool, color: () -> Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.themeText2)
            Spacer()
            Text("¥\(value.toFixed(2))")
                .font(.system(size: isBold ? 15 : 13, weight: isBold ? .bold : .regular))
                .foregroundColor(color())
        }
    }

    private func summaryRow(title: String, percentage: Double, isBold: Bool, color: () -> Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.themeText2)
            Spacer()
            Text("\(percentage.toFixed(2))%")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color())
        }
    }
}

extension Double {
    func toFixed(_ fractionDigits: Int) -> String {
        String(format: "%.\(fractionDigits)f", self)
    }
}
