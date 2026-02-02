import Foundation

/// 온보딩 질문
struct OnboardingQuestion: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var question: String
    var answer: String?
    var category: OnboardingCategory
    var isRequired: Bool
    var placeholder: String

    init(
        id: UUID = UUID(),
        question: String,
        answer: String? = nil,
        category: OnboardingCategory,
        isRequired: Bool = true,
        placeholder: String = ""
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.category = category
        self.isRequired = isRequired
        self.placeholder = placeholder
    }
}

enum OnboardingCategory: String, Codable, CaseIterable {
    case company = "회사 정보"
    case project = "프로젝트"
    case workflow = "업무 방식"
    case tools = "도구 및 환경"
    case communication = "소통 방식"

    var icon: String {
        switch self {
        case .company: return "building.2"
        case .project: return "folder"
        case .workflow: return "arrow.triangle.branch"
        case .tools: return "wrench.and.screwdriver"
        case .communication: return "bubble.left.and.bubble.right"
        }
    }
}

/// 부서별 온보딩 질문 템플릿
struct OnboardingTemplate {

    /// 기획팀 온보딩 질문
    static func planningQuestions() -> [OnboardingQuestion] {
        [
            OnboardingQuestion(
                question: "회사의 핵심 비전과 미션은 무엇인가요?",
                category: .company,
                placeholder: "예: 우리는 AI로 업무 자동화를 혁신합니다"
            ),
            OnboardingQuestion(
                question: "현재 진행 중이거나 계획된 주요 프로젝트가 있나요?",
                category: .project,
                placeholder: "예: 신규 모바일 앱 개발, 기존 서비스 리뉴얼 등"
            ),
            OnboardingQuestion(
                question: "타겟 고객층은 누구인가요?",
                category: .project,
                placeholder: "예: 20-30대 직장인, B2B 기업 고객 등"
            ),
            OnboardingQuestion(
                question: "기획 문서는 어떤 형식으로 작성하면 될까요?",
                category: .workflow,
                placeholder: "예: PRD, 기능 명세서, 와이어프레임 등"
            ),
            OnboardingQuestion(
                question: "의사결정 과정은 어떻게 진행되나요?",
                category: .workflow,
                placeholder: "예: CEO 직접 승인, 팀 리뷰 후 진행 등"
            ),
            OnboardingQuestion(
                question: "참고해야 할 경쟁사나 벤치마킹 대상이 있나요?",
                category: .project,
                isRequired: false,
                placeholder: "예: Notion, Slack, Figma 등"
            ),
            OnboardingQuestion(
                question: "피해야 할 방향이나 금기 사항이 있나요?",
                category: .workflow,
                isRequired: false,
                placeholder: "예: 복잡한 기능보다 단순함 추구 등"
            )
        ]
    }

    /// 디자인팀 온보딩 질문
    static func designQuestions() -> [OnboardingQuestion] {
        [
            OnboardingQuestion(
                question: "브랜드 가이드라인이나 디자인 시스템이 있나요?",
                category: .tools,
                placeholder: "예: 브랜드 컬러, 폰트, 로고 사용 규칙 등"
            ),
            OnboardingQuestion(
                question: "선호하는 디자인 스타일이나 레퍼런스가 있나요?",
                category: .workflow,
                placeholder: "예: 미니멀, 플레이풀, 프로페셔널 등"
            ),
            OnboardingQuestion(
                question: "주로 사용하는 디자인 도구가 있나요?",
                category: .tools,
                placeholder: "예: Figma, Sketch, Adobe XD 등"
            ),
            OnboardingQuestion(
                question: "디자인 에셋은 어디에 저장하면 될까요?",
                category: .tools,
                placeholder: "예: Google Drive, Dropbox, 로컬 폴더 등"
            ),
            OnboardingQuestion(
                question: "디자인 리뷰 프로세스가 어떻게 되나요?",
                category: .workflow,
                placeholder: "예: 주간 리뷰, 즉시 피드백 등"
            )
        ]
    }

