import Foundation

/// 파이프라인 결과를 위키에 자동 저장하는 서비스
class PipelineWikiService {
    static let shared = PipelineWikiService()
    
    private let fileManager = FileManager.default
    private let dataPathService = DataPathService.shared
    
    private init() {}
    
    // MARK: - Public API
    
    /// 파이프라인 결과를 부서별 위키에 저장
    /// - Parameters:
    ///   - run: 파이프라인 실행 정보
    ///   - projectName: 프로젝트 이름
    /// - Returns: 저장된 파일 경로들
    @discardableResult
    func saveToWiki(run: PipelineRun, projectName: String) -> [String] {
        var savedPaths: [String] = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: run.startedAt ?? Date())
        
        // 요약 생성
        let summary = generateSummary(from: run)
        
        // 1. 기획팀 문서 (요구사항 분석, 태스크 분해 결과)
        if let path = savePlanningDocument(run: run, projectName: projectName, dateString: dateString, summary: summary) {
            savedPaths.append(path)
        }
        
        // 2. 디자인팀 문서 (디자인 관련 변경사항)
        if let path = saveDesignDocument(run: run, projectName: projectName, dateString: dateString, summary: summary) {
            savedPaths.append(path)
        }
        
        // 3. 개발팀 문서 (코드 변경 내역, Decision Log)
        if let path = saveDevelopmentDocument(run: run, projectName: projectName, dateString: dateString, summary: summary) {
            savedPaths.append(path)
        }
        
        // 4. QA팀 문서 (빌드 결과, 에러 로그)
        if let path = saveQADocument(run: run, projectName: projectName, dateString: dateString, summary: summary) {
            savedPaths.append(path)
        }
        
