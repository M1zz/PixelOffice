import SwiftUI

/// 자동 승인 규칙 관리 화면
struct AutoApprovalRulesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var showingAddRule = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("자동 승인 규칙")
                    .font(.title2.bold())

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

            // 설명
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("조건과 일치하는 권한 요청은 자동으로 승인됩니다")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))

            // 규칙 목록
            if permissionManager.autoApprovalRules.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "shield.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("자동 승인 규칙이 없습니다")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(permissionManager.autoApprovalRules) { rule in
                        AutoApprovalRuleRow(rule: rule)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let rule = permissionManager.autoApprovalRules[index]
                            permissionManager.deleteAutoApprovalRule(rule.id)
                        }
                    }
                }
            }

            Divider()

            // 하단 버튼
            HStack {
                Button {
                    showingAddRule = true
                } label: {
                    Label("규칙 추가", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $showingAddRule) {
            AddAutoApprovalRuleView()
        }
    }
}

/// 자동 승인 규칙 행
struct AutoApprovalRuleRow: View {
    let rule: AutoApprovalRule
    @StateObject private var permissionManager = PermissionManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // 활성화 토글
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { _ in permissionManager.toggleAutoApprovalRule(rule.id) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 6) {
                Text(rule.name)
                    .font(.body.bold())
                    .foregroundStyle(rule.enabled ? .primary : .secondary)

                // 조건 요약
                VStack(alignment: .leading, spacing: 2) {
                    if !rule.permissionTypes.isEmpty {
                        Text("유형: \(rule.permissionTypes.map { $0.rawValue }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let patterns = rule.pathPatterns, !patterns.isEmpty {
                        Text("경로: \(patterns.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let maxSize = rule.maxFileSize {
                        Text("최대 크기: \(formatFileSize(maxSize))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // 상태 표시
            if rule.enabled {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "shield.slash")
                    .foregroundStyle(.gray)
            }
        }
        .padding(.vertical, 4)
        .opacity(rule.enabled ? 1.0 : 0.6)
    }
}

/// 자동 승인 규칙 추가 화면
struct AddAutoApprovalRuleView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var permissionManager = PermissionManager.shared

    @State private var ruleName = ""
    @State private var selectedTypes: Set<PermissionType> = []
    @State private var pathPattern = ""
    @State private var maxSizeMB: Double = 10

    var body: some View {
        VStack(spacing: 20) {
            // 헤더
            HStack {
                Text("새 자동 승인 규칙")
                    .font(.title2.bold())

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

            // 규칙 이름
            VStack(alignment: .leading, spacing: 8) {
                Text("규칙 이름")
                    .font(.body.bold())
                TextField("예: 프로젝트 문서 자동 승인", text: $ruleName)
                    .textFieldStyle(.roundedBorder)
            }

            // 권한 유형 선택
            VStack(alignment: .leading, spacing: 8) {
                Text("권한 유형")
                    .font(.body.bold())
                FlowLayout(spacing: 8) {
                    ForEach(PermissionType.allCases, id: \.self) { type in
                        Toggle(type.rawValue, isOn: Binding(
                            get: { selectedTypes.contains(type) },
                            set: { isOn in
                                if isOn {
                                    selectedTypes.insert(type)
                                } else {
                                    selectedTypes.remove(type)
                                }
                            }
                        ))
                        .toggleStyle(.button)
                        .buttonStyle(.bordered)
                        .tint(selectedTypes.contains(type) ? .blue : .gray)
                    }
                }
            }

            // 경로 패턴
            VStack(alignment: .leading, spacing: 8) {
                Text("경로 패턴 (선택사항)")
                    .font(.body.bold())
                TextField("예: */datas/*", text: $pathPattern)
                    .textFieldStyle(.roundedBorder)
                Text("* 를 사용하여 와일드카드 지정")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 최대 파일 크기
            VStack(alignment: .leading, spacing: 8) {
                Text("최대 파일 크기: \(Int(maxSizeMB)) MB")
                    .font(.body.bold())
                Slider(value: $maxSizeMB, in: 1...100, step: 1)
            }

            Spacer()

            // 버튼
            HStack(spacing: 12) {
                Button("취소") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("추가") {
                    let rule = AutoApprovalRule(
                        name: ruleName.isEmpty ? "새 규칙" : ruleName,
                        permissionTypes: Array(selectedTypes),
                        pathPatterns: pathPattern.isEmpty ? nil : [pathPattern],
                        maxFileSize: Int(maxSizeMB * 1024 * 1024)
                    )
                    permissionManager.addAutoApprovalRule(rule)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedTypes.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}

// MARK: - Helper Functions
private func formatFileSize(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
}

#Preview {
    AutoApprovalRulesView()
}
