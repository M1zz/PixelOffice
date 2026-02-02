import SwiftUI

struct EmployeeView: View {
    let employee: Employee
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Character
            ZStack {
                Circle()
                    .fill(employee.aiType.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                PixelCharacter(
                    appearance: employee.characterAppearance,
                    status: employee.status,
                    aiType: employee.aiType
                )
            }
            
            // Info
            VStack(spacing: 2) {
                Text(employee.name)
                    .font(.callout.bold())
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(employee.status.color)
                        .frame(width: 6, height: 6)
                    Text(employee.status.rawValue)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? employee.aiType.color.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? employee.aiType.color : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

struct EmployeeCard: View {
    let employee: Employee
    @EnvironmentObject var companyStore: CompanyStore
    
    var currentTask: ProjectTask? {
        guard let taskId = employee.currentTaskId else { return nil }
        return companyStore.company.projects.flatMap { $0.tasks }.first { $0.id == taskId }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(employee.aiType.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                PixelCharacter(
                    appearance: employee.characterAppearance,
                    status: employee.status,
                    aiType: employee.aiType
                )
                .scaleEffect(0.8)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(employee.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(employee.status.color)
                            .frame(width: 8, height: 8)
                        Text(employee.status.rawValue)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: employee.aiType.icon)
                        .foregroundStyle(employee.aiType.color)
                    Text(employee.aiType.rawValue)
                    
                    Spacer()
                    
                    Text("완료: \(employee.totalTasksCompleted)")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                
                if let task = currentTask {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.blue)
                        Text(task.title)
                            .lineLimit(1)
                    }
                    .font(.callout)
                    .padding(.top, 2)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            EmployeeView(
                employee: Employee(name: "Claude-1", aiType: .claude, status: .working),
                isSelected: false,
                onSelect: {}
            )
            
            EmployeeView(
                employee: Employee(name: "GPT-1", aiType: .gpt, status: .idle),
                isSelected: true,
                onSelect: {}
            )
        }
        
        EmployeeCard(
            employee: Employee(name: "Claude-1", aiType: .claude, status: .working, totalTasksCompleted: 15)
        )
        .frame(width: 350)
    }
    .padding()
    .background(Color.black)
    .environmentObject(CompanyStore())
}
