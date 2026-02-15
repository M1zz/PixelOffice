//
//  TaskFileSyncService.swift
//  PixelOffice
//
//  Created by Pipeline on 2026-02-15.
//
//  태스크 파일(*/tasks/*.md) ↔ 칸반 양방향 동기화 서비스
//

import Foundation

/// 태스크 파일과 칸반 보드를 동기화하는 서비스
class TaskFileSyncService {
    static let shared = TaskFileSyncService()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Public API
    
    /// 프로젝트의 tasks 폴더에서 태스크 파일을 읽어 칸반에 동기화
    @MainActor
    func syncTasksFromFiles(project: Project, companyStore: CompanyStore) -> SyncResult {
        var result = SyncResult()
        let projectPath = DataPathService.shared.projectPath(project.name)
        
        // 모든 부서의 tasks 폴더 스캔
        for department in DepartmentType.allCases {
            let tasksPath = "\(projectPath)/\(department.directoryName)/tasks"
            
            guard fileManager.fileExists(atPath: tasksPath) else { continue }
            
            do {
                let taskFiles = try fileManager.contentsOfDirectory(atPath: tasksPath)
                    .filter { $0.hasSuffix(".md") }
                    .sorted()
                
                for taskFile in taskFiles {
                    let filePath = "\(tasksPath)/\(taskFile)"
                    if let task = parseTaskFile(at: filePath, department: department, project: project) {
                        // 이미 존재하는 태스크인지 확인
                        if let existingIndex = findExistingTask(title: task.title, department: department, project: project, companyStore: companyStore) {
                            // 업데이트
                            updateTask(at: existingIndex, with: task, project: project, companyStore: companyStore)
                            result.updated += 1
                        } else {
                            // 새로 추가
                            addTask(task, to: project, companyStore: companyStore)
                            result.created += 1
                        }
                    }
                }
            } catch {
                print("[TaskFileSyncService] ⚠️ \(department.directoryName)/tasks 스캔 실패: \(error)")
            }
        }
        
        print("[TaskFileSyncService] ✅ 동기화 완료 - 생성: \(result.created), 업데이트: \(result.updated)")
        return result
    }
    
    /// 태스크를 파일로 저장 (칸반 → 파일)
    func saveTaskToFile(_ task: ProjectTask, project: Project) {
        let projectPath = DataPathService.shared.projectPath(project.name)
        let tasksPath = "\(projectPath)/\(task.departmentType.directoryName)/tasks"
        
        // tasks 폴더 생성
        try? fileManager.createDirectory(atPath: tasksPath, withIntermediateDirectories: true)
        
        // 파일명 생성 (순번-제목.md)
        let sanitizedTitle = task.title
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let fileName = "\(sanitizedTitle).md"
        let filePath = "\(tasksPath)/\(fileName)"
        
        // 마크다운 생성
        let markdown = generateTaskMarkdown(task)
        
        do {
            try markdown.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("[TaskFileSyncService] 💾 태스크 파일 저장: \(fileName)")
        } catch {
            print("[TaskFileSyncService] ⚠️ 파일 저장 실패: \(error)")
        }
    }
    
    // MARK: - Parsing
    
    /// 태스크 마크다운 파일 파싱
    private func parseTaskFile(at path: String, department: DepartmentType, project: Project) -> ProjectTask? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        
        let lines = content.components(separatedBy: .newlines)
        
