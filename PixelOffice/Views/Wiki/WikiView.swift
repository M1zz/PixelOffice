import SwiftUI

/// 회사 위키 화면
struct WikiView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @State private var selectedCategory: WikiCategory?
    @State private var selectedDocument: WikiDocument?
    @State private var showingNewDocument = false
    @State private var searchText = ""

    var wikiPath: String {
        let path = companyStore.company.settings.wikiSettings?.wikiPath ?? ""
        return path.isEmpty ? WikiService.shared.defaultWikiPath : path
    }

    var body: some View {
        HSplitView {
            // Sidebar - Categories
            WikiSidebar(
                selectedCategory: $selectedCategory,
                documents: companyStore.company.wikiDocuments,
                onSelectDocument: { doc in
                    selectedDocument = doc
                }
            )
            .frame(minWidth: 200, maxWidth: 250)

            // Content
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
            } else {
                WikiPlaceholderView(
                    onCreateDocument: { showingNewDocument = true },
                    onOpenFolder: { WikiService.shared.openWikiInFinder(at: wikiPath) },
                    onInitializeWiki: {
                        try? WikiService.shared.initializeWiki(at: wikiPath)
                        companyStore.updateWikiPath(wikiPath)
                    }
                )
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

            // 기존 .md 파일 스캔하여 추가
            let scannedDocuments = WikiService.shared.scanExistingDocuments(at: wikiPath)
            for doc in scannedDocuments {
                // 이미 등록된 문서가 아닌 경우에만 추가
                if !companyStore.company.wikiDocuments.contains(where: { $0.fileName == doc.fileName }) {
                    companyStore.addWikiDocument(doc)
                }
            }
        }
    }
}

struct WikiSidebar: View {
    @Binding var selectedCategory: WikiCategory?
    let documents: [WikiDocument]
    let onSelectDocument: (WikiDocument) -> Void

    /// 부서 태그 목록 (문서에서 추출)
    var departmentTags: [String] {
        let allTags = documents.flatMap { $0.tags }
        let departmentNames = DepartmentType.allCases.map { $0.rawValue }
        return Array(Set(allTags.filter { departmentNames.contains($0) })).sorted()
    }

    var body: some View {
        List {
            // 전체 문서 (문서가 있을 때만 표시)
            if !documents.isEmpty {
                Section("전체 문서 (\(documents.count)개)") {
                    ForEach(documents.sorted { $0.updatedAt > $1.updatedAt }) { doc in
                        Button {
                            onSelectDocument(doc)
                        } label: {
                            HStack {
                                Image(systemName: doc.category.icon)
                                    .foregroundStyle(.blue)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(doc.title)
                                        .lineLimit(1)
                                    HStack {
                                        Text(doc.createdBy)
                                        Text("•")
                                        Text(doc.category.rawValue)
                                    }
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 부서별 문서
            if !departmentTags.isEmpty {
                Section("부서별") {
                    ForEach(departmentTags, id: \.self) { tag in
                        let tagDocs = documents.filter { $0.tags.contains(tag) }

                        DisclosureGroup {
                            ForEach(tagDocs) { doc in
                                Button {
                                    onSelectDocument(doc)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(doc.title)
                                                .lineLimit(1)
                                            Text(doc.createdBy)
                                                .font(.callout)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "person.3.fill")
                                    .foregroundStyle(.orange)
                                Text("\(tag)팀")
                                Spacer()
                                Text("\(tagDocs.count)")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("카테고리") {
                ForEach(WikiCategory.allCases, id: \.self) { category in
                    let categoryDocs = documents.filter { $0.category == category }

                    if !categoryDocs.isEmpty {
                        DisclosureGroup {
                            ForEach(categoryDocs) { doc in
                                Button {
                                    onSelectDocument(doc)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(doc.title)
                                                .lineLimit(1)
                                            Text(doc.createdBy)
                                                .font(.callout)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundStyle(.blue)
                                Text(category.rawValue)
                                Spacer()
                                Text("\(categoryDocs.count)")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("최근 문서") {
                ForEach(documents.sorted { $0.updatedAt > $1.updatedAt }.prefix(5)) { doc in
                    Button {
                        onSelectDocument(doc)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.title)
                                .lineLimit(1)
                            HStack {
                                Text(doc.createdBy)
                                Text("•")
                                Text(doc.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            }
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.sidebar)
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
                // View mode with markdown rendering
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Metadata
                        HStack(spacing: 16) {
                            Label(document.createdBy, systemImage: "person")
                            Label(document.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)

                        // Tags
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

                        Divider()

                        // Markdown rendered content
                        MarkdownContentView(content: document.content)
                            .textSelection(.enabled)
                    }
                    .padding()
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

/// 마크다운 콘텐츠를 렌더링하는 뷰
struct MarkdownContentView: View {
    let content: String

    var lines: [String] {
        content.components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                MarkdownLineView(line: line)
            }
        }
    }
}

/// 마크다운 라인을 렌더링하는 뷰
struct MarkdownLineView: View {
    let line: String

    var body: some View {
        if line.isEmpty {
            Spacer().frame(height: 8)
        } else if line.hasPrefix("# ") {
            Text(String(line.dropFirst(2)))
                .font(.title.bold())
                .padding(.top, 8)
        } else if line.hasPrefix("## ") {
            Text(String(line.dropFirst(3)))
                .font(.title2.bold())
                .padding(.top, 6)
        } else if line.hasPrefix("### ") {
            Text(String(line.dropFirst(4)))
                .font(.title3.bold())
                .padding(.top, 4)
        } else if line.hasPrefix("#### ") {
            Text(String(line.dropFirst(5)))
                .font(.headline)
                .padding(.top, 2)
        } else if line.hasPrefix("> ") {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 4)
                renderInlineMarkdown(String(line.dropFirst(2)))
                    .font(.body.italic())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
                Spacer()
            }
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .foregroundStyle(.secondary)
                renderInlineMarkdown(String(line.dropFirst(2)))
            }
        } else if let match = line.firstMatch(of: /^(\d+)\.\s(.*)/) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(match.1).")
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .trailing)
                renderInlineMarkdown(String(match.2))
            }
        } else if line.hasPrefix("```") {
            Text(line.replacingOccurrences(of: "```", with: ""))
                .font(.body.monospaced())
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.textBackgroundColor).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else if line.hasPrefix("---") || line.hasPrefix("***") || line.hasPrefix("___") {
            Divider()
                .padding(.vertical, 8)
        } else if line.hasPrefix("|") {
            // 테이블 행
            HStack(spacing: 0) {
                ForEach(Array(line.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }.enumerated()), id: \.offset) { _, cell in
                    if !cell.isEmpty && !cell.allSatisfy({ $0 == "-" || $0 == ":" }) {
                        Text(cell)
                            .frame(minWidth: 60, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                }
            }
            .background(Color(NSColor.textBackgroundColor).opacity(0.2))
        } else {
            renderInlineMarkdown(line)
        }
    }

    @ViewBuilder
    private func renderInlineMarkdown(_ text: String) -> some View {
        if let attributed = try? AttributedString(markdown: text) {
            Text(attributed)
                .font(.body)
        } else {
            Text(text)
                .font(.body)
        }
    }
}

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

                Picker("카테고리", selection: $category) {
                    ForEach(WikiCategory.allCases, id: \.self) { cat in
                        Label(cat.rawValue, systemImage: cat.icon)
                            .tag(cat)
                    }
                }

                TextField("태그 (쉼표로 구분)", text: $tags)

                Section("내용") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
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
                        tags: tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
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

#Preview {
    WikiView()
        .environmentObject(CompanyStore())
}
