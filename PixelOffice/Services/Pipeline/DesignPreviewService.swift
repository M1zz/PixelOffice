import Foundation

/// 디자인 HTML 자동 생성 서비스
/// - SwiftUI 코드를 분석하여 HTML 목업 생성
/// - 또는 디자인팀 AI에게 HTML 생성 요청
class DesignPreviewService {
    static let shared = DesignPreviewService()
    
    private init() {}
    
    // MARK: - HTML Generation
    
    /// SwiftUI 뷰 코드를 분석하여 HTML 목업 생성
    func generateHTMLPreview(
        from swiftCode: String,
        viewName: String,
        projectName: String
    ) async throws -> String {
        let claudeService = ClaudeCodeService()
        
        let prompt = """
        다음 SwiftUI 코드를 분석하여 HTML/CSS 목업을 생성해주세요.
        
        요구사항:
        1. SwiftUI 레이아웃을 최대한 비슷하게 HTML로 재현
        2. 모던한 CSS 사용 (flexbox, grid, CSS variables)
        3. 다크모드 지원 (prefers-color-scheme)
        4. 모바일 반응형 디자인
        5. 애니메이션은 CSS transition으로 표현
        
        SwiftUI 코드:
        ```swift
        \(swiftCode)
        ```
        
        HTML만 출력하세요. 설명 없이 <!DOCTYPE html>부터 시작하세요.
        """
        
        let systemPrompt = """
        당신은 UI/UX 디자이너입니다. SwiftUI 코드를 분석하여 동일한 디자인의 HTML 목업을 생성합니다.
        Apple Human Interface Guidelines를 따르는 깔끔한 디자인을 만듭니다.
        응답은 오직 HTML 코드만 포함해야 합니다.
        """
        
        let response = try await claudeService.sendMessage(prompt, systemPrompt: systemPrompt, autoApprove: true)
        
        // HTML 추출 (코드 블록에서)
        let html = extractHTML(from: response)
        
        // 저장
        if !html.isEmpty {
            try savePreview(html: html, viewName: viewName, projectName: projectName)
        }
        
        return html
    }
    
    /// 요구사항에서 직접 HTML 목업 생성
    func generateHTMLFromRequirement(
        requirement: String,
        projectName: String
    ) async throws -> String {
        let claudeService = ClaudeCodeService()
        
        let prompt = """
        다음 요구사항을 바탕으로 UI 목업을 HTML/CSS로 만들어주세요.
        
        요구사항:
        \(requirement)
        
        디자인 가이드라인:
        1. Apple Human Interface Guidelines 스타일
        2. 깔끔하고 미니멀한 디자인
        3. 적절한 여백과 타이포그래피
        4. 다크모드 지원
        5. 모바일 반응형
        
        HTML만 출력하세요. 설명 없이 <!DOCTYPE html>부터 시작하세요.
        """
        
        let systemPrompt = """
        당신은 시니어 UI/UX 디자이너입니다.
        요구사항을 분석하여 직관적이고 사용하기 쉬운 UI를 HTML로 프로토타이핑합니다.
        응답은 오직 HTML 코드만 포함해야 합니다.
        """
        
        let response = try await claudeService.sendMessage(prompt, systemPrompt: systemPrompt, autoApprove: true)
        let html = extractHTML(from: response)
        
        if !html.isEmpty {
            let timestamp = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
            try savePreview(html: html, viewName: "mockup-\(timestamp)", projectName: projectName)
        }
        
        return html
    }
    
    // MARK: - Screenshot Capture
    
    /// SwiftUI Preview 스크린샷 캡처 (Xcode 연동)
    func captureSwiftUIPreview(
        projectPath: String,
        viewName: String
    ) async throws -> String? {
        // xcodebuild로 Preview 캡처 시도
        // 현재는 구현 어려움 - 향후 Xcode 연동으로 구현
        return nil
    }
    
    // MARK: - File Operations
    
    /// HTML 프리뷰 저장
    private func savePreview(html: String, viewName: String, projectName: String) throws {
        let basePath = DataPathService.shared.basePath
        let previewDir = "\(basePath)/\(projectName)/디자인/previews"
        
        try FileManager.default.createDirectory(atPath: previewDir, withIntermediateDirectories: true)
        
        let filename = "\(viewName).html"
        let filePath = "\(previewDir)/\(filename)"
        
        try html.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("[DesignPreviewService] 프리뷰 저장됨: \(filePath)")
    }
    
    /// 프로젝트의 모든 프리뷰 목록
    func listPreviews(for projectName: String) -> [DesignPreviewItem] {
        let basePath = DataPathService.shared.basePath
        let previewDir = "\(basePath)/\(projectName)/디자인/previews"
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: previewDir) else {
            return []
        }
        
        return files
            .filter { $0.hasSuffix(".html") }
            .compactMap { filename -> DesignPreviewItem? in
                let path = "\(previewDir)/\(filename)"
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                      let modDate = attrs[.modificationDate] as? Date else {
                    return nil
                }
                
                return DesignPreviewItem(
                    name: (filename as NSString).deletingPathExtension,
                    path: path,
                    modifiedAt: modDate
                )
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    // MARK: - Helpers
    
    private func extractHTML(from response: String) -> String {
        // HTML 코드 블록 추출
        if let htmlStart = response.range(of: "```html"),
           let htmlEnd = response.range(of: "```", range: htmlStart.upperBound..<response.endIndex) {
            return String(response[htmlStart.upperBound..<htmlEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // <!DOCTYPE html>로 시작하면 전체가 HTML
        if response.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<!DOCTYPE") ||
           response.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<html") {
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return ""
    }
}

// MARK: - Models

struct DesignPreviewItem: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let modifiedAt: Date
}
