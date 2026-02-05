import SwiftUI
import WebKit

/// 회사 위키 화면
struct WikiView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @State private var selectedDocument: WikiDocument?
    @State private var showingNewDocument = false
    @State private var searchText = ""
    @State private var selectedDepartment: String? = nil
    @State private var sortOption: WikiSortOption = .newest

    enum WikiSortOption: String, CaseIterable {
        case newest = "최신순"
        case oldest = "오래된순"
        case title = "제목순"
        case department = "부서별"
    }

    var wikiPath: String {
        let path = companyStore.company.settings.wikiSettings?.wikiPath ?? ""
        return path.isEmpty ? WikiService.shared.defaultWikiPath : path
    }

    /// 필터링 및 정렬된 문서
    var filteredDocuments: [WikiDocument] {
        var docs = companyStore.company.wikiDocuments

        // 검색 필터
        if !searchText.isEmpty {
            docs = docs.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                $0.createdBy.localizedCaseInsensitiveContains(searchText)
            }
        }

        // 부서 필터
        if let dept = selectedDepartment {
            docs = docs.filter { $0.createdBy == dept }
        }

        // 정렬
        switch sortOption {
        case .newest:
            docs.sort { $0.updatedAt > $1.updatedAt }
        case .oldest:
            docs.sort { $0.updatedAt < $1.updatedAt }
        case .title:
            docs.sort { $0.title < $1.title }
        case .department:
            docs.sort { $0.createdBy < $1.createdBy }
        }

        return docs
    }

    /// 모든 부서 목록
    var departments: [String] {
        Array(Set(companyStore.company.wikiDocuments.map { $0.createdBy })).sorted()
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 게시판 형태의 문서 목록 (50%)
                VStack(spacing: 0) {
                    // 상단 필터 & 검색
                    WikiFilterBar(
                        searchText: $searchText,
                        selectedDepartment: $selectedDepartment,
                        sortOption: $sortOption,
                        departments: departments,
                        documentCount: filteredDocuments.count
                    )
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))

                    Divider()

                    // 문서 테이블
                    if filteredDocuments.isEmpty {
                        WikiEmptyView(hasDocuments: !companyStore.company.wikiDocuments.isEmpty)
                    } else {
                        WikiTableView(
                            documents: filteredDocuments,
                            selectedDocument: $selectedDocument
                        )
                    }
                }
                .frame(width: geometry.size.width / 2)

                Divider()

                // 문서 디테일 뷰 (50%)
                if let document = selectedDocument {
                    WikiDocumentView(
                        document: document,
                        wikiPath: wikiPath,
                        onEdit: { },
                        onDelete: {
                            try? WikiService.shared.deleteDocument(document, at: wikiPath)
                            companyStore.removeWikiDocument(document.id)
                            selectedDocument = nil
                        },
                        onUpdate: { updatedDoc in
                            companyStore.updateWikiDocument(updatedDoc)
                            try? WikiService.shared.saveDocument(updatedDoc, at: wikiPath)
                            selectedDocument = updatedDoc
                        }
                    )
                    .frame(width: geometry.size.width / 2)
                } else {
                    WikiPlaceholderView(
                        onCreateDocument: { showingNewDocument = true },
                        onOpenFolder: { WikiService.shared.openWikiInFinder(at: wikiPath) },
                        onInitializeWiki: {
                            try? WikiService.shared.initializeWiki(at: wikiPath)
                            companyStore.updateWikiPath(wikiPath)
                        }
                    )
                    .frame(width: geometry.size.width / 2)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showingNewDocument = true
                } label: {
                    Label("새 문서", systemImage: "doc.badge.plus")
                }

                Button {
                    WikiService.shared.openWikiInFinder(at: wikiPath)
                } label: {
                    Label("Finder에서 열기", systemImage: "folder")
                }
            }
        }
        .sheet(isPresented: $showingNewDocument) {
            NewWikiDocumentView { document in
                companyStore.addWikiDocument(document)
                try? WikiService.shared.saveDocument(document, at: wikiPath)
                selectedDocument = document
            }
        }
        .onAppear {
            // 위키 초기화 확인
            if !FileManager.default.fileExists(atPath: wikiPath) {
                try? WikiService.shared.initializeWiki(at: wikiPath)
                companyStore.updateWikiPath(wikiPath)
            }

            // 전체 프로젝트에서 .md 파일 스캔하여 추가
            print("🔍 [WikiView] 위키 문서 스캔 시작")
            let scannedDocuments = WikiService.shared.scanAllDocuments()
            print("📊 [WikiView] 스캔 완료: \(scannedDocuments.count)개 문서 발견")

            // 기존 문서와 중복되지 않도록 추가
            var addedCount = 0
            for doc in scannedDocuments {
                // filePath 또는 fileName으로 중복 체크
                let isDuplicate = companyStore.company.wikiDocuments.contains { existing in
                    if let docPath = doc.filePath, let existingPath = existing.filePath {
                        return docPath == existingPath
                    }
                    return existing.fileName == doc.fileName && existing.title == doc.title
                }

                if !isDuplicate {
                    companyStore.addWikiDocument(doc)
                    addedCount += 1
                }
            }
            print("✅ [WikiView] \(addedCount)개 문서 추가 완료")
        }
    }
}

