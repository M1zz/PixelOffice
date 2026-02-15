import Foundation

/// 코드 분석 서비스
/// 파이프라인 실행 전 기존 코드 구조를 분석하여 영향 범위 파악
class CodeAnalyzer {
    static let shared = CodeAnalyzer()
    
    private init() {}
    
    // MARK: - Analysis Result
    
    struct AnalysisResult {
        let projectPath: String
        let requirement: String
        let relevantFiles: [RelevantFile]
        let suggestedApproach: String
        let potentialImpact: [String]
        let existingPatterns: [String]
        
        struct RelevantFile {
            let path: String
            let relevance: Relevance
            let reason: String
            let lineCount: Int
            let keyElements: [String]  // 주요 struct, class, func 이름
            
            enum Relevance: String {
                case high = "높음"
                case medium = "중간"
                case low = "낮음"
            }
        }
        
        /// AI 프롬프트용 요약
        var summaryForAI: String {
            var summary = """
            ## 📊 코드 분석 결과
            
            ### 요구사항
            \(requirement)
            
            ### 관련 파일 (\(relevantFiles.count)개)
            
            """
            
            for file in relevantFiles.prefix(10) {
                summary += """
                #### `\(file.path)` (관련도: \(file.relevance.rawValue), \(file.lineCount)줄)
                - **이유**: \(file.reason)
                - **주요 요소**: \(file.keyElements.prefix(5).joined(separator: ", "))
                
                """
            }
            
            summary += """
            
            ### 권장 접근 방식
            \(suggestedApproach)
            
            ### 잠재적 영향
            \(potentialImpact.map { "- \($0)" }.joined(separator: "\n"))
            
            ### 기존 코드 패턴
            \(existingPatterns.map { "- \($0)" }.joined(separator: "\n"))
            """
            
            return summary
        }
    }
    
    // MARK: - Analyze
    
    /// 요구사항에 따라 코드 분석
    func analyze(requirement: String, projectPath: String) async -> AnalysisResult {
        // 1. 프로젝트 구조 스캔
        let scanner = ProjectScanner.shared
        let scanResult = await scanner.scan(projectPath: projectPath)
        
        // 2. 요구사항에서 키워드 추출
        let keywords = extractKeywords(from: requirement)
        
        // 3. 관련 파일 찾기
        var relevantFiles: [AnalysisResult.RelevantFile] = []
        
        if let structure = scanResult?.structure {
            for file in structure.swiftFiles {
                let fullPath = (projectPath as NSString).appendingPathComponent(file)
                if let fileInfo = analyzeFile(at: fullPath, keywords: keywords, requirement: requirement) {
                    relevantFiles.append(fileInfo)
                }
            }
        }
        
        // 관련도 순으로 정렬
        relevantFiles.sort { file1, file2 in
            let order: [AnalysisResult.RelevantFile.Relevance] = [.high, .medium, .low]
            let idx1 = order.firstIndex(of: file1.relevance) ?? 2
            let idx2 = order.firstIndex(of: file2.relevance) ?? 2
            return idx1 < idx2
        }
        
        // 4. 접근 방식 제안
        let suggestedApproach = generateApproach(
            requirement: requirement,
            relevantFiles: relevantFiles,
            scanResult: scanResult
        )
        
        // 5. 잠재적 영향 분석
        let potentialImpact = analyzePotentialImpact(
            requirement: requirement,
            relevantFiles: relevantFiles
        )
        
        // 6. 기존 패턴 분석
        let existingPatterns = analyzeExistingPatterns(
            projectPath: projectPath,
            scanResult: scanResult
        )
        
        return AnalysisResult(
            projectPath: projectPath,
            requirement: requirement,
            relevantFiles: Array(relevantFiles.prefix(15)),  // 최대 15개
            suggestedApproach: suggestedApproach,
            potentialImpact: potentialImpact,
            existingPatterns: existingPatterns
        )
    }
    
    // MARK: - Keyword Extraction
    
