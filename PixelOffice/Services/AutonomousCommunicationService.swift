import Foundation
import Combine

/// 직원들의 자율적 소통 시스템
/// 주기적으로 직원들끼리 랜덤하게 대화를 생성하고 인사이트를 도출
class AutonomousCommunicationService: ObservableObject {
    static let shared = AutonomousCommunicationService()

    @Published var isEnabled = true  // 자율 소통 활성화 여부
    @Published var communicationInterval: TimeInterval = 3600  // 1시간마다 (초 단위)

    private var timer: Timer?
    private let claudeService = ClaudeService()
    private weak var companyStore: CompanyStore?  // CompanyStore 참조

    private init() {
        // 타이머는 setCompanyStore 호출 후에 시작
    }

    /// CompanyStore 설정 (앱 시작 시 호출)
    func setCompanyStore(_ store: CompanyStore) {
        self.companyStore = store
        if isEnabled {
            startCommunicationTimer()
        }
    }

    // MARK: - Timer Management

    /// 소통 타이머 시작
    func startCommunicationTimer() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: communicationInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isEnabled else { return }
            self.triggerRandomCommunication()
        }

        print("🤖 [자율소통] 타이머 시작: \(communicationInterval / 60)분마다")
    }

    /// 타이머 정지
    func stopCommunicationTimer() {
        timer?.invalidate()
        timer = nil
        print("🤖 [자율소통] 타이머 정지")
    }

    /// 간격 변경
    func updateInterval(_ newInterval: TimeInterval) {
        communicationInterval = newInterval
        startCommunicationTimer()
        print("🤖 [자율소통] 간격 변경: \(newInterval / 60)분")
    }

    // MARK: - Random Communication

    /// 랜덤 소통 트리거
    func triggerRandomCommunication() {
        print("🤖 [자율소통] 랜덤 소통 시작")

        Task {
            await performRandomCommunication()
        }
    }

    /// 랜덤 소통 실행 (비동기)
    private func performRandomCommunication() async {
        // CompanyStore 확인
        guard let companyStore = self.companyStore else {
            print("❌ [자율소통] CompanyStore가 설정되지 않았습니다")
            return
        }

        let allEmployees = getAllEmployees(from: companyStore)

        guard allEmployees.count >= 2 else {
            print("❌ [자율소통] 직원이 부족합니다 (최소 2명 필요)")
            return
        }

        // 랜덤으로 두 명 선택
        let shuffled = allEmployees.shuffled()
        let employee1 = shuffled[0]
        let employee2 = shuffled[1]

        print("💬 [자율소통] \(employee1.name) ↔️ \(employee2.name)")

        // 대화 생성
        do {
            let insight = try await generateCommunicationInsight(
                employee1: employee1,
                employee2: employee2,
                companyStore: companyStore
            )

            // 커뮤니티 포스트로 저장
            await MainActor.run {
                saveCommunityPost(insight, from: employee1, to: employee2, companyStore: companyStore)
            }

            print("✅ [자율소통] 인사이트 생성 완료")
        } catch {
            print("❌ [자율소통] 인사이트 생성 실패: \(error)")
        }
    }

    // MARK: - Communication Generation

    /// 두 직원 간의 대화에서 인사이트 생성
    private func generateCommunicationInsight(
        employee1: EmployeeSnapshot,
        employee2: EmployeeSnapshot,
        companyStore: CompanyStore
    ) async throws -> CommunicationInsight {
        // 각 직원의 최근 업무 정보 수집
        let context1 = await gatherEmployeeContext(employee1, companyStore: companyStore)
        let context2 = await gatherEmployeeContext(employee2, companyStore: companyStore)

        // AI에게 대화 시뮬레이션 요청
        let prompt = """
        두 AI 직원이 우연히 만나서 업무에 대해 이야기를 나눕니다.
        이들의 대화에서 나올 만한 유용한 인사이트나 아이디어를 생성해주세요.

        **직원 1: \(employee1.name)**
        - 부서: \(employee1.departmentType.rawValue)팀
        - 직무: \(employee1.jobRoles.map { $0.rawValue }.joined(separator: ", "))
        - 성격: \(employee1.personality)
        - 강점: \(employee1.strengths.joined(separator: ", "))
        - 최근 활동: \(context1)

        **직원 2: \(employee2.name)**
        - 부서: \(employee2.departmentType.rawValue)팀
        - 직무: \(employee2.jobRoles.map { $0.rawValue }.joined(separator: ", "))
        - 성격: \(employee2.personality)
        - 강점: \(employee2.strengths.joined(separator: ", "))
        - 최근 활동: \(context2)

        다음 형식으로 작성해주세요:

        **제목**: [간단한 제목]

        **배경**: [두 직원이 어떤 상황에서 만났는지]

        **대화 내용**: [핵심 대화 요약]

        **인사이트**: [도출된 아이디어나 제안]

        **기대 효과**: [이 인사이트를 적용하면 어떤 효과가 있을지]

        ---

        규칙:
        - 자연스럽고 현실적인 대화로 작성
        - 각자의 전문 분야를 활용한 인사이트
        - 실제로 유용한 제안이나 아이디어
        - 한국어로 작성
        - 2-3문단 정도의 적당한 길이
        """

        // Claude API 호출 (Claude Code 사용)
        let response = try await claudeService.sendMessageWithClaudeCode(
            messages: [Message(role: .user, content: prompt)],
            systemPrompt: "당신은 직원들 간의 자연스러운 대화와 협업에서 인사이트를 도출하는 관찰자입니다."
        )

        return CommunicationInsight(
            id: UUID(),
            employee1Id: employee1.id,
            employee2Id: employee2.id,
            employee1Name: employee1.name,
            employee2Name: employee2.name,
            content: response.response,
            timestamp: Date()
        )
    }

    /// 직원의 컨텍스트 수집 (최근 업무, 문서, 대화 등)
    private func gatherEmployeeContext(_ employee: EmployeeSnapshot, companyStore: CompanyStore) async -> String {
        var context: [String] = []

        // 최근 대화 횟수
        if employee.conversationCount > 0 {
            context.append("최근 \(employee.conversationCount)회 대화")
        }

        // 작성한 문서
        if employee.documentsCreated > 0 {
            context.append("\(employee.documentsCreated)개 문서 작성")
        }

        // 완료한 태스크
        if employee.tasksCompleted > 0 {
            context.append("\(employee.tasksCompleted)개 태스크 완료")
        }

        // 협업 횟수
        if employee.collaborationCount > 0 {
            context.append("\(employee.collaborationCount)회 협업")
        }

        if context.isEmpty {
            return "아직 활동 기록이 없음"
        }

        return context.joined(separator: ", ")
    }

    /// 커뮤니티 포스트로 저장
    private func saveCommunityPost(
        _ insight: CommunicationInsight,
        from employee1: EmployeeSnapshot,
        to employee2: EmployeeSnapshot,
        companyStore: CompanyStore
    ) {
        // CommunityPost 형태로 저장
        let post = CommunityPost(
            id: insight.id,
            employeeId: employee1.id,
            employeeName: employee1.name,
            departmentType: employee1.departmentType,
            thinkingId: nil,
            title: "💡 \(employee1.name) × \(employee2.name): 자율 소통",
            content: insight.content,
            summary: String(insight.content.prefix(200)),  // 첫 200자를 요약으로
            tags: [employee1.departmentType.rawValue, employee2.departmentType.rawValue, "자율소통"],
            source: .autonomous,  // 자율 소통 출처 표시
            secondaryEmployeeId: employee2.id,
            secondaryEmployeeName: employee2.name,
            createdAt: insight.timestamp
        )

        companyStore.addCommunityPost(post)

        print("📝 [자율소통] 커뮤니티 포스트 저장: \(employee1.name) × \(employee2.name)")
    }

    // MARK: - Helpers

    /// 모든 직원 가져오기 (회사 + 프로젝트)
    private func getAllEmployees(from companyStore: CompanyStore) -> [EmployeeSnapshot] {
        var employees: [EmployeeSnapshot] = []

        // 회사 직원
        for dept in companyStore.company.departments {
            for employee in dept.employees {
                employees.append(EmployeeSnapshot(
                    id: employee.id,
                    name: employee.name,
                    departmentType: dept.type,
                    jobRoles: employee.jobRoles,
                    personality: employee.personality,
                    strengths: employee.strengths,
                    conversationCount: employee.statistics.conversationCount,
                    documentsCreated: employee.statistics.documentsCreated,
                    tasksCompleted: employee.statistics.tasksCompleted,
                    collaborationCount: employee.statistics.collaborationCount
                ))
            }
        }

        // 프로젝트 직원
        for project in companyStore.company.projects {
            for employee in project.allEmployees {
                employees.append(EmployeeSnapshot(
                    id: employee.id,
                    name: employee.name,
                    departmentType: employee.departmentType,
                    jobRoles: employee.jobRoles,
                    personality: employee.personality,
                    strengths: employee.strengths,
                    conversationCount: employee.statistics.conversationCount,
                    documentsCreated: employee.statistics.documentsCreated,
                    tasksCompleted: employee.statistics.tasksCompleted,
                    collaborationCount: employee.statistics.collaborationCount
                ))
            }
        }

        return employees
    }
}

// MARK: - Supporting Models

/// 직원 스냅샷 (소통 생성용)
struct EmployeeSnapshot {
    let id: UUID
    let name: String
    let departmentType: DepartmentType
    let jobRoles: [JobRole]
    let personality: String
    let strengths: [String]
    let conversationCount: Int
    let documentsCreated: Int
    let tasksCompleted: Int
    let collaborationCount: Int
}

/// 소통 인사이트
struct CommunicationInsight {
    let id: UUID
    let employee1Id: UUID
    let employee2Id: UUID
    let employee1Name: String
    let employee2Name: String
    let content: String
    let timestamp: Date
}
