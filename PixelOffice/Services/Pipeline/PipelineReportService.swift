import Foundation

/// 파이프라인 실행 결과를 마크다운 리포트로 생성하는 서비스
class PipelineReportService {
    static let shared = PipelineReportService()

    private init() {}

    /// 리포트 생성 및 저장
    /// - Parameters:
    ///   - run: 파이프라인 실행 결과
    ///   - projectName: 프로젝트 이름
    /// - Returns: 저장된 파일 경로
    func generateAndSaveReport(for run: PipelineRun, projectName: String) -> String? {
        let report = generateReport(for: run, projectName: projectName)
        return saveReport(report, run: run, projectName: projectName)
    }

    /// 마크다운 리포트 생성
    func generateReport(for run: PipelineRun, projectName: String) -> String {
        var md = ""

        // 헤더
        md += generateHeader(run: run, projectName: projectName)

        // 요약
        md += generateSummary(run: run)

        // 요구사항
        md += generateRequirement(run: run)

        // 🧠 결정 사항 (Decision Log)
        if !run.decisions.isEmpty {
            md += generateDecisionsSection(run: run)
        }

        // 분해된 태스크
        md += generateTasksSection(run: run)

        // 빌드 결과
        md += generateBuildSection(run: run)

        // 📱 앱 실행 결과
        if let launchResult = run.appLaunchResult {
            md += generateAppLaunchSection(launchResult: launchResult)
        }

        // Self-Healing (있는 경우)
        if run.healingAttempts > 0 {
            md += generateHealingSection(run: run)
        }

        // 🔀 Git Diff
        if run.gitDiff != nil || run.gitSnapshot != nil {
            md += generateGitDiffSection(run: run)
        }

        // 변경된 파일
        md += generateChangedFilesSection(run: run)

        // 🎨 디자인 프리뷰
        if !run.designPreviewPaths.isEmpty {
            md += generateDesignPreviewSection(paths: run.designPreviewPaths)
        }

        // 로그
        md += generateLogsSection(run: run)

        // 푸터
        md += generateFooter()

        return md
    }

    // MARK: - Section Generators

    private func generateHeader(run: PipelineRun, projectName: String) -> String {
        let statusEmoji = run.state == .completed ? "✅" : (run.state == .failed ? "❌" : "⏸️")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateStr = dateFormatter.string(from: run.createdAt)

        return """
        # \(statusEmoji) 파이프라인 실행 리포트

        | 항목 | 값 |
        |------|-----|
        | **프로젝트** | \(projectName) |
        | **실행일시** | \(dateStr) |
        | **상태** | \(run.state.rawValue) |
        | **소요시간** | \(formatDuration(run.duration)) |

        ---


        """
    }

    private func generateSummary(run: PipelineRun) -> String {
        let totalTasks = run.decomposedTasks.count
        let completedTasks = run.decomposedTasks.filter { $0.status == .completed }.count
        let failedTasks = run.decomposedTasks.filter { $0.status == .failed }.count
        let buildAttempts = run.buildAttempts.count
        let buildSuccess = run.isBuildSuccessful

        return """
        ## 📊 실행 요약

        | 지표 | 값 |
        |------|-----|
        | 분해된 태스크 | \(totalTasks)개 |
        | 성공 | \(completedTasks)개 |
        | 실패 | \(failedTasks)개 |
        | 빌드 시도 | \(buildAttempts)회 |
        | 빌드 결과 | \(buildSuccess ? "✅ 성공" : "❌ 실패") |
        | Self-Healing | \(run.healingAttempts)회 시도 |


        """
    }

    private func generateRequirement(run: PipelineRun) -> String {
        return """
        ## 📝 요구사항

        > \(run.requirement)


        """
    }

    private func generateTasksSection(run: PipelineRun) -> String {
        guard !run.decomposedTasks.isEmpty else {
            return """
            ## 📋 분해된 태스크

            태스크가 없습니다.


            """
        }

        var md = """
        ## 📋 분해된 태스크

        | # | 상태 | 태스크 | 부서 | 우선순위 | 소요시간 |
        |---|------|--------|------|----------|----------|

        """

        for (index, task) in run.decomposedTasks.enumerated() {
            let statusEmoji = task.status.emoji
            let duration = task.duration != nil ? formatDuration(task.duration) : "-"
            md += "| \(index + 1) | \(statusEmoji) | \(task.title) | \(task.department.rawValue) | \(task.priority.rawValue) | \(duration) |\n"
        }

        md += "\n"

        // 각 태스크 상세
        md += "### 태스크 상세\n\n"

        for (index, task) in run.decomposedTasks.enumerated() {
            md += """
            <details>
            <summary><strong>\(index + 1). \(task.title)</strong> \(task.status.emoji)</summary>

            **설명:** \(task.description)

            **부서:** \(task.department.rawValue) | **우선순위:** \(task.priority.rawValue)

            """

            if !task.createdFiles.isEmpty {
                md += "\n**생성된 파일:**\n"
                for file in task.createdFiles {
                    md += "- `\(toRelativePath(file))`\n"
                }
            }

            if !task.modifiedFiles.isEmpty {
                md += "\n**수정된 파일:**\n"
                for file in task.modifiedFiles {
                    md += "- `\(toRelativePath(file))`\n"
                }
            }

            if let error = task.error {
                md += "\n**에러:**\n```\n\(error)\n```\n"
            }

            md += "\n</details>\n\n"
        }

        return md
    }

