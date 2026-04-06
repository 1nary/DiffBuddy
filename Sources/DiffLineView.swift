import SwiftUI

struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            // Line number
            Text(line.lineNumber.map { String($0) } ?? "")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)

            // Content
            Text(line.text.isEmpty ? " " : line.text)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
        }
        .background(backgroundColor)
    }

    private var backgroundColor: Color {
        switch line.type {
        case .same: return .clear
        case .added: return Color.green.opacity(0.15)
        case .removed: return Color.red.opacity(0.15)
        }
    }
}
