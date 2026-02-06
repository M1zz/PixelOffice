import SwiftUI

/// 권한 요청 카드 - 채팅 화면에서 승인/거부를 위한 UI
struct PermissionRequestCard: View {
    let request: PermissionRequest
    let onApprove: (String?) -> Void
    let onDeny: (String?) -> Void
    
    @State private var showReasonInput = false
    @State private var reason = ""
    @State private var isApproving = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Image(systemName: iconForType(request.type))
                    .font(.title2)
                    .foregroundStyle(colorForType(request.type))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.title)
                        .font(.headline)
                    Text(request.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 대기 시간
                if let waitTime = request.waitingTime {
                    Text(formatWaitTime(waitTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // 설명
            Text(request.description)
                .font(.body)
                .foregroundStyle(.secondary)
            
            // 대상 경로
            if let path = request.targetPath {
                HStack {
                    Image(systemName: "folder")
                        .font(.caption)
                    Text(path)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
            
            // 파일 크기
            if let size = request.formattedSize {
                HStack {
                    Image(systemName: "doc")
                        .font(.caption)
                    Text("크기: \(size)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // 사유 입력
            if showReasonInput {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isApproving ? "승인 사유 (선택)" : "거부 사유")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("사유를 입력하세요", text: $reason)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Button("취소") {
                            showReasonInput = false
                            reason = ""
                        }
                        .buttonStyle(.bordered)
                        
                        Button(isApproving ? "승인" : "거부") {
                            if isApproving {
                                onApprove(reason.isEmpty ? nil : reason)
                            } else {
                                onDeny(reason.isEmpty ? nil : reason)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isApproving ? .green : .red)
                    }
                }
            } else {
                // 버튼
                HStack(spacing: 12) {
                    Button {
                        isApproving = false
                        showReasonInput = true
                    } label: {
                        Label("거부", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    
                    Button {
                        isApproving = true
                        showReasonInput = true
                    } label: {
                        Label("승인", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForType(request.type).opacity(0.3), lineWidth: 1)
        )
    }
    
    private func iconForType(_ type: PermissionType) -> String {
        switch type {
        case .fileWrite: return "doc.badge.plus"
        case .fileEdit: return "pencil"
        case .fileDelete: return "trash"
        case .commandExecution: return "terminal"
        case .apiCall: return "network"
        case .dataExport: return "square.and.arrow.up"
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
    
    private func formatWaitTime(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))초 전"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))분 전"
        } else {
            return "\(Int(seconds / 3600))시간 전"
        }
    }
}

#Preview {
    PermissionRequestCard(
        request: PermissionRequest(
            type: .fileWrite,
            employeeId: UUID(),
            employeeName: "Claude",
            employeeDepartment: "개발팀",
            title: "설정 파일 작성",
            description: "프로젝트 설정을 저장하기 위해 config.json 파일을 작성합니다.",
            targetPath: "/Users/test/project/config.json",
            estimatedSize: 2048
        ),
        onApprove: { _ in },
        onDeny: { _ in }
    )
    .frame(width: 400)
    .padding()
}
