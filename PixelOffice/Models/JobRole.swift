import Foundation

/// 직군 (부서 내 세부 역할)
enum JobRole: String, Codable, CaseIterable {
    // 기획팀
    case productManager = "Product Manager"
    case productOwner = "Product Owner"
    case servicePlanner = "서비스 기획자"
    case dataAnalyst = "데이터 분석가"
    case uxResearcher = "UX 리서처"
    case projectManager = "프로젝트 매니저"
    case scrumMaster = "스크럼 마스터"

    // 디자인팀
    case uxDesigner = "UX 디자이너"
    case uiDesigner = "UI 디자이너"
    case visualDesigner = "비주얼 디자이너"
    case motionDesigner = "모션 디자이너"
    case brandDesigner = "브랜드 디자이너"
    case graphicDesigner = "그래픽 디자이너"
    case designSystemManager = "디자인 시스템 매니저"

    // 개발팀
    case frontendDeveloper = "프론트엔드 개발자"
    case backendDeveloper = "백엔드 개발자"
    case iosDeveloper = "iOS 개발자"
    case androidDeveloper = "Android 개발자"
    case fullStackDeveloper = "풀스택 개발자"
    case devOpsEngineer = "DevOps 엔지니어"
    case dataEngineer = "데이터 엔지니어"
    case mlEngineer = "ML 엔지니어"
    case securityEngineer = "보안 엔지니어"
    case dba = "DBA"

    // QA팀
    case qaEngineer = "QA 엔지니어"
    case sdet = "테스트 자동화 엔지니어"
    case qaLead = "QA 리드"
    case performanceTester = "성능 테스터"

    // 마케팅팀
    case growthManager = "그로스 매니저"
    case performanceMarketer = "퍼포먼스 마케터"
    case contentMarketer = "콘텐츠 마케터"
    case brandMarketer = "브랜드 마케터"
    case crmMarketer = "CRM 마케터"
    case seoSpecialist = "SEO 전문가"
    case socialMediaManager = "소셜미디어 매니저"

    // 일반
    case general = "일반"

    /// 해당 직군이 속한 부서
    var department: DepartmentType {
        switch self {
        case .productManager, .productOwner, .servicePlanner, .dataAnalyst, .uxResearcher, .projectManager, .scrumMaster:
            return .planning
        case .uxDesigner, .uiDesigner, .visualDesigner, .motionDesigner, .brandDesigner, .graphicDesigner, .designSystemManager:
            return .design
        case .frontendDeveloper, .backendDeveloper, .iosDeveloper, .androidDeveloper, .fullStackDeveloper, .devOpsEngineer, .dataEngineer, .mlEngineer, .securityEngineer, .dba:
            return .development
        case .qaEngineer, .sdet, .qaLead, .performanceTester:
            return .qa
        case .growthManager, .performanceMarketer, .contentMarketer, .brandMarketer, .crmMarketer, .seoSpecialist, .socialMediaManager:
            return .marketing
        case .general:
            return .general
        }
    }

    /// 직군 설명
    var description: String {
        switch self {
        // 기획팀
        case .productManager:
            return "제품 전체 로드맵, 우선순위 결정, 이해관계자 조율"
        case .productOwner:
            return "백로그 관리, 스프린트 목표 설정, 개발팀과 직접 소통"
        case .servicePlanner:
            return "기능 정의, 화면 설계, 정책 수립"
        case .dataAnalyst:
            return "사용자 행동 분석, A/B 테스트, 지표 추적"
        case .uxResearcher:
            return "사용자 인터뷰, 설문조사, 유저빌리티 테스트"
        case .projectManager:
            return "일정, 리소스, 리스크 관리"
        case .scrumMaster:
            return "애자일/스크럼 프로세스 운영, 팀 생산성 개선"

        // 디자인팀
        case .uxDesigner:
            return "사용자 경험 설계, 정보 구조, 인터랙션 설계"
        case .uiDesigner:
            return "화면 비주얼, 컴포넌트, 디자인 시스템 구축"
        case .visualDesigner:
            return "브랜딩, 일러스트, 아이콘, 그래픽 에셋"
        case .motionDesigner:
            return "애니메이션, 마이크로 인터랙션, 전환 효과"
        case .brandDesigner:
            return "CI/BI, 브랜드 가이드라인, 마케팅 비주얼"
        case .graphicDesigner:
            return "배너, 포스터, SNS 크리에이티브"
        case .designSystemManager:
            return "디자인 토큰, 컴포넌트 라이브러리 운영"

        // 개발팀
        case .frontendDeveloper:
            return "React, Vue 등 웹 UI 개발"
        case .backendDeveloper:
            return "API 설계, 서버 로직, DB 연동"
        case .iosDeveloper:
            return "Swift/SwiftUI 기반 iOS 앱 개발"
        case .androidDeveloper:
            return "Kotlin 기반 Android 앱 개발"
        case .fullStackDeveloper:
            return "프론트엔드와 백엔드 모두 개발"
        case .devOpsEngineer:
            return "CI/CD, 배포 자동화, 인프라 관리"
        case .dataEngineer:
            return "데이터 파이프라인, ETL, 데이터 웨어하우스"
        case .mlEngineer:
            return "머신러닝 모델 개발, 학습, 배포"
        case .securityEngineer:
            return "취약점 점검, 침투 테스트, 보안 솔루션"
        case .dba:
            return "DB 설계, 튜닝, 백업/복구"

        // QA팀
        case .qaEngineer:
            return "테스트 계획, 수동/자동 테스트, 버그 리포팅"
        case .sdet:
            return "테스트 자동화 프레임워크 개발"
        case .qaLead:
            return "QA 전략, 품질 기준 수립, 릴리스 승인"
        case .performanceTester:
            return "성능 테스트, 부하 테스트, 병목 분석"

        // 마케팅팀
        case .growthManager:
            return "성장 전략, 퍼널 분석, AARRR 지표 관리"
        case .performanceMarketer:
            return "광고 집행, ROAS 최적화"
        case .contentMarketer:
            return "블로그, 뉴스레터, SNS 콘텐츠 제작"
        case .brandMarketer:
            return "브랜드 포지셔닝, 캠페인 기획"
        case .crmMarketer:
            return "리텐션, 푸시/이메일 캠페인"
        case .seoSpecialist:
            return "검색엔진 최적화, ASO"
        case .socialMediaManager:
            return "SNS 채널 운영, 커뮤니티 관리"

        case .general:
            return "일반 직무"
        }
    }

