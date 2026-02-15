import SwiftUI
import WebKit

/// 디자인 HTML 미리보기 뷰
struct DesignPreviewView: View {
    let htmlContent: String?
    let filePath: String?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDevice: PreviewDevice = .iPhone14Pro
    @State private var scale: CGFloat = 1.0
    @State private var showCode = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🎨 디자인 미리보기")
                        .font(.title2.bold())

                    if let path = filePath {
                        Text((path as NSString).lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 디바이스 선택
                Picker("디바이스", selection: $selectedDevice) {
                    ForEach(PreviewDevice.allCases, id: \.self) { device in
                        Text(device.name).tag(device)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                // 확대/축소
                HStack(spacing: 4) {
                    Button {
                        scale = max(0.25, scale - 0.25)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .disabled(scale <= 0.25)

                    Text("\(Int(scale * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 50)

                    Button {
                        scale = min(2.0, scale + 0.25)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .disabled(scale >= 2.0)

                    Button {
                        scale = 1.0
                    } label: {
                        Image(systemName: "1.magnifyingglass")
                    }
                }
                .buttonStyle(.bordered)

                // 코드 보기 토글
                Button {
                    showCode.toggle()
                } label: {
                    Label(showCode ? "미리보기" : "코드 보기", systemImage: showCode ? "eye" : "chevron.left.forwardslash.chevron.right")
                }
                .buttonStyle(.bordered)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 메인 콘텐츠
            if showCode {
                // HTML 코드 뷰
                if let html = htmlContent ?? loadHTMLFromFile() {
                    ScrollView {
                        Text(html)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(NSColor.textBackgroundColor))
                }
            } else {
                // 미리보기
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical]) {
                        VStack {
                            // 디바이스 프레임
                            ZStack {
                                // 디바이스 베젤
                                RoundedRectangle(cornerRadius: selectedDevice.cornerRadius * scale)
                                    .fill(Color(NSColor.darkGray))
                                    .frame(
                                        width: (selectedDevice.width + 20) * scale,
                                        height: (selectedDevice.height + 20) * scale
                                    )

                                // 화면
                                if let html = htmlContent ?? loadHTMLFromFile() {
                                    WebViewWrapper(htmlContent: html)
                                        .frame(
                                            width: selectedDevice.width * scale,
                                            height: selectedDevice.height * scale
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: (selectedDevice.cornerRadius - 5) * scale))
                                } else {
                                    Text("HTML 콘텐츠를 불러올 수 없습니다")
                                        .foregroundStyle(.secondary)
                                        .frame(
                                            width: selectedDevice.width * scale,
                                            height: selectedDevice.height * scale
                                        )
                                        .background(Color(NSColor.windowBackgroundColor))
                                }
                            }
                            .shadow(color: .black.opacity(0.3), radius: 20)

                            // 디바이스 이름
                            Text(selectedDevice.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    private func loadHTMLFromFile() -> String? {
        guard let path = filePath else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }
}

// MARK: - WebView Wrapper

struct WebViewWrapper: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
}

// MARK: - Preview Device

enum PreviewDevice: String, CaseIterable {
    case iPhone14Pro = "iphone14pro"
    case iPhoneSE = "iphonese"
    case iPadPro11 = "ipadpro11"
    case iPadMini = "ipadmini"
    case macBook = "macbook"
    case desktop = "desktop"

    var name: String {
        switch self {
        case .iPhone14Pro: return "iPhone 14 Pro"
        case .iPhoneSE: return "iPhone SE"
        case .iPadPro11: return "iPad Pro 11\""
        case .iPadMini: return "iPad mini"
        case .macBook: return "MacBook Pro 14\""
        case .desktop: return "Desktop (1920x1080)"
        }
    }

    var width: CGFloat {
        switch self {
        case .iPhone14Pro: return 393
        case .iPhoneSE: return 375
        case .iPadPro11: return 834
        case .iPadMini: return 744
        case .macBook: return 1512
        case .desktop: return 1920
        }
    }

    var height: CGFloat {
        switch self {
        case .iPhone14Pro: return 852
        case .iPhoneSE: return 667
        case .iPadPro11: return 1194
        case .iPadMini: return 1133
        case .macBook: return 982
        case .desktop: return 1080
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .iPhone14Pro: return 47
        case .iPhoneSE: return 0
        case .iPadPro11: return 18
        case .iPadMini: return 18
        case .macBook: return 10
        case .desktop: return 0
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleHTML = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                margin: 0;
                padding: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
            }
            .card {
                background: white;
                border-radius: 16px;
                padding: 24px;
                box-shadow: 0 4px 20px rgba(0,0,0,0.1);
            }
            h1 {
                color: #333;
                margin: 0 0 16px 0;
            }
            p {
                color: #666;
                line-height: 1.6;
            }
            .button {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                border: none;
                padding: 12px 24px;
                border-radius: 8px;
                font-size: 16px;
                cursor: pointer;
            }
        </style>
    </head>
    <body>
        <div class="card">
            <h1>🎨 디자인 미리보기</h1>
            <p>이것은 파이프라인에서 생성된 디자인 HTML의 미리보기입니다.</p>
            <button class="button">시작하기</button>
        </div>
    </body>
    </html>
    """

    DesignPreviewView(htmlContent: sampleHTML, filePath: nil)
}
