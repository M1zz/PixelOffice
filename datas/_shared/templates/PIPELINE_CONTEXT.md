# 파이프라인 컨텍스트 템플릿

> **이 파일은 자동 개발 파이프라인 실행 전에 필수로 설정해야 하는 정보입니다.**
> 프로젝트별로 `datas/[프로젝트명]/PIPELINE_CONTEXT.md`에 복사하여 사용하세요.

---

## 🔴 필수 정보 (반드시 설정)

### 프로젝트 소스 경로

파이프라인이 코드를 수정하고 빌드할 실제 프로젝트 경로입니다.

```
/Users/사용자명/Documents/workspace/code/프로젝트명
```

> ⚠️ 경로가 없으면 빌드 단계에서 실패합니다.

### 빌드 명령

프로젝트를 빌드하는 명령어입니다.

- **Xcode 프로젝트**: `xcodebuild -project 프로젝트.xcodeproj -scheme 스킴명 build`
- **Xcode 워크스페이스**: `xcodebuild -workspace 프로젝트.xcworkspace -scheme 스킴명 build`
- **Swift Package**: `swift build`
- **Tuist**: `tuist generate && xcodebuild ...`

---

## 📋 기술 스택

### 언어 및 프레임워크

- **언어**: Swift 5.9
- **프레임워크**: SwiftUI, AppKit
- **최소 지원 버전**: macOS 14.0 / iOS 17.0

### 빌드 도구

- **빌드 시스템**: Xcode / Tuist / SPM
- **패키지 매니저**: SPM / CocoaPods

### 주요 의존성

- 예: Alamofire, SwiftLint, Firebase

---

## 📁 프로젝트 구조

코드 생성 시 AI가 파일을 올바른 위치에 배치하도록 안내합니다.

```
프로젝트명/
├── Sources/           # 소스 코드
│   ├── Models/        # 데이터 모델
│   ├── Views/         # UI 뷰
│   ├── ViewModels/    # 뷰모델
│   ├── Services/      # 서비스 레이어
│   └── Utilities/     # 유틸리티
├── Resources/         # 리소스 파일
├── Tests/             # 테스트 코드
└── README.md
```

---

## 🎯 코딩 컨벤션

### 네이밍 규칙

- **타입**: PascalCase (예: `UserProfile`)
- **변수/함수**: camelCase (예: `fetchUserData`)
- **상수**: camelCase 또는 SCREAMING_SNAKE_CASE

### 파일 구조

- 파일당 하나의 주요 타입
- extension은 같은 파일 또는 `+Extension.swift` 형식

### 주석 스타일

- `/// 문서화 주석` 사용
- `// MARK: - 섹션` 으로 구분

---

## ⚠️ 주의사항

### 수정 금지 파일

파이프라인이 수정하면 안 되는 파일 목록

- `Info.plist` (수동 관리)
- `*.xcconfig` (빌드 설정)
- `Podfile`, `Package.swift` (의존성 관리)

### 보안 관련

- API 키는 환경변수 또는 Keychain 사용
- `.env` 파일 직접 수정 금지

---

## 📚 참고 문서

파이프라인이 참조할 문서 경로

- **API 문서**: `docs/API.md`
- **아키텍처**: `docs/ARCHITECTURE.md`
- **변경 이력**: `CHANGELOG.md`

---

## 🔧 빌드 전 실행 스크립트

빌드 전에 실행해야 하는 명령어 (선택)

```bash
# 예: Tuist 프로젝트
tuist generate

# 예: SwiftGen
swiftgen
```

---

## 📝 추가 컨텍스트

AI에게 전달할 추가 정보 (자유 형식)

```
- 이 프로젝트는 MVVM 아키텍처를 따릅니다
- 모든 뷰는 @MainActor로 마킹되어야 합니다
- Combine 대신 async/await를 사용합니다
```
