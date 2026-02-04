import Foundation

/// _projects 폴더에서 프로젝트를 자동으로 복구하는 서비스
class ProjectRecoveryService {
    static let shared = ProjectRecoveryService()

    private let fileManager = FileManager.default

    private init() {}

    /// _projects 폴더에서 프로젝트 복구
    func recoverProjectsIfNeeded(company: inout Company) {
        let projectsPath = "\(DataPathService.shared.basePath)/_projects"

        guard fileManager.fileExists(atPath: projectsPath) else {
            print("📂 _projects 폴더 없음, 복구 건너뜀")
            return
        }

        print("🔄 _projects 폴더에서 프로젝트 복구 시작...")

        do {
            let projectDirs = try fileManager.contentsOfDirectory(atPath: projectsPath)
            var recoveredCount = 0

            for projectDirName in projectDirs {
                if projectDirName.hasPrefix(".") || projectDirName.hasPrefix("_") {
                    continue
                }

                let projectPath = "\(projectsPath)/\(projectDirName)"
                let displayName = projectDirName.replacingOccurrences(of: "-", with: " ")

                // 이미 존재하는 프로젝트인지 확인
                if company.projects.contains(where: { $0.name == displayName }) {
                    print("  ✅ 이미 존재: \(displayName)")

                    // 직원 추가 확인
                    if let projectIndex = company.projects.firstIndex(where: { $0.name == displayName }) {
                        recoverProjectEmployees(
                            projectPath: projectPath,
                            projectIndex: projectIndex,
                            company: &company
                        )
                    }
                    continue
                }

                // 새 프로젝트 생성
                var newProject = Project(
                    name: displayName,
                    description: "",
                    status: .planning
                )

                // 부서별 직원 스캔
                recoverProjectEmployees(
                    projectPath: projectPath,
                    project: &newProject,
                    company: &company
                )

                if !newProject.allEmployees.isEmpty {
                    company.addProject(newProject)
                    recoveredCount += 1
                    print("  🆕 새 프로젝트 복구: \(displayName) (\(newProject.allEmployees.count)명)")
                }
            }

            if recoveredCount > 0 {
                print("✅ \(recoveredCount)개 프로젝트 복구 완료")
            }
        } catch {
            print("⚠️ 프로젝트 복구 실패: \(error)")
        }
    }

    /// 프로젝트 직원 복구 (기존 프로젝트)
    private func recoverProjectEmployees(
        projectPath: String,
        projectIndex: Int,
        company: inout Company
    ) {
        do {
            let deptDirs = try fileManager.contentsOfDirectory(atPath: projectPath)

            for deptDirName in deptDirs {
                if deptDirName.hasPrefix(".") || deptDirName.hasPrefix("_") {
                    continue
                }

                let peoplePath = "\(projectPath)/\(deptDirName)/people"
                guard fileManager.fileExists(atPath: peoplePath) else { continue }

                let employeeFiles = try fileManager.contentsOfDirectory(atPath: peoplePath)
                    .filter { $0.hasSuffix(".md") }

                for empFile in employeeFiles {
                    let empName = (empFile as NSString).deletingPathExtension
                    let empFilePath = "\(peoplePath)/\(empFile)"

                    // 이미 존재하는 직원인지 확인
                    let project = company.projects[projectIndex]
                    let alreadyExists = project.departments.contains { dept in
                        dept.employees.contains { $0.name == empName }
                    }

                    if !alreadyExists {
                        // 직원 정보 파싱 및 추가
                        if let employee = parseEmployeeFile(
                            filePath: empFilePath,
                            departmentType: deptDirName
                        ) {
                            let deptType = parseDepartmentType(deptDirName)
                            company.projects[projectIndex].addEmployee(employee, toDepartment: deptType)
                            print("    👤 \(empName) (\(deptDirName)) 추가")
                        }
                    }
                }
            }
        } catch {
            print("⚠️ 직원 복구 실패: \(error)")
        }
    }

    /// 프로젝트 직원 복구 (새 프로젝트)
    private func recoverProjectEmployees(
        projectPath: String,
        project: inout Project,
        company: inout Company
    ) {
        do {
            let deptDirs = try fileManager.contentsOfDirectory(atPath: projectPath)

            for deptDirName in deptDirs {
                if deptDirName.hasPrefix(".") || deptDirName.hasPrefix("_") {
                    continue
                }

                let peoplePath = "\(projectPath)/\(deptDirName)/people"
                guard fileManager.fileExists(atPath: peoplePath) else { continue }

                let employeeFiles = try fileManager.contentsOfDirectory(atPath: peoplePath)
                    .filter { $0.hasSuffix(".md") }

                for empFile in employeeFiles {
                    let empName = (empFile as NSString).deletingPathExtension
                    let empFilePath = "\(peoplePath)/\(empFile)"

                    // 직원 정보 파싱 및 추가
                    if let employee = parseEmployeeFile(
                        filePath: empFilePath,
                        departmentType: deptDirName
                    ) {
                        let deptType = parseDepartmentType(deptDirName)
                        project.addEmployee(employee, toDepartment: deptType)
                    }
                }
            }
        } catch {
            print("⚠️ 직원 복구 실패: \(error)")
        }
    }

    /// 직원 파일 파싱
    private func parseEmployeeFile(filePath: String, departmentType: String) -> ProjectEmployee? {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return nil
        }

        // 이름 추출
        let namePattern = #"^# (.+)$"#
        let nameRegex = try? NSRegularExpression(pattern: namePattern, options: .anchorsMatchLines)
        var name = (filePath as NSString).lastPathComponent
            .replacingOccurrences(of: ".md", with: "")

        if let match = nameRegex?.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            name = String(content[range])
        }

        // AI 유형 추출
        let aiTypePattern = #"\*\*AI 유형\*\* \| (.+)"#
        let aiTypeRegex = try? NSRegularExpression(pattern: aiTypePattern)
        var aiType = AIType.claude

        if let match = aiTypeRegex?.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            let aiTypeStr = String(content[range]).trimmingCharacters(in: .whitespaces)
            aiType = AIType(rawValue: aiTypeStr) ?? .claude
        }

        // 외모 정보 (간단 버전)
        var appearance = CharacterAppearance.random()
        if content.contains("안경") {
            appearance.accessory = 1
        }

        return ProjectEmployee(
            name: name,
            aiType: aiType,
            characterAppearance: appearance
        )
    }

    /// 부서 타입 파싱
    private func parseDepartmentType(_ dirName: String) -> DepartmentType {
        switch dirName {
        case "기획": return .planning
        case "디자인": return .design
        case "개발": return .development
        case "QA": return .qa
        case "마케팅": return .marketing
        default: return .general
        }
    }
}
