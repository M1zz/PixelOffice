import Foundation

/// 직원 업무 기록 관리 서비스
/// 각 직원의 프로필과 업무 히스토리를 MD 파일로 저장하고 관리
/// 저장 위치: 프로젝트 디렉토리/datas/_shared/people/ (전사 공용)
///           프로젝트 디렉토리/datas/[프로젝트]/[부서]/people/ (프로젝트별)
class EmployeeWorkLogService {
    static let shared = EmployeeWorkLogService()

    /// 업무 기록 저장 폴더 (전사 공용)
    var workLogPath: String {
        let path = "\(DataPathService.shared.sharedPath)/people"
        DataPathService.shared.createDirectoryIfNeeded(at: path)
        return path
    }

    private init() {
        // DataPathService가 기본 디렉토리 생성함
    }

    /// 직원의 업무 기록 파일 경로 (전사 공용)
    func getWorkLogFilePath(for employeeId: UUID, employeeName: String) -> String {
        return DataPathService.shared.globalEmployeeWorkLogPath(employeeName: employeeName, employeeId: employeeId)
    }

    /// 프로젝트 직원의 업무 기록 파일 경로
    func getProjectWorkLogFilePath(projectName: String, department: DepartmentType, employeeName: String) -> String {
        return DataPathService.shared.employeeWorkLogPath(projectName: projectName, department: department, employeeName: employeeName)
    }

    // MARK: - 직원 프로필 생성

    /// 직원 고용 시 프로필 파일 생성 (일반 직원)
    func createEmployeeProfile(employee: Employee, departmentType: DepartmentType) {
        let profile = EmployeeProfile(
            name: employee.name,
            aiType: employee.aiType,
            departmentType: departmentType,
            hireDate: employee.createdAt,
            appearance: employee.characterAppearance
        )

        var workLog = EmployeeWorkLog(
            employeeId: employee.id,
            employeeName: employee.name,
            departmentType: departmentType,
            profile: profile
        )

        // 초기 업무 항목 추가
        let entry = WorkEntry(
            title: "입사",
            summary: "\(departmentType.rawValue)팀에 입사했습니다.",
            details: nil,
            relatedProject: nil
        )
        workLog.entries.append(entry)

        saveWorkLog(workLog)
    }

    /// 프로젝트 직원 프로필 파일 생성
    func createProjectEmployeeProfile(employee: ProjectEmployee, projectName: String) {
        let profile = EmployeeProfile(
            name: employee.name,
            aiType: employee.aiType,
            departmentType: employee.departmentType,
            hireDate: employee.createdAt,
            appearance: employee.characterAppearance
        )

        var workLog = EmployeeWorkLog(
            employeeId: employee.id,
            employeeName: employee.name,
            departmentType: employee.departmentType,
            profile: profile
        )

        // 초기 업무 항목 추가
        let entry = WorkEntry(
            title: "프로젝트 배정",
            summary: "\(projectName) 프로젝트의 \(employee.departmentType.rawValue)팀에 배정되었습니다.",
            details: nil,
            relatedProject: projectName
        )
        workLog.entries.append(entry)

        saveProjectWorkLog(workLog, projectName: projectName, department: employee.departmentType)

        // 전사 기록에도 저장
        var globalWorkLog = loadWorkLog(for: employee.id, employeeName: employee.name)
        globalWorkLog.profile = profile
        globalWorkLog.departmentType = employee.departmentType
        globalWorkLog.entries.append(entry)
        saveWorkLog(globalWorkLog)
    }

    // MARK: - 대화 기록 동기화

    /// 일반 직원의 대화 기록을 MD 파일에 동기화
    func syncEmployeeConversations(employee: Employee, departmentType: DepartmentType) {
        var workLog = loadWorkLog(for: employee.id, employeeName: employee.name)

        // 프로필이 없으면 생성
        if workLog.profile == nil {
            workLog.profile = EmployeeProfile(
                name: employee.name,
                aiType: employee.aiType,
                departmentType: departmentType,
                hireDate: employee.createdAt,
                appearance: employee.characterAppearance
            )
        }

        workLog.departmentType = departmentType

        // 기존 대화 세션 수 계산
        let existingConversationCount = workLog.entries.filter { $0.title == "대화 세션" }.count

        // 대화 기록에서 새로운 세션 추출 (간단히 메시지를 그룹화)
        let messages = employee.conversationHistory
        if !messages.isEmpty && existingConversationCount == 0 {
            // 대화가 있지만 기록이 없으면 요약 생성
            let summary = summarizeConversation(messages: messages)
            let entry = WorkEntry(
                title: "대화 세션",
                summary: summary,
                details: "총 \(messages.count)개의 메시지",
                relatedProject: nil
            )
            workLog.entries.append(entry)
            workLog.profile?.totalConversations = 1
            workLog.profile?.lastActiveDate = messages.last?.timestamp ?? Date()
        }

        saveWorkLog(workLog)
    }

