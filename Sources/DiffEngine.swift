import Foundation

enum DiffLineType {
    case same
    case added
    case removed
}

struct DiffLine: Identifiable {
    let id = UUID()
    let lineNumber: Int?
    let text: String
    let type: DiffLineType
}

struct DiffResult {
    let left: [DiffLine]
    let right: [DiffLine]
}

/// Myers diff algorithm - produces a minimal edit script
struct DiffEngine {
    static func diff(old: String, new: String) -> DiffResult {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")

        let changes = myersDiff(old: oldLines, new: newLines)
        return buildSideBySide(old: oldLines, new: newLines, changes: changes)
    }

    enum Change {
        case equal(oldIdx: Int, newIdx: Int)
        case insert(newIdx: Int)
        case delete(oldIdx: Int)
    }

    private static func myersDiff(old: [String], new: [String]) -> [Change] {
        let n = old.count
        let m = new.count
        let max = n + m

        if max == 0 { return [] }

        var v = [Int: Int]()
        v[1] = 0
        var trace = [[Int: Int]]()

        outer: for d in 0...max {
            trace.append(v)
            var newV = v
            for k in stride(from: -d, through: d, by: 2) {
                var x: Int
                if k == -d || (k != d && (v[k - 1] ?? 0) < (v[k + 1] ?? 0)) {
                    x = v[k + 1] ?? 0
                } else {
                    x = (v[k - 1] ?? 0) + 1
                }
                var y = x - k
                while x < n && y < m && old[x] == new[y] {
                    x += 1
                    y += 1
                }
                newV[k] = x
                if x >= n && y >= m {
                    trace.append(newV)
                    break outer
                }
            }
            v = newV
        }

        // Backtrack
        var changes = [Change]()
        var x = n
        var y = m

        for d in stride(from: trace.count - 2, through: 0, by: -1) {
            let v = trace[d]
            let k = x - y

            var prevK: Int
            if k == -d || (k != d && (v[k - 1] ?? 0) < (v[k + 1] ?? 0)) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }

            let prevX = v[prevK] ?? 0
            let prevY = prevX - prevK

            // Diagonal (equal)
            while x > prevX && y > prevY {
                x -= 1
                y -= 1
                changes.append(.equal(oldIdx: x, newIdx: y))
            }

            if d > 0 {
                if x == prevX {
                    // Insert
                    y -= 1
                    changes.append(.insert(newIdx: y))
                } else {
                    // Delete
                    x -= 1
                    changes.append(.delete(oldIdx: x))
                }
            }
        }

        return changes.reversed()
    }

    private static func buildSideBySide(old: [String], new: [String], changes: [Change]) -> DiffResult {
        var leftLines = [DiffLine]()
        var rightLines = [DiffLine]()

        for change in changes {
            switch change {
            case .equal(let oldIdx, let newIdx):
                leftLines.append(DiffLine(lineNumber: oldIdx + 1, text: old[oldIdx], type: .same))
                rightLines.append(DiffLine(lineNumber: newIdx + 1, text: new[newIdx], type: .same))
            case .delete(let oldIdx):
                leftLines.append(DiffLine(lineNumber: oldIdx + 1, text: old[oldIdx], type: .removed))
                rightLines.append(DiffLine(lineNumber: nil, text: "", type: .same))
            case .insert(let newIdx):
                leftLines.append(DiffLine(lineNumber: nil, text: "", type: .same))
                rightLines.append(DiffLine(lineNumber: newIdx + 1, text: new[newIdx], type: .added))
            }
        }

        return DiffResult(left: leftLines, right: rightLines)
    }
}
