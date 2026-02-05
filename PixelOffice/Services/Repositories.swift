import Foundation
import SwiftUI

// MARK: - Repository Protocol & Errors

/// 모든 Repository의 기본 프로토콜
protocol RepositoryProtocol {
    associatedtype Entity: Codable
    associatedtype ID: Hashable

    /// 엔티티 조회
    func get(id: ID) async throws -> Entity?

    /// 모든 엔티티 조회
    func getAll() async throws -> [Entity]

    /// 엔티티 저장
    func save(_ entity: Entity) async throws

    /// 엔티티 삭제
    func delete(id: ID) async throws
}

/// Repository 에러
enum RepositoryError: LocalizedError {
    case fileNotFound(path: String)
    case decodingFailed(String)
    case encodingFailed(String)
    case saveFailed(String)
    case deleteFailed(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "파일을 찾을 수 없습니다: \(path)"
        case .decodingFailed(let message):
            return "디코딩 실패: \(message)"
        case .encodingFailed(let message):
            return "인코딩 실패: \(message)"
        case .saveFailed(let message):
            return "저장 실패: \(message)"
        case .deleteFailed(let message):
            return "삭제 실패: \(message)"
        case .invalidData(let message):
            return "잘못된 데이터: \(message)"
        }
    }
}

// MARK: - File Repository (Thread-safe Actor)

/// Thread-safe 파일 기반 Repository (Actor)
/// 모든 파일 I/O를 안전하게 처리하며 캐싱 기능 제공
actor FileRepository<T: Codable & Identifiable> where T.ID: Hashable {
    // MARK: - Properties

    private let filePath: String
    private var cache: [T.ID: T] = [:]
    private var cacheTimestamp: Date?
    private let cacheExpiration: TimeInterval = 60 // 60초 캐시
    private let fileManager = FileManager.default

    // MARK: - Init

    init(filePath: String) {
        self.filePath = filePath
        print("📁 [FileRepository] Initialized: \(filePath)")
    }

    // MARK: - Cache Management

    /// 캐시가 유효한지 확인
    private func isCacheValid() -> Bool {
        guard let timestamp = cacheTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < cacheExpiration
    }

    /// 캐시 무효화
    func invalidateCache() {
        cache.removeAll()
        cacheTimestamp = nil
    }

    // MARK: - File I/O

    /// 파일에서 데이터 로드
    private func loadFromFile() throws -> [T] {
        // 캐시가 유효하면 캐시 사용
        if isCacheValid() {
            return Array(cache.values)
        }

        // 파일 존재 여부 확인
        guard fileManager.fileExists(atPath: filePath) else {
            return []
        }

        // 파일 읽기
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let entities = try JSONDecoder().decode([T].self, from: data)

            // 캐시 업데이트
            cache = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
            cacheTimestamp = Date()

            return entities
        } catch {
            throw RepositoryError.decodingFailed(error.localizedDescription)
        }
    }

    /// 파일에 데이터 저장
    private func saveToFile(_ entities: [T]) throws {
        do {
            // 디렉토리 생성
            let directory = (filePath as NSString).deletingLastPathComponent
            if !fileManager.fileExists(atPath: directory) {
                try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
            }

            // JSON 인코딩
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(entities)

            // 파일 쓰기
            try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)

            // 캐시 업데이트
            cache = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
            cacheTimestamp = Date()
        } catch {
            throw RepositoryError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - CRUD Operations

    /// 엔티티 조회
    func get(id: T.ID) throws -> T? {
        let entities = try loadFromFile()
        return entities.first { $0.id == id }
    }

    /// 모든 엔티티 조회
    func getAll() throws -> [T] {
        return try loadFromFile()
    }

    /// 엔티티 저장 (추가 또는 업데이트)
    func save(_ entity: T) throws {
        var entities = try loadFromFile()

        if let index = entities.firstIndex(where: { $0.id == entity.id }) {
            entities[index] = entity
        } else {
            entities.append(entity)
        }

        try saveToFile(entities)
    }

    /// 엔티티 삭제
    func delete(id: T.ID) throws {
        var entities = try loadFromFile()
        entities.removeAll { $0.id == id }
        try saveToFile(entities)
    }

    /// 조건에 맞는 엔티티 조회
    func find(where predicate: @Sendable (T) -> Bool) throws -> [T] {
        let entities = try loadFromFile()
        return entities.filter(predicate)
    }
}
