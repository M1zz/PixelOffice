import Foundation

/// Xcode 프로젝트 템플릿 생성 서비스
/// 새로운 macOS/iOS 앱 프로젝트를 처음부터 생성
class XcodeProjectGenerator {
    static let shared = XcodeProjectGenerator()

    private init() {}

    // MARK: - Project Templates

    enum Platform: String, CaseIterable {
        case macOS = "macOS"
        case iOS = "iOS"

        var deploymentTarget: String {
            switch self {
            case .macOS: return "14.0"
            case .iOS: return "17.0"
            }
        }

        var sdkRoot: String {
            switch self {
            case .macOS: return "macosx"
            case .iOS: return "iphoneos"
            }
        }
    }

    struct ProjectConfig {
        var name: String
        var platform: Platform
        var bundleId: String
        var organizationName: String
        var targetPath: String  // 프로젝트가 생성될 경로

        var sanitizedName: String {
            name.replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
        }
    }

    // MARK: - Generate Project

    /// 새 Xcode 프로젝트 생성
    /// - Parameter config: 프로젝트 설정
    /// - Returns: 생성된 프로젝트 경로 또는 에러
    func generateProject(config: ProjectConfig) throws -> String {
        let projectDir = "\(config.targetPath)/\(config.sanitizedName)"
        let xcodeprojDir = "\(projectDir)/\(config.sanitizedName).xcodeproj"
        let sourcesDir = "\(projectDir)/\(config.sanitizedName)"

        let fileManager = FileManager.default

        // 이미 존재하는지 확인
        if fileManager.fileExists(atPath: projectDir) {
            throw GeneratorError.projectAlreadyExists(projectDir)
        }

        // 디렉토리 생성
        try fileManager.createDirectory(atPath: sourcesDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: xcodeprojDir, withIntermediateDirectories: true)

        // 파일 생성
        try generateAppFile(config: config, at: sourcesDir)
        try generateContentView(config: config, at: sourcesDir)
        try generateAssets(config: config, at: sourcesDir)
        try generateEntitlements(config: config, at: sourcesDir)
        try generatePbxproj(config: config, at: xcodeprojDir)
        try generateInfoPlist(config: config, at: sourcesDir)

        print("[XcodeProjectGenerator] ✅ 프로젝트 생성 완료: \(projectDir)")

        return projectDir
    }

    // MARK: - File Generators

    private func generateAppFile(config: ProjectConfig, at dir: String) throws {
        let content = """
        import SwiftUI

        @main
        struct \(config.sanitizedName)App: App {
            var body: some Scene {
                WindowGroup {
                    ContentView()
                }
            }
        }
        """
        try content.write(toFile: "\(dir)/\(config.sanitizedName)App.swift", atomically: true, encoding: .utf8)
    }

    private func generateContentView(config: ProjectConfig, at dir: String) throws {
        let content = """
        import SwiftUI

        struct ContentView: View {
            var body: some View {
                VStack {
                    Image(systemName: "star.fill")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                    Text("Hello, \(config.name)!")
                }
                .padding()
            }
        }

        #Preview {
            ContentView()
        }
        """
        try content.write(toFile: "\(dir)/ContentView.swift", atomically: true, encoding: .utf8)
    }

    private func generateAssets(config: ProjectConfig, at dir: String) throws {
        let assetsDir = "\(dir)/Assets.xcassets"
        let appIconDir = "\(assetsDir)/AppIcon.appiconset"
        let accentColorDir = "\(assetsDir)/AccentColor.colorset"

        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: appIconDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: accentColorDir, withIntermediateDirectories: true)

