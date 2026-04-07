// Render App Store screenshots without launching the app or needing
// accessibility/screen-recording permission. Uses SwiftUI ImageRenderer.
//
// usage: swift scripts/render_screenshots.swift
//
// Output:
//   dist/screenshots/02_diff_1440x900.png

import SwiftUI
import AppKit

// MARK: - Sample data (visually mirrors real DiffEngine output)

enum LineKind { case same, added, removed, blank }

struct Row: Identifiable {
    let id = UUID()
    let num: Int?
    let text: String
    let kind: LineKind
}

let leftRows: [Row] = [
    Row(num: 1, text: "function greet(name) {",                  kind: .same),
    Row(num: 2, text: #"  console.log("Hello, " + name);"#,      kind: .removed),
    Row(num: 3, text: "  return true;",                          kind: .removed),
    Row(num: 4, text: "}",                                        kind: .same),
    Row(num: 5, text: "",                                         kind: .same),
    Row(num: 6, text: #"greet("world");"#,                        kind: .removed),
]

let rightRows: [Row] = [
    Row(num: 1, text: "function greet(name) {",                  kind: .same),
    Row(num: 2, text: #"  console.log(`Hello, ${name}!`);"#,     kind: .added),
    Row(num: 3, text: "  return { ok: true };",                  kind: .added),
    Row(num: 4, text: "}",                                        kind: .same),
    Row(num: 5, text: "",                                         kind: .same),
    Row(num: 6, text: #"greet("DiffBuddy");"#,                    kind: .added),
]

// MARK: - Visual constants matching DiffBuddy

let addedBg   = Color(red: 0.18, green: 0.75, blue: 0.30).opacity(0.30)
let removedBg = Color(red: 0.85, green: 0.20, blue: 0.20).opacity(0.30)
let addedBar  = Color.green.opacity(0.8)
let removedBar = Color.red.opacity(0.8)

// MARK: - Views

struct DiffRowView: View {
    let row: Row
    var body: some View {
        HStack(spacing: 8) {
            Text(row.num.map { "\($0)" } ?? "")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
            Text(row.text.isEmpty ? " " : row.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .frame(height: 20)
        .background(bg)
    }
    var bg: Color {
        switch row.kind {
        case .added:   return addedBg
        case .removed: return removedBg
        default:       return .clear
        }
    }
}

struct DiffPane: View {
    let title: String
    let rows: [Row]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            VStack(spacing: 0) {
                ForEach(rows) { DiffRowView(row: $0) }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct IndicatorBar: View {
    var body: some View {
        GeometryReader { geo in
            let n = leftRows.count
            ZStack(alignment: .top) {
                Rectangle().fill(Color.gray.opacity(0.15))
                ForEach(0..<n, id: \.self) { i in
                    let l = leftRows[i].kind, r = rightRows[i].kind
                    let kind: LineKind? = (l != .same) ? l : (r != .same ? r : nil)
                    if let kind = kind {
                        Rectangle()
                            .fill(kind == .added ? addedBar : removedBar)
                            .frame(height: max(2, geo.size.height / CGFloat(n)))
                            .offset(y: (CGFloat(i) / CGFloat(n)) * geo.size.height)
                    }
                }
            }
        }
        .frame(width: 12)
    }
}

struct Toolbar: View {
    let showingDiff: Bool
    var body: some View {
        HStack {
            Text("DiffBuddy").font(.headline)
            Spacer()
            if showingDiff {
                Button("戻る") {}
                    .buttonStyle(.bordered)
            } else {
                HStack(spacing: 12) {
                    Button("ファイルを開く（左）") {}
                    Button("ファイルを開く（右）") {}
                    Button("クリア") {}.disabled(true)
                    Button("比較する") {}.buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

struct InputPane: View {
    let title: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            ZStack(alignment: .topLeading) {
                Color.clear
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { i, line in
                        HStack(spacing: 8) {
                            Text("\(i+1)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, alignment: .trailing)
                            Text(String(line).isEmpty ? " " : String(line))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 4)
                        .frame(height: 20)
                    }
                    Spacer(minLength: 0)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

let leftSampleText = """
function greet(name) {
  console.log("Hello, " + name);
  return true;
}

greet("world");
"""

let rightSampleText = """
function greet(name) {
  console.log(`Hello, ${name}!`);
  return { ok: true };
}

greet("DiffBuddy");
"""

struct DiffScreenshot: View {
    var body: some View {
        VStack(spacing: 0) {
            Toolbar(showingDiff: true)
            Divider()
            HStack(spacing: 0) {
                DiffPane(title: "変更前", rows: leftRows)
                IndicatorBar()
                DiffPane(title: "変更後", rows: rightRows)
            }
        }
        .frame(width: 1200, height: 760)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
    }
}

struct InputScreenshot: View {
    var body: some View {
        VStack(spacing: 0) {
            Toolbar(showingDiff: false)
            Divider()
            HStack(spacing: 0) {
                InputPane(title: "変更前", text: leftSampleText)
                Divider()
                InputPane(title: "変更後", text: rightSampleText)
            }
        }
        .frame(width: 1200, height: 760)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
    }
}

struct InputCanvas: View {
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.96, blue: 0.97)
            InputScreenshot()
        }
        .frame(width: 1440, height: 900)
    }
}

struct DiffCanvas: View {
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.96, blue: 0.97)
            DiffScreenshot()
        }
        .frame(width: 1440, height: 900)
    }
}

// MARK: - Render

@MainActor
func renderView<V: View>(_ view: V, to path: String) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0
    guard let nsImage = renderer.nsImage,
          let tiff = nsImage.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("render failed: \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    try! png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
}

@MainActor
func render() {
    let outDir = "dist/screenshots"
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    renderView(InputCanvas(), to: "\(outDir)/01_input_2880x1800.png")
    renderView(DiffCanvas(),  to: "\(outDir)/02_diff_2880x1800.png")
}

// Need a running NSApplication for ImageRenderer to work properly
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

DispatchQueue.main.async {
    render()
    exit(0)
}
app.run()
