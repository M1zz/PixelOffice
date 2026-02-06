import SwiftUI

/// 프로젝트 주요 정보 편집 뷰
struct ProjectContextEditorView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    let projectId: UUID

    @State private var projectContext: String = ""

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("프로젝트 주요 정보")
                        .font(.title2.bold())
                    if let project = project {
                        Text(project.name)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("취소") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("저장") {
                    saveContext()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            // Info
            VStack(alignment: .leading, spacing: 8) {
                Label("AI 직원들이 작업할 때 이 정보를 참고합니다", systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("**포함할 내용:**")
                    .font(.callout.weight(.semibold))

                VStack(alignment: .leading, spacing: 4) {
                    Text("• 프로젝트 목표 및 비전")
                    Text("• 주요 기능 및 요구사항")
                    Text("• 타겟 사용자 및 시장")
                    Text("• 기술 스택 및 제약사항")
                    Text("• 중요한 가이드라인 및 규칙")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.05))

            Divider()

            // Editor
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("프로젝트 컨텍스트")
                        .font(.headline)
                    Spacer()
                    Text("\(projectContext.count)자")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $projectContext)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
            }
            .padding()
        }
        .frame(width: 700, height: 600)
        .onAppear {
            if let project = project {
                projectContext = project.projectContext
            }
        }
    }

    private func saveContext() {
        guard let projectIndex = companyStore.company.projects.firstIndex(where: { $0.id == projectId }) else { return }
        companyStore.company.projects[projectIndex].projectContext = projectContext
        companyStore.saveCompany()
        dismiss()
    }
}
