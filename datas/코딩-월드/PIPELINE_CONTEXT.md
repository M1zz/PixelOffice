# 코딩 월드 - 파이프라인 컨텍스트

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
# 프로젝트 루트에서 실행 (프로젝트에 맞게 수정하세요)
xcodebuild -project [프로젝트명].xcodeproj -scheme [스킴명] -configuration Debug build
```

---

## 📋 기술 스택

### 언어 및 프레임워크

- **언어**: Swift
- **프레임워크**: SwiftUI
- **최소 지원 버전**: macOS 14.0 / iOS 17.0

### 빌드 도구

- **빌드 시스템**: Xcode
- **패키지 매니저**: SPM (Swift Package Manager)

---

## 📁 프로젝트 구조

> 프로젝트 구조를 여기에 작성하세요.

---

## 🎯 코딩 컨벤션

- **타입**: PascalCase
- **변수/함수**: camelCase
- **아키텍처**: MVVM

---

## ⚠️ 주의사항

- 프로젝트 루트 외부에 파일 생성 금지
- 모든 데이터는 `datas/` 폴더에 저장

---

## 📚 참고 문서 (상대경로, 프로젝트 루트 기준)

- **claude.md**: `./claude.md`
- **PROJECT.md**: `./datas/코딩-월드/PROJECT.md`

---

*이 파일은 PixelOffice에서 자동 생성되었습니다.*