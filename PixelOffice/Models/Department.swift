import Foundation
import SwiftUI

struct Department: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var type: DepartmentType
    var employees: [Employee]
    var maxCapacity: Int
    var position: DeskPosition
    
    init(
        id: UUID = UUID(),
        name: String,
        type: DepartmentType,
        employees: [Employee] = [],
        maxCapacity: Int = 4,
        position: DeskPosition = DeskPosition(row: 0, column: 0)
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.employees = employees
        self.maxCapacity = maxCapacity
        self.position = position
    }
    
    var availableSlots: Int {
        maxCapacity - employees.count
    }
    
    var isFull: Bool {
        employees.count >= maxCapacity
    }
    
    static func == (lhs: Department, rhs: Department) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static var defaultDepartments: [Department] {
        [
            Department(name: "기획팀", type: .planning, position: DeskPosition(row: 0, column: 0)),
            Department(name: "디자인팀", type: .design, position: DeskPosition(row: 0, column: 1)),
            Department(name: "개발팀", type: .development, position: DeskPosition(row: 1, column: 0)),
            Department(name: "마케팅팀", type: .marketing, position: DeskPosition(row: 1, column: 1)),
            Department(name: "QA팀", type: .qa, position: DeskPosition(row: 2, column: 0))
        ]
    }
}

enum DepartmentType: String, Codable, CaseIterable {
    case planning = "기획"
    case design = "디자인"
    case development = "개발"
    case marketing = "마케팅"
    case qa = "QA"
    case general = "일반"

    var icon: String {
        switch self {
        case .planning: return "lightbulb.fill"
        case .design: return "paintbrush.fill"
        case .development: return "chevron.left.forwardslash.chevron.right"
        case .marketing: return "megaphone.fill"
        case .qa: return "checkmark.shield.fill"
        case .general: return "briefcase.fill"
        }
    }

    var color: Color {
        switch self {
        case .planning: return .yellow
        case .design: return .pink
        case .development: return .blue
        case .marketing: return .green
        case .qa: return .purple
        case .general: return .gray
        }
    }

    var description: String {
        switch self {
        case .planning: return "프로젝트 기획 및 전략 수립"
        case .design: return "UI/UX 디자인 및 비주얼 작업"
        case .development: return "코드 작성 및 기술 구현"
        case .marketing: return "마케팅 전략 및 콘텐츠 제작"
        case .qa: return "품질 보증 및 테스트"
        case .general: return "일반 업무"
        }
    }

    /// 워크플로우 순서 (낮을수록 먼저)
    var workflowOrder: Int {
        switch self {
        case .planning: return 1    // 1단계: 기획
        case .design: return 2      // 2단계: 디자인
        case .development: return 2 // 2단계: 개발 (디자인과 병행 가능)
        case .qa: return 3          // 3단계: QA
        case .marketing: return 4   // 4단계: 마케팅
        case .general: return 0
        }
    }

    /// 다음 단계로 넘길 수 있는 부서들
    var nextDepartments: [DepartmentType] {
        switch self {
        case .planning: return [.design, .development]  // 기획 → 디자인/개발
        case .design: return [.development, .qa]        // 디자인 → 개발/QA
        case .development: return [.qa]                 // 개발 → QA
        case .qa: return [.marketing]                   // QA → 마케팅
        case .marketing: return []                      // 마케팅 → 완료
        case .general: return DepartmentType.allCases.filter { $0 != .general }
        }
    }

    /// 이전 단계 부서들
    var previousDepartments: [DepartmentType] {
        switch self {
        case .planning: return []
        case .design: return [.planning]
        case .development: return [.planning, .design]
        case .qa: return [.design, .development]
        case .marketing: return [.qa]
        case .general: return []
        }
    }

    /// 워크플로우 단계 이름
    var workflowStageName: String {
        switch self {
        case .planning: return "1단계: 기획"
        case .design: return "2단계: 디자인"
        case .development: return "2단계: 개발"
        case .qa: return "3단계: 검증"
        case .marketing: return "4단계: 출시"
        case .general: return "일반"
        }
    }