// MARK: - 필터 바
struct WikiFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedDepartment: String?
    @Binding var sortOption: WikiView.WikiSortOption
    let departments: [String]
    let documentCount: Int

    var body: some View {
        VStack(spacing: 12) {
            // 상단: 검색 + 문서 개수
            HStack {
                // 검색
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("문서 검색...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)

                // 문서 개수
                Text("\(documentCount)개 문서")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // 하단: 부서 필터 + 정렬
            HStack {
                // 부서 필터
                Menu {
                    Button("전체 부서") {
                        selectedDepartment = nil
                    }
                    Divider()
                    ForEach(departments, id: \.self) { dept in
                        Button(dept) {
                            selectedDepartment = dept
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(selectedDepartment ?? "전체 부서")
                    }
                    .font(.callout)
                }
                .menuStyle(.borderlessButton)

                Divider()
                    .frame(height: 16)

                // 정렬
                Picker("정렬", selection: $sortOption) {
                    ForEach(WikiView.WikiSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Spacer()
            }
        }
    }
}

// MARK: - 테이블 뷰
struct WikiTableView: View {
    let documents: [WikiDocument]
    @Binding var selectedDocument: WikiDocument?

    /// 부서별 아이콘
    func departmentIcon(for createdBy: String) -> String {
        if createdBy.contains("기획") { return "lightbulb.fill" }
        else if createdBy.contains("디자인") { return "paintbrush.fill" }
        else if createdBy.contains("개발") { return "chevron.left.forwardslash.chevron.right" }
        else if createdBy.contains("QA") { return "checkmark.shield.fill" }
        else if createdBy.contains("마케팅") { return "megaphone.fill" }
        else if createdBy.contains("전사") || createdBy.contains("공용") { return "building.2.fill" }
        else { return "doc.text.fill" }
    }

    /// 부서별 색상
    func departmentColor(for createdBy: String) -> Color {
        if createdBy.contains("기획") { return .purple }
        else if createdBy.contains("디자인") { return .pink }
        else if createdBy.contains("개발") { return .blue }
        else if createdBy.contains("QA") { return .green }
        else if createdBy.contains("마케팅") { return .orange }
        else if createdBy.contains("전사") || createdBy.contains("공용") { return .gray }
        else { return .secondary }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 테이블 헤더
                HStack(spacing: 16) {
                    Text("제목")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("작성자")
                        .frame(width: 140, alignment: .leading)
                    Text("태그")
                        .frame(width: 180, alignment: .leading)
                    Text("수정일")
                        .frame(width: 80, alignment: .leading)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // 문서 목록
                ForEach(documents) { doc in
                    Button {
                        selectedDocument = doc
                    } label: {
                        HStack(spacing: 16) {
                            // 제목 + 아이콘
                            HStack(spacing: 10) {
                                HStack(spacing: 4) {
                                    Image(systemName: doc.category.icon)
                                        .foregroundStyle(.blue)
                                        .font(.body)
                                    Image(systemName: doc.fileType.icon)
                                        .foregroundStyle(doc.fileType == .html ? .orange : .secondary)
                                        .font(.caption)
                                }
                                .frame(width: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(doc.title)
                                            .lineLimit(1)
                                            .font(.body)
                                        if doc.fileType == .html {
                                            Text("HTML")
                                                .font(.caption2.weight(.medium))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.15))
                                                .foregroundStyle(.orange)
                                                .cornerRadius(4)
                                        }
                                    }
                                    Text(doc.category.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // 작성자 (부서 뱃지)
                            HStack(spacing: 6) {
                                Image(systemName: departmentIcon(for: doc.createdBy))
                                    .font(.caption)
                                Text(doc.createdBy)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(departmentColor(for: doc.createdBy).opacity(0.15))
                            .foregroundStyle(departmentColor(for: doc.createdBy))
                            .cornerRadius(12)
                            .frame(width: 140, alignment: .leading)

                            // 태그 (칩 형태)
                            HStack(spacing: 4) {
                                ForEach(doc.tags.prefix(2), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.secondary.opacity(0.1))
                                        .foregroundStyle(.secondary)
                                        .cornerRadius(8)
                                        .lineLimit(1)
                                }
                                if doc.tags.count > 2 {
                                    Text("+\(doc.tags.count - 2)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(width: 180, alignment: .leading)

                            // 수정일
                            Text(doc.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            selectedDocument?.id == doc.id ?
                            Color.accentColor.opacity(0.08) :
                            Color.clear
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()
                }
            }
        }
    }
}

// MARK: - 빈 상태 뷰
struct WikiEmptyView: View {
    let hasDocuments: Bool  // 전체 문서는 있는데 검색 결과만 없는 경우

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasDocuments ? "magnifyingglass" : "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text(hasDocuments ? "검색 결과가 없습니다" : "문서가 없습니다")
                    .font(.title3.bold())
                Text(hasDocuments ? "다른 검색어를 입력해보세요" : "AI 직원에게 문서 작성을 요청해보세요")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WikiDocumentView: View {
    let document: WikiDocument
    let wikiPath: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onUpdate: (WikiDocument) -> Void

    @State private var isEditing = false
    @State private var editedContent: String = ""
    @State private var editedTitle: String = ""
    @State private var editedCategory: WikiCategory = .reference
    @State private var editedTags: String = ""

    init(document: WikiDocument, wikiPath: String, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void, onUpdate: @escaping (WikiDocument) -> Void = { _ in }) {
        self.document = document
        self.wikiPath = wikiPath
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if isEditing {
                        // 편집 모드: 카테고리 선택
                        Picker("카테고리", selection: $editedCategory) {
                            ForEach(WikiCategory.allCases, id: \.self) { cat in
                                Label(cat.rawValue, systemImage: cat.icon)
                                    .tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    } else {
                        HStack {
                            Image(systemName: document.category.icon)
                                .foregroundStyle(.blue)
                            Text(document.category.rawValue)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if isEditing {
                        TextField("제목", text: $editedTitle)
                            .font(.title2.bold())
                            .textFieldStyle(.plain)
                    } else {
                        Text(document.title)
                            .font(.title2.bold())
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if isEditing {
                        Button {
                            saveChanges()
                        } label: {
                            Label("저장", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            cancelEditing()
                        } label: {
                            Label("취소", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            startEditing()
                        } label: {
                            Label("편집", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            WikiService.shared.openDocument(document, at: wikiPath)
                        } label: {
                            Label("열기", systemImage: "arrow.up.forward.square")
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content
            if isEditing {
                // Edit mode
                VStack(spacing: 0) {
                    // 태그 편집
                    HStack {
                        Image(systemName: "tag")
                            .foregroundStyle(.secondary)
                        TextField("태그 (쉼표로 구분)", text: $editedTags)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.5))

                    Divider()

                    // 내용 편집
                    TextEditor(text: $editedContent)
                        .font(.body.monospaced())
                        .padding()
                }
            } else {
                // View mode — 메타데이터 + WKWebView 렌더링
                VStack(alignment: .leading, spacing: 0) {
                    // Metadata & Tags (SwiftUI)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            Label(document.createdBy, systemImage: "person")
                            Label(document.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)

                        if !document.tags.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "tag")
                                    .foregroundStyle(.secondary)
                                ForEach(document.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.callout)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                    Divider()

                    // HTML 콘텐츠 (WKWebView가 자체 스크롤 처리)
                    if document.fileType == .html {
                        HTMLContentView(content: document.content)
                    } else {
                        HTMLContentView(
                            content: MarkdownToHTMLConverter.convert(document.content)
                        )
                    }
                }
            }
        }
        .onChange(of: document.id) { _, _ in
            isEditing = false
        }
    }

    private func startEditing() {
        editedContent = document.content
        editedTitle = document.title
        editedCategory = document.category
        editedTags = document.tags.joined(separator: ", ")
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
        editedContent = ""
        editedTitle = ""
        editedTags = ""
    }

    private func saveChanges() {
        var updatedDoc = document
        updatedDoc.title = editedTitle
        updatedDoc.content = editedContent
        updatedDoc.category = editedCategory
        updatedDoc.tags = editedTags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        updatedDoc.updatedAt = Date()
        onUpdate(updatedDoc)
        isEditing = false
    }
}

// MarkdownContentView 및 MarkdownLineView 제거됨
// → 마크다운은 MarkdownToHTMLConverter로 HTML 변환 후 HTMLContentView에서 렌더링

struct WikiPlaceholderView: View {
    let onCreateDocument: () -> Void
    let onOpenFolder: () -> Void
    let onInitializeWiki: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("회사 위키")
                    .font(.title2.bold())
                Text("모든 정보가 마크다운 문서로 저장됩니다")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    onCreateDocument()
                } label: {
                    Label("새 문서 만들기", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onOpenFolder()
                } label: {
                    Label("폴더 열기", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NewWikiDocumentView: View {
    let onSave: (WikiDocument) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var category: WikiCategory = .reference
    @State private var tags = ""
    @State private var fileType: WikiDocumentType = .markdown

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("새 문서")
                    .font(.title2.bold())
                Spacer()
                Button("취소") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                TextField("제목", text: $title)

                Picker("파일 타입", selection: $fileType) {
                    ForEach([WikiDocumentType.markdown, WikiDocumentType.html], id: \.self) { type in
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                            Text(type.rawValue)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.segmented)

                Picker("카테고리", selection: $category) {
                    ForEach(WikiCategory.allCases, id: \.self) { cat in
                        Label(cat.rawValue, systemImage: cat.icon)
                            .tag(cat)
                    }
                }

                TextField("태그 (쉼표로 구분)", text: $tags)

                Section(header: HStack {
                    Text("내용")
                    Spacer()
                    if fileType == .html {
                        Text("HTML 코드를 입력하세요")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("마크다운 형식")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }) {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                        .font(.system(.body, design: fileType == .html ? .monospaced : .default))
                }
            }
            .padding()

            Divider()

            HStack {
                Spacer()
                Button("저장") {
                    let document = WikiDocument(
                        title: title,
                        content: content,
                        category: category,
                        tags: tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) },
                        fileType: fileType
                    )
                    onSave(document)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
    }
}

/// HTML 콘텐츠를 렌더링하는 뷰 (WKWebView 사용)
/// - 마크다운 변환된 HTML과 순수 HTML 콘텐츠 모두 지원
/// - 이미 완전한 HTML 문서(<html> 태그 포함)는 그대로 로드하고,
///   body 조각만 있는 경우 기본 CSS 템플릿으로 래핑
struct HTMLContentView: NSViewRepresentable {
    let content: String

    /// 완전한 HTML 문서인지 확인
    private var isCompleteHTML: Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("<!doctype") || trimmed.hasPrefix("<html")
    }

    /// 렌더링할 최종 HTML
    private var finalHTML: String {
        if isCompleteHTML {
            // 이미 완전한 HTML — 기본 다크모드 CSS만 주입
            return injectBaseStylesIfNeeded(content)
        } else {
            // body 조각 — 템플릿으로 래핑
            return MarkdownToHTMLConverter.wrapInHTMLTemplate(content)
        }
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground") // 투명 배경
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = finalHTML
        // 콘텐츠가 변경된 경우에만 리로드
        if context.coordinator.lastContent != html {
            context.coordinator.lastContent = html
            webView.loadHTMLString(html, baseURL: nil)
            print("✅ [HTMLContentView] HTML 콘텐츠 로드 완료 (\(html.count)자)")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 완전한 HTML 문서에 기본 다크모드 CSS를 주입
    private func injectBaseStylesIfNeeded(_ html: String) -> String {
        // 이미 prefers-color-scheme이 있으면 주입 안 함
        if html.contains("prefers-color-scheme") {
            return html
        }

        let darkModeCSS = """
        <style>
        @media (prefers-color-scheme: dark) {
            body { background: #1d1d1f; color: #f5f5f7; }
            a { color: #4da3ff; }
            table, th, td { border-color: #38383a; }
            code, pre { background: #2c2c2e; }
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", "Noto Sans KR", sans-serif;
            font-size: 14px;
            line-height: 1.7;
            padding: 24px;
        }
        </style>
        """

        // </head> 앞에 주입
        if let range = html.range(of: "</head>", options: .caseInsensitive) {
            var modified = html
            modified.insert(contentsOf: darkModeCSS, at: range.lowerBound)
            return modified
        }

        // <head>가 없으면 <html> 뒤에 추가
        if let range = html.range(of: "<html", options: .caseInsensitive) {
            if let closeRange = html[range.upperBound...].range(of: ">") {
                var modified = html
                modified.insert(contentsOf: "<head>\(darkModeCSS)</head>", at: closeRange.upperBound)
                return modified
            }
        }

        // 어떤 구조도 없으면 그냥 앞에 추가
        return darkModeCSS + html
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastContent: String = ""

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                if url.scheme == "http" || url.scheme == "https" {
                    if navigationAction.navigationType == .linkActivated {
                        NSWorkspace.shared.open(url)
                        decisionHandler(.cancel)
                        return
                    }
                }
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ [HTMLContentView] 로드 실패: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ [HTMLContentView] 렌더링 완료")
        }
    }
}

#Preview {
    WikiView()
        .environmentObject(CompanyStore())
}