        print("[PipelineWikiService] 위키 저장 완료: \(savedPaths.count)개 문서")
        return savedPaths
    }
    
    /// 단계별 중간 결과 저장 (중단 시에도 호출)
    /// - Parameters:
    ///   - run: 파이프라인 실행 정보
    ///   - projectName: 프로젝트 이름
    ///   - phase: 완료된 단계
    func savePhaseResult(run: PipelineRun, projectName: String, phase: PipelinePhase) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmm"
        let dateString = dateFormatter.string(from: Date())
        
        let basePath = dataPathService.basePath
        let projectPath = "\(basePath)/\(dataPathService.sanitizeName(projectName))"
        let pipelineLogPath = "\(projectPath)/_pipeline_logs"
        
        // 파이프라인 로그 디렉토리 생성
        dataPathService.createDirectoryIfNeeded(at: pipelineLogPath)
        
        // 단계별 로그 저장
        let phaseLogPath = "\(pipelineLogPath)/\(dateString)-phase-\(phase.rawValue)-\(phase.name).md"
        let content = generatePhaseLog(run: run, phase: phase)
        
        try? content.write(toFile: phaseLogPath, atomically: true, encoding: .utf8)
        print("[PipelineWikiService] Phase \(phase.rawValue) 로그 저장: \(phaseLogPath)")
    }
    
    // MARK: - Private Methods
    
    /// 요약 생성
    private func generateSummary(from run: PipelineRun) -> String {
        // 요구사항에서 핵심 단어 추출 (최대 30자)
        var summary = run.requirement
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        
        if summary.count > 30 {
            summary = String(summary.prefix(27)) + "..."
        }
        
        // 파일명에 사용할 수 없는 문자 제거
        summary = dataPathService.sanitizeName(summary)
        
        return summary.isEmpty ? "파이프라인-\(run.id.uuidString.prefix(8))" : summary
    }
    
    /// 단계별 로그 생성
    private func generatePhaseLog(run: PipelineRun, phase: PipelinePhase) -> String {
        var content = """
        # 파이프라인 Phase \(phase.rawValue): \(phase.name)
        
        - **실행 ID**: \(run.id.uuidString)
        - **프로젝트**: \(run.projectName)
        - **상태**: \(run.state.rawValue)
        - **기록 시각**: \(Date())
        
        ## 요구사항
        
        \(run.requirement)
        
        ## 로그
        
        """
        
        // 해당 Phase의 로그만 추출
        let phaseLogs = run.logs.filter { $0.phase == phase }
        for log in phaseLogs {
            let levelIcon = log.level == .error ? "❌" : (log.level == .warning ? "⚠️" : "📝")
            content += "- \(levelIcon) \(log.message)\n"
        }
        
        return content
    }
    
    // MARK: - Department Documents
    
    /// 기획팀 문서 저장
    private func savePlanningDocument(run: PipelineRun, projectName: String, dateString: String, summary: String) -> String? {
        let fileName = "\(dateString)-파이프라인-\(summary).md"
        let path = dataPathService.documentPath(projectName: projectName, department: .planning, fileName: fileName)
        
        var content = """
        # 📋 파이프라인 요구사항 분석
        
        - **날짜**: \(dateString)
        - **실행 ID**: \(run.id.uuidString)
        - **상태**: \(run.state.rawValue)
        
        ---
        
        ## 📝 원본 요구사항
        
        \(run.requirement)
        
        ---
        
        ## 🔍 태스크 분해 결과
        
        총 **\(run.decomposedTasks.count)개** 태스크로 분해됨
        
        | # | 태스크 | 부서 | 우선순위 | 상태 |
        |---|--------|------|----------|------|
        """
        
        for (index, task) in run.decomposedTasks.enumerated() {
            let statusIcon = task.status == .completed ? "✅" : (task.status == .failed ? "❌" : "⏳")
            content += "| \(index + 1) | \(task.title) | \(task.department.rawValue) | \(task.priority.rawValue) | \(statusIcon) |\n"
        }
        
        // 각 태스크 상세
        content += "\n---\n\n## 📄 태스크 상세\n\n"
        
        for (index, task) in run.decomposedTasks.enumerated() {
            content += """
            
            ### \(index + 1). \(task.title)
            
            - **부서**: \(task.department.rawValue)
            - **우선순위**: \(task.priority.rawValue)
            - **상태**: \(task.status.rawValue)
            
            **설명:**
            > \(task.description)
            
            """
        }
        
        content += """
        
        ---
        
        *이 문서는 PixelOffice 파이프라인에서 자동 생성되었습니다.*
        """
        
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("[PipelineWikiService] 기획 문서 저장 실패: \(error)")
            return nil
        }
    }
    
    /// 디자인팀 문서 저장
    private func saveDesignDocument(run: PipelineRun, projectName: String, dateString: String, summary: String) -> String? {
        // 디자인 관련 태스크가 없으면 스킵
        let designTasks = run.decomposedTasks.filter { $0.department == .design }
        guard !designTasks.isEmpty || !run.designPreviewPaths.isEmpty else { return nil }
        
        let fileName = "\(dateString)-파이프라인-디자인-\(summary).md"
        let path = dataPathService.documentPath(projectName: projectName, department: .design, fileName: fileName)
        
        var content = """
        # 🎨 파이프라인 디자인 변경 사항
        
        - **날짜**: \(dateString)
        - **실행 ID**: \(run.id.uuidString)
        
        ---
        
        ## 📋 디자인 태스크
        
        """
        
        if designTasks.isEmpty {
            content += "*디자인 관련 태스크 없음*\n"
        } else {
            for (index, task) in designTasks.enumerated() {
                let statusIcon = task.status == .completed ? "✅" : (task.status == .failed ? "❌" : "⏳")
                content += """
                
                ### \(index + 1). \(task.title) \(statusIcon)
                
                \(task.description)
                
                """
            }
        }
        
        // 디자인 프리뷰 링크
        if !run.designPreviewPaths.isEmpty {
            content += "\n---\n\n## 🖼️ 디자인 프리뷰\n\n"
            for (index, previewPath) in run.designPreviewPaths.enumerated() {
                let fileName = (previewPath as NSString).lastPathComponent
                content += "- [\(index + 1). \(fileName)](\(previewPath))\n"
            }
        }
        
        content += """
        
        ---
        
        *이 문서는 PixelOffice 파이프라인에서 자동 생성되었습니다.*
        """
        
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("[PipelineWikiService] 디자인 문서 저장 실패: \(error)")
            return nil
        }
    }
    
    /// 개발팀 문서 저장
    private func saveDevelopmentDocument(run: PipelineRun, projectName: String, dateString: String, summary: String) -> String? {
        let fileName = "\(dateString)-파이프라인-개발-\(summary).md"
        let path = dataPathService.documentPath(projectName: projectName, department: .development, fileName: fileName)
        
        var content = """
        # 💻 파이프라인 개발 변경 내역
        
        - **날짜**: \(dateString)
        - **실행 ID**: \(run.id.uuidString)
        - **상태**: \(run.state.rawValue)
        
        ---
        
        ## 📝 요구사항
        
        \(run.requirement)
        
        ---
        
        ## 📊 태스크 실행 결과
        
        """
        
        let devTasks = run.decomposedTasks.filter { $0.department == .development }
        let completedCount = devTasks.filter { $0.status == .completed }.count
        let failedCount = devTasks.filter { $0.status == .failed }.count
        
        content += """
        - **총 태스크**: \(devTasks.count)개
        - **완료**: \(completedCount)개 ✅
        - **실패**: \(failedCount)개 ❌
        
        """
        
        for (index, task) in devTasks.enumerated() {
            let statusIcon = task.status == .completed ? "✅" : (task.status == .failed ? "❌" : "⏳")
            let duration = task.duration.map { String(format: "%.1fs", $0) } ?? "-"
            content += """
            
            ### \(index + 1). \(task.title) \(statusIcon)
            
            - **소요시간**: \(duration)
            - **상태**: \(task.status.rawValue)
            
            \(task.description)
            
            """
            
            // 실패 시 에러 메시지
            if task.status == .failed, let error = task.error {
                content += """
                
                **에러:**
                ```
                \(error)
                ```
                
                """
            }
        }
        
        // Decision Log
        if !run.decisions.isEmpty {
            content += "\n---\n\n## 🧠 Decision Log\n\n"
            content += "AI가 내린 주요 결정들:\n\n"
            
            for (index, decision) in run.decisions.enumerated() {
                content += """
                
                ### 결정 \(index + 1)
                
                **결정**: \(decision.decision)
                
                **이유**: \(decision.reason)
                
                """
                
                if !decision.alternatives.isEmpty {
                    content += "**고려한 대안들:**\n"
                    for alt in decision.alternatives {
                        content += "- \(alt)\n"
                    }
                }
            }
        }
        
        // Git Diff 요약
        if let diff = run.gitDiff, !diff.isEmpty {
            content += "\n---\n\n## 🔀 Git 변경 사항\n\n"
            
            // 변경된 파일 수 추출
            let addedLines = diff.components(separatedBy: "\n").filter { $0.hasPrefix("+") && !$0.hasPrefix("+++") }.count
            let removedLines = diff.components(separatedBy: "\n").filter { $0.hasPrefix("-") && !$0.hasPrefix("---") }.count
            
            content += """
            - **추가된 라인**: +\(addedLines)
            - **삭제된 라인**: -\(removedLines)
            
            <details>
            <summary>전체 Diff 보기</summary>
            
            ```diff
            \(diff.prefix(10000))
            ```
            
            </details>
            
            """
        }
        
        content += """
        
        ---
        
        *이 문서는 PixelOffice 파이프라인에서 자동 생성되었습니다.*
        """
        
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("[PipelineWikiService] 개발 문서 저장 실패: \(error)")
            return nil
        }
    }
    
    /// QA팀 문서 저장
    private func saveQADocument(run: PipelineRun, projectName: String, dateString: String, summary: String) -> String? {
        // 빌드 시도가 없으면 스킵
        guard !run.buildAttempts.isEmpty else { return nil }
        
        let fileName = "\(dateString)-파이프라인-QA-\(summary).md"
        let path = dataPathService.documentPath(projectName: projectName, department: .qa, fileName: fileName)
        
        var content = """
        # 🧪 파이프라인 QA 리포트
        
        - **날짜**: \(dateString)
        - **실행 ID**: \(run.id.uuidString)
        - **최종 상태**: \(run.state.rawValue)
        
        ---
        
        ## 🔨 빌드 결과
        
        | # | 결과 | 소요시간 | 에러 수 | Self-Healing |
        |---|------|----------|---------|--------------|
        """
        
        for (index, attempt) in run.buildAttempts.enumerated() {
            let result = attempt.success ? "✅ 성공" : "❌ 실패"
            let duration = String(format: "%.1fs", attempt.duration)
            let healing = attempt.isHealingAttempt ? "🩹 Yes" : "-"
            content += "| \(index + 1) | \(result) | \(duration) | \(attempt.errors.count) | \(healing) |\n"
        }
        
        // 최종 빌드 상세
        if let lastAttempt = run.lastBuildAttempt {
            content += "\n---\n\n## 📋 최종 빌드 상세\n\n"
            
            if lastAttempt.success {
                content += "✅ **빌드 성공!**\n\n"
            } else {
                content += "❌ **빌드 실패**\n\n"
                
                // 에러 목록
                if !lastAttempt.errors.isEmpty {
                    content += "### 에러 목록\n\n"
                    
                    for (index, error) in lastAttempt.errors.prefix(20).enumerated() {
                        let icon = error.severity == .error ? "🔴" : (error.severity == .warning ? "🟡" : "🔵")
                        let location = error.location.isEmpty ? "" : " (`\(error.location)`)"
                        content += "\(index + 1). \(icon) \(error.message)\(location)\n"
                    }
                    
                    if lastAttempt.errors.count > 20 {
                        content += "\n*... 외 \(lastAttempt.errors.count - 20)개 에러*\n"
                    }
                }
            }
        }
        
        // Self-Healing 시도
        if run.healingAttempts > 0 {
            content += "\n---\n\n## 🩹 Self-Healing\n\n"
            content += "- **시도 횟수**: \(run.healingAttempts)/\(run.maxHealingAttempts)\n"
            content += "- **결과**: \(run.isBuildSuccessful ? "성공 ✅" : "실패 ❌")\n"
        }
        
        // 앱 실행 결과
        if let launchResult = run.appLaunchResult {
            content += "\n---\n\n## 🚀 앱 실행 결과\n\n"
            content += "- **플랫폼**: \(launchResult.platform.rawValue)\n"
            content += "- **결과**: \(launchResult.success ? "성공 ✅" : "실패 ❌")\n"
            
            if let simulatorName = launchResult.simulatorName {
                content += "- **시뮬레이터**: \(simulatorName)\n"
            }
        }
        
        content += """
        
        ---
        
        *이 문서는 PixelOffice 파이프라인에서 자동 생성되었습니다.*
        """
        
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("[PipelineWikiService] QA 문서 저장 실패: \(error)")
            return nil
        }
    }
}
