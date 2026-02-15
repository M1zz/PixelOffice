import SwiftUI

/// 프로젝트 피드백 입력 뷰
struct ProjectFeedbackView: View {
    let projectId: UUID
    @Binding var isPresented: Bool
    @EnvironmentObject var companyStore: CompanyStore
    
    @State private var feedbackText: String = ""
    @State private var feedbackType: FeedbackType = .improvement
    @State private var priority: FeedbackPriority = .medium
    @State private var targetDepartment: DepartmentType? = nil
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    
    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("💬 프로젝트 피드백")
                        .font(.title2.bold())
                    if let project = project {
                        Text(project.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 피드백 유형
                    VStack(alignment: .leading, spacing: 8) {
                        Text("피드백 유형")
                            .font(.headline)
                        
                        HStack(spacing: 8) {
                            ForEach(FeedbackType.allCases, id: \.self) { type in
                                Button {
                                    feedbackType = type
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: type.icon)
                                        Text(type.rawValue)
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(feedbackType == type ? type.color.opacity(0.2) : Color.gray.opacity(0.1))
                                    .foregroundColor(feedbackType == type ? type.color : .secondary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // 우선순위
                    VStack(alignment: .leading, spacing: 8) {
                        Text("우선순위")
                            .font(.headline)
                        
                        HStack(spacing: 8) {
                            ForEach(FeedbackPriority.allCases, id: \.self) { p in
                                Button {
                                    priority = p
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(p.color)
                                            .frame(width: 8, height: 8)
                                        Text(p.rawValue)
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(priority == p ? p.color.opacity(0.2) : Color.gray.opacity(0.1))
                                    .foregroundColor(priority == p ? p.color : .secondary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // 담당 부서 (선택)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("담당 부서 (선택)")
                            .font(.headline)
                        
                        HStack(spacing: 8) {
                            Button {
                                targetDepartment = nil
                            } label: {
                                Text("전체")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(targetDepartment == nil ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                                    .foregroundColor(targetDepartment == nil ? .accentColor : .secondary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            
                            ForEach(DepartmentType.allCases.filter { $0 != .general }, id: \.self) { dept in
                                Button {
                                    targetDepartment = dept
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: dept.icon)
                                        Text(dept.rawValue)
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(targetDepartment == dept ? dept.color.opacity(0.2) : Color.gray.opacity(0.1))
                                    .foregroundColor(targetDepartment == dept ? dept.color : .secondary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // 피드백 내용
                    VStack(alignment: .leading, spacing: 8) {
                        Text("피드백 내용")
                            .font(.headline)
                        
                        TextEditor(text: $feedbackText)
                            .font(.body)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text("AI가 피드백을 분석하여 태스크를 생성하고, 커뮤니티에 공유합니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 미리보기
                    if !feedbackText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("미리보기")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: feedbackType.icon)
                                        .foregroundColor(feedbackType.color)
                                    Text(feedbackType.rawValue)
                                        .font(.subheadline.bold())
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(priority.color)
                                            .frame(width: 6, height: 6)
                                        Text(priority.rawValue)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(priority.color.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                
                                Text(feedbackText)
                                    .font(.body)
                                    .lineLimit(3)
                                
                                if let dept = targetDepartment {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                        Text("@\(dept.rawValue)팀")
                                            .font(.caption)
                                    }
                                    .foregroundColor(dept.color)
                                }
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // 버튼
            HStack {
                Button("취소") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                if showingSuccess {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("피드백이 등록되었습니다!")
                            .foregroundColor(.green)
                    }
                } else {
                    Button {
                        submitFeedback()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Label("피드백 제출", systemImage: "paperplane.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(feedbackText.isEmpty || isSubmitting)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding()
        }
        .frame(width: 550, height: 650)
    }
    
    private func submitFeedback() {
        guard let project = project else { return }
        isSubmitting = true
        
        // 1. 태스크로 변환
        let task = ProjectTask(
            title: "[\(feedbackType.rawValue)] \(String(feedbackText.prefix(50)))\(feedbackText.count > 50 ? "..." : "")",
            description: """
            ## 피드백 내용
            \(feedbackText)
            
            ## 정보
            - **유형**: \(feedbackType.rawValue)
            - **우선순위**: \(priority.rawValue)
            - **담당**: \(targetDepartment?.rawValue ?? "전체")팀
            - **작성일**: \(Date().formatted())
            """,
            status: .todo,
            priority: priority.toTaskPriority,
            departmentType: targetDepartment ?? .planning
        )
        
        companyStore.addTask(task, toProject: projectId)
        
        // 2. 커뮤니티에 포스트
        let post = CommunityPost(
            employeeId: UUID(), // 시스템
            employeeName: "피드백 시스템",
            departmentType: targetDepartment ?? .general,
            thinkingId: nil,
            title: "[\(feedbackType.rawValue)] \(project.name) 피드백",
            content: """
            ## 피드백 내용
            \(feedbackText)
            
            ---
            
            **프로젝트**: \(project.name)
            **우선순위**: \(priority.rawValue)
            **담당 부서**: \(targetDepartment?.rawValue ?? "전체")팀
            
            > 이 피드백은 태스크로 자동 변환되었습니다.
            """,
            summary: String(feedbackText.prefix(100)),
            tags: [feedbackType.rawValue, project.name, targetDepartment?.rawValue ?? "전체"],
            source: .manual
        )
        
        companyStore.addCommunityPost(post, autoComment: true)
        
        // 성공 표시
        withAnimation {
            isSubmitting = false
            showingSuccess = true
        }
        
        // 잠시 후 닫기
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isPresented = false
        }
    }
}

// MARK: - Types

enum FeedbackType: String, CaseIterable {
    case bug = "버그"
    case improvement = "개선"
    case feature = "기능 요청"
    case question = "질문"
    case praise = "칭찬"
    
    var icon: String {
        switch self {
        case .bug: return "ladybug.fill"
        case .improvement: return "arrow.up.circle.fill"
        case .feature: return "star.fill"
        case .question: return "questionmark.circle.fill"
        case .praise: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .bug: return .red
        case .improvement: return .orange
        case .feature: return .blue
        case .question: return .purple
        case .praise: return .pink
        }
    }
}

enum FeedbackPriority: String, CaseIterable {
    case low = "낮음"
    case medium = "보통"
    case high = "높음"
    case urgent = "긴급"
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    var toTaskPriority: TaskPriority {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .urgent: return .critical
        }
    }
}

#Preview {
    ProjectFeedbackView(projectId: UUID(), isPresented: .constant(true))
        .environmentObject(CompanyStore())
}
