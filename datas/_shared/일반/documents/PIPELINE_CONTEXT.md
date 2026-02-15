# 뽀모도로 타이머 - 파이프라인 컨텍스트

> **파이프라인 실행 전 필수 설정 정보**

---

## 🔴 필수 정보

### 프로젝트 소스 경로

```
/Users/leeo/Documents/code/FocusTimer
```

---

## 📋 기술 스택

- **언어**: Swift 5.9+
- **UI 프레임워크**: SwiftUI + AppKit
- **윈도우 타입**: NSPanel (플로팅)
- **최소 지원 버전**: macOS 14.0
- **빌드 도구**: Xcode 15+
- **아키텍처**: MVVM

---

## 📁 프로젝트 구조

```
FocusTimer/
├── FocusTimer/
│   ├── FocusTimerApp.swift      # 앱 엔트리 + NSPanel 설정
│   ├── Models/
│   │   └── TimerState.swift     # 타이머 상태/모드
│   ├── ViewModels/
│   │   └── TimerViewModel.swift # 타이머 로직
│   ├── Views/
│   │   └── TimerView.swift      # 메인 UI
│   └── Utilities/
│       └── NotificationManager.swift # 알림 처리
└── FocusTimer.xcodeproj
```

---

## 🎯 MVP 요구사항

1. 플로팅 윈도우 (항상 최상단, 투명 배경)
2. 25분 집중 / 5분 휴식 타이머
3. 시작/일시정지/리셋 버튼
4. 세션 완료 시 시스템 알림
5. 완료 세션 수 🍅 표시
6. 집중/휴식 모드별 색상 구분

---

## 🎨 디자인 가이드

| 모드 | Primary Color | 의미 |
|------|--------------|------|
| 집중 | #FF6B6B | 코랄 레드 - 집중, 열정 |
| 휴식 | #4ECDC4 | 민트 - 휴식, 안정 |

---

*이 파일은 PixelOffice에서 자동 생성되었습니다.*
