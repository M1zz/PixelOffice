import SwiftUI

/// 직원 업무 기록 뷰
struct EmployeeWorkLogView: View {
    let employeeId: UUID
    let employeeName: String
    @Environment(\.dismiss) private var dismiss
    @State private var workLog: EmployeeWorkLog?
    @State private var rawMarkdown: String = ""
    @State private var showingRawMarkdown = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(employeeName)의 업무 기록")
                        .font(.title2.bold())
                    if let log = workLog {
                        Text("\(log.entries.count)개의 기록")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                // 보기 모드 토글
                Picker("", selection: $showingRawMarkdown) {
                    Text("목록").tag(false)
                    Text("마크다운").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            if showingRawMarkdown {
                // 마크다운 원본 보기
                ScrollView {
                    Text(rawMarkdown.isEmpty ? "업무 기록이 없습니다." : rawMarkdown)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            } else {
                // 목록 보기
                if let log = workLog, !log.entries.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(log.entries.reversed()) { entry in
                                WorkLogEntryCard(entry: entry)
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("업무 기록이 없습니다")
                            .font(.headline)
                        Text("직원과 대화를 하면 자동으로 기록됩니다")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            Divider()

            // Footer - 파일 경로 정보
            HStack {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(EmployeeWorkLogService.shared.getWorkLogFilePath(for: employeeId, employeeName: employeeName))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()

                Button("파일 열기") {
                    openWorkLogFile()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Finder에서 보기") {
                    showInFinder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 500)
        .onAppear {
            loadWorkLog()
        }
    }

    private func loadWorkLog() {
        workLog = EmployeeWorkLogService.shared.loadWorkLog(for: employeeId, employeeName: employeeName)

        // 마크다운 파일 내용 로드
        let filePath = EmployeeWorkLogService.shared.getWorkLogFilePath(for: employeeId, employeeName: employeeName)
        if FileManager.default.fileExists(atPath: filePath),
           let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            rawMarkdown = content
        }
    }

    private func openWorkLogFile() {
        let filePath = EmployeeWorkLogService.shared.getWorkLogFilePath(for: employeeId, employeeName: employeeName)
        let url = URL(fileURLWithPath: filePath)

        // 파일이 없으면 빈 파일 생성
        if !FileManager.default.fileExists(atPath: filePath) {
            let emptyLog = EmployeeWorkLog(employeeId: employeeId, employeeName: employeeName)
            EmployeeWorkLogService.shared.saveWorkLog(emptyLog)
        }

        NSWorkspace.shared.open(url)
    }

    private func showInFinder() {
        let filePath = EmployeeWorkLogService.shared.getWorkLogFilePath(for: employeeId, employeeName: employeeName)
        let url = URL(fileURLWithPath: filePath)

        // 파일이 없으면 폴더를 열기
        if FileManager.default.fileExists(atPath: filePath) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let folderUrl = URL(fileURLWithPath: EmployeeWorkLogService.shared.workLogPath)
            NSWorkspace.shared.open(folderUrl)
        }
    }
}

/// 업무 기록 카드
struct WorkLogEntryCard: View {
    let entry: WorkEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더
            HStack {
                Text(entry.title)
                    .font(.headline)
                Spacer()
                Text(entry.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 요약
            Text(entry.summary)
                .font(.body)
                .foregroundStyle(.secondary)

            // 프로젝트 정보
            if let project = entry.relatedProject {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                    Text(project)
                        .font(.callout)
                }
            }

            // 상세 내용
            if let details = entry.details, !details.isEmpty {
                Divider()
                Text(details)
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.8))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// 프로젝트 직원용 업무 기록 뷰
struct ProjectEmployeeWorkLogView: View {
    let employeeId: UUID
    let employeeName: String
    let projectName: String
    let departmentType: DepartmentType
    @Environment(\.dismiss) private var dismiss
    @State private var workLog: EmployeeWorkLog?
    @State private var rawMarkdown: String = ""
    @State private var showingRawMarkdown = false

    init(employeeId: UUID, employeeName: String, projectName: String, departmentType: DepartmentType = .general) {
        self.employeeId = employeeId
        self.employeeName = employeeName
        self.projectName = projectName
        self.departmentType = departmentType
    }

    var filePath: String {
        DataPathService.shared.employeeWorkLogPath(projectName: projectName, department: departmentType, employeeName: employeeName)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(employeeName)의 업무 기록")
                        .font(.title2.bold())
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                        Text(projectName)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("•")
                        Text(departmentType.rawValue)
                            .font(.callout)
                            .foregroundStyle(departmentType.color)
                        if let log = workLog {
                            Text("•")
                            Text("\(log.entries.count)개의 기록")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()

                Picker("", selection: $showingRawMarkdown) {
                    Text("목록").tag(false)
                    Text("마크다운").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            if showingRawMarkdown {
                ScrollView {
                    Text(rawMarkdown.isEmpty ? "업무 기록이 없습니다." : rawMarkdown)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            } else {
                if let log = workLog, !log.entries.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(log.entries.reversed()) { entry in
                                WorkLogEntryCard(entry: entry)
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("업무 기록이 없습니다")
                            .font(.headline)
                        Text("직원과 대화를 하면 자동으로 기록됩니다")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            Divider()

            HStack {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(filePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()

                Button("파일 열기") {
                    openWorkLogFile()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Finder에서 보기") {
                    showInFinder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 500)
        .onAppear {
            loadWorkLog()
        }
    }

    private func loadWorkLog() {
        workLog = EmployeeWorkLogService.shared.loadProjectWorkLog(
            projectName: projectName,
            department: departmentType,
            employeeId: employeeId,
            employeeName: employeeName
        )

        if FileManager.default.fileExists(atPath: filePath),
           let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            rawMarkdown = content
        }
    }

    private func openWorkLogFile() {
        let url = URL(fileURLWithPath: filePath)

        if !FileManager.default.fileExists(atPath: filePath) {
            let emptyLog = EmployeeWorkLog(employeeId: employeeId, employeeName: employeeName, departmentType: departmentType)
            EmployeeWorkLogService.shared.saveProjectWorkLog(emptyLog, projectName: projectName, department: departmentType)
        }

        NSWorkspace.shared.open(url)
    }

    private func showInFinder() {
        let url = URL(fileURLWithPath: filePath)

        if FileManager.default.fileExists(atPath: filePath) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let folderUrl = URL(fileURLWithPath: DataPathService.shared.peoplePath(projectName, department: departmentType))
            NSWorkspace.shared.open(folderUrl)
        }
    }
}

#Preview {
    EmployeeWorkLogView(employeeId: UUID(), employeeName: "Claude-기획")
}
