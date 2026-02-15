//
//  TaskTrackingService.swift
//  PixelOffice
//
//  Created by Pipeline on 2026-02-15.
//
//  직원과의 대화 및 파이프라인 실행 중 태스크 자동 추적
//

import Foundation

/// 태스크 자동 추적 서비스
/// - 직원 대화에서 작업 완료 감지
/// - 파이프라인 실행 중 태스크 기록
/// - 칸반 보드 자동 업데이트
class TaskTrackingService {
    static let shared = TaskTrackingService()
    
    private init() {}
    
    // MARK: - Task Creation from Chat
    
    /// 대화 내용에서 태스크 완료 감지 및 기록
    /// - Parameters:
    ///   - message: AI 응답 메시지
    ///   - employee: 담당 직원
    ///   - project: 프로젝트
    ///   - companyStore: CompanyStore 참조
    @MainActor
    func detectAndTrackTask(
        from message: String,
        employee: ProjectEmployee,
        project: Project,
        companyStore: CompanyStore
    ) {
        // 작업 완료 패턴 감지
        let completionPatterns = [
            "완료했습니다",
            "완료됐습니다",
            "작성했습니다",
            "구현했습니다",
            "만들었습니다",
            "생성했습니다",
            "저장했습니다",
            "커밋했습니다",
            "파일을 생성",
            "문서를 작성",
            "코드를 작성"
        ]
        
        let hasCompletion = completionPatterns.contains { message.contains($0) }
        guard hasCompletion else { return }
        
        // 태스크 정보 추출
        let taskInfo = extractTaskInfo(from: message, employee: employee)
        
        guard let title = taskInfo.title else {
            print("[TaskTrackingService] 태스크 제목을 추출할 수 없음")
            return
        }
        
        // 태스크 생성
        let task = ProjectTask(
            title: title,
            description: taskInfo.description ?? "",
            status: .done,
            priority: .medium,
            assigneeId: employee.id,
            departmentType: employee.departmentType,
            outputs: taskInfo.outputs,
            completedAt: Date()
        )
        
        // 프로젝트에 태스크 추가
        addTaskToProject(task, project: project, companyStore: companyStore)
        
        // 파일로도 저장
        TaskFileSyncService.shared.saveTaskToFile(task, project: project)
        
        print("[TaskTrackingService] ✅ 태스크 자동 기록: \(title) by \(employee.name)")
    }
    
    /// 파이프라인 태스크 완료 시 기록
    @MainActor
    func trackPipelineTask(
        phase: String,
        taskName: String,
        employee: ProjectEmployee?,
        outputs: [String],
        project: Project,
        companyStore: CompanyStore
    ) {
        let outputList = outputs.map { filePath in
            TaskOutput(
                type: filePath.hasSuffix(".swift") ? .code : .document,
                content: filePath,
                fileName: (filePath as NSString).lastPathComponent
            )
        }
        
        let task = ProjectTask(
            title: "[\(phase)] \(taskName)",
            description: "파이프라인에서 자동 생성된 태스크",
            status: .done,
            priority: .medium,
            assigneeId: employee?.id,
            departmentType: DepartmentType(rawValue: phase) ?? .general,
            outputs: outputList,
            completedAt: Date()
        )
        
        addTaskToProject(task, project: project, companyStore: companyStore)
        TaskFileSyncService.shared.saveTaskToFile(task, project: project)
        
        print("[TaskTrackingService] 📋 파이프라인 태스크 기록: \(taskName)")
    }
    
    // MARK: - Task Info Extraction
    
    private struct TaskInfo {
        var title: String?
        var description: String?
        var outputs: [TaskOutput] = []
    }
    
