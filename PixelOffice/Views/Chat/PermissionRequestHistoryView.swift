import SwiftUI

/// 권한 요청 히스토리 뷰 - 특정 직원의 권한 요청 내역을 보여줌
struct PermissionRequestHistoryView: View {
    let employeeId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var filterStatus: PermissionStatus? = nil
    
    var filteredRequests: [PermissionRequest] {
        companyStore.company.permissionRequests
            .filter { $0.employeeId == employeeId }
            .filter { filterStatus == nil || $0.status == filterStatus }
            .sorted { $0.requestedAt > $1.requestedAt }
    }
    
    var employee: Employee? {
        companyStore.company.departments
            .flatMap { $0.employees }
            .first { $0.id == employeeId }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading) {
                    Text("권한 요청 내역")
                        .font(.title2.bold())
                    if let emp = employee {
                        Text(emp.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // 필터
            HStack {
                Text("필터:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("상태", selection: $filterStatus) {
                    Text("전체").tag(nil as PermissionStatus?)
                    ForEach([PermissionStatus.pending, .approved, .denied, .expired], id: \.self) { status in
                        Text(status.rawValue).tag(status as PermissionStatus?)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // 리스트
            if filteredRequests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("권한 요청 내역이 없습니다")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredRequests) { request in
                    HistoryRow(request: request)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 600, height: 500)
    }
}

struct HistoryRow: View {
    let request: PermissionRequest
    
    var body: some View {
        HStack(spacing: 12) {
            // 상태 아이콘
            statusIcon
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(request.title)
                        .font(.body.bold())
                    
                    Text(request.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
                
                Text(request.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text(formatDate(request.requestedAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    if let respondedAt = request.respondedAt {
                        Text("→")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(formatDate(respondedAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    if request.autoApproved {
                        Label("자동 승인", systemImage: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            // 상태 배지
            statusBadge
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch request.status {
        case .pending:
            Image(systemName: "clock.fill")
                .foregroundStyle(.orange)
        case .approved:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .expired:
            Image(systemName: "clock.badge.exclamationmark.fill")
                .foregroundStyle(.gray)
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        Text(request.status.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch request.status {
        case .pending: return .orange
        case .approved: return .green
        case .denied: return .red
        case .expired: return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    PermissionRequestHistoryView(employeeId: UUID())
        .environmentObject(CompanyStore())
}
