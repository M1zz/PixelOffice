import Foundation

/// 요구사항을 태스크로 분해하는 서비스
actor RequirementDecomposer {
    private let claudeService = ClaudeCodeService()

    /// 요구사항 분해
    /// - Parameters:
    ///   - requirement: 사용자 요구사항
    ///   - projectInfo: 프로젝트 정보
    ///   - projectContext: 추가 컨텍스트 (CLAUDE.md 등)
    ///   - autoApprove: AI 도구 자동 승인 여부
    /// - Returns: 분해된 태스크 목록
    func decompose(
        requirement: String,
        projectInfo: ProjectInfo?,
        projectContext: String = "",
        autoApprove: Bool = true
    ) async throws -> DecompositionResult {
        let prompt = buildDecompositionPrompt(
            requirement: requirement,
            projectInfo: projectInfo,
            projectContext: projectContext
        )

        let systemPrompt = """
        당신은 소프트웨어 개발 프로젝트 매니저입니다.
        사용자의 요구사항을 분석하여 실행 가능한 개발 태스크로 분해합니다.

        응답은 반드시 JSON 형식으로만 해주세요.
        """

        let response = try await claudeService.sendMessage(
            prompt,
            systemPrompt: systemPrompt,
            autoApprove: autoApprove
        )

        return try parseDecompositionResponse(response)
    }

    /// 분해 프롬프트 생성
    private func buildDecompositionPrompt(
        requirement: String,
        projectInfo: ProjectInfo?,
        projectContext: String
    ) -> String {
        var prompt = """
        다음 요구사항을 개발 태스크로 분해해주세요.

        ## 요구사항
        \(requirement)

        """

        if let info = projectInfo {
            prompt += """

            ## 프로젝트 정보
            - 언어: \(info.language.isEmpty ? "미지정" : info.language)
            - 프레임워크: \(info.framework.isEmpty ? "미지정" : info.framework)
            - 빌드 도구: \(info.buildTool.isEmpty ? "미지정" : info.buildTool)
            - 비전: \(info.vision.isEmpty ? "미지정" : info.vision)
            """
        }

        if !projectContext.isEmpty {
            prompt += """

            ## 프로젝트 컨텍스트
            \(projectContext)
            """
        }

        prompt += """

        ## 응답 형식
        반드시 다음 JSON 형식으로만 응답하세요:
        ```json
        {
            "tasks": [
                {
                    "title": "태스크 제목",
                    "description": "상세 설명",
                    "department": "개발",
                    "priority": "medium",
                    "dependencies": [],
                    "order": 1
                }
            ],
            "summary": "요약",
            "warnings": ["주의사항"],
            "estimatedTime": "예상 소요 시간"
        }
        ```

        ## 규칙
        1. 부서(department)는 다음 중 하나: 기획, 디자인, 개발, QA, 마케팅
        2. 우선순위(priority)는: low, medium, high, critical
        3. dependencies는 선행되어야 하는 태스크의 order 번호 배열
        4. 개발 태스크를 중심으로 분해하되, 필요시 다른 부서 태스크도 포함
        5. 각 태스크는 구체적이고 실행 가능해야 함
        6. MVP 범위로 최소한의 태스크로 분해

        JSON만 응답하세요.
        """

        return prompt
    }

    /// Claude 응답 파싱
    private func parseDecompositionResponse(_ response: String) throws -> DecompositionResult {
        // JSON 블록 추출
        var jsonString = response

        // ```json ... ``` 블록 추출
        if let jsonRange = response.range(of: "```json"),
           let endRange = response.range(of: "```", range: jsonRange.upperBound..<response.endIndex) {
            jsonString = String(response[jsonRange.upperBound..<endRange.lowerBound])
        } else if let startBrace = response.firstIndex(of: "{"),
                  let endBrace = response.lastIndex(of: "}") {
            jsonString = String(response[startBrace...endBrace])
        }

        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8) else {
            throw DecompositionError.parseError("Failed to convert response to data")
        }

        do {
            let claudeResponse = try JSONDecoder().decode(ClaudeTaskResponse.self, from: data)

            // ClaudeTask -> DecomposedTask 변환
            var tasks: [DecomposedTask] = []
            var idMap: [Int: UUID] = [:] // order -> UUID 매핑

            // 먼저 모든 태스크 생성
            for (index, claudeTask) in claudeResponse.tasks.enumerated() {
                var task = DecomposedTask.from(claudeTask: claudeTask, index: index, allTasks: claudeResponse.tasks)
                idMap[claudeTask.order ?? index] = task.id
                tasks.append(task)
            }

            // 의존성 설정
            for (index, claudeTask) in claudeResponse.tasks.enumerated() {
                if let deps = claudeTask.dependencies {
                    tasks[index].dependencies = deps.compactMap { idMap[$0] }
                }
            }

            return DecompositionResult(
                tasks: tasks,
                summary: claudeResponse.summary ?? "",
                warnings: claudeResponse.warnings ?? [],
                estimatedTime: claudeResponse.estimatedTime
            )
        } catch {
            print("[RequirementDecomposer] JSON parse error: \(error)")
            print("[RequirementDecomposer] JSON string: \(jsonString)")
            throw DecompositionError.parseError("JSON 파싱 실패: \(error.localizedDescription)")
        }
    }
}

enum DecompositionError: LocalizedError {
    case parseError(String)
    case emptyResponse
    case noTasks

    var errorDescription: String? {
        switch self {
        case .parseError(let message):
            return "분해 응답 파싱 실패: \(message)"
        case .emptyResponse:
            return "분해 응답이 비어있습니다"
        case .noTasks:
            return "분해된 태스크가 없습니다"
        }
    }
}
