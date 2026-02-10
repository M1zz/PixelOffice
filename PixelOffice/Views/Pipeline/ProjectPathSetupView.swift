import SwiftUI

/// 프로젝트 경로 설정 뷰
/// 파이프라인 실행 전 외부 프로젝트 경로를 설정하는 UI
struct ProjectPathSetupView: View {
    let projectName: String
    @Binding var isPresented: Bool
    let onSave: (String) -> Void

    @State private var projectPath: String = ""
    @State private var isValidPath: Bool = false
    @State private var validationMessage: String = ""
    @State private var detectedSchemes: [String] = []
    @State private var isValidating: Bool = false
    @State private var showFilePicker: Bool = false
    @State private var showNewProjectSheet: Bool = false

    /// 경로 유형
    enum PathType: String, CaseIterable {
        case relative = "상대경로"
        case absolute = "절대경로"

        var icon: String {
            switch self {
            case .relative: return "arrow.up.left.and.arrow.down.right"
            case .absolute: return "folder"
            }
        }
    }

    @State private var pathType: PathType = .absolute

    var body: some View {
        VStack(spacing: 20) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("프로젝트 경로 설정")
                        .font(.title2.bold())
                    Text("\(projectName) 프로젝트의 소스 코드 위치를 설정하세요")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // 경로 유형 선택
            VStack(alignment: .leading, spacing: 12) {
                Text("경로 유형")
                    .font(.headline)

                Picker("", selection: $pathType) {
                    ForEach(PathType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                Text(pathType == .relative ?
                     "⚠️ 상대경로는 여러 컴퓨터에서 작업할 때 권장됩니다." :
                     "💡 절대경로는 외부 프로젝트를 지정할 때 사용합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 경로 입력
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("프로젝트 경로")
                        .font(.headline)
                    Spacer()

                    if pathType == .absolute {
                        Button("폴더 선택...") {
                            showFilePicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                }

                HStack(spacing: 8) {
                    TextField(
                        pathType == .relative ? "../.." : "/Users/.../프로젝트",
                        text: $projectPath
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: projectPath) { _, newValue in
                        validatePath(newValue)
                    }

                    if isValidating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !projectPath.isEmpty {
                        Image(systemName: isValidPath ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isValidPath ? .green : .red)
                    }
                }

                // 검증 메시지
                if !validationMessage.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: isValidPath ? "checkmark.circle" : "exclamationmark.triangle")
                            .foregroundStyle(isValidPath ? .green : .orange)
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(isValidPath ? .green : .orange)
                    }
                }

                // 감지된 스킴 표시
                if !detectedSchemes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("감지된 스킴")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(detectedSchemes, id: \.self) { scheme in
                                    Text(scheme)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }

            // 새 프로젝트 생성 안내
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🆕 Xcode 프로젝트가 없나요?")
                            .font(.headline)
                        Text("PixelOffice에서 새 프로젝트를 바로 생성할 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showNewProjectSheet = true
                    } label: {
                        Label("새 프로젝트 생성", systemImage: "plus.app")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 도움말
            VStack(alignment: .leading, spacing: 8) {
                Text("💡 도움말")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    HelpRow(icon: "folder", text: "Xcode 프로젝트(.xcodeproj) 또는 워크스페이스(.xcworkspace)가 있는 폴더를 선택하세요.")
                    HelpRow(icon: "arrow.triangle.branch", text: "상대경로 '../..'는 PixelOffice 프로젝트 자체를 가리킵니다.")
                    HelpRow(icon: "externaldrive", text: "외부 앱(회고앱 등)은 절대경로로 해당 프로젝트 폴더를 지정하세요.")
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            // 버튼
            HStack {
                Button("취소") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("저장") {
                    onSave(projectPath)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidPath || projectPath.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 550, height: 620)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.folder],
            onCompletion: { result in
                if case .success(let url) = result {
                    projectPath = url.path
                    validatePath(url.path)
                }
            }
        )
        .sheet(isPresented: $showNewProjectSheet) {
            NewXcodeProjectView(isPresented: $showNewProjectSheet) { createdPath in
                // 생성된 프로젝트 경로를 자동으로 설정
                projectPath = createdPath
                pathType = .absolute
                validatePath(createdPath)
            }
        }
        .onAppear {
            loadCurrentPath()
        }
    }

    /// 현재 설정된 경로 로드
    private func loadCurrentPath() {
        let basePath = DataPathService.shared.basePath
        let sanitizedName = DataPathService.shared.sanitizeName(projectName)
        let contextPath = "\(basePath)/\(sanitizedName)/PIPELINE_CONTEXT.md"

        if let content = try? String(contentsOfFile: contextPath, encoding: .utf8) {
            // 코드 블록에서 경로 추출
            if let extractedPath = extractPathFromContent(content) {
                projectPath = extractedPath
                pathType = extractedPath.hasPrefix("/") ? .absolute : .relative
                validatePath(extractedPath)
            }
        }
    }

    /// PIPELINE_CONTEXT.md에서 경로 추출
    private func extractPathFromContent(_ content: String) -> String? {
        let lines = content.components(separatedBy: "\n")
        var inSourcePathSection = false
        var inCodeBlock = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("프로젝트 소스 경로") || trimmed.contains("프로젝트 경로") {
                inSourcePathSection = true
                continue
            }

            if inSourcePathSection && trimmed.hasPrefix("###") {
                inSourcePathSection = false
                continue
            }

            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }

            if inSourcePathSection && inCodeBlock && !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                return trimmed
            }
        }

        return nil
    }

