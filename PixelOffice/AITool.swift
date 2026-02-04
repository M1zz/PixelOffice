import Foundation

/// AI가 사용할 수 있는 도구 정의 (Claude Tool Use)
struct AITool: Codable {
    let name: String
    let description: String
    let inputSchema: InputSchema

    struct InputSchema: Codable {
        let type: String = "object"
        let properties: [String: Property]
        let required: [String]

        struct Property: Codable {
            let type: String
            let description: String
            let items: Items?

            struct Items: Codable {
                let type: String
            }
        }
    }
}

/// AI 도구 실행 결과
struct AIToolResult {
    let toolUseId: String
    let content: String
    let isError: Bool
}

/// AI 도구 목록 (직원이 사용 가능한 도구들)
enum EmployeeTools {
    /// 위키 문서 생성 도구
    static let createWikiDocument = AITool(
        name: "create_wiki_document",
        description: """
        위키에 새로운 문서를 생성합니다. 기획서, 명세서, 회의록 등을 작성할 때 사용하세요.
        프로젝트 관련 문서는 프로젝트별 위키에 저장됩니다.
        """,
        inputSchema: AITool.InputSchema(
            properties: [
                "title": AITool.InputSchema.Property(
                    type: "string",
                    description: "문서 제목 (예: 픽셀오피스 기능명세서 v1.0)",
                    items: nil
                ),
                "content": AITool.InputSchema.Property(
                    type: "string",
                    description: "문서 내용 (마크다운 형식)",
                    items: nil
                ),
                "category": AITool.InputSchema.Property(
                    type: "string",
                    description: "문서 카테고리 (spec, meeting, guide, reference 중 하나)",
                    items: nil
                )
            ],
            required: ["title", "content", "category"]
        )
    )

    /// 태스크 생성 도구
    static let createTask = AITool(
        name: "create_task",
        description: """
        프로젝트에 새로운 태스크를 생성합니다. 개발, 디자인, 테스트 등 모든 작업을 태스크로 만들 수 있습니다.
        태스크는 칸반 보드에 자동으로 추가됩니다.
        """,
        inputSchema: AITool.InputSchema(
            properties: [
                "title": AITool.InputSchema.Property(
                    type: "string",
                    description: "태스크 제목",
                    items: nil
                ),
                "description": AITool.InputSchema.Property(
                    type: "string",
                    description: "태스크 상세 설명",
                    items: nil
                ),
                "priority": AITool.InputSchema.Property(
                    type: "string",
                    description: "우선순위 (high, medium, low 중 하나)",
                    items: nil
                ),
                "estimatedHours": AITool.InputSchema.Property(
                    type: "number",
                    description: "예상 소요 시간 (시간 단위)",
                    items: nil
                ),
                "tags": AITool.InputSchema.Property(
                    type: "array",
                    description: "태그 목록 (예: [기능, UI, 백엔드])",
                    items: AITool.InputSchema.Property.Items(type: "string")
                )
            ],
            required: ["title", "description", "priority"]
        )
    )

    /// 직원 멘션 도구
    static let mentionEmployee = AITool(
        name: "mention_employee",
        description: """
        특정 직원이나 부서를 멘션하여 작업을 요청하거나 협업을 시작합니다.
        멘션된 직원/부서에게 알림이 전송되고, 해당 직원이 대화에 참여할 수 있습니다.
        """,
        inputSchema: AITool.InputSchema(
            properties: [
                "targetType": AITool.InputSchema.Property(
                    type: "string",
                    description: "멘션 대상 유형 (department 또는 employee)",
                    items: nil
                ),
                "targetName": AITool.InputSchema.Property(
                    type: "string",
                    description: "멘션 대상 이름 (부서명: 기획팀, 디자인팀 등 또는 직원명)",
                    items: nil
                ),
                "message": AITool.InputSchema.Property(
                    type: "string",
                    description: "멘션 메시지 (요청 내용)",
                    items: nil
                )
            ],
            required: ["targetType", "targetName", "message"]
        )
    )

    /// 협업 기록 생성 도구
    static let createCollaboration = AITool(
        name: "create_collaboration",
        description: """
        부서 간 협업 내용을 기록합니다. 회의, 리뷰, 공동 작업 등을 문서화할 때 사용하세요.
        """,
        inputSchema: AITool.InputSchema(
            properties: [
                "title": AITool.InputSchema.Property(
                    type: "string",
                    description: "협업 제목",
                    items: nil
                ),
                "departments": AITool.InputSchema.Property(
                    type: "array",
                    description: "참여 부서 목록 (예: [기획팀, 디자인팀])",
                    items: AITool.InputSchema.Property.Items(type: "string")
                ),
                "content": AITool.InputSchema.Property(
                    type: "string",
                    description: "협업 내용 (마크다운 형식)",
                    items: nil
                ),
                "outcome": AITool.InputSchema.Property(
                    type: "string",
                    description: "협업 결과/결론",
                    items: nil
                )
            ],
            required: ["title", "departments", "content"]
        )
    )

    /// 모든 도구 목록
    static var allTools: [AITool] {
        [
            createWikiDocument,
            createTask,
            mentionEmployee,
            createCollaboration
        ]
    }
}
