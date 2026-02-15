import SwiftUI

/// 질문-답변 메인 화면
struct ClarificationView: View {
    @ObservedObject var manager: ClarificationManager
    let onComplete: (String) -> Void  // 보강된 요구사항 전달
    let onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            headerView

            Divider()

            // 진행 상태
            progressView

            // 질문 리스트
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(manager.currentSession?.requests ?? []) { request in
                        ClarificationCardView(request: request) { answer in
                            manager.answerQuestion(request.id, with: answer)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // 하단 버튼
            bottomButtons
        }
        .frame(minWidth: 600, minHeight: 500)
        .frame(maxWidth: 800, maxHeight: 700)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("💬")
                        .font(.title)
                    Text("확인이 필요해요!")
                        .font(.title2.bold())
                }

                Text("더 좋은 결과를 위해 몇 가지 질문에 답해주세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(spacing: 8) {
            HStack {
                // 답변 현황
                let answered = manager.currentSession?.answeredCount ?? 0
                let total = manager.currentSession?.requests.count ?? 0

                Text("\(answered)/\(total) 답변 완료")
                    .font(.subheadline.weight(.medium))

                Spacer()

                // 필수 질문 미답변 경고
                if let session = manager.currentSession, session.unansweredCriticalCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("필수 \(session.unansweredCriticalCount)개 미답변")
                            .foregroundStyle(.red)
                    }
                    .font(.caption.weight(.medium))
                }
            }

            ProgressView(value: manager.progress)
                .tint(.blue)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 16) {
            // 스킵 버튼
            Button {
                manager.skipSession()
                if let enriched = manager.getEnrichedRequirement() {
                    onSkip()
                }
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "forward.fill")
                    Text("그냥 알아서 해줘")
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.bordered)
            .help("AI가 적절한 기본값을 사용하여 진행합니다")

            Spacer()

            // 요구사항 미리보기 (답변이 있을 때)
            if (manager.currentSession?.answeredCount ?? 0) > 0 {
                Button {
                    // 미리보기 (향후 구현)
                } label: {
                    Label("미리보기", systemImage: "eye")
                }
                .buttonStyle(.bordered)
                .disabled(true)  // 향후 구현
            }

            // 확인 버튼
            Button {
                manager.completeSession()
                if let enriched = manager.getEnrichedRequirement() {
                    onComplete(enriched)
                }
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("확인")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!manager.canComplete)
            .help(manager.canComplete ? "파이프라인을 시작합니다" : "필수 질문에 먼저 답해주세요")
        }
        .padding()
    }
}

// MARK: - Loading View

struct ClarificationLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            VStack(spacing: 8) {
                Text("요구사항을 분석하고 있어요...")
                    .font(.headline)

                Text("AI가 부족한 정보를 파악 중입니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 300, minHeight: 200)
        .padding(40)
    }
}

// MARK: - Preview

#if DEBUG
struct ClarificationView_Previews: PreviewProvider {
    static var previews: some View {
        let manager = ClarificationManager()
        // 테스트 세션 설정
        manager.currentSession = ClarificationSession(
            requirement: "로그인 화면에 소셜 로그인 기능을 추가해주세요",
            requests: [
                ClarificationRequest(
                    question: "어떤 소셜 로그인을 지원할까요?",
                    askedBy: "김개발",
                    department: .development,
                    options: ["Google만", "Apple만", "Google + Apple", "모두 (Google, Apple, Kakao)"],
                    priority: .critical
                ),
                ClarificationRequest(
                    question: "다크모드 지원이 필요한가요?",
                    askedBy: "이디자인",
                    department: .design,
                    options: ["예", "아니오", "나중에"],
                    priority: .important
                ),
                ClarificationRequest(
                    question: "출시 일정이 있나요?",
                    askedBy: "박마케팅",
                    department: .marketing,
                    priority: .optional
                )
            ],
            projectId: UUID()
        )

        return ClarificationView(
            manager: manager,
            onComplete: { _ in },
            onSkip: { }
        )
    }
}
#endif
