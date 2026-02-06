import SwiftUI

/// 프로젝트별 위키 화면
struct ProjectWikiView: View {
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @State private var selectedDocument: WikiDocument?
    @State private var showingNewDocument = false
    @State private var documents: [WikiDocument] = []
    @State private var searchText = ""
    @State private var selectedDepartment: String? = nil
    @State private var sortOption: ProjectWikiSortOption = .newest

    enum ProjectWikiSortOption: String, CaseIterable {
        case newest = "최신순"
        case oldest = "오래된순"
        case title = "제목순"
        case department = "부서별"
    }

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    var wikiPath: String {
        guard let project = project else { return "" }
        return DataPathService.shared.projectWikiPath(project.name)
    }

    /// 필터링 및 정렬된 문서
    var filteredDocuments: [WikiDocument] {
        var docs = documents

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
        Array(Set(documents.map { $0.createdBy })).sorted()
    }

    var body: some View {
        if let project = project {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // 게시판 형태의 문서 목록 (50%)
                    VStack(spacing: 0) {
                        // 상단 필터 & 검색
                        ProjectWikiFilterBar(
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
                            ProjectWikiEmptyView(hasDocuments: !documents.isEmpty)
                        } else {
                            ProjectWikiTableView(
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
                        .frame(width: geometry.size.width / 2)
                    } else {
                        ProjectWikiPlaceholderView(
                            projectName: project.name,
                            onCreateDocument: { showingNewDocument = true },
                            onOpenFolder: { WikiService.shared.openWikiInFinder(at: wikiPath) }
                        )
                        .frame(width: geometry.size.width / 2)
                    }
                }
            }
            .navigationTitle("\(project.name) 위키")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        initializeProjectWiki()
                    } label: {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }

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
        guard let project = project else { return }

        // 위키 폴더 초기화
        if !FileManager.default.fileExists(atPath: wikiPath) {
            try? WikiService.shared.initializeWiki(at: wikiPath)
        }

        // 프로젝트 README 생성 (없으면)
        createProjectWikiReadme()

        // 프로젝트 전체 디렉토리에서 .md, .html 파일 스캔 (people 폴더 제외)
        let projectPath = DataPathService.shared.projectPath(project.name)
        documents = WikiService.shared.scanProjectDirectory(at: projectPath, projectName: project.name)

        print("📊 [ProjectWikiView] \(project.name) 프로젝트 문서 스캔 완료: \(documents.count)개")
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

// MARK: - 프로젝트 위키 필터 바
struct ProjectWikiFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedDepartment: String?
    @Binding var sortOption: ProjectWikiView.ProjectWikiSortOption
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
                    ForEach(ProjectWikiView.ProjectWikiSortOption.allCases, id: \.self) { option in
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

// MARK: - 프로젝트 위키 테이블 뷰
struct ProjectWikiTableView: View {
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

    /// 시간 포맷 (초 단위까지)
    func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm:ss"
        return formatter.string(from: date)
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
                    Text("직원")
                        .frame(width: 120, alignment: .leading)
                    Text("수정일시")
                        .frame(width: 110, alignment: .leading)
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
                                Image(systemName: doc.category.icon)
                                    .foregroundStyle(.blue)
                                    .frame(width: 18)
                                    .font(.body)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(doc.title)
                                        .lineLimit(1)
                                        .font(.body)
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

                            // 직원명 (태그에서)
                            if let authorTag = doc.tags.first {
                                Text(authorTag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.1))
                                    .foregroundStyle(.secondary)
                                    .cornerRadius(8)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                            } else {
                                Text("-")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 120, alignment: .leading)
                            }

                            // 수정일시 (초 단위까지)
                            Text(formatDateTime(doc.updatedAt))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 110, alignment: .leading)
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

// MARK: - 프로젝트 위키 빈 상태 뷰
struct ProjectWikiEmptyView: View {
    let hasDocuments: Bool

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
