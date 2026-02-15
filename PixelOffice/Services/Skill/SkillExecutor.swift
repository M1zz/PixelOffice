import Foundation

/// 스킬 실행을 담당하는 서비스
class SkillExecutor {
    
    // MARK: - Private Properties
    
    private let claudeService = ClaudeCodeService()
    private let registry = SkillRegistry.shared
    
    // MARK: - Public Methods
    
    /// 스킬 실행
    func execute(_ request: SkillExecutionRequest) async throws -> SkillExecutionResult {
        guard let skill = registry.getSkill(request.skillId) else {
            throw SkillExecutionError.skillNotFound(request.skillId)
        }
        
        let startTime = Date()
        
        // 프롬프트 빌드
        let prompt = buildPrompt(skill: skill, input: request.input, context: request.context)
        let systemPrompt = skill.systemPrompt ?? "당신은 전문가입니다. 주어진 태스크를 완수합니다."
        
        // 도구 허용 설정
        let allowedTools: ClaudeCodeService.AllowedTools
        if request.options?.allowFileWrite == true {
            allowedTools = (request.options?.autoApprove ?? true) ? .all : .readOnly
        } else {
            allowedTools = .readOnly
        }
        
        // Claude Code 호출
        let tokenResult = try await claudeService.sendMessageWithTokens(
            prompt,
            systemPrompt: systemPrompt,
            allowedTools: allowedTools,
            workingDirectory: request.context?.projectPath
        )
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // 결과 파싱
        let parsedOutput = parseOutput(from: tokenResult.response, skill: skill)
        let artifacts = parseArtifacts(from: tokenResult.response, skill: skill)
        
        let metrics = SkillExecutionMetrics(
            executionTime: executionTime,
            inputTokens: tokenResult.inputTokens,
            outputTokens: tokenResult.outputTokens,
            costUSD: tokenResult.totalCostUSD,
            cacheHit: tokenResult.cacheReadInputTokens > 0
        )
        
        return SkillExecutionResult(
            skillId: skill.id,
            success: true,
            output: parsedOutput,
            error: nil,
            metrics: metrics,
            artifacts: artifacts
        )
    }
    
    /// 여러 스킬을 순차적으로 실행
    func executeSequence(_ requests: [SkillExecutionRequest]) async throws -> [SkillExecutionResult] {
        var results: [SkillExecutionResult] = []
        
        for request in requests {
            let result = try await execute(request)
            results.append(result)
            
            // 실패 시 중단
            if !result.success {
                break
            }
        }
        
        return results
    }
    
