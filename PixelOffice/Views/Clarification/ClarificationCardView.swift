import SwiftUI

/// 개별 질문 카드 뷰
struct ClarificationCardView: View {
    let request: ClarificationRequest
    let onAnswer: (String) -> Void

    @State private var textAnswer: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더: 직원 정보 + 우선순위
            HStack(spacing: 10) {
                // 부서 아이콘
                ZStack {
                    Circle()
                        .fill(request.department.color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: request.department.icon)
                        .foregroundStyle(request.department.color)
                        .font(.system(size: 14))
                }

                // 직원 이름 + 부서
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.askedBy)
                        .font(.subheadline.weight(.semibold))
                    Text(request.department.rawValue + "팀")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 우선순위 뱃지
                HStack(spacing: 4) {
                    Image(systemName: request.priority.icon)
                    Text(request.priority.displayName)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(request.priority.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(request.priority.color.opacity(0.1))
                .clipShape(Capsule())

                // 답변 완료 체크
                if request.isAnswered {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }

            // 질문 배경 (있으면)
            if let context = request.context, !context.isEmpty {
                Text(context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // 질문 내용
            Text(request.question)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // 답변 영역
            if request.isAnswered {
                // 답변 완료 상태
                HStack(spacing: 8) {
                    Image(systemName: "text.quote")
                        .foregroundStyle(.secondary)
                    Text(request.answer ?? "")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let options = request.options, !options.isEmpty {
                // 선택지가 있는 경우
                optionButtons(options: options)
            } else {
                // 텍스트 입력
                textInputField
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    request.isAnswered ? Color.green.opacity(0.3) :
                    request.priority == .critical ? Color.red.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Option Buttons

    @ViewBuilder
    private func optionButtons(options: [String]) -> some View {
        VStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    onAnswer(option)
                } label: {
                    HStack {
                        Text(option)
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            // 직접 입력 옵션
            HStack(spacing: 8) {
                TextField("또는 직접 입력...", text: $textAnswer)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .focused($isTextFieldFocused)

                Button {
                    guard !textAnswer.isEmpty else { return }
                    onAnswer(textAnswer)
                    textAnswer = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(textAnswer.isEmpty ? .secondary : .blue)
                }
                .buttonStyle(.plain)
                .disabled(textAnswer.isEmpty)
            }
        }
    }

    // MARK: - Text Input Field

    private var textInputField: some View {
        HStack(spacing: 8) {
            TextField("답변을 입력하세요...", text: $textAnswer)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .focused($isTextFieldFocused)
                .onSubmit {
                    submitAnswer()
                }

            Button {
                submitAnswer()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(textAnswer.isEmpty ? .secondary : .blue)
            }
            .buttonStyle(.plain)
            .disabled(textAnswer.isEmpty)
        }
    }

    private func submitAnswer() {
        guard !textAnswer.isEmpty else { return }
        onAnswer(textAnswer)
        textAnswer = ""
    }
}

// MARK: - Preview

#if DEBUG
struct ClarificationCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // 선택지가 있는 질문
            ClarificationCardView(
                request: ClarificationRequest(
                    question: "다크모드 지원이 필요한가요?",
                    askedBy: "김디자인",
                    department: .design,
                    context: "앱의 전체적인 디자인 방향을 결정하기 위해 필요합니다.",
                    options: ["예, 필수입니다", "아니오, 라이트모드만", "나중에 추가할 예정"],
                    priority: .important
                ),
                onAnswer: { _ in }
            )

            // 텍스트 입력 질문
            ClarificationCardView(
                request: ClarificationRequest(
                    question: "타겟 사용자가 누구인가요?",
                    askedBy: "박기획",
                    department: .planning,
                    priority: .critical
                ),
                onAnswer: { _ in }
            )

            // 답변 완료된 질문
            ClarificationCardView(
                request: ClarificationRequest(
                    question: "성능 요구사항이 있나요?",
                    askedBy: "이개발",
                    department: .development,
                    answer: "앱 실행 시 3초 이내 로딩",
                    isAnswered: true,
                    priority: .optional
                ),
                onAnswer: { _ in }
            )
        }
        .padding()
        .frame(width: 500)
    }
}
#endif