    private func extractKeywords(from requirement: String) -> [String] {
        var keywords: [String] = []
        
        // UI 관련 키워드
        let uiKeywords = ["버튼", "화면", "뷰", "view", "button", "label", "text", "image", "색", "색상", "color", "배경", "background", "레이아웃", "layout", "폰트", "font", "크기", "size", "애니메이션", "animation"]
        
        // 데이터 관련 키워드
        let dataKeywords = ["저장", "로드", "데이터", "모델", "model", "save", "load", "fetch", "api", "네트워크", "network", "데이터베이스", "database", "캐시", "cache"]
        
        // 기능 관련 키워드
        let featureKeywords = ["추가", "삭제", "수정", "변경", "업데이트", "add", "delete", "update", "edit", "remove", "create", "만들", "생성"]
        
        // 네비게이션 관련
        let navKeywords = ["네비게이션", "화면전환", "navigation", "push", "pop", "sheet", "modal", "present"]
        
        let allKeywords = uiKeywords + dataKeywords + featureKeywords + navKeywords
        let lowerRequirement = requirement.lowercased()
        
        for keyword in allKeywords {
            if lowerRequirement.contains(keyword.lowercased()) {
                keywords.append(keyword)
            }
        }
        
        // 요구사항에서 영어 단어 추출 (CamelCase 가능성)
        let englishWords = requirement.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && $0.range(of: "[a-zA-Z]", options: .regularExpression) != nil }
        keywords.append(contentsOf: englishWords)
        
