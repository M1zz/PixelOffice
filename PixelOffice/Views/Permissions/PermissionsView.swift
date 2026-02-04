import SwiftUI

/// 권한 요청 관리 화면
struct PermissionsView: View {
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var selectedFilter: PermissionFilter = .pending
    @State private var selectedRequest: PermissionRequest?
    @State private var showingSettings = false

    enum PermissionFilter: String, CaseIterable {
        case pending = "대기 중"
        case approved = "승인됨"
        case denied = "거부됨"
        case all = "전체"
    }

    var filteredRequests: [PermissionRequest] {
        switch selectedFilter {
        case .pending:
            return permissionManager.pendingRequests
        case .approved:
            return permissionManager.approvedRequests
        case .denied:
            return permissionManager.deniedRequests
        case .all:
            return permissionManager.requests
        }
    }

    var body: some View {
        NavigationSplitView {
            // 사이드바
            VStack(spacing: 0) {
                // 필터 선택
                Picker("필터", selection: $selectedFilter) {
                    ForEach(PermissionFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                // 요청 목록
                if filteredRequests.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(emptyMessage)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List(filteredRequests, selection: $selectedRequest) { request in
                        PermissionRequestRow(request: request)
                            .tag(request)
                    }
                }

                Divider()

                // 하단 통계 및 액션
                HStack {
                    // 통계
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(permissionManager.pendingCount)개 대기 중")
                            .font(.caption.bold())
                            .foregroundStyle(permissionManager.pendingCount > 0 ? .orange : .secondary)
                        Text("승인률 \(Int(permissionManager.approvalRate * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // 액션 버튼
                    Menu {
                        Button("대기 중인 요청 삭제") {
                            permissionManager.clearPendingRequests()
                        }
                        .disabled(permissionManager.pendingCount == 0)

                        Button("완료된 요청 삭제") {
                            permissionManager.clearCompletedRequests()
                        }

                        Divider()

                        Button("자동 승인 규칙...") {
                            showingSettings = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 300, idealWidth: 350)
            .navigationTitle("권한 요청")
        } detail: {
            // 상세 화면
            if let request = selectedRequest {
                PermissionRequestDetailView(request: request)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("권한 요청을 선택하세요")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingSettings) {
            AutoApprovalRulesView()
        }
    }

    private var emptyMessage: String {
        switch selectedFilter {
        case .pending:
            return "대기 중인 권한 요청이 없습니다"
        case .approved:
            return "승인된 권한 요청이 없습니다"
        case .denied:
            return "거부된 권한 요청이 없습니다"
        case .all:
            return "권한 요청 내역이 없습니다"
        }
    }
}

/// 권한 요청 행
struct PermissionRequestRow: View {
    let request: PermissionRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 타입 아이콘
                Image(systemName: iconForType(request.type))
                    .font(.title3)
                    .foregroundStyle(colorForType(request.type))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.title)
                        .font(.body.bold())
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(request.employeeName)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(request.type.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 상태 뱃지
                statusBadge
            }

            // 경로 또는 설명
            if let path = request.targetPath {
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // 시간 정보
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(timeAgo(from: request.requestedAt))
                    .font(.caption2)

                if let size = request.formattedSize {
                    Text("•")
                    Text(size)
                        .font(.caption2)
                }
            }
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        Group {
            switch request.status {
            case .pending:
                Label(request.status.rawValue, systemImage: "hourglass")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())

            case .approved:
                Label(request.status.rawValue, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())

            case .denied:
                Label(request.status.rawValue, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.2))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())

            case .expired:
                Label(request.status.rawValue, systemImage: "clock.badge.xmark")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .foregroundStyle(.gray)
                    .clipShape(Capsule())
            }
        }
    }

    private func iconForType(_ type: PermissionType) -> String {
        switch type {
        case .fileWrite: return "doc.badge.plus"
        case .fileEdit: return "pencil"
        case .fileDelete: return "trash"
        case .commandExecution: return "terminal"
        case .apiCall: return "network"
        case .dataExport: return "arrow.up.doc"
        }
    }

    private func colorForType(_ type: PermissionType) -> Color {
        switch type {
        case .fileWrite: return .blue
        case .fileEdit: return .orange
        case .fileDelete: return .red
        case .commandExecution: return .purple
        case .apiCall: return .green
        case .dataExport: return .cyan
        }
    }

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days)일 전"
        } else if hours > 0 {
            return "\(hours)시간 전"
        } else if minutes > 0 {
            return "\(minutes)분 전"
        } else {
            return "방금 전"
        }
    }
}

#Preview {
    PermissionsView()
}