    /// 경로 검증
    private func validatePath(_ path: String) {
        guard !path.isEmpty else {
            isValidPath = false
            validationMessage = ""
            detectedSchemes = []
            return
        }

        isValidating = true

        Task {
            var absolutePath = path

            // 상대경로인 경우 절대경로로 변환
            if !path.hasPrefix("/") {
                let basePath = DataPathService.shared.basePath
                let sanitizedName = DataPathService.shared.sanitizeName(projectName)
                let contextDir = "\(basePath)/\(sanitizedName)"
                absolutePath = (contextDir as NSString).appendingPathComponent(path)
                absolutePath = (absolutePath as NSString).standardizingPath
            }

            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: absolutePath, isDirectory: &isDirectory)

            await MainActor.run {
                isValidating = false

                if !exists {
                    isValidPath = false
                    validationMessage = "경로가 존재하지 않습니다: \(absolutePath)"
                    detectedSchemes = []
                    return
                }

                if !isDirectory.boolValue {
                    isValidPath = false
                    validationMessage = "폴더가 아닙니다"
                    detectedSchemes = []
                    return
                }

                // Xcode 프로젝트 파일 확인
                if let contents = try? fileManager.contentsOfDirectory(atPath: absolutePath) {
                    let hasXcodeProject = contents.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") })
                    let hasPackageSwift = contents.contains("Package.swift")
                    let hasTuist = contents.contains("Project.swift")

                    if hasXcodeProject || hasPackageSwift || hasTuist {
                        isValidPath = true
                        if hasXcodeProject {
                            validationMessage = "✓ Xcode 프로젝트 발견"
                        } else if hasTuist {
                            validationMessage = "✓ Tuist 프로젝트 발견"
                        } else {
                            validationMessage = "✓ Swift Package 발견"
                        }

                        // 스킴 감지 (비동기)
                        detectSchemes(at: absolutePath)
                    } else {
                        isValidPath = false
                        validationMessage = "Xcode 프로젝트(.xcodeproj, .xcworkspace) 또는 Package.swift가 없습니다"
                        detectedSchemes = []
                    }
                } else {
                    isValidPath = false
                    validationMessage = "폴더 내용을 읽을 수 없습니다"
                    detectedSchemes = []
                }
            }
        }
    }

    /// 스킴 감지
    private func detectSchemes(at path: String) {
        Task {
            let buildService = BuildService()
            let schemes = await buildService.listSchemes(projectPath: path)

            await MainActor.run {
                detectedSchemes = schemes
                if !schemes.isEmpty {
                    validationMessage = "✓ Xcode 프로젝트 발견 (\(schemes.count)개 스킴)"
                }
            }
        }
    }
}

/// 도움말 행
struct HelpRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ProjectPathSetupView(
        projectName: "회고앱",
        isPresented: .constant(true)
    ) { path in
        print("Saved path: \(path)")
    }
}