        // 제목 추출 (# 으로 시작하는 첫 줄)
        guard let titleLine = lines.first(where: { $0.hasPrefix("# ") }) else {
            return nil
        }
        let title = String(titleLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        
        // 상태 추출
        var status: TaskStatus = .todo
        if let statusLine = lines.first(where: { $0.contains("상태:") }) {
            if statusLine.contains("완료") || statusLine.contains("✅") {
                status = .done
            } else if statusLine.contains("진행") || statusLine.contains("🔄") {
                status = .inProgress
            } else if statusLine.contains("검토") || statusLine.contains("리뷰") {
                status = .needsReview
            }
        }
        
        // 담당자 추출
        var assigneeName: String?
        if let assigneeLine = lines.first(where: { $0.contains("담당:") }) {
            assigneeName = assigneeLine
                .replacingOccurrences(of: "## 담당:", with: "")
                .replacingOccurrences(of: "담당:", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        
        // 설명 추출 (### 설명 섹션)
        var description = ""
        if let descIndex = lines.firstIndex(where: { $0.contains("### 설명") }) {
            let descLines = lines.dropFirst(descIndex + 1)
            for line in descLines {
                if line.hasPrefix("###") { break }
                description += line + "\n"
            }
        }
        
        // 완료일 추출
        var completedAt: Date?
        if let dateLine = lines.first(where: { $0.contains("완료일:") }) {
            let dateStr = dateLine
                .replacingOccurrences(of: "## 완료일:", with: "")
                .replacingOccurrences(of: "완료일:", with: "")
                .trimmingCharacters(in: .whitespaces)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            completedAt = formatter.date(from: dateStr)
        }
        
        // 산출물 추출
        var outputs: [TaskOutput] = []
        if let outputIndex = lines.firstIndex(where: { $0.contains("### 산출물") }) {
            let outputLines = lines.dropFirst(outputIndex + 1)
            for line in outputLines {
                if line.hasPrefix("###") { break }
                if line.contains("`") {
                    // 백틱 안의 경로 추출
                    if let start = line.firstIndex(of: "`"),
                       let end = line.lastIndex(of: "`"),
                       start < end {
                        let filePath = String(line[line.index(after: start)..<end])
                        outputs.append(TaskOutput(
                            type: filePath.hasSuffix(".swift") ? .code : .document,
                            content: filePath,
                            fileName: (filePath as NSString).lastPathComponent
                        ))
                    }
                } else if line.hasPrefix("- ") {
                    let filePath = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if !filePath.isEmpty {
                        outputs.append(TaskOutput(
                            type: filePath.hasSuffix(".swift") ? .code : .document,
                            content: filePath,
                            fileName: (filePath as NSString).lastPathComponent
                        ))
                    }
                }
            }
        }
        
        // 담당자 ID 찾기
        var assigneeId: UUID?
        if let name = assigneeName {
            assigneeId = findEmployeeId(name: name, department: department, project: project)
        }
        
        return ProjectTask(
            title: title,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            priority: .medium,
            assigneeId: assigneeId,
            departmentType: department,
            outputs: outputs,
            completedAt: completedAt
        )
    }
    
    /// 태스크를 마크다운으로 변환
    private func generateTaskMarkdown(_ task: ProjectTask) -> String {
        let statusEmoji: String
        switch task.status {
        case .backlog: statusEmoji = "📥 백로그"
        case .todo: statusEmoji = "📋 할일"
        case .inProgress: statusEmoji = "🔄 진행 중"
        case .needsReview: statusEmoji = "👀 검토 필요"
        case .done: statusEmoji = "✅ 완료"
        case .rejected: statusEmoji = "❌ 반려됨"
        }
        
        var markdown = """
        # \(task.title)
        
        ## 상태: \(statusEmoji)
        ## 부서: \(task.departmentType.rawValue)
        """
        
        if let completedAt = task.completedAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            markdown += "\n## 완료일: \(formatter.string(from: completedAt))"
        }
        
        if !task.description.isEmpty {
            markdown += "\n\n### 설명\n\(task.description)"
        }
        
        if !task.outputs.isEmpty {
            markdown += "\n\n### 산출물"
            for output in task.outputs {
                markdown += "\n- `\(output.content)`"
            }
        }
        
        markdown += "\n\n---\n*PixelOffice 자동 생성*\n"
        
        return markdown
    }
    
    // MARK: - Helpers
    
    @MainActor
    private func findExistingTask(title: String, department: DepartmentType, project: Project, companyStore: CompanyStore) -> Int? {
        guard let projectIndex = companyStore.company.projects.firstIndex(where: { $0.id == project.id }) else {
            return nil
        }
        
        return companyStore.company.projects[projectIndex].tasks.firstIndex {
            $0.title == title && $0.departmentType == department
        }
    }
    
    private func findEmployeeId(name: String, department: DepartmentType, project: Project) -> UUID? {
        for dept in project.departments {
            if dept.type == department {
                if let employee = dept.employees.first(where: { $0.name == name }) {
                    return employee.id
                }
            }
        }
        return nil
    }
    
    @MainActor
    private func addTask(_ task: ProjectTask, to project: Project, companyStore: CompanyStore) {
        guard let projectIndex = companyStore.company.projects.firstIndex(where: { $0.id == project.id }) else {
            return
        }
        companyStore.company.projects[projectIndex].tasks.append(task)
    }
    
    @MainActor
    private func updateTask(at index: Int, with task: ProjectTask, project: Project, companyStore: CompanyStore) {
        guard let projectIndex = companyStore.company.projects.firstIndex(where: { $0.id == project.id }) else {
            return
        }
        var existingTask = companyStore.company.projects[projectIndex].tasks[index]
        existingTask.status = task.status
        existingTask.description = task.description
        existingTask.outputs = task.outputs
        existingTask.completedAt = task.completedAt
        existingTask.updatedAt = Date()
        companyStore.company.projects[projectIndex].tasks[index] = existingTask
    }
}

// MARK: - Sync Result

struct SyncResult {
    var created: Int = 0
    var updated: Int = 0
}
