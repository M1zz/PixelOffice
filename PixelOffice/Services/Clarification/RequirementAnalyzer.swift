import Foundation

/// 요구사항을 분석하여 필요한 질문을 생성하는 서비스
actor RequirementAnalyzer {
    private let claudeService = ClaudeCodeService()

    /// 부서별 질문 템플릿
    private let departmentQuestionTemplates: [DepartmentType: [String]] = [
        .planning: [
            "타겟 사용자가 누구인가요?",
            "성공 기준이 뭔가요?",
            "기능의 우선순위가 어떻게 되나요?",
            "비즈니스 목표와 어떻게 연결되나요?"
        ],
        .design: [
            "참고할 디자인이 있나요?",
            "다크모드 지원 필요한가요?",
            "컬러/폰트 가이드가 있나요?",
            "특별히 중요한 UX 요구사항이 있나요?"
        ],
        .development: [
            "기술 스택 제약이 있나요?",
            "성능 요구사항이 있나요?",
            "기존 코드와 호환성 고려할 게 있나요?",
            "API 연동이 필요한가요?"
        ],
        .qa: [
            "테스트해야 할 핵심 시나리오가 뭔가요?",
            "엣지 케이스 고려할 게 있나요?",
            "품질 기준이 있나요?"
        ],
        .marketing: [
            "출시 일정이 있나요?",
            "특별히 강조할 기능이 있나요?",
            "타겟 마케팅 채널이 있나요?"
        ]
    ]

    /// 요구사항 분석 및 질문 생성
    /// - Parameters:
    ///   - requirement: 사용자 요구사항
    ///   - project: 프로젝트 정보
    ///   - employees: 프로젝트 직원 목록
    /// - Returns: 생성된 질문 목록
    func analyzeRequirement(
        requirement: String,
        project: Project,
        employees: [ProjectEmployee]
    ) async throws -> [ClarificationRequest] {
        let prompt = buildAnalysisPrompt(requirement: requirement, project: project)

        let systemPrompt = """
        당신은 프로젝트 분석 전문가입니다.
        사용자의 요구사항을 분석하여 부족한 정보를 파악하고 적절한 질문을 생성합니다.
        
        각 부서(기획, 디자인, 개발, QA, 마케팅)의 관점에서 필요한 정보가 무엇인지 판단하세요.
        질문은 구체적이고 명확해야 하며, 가능하면 선택지를 제공하세요.
        
        응답은 반드시 JSON 형식으로만 해주세요.
        """

        let response = try await claudeService.sendMessage(
            prompt,
            systemPrompt: systemPrompt,
            autoApprove: true
        )

        return try parseAnalysisResponse(response, employees: employees)
    }

    /// 분석 프롬프트 생성
    private func buildAnalysisPrompt(requirement: String, project: Project) -> String {
        let prompt = """
        다음 요구사항을 분석하여 부족한 정보에 대한 질문을 생성해주세요.

        ## 요구사항
        \(requirement)

        ## 프로젝트 정보
        - 이름: \(project.name)
        - 설명: \(project.description)
        - 상태: \(project.status.rawValue)

        ## 부서별 관점
        각 부서에서 필요할 수 있는 정보:

        **기획팀:**
        - 타겟 사용자, 성공 기준, 우선순위, 비즈니스 목표

        **디자인팀:**
        - 참고 디자인, 다크모드, 컬러/폰트 가이드, UX 요구사항

        **개발팀:**
        - 기술 스택, 성능 요구사항, 코드 호환성, API 연동

        **QA팀:**
        - 핵심 테스트 시나리오, 엣지 케이스, 품질 기준

        **마케팅팀:**
        - 출시 일정, 강조 기능, 마케팅 채널

        ## 응답 형식
        반드시 다음 JSON 형식으로만 응답하세요:
        ```json
        {
            "questions": [
                {
                    "question": "질문 내용",
                    "department": "기획",
                    "context": "이 질문이 필요한 이유",
                    "options": ["옵션1", "옵션2", "옵션3"],
                    "priority": "critical"
                }
            ],
            "summary": "요구사항 분석 요약"
        }
        ```

        ## 규칙
        1. 부서(department)는 다음 중 하나: 기획, 디자인, 개발, QA, 마케팅
        2. 우선순위(priority): critical(필수), important(중요), optional(선택)
        3. options는 선택지가 명확한 경우에만 제공 (없으면 null 또는 빈 배열)
        4. 이미 요구사항에 명시된 정보는 질문하지 않음
        5. 최대 5개의 핵심 질문만 생성 (너무 많으면 사용자 피로)
        6. 실제로 개발에 필요한 질문만 생성

        JSON만 응답하세요.
        """

        return prompt
    }

    /// AI 응답 파싱
    private func parseAnalysisResponse(
        _ response: String,
        employees: [ProjectEmployee]
    ) throws -> [ClarificationRequest] {
        // JSON 블록 추출
        var jsonString = response

        if let jsonRange = response.range(of: "```json"),
           let endRange = response.range(of: "```", range: jsonRange.upperBound..<response.endIndex) {
            jsonString = String(response[jsonRange.upperBound..<endRange.lowerBound])
        } else if let startBrace = response.firstIndex(of: "{"),
                  let endBrace = response.lastIndex(of: "}") {
            jsonString = String(response[startBrace...endBrace])
        }

        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8) else {
            throw ClarificationError.parseError("응답을 데이터로 변환할 수 없습니다")
        }

        do {
            let decoded = try JSONDecoder().decode(ClarificationResponse.self, from: data)
            return decoded.questions.map { q in
                let dept = parseDepartmentType(q.department)
                let employee = findRepresentativeEmployee(for: dept, in: employees)

                return ClarificationRequest(
                    question: q.question,
                    askedBy: employee?.name ?? "\(dept.rawValue)팀 담당자",
                    department: dept,
                    context: q.context,
                    options: q.options?.isEmpty == true ? nil : q.options,
                    priority: parsePriority(q.priority)
                )
            }
        } catch {
            print("[RequirementAnalyzer] JSON parse error: \(error)")
            print("[RequirementAnalyzer] JSON string: \(jsonString)")
            throw ClarificationError.parseError("JSON 파싱 실패: \(error.localizedDescription)")
        }
    }

    /// 부서 타입 파싱
    private func parseDepartmentType(_ string: String) -> DepartmentType {
        switch string.lowercased() {
        case "기획", "planning": return .planning
        case "디자인", "design": return .design
        case "개발", "development": return .development
        case "qa", "품질", "테스트": return .qa
        case "마케팅", "marketing": return .marketing
        default: return .general
        }
    }

    /// 우선순위 파싱
    private func parsePriority(_ string: String) -> ClarificationPriority {
        switch string.lowercased() {
        case "critical", "필수": return .critical
        case "important", "중요": return .important
        case "optional", "선택": return .optional
        default: return .important
        }
    }

    /// 부서 대표 직원 찾기
    private func findRepresentativeEmployee(
        for department: DepartmentType,
        in employees: [ProjectEmployee]
    ) -> ProjectEmployee? {
        // 해당 부서의 직원 중 첫 번째 반환
        return employees.first { $0.departmentType == department }
    }
}

// MARK: - Response Models

/// AI 응답 파싱용 구조체
private struct ClarificationResponse: Codable {
    let questions: [ClarificationQuestion]
    let summary: String?
}

private struct ClarificationQuestion: Codable {
    let question: String
    let department: String
    let context: String?
    let options: [String]?
    let priority: String
}

// MARK: - Errors

enum ClarificationError: LocalizedError {
    case parseError(String)
    case emptyResponse
    case noQuestions

    var errorDescription: String? {
        switch self {
        case .parseError(let message):
            return "분석 응답 파싱 실패: \(message)"
        case .emptyResponse:
            return "분석 응답이 비어있습니다"
        case .noQuestions:
            return "생성된 질문이 없습니다"
        }
    }
}
