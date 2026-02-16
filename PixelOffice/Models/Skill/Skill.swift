import Foundation
import SwiftUI

// MARK: - Skill

/// 재사용 가능한 능력 모듈
struct Skill: Codable, Identifiable, Hashable {
    var id: String  // 예: "code-analysis", "design-to-html"
    var name: String
    var description: String
    var category: SkillCategory
    var version: String = "1.0.0"
    
    /// 스킬 실행에 필요한 프롬프트 템플릿
    var promptTemplate: String
    
    /// 시스템 프롬프트 (역할 정의)
    var systemPrompt: String?
    
    /// 입력 스키마 (JSON Schema 형식)
    var inputSchema: SkillSchema?
    
    /// 출력 스키마 (JSON Schema 형식)
    var outputSchema: SkillSchema?
    
    /// 필요한 도구들
    var requiredTools: [SkillTool] = []
    
    /// 예상 토큰 사용량 (입력 + 출력)
    var estimatedTokens: Int?
    
    /// 예상 실행 시간 (초)
    var estimatedDuration: TimeInterval?
    
    /// 태그 (검색/필터용)
    var tags: [String] = []
    
    /// 커스텀 스킬 여부
    var isCustom: Bool = false
    
    /// 생성일
    var createdAt: Date = Date()
    
    /// 마지막 수정일
    var updatedAt: Date = Date()
    
    // MARK: - Hashable
    
    static func == (lhs: Skill, rhs: Skill) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Skill Category

/// 스킬 카테고리
enum SkillCategory: String, Codable, CaseIterable {
    case analysis = "분석"
    case generation = "생성"
    case transformation = "변환"
    case testing = "테스팅"
    case documentation = "문서화"
    case design = "디자인"
    case optimization = "최적화"
    case custom = "커스텀"
    
    var icon: String {
        switch self {
        case .analysis: return "magnifyingglass.circle"
        case .generation: return "plus.circle"
        case .transformation: return "arrow.triangle.2.circlepath"
        case .testing: return "checkmark.shield"
        case .documentation: return "doc.text"
        case .design: return "paintbrush"
        case .optimization: return "speedometer"
        case .custom: return "gearshape"
        }
    }
    
    var color: Color {
        switch self {
        case .analysis: return .purple
        case .generation: return .blue
        case .transformation: return .orange
        case .testing: return .green
        case .documentation: return .cyan
        case .design: return .pink
        case .optimization: return .yellow
        case .custom: return .secondary
        }
    }
}

// MARK: - Skill Schema

/// 스킬 입출력 스키마
struct SkillSchema: Codable, Hashable {
    var type: String = "object"
    var properties: [String: SchemaProperty]
    var required: [String] = []
    var description: String?
}

/// 스키마 속성
struct SchemaProperty: Codable, Hashable {
    var type: String  // "string", "number", "boolean", "array", "object"
    var description: String?
    var enumValues: [String]?  // enum 타입일 때
    var defaultValue: String?
    var itemType: String?  // array 타입일 때 요소 타입 (재귀 방지)
    var itemDescription: String?  // array 요소 설명
    
    enum CodingKeys: String, CodingKey {
        case type, description
        case enumValues = "enum"
        case defaultValue = "default"
        case itemType, itemDescription
    }
}

// MARK: - Skill Tool

/// 스킬에서 사용하는 도구
struct SkillTool: Codable, Hashable {
    var name: String
    var description: String
    var isRequired: Bool = false
}

// MARK: - Skill Execution

/// 스킬 실행 요청
struct SkillExecutionRequest: Codable {
    var skillId: String
    var input: [String: AnyCodable]
    var context: SkillContext?
    var options: SkillExecutionOptions?
}

/// 스킬 실행 컨텍스트
struct SkillContext: Codable {
    var projectPath: String?
    var projectInfo: ProjectInfo?
    var additionalContext: String?
    var relatedFiles: [String]?
}

/// 스킬 실행 옵션
struct SkillExecutionOptions: Codable {
    var autoApprove: Bool = true
    var maxTokens: Int?
    var timeout: TimeInterval?
    var allowFileWrite: Bool = true
}

/// 스킬 실행 결과
struct SkillExecutionResult: Codable {
    var skillId: String
    var success: Bool
    var output: [String: AnyCodable]?
    var error: String?
    var metrics: SkillExecutionMetrics
    var artifacts: [SubAgentArtifact] = []
}

/// 스킬 실행 메트릭
struct SkillExecutionMetrics: Codable {
    var executionTime: TimeInterval
    var inputTokens: Int
    var outputTokens: Int
    var costUSD: Double
    var cacheHit: Bool = false
}

// MARK: - AnyCodable (for dynamic JSON)

/// 동적 JSON 값을 위한 래퍼
struct AnyCodable: Codable, Hashable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode AnyCodable"))
        }
    }
    
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // 단순 비교를 위해 문자열로 변환
        String(describing: lhs.value) == String(describing: rhs.value)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}

