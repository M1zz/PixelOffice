import Foundation

/// 위키 문서 관리 담당 도메인 Store
@MainActor
final class WikiStore {

    // MARK: - Properties

    unowned let coordinator: StoreCoordinator

    // MARK: - Init

    init(coordinator: StoreCoordinator) {
        self.coordinator = coordinator
    }

    // MARK: - 위키 문서 CRUD

    /// 위키 문서 추가
    func addWikiDocument(_ document: WikiDocument) {
        coordinator.company.wikiDocuments.append(document)
    }

    /// 위키 문서 제거
    func removeWikiDocument(_ documentId: UUID) {
        coordinator.company.wikiDocuments.removeAll { $0.id == documentId }
    }

    /// 모든 위키 문서 삭제
    func clearAllWikiDocuments() {
        coordinator.company.wikiDocuments.removeAll()
        coordinator.saveCompany()
    }

    /// 위키 문서 업데이트
    func updateWikiDocument(_ document: WikiDocument) {
        if let index = coordinator.company.wikiDocuments.firstIndex(where: { $0.id == document.id }) {
            coordinator.company.wikiDocuments[index] = document
        }
    }

    /// 위키 경로 업데이트
    func updateWikiPath(_ path: String) {
        if coordinator.company.settings.wikiSettings == nil {
            coordinator.company.settings.wikiSettings = WikiSettings()
        }
        coordinator.company.settings.wikiSettings?.wikiPath = path
    }

    // MARK: - 위키 파일 동기화

    /// 위키 문서를 부서별 documents 폴더에 동기화
    func syncWikiDocumentsToFiles() {
        for document in coordinator.company.wikiDocuments {
            // 부서 타입 추출 (tags에서)
            var departmentType: DepartmentType = .general
            for tag in document.tags {
                if let deptType = DepartmentType(rawValue: tag) {
                    departmentType = deptType
                    break
                }
            }

            // 프로젝트명 추출 (tags에서 - 직원명과 부서명이 아닌 태그)
            let knownTags = Set(DepartmentType.allCases.map { $0.rawValue })
            let projectName = document.tags.first { tag in
                !knownTags.contains(tag) && tag != document.createdBy
            }

            // 저장 경로 결정
            let documentsPath: String
            if let projName = projectName {
                // 프로젝트별 부서 문서 폴더
                documentsPath = DataPathService.shared.documentsPath(projName, department: departmentType)
            } else {
                // 전사 공용 부서 문서 폴더
                let basePath = DataPathService.shared.basePath
                documentsPath = "\(basePath)/_shared/\(departmentType.directoryName)/documents"
                DataPathService.shared.createDirectoryIfNeeded(at: documentsPath)
            }

            // 파일 저장
            let filePath = (documentsPath as NSString).appendingPathComponent(document.fileName)
            try? document.content.write(toFile: filePath, atomically: true, encoding: .utf8)
        }
    }
}