    /// 프로젝트 직원의 대화 기록을 MD 파일에 동기화
    func syncProjectEmployeeConversations(employee: ProjectEmployee, projectName: String) {
        var workLog = loadProjectWorkLog(
            projectName: projectName,
            department: employee.departmentType,
            employeeId: employee.id,
            employeeName: employee.name
        )

        // 프로필이 없으면 생성
        if workLog.profile == nil {
            workLog.profile = EmployeeProfile(
                name: employee.name,
                aiType: employee.aiType,
                departmentType: employee.departmentType,
                hireDate: employee.createdAt,
                appearance: employee.characterAppearance
            )
        }

        workLog.departmentType = employee.departmentType

        // 기존 대화 세션 수 계산
        let existingConversationCount = workLog.entries.filter { $0.title == "대화 세션" }.count

        // 대화 기록에서 새로운 세션 추출
        let messages = employee.conversationHistory
        if !messages.isEmpty && existingConversationCount == 0 {
            let summary = summarizeConversation(messages: messages)
            let entry = WorkEntry(
                title: "대화 세션",
                summary: summary,
                details: "총 \(messages.count)개의 메시지\n\n**프로젝트:** \(projectName)",
                relatedProject: projectName
            )
            workLog.entries.append(entry)
            workLog.profile?.totalConversations = 1
            workLog.profile?.lastActiveDate = messages.last?.timestamp ?? Date()
        }

        saveProjectWorkLog(workLog, projectName: projectName, department: employee.departmentType)

        // 전사 기록에도 동기화
        var globalWorkLog = loadWorkLog(for: employee.id, employeeName: employee.name)
        if globalWorkLog.profile == nil {
            globalWorkLog.profile = workLog.profile
        }
        globalWorkLog.departmentType = employee.departmentType

        let globalConversationCount = globalWorkLog.entries.filter { $0.title == "대화 세션" }.count
        if !messages.isEmpty && globalConversationCount == 0 {
            let summary = summarizeConversation(messages: messages)
            let entry = WorkEntry(
                title: "대화 세션",
                summary: summary,
                details: "총 \(messages.count)개의 메시지\n\n**프로젝트:** \(projectName)",
                relatedProject: projectName
            )
            globalWorkLog.entries.append(entry)
            globalWorkLog.profile?.totalConversations = 1
            globalWorkLog.profile?.lastActiveDate = messages.last?.timestamp ?? Date()
        }
        saveWorkLog(globalWorkLog)
    }

    /// 대화 내용 간단 요약
    private func summarizeConversation(messages: [Message]) -> String {
        guard !messages.isEmpty else { return "대화 없음" }

        let userMessages = messages.filter { $0.role == .user }
        let assistantMessages = messages.filter { $0.role == .assistant }

        if let firstUserMessage = userMessages.first {
            let preview = String(firstUserMessage.content.prefix(100))
            return "사용자와 \(messages.count)개의 메시지를 주고받음. 첫 질문: \"\(preview)...\""
        }

        return "총 \(messages.count)개의 메시지 (사용자: \(userMessages.count), AI: \(assistantMessages.count))"
    }

    // MARK: - 업무 기록 로드/저장

    /// 업무 기록 로드
    func loadWorkLog(for employeeId: UUID, employeeName: String) -> EmployeeWorkLog {
        let filePath = getWorkLogFilePath(for: employeeId, employeeName: employeeName)

        if FileManager.default.fileExists(atPath: filePath),
           let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            return parseWorkLog(from: content, employeeId: employeeId, employeeName: employeeName)
        }