// MARK: - Built-in Skills

/// 기본 제공 스킬 정의
enum BuiltInSkills {
    
    /// 코드 분석 스킬
    static let codeAnalysis = Skill(
        id: "code-analysis",
        name: "코드 분석",
        description: "프로젝트의 코드 구조, 의존성, 패턴을 분석합니다.",
        category: .analysis,
        promptTemplate: """
        다음 코드/프로젝트를 분석해주세요:
        
        {{input}}
        
        분석 결과를 다음 형식으로 제공해주세요:
        1. 구조 분석
        2. 주요 컴포넌트
        3. 의존성 관계
        4. 코드 품질 이슈
        5. 개선 제안
        """,
        systemPrompt: "당신은 시니어 소프트웨어 아키텍트입니다. 코드 구조를 분석하고 개선점을 제안합니다.",
        inputSchema: SkillSchema(
            properties: [
                "code": SchemaProperty(type: "string", description: "분석할 코드 또는 파일 경로"),
                "focus": SchemaProperty(type: "string", description: "분석 초점 (architecture, performance, security)")
            ],
            required: ["code"]
        ),
        outputSchema: SkillSchema(
            properties: [
                "structure": SchemaProperty(type: "object", description: "구조 분석 결과"),
                "issues": SchemaProperty(type: "array", description: "발견된 이슈들"),
                "suggestions": SchemaProperty(type: "array", description: "개선 제안")
            ]
        ),
        tags: ["analysis", "architecture", "quality"]
    )
    
    /// 디자인 → HTML 변환 스킬
    static let designToHTML = Skill(
        id: "design-to-html",
        name: "디자인 → HTML",
        description: "디자인 스펙을 HTML/CSS 코드로 변환합니다.",
        category: .transformation,
        promptTemplate: """
        다음 디자인 스펙을 HTML/CSS로 구현해주세요:
        
        {{input}}
        
        요구사항:
        - 시맨틱 HTML5 사용
        - 반응형 디자인 적용
        - 접근성 고려 (ARIA)
        - CSS Grid/Flexbox 활용
        """,
        systemPrompt: "당신은 프론트엔드 전문가입니다. 디자인을 정확하게 HTML/CSS로 구현합니다.",
        inputSchema: SkillSchema(
            properties: [
                "design": SchemaProperty(type: "string", description: "디자인 스펙 또는 설명"),
                "style": SchemaProperty(type: "string", description: "스타일 프레임워크 (tailwind, css, scss)")
            ],
            required: ["design"]
        ),
        outputSchema: SkillSchema(
            properties: [
                "html": SchemaProperty(type: "string", description: "생성된 HTML"),
                "css": SchemaProperty(type: "string", description: "생성된 CSS"),
                "preview": SchemaProperty(type: "string", description: "프리뷰용 완전한 HTML")
            ]
        ),
        tags: ["design", "html", "css", "frontend"]
    )
    
    /// 테스트 코드 생성 스킬
    static let testGeneration = Skill(
        id: "test-gen",
        name: "테스트 생성",
        description: "코드에 대한 테스트 코드를 자동 생성합니다.",
        category: .testing,
        promptTemplate: """
        다음 코드에 대한 테스트를 작성해주세요:
        
        {{input}}
        
        요구사항:
        - 단위 테스트 작성
        - 엣지 케이스 커버
        - 테스트 설명 포함
        - 프로젝트 테스트 프레임워크 사용
        """,
        systemPrompt: "당신은 QA 엔지니어입니다. 철저한 테스트 코드를 작성합니다.",
        inputSchema: SkillSchema(
            properties: [
                "code": SchemaProperty(type: "string", description: "테스트할 코드"),
                "framework": SchemaProperty(type: "string", description: "테스트 프레임워크 (XCTest, Jest, pytest)")
            ],
            required: ["code"]
        ),
        outputSchema: SkillSchema(
            properties: [
                "tests": SchemaProperty(type: "string", description: "생성된 테스트 코드"),
                "coverage": SchemaProperty(type: "array", description: "커버되는 케이스들")
            ]
        ),
        tags: ["testing", "quality", "automation"]
    )
    
