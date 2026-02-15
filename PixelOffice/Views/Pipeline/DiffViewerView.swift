import SwiftUI

/// Git Diff 뷰어
struct DiffViewerView: View {
    let diff: String
    let snapshot: GitSnapshot?
    @Environment(\.dismiss) private var dismiss
    @State private var showFullDiff = false
    @State private var selectedFile: String?

    /// 파싱된 diff 파일들
    var parsedFiles: [DiffFile] {
        DiffParser.parse(diff)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔀 코드 변경사항")
                        .font(.title2.bold())

                    if let snapshot = snapshot {
                        HStack(spacing: 12) {
                            Label(snapshot.branch, systemImage: "arrow.triangle.branch")
                            Label(String(snapshot.commitHash.prefix(8)), systemImage: "number")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 변경 통계
                HStack(spacing: 16) {
                    let stats = calculateStats()
                    Label("+\(stats.additions)", systemImage: "plus.circle.fill")
                        .foregroundStyle(.green)
                    Label("-\(stats.deletions)", systemImage: "minus.circle.fill")
                        .foregroundStyle(.red)
                    Label("\(parsedFiles.count)개 파일", systemImage: "doc.text")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 메인 콘텐츠
            HSplitView {
                // 파일 목록
                VStack(alignment: .leading, spacing: 0) {
                    Text("변경된 파일")
                        .font(.headline)
                        .padding()

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(parsedFiles, id: \.path) { file in
                                DiffFileRow(
                                    file: file,
                                    isSelected: selectedFile == file.path,
                                    onSelect: { selectedFile = file.path }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .frame(minWidth: 250, maxWidth: 300)

                Divider()

                // Diff 내용
                VStack(spacing: 0) {
                    if let selectedPath = selectedFile,
                       let file = parsedFiles.first(where: { $0.path == selectedPath }) {
                        DiffContentView(file: file)
                    } else if !parsedFiles.isEmpty {
                        // 첫 번째 파일 자동 선택
                        DiffContentView(file: parsedFiles[0])
                            .onAppear { selectedFile = parsedFiles[0].path }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.badge.clock")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("변경사항이 없습니다")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private func calculateStats() -> (additions: Int, deletions: Int) {
        var additions = 0
        var deletions = 0
        for file in parsedFiles {
            additions += file.additions
            deletions += file.deletions
        }
        return (additions, deletions)
    }
}

// MARK: - Diff File Row

struct DiffFileRow: View {
    let file: DiffFile
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 8) {
                // 변경 타입 아이콘
                Image(systemName: file.changeType.icon)
                    .foregroundStyle(file.changeType.color)
                    .frame(width: 16)

                // 파일명
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.fileName)
                        .font(.body)
                        .lineLimit(1)
                    Text(file.directory)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // 변경 통계
                HStack(spacing: 4) {
                    if file.additions > 0 {
                        Text("+\(file.additions)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.green)
                    }
                    if file.deletions > 0 {
                        Text("-\(file.deletions)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Diff Content View

struct DiffContentView: View {
    let file: DiffFile

    var body: some View {
        VStack(spacing: 0) {
            // 파일 헤더
            HStack {
                Label(file.path, systemImage: "doc.text")
                    .font(.headline)

                Spacer()

                HStack(spacing: 8) {
                    Text("+\(file.additions)")
                        .foregroundStyle(.green)
                    Text("-\(file.deletions)")
                        .foregroundStyle(.red)
                }
                .font(.subheadline.monospacedDigit())
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Diff 라인
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(file.lines.enumerated()), id: \.offset) { _, line in
                        DiffLineView(line: line)
                    }
                }
            }
        }
    }
}

// MARK: - Diff Line View

struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            // 라인 번호
            HStack(spacing: 4) {
                Text(line.oldLineNumber.map { String($0) } ?? "")
                    .frame(width: 40, alignment: .trailing)
                Text(line.newLineNumber.map { String($0) } ?? "")
                    .frame(width: 40, alignment: .trailing)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .background(line.type.backgroundColor.opacity(0.3))

            // 변경 타입 표시
            Text(line.type.symbol)
                .font(.body.monospaced())
                .frame(width: 20)
                .foregroundStyle(line.type.color)

            // 코드 내용
            Text(line.content)
                .font(.body.monospaced())
                .foregroundStyle(line.type.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .background(line.type.backgroundColor)
    }
}

// MARK: - Diff Models

struct DiffFile {
    let path: String
    let lines: [DiffLine]
    let changeType: DiffChangeType
    var additions: Int = 0
    var deletions: Int = 0

    var fileName: String {
        (path as NSString).lastPathComponent
    }

    var directory: String {
        (path as NSString).deletingLastPathComponent
    }
}

struct DiffLine {
    let content: String
    let type: DiffLineType
    let oldLineNumber: Int?
    let newLineNumber: Int?
}

enum DiffLineType {
    case addition
    case deletion
    case context
    case header

    var symbol: String {
        switch self {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .header: return "@"
        }
    }

    var color: Color {
        switch self {
        case .addition: return .green
        case .deletion: return .red
        case .context: return .secondary
        case .header: return .blue
        }
    }

    var textColor: Color {
        switch self {
        case .addition: return .green
        case .deletion: return .red
        default: return .primary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .addition: return .green.opacity(0.1)
        case .deletion: return .red.opacity(0.1)
        case .header: return .blue.opacity(0.1)
        default: return .clear
        }
    }
}

enum DiffChangeType {
    case added
    case modified
    case deleted
    case renamed

    var icon: String {
        switch self {
        case .added: return "plus.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .deleted: return "minus.circle.fill"
        case .renamed: return "arrow.right.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .added: return .green
        case .modified: return .orange
        case .deleted: return .red
        case .renamed: return .blue
        }
    }
}

// MARK: - Diff Parser

struct DiffParser {
    static func parse(_ diffString: String) -> [DiffFile] {
        var files: [DiffFile] = []
        let lines = diffString.components(separatedBy: "\n")

        var currentFilePath: String?
        var currentLines: [DiffLine] = []
        var oldLine = 0
        var newLine = 0
        var additions = 0
        var deletions = 0

        for line in lines {
            // 새 파일 시작
            if line.hasPrefix("diff --git") {
                // 이전 파일 저장
                if let path = currentFilePath {
                    let changeType = determineChangeType(additions: additions, deletions: deletions)
                    files.append(DiffFile(
                        path: path,
                        lines: currentLines,
                        changeType: changeType,
                        additions: additions,
                        deletions: deletions
                    ))
                }

                // 파일 경로 추출 (a/path b/path 형식)
                if let range = line.range(of: " b/") {
                    currentFilePath = String(line[range.upperBound...])
                }
                currentLines = []
                additions = 0
                deletions = 0
                continue
            }

            // 헝크 헤더 (@@ -old,count +new,count @@)
            if line.hasPrefix("@@") {
                let pattern = #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    if let oldRange = Range(match.range(at: 1), in: line) {
                        oldLine = Int(line[oldRange]) ?? 0
                    }
                    if let newRange = Range(match.range(at: 2), in: line) {
                        newLine = Int(line[newRange]) ?? 0
                    }
                }
                currentLines.append(DiffLine(content: line, type: .header, oldLineNumber: nil, newLineNumber: nil))
                continue
            }

            // 변경 라인
            if line.hasPrefix("+") && !line.hasPrefix("+++") {
                currentLines.append(DiffLine(content: String(line.dropFirst()), type: .addition, oldLineNumber: nil, newLineNumber: newLine))
                newLine += 1
                additions += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                currentLines.append(DiffLine(content: String(line.dropFirst()), type: .deletion, oldLineNumber: oldLine, newLineNumber: nil))
                oldLine += 1
                deletions += 1
            } else if !line.hasPrefix("\\") && !line.hasPrefix("diff") && !line.hasPrefix("index") && !line.hasPrefix("---") && !line.hasPrefix("+++") {
                let content = line.hasPrefix(" ") ? String(line.dropFirst()) : line
                currentLines.append(DiffLine(content: content, type: .context, oldLineNumber: oldLine, newLineNumber: newLine))
                oldLine += 1
                newLine += 1
            }
        }

        // 마지막 파일 저장
        if let path = currentFilePath {
            let changeType = determineChangeType(additions: additions, deletions: deletions)
            files.append(DiffFile(
                path: path,
                lines: currentLines,
                changeType: changeType,
                additions: additions,
                deletions: deletions
            ))
        }

        return files
    }

    private static func determineChangeType(additions: Int, deletions: Int) -> DiffChangeType {
        if deletions == 0 && additions > 0 {
            return .added
        } else if additions == 0 && deletions > 0 {
            return .deleted
        } else {
            return .modified
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleDiff = """
    diff --git a/PixelOffice/Models/Test.swift b/PixelOffice/Models/Test.swift
    index abc123..def456 100644
    --- a/PixelOffice/Models/Test.swift
    +++ b/PixelOffice/Models/Test.swift
    @@ -1,5 +1,7 @@
     import Foundation
     
    +// 새로운 주석 추가
    +
     struct Test {
    -    let name: String
    +    let name: String
    +    let value: Int
     }
    """

    DiffViewerView(
        diff: sampleDiff,
        snapshot: GitSnapshot(
            commitHash: "abc123def456",
            branch: "main",
            hasUncommittedChanges: true
        )
    )
}