        return Array(Set(keywords))  // 중복 제거
    }
    
    // MARK: - File Analysis
    
    private func analyzeFile(at path: String, keywords: [String], requirement: String) -> AnalysisResult.RelevantFile? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        
        let fileName = (path as NSString).lastPathComponent
        let lowerContent = content.lowercased()
        let lowerFileName = fileName.lowercased()
        let lines = content.components(separatedBy: "\n")
        
        // 키워드 매칭 점수
        var score = 0
        var matchedKeywords: [String] = []
        
        for keyword in keywords {
            if lowerContent.contains(keyword.lowercased()) {
                score += 2
                matchedKeywords.append(keyword)
            }
            if lowerFileName.contains(keyword.lowercased()) {
                score += 3  // 파일명 매칭은 더 높은 점수
                matchedKeywords.append(keyword + "(파일명)")
            }
        }
        
        // UI 관련 요구사항이면 View 파일 우선
        let isUIRelated = keywords.contains(where: { ["뷰", "view", "화면", "색", "버튼", "배경"].contains($0.lowercased()) })
        if isUIRelated && (lowerFileName.contains("view") || content.contains("import SwiftUI")) {
            score += 5
        }
        
        // ContentView, MainView 등 주요 파일 가산점
        if ["contentview", "mainview", "appdelegate", "app.swift"].contains(where: { lowerFileName.contains($0) }) {
            score += 3
        }
        
        // 점수가 너무 낮으면 제외
        guard score >= 2 else { return nil }
        
        // 주요 요소 추출
        let keyElements = extractKeyElements(from: content)
        
        // 관련도 결정
        let relevance: AnalysisResult.RelevantFile.Relevance
        if score >= 8 {
            relevance = .high
        } else if score >= 4 {
            relevance = .medium
        } else {
            relevance = .low
        }
        
        // 이유 생성
        let reason = matchedKeywords.isEmpty ?
            "프로젝트 구조상 관련 가능성" :
            "키워드 매칭: \(matchedKeywords.prefix(3).joined(separator: ", "))"
        
        // 상대 경로로 변환
        let relativePath = path.components(separatedBy: "/").suffix(3).joined(separator: "/")
        
        return AnalysisResult.RelevantFile(
            path: relativePath,
            relevance: relevance,
            reason: reason,
            lineCount: lines.count,
            keyElements: keyElements
        )
    }
    
    private func extractKeyElements(from content: String) -> [String] {
        var elements: [String] = []
        
        // struct, class, enum, func 추출
        let patterns = [
            "struct\\s+(\\w+)",
            "class\\s+(\\w+)",
            "enum\\s+(\\w+)",
            "func\\s+(\\w+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(content.startIndex..., in: content)
                let matches = regex.matches(in: content, options: [], range: range)
                
                for match in matches.prefix(5) {
                    if let nameRange = Range(match.range(at: 1), in: content) {
                        elements.append(String(content[nameRange]))
                    }
                }
            }
        }
        
        return Array(Set(elements)).prefix(10).map { String($0) }
    }
    
    // MARK: - Approach Generation
    
    private func generateApproach(
        requirement: String,
        relevantFiles: [AnalysisResult.RelevantFile],
        scanResult: ProjectScanner.ScanResult?
    ) -> String {
        let lowerReq = requirement.lowercased()
        
        // UI 변경
        if lowerReq.contains("색") || lowerReq.contains("color") || lowerReq.contains("배경") {
            let viewFiles = relevantFiles.filter { $0.path.lowercased().contains("view") }
            if let mainView = viewFiles.first {
                return """
                1. `\(mainView.path)` 파일을 수정하여 색상 변경
                2. SwiftUI의 `.background()` 또는 `.foregroundColor()` modifier 사용
                3. 다크모드 지원이 필요하면 `Color` asset 또는 `@Environment(\\.colorScheme)` 활용
                """
            }
        }
        
        // 기능 추가
        if lowerReq.contains("추가") || lowerReq.contains("만들") || lowerReq.contains("생성") {
            return """
            1. 관련 Model 파일에 데이터 구조 정의
            2. View 파일에 UI 컴포넌트 추가
            3. 필요시 Service/Store에 비즈니스 로직 추가
            4. 기존 패턴과 일관성 유지
            """
        }
        
        // 버그 수정
        if lowerReq.contains("수정") || lowerReq.contains("고쳐") || lowerReq.contains("fix") {
            return """
            1. 관련 파일에서 문제 영역 식별
            2. 기존 로직 분석 후 수정
            3. 사이드 이펙트 확인
            4. 빌드 및 테스트
            """
        }
        
        // 기본
        return """
        1. 관련 파일 분석 (위 목록 참조)
        2. 기존 코드 패턴 파악
        3. 최소한의 변경으로 요구사항 구현
        4. 빌드 및 검증
        """
    }
    
    // MARK: - Impact Analysis
    
    private func analyzePotentialImpact(
        requirement: String,
        relevantFiles: [AnalysisResult.RelevantFile]
    ) -> [String] {
        var impacts: [String] = []
        
        // 고관련도 파일이 많으면 영향 범위 넓음
        let highRelevanceCount = relevantFiles.filter { $0.relevance == .high }.count
        if highRelevanceCount > 3 {
            impacts.append("⚠️ 여러 파일에 영향을 줄 수 있음 (\(highRelevanceCount)개 고관련 파일)")
        }
        
        // 큰 파일 수정 경고
        let largeFiles = relevantFiles.filter { $0.lineCount > 500 }
        if !largeFiles.isEmpty {
            impacts.append("⚠️ 대형 파일 수정 필요: \(largeFiles.map { $0.path }.joined(separator: ", "))")
        }
        
        // UI 변경 시 다크모드 고려
        let uiKeywordsForDarkMode = ["색", "color", "배경"]
        if uiKeywordsForDarkMode.contains(where: { requirement.lowercased().contains($0) }) {
            impacts.append("💡 다크모드 지원 확인 필요")
        }
        
        // 데이터 모델 변경 시 마이그레이션 고려
        let dataKeywords = ["모델", "데이터", "저장"]
        if dataKeywords.contains(where: { requirement.lowercased().contains($0) }) {
            impacts.append("💡 데이터 마이그레이션 필요 여부 확인")
        }
        
        if impacts.isEmpty {
            impacts.append("✅ 영향 범위 제한적 (단일 파일 수정 예상)")
        }
        
        return impacts
    }
    
    // MARK: - Pattern Analysis
    
    private func analyzeExistingPatterns(
        projectPath: String,
        scanResult: ProjectScanner.ScanResult?
    ) -> [String] {
        var patterns: [String] = []
        
        guard let structure = scanResult?.structure else {
            return ["프로젝트 구조 분석 필요"]
        }
        
        // 아키텍처 패턴 추론
        if !structure.viewFiles.isEmpty && !structure.modelFiles.isEmpty {
            if !structure.serviceFiles.isEmpty {
                patterns.append("MVVM 또는 Clean Architecture 패턴 사용 중")
            } else {
                patterns.append("MV 패턴 사용 중 (View + Model)")
            }
        }
        
        // SwiftUI vs UIKit
        if let framework = scanResult?.framework {
            patterns.append("\(framework) 기반 프로젝트")
        }
        
        // 파일 네이밍 컨벤션
        let hasViewSuffix = structure.viewFiles.contains { $0.hasSuffix("View.swift") }
        let hasModelSuffix = structure.modelFiles.contains { $0.hasSuffix("Model.swift") }
        if hasViewSuffix || hasModelSuffix {
            patterns.append("파일명 접미사 컨벤션 사용 (예: *View.swift, *Model.swift)")
        }
        
        // 폴더 구조
        if structure.directories.contains(where: { $0.contains("Views") || $0.contains("View") }) {
            patterns.append("Views 폴더에 View 파일 분리")
        }
        if structure.directories.contains(where: { $0.contains("Models") || $0.contains("Model") }) {
            patterns.append("Models 폴더에 Model 파일 분리")
        }
        
        return patterns.isEmpty ? ["별도 패턴 미탐지"] : patterns
    }
}