    /// 리팩토링 제안 스킬
    static let refactoring = Skill(
        id: "refactor",
        name: "리팩토링",
        description: "코드 품질 개선을 위한 리팩토링을 제안하고 실행합니다.",
        category: .optimization,
        promptTemplate: """
        다음 코드를 리팩토링해주세요:
        
        {{input}}
        
        리팩토링 원칙:
        - SOLID 원칙 적용
        - 코드 중복 제거
        - 가독성 향상
        - 성능 최적화 (필요시)
        
        변경 전후를 명확히 설명해주세요.
        """,
        systemPrompt: "당신은 리팩토링 전문가입니다. 코드 품질을 개선하면서 기능은 유지합니다.",
        inputSchema: SkillSchema(
            properties: [
                "code": SchemaProperty(type: "string", description: "리팩토링할 코드"),
                "focus": SchemaProperty(type: "string", description: "리팩토링 초점 (readability, performance, solid)")
            ],
            required: ["code"]
        ),
        outputSchema: SkillSchema(
            properties: [
                "refactoredCode": SchemaProperty(type: "string", description: "리팩토링된 코드"),
                "changes": SchemaProperty(type: "array", description: "변경 사항 목록"),
                "rationale": SchemaProperty(type: "string", description: "리팩토링 이유")
            ]
        ),
        tags: ["refactoring", "quality", "optimization"]
    )
    
    /// 문서 자동 생성 스킬
    static let docGeneration = Skill(
        id: "doc-gen",
        name: "문서 생성",
        description: "코드에 대한 문서를 자동으로 생성합니다.",
        category: .documentation,
        promptTemplate: """
        다음 코드에 대한 문서를 생성해주세요:
        
        {{input}}
        
        포함할 내용:
        - 개요/목적
        - API 레퍼런스 (함수, 클래스, 파라미터)
        - 사용 예제
        - 주의사항
        
        마크다운 형식으로 작성해주세요.
        """,
        systemPrompt: "당신은 기술 문서 작성자입니다. 명확하고 이해하기 쉬운 문서를 작성합니다.",
        inputSchema: SkillSchema(
            properties: [
                "code": SchemaProperty(type: "string", description: "문서화할 코드"),
                "format": SchemaProperty(type: "string", description: "문서 형식 (markdown, docstring, readme)")
            ],
            required: ["code"]
        ),
        outputSchema: SkillSchema(
            properties: [
                "documentation": SchemaProperty(type: "string", description: "생성된 문서"),
                "apiReference": SchemaProperty(type: "object", description: "API 레퍼런스")
            ]
        ),
        tags: ["documentation", "api", "readme"]
    )
    
    // MARK: - Claude Code 스킬
    
    /// Claude Code 프로젝트 분석
    static let claudeCodeAnalyze = Skill(
        id: "claude-code-analyze",
        name: "Claude Code 분석",
        description: "Claude Code CLI로 프로젝트 전체 구조와 코드를 심층 분석합니다.",
        category: .analysis,
        promptTemplate: """
        프로젝트 분석 요청:
        
        {{input}}
        
        Claude Code가 프로젝트 컨텍스트를 이해하고 있으므로,
        전체 구조, 의존성, 아키텍처 패턴을 종합적으로 분석합니다.
        """,
        systemPrompt: nil,
        inputSchema: SkillSchema(
            properties: [
                "projectPath": SchemaProperty(type: "string", description: "프로젝트 경로"),
                "focus": SchemaProperty(type: "string", description: "분석 초점 (architecture, dependencies, patterns, security)")
            ],
            required: ["projectPath"]
        ),
        outputSchema: SkillSchema(
            properties: [
                "analysis": SchemaProperty(type: "object", description: "분석 결과"),
                "recommendations": SchemaProperty(type: "array", description: "개선 권장사항")
            ]
        ),
        requiredTools: [
            SkillTool(name: "claude", description: "Claude Code CLI", isRequired: true),
            SkillTool(name: "read", description: "파일 읽기", isRequired: true)
        ],
        tags: ["claude-code", "cli", "analysis", "architecture"]
    )
    
