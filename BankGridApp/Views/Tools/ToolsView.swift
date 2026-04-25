import SwiftUI

struct ToolsView: View {
    @ObservedObject var viewModel: ToolsViewModel
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    toolCard(icon: "🎛️", title: "通用设置", subtitle: "主题外观与刷新频率") {
                        viewModel.settingsType = .general
                        viewModel.showSettingsSheet = true
                    }

                    toolCard(icon: "⚙️", title: "网格与仓位设置", subtitle: "自定义买卖点、单次仓位") {
                        viewModel.settingsType = .grid
                        viewModel.showSettingsSheet = true
                    }

                    toolCard(icon: "💰", title: "交易手续费设置", subtitle: "佣金、过户费与印花税详情") {
                        viewModel.settingsType = .fees
                        viewModel.showSettingsSheet = true
                    }

                    toolCard(icon: "📊", title: "网格利润拆解", subtitle: "网格利差/分红/浮盈三分离") {
                        viewModel.calculateProfitBreakdown()
                        viewModel.showProfitBreakdown = true
                    }

                    toolCard(icon: "⚖️", title: "月度平准再平衡", subtitle: "资金归齐与仓位内部重分配") {
                        viewModel.showRebalance = true
                    }

                    toolCard(icon: "🗑️", title: "重置所有数据(自动备份)", subtitle: "清除持仓与日志并在云端保存存档", isDanger: true) {
                        viewModel.confirmReset()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .background(Color.themeBg)
            .navigationTitle("工具")
            .sheet(isPresented: $viewModel.showSettingsSheet) {
                SettingsSheetView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showProfitBreakdown) {
                ProfitBreakdownView(breakdown: viewModel.profitBreakdown)
            }
            .sheet(isPresented: $viewModel.showRebalance) {
                RebalanceSheetView(viewModel: viewModel)
            }
            .alert("⚠️ 警告", isPresented: $viewModel.showResetConfirmation) {
                if viewModel.resetStep == 1 {
                    Button("确认继续", role: .destructive) {
                        viewModel.nextResetStep()
                        viewModel.showResetConfirmation = true
                    }
                    Button("取消", role: .cancel) {
                        viewModel.cancelReset()
                    }
                } else if viewModel.resetStep == 2 {
                    Button("确认重置", role: .destructive) {
                        viewModel.executeReset()
                    }
                    Button("取消", role: .cancel) {
                        viewModel.cancelReset()
                    }
                }
            } message: {
                if viewModel.resetStep == 1 {
                    Text("确定要重置并清除所有历史记录吗？\n\n备份机制：\n为防止误操作，当前持仓和日志数据将自动按时间戳打包备份到本地云盘中。")
                } else {
                    Text("当前面板的所有数据即将清零。确定执行重置与备份吗？")
                }
            }
            .overlay {
                if viewModel.showToast, let msg = viewModel.toastMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.themeAccent)
                            .cornerRadius(20)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.bottom, 100)
                    }
                    .animation(.easeInOut, value: viewModel.showToast)
                }
            }
        }
    }

    private func toolCard(icon: String, title: String, subtitle: String, isDanger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isDanger ? .themeRed : .themeText)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.themeText2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.themeText2)
            }
            .padding(14)
            .background(Color.themeCard)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.themeBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
