import SwiftUI

/// 신규 직원 온보딩 화면
struct OnboardingView: View {
    let employee: Employee
    let departmentType: DepartmentType
    let onComplete: ([OnboardingQuestion]) -> Void
    let onSkip: () -> Void

    @State private var questions: [OnboardingQuestion]
    @State private var currentIndex = 0
    @State private var showingCompletion = false
    @Environment(\.dismiss) private var dismiss

    init(
        employee: Employee,
        departmentType: DepartmentType,
        onComplete: @escaping ([OnboardingQuestion]) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.employee = employee
        self.departmentType = departmentType
        self.onComplete = onComplete
        self.onSkip = onSkip
        self._questions = State(initialValue: OnboardingTemplate.questions(for: departmentType))
    }

    var progress: Double {
        Double(currentIndex) / Double(questions.count)
    }

    var currentQuestion: OnboardingQuestion {
        questions[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            OnboardingHeader(
                employee: employee,
                departmentType: departmentType,
                progress: progress,
                onSkip: {
                    onSkip()
                    dismiss()
                }
            )

            Divider()

            if showingCompletion {
                OnboardingCompletionView(
                    questions: questions,
                    onConfirm: {
                        onComplete(questions)
                        dismiss()
                    },
                    onEdit: {
                        showingCompletion = false
                        currentIndex = 0
                    }
                )
            } else {
                // Question Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Category badge
                        HStack {
                            Image(systemName: currentQuestion.category.icon)
                            Text(currentQuestion.category.rawValue)
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.secondary.opacity(0.1))
                        .clipShape(Capsule())

                        // Question
                        Text(currentQuestion.question)
                            .font(.title2.bold())

                        // Required indicator
                        if currentQuestion.isRequired {
                            Text("* 필수 질문입니다")
                                .font(.callout)
                                .foregroundStyle(.red)
                        }

                        // Answer input
                        TextEditor(text: Binding(
                            get: { questions[currentIndex].answer ?? "" },
                            set: { questions[currentIndex].answer = $0 }
                        ))
                        .font(.body)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color(NSColor.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )

                        // Placeholder hint
                        if let answer = questions[currentIndex].answer, answer.isEmpty,
                           !currentQuestion.placeholder.isEmpty {
                            Text("💡 \(currentQuestion.placeholder)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(24)
                }

                Divider()

                // Navigation
                OnboardingNavigation(
                    currentIndex: currentIndex,
                    totalCount: questions.count,
                    canGoNext: !currentQuestion.isRequired ||
                              (questions[currentIndex].answer != nil && !questions[currentIndex].answer!.isEmpty),
                    onPrevious: {
                        withAnimation {
                            currentIndex -= 1
                        }
                    },
                    onNext: {
                        withAnimation {
                            if currentIndex < questions.count - 1 {
                                currentIndex += 1
                            } else {
                                showingCompletion = true
                            }
                        }
                    }
                )
            }
        }
        .frame(width: 600, height: 500)
    }
}

struct OnboardingHeader: View {
    let employee: Employee
    let departmentType: DepartmentType
    let progress: Double
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Employee info
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(departmentType.color.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: departmentType.icon)
                            .foregroundStyle(departmentType.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(employee.name)님의 온보딩")
                            .font(.headline)
                        Text("\(departmentType.rawValue)팀 · 10년차 전문가")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("건너뛰기") {
                    onSkip()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(departmentType.color)
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct OnboardingNavigation: View {
    let currentIndex: Int
    let totalCount: Int
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var isLastQuestion: Bool {
        currentIndex == totalCount - 1
    }

    var body: some View {
        HStack {
            // Previous button
            Button {
                onPrevious()
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("이전")
                }
            }
            .buttonStyle(.bordered)
            .disabled(currentIndex == 0)

            Spacer()

            // Progress indicator
            Text("\(currentIndex + 1) / \(totalCount)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            // Next button
            Button {
                onNext()
            } label: {
                HStack {
                    Text(isLastQuestion ? "완료" : "다음")
                    Image(systemName: isLastQuestion ? "checkmark" : "chevron.right")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canGoNext)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct OnboardingCompletionView: View {
    let questions: [OnboardingQuestion]
    let onConfirm: () -> Void
    let onEdit: () -> Void

    var answeredCount: Int {
        questions.filter { $0.answer != nil && !$0.answer!.isEmpty }.count
    }

    var body: some View {
        VStack(spacing: 24) {
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 8) {
                Text("온보딩 완료!")
                    .font(.title2.bold())
                Text("\(answeredCount)/\(questions.count)개의 질문에 답변하셨습니다")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Summary
            VStack(alignment: .leading, spacing: 12) {
                Text("📝 답변 요약")
                    .font(.headline)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(questions.filter { $0.answer != nil && !$0.answer!.isEmpty }) { question in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(question.question)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Text(question.answer ?? "")
                                    .font(.callout)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .padding()
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Actions
            HStack(spacing: 12) {
                Button("다시 수정하기") {
                    onEdit()
                }
                .buttonStyle(.bordered)

                Button("문서로 저장하기") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
            }

            Text("💡 답변 내용은 회사 위키에 마크다운 문서로 저장됩니다")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

#Preview {
    OnboardingView(
        employee: Employee(name: "Claude-기획", aiType: .claude),
        departmentType: .planning,
        onComplete: { _ in },
        onSkip: {}
    )
}