    private func generateBuildSection(run: PipelineRun) -> String {
        guard !run.buildAttempts.isEmpty else {
            return """
            ## 🔨 빌드 결과

            빌드가 실행되지 않았습니다.


            """
        }

        var md = """
        ## 🔨 빌드 결과

        | 시도 | 결과 | 에러 수 | 소요시간 | Self-Healing |
        |------|------|---------|----------|--------------|

        """

        for (index, attempt) in run.buildAttempts.enumerated() {
            let resultEmoji = attempt.success ? "✅ 성공" : "❌ 실패"
            let healingMark = attempt.isHealingAttempt ? "🩹 수정 후" : "-"
            md += "| \(index + 1) | \(resultEmoji) | \(attempt.errors.count)개 | \(formatDuration(attempt.duration)) | \(healingMark) |\n"
        }

        md += "\n"

        // 마지막 빌드의 에러 상세 (실패한 경우)
        if let lastAttempt = run.lastBuildAttempt, !lastAttempt.success && !lastAttempt.errors.isEmpty {
            md += "### 빌드 에러 상세\n\n"

            for error in lastAttempt.errors.prefix(20) {
                let icon = error.severity == .error ? "❌" : (error.severity == .warning ? "⚠️" : "ℹ️")
                md += "- \(icon) "
                if !error.location.isEmpty {
                    md += "`\(error.location)`: "
                }
                md += "\(error.message)\n"
            }

            if lastAttempt.errors.count > 20 {
                md += "\n...외 \(lastAttempt.errors.count - 20)개 에러\n"
            }

            md += "\n"
        }

        return md
    }

    private func generateHealingSection(run: PipelineRun) -> String {
        var md = """
        ## 🩹 Self-Healing

        | 항목 | 값 |
        |------|-----|
        | 시도 횟수 | \(run.healingAttempts)/\(run.maxHealingAttempts) |
        | 결과 | \(run.isBuildSuccessful ? "✅ 수정 성공" : "❌ 수정 실패") |


        """

        // Healing 후 빌드 결과
        let healingAttempts = run.buildAttempts.filter { $0.isHealingAttempt }
        if !healingAttempts.isEmpty {
            md += "### Healing 빌드 결과\n\n"
            for (index, attempt) in healingAttempts.enumerated() {
                md += "**시도 \(index + 1):** \(attempt.success ? "✅ 성공" : "❌ 실패") (\(attempt.errors.count)개 에러)\n\n"
            }
        }

        return md
    }

    private func generateChangedFilesSection(run: PipelineRun) -> String {
        let allCreated = Set(run.decomposedTasks.flatMap { $0.createdFiles })
        let allModified = Set(run.decomposedTasks.flatMap { $0.modifiedFiles })

        if allCreated.isEmpty && allModified.isEmpty {
            return """
            ## 📁 변경된 파일

            변경된 파일 정보가 없습니다.


            """
        }

        var md = """
        ## 📁 변경된 파일


        """

        if !allCreated.isEmpty {
            md += "### 생성된 파일 (\(allCreated.count)개)\n\n"
            for file in allCreated.sorted() {
                md += "- `\(toRelativePath(file))`\n"
            }
            md += "\n"
        }

        if !allModified.isEmpty {
            md += "### 수정된 파일 (\(allModified.count)개)\n\n"
            for file in allModified.sorted() {
                md += "- `\(toRelativePath(file))`\n"
            }
            md += "\n"
        }

        return md
    }

