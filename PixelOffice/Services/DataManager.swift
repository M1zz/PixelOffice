import Foundation

class DataManager {
    private let fileManager = FileManager.default
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PixelOffice", isDirectory: true)
    }
    
    private var companyFileURL: URL {
        documentsDirectory.appendingPathComponent("company.json")
    }
    
    init() {
        createDirectoryIfNeeded()
    }
    
    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: documentsDirectory.path) {
            try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Company Persistence
    
    func saveCompany(_ company: Company) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(company)
            try data.write(to: companyFileURL)
            print("✅ Company saved successfully")
        } catch {
            print("❌ Failed to save company: \(error)")
        }
    }
    
    func loadCompany() -> Company? {
        guard fileManager.fileExists(atPath: companyFileURL.path) else {
            print("📁 No saved company found, creating new one")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: companyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let company = try decoder.decode(Company.self, from: data)
            print("✅ Company loaded successfully")
            return company
        } catch {
            print("❌ Failed to load company: \(error)")
            return nil
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
        let backupDirectory = documentsDirectory.appendingPathComponent("Backups", isDirectory: true)
        
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
        let backupDirectory = documentsDirectory.appendingPathComponent("Backups", isDirectory: true)
        
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