    /// Claude Code 코드 생성
    static let claudeCodeGenerate = Skill(
        id: "claude-code-generate",
        name: "Claude Code 코드 생성",
        description: "Claude Code CLI로 새로운 기능/파일을 생성합니다.",
        category: .generation,
        promptTemplate: """
        코드 생성 요청:
        
        {{input}}
        
        프로젝트 컨벤션과 기존 패턴을 따라 코드를 생성합니다.
        """,
        systemPrompt: nil,
        inputSchema: SkillSchema(
            properties: [
                "projectPath": SchemaProperty(type: "string", description: "프로젝트 경로"),
                "requirement": SchemaProperty(type: "string", description: "생성할 기능/코드 설명"),
                "targetPath": SchemaProperty(type: "string", description: "생성할 파일 경로 (선택)")
            ],
            required: ["projectPath", "requirement"]
        ),
        outputSchema: SkillSchema(
            properties: [
                "generatedFiles": SchemaProperty(type: "array", description: "생성된 파일 목록"),
                "code": SchemaProperty(type: "string", description: "생성된 코드")
            ]
        ),
        requiredTools: [
            SkillTool(name: "claude", description: "Claude Code CLI", isRequired: true),
            SkillTool(name: "write", description: "파일 쓰기", isRequired: true)
        ],
        tags: ["claude-code", "cli", "generation", "coding"]
    )
    
    /// Claude Code 리팩토링
    static let claudeCodeRefactor = Skill(
        id: "claude-code-refactor",
        name: "Claude Code 리팩토링",
        description: "Claude Code CLI로 기존 코드를 리팩토링합니다.",
        category: .optimization,
        promptTemplate: """
        리팩토링 요청:
        
        대상: {{targetFile}}
        
        {{input}}
        
        기존 기능을 유지하면서 코드 품질을 개선합니다.
        """,
        systemPrompt: nil,
        inputSchema: SkillSchema(
            properties: [
                "projectPath": SchemaProperty(type: "string", description: "프로젝트 경로"),
                "targetFile": SchemaProperty(type: "string", description: "리팩토링할 파일"),
                "focus": SchemaProperty(type: "string", description: "초점 (performance, readability, solid, dry)")
            ],
            required: ["projectPath", "targetFile"]
        ),
        outputSchema: SkillSchema(
            properties: [
                "changes": SchemaProperty(type: "array", description: "변경 사항"),
                "diff": SchemaProperty(type: "string", description: "변경 diff")
            ]
        ),
        requiredTools: [
            SkillTool(name: "claude", description: "Claude Code CLI", isRequired: true),
            SkillTool(name: "edit", description: "파일 수정", isRequired: true)
        ],
        tags: ["claude-code", "cli", "refactoring", "optimization"]
    )
    
    /// Claude Code 테스트 생성
    static let claudeCodeTest = Skill(
        id: "claude-code-test",
        name: "Claude Code 테스트 생성",
        description: "Claude Code CLI로 테스트 코드를 자동 생성합니다.",
        category: .testing,
        promptTemplate: """
        테스트 생성 요청:
        
        대상: {{targetFile}}
        
        프로젝트의 테스트 프레임워크와 컨벤션을 따라
        단위 테스트를 생성합니다.
        
        {{additionalRequirements}}
        """,
        systemPrompt: nil,
        inputSchema: SkillSchema(
            properties: [
                "projectPath": SchemaProperty(type: "string", description: "프로젝트 경로"),
                "targetFile": SchemaProperty(type: "string", description: "테스트할 파일"),
                "framework": SchemaProperty(type: "string", description: "테스트 프레임워크 (XCTest, Jest, pytest 등)"),
                "additionalRequirements": SchemaProperty(type: "string", description: "추가 요구사항")
            ],
            required: ["projectPath", "targetFile"]
        ),
        outputSchema: SkillSchema(
            properties: [
                "testFile": SchemaProperty(type: "string", description: "생성된 테스트 파일 경로"),
                "testCode": SchemaProperty(type: "string", description: "테스트 코드"),
                "coverage": SchemaProperty(type: "array", description: "커버되는 케이스")
            ]
        ),
        requiredTools: [
            SkillTool(name: "claude", description: "Claude Code CLI", isRequired: true),
            SkillTool(name: "write", description: "파일 쓰기", isRequired: true)
        ],
        tags: ["claude-code", "cli", "testing", "automation"]
    )
    
