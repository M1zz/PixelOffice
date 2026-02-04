import SwiftUI

/// 협업 기록 조회 뷰
struct CollaborationHistoryView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @State private var searchText = ""
    @State private var selectedDepartment: String? = nil
    @State private var selectedRecord: CollaborationRecord?

    var filteredRecords: [CollaborationRecord] {
        var records = companyStore.collaborationRecords

        // 부서 필터
        if let dept = selectedDepartment {
            records = records.filter {
                $0.requesterDepartment == dept || $0.responderDepartment == dept
            }
        }

        // 검색어 필터
        if !searchText.isEmpty {
            records = records.filter {
                $0.requesterName.localizedCaseInsensitiveContains(searchText) ||
                $0.responderName.localizedCaseInsensitiveContains(searchText) ||
                $0.requestContent.localizedCaseInsensitiveContains(searchText) ||
                $0.responseContent.localizedCaseInsensitiveContains(searchText) ||
                ($0.projectName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return records
    }

    /// 사용 가능한 부서 목록
    var availableDepartments: [String] {
        let depts = Set(companyStore.collaborationRecords.flatMap {
            [$0.requesterDepartment, $0.responderDepartment]
        })
        return Array(depts).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("협업 기록")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(filteredRecords.count)건")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            // 필터 바
            HStack(spacing: 12) {
                // 검색
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("검색...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // 부서 필터
                Picker("부서", selection: $selectedDepartment) {
                    Text("전체 부서").tag(nil as String?)
                    ForEach(availableDepartments, id: \.self) { dept in
                        Text(dept).tag(dept as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // 기록 목록
            if filteredRecords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("협업 기록이 없습니다")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("AI 직원들이 @멘션으로 협업하면\n여기에 기록됩니다")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredRecords) { record in
                    CollaborationRecordRow(record: record)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRecord = record
                        }
                }
                .listStyle(.inset)
            }
        }
        .sheet(item: $selectedRecord) { record in
            CollaborationDetailView(record: record)
        }
    }
}

/// 협업 기록 행
struct CollaborationRecordRow: View {
    let record: CollaborationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더: 요청자 → 응답자
            HStack {
                // 요청자
                HStack(spacing: 4) {
                    Image(systemName: getDepartmentIcon(record.requesterDepartment))
                        .foregroundStyle(getDepartmentColor(record.requesterDepartment))
                    Text(record.requesterName)
                        .fontWeight(.medium)
                }

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // 응답자
                HStack(spacing: 4) {
                    Image(systemName: getDepartmentIcon(record.responderDepartment))
                        .foregroundStyle(getDepartmentColor(record.responderDepartment))
                    Text(record.responderName)
                        .fontWeight(.medium)
                }

                Spacer()

                // 시간
                Text(record.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 프로젝트 태그 (있는 경우)
            if let projectName = record.projectName {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                    Text(projectName)
                        .font(.caption)
                }
                .foregroundStyle(.blue)
            }

            // 요청 내용 요약
            Text(record.summary)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // 상태 표시
            HStack {
                Image(systemName: record.status.icon)
                Text(record.status.rawValue)
            }
            .font(.caption)
            .foregroundStyle(record.status == .completed ? .green : .orange)
        }
        .padding(.vertical, 8)
    }

    func getDepartmentIcon(_ name: String) -> String {
        switch name {
        case "기획": return "lightbulb.fill"
        case "디자인": return "paintbrush.fill"
        case "개발": return "chevron.left.forwardslash.chevron.right"
        case "마케팅": return "megaphone.fill"
        case "QA": return "checkmark.shield.fill"
        default: return "briefcase.fill"
        }
    }

    func getDepartmentColor(_ name: String) -> Color {
        switch name {
        case "기획": return .yellow
        case "디자인": return .pink
        case "개발": return .blue
        case "마케팅": return .green
        case "QA": return .purple
        default: return .gray
        }
    }
}

/// 협업 상세 뷰
struct CollaborationDetailView: View {
    let record: CollaborationRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("협업 상세")
                    .font(.headline)
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

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 메타 정보
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("일시")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(record.formattedDate)
                        }

                        if let projectName = record.projectName {
                            HStack {
                                Text("프로젝트")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(projectName)
                                    .foregroundStyle(.blue)
                            }
                        }

                        HStack {
                            Text("상태")
                                .foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: record.status.icon)
                                Text(record.status.rawValue)
                            }
                            .foregroundStyle(record.status == .completed ? .green : .orange)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // 요청 내용
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.blue)
                            Text("\(record.requesterName) (\(record.requesterDepartment))")
                                .fontWeight(.medium)
                            Text("요청")
                                .foregroundStyle(.secondary)
                        }

                        Text(record.requestContent)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // 응답 내용
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.green)
                            Text("\(record.responderName) (\(record.responderDepartment))")
                                .fontWeight(.medium)
                            Text("응답")
                                .foregroundStyle(.secondary)
                        }

                        Text(record.responseContent)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // 태그
                    if !record.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("태그")
                                .foregroundStyle(.secondary)

                            FlowLayout(spacing: 8) {
                                ForEach(record.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            // 하단 버튼
            HStack {
                Button("복사") {
                    let text = """
                    [협업 기록]
                    일시: \(record.formattedDate)
                    \(record.projectName.map { "프로젝트: \($0)\n" } ?? "")
                    요청자: \(record.requesterName) (\(record.requesterDepartment))
                    응답자: \(record.responderName) (\(record.responderDepartment))

                    [요청]
                    \(record.requestContent)

                    [응답]
                    \(record.responseContent)
                    """
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }

                Spacer()

                Button("닫기") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }
}

/// FlowLayout for tags
/// 플로우 레이아웃 (자동으로 줄바꿈되는 레이아웃)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), frames)
    }
}

#Preview {
    CollaborationHistoryView()
        .environmentObject(CompanyStore())
}
