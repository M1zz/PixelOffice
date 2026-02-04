import SwiftUI

/// 권한 요청 상세 화면
struct PermissionRequestDetailView: View {
    let request: PermissionRequest
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var denyReason = ""
    @State private var showingDenySheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 헤더
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: iconForType(request.type))
                            .font(.system(size: 40))
                            .foregroundStyle(colorForType(request.type))

                        Spacer()

                        statusBadge
                    }

                    Text(request.title)
                        .font(.title2.bold())

                    HStack(spacing: 16) {
                        Label(request.employeeName, systemImage: "person.fill")
                        Label(request.employeeDepartment, systemImage: "building.2")
                        if let projectName = request.projectName {
                            Label(projectName, systemImage: "folder")
                        }
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)
                }

                Divider()

                // 요청 정보
                VStack(alignment: .leading, spacing: 16) {
                    DetailSection(title: "요청 유형", icon: "info.circle") {
                        Text(request.type.rawValue)
                    }

                    DetailSection(title: "설명", icon: "text.alignleft") {
                        Text(request.description)
                    }

                    if let path = request.targetPath {
                        DetailSection(title: "대상", icon: "doc") {
                            Text(path)
                                .textSelection(.enabled)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    if let size = request.formattedSize {
                        DetailSection(title: "파일 크기", icon: "doc.text") {
                            Text(size)
                        }
                    }

                    DetailSection(title: "요청 시간", icon: "clock") {
                        Text(request.requestedAt.formatted(date: .abbreviated, time: .shortened))
                    }

                    if let respondedAt = request.respondedAt {
                        DetailSection(title: "응답 시간", icon: "checkmark.circle") {
                            Text(respondedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    }

                    if request.autoApproved {
                        DetailSection(title: "자동 승인", icon: "sparkles") {
                            Label("자동 승인 규칙에 의해 승인됨", systemImage: "checkmark.shield")
                                .foregroundStyle(.green)
                        }
                    }

                    if let reason = request.reason {
                        DetailSection(title: "사유", icon: "text.bubble") {
                            Text(reason)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    // 메타데이터
                    if !request.metadata.isEmpty {
                        DetailSection(title: "추가 정보", icon: "ellipsis.circle") {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(request.metadata.keys.sorted()), id: \.self) { key in
                                    HStack {
                                        Text(key)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(request.metadata[key] ?? "")
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }

                Divider()

                // 액션 버튼
                if request.status == .pending {
                    HStack(spacing: 12) {
                        Button {
                            showingDenySheet = true
                        } label: {
                            Label("거부", systemImage: "xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            permissionManager.approveRequest(request.id, reason: "사용자 승인")
                        } label: {
                            Label("승인", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                } else {
                    Button(role: .destructive) {
                        permissionManager.deleteRequest(request.id)
                    } label: {
                        Label("기록 삭제", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(24)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showingDenySheet) {
            DenyReasonSheet(
                isPresented: $showingDenySheet,
                onSubmit: { reason in
                    permissionManager.denyRequest(request.id, reason: reason)
                }
            )
        }
    }

    private var statusBadge: some View {
        Group {
            switch request.status {
            case .pending:
                Label(request.status.rawValue, systemImage: "hourglass")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())

            case .approved:
                Label(request.status.rawValue, systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())

            case .denied:
                Label(request.status.rawValue, systemImage: "xmark.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.2))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())

            case .expired:
                Label(request.status.rawValue, systemImage: "clock.badge.xmark")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
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
}

/// 상세 정보 섹션
struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
        }
    }
}

/// 거부 사유 입력 시트
struct DenyReasonSheet: View {
    @Binding var isPresented: Bool
    let onSubmit: (String) -> Void

    @State private var reason = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            // 헤더
            HStack {
                Text("거부 사유")
                    .font(.title2.bold())

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

            // 사유 입력
            VStack(alignment: .leading, spacing: 8) {
                Text("거부 사유를 입력하세요 (선택사항)")
                    .font(.body)
                    .foregroundStyle(.secondary)

                TextEditor(text: $reason)
                    .font(.body)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .focused($isFocused)
            }

            // 버튼
            HStack(spacing: 12) {
                Button("취소") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("거부") {
                    onSubmit(reason.isEmpty ? "사용자 거부" : reason)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    PermissionRequestDetailView(
        request: PermissionRequest(
            type: .fileWrite,
            employeeId: UUID(),
            employeeName: "Claude-개발",
            employeeDepartment: "개발팀",
            projectName: "픽셀 오피스",
            title: "기능 명세서 작성",
            description: "프로젝트의 상세 기능 명세서를 작성합니다.",
            targetPath: "/Users/user/Documents/PixelOffice/datas/wiki/spec.md",
            estimatedSize: 37000
        )
    )
}
