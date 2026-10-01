import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject private var controller: TransposeController
    @State private var flash = false

    var body: some View {
        HStack(spacing: 6) {
            StatusIndicator(status: controller.status, flash: flash)
            Spacer()
            Text("Base: \(controller.baseKeyName)")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .onChange(of: controller.status) { _, status in
            guard case .sent = status else { return }
            flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) { flash = false }
            }
        }
    }
}

private struct StatusIndicator: View {
    let status: SendStatus
    var flash = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .scaleEffect(flash ? 1.6 : 1)
            Text(text)
                .foregroundStyle(status.isFailure ? .red : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(text)
        }
    }

    private var color: Color {
        switch status {
        case .sent: .green
        case .failed: .red
        case .noDestination, .idle: .gray
        }
    }

    private var text: String {
        switch status {
        case .idle: "待機中"
        case .sent(let date): "Sent \(date.formatted(date: .omitted, time: .standard))"
        case .failed(let message): "送信失敗: \(message)"
        case .noDestination: "未接続"
        }
    }
}

private extension SendStatus {
    var isFailure: Bool {
        if case .failed = self { true } else { false }
    }
}
