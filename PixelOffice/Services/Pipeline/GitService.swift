import Foundation

/// Git 관련 기능 서비스
actor GitService {

    /// Git 스냅샷 캡처 (파이프라인 시작 전)
    func captureSnapshot(projectPath: String) async -> GitSnapshot? {
        guard isGitRepository(projectPath: projectPath) else {
            print("[GitService] Not a git repository: \(projectPath)")
            return nil
        }

        // 현재 브랜치
        let branch = await getCurrentBranch(projectPath: projectPath)

        // 현재 커밋 해시
        let commitHash = await getCurrentCommitHash(projectPath: projectPath)

        // 미커밋 변경 여부
        let hasChanges = await hasUncommittedChanges(projectPath: projectPath)

        // 미커밋 변경이 있으면 stash 저장
        var stashRef: String? = nil
        if hasChanges {
            stashRef = await createStash(projectPath: projectPath)
            if stashRef != nil {
                // stash 적용 (변경사항 유지하면서 저장만)
                await applyStash(projectPath: projectPath)
            }
        }

        return GitSnapshot(
            commitHash: commitHash ?? "unknown",
            branch: branch ?? "unknown",
            stashRef: stashRef,
            hasUncommittedChanges: hasChanges
        )
    }

    /// Git diff 캡처 (파이프라인 완료 후)
    func captureDiff(projectPath: String, snapshot: GitSnapshot?) async -> String {
        guard isGitRepository(projectPath: projectPath) else {
            return ""
        }

        var diffArgs = ["diff"]

        // 스냅샷의 커밋과 현재 상태 비교
        if let commitHash = snapshot?.commitHash, commitHash != "unknown" {
            diffArgs.append(commitHash)
        }

        // --stat도 포함
        let stat = await runGitCommand(projectPath: projectPath, arguments: ["diff", "--stat"])
        let diff = await runGitCommand(projectPath: projectPath, arguments: diffArgs)

        var result = ""
        if !stat.isEmpty {
            result += "=== 변경 요약 ===\n\(stat)\n\n"
        }
        if !diff.isEmpty {
            result += "=== 상세 diff ===\n\(diff)"
        }

        return result
    }

    /// Git 저장소인지 확인
    func isGitRepository(projectPath: String) -> Bool {
        let gitPath = (projectPath as NSString).appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitPath)
    }

    /// 현재 브랜치 가져오기
    func getCurrentBranch(projectPath: String) async -> String? {
        let output = await runGitCommand(projectPath: projectPath, arguments: ["rev-parse", "--abbrev-ref", "HEAD"])
        return output.isEmpty ? nil : output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 현재 커밋 해시 가져오기
    func getCurrentCommitHash(projectPath: String) async -> String? {
        let output = await runGitCommand(projectPath: projectPath, arguments: ["rev-parse", "HEAD"])
        return output.isEmpty ? nil : output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 미커밋 변경 여부 확인
    func hasUncommittedChanges(projectPath: String) async -> Bool {
        let output = await runGitCommand(projectPath: projectPath, arguments: ["status", "--porcelain"])
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Stash 생성
    func createStash(projectPath: String, message: String = "PixelOffice Pipeline Snapshot") async -> String? {
        let output = await runGitCommand(projectPath: projectPath, arguments: ["stash", "push", "-m", message])
        if output.contains("No local changes") {
            return nil
        }
        // stash ref 가져오기
        let stashList = await runGitCommand(projectPath: projectPath, arguments: ["stash", "list", "-1"])
        if let match = stashList.range(of: #"stash@\{\d+\}"#, options: .regularExpression) {
            return String(stashList[match])
        }
        return "stash@{0}"
    }

    /// Stash 적용 (pop하지 않고 apply만)
    func applyStash(projectPath: String, stashRef: String = "stash@{0}") async {
        _ = await runGitCommand(projectPath: projectPath, arguments: ["stash", "apply", stashRef])
    }

    /// 변경된 파일 목록 가져오기
    func getChangedFiles(projectPath: String, since: String? = nil) async -> [String] {
        var args = ["diff", "--name-only"]
        if let since = since {
            args.append(since)
        }

        let output = await runGitCommand(projectPath: projectPath, arguments: args)
        return output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Git 명령 실행
    private func runGitCommand(projectPath: String, arguments: [String]) async -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: outputData, encoding: .utf8) ?? ""
        } catch {
            print("[GitService] Git command failed: \(error)")
            return ""
        }
    }
}
