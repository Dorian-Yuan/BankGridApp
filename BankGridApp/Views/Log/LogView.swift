import SwiftUI

struct LogView: View {
    @ObservedObject var viewModel: LogViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.logs.isEmpty {
                    VStack {
                        Spacer()
                            .frame(height: 120)
                        Text("暂无交易记录")
                            .font(.system(size: 14))
                            .foregroundColor(.themeText2)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.logs) { log in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(log.action)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(log.color)

                                Text(log.detail)
                                    .font(.system(size: 12))
                                    .foregroundColor(.themeText2)

                                Text(log.time)
                                    .font(.system(size: 11))
                                    .foregroundColor(.themeText2)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)

                            if log.id != viewModel.logs.last?.id {
                                Divider()
                                    .background(Color.themeBorder)
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .background(Color.themeBg)
            .navigationTitle("交易日志")
            .refreshable {
                viewModel.loadLogs()
            }
        }
    }
}
