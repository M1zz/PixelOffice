# 픽셀 오피스 - 파이프라인 컨텍스트

> **파이프라인 실행 전 필수 설정 정보**

---

## 🔴 필수 정보

### 프로젝트 소스 경로

> ⚠️ **절대경로를 사용하지 마세요!** 여러 컴퓨터에서 작업합니다.

```
../..
```

**프로젝트 루트 탐색 방법:**
1. 이 파일(`PIPELINE_CONTEXT.md`) 기준 상대경로 `../..`
2. 또는 `*.xcodeproj` / `Project.swift` 파일이 있는 폴더 자동 탐색

### 빌드 명령

```bash
# 프로젝트 루트에서 실행
xcodebuild -project PixelOffice.xcodeproj -scheme PixelOffice -configuration Debug build
```

---

## 📋 기술 스택

### 언어 및 프레임워크

- **언어**: Swift 5.9
- **프레임워크**: SwiftUI, AppKit
- **최소 지원 버전**: macOS 14.0

### 빌드 도구

- **빌드 시스템**: Xcode 15+
- **패키지 매니저**: SPM (Swift Package Manager)

---

## 📁 프로젝트 구조

```
PixelOffice/
├── PixelOffice/
│   ├── PixelOfficeApp.swift    # 앱 진입점
│   ├── Models/                  # 데이터 모델
│   │   ├── Company.swift
│   │   ├── Project.swift
│   │   ├── Employee.swift
│   │   ├── Task.swift
│   │   ├── Department.swift
│   │   └── Pipeline/            # 파이프라인 모델
│   ├── Views/                   # UI 뷰
│   │   ├── Main/
│   │   ├── Chat/
│   │   ├── Kanban/
│   │   ├── Pipeline/
│   │   └── Components/
│   ├── ViewModels/              # 뷰모델
│   ├── Services/                # 서비스 레이어
│   │   ├── CompanyStore.swift
│   │   ├── ClaudeCodeService.swift
│   │   └── Pipeline/
│   └── Resources/               # 리소스
├── datas/                       # 데이터 저장소
│   ├── _shared/                 # 전사 공용
│   └── [프로젝트명]/            # 프로젝트별 데이터
└── PixelOffice.xcodeproj
```

---

## 🎯 코딩 컨벤션

### 네이밍 규칙

- **타입**: PascalCase (예: `PipelineCoordinator`)
- **변수/함수**: camelCase (예: `startPipeline`)
- **상수**: camelCase

### 아키텍처 패턴

- **MVVM**: View - ViewModel - Model
- **Stores**: `CompanyStore`, `ProjectStore` 등 ObservableObject 사용
- **Services**: 싱글톤 또는 주입 방식

### SwiftUI 규칙

- 모든 View는 `@MainActor` 암시적 적용
- `@Published` 프로퍼티 변경 시 반드시 재할당 (in-place mutation 피하기)
- actor 패턴으로 동시성 관리

---

## ⚠️ 주의사항

### 수정 금지 파일

- `Info.plist`
- `PixelOffice.entitlements`
- `datas/` 내 사용자 데이터 파일들

### 중요 규칙

- 프로젝트 루트 외부에 파일 생성 금지
- 모든 데이터는 `datas/` 폴더에 저장
- Claude Code CLI 연동 시 `--dangerously-skip-permissions` 사용

---

## 📚 참고 문서 (상대경로, 프로젝트 루트 기준)

- **claude.md**: `./claude.md`
- **PROJECT.md**: `./datas/픽셀-오피스/PROJECT.md`

---

## 📝 추가 컨텍스트

- 이 프로젝트는 AI 직원이 협업하는 가상 오피스 앱입니다
- 파이프라인은 요구사항 분해 → 코드 생성 → 빌드 → Self-Healing 순서로 실행됩니다
- ClaudeCodeService를 통해 Claude Code CLI를 호출합니다
- 모든 로그는 PipelineRun에 기록됩니다
