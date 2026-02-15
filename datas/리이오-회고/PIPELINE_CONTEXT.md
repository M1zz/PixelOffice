# 리이오 회고 - 파이프라인 컨텍스트

> **파이프라인 실행 전 필수 설정 정보**

---

## 🔴 필수 정보

### 프로젝트 소스 경로

```
/Users/leeo/Documents/code/LeeeoRetrospect
```

---

## 📋 기술 스택

- **언어**: Swift 5.9+
- **UI 프레임워크**: SwiftUI
- **데이터 저장**: SwiftData
- **최소 지원 버전**: macOS 14.0
- **빌드 도구**: Xcode 15+
- **아키텍처**: MVVM

---

## 📁 프로젝트 구조

```
LeeeoRetrospect/
├── LeeeoRetrospect/
│   ├── LeeeoRetrospectApp.swift
│   ├── Models/
│   │   ├── Retrospect.swift
│   │   └── Tag.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── RetrospectListView.swift
│   │   ├── RetrospectDetailView.swift
│   │   ├── RetrospectEditorView.swift
│   │   └── StatsView.swift
│   ├── ViewModels/
│   │   └── RetrospectViewModel.swift
│   └── Services/
│       └── SearchService.swift
├── LeeeoRetrospect.xcodeproj
└── README.md
```

---

## 🎯 MVP 요구사항

1. 회고 CRUD (생성/조회/수정/삭제)
2. 기분/에너지 레벨 (1-5점)
3. 구조화된 입력 (하이라이트/감사/배움/개선)
4. 태그 시스템
5. 검색 기능
6. 3-column NavigationSplitView 레이아웃

---

*이 파일은 PixelOffice에서 자동 생성되었습니다.*
