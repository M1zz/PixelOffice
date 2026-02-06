import SwiftUI

/// 프로젝트 정보 편집 뷰
struct ProjectInfoEditorView: View {
    let projectName: String
    @Binding var isPresented: Bool
    @State private var info: ProjectInfo
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var saveSuccess = false

    // 리스트 편집용 임시 상태
    @State private var newDependency = ""
    @State private var newFeature = ""
    @State private var newEndpoint = ""
    @State private var newService = ""
    @State private var newFieldTitle = ""

    private let projectPath: String

    init(projectName: String, isPresented: Binding<Bool>) {
        self.projectName = projectName
        self._isPresented = isPresented
        self.projectPath = DataPathService.shared.projectPath(projectName)
        self._info = State(initialValue: ProjectInfo())
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            header

            Divider()

            if isLoading {
                ProgressView("불러오는 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 폼
                ScrollView {
                    VStack(spacing: 24) {
                        pathSection
                        techStackSection
                        productSection
                        guideSection
                        integrationSection
                        notesSection
                        customFieldsSection
                    }
                    .padding(24)
                }
            }

            Divider()

            // 푸터
            footer
        }
        .frame(width: 700, height: 800)
        .onAppear {
            loadProjectInfo()
        }
        .alert(saveSuccess ? "저장 완료" : "오류", isPresented: $showingSaveAlert) {
            Button("확인") {
                if saveSuccess {
                    isPresented = false
                }
            }
        } message: {
            Text(saveAlertMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("프로젝트 정보")
                    .font(.title2.bold())
                Text(projectName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

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
        .padding()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                openInFinder()
            } label: {
                Label("Finder에서 열기", systemImage: "folder")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("취소") {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)

            Button("저장") {
                saveProjectInfo()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving)
        }
        .padding()
    }

    // MARK: - Path Section

    private var pathSection: some View {
        SectionCard(title: "프로젝트 경로", icon: "folder.fill", color: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("상대경로")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("예: ../MyProject", text: $info.relativePath)
                            .textFieldStyle(.roundedBorder)
                            .font(.body.monospaced())
                        Button {
                            selectFolder(isRelative: true)
                        } label: {
                            Image(systemName: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("절대경로 (로컬 참조용)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("예: /Users/name/Projects/MyProject", text: $info.absolutePath)
                            .textFieldStyle(.roundedBorder)
                            .font(.body.monospaced())
                        Button {
                            selectFolder(isRelative: false)
                        } label: {
                            Image(systemName: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Text("상대경로는 git으로 추적되어 다른 컴퓨터에서도 사용할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Tech Stack Section

    private var techStackSection: some View {
        SectionCard(title: "기술 스택", icon: "wrench.and.screwdriver.fill", color: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("언어")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("예: Swift 5.9", text: $info.language)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("프레임워크")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("예: SwiftUI, AppKit", text: $info.framework)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("빌드 도구")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("예: Tuist, SPM", text: $info.buildTool)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("주요 의존성")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    EditableTagList(
                        items: $info.dependencies,
                        newItem: $newDependency,
                        placeholder: "의존성 추가..."
                    )
                }
            }
        }
    }

    // MARK: - Product Section

    private var productSection: some View {
        SectionCard(title: "제품 정보", icon: "shippingbox.fill", color: .purple) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("비전/목표")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $info.vision)
                        .frame(minHeight: 60)
                        .font(.body)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2))
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("타겟 사용자")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("예: 개발자, 디자이너, 일반 사용자", text: $info.targetUsers)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("핵심 기능")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    EditableTagList(
                        items: $info.coreFeatures,
                        newItem: $newFeature,
                        placeholder: "기능 추가..."
                    )
                }
            }
        }
    }

    // MARK: - Guide Section

    private var guideSection: some View {
        SectionCard(title: "개발 가이드", icon: "book.fill", color: .green) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("브랜치 전략")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("예: main, feature/*, fix/*", text: $info.branchStrategy)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("커밋 규칙")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("예: Conventional Commits", text: $info.commitConvention)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("코드 스타일")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("예: SwiftLint 기본 설정", text: $info.codeStyle)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    // MARK: - Integration Section

    private var integrationSection: some View {
        SectionCard(title: "외부 연동", icon: "link", color: .cyan) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API 엔드포인트")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    EditableTagList(
                        items: $info.apiEndpoints,
                        newItem: $newEndpoint,
                        placeholder: "엔드포인트 추가..."
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("외부 서비스")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    EditableTagList(
                        items: $info.externalServices,
                        newItem: $newService,
                        placeholder: "서비스 추가..."
                    )
                }
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        SectionCard(title: "메모", icon: "note.text", color: .gray) {
            VStack(alignment: .leading, spacing: 4) {
                TextEditor(text: $info.notes)
                    .frame(minHeight: 80)
                    .font(.body)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2))
                    )

                Text("추가로 기록해둘 정보를 자유롭게 작성하세요.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Custom Fields Section

    private var customFieldsSection: some View {
        SectionCard(title: "추가 정보", icon: "plus.rectangle.on.rectangle", color: .indigo) {
            VStack(alignment: .leading, spacing: 16) {
                // 기존 커스텀 필드들
                ForEach($info.customFields) { $field in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("필드 제목", text: $field.title)
                                .font(.headline)
                                .textFieldStyle(.plain)

                            Spacer()

                            Button {
                                info.customFields.removeAll { $0.id == field.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }

                        TextEditor(text: $field.content)
                            .frame(minHeight: 60)
                            .font(.body)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // 새 필드 추가
                HStack {
                    TextField("새 필드 제목 (예: 디자인 참고, 회의 결정사항...)", text: $newFieldTitle)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        addCustomField()
                    } label: {
                        Label("추가", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newFieldTitle.isEmpty)
                }

                Text("대화하면서 얻은 정보나 결정사항을 자유롭게 추가하세요.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func addCustomField() {
        let trimmed = newFieldTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            let field = CustomField(title: trimmed)
            info.customFields.append(field)
            newFieldTitle = ""
        }
    }

    // MARK: - Actions

    private func loadProjectInfo() {
        let filePath = "\(projectPath)/PROJECT.md"

        if FileManager.default.fileExists(atPath: filePath),
           let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            info = ProjectInfo.fromMarkdown(content)
        }

        isLoading = false
    }

    private func saveProjectInfo() {
        isSaving = true

        let filePath = "\(projectPath)/PROJECT.md"
        let markdown = "# \(projectName)\n\n\(info.toMarkdown())"

        do {
            try markdown.write(toFile: filePath, atomically: true, encoding: .utf8)
            saveSuccess = true
            saveAlertMessage = "프로젝트 정보가 저장되었습니다."
        } catch {
            saveSuccess = false
            saveAlertMessage = "저장 실패: \(error.localizedDescription)"
            print("PROJECT.md 저장 실패: \(error)")
        }

        isSaving = false
        showingSaveAlert = true
    }

    private func openInFinder() {
        let filePath = "\(projectPath)/PROJECT.md"
        if FileManager.default.fileExists(atPath: filePath) {
            NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: projectPath)
        } else {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: projectPath)
        }
    }

    private func selectFolder(isRelative: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "프로젝트 폴더를 선택하세요"

        if panel.runModal() == .OK, let url = panel.url {
            let absolutePath = url.path

            if isRelative {
                // 상대경로 계산
                let basePath = projectPath
                info.relativePath = calculateRelativePath(from: basePath, to: absolutePath)
                info.absolutePath = absolutePath
            } else {
                info.absolutePath = absolutePath
            }
        }
    }

    private func calculateRelativePath(from base: String, to target: String) -> String {
        let baseComponents = base.components(separatedBy: "/").filter { !$0.isEmpty }
        let targetComponents = target.components(separatedBy: "/").filter { !$0.isEmpty }

        // 공통 prefix 찾기
        var commonCount = 0
        for i in 0..<min(baseComponents.count, targetComponents.count) {
            if baseComponents[i] == targetComponents[i] {
                commonCount += 1
            } else {
                break
            }
        }

        // 상위로 올라가는 횟수
        let upCount = baseComponents.count - commonCount

        // 상대경로 생성
        var relativePath = Array(repeating: "..", count: upCount)
        relativePath.append(contentsOf: targetComponents[commonCount...])

        return relativePath.joined(separator: "/")
    }
}

// MARK: - Section Card

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }

            content
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Editable Tag List

struct EditableTagList: View {
    @Binding var items: [String]
    @Binding var newItem: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 기존 아이템
            if !items.isEmpty {
                FlowLayoutView(items: items) { item in
                    HStack(spacing: 4) {
                        Text(item)
                            .font(.callout)
                        Button {
                            items.removeAll { $0 == item }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            // 새 아이템 입력
            HStack {
                TextField(placeholder, text: $newItem)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addItem()
                    }

                Button {
                    addItem()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(newItem.isEmpty)
            }
        }
    }

    private func addItem() {
        let trimmed = newItem.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !items.contains(trimmed) {
            items.append(trimmed)
            newItem = ""
        }
    }
}

// MARK: - Flow Layout (간단 버전)

struct FlowLayoutView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element) { _, item in
                content(item)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geometry.size.width {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == items.last! {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last! {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry -> Color in
            DispatchQueue.main.async {
                binding.wrappedValue = geometry.size.height
            }
            return Color.clear
        }
    }
}

#Preview {
    ProjectInfoEditorView(projectName: "테스트 프로젝트", isPresented: .constant(true))
}
