import Foundation

/// 마크다운을 HTML로 변환하는 유틸리티
/// - headings, bold, italic, strikethrough, code blocks, inline code
/// - tables, lists (ordered/unordered/nested), blockquotes, links, images
/// - horizontal rules, task lists (checkboxes)
struct MarkdownToHTMLConverter {
    
    // MARK: - Public API
    
    /// 마크다운 문자열을 완전한 HTML 문서로 변환
    static func convert(_ markdown: String) -> String {
        let bodyHTML = convertToBodyHTML(markdown)
        return wrapInHTMLTemplate(bodyHTML)
    }
    
    /// 마크다운 문자열을 HTML body 내용으로만 변환 (템플릿 없이)
    static func convertToBodyHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var html = ""
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            
            // 빈 줄
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                continue
            }
            
            // 코드 블록 (```)
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                let lang = line.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespaces)
                let langClass = lang.isEmpty ? "" : " class=\"language-\(escapeHTML(lang))\""
                let langLabel = lang.isEmpty ? "" : "<span class=\"code-lang\">\(escapeHTML(lang))</span>"
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(escapeHTML(lines[i]))
                    i += 1
                }
                if i < lines.count { i += 1 } // skip closing ```
                html += "<div class=\"code-block\">\(langLabel)<pre><code\(langClass)>\(codeLines.joined(separator: "\n"))</code></pre></div>\n"
                continue
            }
            
            // 테이블
            if line.contains("|") && line.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                var tableLines: [String] = []
                var j = i
                while j < lines.count && lines[j].contains("|") {
                    tableLines.append(lines[j])
                    j += 1
                }
                if tableLines.count >= 2 {
                    html += parseTable(tableLines)
                    i = j
                    continue
                }
            }
            
            // 순서 없는 리스트 (-, *, +)
            if let match = line.range(of: #"^(\s*)([-*+])\s+"#, options: .regularExpression) {
                var listItems: [(indent: Int, content: String)] = []
                var j = i
                while j < lines.count {
                    let l = lines[j]
                    if let m = l.range(of: #"^(\s*)([-*+])\s+(.*)$"#, options: .regularExpression) {
                        let spaces = l.prefix(while: { $0 == " " || $0 == "\t" }).count
                        let content = String(l[m]).replacingOccurrences(of: #"^\s*[-*+]\s+"#, with: "", options: .regularExpression)
                        listItems.append((indent: spaces, content: content))
                        j += 1
                    } else if j > i && !l.trimmingCharacters(in: .whitespaces).isEmpty && !l.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                        // 이어지는 줄 (들여쓰기가 있는 경우)
                        if l.hasPrefix("  ") || l.hasPrefix("\t") {
                            if !listItems.isEmpty {
                                listItems[listItems.count - 1].content += " " + l.trimmingCharacters(in: .whitespaces)
                            }
                            j += 1
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }
                html += buildNestedList(listItems, ordered: false)
                i = j
                continue
            }
            
            // 순서 있는 리스트
            if line.range(of: #"^\s*\d+[.)]\s+"#, options: .regularExpression) != nil {
                var listItems: [(indent: Int, content: String)] = []
                var j = i
                while j < lines.count {
                    let l = lines[j]
                    if l.range(of: #"^\s*\d+[.)]\s+(.*)$"#, options: .regularExpression) != nil {
                        let spaces = l.prefix(while: { $0 == " " || $0 == "\t" }).count
                        let content = l.replacingOccurrences(of: #"^\s*\d+[.)]\s+"#, with: "", options: .regularExpression)
                        listItems.append((indent: spaces, content: content))
                        j += 1
                    } else if j > i && !l.trimmingCharacters(in: .whitespaces).isEmpty {
                        if l.hasPrefix("  ") || l.hasPrefix("\t") {
                            if !listItems.isEmpty {
                                listItems[listItems.count - 1].content += " " + l.trimmingCharacters(in: .whitespaces)
                            }
                            j += 1
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }
                html += buildNestedList(listItems, ordered: true)
                i = j
                continue
            }
            
            // Blockquote
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("> ") || line.trimmingCharacters(in: .whitespaces) == ">" {
                var quoteLines: [String] = []
                var j = i
                while j < lines.count {
                    let l = lines[j].trimmingCharacters(in: .whitespaces)
                    if l.hasPrefix("> ") {
                        quoteLines.append(String(l.dropFirst(2)))
                        j += 1
                    } else if l == ">" {
                        quoteLines.append("")
                        j += 1
                    } else {
                        break
                    }
                }
                let innerHTML = convertToBodyHTML(quoteLines.joined(separator: "\n"))
                html += "<blockquote>\(innerHTML)</blockquote>\n"
                i = j
                continue
            }
            
            // Headings
            if let headingMatch = line.range(of: #"^(#{1,6})\s+(.+)$"#, options: .regularExpression) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let text = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                html += "<h\(level)>\(processInline(text))</h\(level)>\n"
                i += 1
                continue
            }
            
            // Horizontal rule
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.count >= 3 &&
                (trimmedLine.allSatisfy({ $0 == "-" || $0 == " " }) && trimmedLine.filter({ $0 == "-" }).count >= 3 ||
                 trimmedLine.allSatisfy({ $0 == "*" || $0 == " " }) && trimmedLine.filter({ $0 == "*" }).count >= 3 ||
                 trimmedLine.allSatisfy({ $0 == "_" || $0 == " " }) && trimmedLine.filter({ $0 == "_" }).count >= 3) {
                html += "<hr>\n"
                i += 1
                continue
            }
            
            // 일반 문단 (연속된 텍스트를 하나의 <p>로)
            var paragraphLines: [String] = []
            var j = i
            while j < lines.count {
                let l = lines[j]
                let t = l.trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("#") || t.hasPrefix("```") || t.hasPrefix("> ") ||
                   t.hasPrefix("---") || t.hasPrefix("***") || t.hasPrefix("___") ||
                   (t.hasPrefix("|") && t.contains("|")) ||
                   t.range(of: #"^[-*+]\s+"#, options: .regularExpression) != nil ||
                   t.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) != nil {
                    if j == i {
                        // 만약 첫 줄이 이 조건이면 그냥 넘어감 (위 로직에서 못 잡은 경우)
                        paragraphLines.append(l)
                        j += 1
                    }
                    break
                }
                paragraphLines.append(l)
                j += 1
            }
            
            if !paragraphLines.isEmpty {
                let text = paragraphLines.joined(separator: " ")
                html += "<p>\(processInline(text))</p>\n"
                i = j
            } else {
                i += 1
            }
        }
        
        return html
    }
    
    // MARK: - Inline Processing
    
    /// 인라인 마크다운 처리 (bold, italic, code, links, images, strikethrough, task lists)
    static func processInline(_ text: String) -> String {
        var result = escapeHTML(text)
        
        // 이미지: ![alt](url)
        result = result.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^)]+)\)"#,
            with: "<img src=\"$2\" alt=\"$1\" loading=\"lazy\">",
            options: .regularExpression
        )
        
        // 링크: [text](url)
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#,
            with: "<a href=\"$2\" target=\"_blank\">$1</a>",
            options: .regularExpression
        )
        
        // 인라인 코드: `code`
        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "<code>$1</code>",
            options: .regularExpression
        )
        
        // Bold + Italic: ***text*** or ___text___
        result = result.replacingOccurrences(
            of: #"\*\*\*(.+?)\*\*\*"#,
            with: "<strong><em>$1</em></strong>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"___(.+?)___"#,
            with: "<strong><em>$1</em></strong>",
            options: .regularExpression
        )
        
        // Bold: **text** or __text__
        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"__(.+?)__"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        
        // Italic: *text* or _text_
        result = result.replacingOccurrences(
            of: #"\*(.+?)\*"#,
            with: "<em>$1</em>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\b_(.+?)_\b"#,
            with: "<em>$1</em>",
            options: .regularExpression
        )
        
        // Strikethrough: ~~text~~
        result = result.replacingOccurrences(
            of: #"~~(.+?)~~"#,
            with: "<del>$1</del>",
            options: .regularExpression
        )
        
        // Task list checkboxes: - [x] or - [ ]
        result = result.replacingOccurrences(
            of: #"\[x\]"#,
            with: "<input type=\"checkbox\" checked disabled>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\[ \]"#,
            with: "<input type=\"checkbox\" disabled>",
            options: .regularExpression
        )
        
        // 줄바꿈 (trailing double space → <br>)
        result = result.replacingOccurrences(of: "  $", with: "<br>", options: .regularExpression)
        
        return result
    }
    
    // MARK: - Table Parsing
    
    static func parseTable(_ lines: [String]) -> String {
        guard lines.count >= 2 else { return "" }
        
        var html = "<div class=\"table-wrapper\"><table>\n"
        
        // Header
        let headerCells = parseTableRow(lines[0])
        html += "<thead><tr>\n"
        for cell in headerCells {
            html += "<th>\(processInline(cell))</th>\n"
        }
        html += "</tr></thead>\n"
        
        // Alignment row (skip it, but parse for alignment)
        var alignments: [String] = []
        if lines.count >= 2 {
            let alignRow = parseTableRow(lines[1])
            for cell in alignRow {
                let trimmed = cell.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix(":") && trimmed.hasSuffix(":") {
                    alignments.append("center")
                } else if trimmed.hasSuffix(":") {
                    alignments.append("right")
                } else if trimmed.hasPrefix(":") {
                    alignments.append("left")
                } else {
                    alignments.append("left")
                }
            }
        }
        
        // Body rows
        if lines.count > 2 {
            html += "<tbody>\n"
            for rowIdx in 2..<lines.count {
                let cells = parseTableRow(lines[rowIdx])
                html += "<tr>\n"
                for (cellIdx, cell) in cells.enumerated() {
                    let align = cellIdx < alignments.count ? alignments[cellIdx] : "left"
                    html += "<td style=\"text-align: \(align)\">\(processInline(cell))</td>\n"
                }
                html += "</tr>\n"
            }
            html += "</tbody>\n"
        }
        
        html += "</table></div>\n"
        return html
    }
    
    static func parseTableRow(_ line: String) -> [String] {
        var row = line.trimmingCharacters(in: .whitespaces)
        if row.hasPrefix("|") { row = String(row.dropFirst()) }
        if row.hasSuffix("|") { row = String(row.dropLast()) }
        return row.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }
    
    // MARK: - Nested List Builder
    
    static func buildNestedList(_ items: [(indent: Int, content: String)], ordered: Bool) -> String {
        let tag = ordered ? "ol" : "ul"
        var html = "<\(tag)>\n"
        
        for item in items {
            html += "<li>\(processInline(item.content))</li>\n"
        }
        
        html += "</\(tag)>\n"
        return html
    }
    
    // MARK: - HTML Escaping
    
    static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
    
    // MARK: - HTML Template
    
    /// HTML body를 완전한 HTML 문서로 래핑 (CSS 포함)
    static func wrapInHTMLTemplate(_ bodyHTML: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="ko">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        \(cssTemplate)
        </style>
        </head>
        <body>
        <article class="wiki-content">
        \(bodyHTML)
        </article>
        </body>
        </html>
        """
    }
    
    /// 위키 콘텐츠용 CSS 템플릿 — 다크모드, 한글 폰트, 코드 하이라이팅, 테이블 스타일
    static let cssTemplate: String = """
        :root {
            --bg: #ffffff;
            --fg: #1d1d1f;
            --fg-secondary: #6e6e73;
            --border: #d2d2d7;
            --code-bg: #f5f5f7;
            --code-fg: #1d1d1f;
            --link: #0066cc;
            --blockquote-border: #0066cc;
            --blockquote-bg: #f0f4ff;
            --table-header-bg: #f5f5f7;
            --table-border: #d2d2d7;
            --table-stripe: #fafafa;
            --hr-color: #d2d2d7;
            --selection-bg: #0066cc33;
            --code-lang-color: #86868b;
            --checkbox-accent: #0066cc;
        }

        @media (prefers-color-scheme: dark) {
            :root {
                --bg: #1d1d1f;
                --fg: #f5f5f7;
                --fg-secondary: #98989d;
                --border: #38383a;
                --code-bg: #2c2c2e;
                --code-fg: #f5f5f7;
                --link: #4da3ff;
                --blockquote-border: #4da3ff;
                --blockquote-bg: #1c2333;
                --table-header-bg: #2c2c2e;
                --table-border: #38383a;
                --table-stripe: #242426;
                --hr-color: #38383a;
                --selection-bg: #4da3ff33;
                --code-lang-color: #6e6e73;
                --checkbox-accent: #4da3ff;
            }
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", "Noto Sans KR", "Malgun Gothic", sans-serif;
            font-size: 14px;
            line-height: 1.7;
            color: var(--fg);
            background: var(--bg);
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale;
        }

        ::selection {
            background: var(--selection-bg);
        }

        .wiki-content {
            max-width: 800px;
            margin: 0 auto;
            padding: 24px 32px;
        }

        /* Headings */
        h1, h2, h3, h4, h5, h6 {
            font-weight: 700;
            line-height: 1.3;
            margin-top: 1.5em;
            margin-bottom: 0.5em;
            color: var(--fg);
        }

        h1 { font-size: 1.85em; border-bottom: 1px solid var(--border); padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid var(--border); padding-bottom: 0.25em; }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1.1em; }
        h5 { font-size: 1em; }
        h6 { font-size: 0.9em; color: var(--fg-secondary); }

        h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }

        /* Paragraphs */
        p {
            margin-bottom: 1em;
        }

        /* Links */
        a {
            color: var(--link);
            text-decoration: none;
            border-bottom: 1px solid transparent;
            transition: border-color 0.15s;
        }

        a:hover {
            border-bottom-color: var(--link);
        }

        /* Bold, Italic */
        strong { font-weight: 600; }
        em { font-style: italic; }
        del { text-decoration: line-through; color: var(--fg-secondary); }

        /* Inline Code */
        code {
            font-family: "SF Mono", "Fira Code", "JetBrains Mono", Menlo, Monaco, monospace;
            font-size: 0.88em;
            padding: 0.15em 0.4em;
            background: var(--code-bg);
            color: var(--code-fg);
            border-radius: 4px;
        }

        /* Code Blocks */
        .code-block {
            position: relative;
            margin: 1em 0;
        }

        .code-block .code-lang {
            position: absolute;
            top: 8px;
            right: 12px;
            font-size: 0.75em;
            color: var(--code-lang-color);
            font-family: -apple-system, sans-serif;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        pre {
            background: var(--code-bg);
            border-radius: 8px;
            padding: 16px 20px;
            overflow-x: auto;
            line-height: 1.5;
            -webkit-overflow-scrolling: touch;
        }

        pre code {
            background: transparent;
            padding: 0;
            font-size: 0.88em;
            border-radius: 0;
        }

        /* Blockquotes */
        blockquote {
            margin: 1em 0;
            padding: 12px 20px;
            border-left: 4px solid var(--blockquote-border);
            background: var(--blockquote-bg);
            border-radius: 0 8px 8px 0;
            color: var(--fg);
        }

        blockquote p {
            margin-bottom: 0.5em;
        }

        blockquote p:last-child {
            margin-bottom: 0;
        }

        /* Lists */
        ul, ol {
            margin: 0.5em 0;
            padding-left: 2em;
        }

        li {
            margin-bottom: 0.35em;
            line-height: 1.6;
        }

        li > ul, li > ol {
            margin-top: 0.25em;
            margin-bottom: 0;
        }

        /* Task Lists */
        input[type="checkbox"] {
            margin-right: 6px;
            accent-color: var(--checkbox-accent);
            transform: scale(1.1);
            vertical-align: middle;
        }

        /* Tables */
        .table-wrapper {
            margin: 1em 0;
            overflow-x: auto;
            -webkit-overflow-scrolling: touch;
            border-radius: 8px;
            border: 1px solid var(--table-border);
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.92em;
        }

        thead {
            background: var(--table-header-bg);
        }

        th {
            font-weight: 600;
            padding: 10px 14px;
            text-align: left;
            border-bottom: 2px solid var(--table-border);
        }

        td {
            padding: 8px 14px;
            border-bottom: 1px solid var(--table-border);
        }

        tbody tr:nth-child(even) {
            background: var(--table-stripe);
        }

        tbody tr:last-child td {
            border-bottom: none;
        }

        /* Horizontal Rule */
        hr {
            border: none;
            height: 1px;
            background: var(--hr-color);
            margin: 2em 0;
        }

        /* Images */
        img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 1em 0;
        }

        /* Scrollbar (WebKit) */
        ::-webkit-scrollbar {
            width: 6px;
            height: 6px;
        }

        ::-webkit-scrollbar-track {
            background: transparent;
        }

        ::-webkit-scrollbar-thumb {
            background: var(--border);
            border-radius: 3px;
        }

        ::-webkit-scrollbar-thumb:hover {
            background: var(--fg-secondary);
        }
    """
}
