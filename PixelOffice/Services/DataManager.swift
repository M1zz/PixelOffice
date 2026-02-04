import Foundation

class DataManager {
    private let fileManager = FileManager.default

    /// 프로젝트 디렉토리 내 데이터 저장 경로
    private var projectDataDirectory: URL {
        let basePath = DataPathService.shared.basePath
        return URL(fileURLWithPath: basePath)
    }

    /// iCloud 저장 경로 (datas 폴더 전체)
    private var iCloudDatasDirectory: URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("PixelOffice")
            .appendingPathComponent("datas")
    }

    /// 프로젝트 내 company.json 경로
    private var companyFileURL: URL {
        projectDataDirectory.appendingPathComponent("company.json")
    }

    /// iCloud company.json 경로
    private var iCloudCompanyFileURL: URL? {
        iCloudDatasDirectory?.appendingPathComponent("company.json")
    }

    init() {
        createDirectoryIfNeeded()
    }

    private func createDirectoryIfNeeded() {
        // 프로젝트 디렉토리 생성
        if !fileManager.fileExists(atPath: projectDataDirectory.path) {
            try? fileManager.createDirectory(at: projectDataDirectory, withIntermediateDirectories: true)
        }

        // iCloud datas 디렉토리 생성
        if let iCloudDatasDir = iCloudDatasDirectory {
            if !fileManager.fileExists(atPath: iCloudDatasDir.path) {
                try? fileManager.createDirectory(at: iCloudDatasDir, withIntermediateDirectories: true)
            }
        }
    }
    
    // MARK: - Company Persistence
    
    func saveCompany(_ company: Company) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(company)

            // 1. 프로젝트 디렉토리에 저장
            try data.write(to: companyFileURL)
            print("✅ Company saved to project directory: \(companyFileURL.path)")

            // 2. iCloud에 전체 datas 폴더 동기화
            syncDatasToiCloud()
        } catch {
            print("❌ Failed to save company: \(error)")
        }
    }

    /// datas 폴더 전체를 iCloud에 동기화
    private func syncDatasToiCloud() {
        guard let iCloudDatasDir = iCloudDatasDirectory else {
            print("⚠️ iCloud not available")
            return
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            do {
                // iCloud datas 디렉토리가 없으면 생성
                if !self.fileManager.fileExists(atPath: iCloudDatasDir.path) {
                    try self.fileManager.createDirectory(at: iCloudDatasDir, withIntermediateDirectories: true)
                }

                // datas 폴더의 모든 파일/폴더 가져오기
                let datasContents = try self.fileManager.contentsOfDirectory(
                    at: self.projectDataDirectory,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )

                var syncedCount = 0
                var errorCount = 0

                for item in datasContents {
                    // Backups 폴더는 제외 (너무 커질 수 있음)
                    if item.lastPathComponent == "Backups" {
                        continue
                    }

                    let destinationURL = iCloudDatasDir.appendingPathComponent(item.lastPathComponent)

                    // 기존 파일/폴더가 있으면 삭제
                    if self.fileManager.fileExists(atPath: destinationURL.path) {
                        try? self.fileManager.removeItem(at: destinationURL)
                    }

                    // 복사
                    do {
                        try self.fileManager.copyItem(at: item, to: destinationURL)
                        syncedCount += 1
                    } catch {
                        print("⚠️ Failed to sync \(item.lastPathComponent): \(error.localizedDescription)")
                        errorCount += 1
                    }
                }

                DispatchQueue.main.async {
                    print("☁️ iCloud 동기화 완료: \(syncedCount)개 항목 백업됨" + (errorCount > 0 ? " (\(errorCount)개 실패)" : ""))
                }
            } catch {
                DispatchQueue.main.async {
                    print("⚠️ iCloud 동기화 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func loadCompany() -> Company? {
        // 1. 프로젝트 디렉토리에서 로드 시도
        print("🔍 Loading company from: \(companyFileURL.path)")
        if fileManager.fileExists(atPath: companyFileURL.path) {
            do {
                let data = try Data(contentsOf: companyFileURL)
                print("📊 File size: \(data.count) bytes")
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let company = try decoder.decode(Company.self, from: data)
                print("✅ Company loaded from project directory")
                print("👥 Departments: \(company.departments.count)")
                print("👥 Total employees: \(company.allEmployees.count)")
                for dept in company.departments {
                    print("   - \(dept.name): \(dept.employees.count)명")
                }
                return company
            } catch {
                print("⚠️ Failed to load from project directory: \(error)")
            }
        } else {
            print("⚠️ Company file does not exist at path")
        }

        // 2. iCloud에서 전체 복원 시도
        if let iCloudURL = iCloudCompanyFileURL,
           fileManager.fileExists(atPath: iCloudURL.path) {
            print("☁️ Company found in iCloud, restoring entire datas folder...")
            restoreDatasFromiCloud()

            // 복원 후 다시 로드
            if fileManager.fileExists(atPath: companyFileURL.path) {
                do {
                    let data = try Data(contentsOf: companyFileURL)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let company = try decoder.decode(Company.self, from: data)
                    print("✅ Company restored from iCloud")
                    return company
                } catch {
                    print("⚠️ Failed to decode restored company: \(error)")
                }
            }
        }

        print("📁 No saved company found, creating new one")
        return nil
    }

    /// iCloud에서 전체 datas 폴더 복원
    private func restoreDatasFromiCloud() {
        guard let iCloudDatasDir = iCloudDatasDirectory else {
            print("⚠️ iCloud not available")
            return
        }

        guard fileManager.fileExists(atPath: iCloudDatasDir.path) else {
            print("⚠️ iCloud datas folder not found")
            return
        }

        do {
            // iCloud datas 폴더의 모든 내용 가져오기
            let iCloudContents = try fileManager.contentsOfDirectory(
                at: iCloudDatasDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            var restoredCount = 0

            for item in iCloudContents {
                let destinationURL = projectDataDirectory.appendingPathComponent(item.lastPathComponent)

                // 기존 파일/폴더가 없을 때만 복사 (덮어쓰지 않음)
                if !fileManager.fileExists(atPath: destinationURL.path) {
                    do {
                        try fileManager.copyItem(at: item, to: destinationURL)
                        restoredCount += 1
                    } catch {
                        print("⚠️ Failed to restore \(item.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }

            print("✅ iCloud에서 \(restoredCount)개 항목 복원됨")
        } catch {
            print("⚠️ Failed to restore from iCloud: \(error.localizedDescription)")
        }
    }
    
    func deleteCompany() {
        try? fileManager.removeItem(at: companyFileURL)
        print("🗑️ Company data deleted")
    }
    
    // MARK: - Export/Import
    
    func exportCompany(_ company: Company) -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(company)
        } catch {
            print("❌ Failed to export company: \(error)")
            return nil
        }
    }
    
    func importCompany(from data: Data) -> Company? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Company.self, from: data)
        } catch {
            print("❌ Failed to import company: \(error)")
            return nil
        }
    }
    
    // MARK: - Backup

    func createBackup(_ company: Company) -> URL? {
        let backupDirectory = projectDataDirectory.appendingPathComponent("Backups", isDirectory: true)
        
        if !fileManager.fileExists(atPath: backupDirectory.path) {
            try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let backupURL = backupDirectory.appendingPathComponent("backup_\(timestamp).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(company)
            try data.write(to: backupURL)
            print("✅ Backup created: \(backupURL.lastPathComponent)")
            return backupURL
        } catch {
            print("❌ Failed to create backup: \(error)")
            return nil
        }
    }
    
    func listBackups() -> [URL] {
        let backupDirectory = projectDataDirectory.appendingPathComponent("Backups", isDirectory: true)
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }
        
        return contents.filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
    
    func restoreBackup(from url: URL) -> Company? {
        do {
            let data = try Data(contentsOf: url)
            return importCompany(from: data)
        } catch {
            print("❌ Failed to restore backup: \(error)")
            return nil
        }
    }
}
