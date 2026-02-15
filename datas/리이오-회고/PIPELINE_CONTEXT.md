# 리이오 회고 - 파이프라인 컨텍스트

> **파이프라인 실행 전 필수 설정 정보**

---

## 🔴 필수 정보

### 프로젝트 소스 경로

```
/Users/leeo/Documents/code/LeeeoRetrospect
```

### 빌드 명령

```bash
# Xcode 프로젝트 빌드
xcodebuild -project LeeeoRetrospect.xcodeproj -scheme LeeeoRetrospect -configuration Debug build

# 또는 Swift Package Manager
swift build
```

---

## 📋 기술 스택

### 언어 및 프레임워크

- **언어**: Swift 5.9+
- **UI 프레임워크**: SwiftUI
- **데이터 저장**: SwiftData
- **최소 지원 버전**: macOS 14.0

### 빌드 도구

- **빌드 시스템**: Xcode 15+
- **패키지 매니저**: Swift Package Manager

---

## 📁 프로젝트 구조

```
LeeeoRetrospect/
├── LeeeoRetrospect/
│   ├── App/
│   │   └── LeeeoRetrospectApp.swift
│   ├── Models/
│   ├── Views/
│   ├── ViewModels/
│   └── Services/
├── LeeeoRetrospect.xcodeproj
└── README.md
```

---

## 🎯 코딩 컨벤션

- **타입**: PascalCase (예: `RetrospectViewModel`)
- **변수/함수**: camelCase (예: `saveRetrospect()`)
- **아키텍처**: MVVM
- **SwiftUI 스타일**: ViewBuilder 적극 활용
- **에러 처리**: Swift Error + do-catch

---

## ⚠️ 주의사항

- 프로젝트 루트 외부에 파일 생성 금지
- 모든 데이터는 SwiftData로 로컬 저장
- 네트워크 기능 없음 (오프라인 우선)

---

## 📚 참고 문서

- **PROJECT.md**: `./datas/리이오-회고/PROJECT.md`
- **기획서**: `./datas/리이오-회고/기획/documents/`
- **디자인 가이드**: `./datas/리이오-회고/디자인/documents/`

---

*이 파일은 PixelOffice에서 자동 생성되었습니다.*