    /// 여러 스킬을 병렬로 실행
    func executeParallel(_ requests: [SkillExecutionRequest]) async throws -> [SkillExecutionResult] {
        return try await withThrowingTaskGroup(of: SkillExecutionResult.self) { group in
            for request in requests {
                group.addTask {
                    try await self.execute(request)
                }
            }
            
            var results: [SkillExecutionResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    /// 스킬 체인 실행 (이전 결과를 다음 입력으로)
    func executeChain(
        skillIds: [String],
        initialInput: [String: AnyCodable],
        context: SkillContext?
    ) async throws -> SkillExecutionResult {
        var currentInput = initialInput
        var lastResult: SkillExecutionResult?
        
        for skillId in skillIds {
            let request = SkillExecutionRequest(
                skillId: skillId,
                input: currentInput,
                context: context
            )
            
            let result = try await execute(request)
            
            if !result.success {
                return result
            }
            
            // 다음 스킬의 입력으로 전달
            if let output = result.output {
                currentInput = output
            }
            
            lastResult = result
        }
        
        return lastResult ?? SkillExecutionResult(
            skillId: skillIds.last ?? "",
            success: false,
            output: nil,
            error: "실행할 스킬이 없습니다",
            metrics: SkillExecutionMetrics(executionTime: 0, inputTokens: 0, outputTokens: 0, costUSD: 0)
        )
    }
    
    // MARK: - Private Methods
    
    /// 프롬프트 빌드
    private func buildPrompt(
        skill: Skill,
        input: [String: AnyCodable],
        context: SkillContext?
    ) -> String {
        var prompt = skill.promptTemplate
        
        // 입력 값 치환
        for (key, value) in input {
            let placeholder = "{{\(key)}}"
            let stringValue = String(describing: value.value)
            prompt = prompt.replacingOccurrences(of: placeholder, with: stringValue)
        }
        
        // {{input}} 기본 치환
        if prompt.contains("{{input}}") {
            if let inputValue = input["input"]?.value as? String {
                prompt = prompt.replacingOccurrences(of: "{{input}}", with: inputValue)
            }
        }
        
        // 컨텍스트 추가
        if let context = context {
            var contextSection = "\n\n## 컨텍스트\n"
            
            if let projectPath = context.projectPath {
                contextSection += "- 프로젝트 경로: \(projectPath)\n"
            }
            
            if let projectInfo = context.projectInfo {
                contextSection += "- 언어: \(projectInfo.language)\n"
                contextSection += "- 프레임워크: \(projectInfo.framework)\n"
            }
            
            if let additional = context.additionalContext, !additional.isEmpty {
                contextSection += "\n\(additional)\n"
            }
            
            if let relatedFiles = context.relatedFiles, !relatedFiles.isEmpty {
                contextSection += "\n관련 파일:\n"
                for file in relatedFiles {
                    contextSection += "- \(file)\n"
                }
            }
            
            prompt += contextSection
        }
        
        return prompt
    }
    
    /// 출력 파싱
    private func parseOutput(from response: String, skill: Skill) -> [String: AnyCodable]? {
        var output: [String: AnyCodable] = [:]
        
        // 기본 결과
        output["result"] = AnyCodable(response)
        
        // 스키마 기반 파싱 (간단한 구현)
        if let schema = skill.outputSchema {
            for (key, _) in schema.properties {
                // <<<KEY>>>...<<<END_KEY>>> 형식 파싱
                let pattern = "<<<\(key.uppercased())>>>(.*?)<<<END_\(key.uppercased())>>>"
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
                   let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)),
                   let range = Range(match.range(at: 1), in: response) {
                    let value = String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    output[key] = AnyCodable(value)
                }
            }
        }
        
        // 코드 블록 추출
        let codeBlocks = extractCodeBlocks(from: response)
        if !codeBlocks.isEmpty {
            output["codeBlocks"] = AnyCodable(codeBlocks)
        }
        
        return output
    }
    
    /// 코드 블록 추출
    private func extractCodeBlocks(from response: String) -> [[String: String]] {
        var blocks: [[String: String]] = []
        
        let pattern = #"```(\w*)\n([\s\S]*?)```"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return blocks
        }
        
        let matches = regex.matches(in: response, options: [], range: NSRange(response.startIndex..., in: response))
        
        for match in matches {
            var block: [String: String] = [:]
            
            if let langRange = Range(match.range(at: 1), in: response) {
                block["language"] = String(response[langRange])
            }
            
            if let codeRange = Range(match.range(at: 2), in: response) {
                block["code"] = String(response[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            if !block.isEmpty {
                blocks.append(block)
            }
        }
        
        return blocks
    }
    
    /// 아티팩트 파싱
    private func parseArtifacts(from response: String, skill: Skill) -> [SubAgentArtifact] {
        var artifacts: [SubAgentArtifact] = []
        
        // 코드 블록을 아티팩트로 변환
        let codeBlocks = extractCodeBlocks(from: response)
        
        for (index, block) in codeBlocks.enumerated() {
            guard let code = block["code"], !code.isEmpty else { continue }
            
            let language = block["language"] ?? "text"
            let artifactType: SubAgentArtifact.ArtifactType
            
            switch language.lowercased() {
            case "swift", "python", "javascript", "typescript", "java", "kotlin", "go", "rust":
                artifactType = .code
            case "html", "css", "scss":
                artifactType = .design
            case "json", "yaml", "xml":
                artifactType = .data
            case "markdown", "md":
                artifactType = .document
            default:
                artifactType = .other
            }
            
            artifacts.append(SubAgentArtifact(
                name: "\(skill.name)-\(index + 1).\(language)",
                type: artifactType,
                content: code
            ))
        }
        
        // <<<ARTIFACT>>>...<<<END_ARTIFACT>>> 형식도 지원
        let pattern = #"<<<ARTIFACT>>>([\s\S]*?)<<<END_ARTIFACT>>>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: response, options: [], range: NSRange(response.startIndex..., in: response))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: response) {
                    let content = String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    artifacts.append(SubAgentArtifact(
                        name: "\(skill.name)-artifact",
                        type: .other,
                        content: content
                    ))
                }
            }
        }
        
        return artifacts
    }
}

