import SwiftUI
import AppKit

// VSCode-style: two independent scroll views synced via notification,
// with colored backgrounds applied as SwiftUI views (not NSView draw).

struct SyncedDiffView: View {
    let result: DiffResult
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            // Left pane
            DiffPaneView(lines: result.left, scrollOffset: $scrollOffset, isSource: true)

            // Center indicator
            DiffIndicatorBar(result: result)
                .frame(width: 12)

            // Right pane
            DiffPaneView(lines: result.right, scrollOffset: $scrollOffset, isSource: false)
        }
    }
}

// MARK: - Diff Pane (each side)

struct DiffPaneView: NSViewRepresentable {
    let lines: [DiffLine]
    @Binding var scrollOffset: CGFloat
    let isSource: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("line"))
        column.isEditable = false
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 20
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.backgroundColor = .clear
        tableView.style = .plain
        tableView.usesAutomaticRowHeights = false
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        context.coordinator.tableView = tableView
        context.coordinator.scrollView = scrollView

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.tableView?.reloadData()

        // Sync scroll position from the other pane
        if !context.coordinator.isScrolling {
            let currentY = scrollView.contentView.bounds.origin.y
            if abs(currentY - scrollOffset) > 1 {
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollOffset))
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
    }

    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: DiffPaneView
        weak var tableView: NSTableView?
        weak var scrollView: NSScrollView?
        var isScrolling = false

        init(_ parent: DiffPaneView) {
            self.parent = parent
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.lines.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let line = parent.lines[row]

            let cell = NSView()
            cell.wantsLayer = true

            // Background color
            switch line.type {
            case .added:
                cell.layer?.backgroundColor = NSColor(red: 0.18, green: 0.75, blue: 0.3, alpha: 0.3).cgColor
            case .removed:
                cell.layer?.backgroundColor = NSColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 0.3).cgColor
            case .same:
                cell.layer?.backgroundColor = NSColor.clear.cgColor
            }

            // Line number
            let lineNumLabel = NSTextField(labelWithString: line.lineNumber.map { "\($0)" } ?? "")
            lineNumLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            lineNumLabel.textColor = .secondaryLabelColor
            lineNumLabel.alignment = .right
            lineNumLabel.translatesAutoresizingMaskIntoConstraints = false

            // Text
            let textLabel = NSTextField(labelWithString: line.text)
            textLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            textLabel.textColor = .labelColor
            textLabel.lineBreakMode = .byClipping
            textLabel.translatesAutoresizingMaskIntoConstraints = false

            cell.addSubview(lineNumLabel)
            cell.addSubview(textLabel)

            NSLayoutConstraint.activate([
                lineNumLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                lineNumLabel.widthAnchor.constraint(equalToConstant: 40),
                lineNumLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),

                textLabel.leadingAnchor.constraint(equalTo: lineNumLabel.trailingAnchor, constant: 8),
                textLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])

            return cell
        }

        @objc func scrollDidChange(_ notification: Notification) {
            guard parent.isSource else { return }
            guard let scrollView = scrollView else { return }
            isScrolling = true
            parent.scrollOffset = scrollView.contentView.bounds.origin.y
            DispatchQueue.main.async {
                self.isScrolling = false
            }
        }
    }
}

// MARK: - Center indicator bar

struct DiffIndicatorBar: View {
    let result: DiffResult

    var body: some View {
        GeometryReader { geo in
            let lineCount = result.left.count
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))

                if lineCount > 0 {
                    ForEach(Array(zip(result.left, result.right).enumerated()), id: \.offset) { i, pair in
                        let (left, right) = pair
                        let type: DiffLineType? = {
                            if left.type != .same { return left.type }
                            if right.type != .same { return right.type }
                            return nil
                        }()

                        if let type = type {
                            Rectangle()
                                .fill(type == .added ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                                .frame(height: max(2, geo.size.height / CGFloat(lineCount)))
                                .offset(y: (CGFloat(i) / CGFloat(lineCount)) * geo.size.height)
                        }
                    }
                }
            }
        }
    }
}
