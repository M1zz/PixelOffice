import SwiftUI

/// 프로젝트별 위키 화면
struct ProjectWikiView: View {
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @State private var selectedDocument: WikiDocument?
    @State private var showingNewDocument = false
    @State private var documents: [WikiDocument] = []

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    var wikiPath: String {
        guard let project = project else { return "" }
        return DataPathService.shared.projectWikiPath(project.name)
    }

    var body: some View {
        if let project = project {
            HSplitView {
                // Sidebar - Documents
                ProjectWikiSidebar(
                    projectName: project.name,
                    documents: documents,
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
                            documents.removeAll { $0.id == document.id }
                            selectedDocument = nil
                        },
                        onUpdate: { updatedDoc in
                            if let index = documents.firstIndex(where: { $0.id == updatedDoc.id }) {
                                documents[index] = updatedDoc
                            }
                            try? WikiService.shared.saveDocument(updatedDoc, at: wikiPath)
                            selectedDocument = updatedDoc
                        }
                    )
                } else {
                    ProjectWikiPlaceholderView(
                        projectName: project.name,
                        onCreateDocument: { showingNewDocument = true },
                        onOpenFolder: { WikiService.shared.openWikiInFinder(at: wikiPath) }
                    )
                }
            }
            .navigationTitle("\(project.name) 위키")
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
                    documents.append(document)
                    try? WikiService.shared.saveDocument(document, at: wikiPath)
                    selectedDocument = document
                }
            }
            .onAppear {
                initializeProjectWiki()
            }
        } else {
            Text("프로젝트를 찾을 수 없습니다")
        }
    }

    private func initializeProjectWiki() {
        // 위키 폴더 초기화
        if !FileManager.default.fileExists(atPath: wikiPath) {
            try? WikiService.shared.initializeWiki(at: wikiPath)
        }

        // 프로젝트 README 생성 (없으면)
        createProjectWikiReadme()

        // 기존 .md 파일 스캔
        documents = WikiService.shared.scanExistingDocuments(at: wikiPath)
    }

    private func createProjectWikiReadme() {
        guard let project = project else { return }
        let readmePath = (wikiPath as NSString).appendingPathComponent("README.md")

        guard !FileManager.default.fileExists(atPath: readmePath) else { return }

        let content = """
        # \(project.name) 프로젝트 위키

        이 위키는 **\(project.name)** 프로젝트의 문서를 관리합니다.

        ## 프로젝트 정보

        - **상태**: \(project.status.rawValue)
        - **생성일**: \(project.createdAt.formatted(date: .abbreviated, time: .omitted))
        - **직원 수**: \(project.allEmployees.count)명

        ## 문서 카테고리

        - `company/` - 프로젝트 개요 및 목표
        - `projects/` - 기획 문서
        - `guidelines/` - 개발/디자인 가이드라인
        - `meetings/` - 회의록
        - `reference/` - 참고 자료

        ---
        *이 위키는 PixelOffice에서 자동 생성되었습니다.*
        """

        try? content.write(toFile: readmePath, atomically: true, encoding: .utf8)
    }
}

struct ProjectWikiSidebar: View {
    let projectName: String
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

struct ProjectWikiPlaceholderView: View {
    let projectName: String
    let onCreateDocument: () -> Void
    let onOpenFolder: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("\(projectName) 위키")
                    .font(.title2.bold())
                Text("프로젝트 문서가 마크다운으로 저장됩니다")
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

#Preview {
    ProjectWikiView(projectId: UUID())
        .environmentObject(CompanyStore())
}