        return EmployeeWorkLog(employeeId: employeeId, employeeName: employeeName)
    }

    /// 업무 기록 저장
    func saveWorkLog(_ workLog: EmployeeWorkLog) {
        let filePath = getWorkLogFilePath(for: workLog.employeeId, employeeName: workLog.employeeName)
        let content = workLog.toMarkdown()

        do {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            print("업무 기록 저장 실패: \(error)")
        }
    }

    /// 업무 항목 추가
    func addWorkEntry(
        for employeeId: UUID,
        employeeName: String,
        departmentType: DepartmentType,
        title: String,
        summary: String,
        details: String? = nil,
        relatedProject: String? = nil
    ) {
        var workLog = loadWorkLog(for: employeeId, employeeName: employeeName)
        workLog.departmentType = departmentType

        let entry = WorkEntry(
            title: title,
            summary: summary,
            details: details,
            relatedProject: relatedProject
        )
        workLog.entries.append(entry)

        saveWorkLog(workLog)
    }

    /// 대화 세션 요약 추가
    func addConversationSummary(
        for employeeId: UUID,
        employeeName: String,
        departmentType: DepartmentType,
        conversationSummary: String,
        keyPoints: [String],
        actionItems: [String],
        relatedProject: String? = nil
    ) {
        var workLog = loadWorkLog(for: employeeId, employeeName: employeeName)
        workLog.departmentType = departmentType

        // 대화 요약을 업무 항목으로 변환
        var details = ""
        if !keyPoints.isEmpty {
            details += "### 핵심 내용\n"
            for point in keyPoints {
                details += "- \(point)\n"
            }
            details += "\n"
        }
        if !actionItems.isEmpty {
            details += "### 액션 아이템\n"
            for item in actionItems {
                details += "- [ ] \(item)\n"
            }
        }

        let entry = WorkEntry(
            title: "대화 세션",
            summary: conversationSummary,
            details: details.isEmpty ? nil : details,
            relatedProject: relatedProject
        )
        workLog.entries.append(entry)

        // 프로필 업무 통계 업데이트
        workLog.profile?.totalConversations += 1
        workLog.profile?.lastActiveDate = Date()

        saveWorkLog(workLog)

        // 프로젝트가 있으면 프로젝트별 기록에도 저장
        if let projectName = relatedProject {
            saveToProjectWorkLog(
                projectName: projectName,
                department: departmentType,
                employeeId: employeeId,
                employeeName: employeeName,
                entry: entry
            )
        }
    }

    // MARK: - 프로젝트별 업무 기록

    /// 프로젝트별 업무 기록 로드
    func loadProjectWorkLog(projectName: String, department: DepartmentType, employeeId: UUID, employeeName: String) -> EmployeeWorkLog {
        let filePath = getProjectWorkLogFilePath(projectName: projectName, department: department, employeeName: employeeName)

        if FileManager.default.fileExists(atPath: filePath),
           let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            return parseWorkLog(from: content, employeeId: employeeId, employeeName: employeeName)
        }

        return EmployeeWorkLog(employeeId: employeeId, employeeName: employeeName, departmentType: department)
    }

    /// 프로젝트별 업무 기록 저장
    func saveProjectWorkLog(_ workLog: EmployeeWorkLog, projectName: String, department: DepartmentType) {
        let filePath = getProjectWorkLogFilePath(projectName: projectName, department: department, employeeName: workLog.employeeName)
        let content = workLog.toMarkdown()

        do {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            print("프로젝트 업무 기록 저장 실패: \(error)")
        }
    }

    /// 프로젝트별 업무 기록에 항목 저장
    private func saveToProjectWorkLog(projectName: String, department: DepartmentType, employeeId: UUID, employeeName: String, entry: WorkEntry) {
        var workLog = loadProjectWorkLog(projectName: projectName, department: department, employeeId: employeeId, employeeName: employeeName)
        workLog.departmentType = department
        workLog.entries.append(entry)

        // 프로필 업무 통계 업데이트
        workLog.profile?.totalConversations += 1
        workLog.profile?.lastActiveDate = Date()

        saveProjectWorkLog(workLog, projectName: projectName, department: department)
    }

    /// 프로젝트 직원 대화 세션 요약 추가
    func addProjectConversationSummary(
        projectName: String,
        department: DepartmentType,
        employeeId: UUID,
        employeeName: String,
        conversationSummary: String,
        keyPoints: [String],
        actionItems: [String]
    ) {
        var details = ""
        if !keyPoints.isEmpty {
            details += "### 핵심 내용\n"
            for point in keyPoints {
                details += "- \(point)\n"
            }
            details += "\n"
        }
        if !actionItems.isEmpty {
            details += "### 액션 아이템\n"
            for item in actionItems {
                details += "- [ ] \(item)\n"
            }
        }

        let entry = WorkEntry(
            title: "대화 세션",
            summary: conversationSummary,
            details: details.isEmpty ? nil : details,
            relatedProject: projectName
        )

        // 프로젝트별 기록에 저장
        saveToProjectWorkLog(projectName: projectName, department: department, employeeId: employeeId, employeeName: employeeName, entry: entry)

        // 전사 기록에도 저장
        var globalWorkLog = loadWorkLog(for: employeeId, employeeName: employeeName)
        globalWorkLog.departmentType = department
        globalWorkLog.entries.append(entry)
        globalWorkLog.profile?.totalConversations += 1
        globalWorkLog.profile?.lastActiveDate = Date()
        saveWorkLog(globalWorkLog)
    }

    /// 프로젝트 업무 기록 요약 (시스템 프롬프트용)
    func getProjectWorkLogSummary(projectName: String, department: DepartmentType, employeeId: UUID, employeeName: String, maxEntries: Int = 5) -> String {
        let workLog = loadProjectWorkLog(projectName: projectName, department: department, employeeId: employeeId, employeeName: employeeName)

        if workLog.entries.isEmpty {
            return ""
        }

        var summary = "📋 프로젝트 업무 기록 (\(projectName)):\n"
        let recentEntries = workLog.entries.suffix(maxEntries)

        for entry in recentEntries {
            summary += "- [\(entry.formattedDate)] \(entry.title): \(entry.summary)\n"
        }

        return summary
    }

    /// 업무 기록 MD 내용 파싱
    private func parseWorkLog(from content: String, employeeId: UUID, employeeName: String) -> EmployeeWorkLog {
        // 기본 workLog 생성
        var workLog = EmployeeWorkLog(employeeId: employeeId, employeeName: employeeName)

        // 간단한 파싱 - 실제로는 더 정교한 파싱이 필요할 수 있음
        let lines = content.components(separatedBy: "\n")
        var currentEntry: WorkEntry?
        var currentDetails = ""

        for line in lines {
            if line.hasPrefix("## ") && line.contains("[") {
                // 새 업무 항목 시작
                if let entry = currentEntry {
                    var finalEntry = entry
                    if !currentDetails.isEmpty {
                        finalEntry.details = currentDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    workLog.entries.append(finalEntry)
                }

                // 날짜와 제목 파싱
                let title = line.replacingOccurrences(of: "## ", with: "")
                    .components(separatedBy: " [").first ?? "업무"
                currentEntry = WorkEntry(title: title, summary: "")
                currentDetails = ""
            } else if line.hasPrefix("> ") {
                // 요약
                currentEntry?.summary = line.replacingOccurrences(of: "> ", with: "")
            } else if line.hasPrefix("**프로젝트:**") {
                currentEntry?.relatedProject = line.replacingOccurrences(of: "**프로젝트:** ", with: "")
            } else if !line.isEmpty && currentEntry != nil {
                currentDetails += line + "\n"
            }
        }

        // 마지막 항목 추가
        if let entry = currentEntry {
            var finalEntry = entry
            if !currentDetails.isEmpty {
                finalEntry.details = currentDetails.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            workLog.entries.append(finalEntry)
        }

        return workLog
    }

    /// 업무 기록 요약 (시스템 프롬프트용)
    func getWorkLogSummary(for employeeId: UUID, employeeName: String, maxEntries: Int = 5) -> String {
        let workLog = loadWorkLog(for: employeeId, employeeName: employeeName)

        if workLog.entries.isEmpty {
            return ""
        }

        var summary = "📋 이전 업무 기록:\n"
        let recentEntries = workLog.entries.suffix(maxEntries)

        for entry in recentEntries {
            summary += "- [\(entry.formattedDate)] \(entry.title): \(entry.summary)\n"
        }

        return summary
    }
}

// MARK: - 직원 프로필

/// 직원 프로필 정보
struct EmployeeProfile {
    var name: String
    var aiType: AIType
    var departmentType: DepartmentType
    var hireDate: Date
    var appearance: CharacterAppearance

    // 업무 통계
    var totalConversations: Int = 0
    var lastActiveDate: Date?

    // 외모 설명
    var appearanceDescription: String {
        var desc = ""

        // 피부톤
        let skinTones = ["밝은", "중간 밝은", "중간", "어두운"]
        desc += "\(skinTones[min(appearance.skinTone, skinTones.count - 1)]) 피부톤, "

        // 헤어스타일
        let hairStyles = ["짧은 머리", "중간 머리", "긴 머리", "뾰족한 머리", "민머리"]
        desc += "\(hairStyles[min(appearance.hairStyle, hairStyles.count - 1)]), "

        // 머리색
        let hairColors = ["검은색", "갈색", "밝은 갈색", "금발", "빨간색", "회색"]
        if appearance.hairStyle != 4 {  // 민머리가 아니면
            desc += "\(hairColors[min(appearance.hairColor, hairColors.count - 1)]) 머리카락, "
        }

        // 셔츠 색
        let shirtColors = ["흰색", "파란색", "빨간색", "초록색", "보라색", "주황색", "분홍색", "회색"]
        desc += "\(shirtColors[min(appearance.shirtColor, shirtColors.count - 1)]) 셔츠"

        // 악세서리
        let accessories = ["", ", 안경 착용", ", 모자 착용", ", 헤드폰 착용"]
        desc += accessories[min(appearance.accessory, accessories.count - 1)]

        return desc
    }

    /// 마크다운으로 변환
    func toMarkdown() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy년 MM월 dd일"

        var md = "## 👤 프로필\n\n"
        md += "| 항목 | 내용 |\n"
        md += "|------|------|\n"
        md += "| **이름** | \(name) |\n"
        md += "| **AI 유형** | \(aiType.rawValue) |\n"
        md += "| **부서** | \(departmentType.rawValue)팀 |\n"
        md += "| **입사일** | \(dateFormatter.string(from: hireDate)) |\n"
        md += "| **총 대화 수** | \(totalConversations)회 |\n"

        if let lastActive = lastActiveDate {
            md += "| **마지막 활동** | \(dateFormatter.string(from: lastActive)) |\n"
        }

        md += "\n### 외모\n\n"
        md += "\(appearanceDescription)\n\n"

        return md
    }
}

