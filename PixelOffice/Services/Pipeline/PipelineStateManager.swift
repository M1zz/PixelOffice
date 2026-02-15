import Foundation

/// 파이프라인 상태 영속화 및 복구 관리자
/// - 실시간 상태 저장 (태스크 단위)
/// - 파일 기반 로깅
/// - 중단된 파이프라인 복구
@MainActor
class PipelineStateManager: ObservableObject {
    static let shared = PipelineStateManager()
    
    // MARK: - Published
    
    /// 복구 가능한 중단된 파이프라인
    @Published var interruptedRuns: [PipelineRun] = []
    
    /// 복구 알림 표시 여부
    @Published var showRecoveryAlert: Bool = false
    
    // MARK: - Paths
    
    private var basePath: String {
        DataPathService.shared.basePath
    }
    
    /// 현재 진행 중인 파이프라인 상태 파일 (크래시 복구용)
    private var currentRunPath: String {
        "\(basePath)/_shared/pipeline_current.json"
    }
    
    /// 파이프라인 로그 디렉토리
    private var logDirectory: String {
        "\(basePath)/_logs/pipeline"
    }
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Current Run State (Crash Recovery)
    
    /// 파이프라인 시작 시 현재 상태 저장
    func markRunStarted(_ run: PipelineRun) {
        saveCurrentRun(run)
        log(run: run, level: .info, message: "🚀 파이프라인 시작: \(run.requirement.prefix(50))...")
    }
    
    /// 파이프라인 진행 중 상태 업데이트 (자주 호출)
    func updateRunState(_ run: PipelineRun, checkpoint: String? = nil) {
        saveCurrentRun(run)
        if let checkpoint = checkpoint {
            log(run: run, level: .debug, message: "💾 체크포인트: \(checkpoint)")
        }
    }
    
    /// 태스크 완료 시 상태 저장
    func markTaskCompleted(_ run: PipelineRun, task: DecomposedTask) {
        saveCurrentRun(run)
        log(run: run, level: .info, message: "✅ 태스크 완료: \(task.title)")
    }
    
    /// Phase 완료 시 상태 저장
    func markPhaseCompleted(_ run: PipelineRun, phase: PipelinePhase) {
        saveCurrentRun(run)
        log(run: run, level: .info, message: "🏁 Phase 완료: \(phase.name)")
    }
    
    /// 에러 발생 시 로깅
    func logError(_ run: PipelineRun, error: Error, context: String) {
        var updatedRun = run
        updatedRun.addLog("❌ 에러 [\(context)]: \(error.localizedDescription)", level: .error)
        saveCurrentRun(updatedRun)
        log(run: run, level: .error, message: "❌ 에러 [\(context)]: \(error.localizedDescription)")
        
        // 에러 스택 트레이스도 기록
        log(run: run, level: .debug, message: "   상세: \(String(describing: error))")
    }
    
    /// 파이프라인 정상 완료 시 현재 상태 파일 삭제
    func markRunCompleted(_ run: PipelineRun) {
        clearCurrentRun()
        log(run: run, level: .info, message: "🎉 파이프라인 완료: \(run.state.rawValue)")
    }
    
    /// 파이프라인 취소/실패 시
    func markRunFailed(_ run: PipelineRun, reason: String) {
        var updatedRun = run
        updatedRun.state = .failed
        saveCurrentRun(updatedRun)
        log(run: run, level: .error, message: "💥 파이프라인 실패: \(reason)")
    }
    
    // MARK: - Crash Recovery
    
    /// 앱 시작 시 중단된 파이프라인 확인
    func checkForInterruptedRuns() {
        // 1. 현재 진행 중이던 파이프라인 확인
        if let currentRun = loadCurrentRun() {
            // 앱이 비정상 종료되었다면 이 파일이 남아있음
            if currentRun.state.isActive {
                interruptedRuns.append(currentRun)
                log(run: currentRun, level: .warning, message: "⚠️ 중단된 파이프라인 발견 (앱 비정상 종료)")
            }
        }
        
        // 2. 히스토리에서 paused 상태인 것들도 확인
        // (이미 PipelineCoordinator에서 처리하므로 여기서는 current만)
        
        if !interruptedRuns.isEmpty {
            showRecoveryAlert = true
        }
    }
    
    /// 복구 알림 확인 (무시)
    func dismissRecoveryAlert() {
        showRecoveryAlert = false
    }
    
    /// 복구 알림 확인 후 정리
    func acknowledgeInterruptedRun(_ runId: UUID) {
        interruptedRuns.removeAll { $0.id == runId }
        if interruptedRuns.isEmpty {
            showRecoveryAlert = false
            clearCurrentRun()
        }
    }
    
    // MARK: - File Operations
    
    private func saveCurrentRun(_ run: PipelineRun) {
        do {
            var runToSave = run
            runToSave.lastSavedAt = Date()
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(runToSave)
            
            // 디렉토리 생성
            let directory = (currentRunPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            
            try data.write(to: URL(fileURLWithPath: currentRunPath))
        } catch {
            print("[PipelineStateManager] 상태 저장 실패: \(error)")
        }
    }
    
    private func loadCurrentRun() -> PipelineRun? {
        guard FileManager.default.fileExists(atPath: currentRunPath),
              let data = FileManager.default.contents(atPath: currentRunPath) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(PipelineRun.self, from: data)
        } catch {
            print("[PipelineStateManager] 상태 로드 실패: \(error)")
            return nil
        }
    }
    
    private func clearCurrentRun() {
        try? FileManager.default.removeItem(atPath: currentRunPath)
    }
    
    // MARK: - File Logging
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }
    
    /// 파일에 로그 기록
    func log(run: PipelineRun, level: LogLevel, message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] [\(level.rawValue)] [\(run.projectName)] \(message)\n"
        
        let logPath = logFilePath(for: run)
        
        do {
            // 디렉토리 생성
            try FileManager.default.createDirectory(atPath: logDirectory, withIntermediateDirectories: true)
            
            if FileManager.default.fileExists(atPath: logPath) {
                // 기존 파일에 추가
                let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: logPath))
                fileHandle.seekToEndOfFile()
                if let data = logLine.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                // 새 파일 생성
                try logLine.write(toFile: logPath, atomically: true, encoding: .utf8)
            }
        } catch {
            print("[PipelineStateManager] 로그 기록 실패: \(error)")
        }
    }
    
    private func logFilePath(for run: PipelineRun) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: run.createdAt)
        let runIdShort = String(run.id.uuidString.prefix(8))
        return "\(logDirectory)/\(dateStr)_\(run.projectName)_\(runIdShort).log"
    }
    
    /// 특정 파이프라인의 로그 파일 경로
    func getLogPath(for run: PipelineRun) -> String {
        return logFilePath(for: run)
    }
    
    /// 로그 파일 내용 읽기
    func readLogs(for run: PipelineRun) -> String? {
        let path = logFilePath(for: run)
        return try? String(contentsOfFile: path, encoding: .utf8)
    }
}
