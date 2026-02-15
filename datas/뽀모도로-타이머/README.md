# 🍅 FocusTimer - 뽀모도로 타이머

> 1인 창업자를 위한 맥용 플로팅 뽀모도로 타이머

![Platform](https://img.shields.io/badge/platform-macOS%2014+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ 특징

- 🎯 **플로팅 윈도우** - 다른 앱 위에 항상 표시
- ⏱️ **뽀모도로 기법** - 25분 집중 + 5분 휴식
- 🎨 **미니멀 디자인** - 반투명 블러 배경
- 🔔 **시스템 알림** - 세션 완료 알림
- 🍅 **세션 트래킹** - 완료한 세션 카운트

## 📸 스크린샷

```
┌─────────────────────────────┐
│     ░░ 블러 배경 ░░          │
│                             │
│         25:00               │
│         집중 중              │
│                             │
│      ▶   ⏸   ↺             │
│                             │
│      🍅🍅🍅                  │
└─────────────────────────────┘
```

## 🚀 설치 및 실행

```bash
# Xcode에서 열기
open FocusTimer.xcodeproj

# 빌드 및 실행
Cmd + R
```

## 🏗️ 기술 스택

- **SwiftUI** - 선언적 UI
- **AppKit (NSPanel)** - 플로팅 윈도우
- **UserNotifications** - 시스템 알림
- **MVVM** - 아키텍처 패턴

## 📁 프로젝트 구조

```
FocusTimer/
├── FocusTimerApp.swift     # 앱 + 플로팅 윈도우
├── Models/
│   └── TimerState.swift    # 타이머 상태
├── ViewModels/
│   └── TimerViewModel.swift # 타이머 로직
├── Views/
│   └── TimerView.swift     # UI
└── Utilities/
    └── NotificationManager.swift # 알림
```

## 🎨 컬러 시스템

| 모드 | 색상 | HEX |
|------|------|-----|
| 집중 | 🔴 코랄 | `#FF6B6B` |
| 휴식 | 🟢 민트 | `#4ECDC4` |

## 📝 라이선스

MIT License

---

*Made with ❤️ by PixelOffice Pipeline*