    private func generateLogsSection(run: PipelineRun) -> String {
        guard !run.logs.isEmpty else {
            return ""
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"

        var md = """
        ## 📜 실행 로그

        <details>
        <summary>전체 로그 보기 (\(run.logs.count)개)</summary>

        | 시간 | 레벨 | 메시지 |
        |------|------|--------|

        """

        for log in run.logs {
            let time = dateFormatter.string(from: log.timestamp)
            let levelEmoji = log.level.emoji
            let message = log.message.replacingOccurrences(of: "|", with: "\\|")
            md += "| \(time) | \(levelEmoji) | \(message) |\n"
        }

        md += """

        </details>


        """

        return md
    }

    // MARK: - Decision Log Section

    private func generateDecisionsSection(run: PipelineRun) -> String {
        var md = """
        ## 🧠 결정 사항 (Decision Log)

        AI가 작업 중 내린 주요 결정들입니다.

        | 결정 | 이유 | 대안 |
        |------|------|------|

        """

        for decision in run.decisions {
            let alternativesStr = decision.alternatives.isEmpty ? "-" : decision.alternatives.joined(separator: ", ")
            let decisionStr = decision.decision.replacingOccurrences(of: "|", with: "\\|")
            let reasonStr = decision.reason.replacingOccurrences(of: "|", with: "\\|")
            md += "| \(decisionStr) | \(reasonStr) | \(alternativesStr) |\n"
        }

        md += "\n"
        return md
    }

    // MARK: - Git Diff Section

    private func generateGitDiffSection(run: PipelineRun) -> String {
        var md = """
        ## 🔀 코드 변경사항 (Git Diff)


        """

        if let snapshot = run.gitSnapshot {
            md += """
            ### 시작 시점 스냅샷
            - **브랜치**: \(snapshot.branch)
            - **커밋**: `\(snapshot.commitHash.prefix(8))`
            - **시각**: \(formatDate(snapshot.capturedAt))
            - **미커밋 변경**: \(snapshot.hasUncommittedChanges ? "있음" : "없음")


            """
        }

        if let diff = run.gitDiff, !diff.isEmpty {
            md += """
            ### Diff 상세

            <details>
            <summary>전체 diff 보기</summary>

            ```diff
            \(diff)
            ```

            </details>


            """
        } else {
            md += "*변경사항 없음*\n\n"
        }

        return md
    }

    // MARK: - App Launch Section

    private func generateAppLaunchSection(launchResult: AppLaunchResult) -> String {
        let statusEmoji = launchResult.success ? "✅" : "❌"

        var md = """
        ## 📱 앱 실행 결과

        | 항목 | 값 |
        |------|-----|
        | **상태** | \(statusEmoji) \(launchResult.success ? "실행 성공" : "실행 실패") |
        | **플랫폼** | \(launchResult.platform.rawValue) |

        """

        if let simulatorName = launchResult.simulatorName {
            md += "| **시뮬레이터** | \(simulatorName) |\n"
        }

        if let bundleId = launchResult.appBundleId {
            md += "| **Bundle ID** | `\(bundleId)` |\n"
        }

        md += "\n"

        // 실행 로그
        if !launchResult.logs.isEmpty {
            md += """
            ### 실행 로그

            """
            for log in launchResult.logs {
                md += "- \(log)\n"
            }
            md += "\n"
        }

        return md
    }

    // MARK: - Design Preview Section

    private func generateDesignPreviewSection(paths: [String]) -> String {
        var md = """
        ## 🎨 디자인 프리뷰

        생성된 디자인 HTML 파일:


        """

        for (index, path) in paths.enumerated() {
            let fileName = (path as NSString).lastPathComponent
            md += "\(index + 1). `\(fileName)` - [열기](file://\(path))\n"
        }

        md += "\n"
        return md
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func generateFooter() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let now = dateFormatter.string(from: Date())

        return """
        ---

        *이 리포트는 PixelOffice 자동 개발 파이프라인에 의해 생성되었습니다.*
        *생성 시각: \(now)*
        """
    }

    // MARK: - Save

    private func saveReport(_ report: String, run: PipelineRun, projectName: String) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateStr = dateFormatter.string(from: run.createdAt)

        let statusSuffix = run.state == .completed ? "성공" : "실패"
        let fileName = "\(dateStr)-파이프라인-\(statusSuffix).md"

        // 프로젝트 wiki 폴더에 저장
        let wikiPath = DataPathService.shared.projectWikiPath(projectName)
        let filePath = (wikiPath as NSString).appendingPathComponent(fileName)

        do {
            try report.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("[PipelineReportService] 리포트 저장됨: \(filePath)")
            return filePath
        } catch {
            print("[PipelineReportService] 리포트 저장 실패: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration = duration else { return "-" }

        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "\(minutes)분 \(seconds)초"
        } else {
            return "\(seconds)초"
        }
    }
    
    /// 절대경로를 상대경로로 변환 (프로젝트 루트 기준)
    /// - 예: /Users/leeo/Documents/code/MyApp/MyApp/View.swift → MyApp/View.swift
    private func toRelativePath(_ absolutePath: String) -> String {
        // 일반적인 프로젝트 경로 패턴들
        let patterns = [
            "/Users/[^/]+/Documents/code/[^/]+/",
            "/Users/[^/]+/Developer/[^/]+/",
            "/Users/[^/]+/Projects/[^/]+/",
            "/Users/[^/]+/[^/]+/[^/]+/"  // 더 일반적인 패턴
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: absolutePath, options: [], range: NSRange(absolutePath.startIndex..., in: absolutePath)),
               let range = Range(match.range, in: absolutePath) {
                let relativePart = String(absolutePath[range.upperBound...])
                if !relativePart.isEmpty {
                    return relativePart
                }
            }
        }
        
        // 패턴 매칭 실패 시 마지막 2-3개 경로 컴포넌트만 표시
        let components = absolutePath.components(separatedBy: "/")
        if components.count > 3 {
            return components.suffix(3).joined(separator: "/")
        }
        
        return absolutePath
    }
}

// MARK: - Extensions for Report

extension DecomposedTaskStatus {
    var emoji: String {
        switch self {
        case .pending: return "⏳"
        case .running: return "🔄"
        case .completed: return "✅"
        case .failed: return "❌"
        case .skipped: return "⏭️"
        }
    }
}

extension PipelineLogLevel {
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .success: return "✅"
        }
    }
}