    private func extractTaskInfo(from message: String, employee: ProjectEmployee) -> TaskInfo {
        var info = TaskInfo()
        
        // 파일 경로 추출 (백틱 또는 경로 패턴)
        let pathPatterns = [
            "`([^`]+\\.(swift|md|json|yaml|txt))`",  // 백틱 안의 파일
            "(/[\\w\\-/]+\\.(swift|md|json))",        // 절대 경로
            "([\\w\\-]+/[\\w\\-/]+\\.(swift|md))"     // 상대 경로
        ]
        
        for pattern in pathPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: message, options: [], range: NSRange(message.startIndex..., in: message))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: message) {
                        let filePath = String(message[range])
                        let type: OutputType = filePath.hasSuffix(".swift") ? .code : .document
                        info.outputs.append(TaskOutput(
                            type: type,
                            content: filePath,
                            fileName: (filePath as NSString).lastPathComponent
                        ))
                    }
                }
            }
        }
        
        // 제목 추출 (첫 줄 또는 "~를 완료" 패턴)
        let lines = message.components(separatedBy: .newlines)
        
        // "~를 완료했습니다" 패턴에서 제목 추출
        let completionPatterns = [
            "(.+)를 완료했습니다",
            "(.+)를 작성했습니다",
            "(.+)를 구현했습니다",
            "(.+)를 생성했습니다"
        ]
        
        for pattern in completionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                if let match = regex.firstMatch(in: message, options: [], range: NSRange(message.startIndex..., in: message)) {
                    if let range = Range(match.range(at: 1), in: message) {
                        info.title = String(message[range]).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            }
        }
        
        // 제목이 없으면 산출물에서 추측
        if info.title == nil && !info.outputs.isEmpty {
            let firstOutput = info.outputs[0].content
            let fileName = (firstOutput as NSString).lastPathComponent
            let baseName = (fileName as NSString).deletingPathExtension
            info.title = "\(baseName) 작성"
        }
        
        // 그래도 없으면 기본 제목
        if info.title == nil {
            info.title = "\(employee.departmentType.rawValue) 작업 완료"
        }
        
        // 설명: 첫 몇 줄
        info.description = lines.prefix(3).joined(separator: "\n")
        
        return info
    }
    
    // MARK: - Helpers
    
    @MainActor
    private func addTaskToProject(_ task: ProjectTask, project: Project, companyStore: CompanyStore) {
        guard let projectIndex = companyStore.company.projects.firstIndex(where: { $0.id == project.id }) else {
            print("[TaskTrackingService] ⚠️ 프로젝트를 찾을 수 없음: \(project.name)")
            return
        }
        
        // 중복 체크
        let isDuplicate = companyStore.company.projects[projectIndex].tasks.contains {
            $0.title == task.title && $0.departmentType == task.departmentType
        }
        
        if !isDuplicate {
            companyStore.company.projects[projectIndex].tasks.append(task)
        }
    }
}

// MARK: - Task Activity Log

/// 태스크 활동 로그 (누가 무엇을 했는지 추적)
struct TaskActivity: Codable, Identifiable {
    var id: UUID = UUID()
    var taskId: UUID
    var employeeId: UUID
    var employeeName: String
    var departmentType: DepartmentType
    var action: TaskAction
    var timestamp: Date
    var details: String?
    
    enum TaskAction: String, Codable {
        case created = "생성"
        case started = "시작"
        case completed = "완료"
        case reviewed = "검토"
        case commented = "코멘트"
        case fileCreated = "파일 생성"
        case fileModified = "파일 수정"
    }
}

/// 태스크 활동 로그 관리
class TaskActivityLog {
    static let shared = TaskActivityLog()
    
    private var activities: [TaskActivity] = []
    private let fileManager = FileManager.default
    
    private init() {
        loadActivities()
    }
    
    func log(
        taskId: UUID,
        employee: ProjectEmployee,
        action: TaskActivity.TaskAction,
        details: String? = nil
    ) {
        let activity = TaskActivity(
            taskId: taskId,
            employeeId: employee.id,
            employeeName: employee.name,
            departmentType: employee.departmentType,
            action: action,
            timestamp: Date(),
            details: details
        )
        
        activities.append(activity)
        saveActivities()
        
        print("[TaskActivityLog] 📝 \(employee.name) (\(employee.departmentType.rawValue)): \(action.rawValue)")
    }
    
    func getActivities(for taskId: UUID) -> [TaskActivity] {
        activities.filter { $0.taskId == taskId }
    }
    
    func getActivities(by employeeId: UUID) -> [TaskActivity] {
        activities.filter { $0.employeeId == employeeId }
    }
    
    func getActivities(in department: DepartmentType) -> [TaskActivity] {
        activities.filter { $0.departmentType == department }
    }
    
    func getRecentActivities(limit: Int = 50) -> [TaskActivity] {
        Array(activities.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
    
    // MARK: - Persistence
    
    private var logFilePath: String {
        "\(DataPathService.shared.sharedPath)/task_activities.json"
    }
    
    private func loadActivities() {
        guard fileManager.fileExists(atPath: logFilePath),
              let data = fileManager.contents(atPath: logFilePath) else {
            return
        }
        
        do {
            activities = try JSONDecoder().decode([TaskActivity].self, from: data)
        } catch {
            print("[TaskActivityLog] ⚠️ 로드 실패: \(error)")
        }
    }
    
    private func saveActivities() {
        do {
            let data = try JSONEncoder().encode(activities)
            try data.write(to: URL(fileURLWithPath: logFilePath))
        } catch {
            print("[TaskActivityLog] ⚠️ 저장 실패: \(error)")
        }
    }
}
