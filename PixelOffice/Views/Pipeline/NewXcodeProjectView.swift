import SwiftUI

/// 새 Xcode 프로젝트 생성 뷰
struct NewXcodeProjectView: View {
    @Binding var isPresented: Bool
    let onProjectCreated: (String) -> Void  // 생성된 프로젝트 경로 전달

    @State private var projectName: String = ""
    @State private var bundleIdPrefix: String = "com.yourcompany"
    @State private var selectedPlatform: XcodeProjectGenerator.Platform = .macOS
    @State private var targetPath: String = ""
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?
    @State private var showFilePicker: Bool = false

    /// 번들 ID 자동 생성
    var generatedBundleId: String {
        let sanitizedName = projectName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        return "\(bundleIdPrefix).\(sanitizedName)"
    }

    /// 생성 가능 여부
    var canCreate: Bool {
        !projectName.isEmpty &&
        !bundleIdPrefix.isEmpty &&
        !targetPath.isEmpty &&
        FileManager.default.fileExists(atPath: targetPath)
    }

    var body: some View {
        VStack(spacing: 20) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("새 Xcode 프로젝트 생성")
                        .font(.title2.bold())
                    Text("PixelOffice에서 자동으로 새 앱 프로젝트를 생성합니다")
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

            // 입력 폼
            VStack(alignment: .leading, spacing: 16) {
                // 프로젝트 이름
                VStack(alignment: .leading, spacing: 8) {
                    Text("프로젝트 이름")
                        .font(.headline)

                    TextField("예: 회고앱", text: $projectName)
                        .textFieldStyle(.roundedBorder)

                    Text("영문/한글 모두 가능. 공백은 자동으로 제거됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 플랫폼 선택
                VStack(alignment: .leading, spacing: 8) {
                    Text("플랫폼")
                        .font(.headline)

                    Picker("", selection: $selectedPlatform) {
                        ForEach(XcodeProjectGenerator.Platform.allCases, id: \.self) { platform in
                            HStack {
                                Image(systemName: platform == .macOS ? "desktopcomputer" : "iphone")
                                Text(platform.rawValue)
                            }
                            .tag(platform)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 번들 ID
                VStack(alignment: .leading, spacing: 8) {
                    Text("번들 ID 접두사")
                        .font(.headline)

                    TextField("com.yourcompany", text: $bundleIdPrefix)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 4) {
                        Text("생성될 번들 ID:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(generatedBundleId)
                            .font(.caption.monospaced())
                            .foregroundStyle(.blue)
                    }
                }

                // 저장 위치
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("저장 위치")
                            .font(.headline)
                        Spacer()
                        Button("폴더 선택...") {
                            showFilePicker = true
                        }
                        .buttonStyle(.bordered)
                    }

                    if targetPath.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.badge.questionmark")
                                .foregroundStyle(.orange)
                            Text("프로젝트가 생성될 폴더를 선택하세요")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.blue)
                            Text(targetPath)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        // 최종 경로 미리보기
                        if !projectName.isEmpty {
                            let sanitizedName = projectName.replacingOccurrences(of: " ", with: "")
                            HStack(spacing: 4) {
                                Text("생성될 경로:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(targetPath)/\(sanitizedName)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                // 에러 메시지
                if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.body)
                            .foregroundStyle(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Spacer()

            // 생성될 파일 구조 미리보기
            if !projectName.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("생성될 파일 구조")
                        .font(.headline)

                    let name = projectName.replacingOccurrences(of: " ", with: "")
                    VStack(alignment: .leading, spacing: 4) {
                        FileTreeRow(icon: "folder.fill", name: name, color: .blue)
                        FileTreeRow(icon: "folder.fill", name: "\(name).xcodeproj", color: .blue, indent: 1)
                        FileTreeRow(icon: "folder.fill", name: name, color: .yellow, indent: 1)
                        FileTreeRow(icon: "swift", name: "\(name)App.swift", color: .orange, indent: 2)
                        FileTreeRow(icon: "swift", name: "ContentView.swift", color: .orange, indent: 2)
                        FileTreeRow(icon: "folder.fill", name: "Assets.xcassets", color: .blue, indent: 2)
                        FileTreeRow(icon: "doc.text", name: "\(name).entitlements", color: .gray, indent: 2)
                    }
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Divider()

            // 버튼
            HStack {
                Button("취소") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    createProject()
                } label: {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 20, height: 20)
                    } else {
                        Label("프로젝트 생성", systemImage: "plus.app")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate || isCreating)
            }
        }
        .padding(24)
        .frame(width: 550, height: 650)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.folder],
            onCompletion: { result in
                if case .success(let url) = result {
                    targetPath = url.path
                }
            }
        )
        .onAppear {
            // 기본 경로 설정
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            targetPath = "\(homeDir)/Documents/code"
        }
    }

    /// 프로젝트 생성
    private func createProject() {
        errorMessage = nil
        isCreating = true

        let config = XcodeProjectGenerator.ProjectConfig(
            name: projectName,
            platform: selectedPlatform,
            bundleId: generatedBundleId,
            organizationName: bundleIdPrefix.components(separatedBy: ".").last ?? "YourCompany",
            targetPath: targetPath
        )

        Task {
            do {
                let projectPath = try XcodeProjectGenerator.shared.generateProject(config: config)

                await MainActor.run {
                    isCreating = false
                    onProjectCreated(projectPath)
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

/// 파일 트리 행
struct FileTreeRow: View {
    let icon: String
    let name: String
    let color: Color
    var indent: Int = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<indent, id: \.self) { _ in
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 16)
            }

            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)

            Text(name)
                .font(.system(.caption, design: .monospaced))
        }
    }
}

#Preview {
    NewXcodeProjectView(isPresented: .constant(true)) { path in
        print("Created: \(path)")
    }
}
