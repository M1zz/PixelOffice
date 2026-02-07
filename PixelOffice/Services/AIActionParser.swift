import Foundation

/// AI 응답에서 특수 액션을 파싱하고 실행하는 서비스
actor AIActionParser {
    static let shared = AIActionParser()

    private init() {}

    /// AI 응답을 파싱하여 액션 추출
    func parseActions(from response: String) -> [AIAction] {
        var actions: [AIAction] = []

        // 1. 위키 문서 생성 파싱
        actions.append(contentsOf: parseWikiDocuments(from: response))

        // 2. 태스크 생성 파싱
        actions.append(contentsOf: parseTasks(from: response))

        // 3. 태스크 상태 변경 파싱
        actions.append(contentsOf: parseTaskStatusUpdates(from: response))

        // 4. 멘션 파싱
        actions.append(contentsOf: parseMentions(from: response))

        // 5. 협업 기록 파싱
        actions.append(contentsOf: parseCollaborations(from: response))

        // 6. 직접 메시지 파싱
        actions.append(contentsOf: parseDirectMessages(from: response))

        return actions
    }

    /// 위키 문서 생성 파싱
    /// 포맷: [CREATE_WIKI: 제목 | 카테고리]\n내용\n[/CREATE_WIKI]
    private func parseWikiDocuments(from text: String) -> [AIAction] {
        var actions: [AIAction] = []

        let pattern = #"\[CREATE_WIKI:\s*([^\|\]]+)\s*\|\s*(\w+)\]([\s\S]*?)\[\/CREATE_WIKI\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return actions }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard match.numberOfRanges == 4,
                  let titleRange = Range(match.range(at: 1), in: text),
                  let categoryRange = Range(match.range(at: 2), in: text),
                  let contentRange = Range(match.range(at: 3), in: text) else {
                continue
            }

            let title = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let categoryStr = String(text[categoryRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let content = String(text[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            let category = WikiCategory(rawValue: categoryStr) ?? .reference

            actions.append(.createWiki(title: title, content: content, category: category))
        }

        return actions
    }

    /// 태스크 생성 파싱
    /// 포맷: [CREATE_TASK]\n제목: ...\n설명: ...\n우선순위: ...\n예상시간: ...\n태그: ...\n[/CREATE_TASK]
    private func parseTasks(from text: String) -> [AIAction] {
        var actions: [AIAction] = []

        let pattern = #"\[CREATE_TASK\]([\s\S]*?)\[\/CREATE_TASK\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return actions }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard match.numberOfRanges == 2,
                  let contentRange = Range(match.range(at: 1), in: text) else {
                continue
            }

            let content = String(text[contentRange])
            let lines = content.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            var title: String?
            var description: String?
            var priority: TaskPriority = .medium
            var estimatedHours: Double?
            var tags: [String] = []

            for line in lines where !line.isEmpty {
                if line.hasPrefix("제목:") || line.hasPrefix("Title:") {
                    title = line.replacingOccurrences(of: "제목:", with: "")
                        .replacingOccurrences(of: "Title:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("설명:") || line.hasPrefix("Description:") {
                    description = line.replacingOccurrences(of: "설명:", with: "")
                        .replacingOccurrences(of: "Description:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("우선순위:") || line.hasPrefix("Priority:") {
                    let priorityStr = line.replacingOccurrences(of: "우선순위:", with: "")
                        .replacingOccurrences(of: "Priority:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                        .lowercased()
                    if priorityStr.contains("high") || priorityStr.contains("높음") {
                        priority = .high
                    } else if priorityStr.contains("low") || priorityStr.contains("낮음") {
                        priority = .low
                    }
                } else if line.hasPrefix("예상시간:") || line.hasPrefix("EstimatedHours:") {
                    let hoursStr = line.replacingOccurrences(of: "예상시간:", with: "")
                        .replacingOccurrences(of: "EstimatedHours:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    estimatedHours = Double(hoursStr)
                } else if line.hasPrefix("태그:") || line.hasPrefix("Tags:") {
                    let tagsStr = line.replacingOccurrences(of: "태그:", with: "")
                        .replacingOccurrences(of: "Tags:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    tags = tagsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
            }

            if let title = title, let description = description {
                actions.append(.createTask(
                    title: title,
                    description: description,
                    priority: priority,
                    estimatedHours: estimatedHours,
                    tags: tags
                ))
            }
        }

        return actions
    }

    /// 멘션 파싱
    /// 포맷: @부서명 메시지 또는 @직원명 메시지
    private func parseMentions(from text: String) -> [AIAction] {
        var actions: [AIAction] = []

        // @부서명 또는 @직원명 패턴
        let pattern = #"@([\p{L}\p{N}]+)\s+([^\n@]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return actions }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard match.numberOfRanges == 3,
                  let targetRange = Range(match.range(at: 1), in: text),
                  let messageRange = Range(match.range(at: 2), in: text) else {
                continue
            }

            let target = String(text[targetRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let message = String(text[messageRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            // 부서명인지 직원명인지 판단
            let departmentNames = ["기획팀", "디자인팀", "개발팀", "QA팀", "마케팅팀", "일반팀"]
            let isDepartment = departmentNames.contains { target.contains($0) }

            actions.append(.mention(
                targetType: isDepartment ? .department : .employee,
                targetName: target,
                message: message
            ))
        }

        return actions
    }

    /// 태스크 상태 변경 파싱
    /// 포맷: [UPDATE_TASK: 태스크제목 | 상태] 또는 자연어
    private func parseTaskStatusUpdates(from text: String) -> [AIAction] {
        var actions: [AIAction] = []

        // 1. 태그 형식: [UPDATE_TASK: 태스크제목 | 상태]
        let tagPattern = #"\[UPDATE_TASK:\s*([^\|\]]+)\s*\|\s*([^\]]+)\]"#
        if let tagRegex = try? NSRegularExpression(pattern: tagPattern) {
            let matches = tagRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                guard match.numberOfRanges == 3,
                      let titleRange = Range(match.range(at: 1), in: text),
                      let statusRange = Range(match.range(at: 2), in: text) else {
                    continue
                }

                let title = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let statusStr = String(text[statusRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                if let status = parseTaskStatus(from: statusStr) {
                    actions.append(.updateTaskStatus(taskTitle: title, newStatus: status))
                }
            }
        }

        // 2. 자연어 형식: "~~ 태스크 시작합니다" 또는 "~~ 완료했습니다"
        let naturalPatterns: [(pattern: String, status: TaskStatus)] = [
            (#"['\""]?([^'\""\n]+)['\""]?\s*(태스크|작업)?\s*(시작합니다|시작할게요|시작하겠습니다|착수합니다)"#, .inProgress),
            (#"['\""]?([^'\""\n]+)['\""]?\s*(태스크|작업)?\s*(완료했습니다|완료합니다|끝났습니다|마쳤습니다)"#, .done),
            (#"['\""]?([^'\""\n]+)['\""]?\s*(태스크|작업)?\s*(검토\s*부탁|리뷰\s*부탁|확인\s*부탁)"#, .needsReview),
            (#"(이\s*태스크|이\s*작업|해당\s*태스크|해당\s*작업)\s*(시작합니다|시작할게요|시작하겠습니다)"#, .inProgress),
            (#"(이\s*태스크|이\s*작업|해당\s*태스크|해당\s*작업)\s*(완료했습니다|완료합니다|끝났습니다)"#, .done),
        ]

        for (pattern, status) in naturalPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if match.numberOfRanges >= 2,
                       let titleRange = Range(match.range(at: 1), in: text) {
                        let title = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        // "이 태스크" 같은 지시어는 현재 컨텍스트 태스크 의미 (빈 문자열로)
                        let cleanTitle = title.contains("태스크") || title.contains("작업") ? "" : title
                        actions.append(.updateTaskStatus(taskTitle: cleanTitle, newStatus: status))
                    }
                }
            }
        }

        return actions
    }

    /// 상태 문자열을 TaskStatus로 변환
    private func parseTaskStatus(from str: String) -> TaskStatus? {
        let lowered = str.lowercased()
        if lowered.contains("백로그") || lowered.contains("backlog") {
            return .backlog
        } else if lowered.contains("할일") || lowered.contains("todo") {
            return .todo
        } else if lowered.contains("진행") || lowered.contains("progress") || lowered.contains("시작") {
            return .inProgress
        } else if lowered.contains("완료") || lowered.contains("done") || lowered.contains("끝") {
            return .done
        } else if lowered.contains("검토") || lowered.contains("리뷰") || lowered.contains("review") {
            return .needsReview
        } else if lowered.contains("반려") || lowered.contains("reject") {
            return .rejected
        }
        return nil
    }

    /// 직접 메시지 파싱
    /// 포맷: [DIRECT_MESSAGE]\n메시지내용\n[/DIRECT_MESSAGE]
    private func parseDirectMessages(from text: String) -> [AIAction] {
        var actions: [AIAction] = []

        let pattern = #"\[DIRECT_MESSAGE\]([\s\S]*?)\[\/DIRECT_MESSAGE\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return actions }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard match.numberOfRanges == 2,
                  let contentRange = Range(match.range(at: 1), in: text) else {
                continue
            }

            let message = String(text[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty {
                actions.append(.directMessage(toUser: true, message: message))
            }
        }

        return actions
    }

    /// 협업 기록 파싱
    /// 포맷: [COLLABORATION: 제목]\n참여부서: ...\n내용: ...\n결과: ...\n[/COLLABORATION]
    private func parseCollaborations(from text: String) -> [AIAction] {
        var actions: [AIAction] = []

        let pattern = #"\[COLLABORATION:\s*([^\]]+)\]([\s\S]*?)\[\/COLLABORATION\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return actions }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard match.numberOfRanges == 3,
                  let titleRange = Range(match.range(at: 1), in: text),
                  let contentRange = Range(match.range(at: 2), in: text) else {
                continue
            }

            let title = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let content = String(text[contentRange])
            let lines = content.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            var departments: [String] = []
            var contentText = ""
            var outcome = ""

            for line in lines where !line.isEmpty {
                if line.hasPrefix("참여부서:") || line.hasPrefix("Departments:") {
                    let deptStr = line.replacingOccurrences(of: "참여부서:", with: "")
                        .replacingOccurrences(of: "Departments:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    departments = deptStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                } else if line.hasPrefix("내용:") || line.hasPrefix("Content:") {
                    contentText = line.replacingOccurrences(of: "내용:", with: "")
                        .replacingOccurrences(of: "Content:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("결과:") || line.hasPrefix("Outcome:") {
                    outcome = line.replacingOccurrences(of: "결과:", with: "")
                        .replacingOccurrences(of: "Outcome:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
            }

            if !departments.isEmpty {
                actions.append(.createCollaboration(
                    title: title,
                    departments: departments,
                    content: contentText,
                    outcome: outcome
                ))
            }
        }

        return actions
    }

    /// 액션을 실제로 실행
    func executeActions(
        _ actions: [AIAction],
        projectId: UUID?,
        employeeId: UUID,
        companyStore: CompanyStore
    ) async {
        for action in actions {
            await executeAction(action, projectId: projectId, employeeId: employeeId, companyStore: companyStore)
        }
    }

    private func executeAction(
        _ action: AIAction,
        projectId: UUID?,
        employeeId: UUID,
        companyStore: CompanyStore
    ) async {
        switch action {
        case .createWiki(let title, let content, let category):
            await createWikiDocument(title: title, content: content, category: category, projectId: projectId, companyStore: companyStore)

        case .createTask(let title, let description, let priority, let estimatedHours, let tags):
            await createTask(title: title, description: description, priority: priority, estimatedHours: estimatedHours, tags: tags, projectId: projectId, companyStore: companyStore)

        case .updateTaskStatus(let taskTitle, let newStatus):
            await updateTaskStatus(taskTitle: taskTitle, newStatus: newStatus, projectId: projectId, employeeId: employeeId, companyStore: companyStore)

        case .mention(let targetType, let targetName, let message):
            await processMention(targetType: targetType, targetName: targetName, message: message, fromEmployeeId: employeeId, companyStore: companyStore)

        case .createCollaboration(let title, let departments, let content, let outcome):
            await createCollaboration(title: title, departments: departments, content: content, outcome: outcome, companyStore: companyStore)

        case .directMessage(let toUser, let message):
            await sendDirectMessage(toUser: toUser, message: message, fromEmployeeId: employeeId, companyStore: companyStore)
        }
    }

    // MARK: - 실제 실행 로직

    private func createWikiDocument(
        title: String,
        content: String,
        category: WikiCategory,
        projectId: UUID?,
        companyStore: CompanyStore
    ) async {
        let document = WikiDocument(
            title: title,
            content: content,
            category: category
        )

        // 위키 경로 결정
        let wikiPath: String
        if let projectId = projectId {
            // 프로젝트 위키 경로 (동기적으로 가져오기)
            let projectName = await MainActor.run {
                companyStore.company.projects.first(where: { $0.id == projectId })?.name ?? "Unknown"
            }
            wikiPath = DataPathService.shared.projectWikiPath(projectName)
        } else {
            // 전사 공용 위키 경로
            wikiPath = "\(DataPathService.shared.sharedPath)/wiki"
            DataPathService.shared.createDirectoryIfNeeded(at: wikiPath)
        }

        // 위키 문서 저장
        try? WikiService.shared.saveDocument(document, at: wikiPath)
        await MainActor.run {
            companyStore.addWikiDocument(document)
        }
    }

    private func createTask(
        title: String,
        description: String,
        priority: TaskPriority,
        estimatedHours: Double?,
        tags: [String],
        projectId: UUID?,
        companyStore: CompanyStore
    ) async {
        guard let projectId = projectId else { return }

        let task = ProjectTask(
            title: title,
            description: description,
            status: .todo,
            estimatedHours: estimatedHours,
            prompt: description
        )

        await MainActor.run {
            companyStore.addTask(task, toProject: projectId)
        }
    }

    private func processMention(
        targetType: MentionTargetType,
        targetName: String,
        message: String,
        fromEmployeeId: UUID,
        companyStore: CompanyStore
    ) async {
        // TODO: 실제 멘션 알림 시스템 구현
        print("[Mention] \(targetType == .department ? "부서" : "직원"): \(targetName) - \(message)")

        // 알림으로 기록할 수 있도록 추가 (향후 구현)
        // companyStore.addNotification(...)
    }

    private func createCollaboration(
        title: String,
        departments: [String],
        content: String,
        outcome: String,
        companyStore: CompanyStore
    ) async {
        // TODO: 협업 기록 저장 구현
        // 현재는 콘솔에만 출력
        print("[Collaboration] \(title)")
        print("  Departments: \(departments.joined(separator: ", "))")
        print("  Content: \(content)")
        print("  Outcome: \(outcome)")
    }

    /// 태스크 상태 변경
    private func updateTaskStatus(
        taskTitle: String,
        newStatus: TaskStatus,
        projectId: UUID?,
        employeeId: UUID,
        companyStore: CompanyStore
    ) async {
        guard let projectId = projectId else {
            print("⚠️ [TaskStatus] 프로젝트 ID가 없어서 태스크 상태를 변경할 수 없습니다")
            return
        }

        await MainActor.run {
            // 태스크 찾기 (제목 또는 담당자로)
            guard let project = companyStore.company.projects.first(where: { $0.id == projectId }) else {
                print("⚠️ [TaskStatus] 프로젝트를 찾을 수 없습니다")
                return
            }

            var targetTask: ProjectTask?

            if taskTitle.isEmpty {
                // 제목이 비어있으면 현재 직원에게 할당된 진행중 태스크 찾기
                targetTask = project.tasks.first(where: { $0.assigneeId == employeeId && $0.status == .inProgress })
                    ?? project.tasks.first(where: { $0.assigneeId == employeeId && $0.status == .todo })
            } else {
                // 제목으로 태스크 찾기 (부분 일치)
                targetTask = project.tasks.first(where: {
                    $0.title.contains(taskTitle) || taskTitle.contains($0.title)
                })
            }

            guard var task = targetTask else {
                print("⚠️ [TaskStatus] 태스크를 찾을 수 없습니다: \(taskTitle)")
                return
            }

            let oldStatus = task.status
            task.status = newStatus
            task.updatedAt = Date()

            if newStatus == .done {
                task.completedAt = Date()
            }

            companyStore.updateTask(task, inProject: projectId)
            print("✅ [TaskStatus] '\(task.title)' 상태 변경: \(oldStatus.rawValue) → \(newStatus.rawValue)")
        }
    }

    /// 사용자에게 직접 메시지 전송
    private func sendDirectMessage(
        toUser: Bool,
        message: String,
        fromEmployeeId: UUID,
        companyStore: CompanyStore
    ) async {
        guard toUser else { return }

        await MainActor.run {
            // 직원 정보 찾기
            let employeeName = companyStore.findEmployee(byId: fromEmployeeId)?.name ?? "AI 직원"

            // 알림으로 표시 (ToastManager 사용)
            print("💬 [DirectMessage] \(employeeName): \(message)")

            // 커뮤니티 게시글로 등록 (사용자에게 직접 전달)
            let post = CommunityPost(
                employeeId: fromEmployeeId,
                employeeName: employeeName,
                departmentType: .general,
                thinkingId: nil,
                title: "💬 \(employeeName)님의 메시지",
                content: message,
                summary: message,
                tags: ["직접메시지"]
            )
            companyStore.addCommunityPost(post, autoComment: false)
        }
    }
}

/// AI가 수행할 수 있는 액션
enum AIAction {
    case createWiki(title: String, content: String, category: WikiCategory)
    case createTask(title: String, description: String, priority: TaskPriority, estimatedHours: Double?, tags: [String])
    case updateTaskStatus(taskTitle: String, newStatus: TaskStatus)
    case mention(targetType: MentionTargetType, targetName: String, message: String)
    case createCollaboration(title: String, departments: [String], content: String, outcome: String)
    case directMessage(toUser: Bool, message: String)  // 사용자에게 직접 메시지
}

/// 멘션 대상 유형
enum MentionTargetType {
    case department
    case employee
}