        // Contents.json for Assets
        let assetsContents = """
        {
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
        try assetsContents.write(toFile: "\(assetsDir)/Contents.json", atomically: true, encoding: .utf8)

        // AppIcon Contents.json
        let appIconContents = """
        {
          "images" : [
            {
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "16x16"
            },
            {
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "16x16"
            },
            {
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "32x32"
            },
            {
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "32x32"
            },
            {
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "128x128"
            },
            {
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "128x128"
            },
            {
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "256x256"
            },
            {
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "256x256"
            },
            {
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "512x512"
            },
            {
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "512x512"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
        try appIconContents.write(toFile: "\(appIconDir)/Contents.json", atomically: true, encoding: .utf8)

        // AccentColor Contents.json
        let accentColorContents = """
        {
          "colors" : [
            {
              "idiom" : "universal"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
        try accentColorContents.write(toFile: "\(accentColorDir)/Contents.json", atomically: true, encoding: .utf8)
    }

    private func generateEntitlements(config: ProjectConfig, at dir: String) throws {
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>com.apple.security.app-sandbox</key>
            <false/>
        </dict>
        </plist>
        """
        try content.write(toFile: "\(dir)/\(config.sanitizedName).entitlements", atomically: true, encoding: .utf8)
    }

    private func generateInfoPlist(config: ProjectConfig, at dir: String) throws {
        // macOS 앱의 경우 Info.plist는 빌드 설정으로 처리되므로 별도 파일 불필요
        // 필요시 추가 가능
    }

    private func generatePbxproj(config: ProjectConfig, at xcodeprojDir: String) throws {
        let mainGroupUUID = generateUUID()
        let sourcesGroupUUID = generateUUID()
        let productsGroupUUID = generateUUID()
        let targetUUID = generateUUID()
        let buildConfigDebugUUID = generateUUID()
        let buildConfigReleaseUUID = generateUUID()
        let targetConfigDebugUUID = generateUUID()
        let targetConfigReleaseUUID = generateUUID()
        let configListProjectUUID = generateUUID()
        let configListTargetUUID = generateUUID()
        let appFileRefUUID = generateUUID()
        let contentViewRefUUID = generateUUID()
        let assetsRefUUID = generateUUID()
        let entitlementsRefUUID = generateUUID()
        let productRefUUID = generateUUID()
        let sourcesBuildPhaseUUID = generateUUID()
        let resourcesBuildPhaseUUID = generateUUID()
        let frameworksBuildPhaseUUID = generateUUID()
        let appFileBuildUUID = generateUUID()
        let contentViewBuildUUID = generateUUID()
        let assetsBuildUUID = generateUUID()
        let rootObjectUUID = generateUUID()

        let content = """
        // !$*UTF8*$!
        {
            archiveVersion = 1;
            classes = {
            };
            objectVersion = 56;
            objects = {

        /* Begin PBXBuildFile section */
                \(appFileBuildUUID) /* \(config.sanitizedName)App.swift in Sources */ = {isa = PBXBuildFile; fileRef = \(appFileRefUUID) /* \(config.sanitizedName)App.swift */; };
                \(contentViewBuildUUID) /* ContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = \(contentViewRefUUID) /* ContentView.swift */; };
                \(assetsBuildUUID) /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = \(assetsRefUUID) /* Assets.xcassets */; };
        /* End PBXBuildFile section */

        /* Begin PBXFileReference section */
                \(productRefUUID) /* \(config.sanitizedName).app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "\(config.sanitizedName).app"; sourceTree = BUILT_PRODUCTS_DIR; };
                \(appFileRefUUID) /* \(config.sanitizedName)App.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "\(config.sanitizedName)App.swift"; sourceTree = "<group>"; };
                \(contentViewRefUUID) /* ContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; };
                \(assetsRefUUID) /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };
                \(entitlementsRefUUID) /* \(config.sanitizedName).entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = "\(config.sanitizedName).entitlements"; sourceTree = "<group>"; };
        /* End PBXFileReference section */

        /* Begin PBXFrameworksBuildPhase section */
                \(frameworksBuildPhaseUUID) /* Frameworks */ = {
                    isa = PBXFrameworksBuildPhase;
                    buildActionMask = 2147483647;
                    files = (
                    );
                    runOnlyForDeploymentPostprocessing = 0;
                };
        /* End PBXFrameworksBuildPhase section */

        /* Begin PBXGroup section */
                \(mainGroupUUID) = {
                    isa = PBXGroup;
                    children = (
                        \(sourcesGroupUUID) /* \(config.sanitizedName) */,
                        \(productsGroupUUID) /* Products */,
                    );
                    sourceTree = "<group>";
                };
                \(productsGroupUUID) /* Products */ = {
                    isa = PBXGroup;
                    children = (
                        \(productRefUUID) /* \(config.sanitizedName).app */,
                    );
                    name = Products;
                    sourceTree = "<group>";
                };
                \(sourcesGroupUUID) /* \(config.sanitizedName) */ = {
                    isa = PBXGroup;
                    children = (
                        \(appFileRefUUID) /* \(config.sanitizedName)App.swift */,
                        \(contentViewRefUUID) /* ContentView.swift */,
                        \(assetsRefUUID) /* Assets.xcassets */,
                        \(entitlementsRefUUID) /* \(config.sanitizedName).entitlements */,
                    );
                    path = \(config.sanitizedName);
                    sourceTree = "<group>";
                };
        /* End PBXGroup section */

        /* Begin PBXNativeTarget section */
                \(targetUUID) /* \(config.sanitizedName) */ = {
                    isa = PBXNativeTarget;
                    buildConfigurationList = \(configListTargetUUID) /* Build configuration list for PBXNativeTarget "\(config.sanitizedName)" */;
                    buildPhases = (
                        \(sourcesBuildPhaseUUID) /* Sources */,
                        \(frameworksBuildPhaseUUID) /* Frameworks */,
                        \(resourcesBuildPhaseUUID) /* Resources */,
                    );
                    buildRules = (
                    );
                    dependencies = (
                    );
                    name = \(config.sanitizedName);
                    productName = \(config.sanitizedName);
                    productReference = \(productRefUUID) /* \(config.sanitizedName).app */;
                    productType = "com.apple.product-type.application";
                };
        /* End PBXNativeTarget section */

        /* Begin PBXProject section */
                \(rootObjectUUID) /* Project object */ = {
                    isa = PBXProject;
                    attributes = {
                        BuildIndependentTargetsInParallel = 1;
                        LastSwiftUpdateCheck = 1500;
                        LastUpgradeCheck = 1500;
                        TargetAttributes = {
                            \(targetUUID) = {
                                CreatedOnToolsVersion = 15.0;
                            };
                        };
                    };
                    buildConfigurationList = \(configListProjectUUID) /* Build configuration list for PBXProject "\(config.sanitizedName)" */;
                    compatibilityVersion = "Xcode 14.0";
                    developmentRegion = ko;
                    hasScannedForEncodings = 0;
                    knownRegions = (
                        ko,
                        Base,
                    );
                    mainGroup = \(mainGroupUUID);
                    productRefGroup = \(productsGroupUUID) /* Products */;
                    projectDirPath = "";
                    projectRoot = "";
                    targets = (
                        \(targetUUID) /* \(config.sanitizedName) */,
                    );
                };
        /* End PBXProject section */

        /* Begin PBXResourcesBuildPhase section */
                \(resourcesBuildPhaseUUID) /* Resources */ = {
                    isa = PBXResourcesBuildPhase;
                    buildActionMask = 2147483647;
                    files = (
                        \(assetsBuildUUID) /* Assets.xcassets in Resources */,
                    );
                    runOnlyForDeploymentPostprocessing = 0;
                };
        /* End PBXResourcesBuildPhase section */

        /* Begin PBXSourcesBuildPhase section */
                \(sourcesBuildPhaseUUID) /* Sources */ = {
                    isa = PBXSourcesBuildPhase;
                    buildActionMask = 2147483647;
                    files = (
                        \(contentViewBuildUUID) /* ContentView.swift in Sources */,
                        \(appFileBuildUUID) /* \(config.sanitizedName)App.swift in Sources */,
                    );
                    runOnlyForDeploymentPostprocessing = 0;
                };
        /* End PBXSourcesBuildPhase section */

        /* Begin XCBuildConfiguration section */
                \(buildConfigDebugUUID) /* Debug */ = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        ALWAYS_SEARCH_USER_PATHS = NO;
                        ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
                        CLANG_ANALYZER_NONNULL = YES;
                        CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
                        CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
                        CLANG_ENABLE_MODULES = YES;
                        CLANG_ENABLE_OBJC_ARC = YES;
                        CLANG_ENABLE_OBJC_WEAK = YES;
                        CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
                        CLANG_WARN_BOOL_CONVERSION = YES;
                        CLANG_WARN_COMMA = YES;
                        CLANG_WARN_CONSTANT_CONVERSION = YES;
                        CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
                        CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
                        CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
                        CLANG_WARN_EMPTY_BODY = YES;
                        CLANG_WARN_ENUM_CONVERSION = YES;
                        CLANG_WARN_INFINITE_RECURSION = YES;
                        CLANG_WARN_INT_CONVERSION = YES;
                        CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
                        CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
                        CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
                        CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
                        CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
                        CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
                        CLANG_WARN_STRICT_PROTOTYPES = YES;
                        CLANG_WARN_SUSPICIOUS_MOVE = YES;
                        CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
                        CLANG_WARN_UNREACHABLE_CODE = YES;
                        CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
                        COPY_PHASE_STRIP = NO;
                        DEBUG_INFORMATION_FORMAT = dwarf;
                        ENABLE_STRICT_OBJC_MSGSEND = YES;
                        ENABLE_TESTABILITY = YES;
                        ENABLE_USER_SCRIPT_SANDBOXING = YES;
                        GCC_C_LANGUAGE_STANDARD = gnu17;
                        GCC_DYNAMIC_NO_PIC = NO;
                        GCC_NO_COMMON_BLOCKS = YES;
                        GCC_OPTIMIZATION_LEVEL = 0;
                        GCC_PREPROCESSOR_DEFINITIONS = (
                            "DEBUG=1",
                            "$(inherited)",
                        );
                        GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
                        GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
                        GCC_WARN_UNDECLARED_SELECTOR = YES;
                        GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
                        GCC_WARN_UNUSED_FUNCTION = YES;
                        GCC_WARN_UNUSED_VARIABLE = YES;
                        LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
                        MACOSX_DEPLOYMENT_TARGET = \(config.platform.deploymentTarget);
                        MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
                        MTL_FAST_MATH = YES;
                        ONLY_ACTIVE_ARCH = YES;
                        SDKROOT = \(config.platform.sdkRoot);
                        SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
                        SWIFT_OPTIMIZATION_LEVEL = "-Onone";
                    };
                    name = Debug;
                };
                \(buildConfigReleaseUUID) /* Release */ = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        ALWAYS_SEARCH_USER_PATHS = NO;
                        ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
                        CLANG_ANALYZER_NONNULL = YES;
                        CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
                        CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
                        CLANG_ENABLE_MODULES = YES;
                        CLANG_ENABLE_OBJC_ARC = YES;
                        CLANG_ENABLE_OBJC_WEAK = YES;
                        CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
                        CLANG_WARN_BOOL_CONVERSION = YES;
                        CLANG_WARN_COMMA = YES;
                        CLANG_WARN_CONSTANT_CONVERSION = YES;
                        CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
                        CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
                        CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
                        CLANG_WARN_EMPTY_BODY = YES;
                        CLANG_WARN_ENUM_CONVERSION = YES;
                        CLANG_WARN_INFINITE_RECURSION = YES;
                        CLANG_WARN_INT_CONVERSION = YES;
                        CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
                        CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
                        CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
                        CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
                        CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
                        CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
                        CLANG_WARN_STRICT_PROTOTYPES = YES;
                        CLANG_WARN_SUSPICIOUS_MOVE = YES;
                        CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
                        CLANG_WARN_UNREACHABLE_CODE = YES;
                        CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
                        COPY_PHASE_STRIP = NO;
                        DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
                        ENABLE_NS_ASSERTIONS = NO;
                        ENABLE_STRICT_OBJC_MSGSEND = YES;
                        ENABLE_USER_SCRIPT_SANDBOXING = YES;
                        GCC_C_LANGUAGE_STANDARD = gnu17;
                        GCC_NO_COMMON_BLOCKS = YES;
                        GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
                        GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
                        GCC_WARN_UNDECLARED_SELECTOR = YES;
                        GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
                        GCC_WARN_UNUSED_FUNCTION = YES;
                        GCC_WARN_UNUSED_VARIABLE = YES;
                        LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
                        MACOSX_DEPLOYMENT_TARGET = \(config.platform.deploymentTarget);
                        MTL_ENABLE_DEBUG_INFO = NO;
                        MTL_FAST_MATH = YES;
                        SDKROOT = \(config.platform.sdkRoot);
                        SWIFT_COMPILATION_MODE = wholemodule;
                    };
                    name = Release;
                };
                \(targetConfigDebugUUID) /* Debug */ = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
                        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
                        CODE_SIGN_ENTITLEMENTS = "\(config.sanitizedName)/\(config.sanitizedName).entitlements";
                        CODE_SIGN_STYLE = Automatic;
                        COMBINE_HIDPI_IMAGES = YES;
                        CURRENT_PROJECT_VERSION = 1;
                        DEVELOPMENT_TEAM = "";
                        ENABLE_HARDENED_RUNTIME = YES;
                        GENERATE_INFOPLIST_FILE = YES;
                        INFOPLIST_KEY_NSHumanReadableCopyright = "";
                        INFOPLIST_KEY_NSMainStoryboardFile = "";
                        INFOPLIST_KEY_NSPrincipalClass = NSApplication;
                        LD_RUNPATH_SEARCH_PATHS = (
                            "$(inherited)",
                            "@executable_path/../Frameworks",
                        );
                        MARKETING_VERSION = 1.0;
                        PRODUCT_BUNDLE_IDENTIFIER = "\(config.bundleId)";
                        PRODUCT_NAME = "$(TARGET_NAME)";
                        SWIFT_EMIT_LOC_STRINGS = YES;
                        SWIFT_VERSION = 5.0;
                    };
                    name = Debug;
                };
                \(targetConfigReleaseUUID) /* Release */ = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
                        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
                        CODE_SIGN_ENTITLEMENTS = "\(config.sanitizedName)/\(config.sanitizedName).entitlements";
                        CODE_SIGN_STYLE = Automatic;
                        COMBINE_HIDPI_IMAGES = YES;
                        CURRENT_PROJECT_VERSION = 1;
                        DEVELOPMENT_TEAM = "";
                        ENABLE_HARDENED_RUNTIME = YES;
                        GENERATE_INFOPLIST_FILE = YES;
                        INFOPLIST_KEY_NSHumanReadableCopyright = "";
                        INFOPLIST_KEY_NSMainStoryboardFile = "";
                        INFOPLIST_KEY_NSPrincipalClass = NSApplication;
                        LD_RUNPATH_SEARCH_PATHS = (
                            "$(inherited)",
                            "@executable_path/../Frameworks",
                        );
                        MARKETING_VERSION = 1.0;
                        PRODUCT_BUNDLE_IDENTIFIER = "\(config.bundleId)";
                        PRODUCT_NAME = "$(TARGET_NAME)";
                        SWIFT_EMIT_LOC_STRINGS = YES;
                        SWIFT_VERSION = 5.0;
                    };
                    name = Release;
                };
        /* End XCBuildConfiguration section */

        /* Begin XCConfigurationList section */
                \(configListProjectUUID) /* Build configuration list for PBXProject "\(config.sanitizedName)" */ = {
                    isa = XCConfigurationList;
                    buildConfigurations = (
                        \(buildConfigDebugUUID) /* Debug */,
                        \(buildConfigReleaseUUID) /* Release */,
                    );
                    defaultConfigurationIsVisible = 0;
                    defaultConfigurationName = Release;
                };
                \(configListTargetUUID) /* Build configuration list for PBXNativeTarget "\(config.sanitizedName)" */ = {
                    isa = XCConfigurationList;
                    buildConfigurations = (
                        \(targetConfigDebugUUID) /* Debug */,
                        \(targetConfigReleaseUUID) /* Release */,
                    );
                    defaultConfigurationIsVisible = 0;
                    defaultConfigurationName = Release;
                };
        /* End XCConfigurationList section */
            };
            rootObject = \(rootObjectUUID) /* Project object */;
        }
        """

        try content.write(toFile: "\(xcodeprojDir)/project.pbxproj", atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers

    private func generateUUID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24).uppercased()
    }

    enum GeneratorError: LocalizedError {
        case projectAlreadyExists(String)
        case failedToCreateDirectory(String)
        case failedToWriteFile(String)

        var errorDescription: String? {
            switch self {
            case .projectAlreadyExists(let path):
                return "프로젝트가 이미 존재합니다: \(path)"
            case .failedToCreateDirectory(let path):
                return "디렉토리 생성 실패: \(path)"
            case .failedToWriteFile(let path):
                return "파일 쓰기 실패: \(path)"
            }
        }
    }
}