    /// 10년차 전문가 역할 프롬프트
    var expertRolePrompt: String {
        switch self {
        case .planning:
            return """
            당신은 10년차 시니어 기획자입니다. 수많은 프로젝트를 성공시킨 경험이 있습니다.

            당신의 전문 분야:
            - 제품/서비스 기획 및 전략 수립
            - 시장 분석 및 경쟁사 조사
            - 사용자 요구사항 정의 및 PRD 작성
            - 프로젝트 로드맵 및 마일스톤 관리
            - 이해관계자 커뮤니케이션

            대화할 때:
            - 프로젝트의 목표와 비전을 명확히 이해하려고 합니다
            - 타겟 사용자와 핵심 가치를 파악하려 합니다
            - 실현 가능성과 리소스를 고려한 현실적인 조언을 합니다
            """
        case .design:
            return """
            당신은 10년차 시니어 디자이너입니다. UI/UX 전문가로 다양한 플랫폼 경험이 있습니다.

            당신의 전문 분야:
            - UI/UX 디자인 및 사용자 경험 설계
            - 디자인 시스템 구축 및 운영
            - 프로토타이핑 및 사용성 테스트
            - 브랜드 아이덴티티 및 비주얼 디자인
            - 디자인-개발 협업 프로세스

            대화할 때:
            - 사용자 관점에서 문제를 바라봅니다
            - 심미성과 사용성의 균형을 중시합니다
            - 구체적인 디자인 방향과 레퍼런스를 제시합니다
            """
        case .development:
            return """
            당신은 10년차 시니어 개발자입니다. 풀스택 경험과 아키텍처 설계 능력을 갖추고 있습니다.

            당신의 전문 분야:
            - 소프트웨어 아키텍처 설계
            - 프론트엔드/백엔드 개발
            - 코드 리뷰 및 기술 멘토링
            - 성능 최적화 및 확장성 설계
            - DevOps 및 CI/CD 파이프라인

            대화할 때:
            - 기술적 실현 가능성을 먼저 검토합니다
            - 확장성과 유지보수성을 고려합니다
            - 구체적인 기술 스택과 구현 방안을 제안합니다
            """
        case .qa:
            return """
            당신은 10년차 시니어 QA 엔지니어입니다. 품질 보증 전문가로 다양한 테스트 경험이 있습니다.

            당신의 전문 분야:
            - 테스트 전략 수립 및 테스트 계획
            - 자동화 테스트 프레임워크 구축
            - 버그 트래킹 및 품질 메트릭 관리
            - 성능/보안/접근성 테스트
            - 릴리즈 품질 게이트 관리

            대화할 때:
            - 엣지 케이스와 예외 상황을 먼저 고려합니다
            - 품질 기준과 테스트 범위를 명확히 합니다
            - 리스크 기반 테스트 우선순위를 제안합니다
            """
        case .marketing:
            return """
            당신은 10년차 시니어 마케터입니다. 디지털 마케팅과 그로스 해킹 전문가입니다.

            당신의 전문 분야:
            - 마케팅 전략 및 캠페인 기획
            - 콘텐츠 마케팅 및 브랜딩
            - 퍼포먼스 마케팅 및 데이터 분석
            - 사용자 획득 및 리텐션 전략
            - PR 및 커뮤니케이션

            대화할 때:
            - 타겟 고객과 시장 포지셔닝을 파악하려 합니다
            - 데이터 기반 의사결정을 중시합니다
            - 측정 가능한 마케팅 목표를 설정합니다
            """
        case .general:
            return """
            당신은 10년차 베테랑 직원입니다. 다양한 업무 경험으로 회사 전반을 이해하고 있습니다.
            """
        }
    }

    /// 처음 인사할 때 물어볼 핵심 질문들
    var onboardingQuestions: [String] {
        switch self {
        case .planning:
            return [
                "이번 프로젝트의 핵심 목표와 성공 지표는 무엇인가요?",
                "주요 타겟 사용자는 누구이고, 그들의 핵심 니즈는 무엇인가요?",
                "프로젝트 일정과 주요 마일스톤이 정해져 있나요?",
                "경쟁사 대비 우리의 차별점은 무엇인가요?"
            ]
        case .design:
            return [
                "디자인 시스템이나 스타일 가이드가 있나요?",
                "참고할 만한 디자인 레퍼런스가 있나요?",
                "주요 사용자 플로우와 핵심 화면은 무엇인가요?",
                "디자인 결과물의 형태와 전달 방식은 어떻게 되나요?"
            ]
        case .development:
            return [
                "현재 기술 스택과 개발 환경은 어떻게 구성되어 있나요?",
                "코드 컨벤션이나 개발 가이드라인이 있나요?",
                "배포 환경과 CI/CD 파이프라인이 구축되어 있나요?",
                "기술적으로 가장 도전적인 부분은 무엇인가요?"
            ]
        case .qa:
            return [
                "품질 기준과 릴리즈 조건이 정의되어 있나요?",
                "자동화 테스트가 구축되어 있나요? 커버리지는 어느 정도인가요?",
                "버그 리포팅과 트래킹 프로세스는 어떻게 되나요?",
                "특별히 주의해야 할 크리티컬한 기능이 있나요?"
            ]
        case .marketing:
            return [
                "현재 마케팅 채널과 주요 KPI는 무엇인가요?",
                "타겟 고객의 페르소나가 정의되어 있나요?",
                "브랜드 톤앤매너 가이드가 있나요?",
                "출시 일정과 마케팅 예산은 어떻게 되나요?"
            ]
        case .general:
            return [
                "현재 진행 중인 프로젝트가 있나요?",
                "제가 어떤 업무를 담당하게 되나요?"
            ]
        }
    }
}

struct DeskPosition: Codable, Hashable {
    var row: Int
    var column: Int
}
