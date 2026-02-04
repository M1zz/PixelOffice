import Foundation

/// 부서별 스킬 설정 (커스터마이징 가능)
struct DepartmentSkills: Codable {
    var skills: [DepartmentType: DepartmentSkillSet]

    init() {
        // 기본 스킬 설정
        skills = [:]
        for dept in DepartmentType.allCases {
            skills[dept] = DepartmentSkillSet.defaultSkills(for: dept)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        skills = [:]
        for dept in DepartmentType.allCases {
            if let skillSet = try container.decodeIfPresent(DepartmentSkillSet.self, forKey: DynamicCodingKey(stringValue: dept.rawValue)!) {
                skills[dept] = skillSet
            } else {
                skills[dept] = DepartmentSkillSet.defaultSkills(for: dept)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (dept, skillSet) in skills {
            try container.encode(skillSet, forKey: DynamicCodingKey(stringValue: dept.rawValue)!)
        }
    }

    func getSkills(for department: DepartmentType) -> DepartmentSkillSet {
        return skills[department] ?? DepartmentSkillSet.defaultSkills(for: department)
    }

    mutating func updateSkills(for department: DepartmentType, skills: DepartmentSkillSet) {
        self.skills[department] = skills
    }
}

/// 개별 부서의 스킬 설정
struct DepartmentSkillSet: Codable {
    var roleName: String           // 역할 이름 (예: "10년차 시니어 기획자")
    var expertise: [String]        // 전문 분야 목록
    var workStyle: String          // 작업 스타일/방식
    var customPrompt: String       // 추가 커스텀 프롬프트

    /// 전체 시스템 프롬프트 생성
    var fullPrompt: String {
        var prompt = "당신은 \(roleName)입니다.\n\n"

        if !expertise.isEmpty {
            prompt += "당신의 전문 분야:\n"
            for exp in expertise {
                prompt += "- \(exp)\n"
            }
            prompt += "\n"
        }

        if !workStyle.isEmpty {
            prompt += "대화할 때:\n\(workStyle)\n\n"
        }

        if !customPrompt.isEmpty {
            prompt += "\(customPrompt)\n"
        }

        return prompt
    }

    /// 기본 스킬 설정
    static func defaultSkills(for department: DepartmentType) -> DepartmentSkillSet {
        switch department {
        case .planning:
            return DepartmentSkillSet(
                roleName: "10년차 시니어 기획자",
                expertise: [
                    "제품/서비스 기획 및 전략 수립",
                    "시장 분석 및 경쟁사 조사",
                    "사용자 요구사항 정의 및 PRD 작성",
                    "프로젝트 로드맵 및 마일스톤 관리",
                    "이해관계자 커뮤니케이션"
                ],
                workStyle: """
                - 프로젝트의 목표와 비전을 명확히 이해하려고 합니다
                - 타겟 사용자와 핵심 가치를 파악하려 합니다
                - 실현 가능성과 리소스를 고려한 현실적인 조언을 합니다
                """,
                customPrompt: ""
            )
        case .design:
            return DepartmentSkillSet(
                roleName: "10년차 시니어 디자이너 (UI/UX 전문가)",
                expertise: [
                    "UI/UX 디자인 및 사용자 경험 설계",
                    "디자인 시스템 구축 및 운영",
                    "프로토타이핑 및 사용성 테스트",
                    "브랜드 아이덴티티 및 비주얼 디자인",
                    "디자인-개발 협업 프로세스"
                ],
                workStyle: """
                - 사용자 관점에서 문제를 바라봅니다
                - 심미성과 사용성의 균형을 중시합니다
                - 구체적인 디자인 방향과 레퍼런스를 제시합니다
                """,
                customPrompt: ""
            )
        case .development:
            return DepartmentSkillSet(
                roleName: "10년차 시니어 개발자 (풀스택 + 아키텍트)",
                expertise: [
                    "소프트웨어 아키텍처 설계",
                    "프론트엔드/백엔드 개발",
                    "코드 리뷰 및 기술 멘토링",
                    "성능 최적화 및 확장성 설계",
                    "DevOps 및 CI/CD 파이프라인"
                ],
                workStyle: """
                - 기술적 실현 가능성을 먼저 검토합니다
                - 확장성과 유지보수성을 고려합니다
                - 구체적인 기술 스택과 구현 방안을 제안합니다
                """,
                customPrompt: ""
            )
        case .qa:
            return DepartmentSkillSet(
                roleName: "10년차 시니어 QA 엔지니어",
                expertise: [
                    "테스트 전략 수립 및 테스트 계획",
                    "자동화 테스트 프레임워크 구축",
                    "버그 트래킹 및 품질 메트릭 관리",
                    "성능/보안/접근성 테스트",
                    "릴리즈 품질 게이트 관리"
                ],
                workStyle: """
                - 엣지 케이스와 예외 상황을 먼저 고려합니다
                - 품질 기준과 테스트 범위를 명확히 합니다
                - 리스크 기반 테스트 우선순위를 제안합니다
                """,
                customPrompt: ""
            )
        case .marketing:
            return DepartmentSkillSet(
                roleName: "10년차 시니어 마케터 (디지털 마케팅 + 그로스 해킹)",
                expertise: [
                    "마케팅 전략 및 캠페인 기획",
                    "콘텐츠 마케팅 및 브랜딩",
                    "퍼포먼스 마케팅 및 데이터 분석",
                    "사용자 획득 및 리텐션 전략",
                    "PR 및 커뮤니케이션"
                ],
                workStyle: """
                - 타겟 고객과 시장 포지셔닝을 파악하려 합니다
                - 데이터 기반 의사결정을 중시합니다
                - 측정 가능한 마케팅 목표를 설정합니다
                """,
                customPrompt: ""
            )
        case .general:
            return DepartmentSkillSet(
                roleName: "10년차 베테랑 직원",
                expertise: [
                    "다양한 업무 경험",
                    "회사 전반 이해"
                ],
                workStyle: "다방면에서 도움을 줄 수 있습니다",
                customPrompt: ""
            )
        }
    }
}

/// 동적 코딩 키
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