// MARK: - 업무 기록

/// 직원 업무 기록
struct EmployeeWorkLog {
    var employeeId: UUID
    var employeeName: String
    var departmentType: DepartmentType?
    var profile: EmployeeProfile?
    var entries: [WorkEntry]

    init(employeeId: UUID, employeeName: String, departmentType: DepartmentType? = nil, profile: EmployeeProfile? = nil, entries: [WorkEntry] = []) {
        self.employeeId = employeeId
        self.employeeName = employeeName
        self.departmentType = departmentType
        self.profile = profile
        self.entries = entries
    }

    /// 마크다운으로 변환
    func toMarkdown() -> String {
        var md = "# \(employeeName)\n\n"

        // 프로필 섹션
        if let profile = profile {
            md += profile.toMarkdown()
        } else if let dept = departmentType {
            md += "**부서:** \(dept.rawValue)팀\n\n"
        }

        md += "---\n\n"
        md += "## 📋 업무 기록\n\n"

        if entries.isEmpty {
            md += "*아직 업무 기록이 없습니다.*\n\n"
        } else {
            for entry in entries.reversed() {  // 최신순
                md += "### \(entry.title) [\(entry.formattedDate)]\n\n"
                md += "> \(entry.summary)\n\n"

                if let project = entry.relatedProject {
                    md += "**프로젝트:** \(project)\n\n"
                }

                if let details = entry.details, !details.isEmpty {
                    md += details + "\n\n"
                }

                md += "---\n\n"
            }
        }

        return md
    }
}

/// 업무 항목
struct WorkEntry: Identifiable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var title: String
    var summary: String
    var details: String?
    var relatedProject: String?

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: timestamp)
    }
}

/// 업무 기록 윈도우용 데이터
struct EmployeeWorkLogData: Codable, Hashable {
    let employeeId: UUID
    let employeeName: String
}

/// 프로젝트 직원 업무 기록 윈도우용 데이터
struct ProjectEmployeeWorkLogData: Codable, Hashable {
    let employeeId: UUID
    let employeeName: String
    let projectName: String
    let departmentType: DepartmentType
}