// MARK: - Errors

/// 스킬 실행 에러
enum SkillExecutionError: LocalizedError {
    case skillNotFound(String)
    case invalidInput(String)
    case executionFailed(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .skillNotFound(let id):
            return "스킬을 찾을 수 없습니다: \(id)"
        case .invalidInput(let message):
            return "잘못된 입력: \(message)"
        case .executionFailed(let message):
            return "실행 실패: \(message)"
        case .timeout:
            return "실행 시간 초과"
        }
    }
}

// MARK: - Convenience Extensions

extension SkillExecutor {
    
    /// 간편한 스킬 실행 (입력 문자열만)
    func execute(
        skillId: String,
        input: String,
        projectPath: String? = nil,
        autoApprove: Bool = true
    ) async throws -> SkillExecutionResult {
        let request = SkillExecutionRequest(
            skillId: skillId,
            input: ["input": AnyCodable(input)],
            context: projectPath != nil ? SkillContext(projectPath: projectPath) : nil,
            options: SkillExecutionOptions(autoApprove: autoApprove)
        )
        
        return try await execute(request)
    }
    
    /// 코드 분석 실행
    func analyzeCode(
        _ code: String,
        focus: String = "general",
        projectPath: String? = nil
    ) async throws -> SkillExecutionResult {
        let request = SkillExecutionRequest(
            skillId: "code-analysis",
            input: [
                "code": AnyCodable(code),
                "focus": AnyCodable(focus)
            ],
            context: projectPath != nil ? SkillContext(projectPath: projectPath) : nil
        )
        
        return try await execute(request)
    }
    
    /// 테스트 생성 실행
    func generateTests(
        for code: String,
        framework: String = "XCTest",
        projectPath: String? = nil
    ) async throws -> SkillExecutionResult {
        let request = SkillExecutionRequest(
            skillId: "test-gen",
            input: [
                "code": AnyCodable(code),
                "framework": AnyCodable(framework)
            ],
            context: projectPath != nil ? SkillContext(projectPath: projectPath) : nil
        )
        
        return try await execute(request)
    }
    
    /// 문서 생성 실행
    func generateDocumentation(
        for code: String,
        format: String = "markdown",
        projectPath: String? = nil
    ) async throws -> SkillExecutionResult {
        let request = SkillExecutionRequest(
            skillId: "doc-gen",
            input: [
                "code": AnyCodable(code),
                "format": AnyCodable(format)
            ],
            context: projectPath != nil ? SkillContext(projectPath: projectPath) : nil
        )
        
        return try await execute(request)
    }
    
    /// 리팩토링 실행
    func refactor(
        _ code: String,
        focus: String = "readability",
        projectPath: String? = nil
    ) async throws -> SkillExecutionResult {
        let request = SkillExecutionRequest(
            skillId: "refactor",
            input: [
                "code": AnyCodable(code),
                "focus": AnyCodable(focus)
            ],
            context: projectPath != nil ? SkillContext(projectPath: projectPath) : nil
        )
        
        return try await execute(request)
    }
    
    /// 디자인 → HTML 변환
    func designToHTML(
        _ design: String,
        style: String = "css",
        projectPath: String? = nil
    ) async throws -> SkillExecutionResult {
        let request = SkillExecutionRequest(
            skillId: "design-to-html",
            input: [
                "design": AnyCodable(design),
                "style": AnyCodable(style)
            ],
            context: projectPath != nil ? SkillContext(projectPath: projectPath) : nil
        )
        
        return try await execute(request)
    }
}
