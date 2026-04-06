import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var leftText = ""
    @State private var rightText = ""
    @State private var diffResult: DiffResult?
    @State private var showingDiff = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)

            Divider()

            if showingDiff, let result = diffResult {
                diffView(result: result)
            } else {
                inputView
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("DiffBuddy")
                .font(.headline)

            Spacer()

            if showingDiff {
                Button("戻る") {
                    showingDiff = false
                }
                .keyboardShortcut(.escape)
            } else {
                HStack(spacing: 12) {
                    Button("ファイルを開く（左）") { pickFile(side: .left) }
                    Button("ファイルを開く（右）") { pickFile(side: .right) }

                    Button("クリア") {
                        leftText = ""
                        rightText = ""
                    }
                    .disabled(leftText.isEmpty && rightText.isEmpty)

                    Button("比較する") {
                        diffResult = DiffEngine.diff(old: leftText, new: rightText)
                        showingDiff = true
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(leftText.isEmpty && rightText.isEmpty)
                }
            }
        }
    }

    // MARK: - Input View (text entry + paste + file drop)

    private var inputView: some View {
        HSplitView {
            editorPane(title: "変更前", text: $leftText, side: .left)
            editorPane(title: "変更後", text: $rightText, side: .right)
        }
    }

    private enum Side { case left, right }

    private func editorPane(title: String, text: Binding<String>, side: Side) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ZStack {
                TextEditor(text: text)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)

                // Placeholder
                if text.wrappedValue.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 32))
                        Text("テキストを入力・ペースト\nまたはファイルをドロップ")
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.tertiary)
                    .allowsHitTesting(false)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers, side: side)
                return true
            }
        }
    }

    private func pickFile(side: Side) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                if side == .left { leftText = content } else { rightText = content }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider], side: Side) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  let content = try? String(contentsOf: url, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                if side == .left { leftText = content } else { rightText = content }
            }
        }
    }

    // MARK: - Diff View

    private func diffView(result: DiffResult) -> some View {
        HSplitView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(result.left) { line in
                        DiffLineView(line: line)
                    }
                }
                .padding(.vertical, 4)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(result.right) { line in
                        DiffLineView(line: line)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