    /// 개발팀 온보딩 질문
    static func developmentQuestions() -> [OnboardingQuestion] {
        [
            OnboardingQuestion(
                question: "사용 중인 기술 스택은 무엇인가요?",
                category: .tools,
                placeholder: "예: Swift, React, Python, AWS 등"
            ),
            OnboardingQuestion(
                question: "코드 저장소와 브랜치 전략은 어떻게 되나요?",
                category: .workflow,
                placeholder: "예: GitHub, GitFlow, trunk-based 등"
            ),
            OnboardingQuestion(
                question: "코드 리뷰 프로세스가 있나요?",
                category: .workflow,
                placeholder: "예: PR 필수, 1명 이상 승인 등"
            ),
            OnboardingQuestion(
                question: "배포 환경과 프로세스는 어떻게 되나요?",
                category: .tools,
                placeholder: "예: CI/CD, 수동 배포, 스테이징 환경 등"
            ),
            OnboardingQuestion(
                question: "기술 부채나 레거시 코드에 대한 정책이 있나요?",
                category: .workflow,
                isRequired: false,
                placeholder: "예: 점진적 개선, 리팩토링 스프린트 등"
            )
        ]
    }

    /// QA팀 온보딩 질문
    static func qaQuestions() -> [OnboardingQuestion] {
        [
            OnboardingQuestion(
                question: "테스트 환경은 어떻게 구성되어 있나요?",
                category: .tools,
                placeholder: "예: 테스트 서버, 로컬 환경 등"
            ),
            OnboardingQuestion(
                question: "테스트 케이스 관리 도구가 있나요?",
                category: .tools,
                placeholder: "예: TestRail, 스프레드시트, Notion 등"
            ),
            OnboardingQuestion(
                question: "버그 리포트 형식이 있나요?",
                category: .workflow,
                placeholder: "예: 재현 스텝, 스크린샷, 심각도 등"
            ),
            OnboardingQuestion(
                question: "품질 기준이나 출시 조건이 있나요?",
                category: .workflow,
                placeholder: "예: 크리티컬 버그 0건, 성능 기준 등"
            )
        ]
    }

    /// 마케팅팀 온보딩 질문
    static func marketingQuestions() -> [OnboardingQuestion] {
        [
            OnboardingQuestion(
                question: "마케팅 채널은 어떤 것들을 사용하나요?",
                category: .tools,
                placeholder: "예: SNS, 블로그, 뉴스레터, 광고 등"
            ),
            OnboardingQuestion(
                question: "타겟 오디언스의 특성은 무엇인가요?",
                category: .project,
                placeholder: "예: 연령대, 관심사, 행동 패턴 등"
            ),
            OnboardingQuestion(
                question: "브랜드 톤앤매너가 정해져 있나요?",
                category: .workflow,
                placeholder: "예: 친근함, 전문성, 유머러스 등"
            ),
            OnboardingQuestion(
                question: "마케팅 예산이나 KPI가 있나요?",
                category: .project,
                isRequired: false,
                placeholder: "예: 월 예산, DAU 목표, 전환율 등"
            )
        ]
    }

    /// 부서 타입에 따른 질문 가져오기
    static func questions(for departmentType: DepartmentType) -> [OnboardingQuestion] {
        switch departmentType {
        case .planning: return planningQuestions()
        case .design: return designQuestions()
        case .development: return developmentQuestions()
        case .qa: return qaQuestions()
        case .marketing: return marketingQuestions()
        case .general: return planningQuestions() // 기본값
        }
    }
}

/// 직원의 온보딩 상태
struct EmployeeOnboarding: Codable, Identifiable {
    var id: UUID = UUID()
    var employeeId: UUID
    var questions: [OnboardingQuestion]
    var isCompleted: Bool
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        employeeId: UUID,
        questions: [OnboardingQuestion],
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.employeeId = employeeId
        self.questions = questions
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }

    var progress: Double {
        let answered = questions.filter { $0.answer != nil && !$0.answer!.isEmpty }.count
        return Double(answered) / Double(questions.count)
    }

    var hasAllRequiredAnswers: Bool {
        questions.filter { $0.isRequired }.allSatisfy { $0.answer != nil && !$0.answer!.isEmpty }
    }
}