    /// 부서별 직군 목록
    static func roles(for department: DepartmentType) -> [JobRole] {
        JobRole.allCases.filter { $0.department == department }
    }

    /// 직군별 전문 스킬셋
    func skillSet() -> DepartmentSkillSet {
        let baseSkills = DepartmentSkillSet.defaultSkills(for: department)
        var customSkills = baseSkills

        // 직군별 세부 역할 추가
        customSkills.role = """
        \(baseSkills.role)

        **세부 직군**: \(rawValue)
        \(description)
        """

        // 직군별 특화 스킬 추가
        switch self {
        // 기획팀
        case .productManager:
            customSkills.skills.append("제품 로드맵 수립")
            customSkills.skills.append("우선순위 결정 (RICE, MoSCoW)")
            customSkills.skills.append("이해관계자 관리")
        case .productOwner:
            customSkills.skills.append("백로그 관리")
            customSkills.skills.append("사용자 스토리 작성")
            customSkills.skills.append("스프린트 계획")
        case .dataAnalyst:
            customSkills.skills.append("SQL, Python 기반 데이터 분석")
            customSkills.skills.append("A/B 테스트 설계 및 분석")
            customSkills.skills.append("대시보드 구축 (Tableau, Looker)")

        // 디자인팀
        case .uxDesigner:
            customSkills.skills.append("사용자 플로우 설계")
            customSkills.skills.append("와이어프레임, 프로토타입")
            customSkills.skills.append("인터랙션 디자인")
        case .uiDesigner:
            customSkills.skills.append("시각적 디자인")
            customSkills.skills.append("컴포넌트 설계")
            customSkills.skills.append("디자인 시스템 구축")
        case .motionDesigner:
            customSkills.skills.append("애니메이션 타이밍")
            customSkills.skills.append("마이크로 인터랙션")
            customSkills.skills.append("Lottie, After Effects")

        // 개발팀
        case .frontendDeveloper:
            customSkills.skills.append("React, Vue, Angular")
            customSkills.skills.append("TypeScript, JavaScript")
            customSkills.skills.append("웹 성능 최적화")
        case .backendDeveloper:
            customSkills.skills.append("RESTful API, GraphQL")
            customSkills.skills.append("데이터베이스 설계")
            customSkills.skills.append("서버 아키텍처")
        case .devOpsEngineer:
            customSkills.skills.append("CI/CD 파이프라인 (Jenkins, GitHub Actions)")
            customSkills.skills.append("컨테이너 (Docker, Kubernetes)")
            customSkills.skills.append("IaC (Terraform, Ansible)")
        case .mlEngineer:
            customSkills.skills.append("머신러닝 모델 개발")
            customSkills.skills.append("데이터 전처리, 특성 공학")
            customSkills.skills.append("MLOps, 모델 배포")

        // QA팀
        case .qaEngineer:
            customSkills.skills.append("테스트 케이스 설계")
            customSkills.skills.append("버그 리포팅 (Jira, Linear)")
            customSkills.skills.append("회귀 테스트")
        case .sdet:
            customSkills.skills.append("테스트 자동화 (Selenium, Cypress)")
            customSkills.skills.append("CI/CD 통합")
            customSkills.skills.append("테스트 프레임워크 구축")

        // 마케팅팀
        case .growthManager:
            customSkills.skills.append("AARRR 퍼널 분석")
            customSkills.skills.append("그로스 해킹 전략")
            customSkills.skills.append("코호트 분석")
        case .performanceMarketer:
            customSkills.skills.append("Google Ads, Meta Ads")
            customSkills.skills.append("ROAS 최적화")
            customSkills.skills.append("광고 크리에이티브 A/B 테스트")
        case .contentMarketer:
            customSkills.skills.append("콘텐츠 기획 및 제작")
            customSkills.skills.append("SEO 글쓰기")
            customSkills.skills.append("스토리텔링")

        default:
            break
        }

        return customSkills
    }
}