    /// Claude Code 버그 수정
    static let claudeCodeFix = Skill(
        id: "claude-code-fix",
        name: "Claude Code 버그 수정",
        description: "Claude Code CLI로 버그를 분석하고 수정합니다.",
        category: .optimization,
        promptTemplate: """
        버그 수정 요청:
        
        증상: {{bugDescription}}
        
        관련 파일: {{relatedFiles}}
        
        버그 원인을 분석하고 수정합니다.
        """,
        systemPrompt: nil,
        inputSchema: SkillSchema(
            properties: [
                "projectPath": SchemaProperty(type: "string", description: "프로젝트 경로"),
                "bugDescription": SchemaProperty(type: "string", description: "버그 설명/에러 메시지"),
                "relatedFiles": SchemaProperty(type: "string", description: "관련 파일들"),
                "errorLog": SchemaProperty(type: "string", description: "에러 로그 (선택)")
            ],
            required: ["projectPath", "bugDescription"]
        ),
        outputSchema: SkillSchema(
            properties: [
                "rootCause": SchemaProperty(type: "string", description: "근본 원인"),
                "fix": SchemaProperty(type: "string", description: "수정 내용"),
                "modifiedFiles": SchemaProperty(type: "array", description: "수정된 파일들")
            ]
        ),
        requiredTools: [
            SkillTool(name: "claude", description: "Claude Code CLI", isRequired: true),
            SkillTool(name: "edit", description: "파일 수정", isRequired: true)
        ],
        tags: ["claude-code", "cli", "debugging", "bugfix"]
    )
    
    /// Claude Code PR 리뷰
    static let claudeCodeReview = Skill(
        id: "claude-code-review",
        name: "Claude Code PR 리뷰",
        description: "Claude Code CLI로 코드 변경사항을 리뷰합니다.",
        category: .analysis,
        promptTemplate: """
        코드 리뷰 요청:
        
        {{input}}
        
        다음 관점에서 리뷰합니다:
        - 코드 품질 및 가독성
        - 잠재적 버그
        - 성능 이슈
        - 보안 취약점
        - 베스트 프랙티스 준수
        """,
        systemPrompt: nil,
        inputSchema: SkillSchema(
            properties: [
                "projectPath": SchemaProperty(type: "string", description: "프로젝트 경로"),
                "diffOrBranch": SchemaProperty(type: "string", description: "리뷰할 diff 또는 브랜치"),
                "focus": SchemaProperty(type: "string", description: "리뷰 초점 (security, performance, style)")
            ],
            required: ["projectPath"]
        ),
        outputSchema: SkillSchema(
            properties: [
                "summary": SchemaProperty(type: "string", description: "리뷰 요약"),
                "issues": SchemaProperty(type: "array", description: "발견된 이슈"),
                "suggestions": SchemaProperty(type: "array", description: "개선 제안"),
                "approval": SchemaProperty(type: "boolean", description: "승인 여부")
            ]
        ),
        requiredTools: [
            SkillTool(name: "claude", description: "Claude Code CLI", isRequired: true),
            SkillTool(name: "bash", description: "Git 명령어", isRequired: false)
        ],
        tags: ["claude-code", "cli", "review", "pr"]
    )
    
    /// 모든 기본 스킬
    static var all: [Skill] {
        [
            // 일반 스킬
            codeAnalysis, designToHTML, testGeneration, refactoring, docGeneration,
            // Claude Code 스킬
            claudeCodeAnalyze, claudeCodeGenerate, claudeCodeRefactor,
            claudeCodeTest, claudeCodeFix, claudeCodeReview
        ]
    }
    
    /// Claude Code 스킬만
    static var claudeCodeSkills: [Skill] {
        [claudeCodeAnalyze, claudeCodeGenerate, claudeCodeRefactor,
         claudeCodeTest, claudeCodeFix, claudeCodeReview]
    }
}
