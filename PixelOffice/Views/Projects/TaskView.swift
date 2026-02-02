import SwiftUI

struct TaskView: View {
    let task: ProjectTask
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    
    var assignee: Employee? {
        guard let id = task.assigneeId else { return nil }
        return companyStore.getEmployee(byId: id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Label(task.departmentType.rawValue, systemImage: task.departmentType.icon)
                            .foregroundStyle(task.departmentType.color)
                        
                        Divider()
                            .frame(height: 12)
                        
                        Label(task.status.rawValue, systemImage: task.status.icon)
                            .foregroundStyle(task.status.color)
                    }
                    .font(.callout)
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(task.status.color)
                    .frame(width: 12, height: 12)
            }
            
            // Description
            if !task.description.isEmpty {
                Text(task.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            Divider()
            
            // Assignee
            HStack {
                if let assignee = assignee {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(assignee.aiType.color.opacity(0.2))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: assignee.aiType.icon)
                                .foregroundStyle(assignee.aiType.color)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(assignee.name)
                                .font(.callout.bold())
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(assignee.status.color)
                                    .frame(width: 6, height: 6)
                                Text(assignee.status.rawValue)
                            }
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Label("미배정", systemImage: "person.badge.plus")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Conversation count
                if !task.conversation.isEmpty {
                    Label("\(task.conversation.count)", systemImage: "bubble.left.and.bubble.right")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                
                // Output count
                if !task.outputs.isEmpty {
                    Label("\(task.outputs.count)", systemImage: "doc.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TaskRowView: View {
    let task: ProjectTask
    @EnvironmentObject var companyStore: CompanyStore
    
    var assignee: Employee? {
        guard let id = task.assigneeId else { return nil }
        return companyStore.getEmployee(byId: id)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: task.status.icon)
                .foregroundStyle(task.status.color)
                .frame(width: 24)
            
            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(task.departmentType.rawValue, systemImage: task.departmentType.icon)
                        .foregroundStyle(task.departmentType.color)
                    
                    if let assignee = assignee {
                        Text("• \(assignee.name)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
            }
            
            Spacer()
            
            // Indicators
            HStack(spacing: 8) {
                if !task.conversation.isEmpty {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundStyle(.secondary)
                }
                
                if !task.outputs.isEmpty {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        TaskView(
            task: ProjectTask(
                title: "앱 기획서 작성",
                description: "새로운 iOS 앱의 기획서를 작성합니다. 주요 기능과 타겟 유저를 정의합니다.",
                status: .inProgress,
                departmentType: .planning
            ),
            projectId: UUID()
        )
        
        TaskRowView(
            task: ProjectTask(
                title: "UI 디자인",
                status: .todo,
                departmentType: .design
            )
        )
    }
    .padding()
    .frame(width: 400)
    .environmentObject(CompanyStore())
}
