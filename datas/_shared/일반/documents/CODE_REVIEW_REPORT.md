# Token-memo 코드 리뷰 보고서

> **작성일**: 2024-02-03
> **작성자**: 켄트백 (시니어 개발자)
> **프로젝트 경로**: `~/Documents/code/Token-memo` (상대경로: `./`)

---

## 📁 프로젝트 구조

```
Token-memo/
├── ClipKeyboard/                    # iOS 메인 앱
│   ├── Model/Memo.swift            # 데이터 모델
│   ├── Service/                    # 비즈니스 로직
│   │   ├── MemoStore.swift
│   │   ├── CloudKitBackupService.swift
│   │   └── ComboExecutionService.swift
│   ├── Manager/                    # 시스템 관리
│   │   └── DataManager.swift
│   └── Screens/                    # SwiftUI Views
│       ├── List/ClipKeyboardList.swift
│       └── Memo/MemoAdd.swift, MemoDetail.swift
├── ClipKeyboardExtension/          # iOS 키보드 익스텐션
│   ├── KeyboardViewController.swift
│   ├── KeyboardView.swift
│   └── ComboKeyboardView.swift
├── Shared/                         # 공유 모델
└── widget/                         # 위젯
```

---

## 🔴 심각한 문제점 (즉시 수정 필요)

### 1. 메모리 관리 위험

| 파일 | 라인 | 문제 | 영향 |
|------|------|------|------|
| `KeyboardViewController.swift` | 11-19 | 전역 변수로 메모 배열 선언 | 30MB 제한 초과로 크래시 |
| `KeyboardViewController.swift` | 400-477 | 모든 메모를 한 번에 메모리 로드 | 메모리 부족 |
| `ClipKeyboardList.swift` | 11-12 | 전역 변수 `isFirstVisit`, `fontSize` | Race Condition |
| `MemoAdd.swift` | 321, 326 | `DispatchQueue` 클로저에서 `[weak self]` 미사용 | Retain Cycle |

#### 예시 - KeyboardViewController.swift:11-19
```swift
// ❌ 문제: 전역 변수로 선언
var clipKey: [String] = []
var clipValue: [String] = []
var clipMemos: [Memo] = []  // 이미지 포함 시 수 MB

// ✅ 해결: 클래스 프로퍼티로 이동 + lazy loading
class KeyboardViewController: UIInputViewController {
    private lazy var clipMemos: [Memo] = []
}
```

---

### 2. 강제 언래핑 (Force Unwrap) - 크래시 위험

| 파일 | 라인 | 코드 |
|------|------|------|
| `DataManager.swift` | 50, 57, 58 | `UserDefaults(suiteName:)!` |
| `ClipKeyboardList.swift` | 50 | `UserDefaults(suiteName:)!` |
| `MemoAdd.swift` | 210 | `try MemoStore.shared.load()` 에러 시 크래시 |
| `CollectionViewCell.swift` | 52 | `titleLabel.text!` |

#### 해결 방법
```swift
// ❌ 문제
UserDefaults(suiteName: AppConfig.appGroup)!.stringArray(forKey: "entries")

// ✅ 해결
guard let defaults = UserDefaults(suiteName: AppConfig.appGroup) else {
    print("❌ App Group 접근 실패")
    return
}
let entries = defaults.stringArray(forKey: "entries") ?? []
```

---

### 3. 에러 핸들링 부족

| 파일 | 라인 | 문제 |
|------|------|------|
| `MemoStore.swift` | 77, 106, 159 | `try?`로 에러 무시 |
| `MemoStore.swift` | 116-119 | 디코딩 실패 시 빈 배열 반환 (데이터 손실) |
| `KeyboardViewController.swift` | 474-476 | 로드 실패 시 로그만 출력 |
| `MemoAdd.swift` | 330 | `fatalError()` 사용 |

---

### 4. 스레드 안전성 문제

#### MemoStore.swift - Race Condition
```swift
// ❌ 문제: 라인 237-268
var history = try loadSmartClipboardHistory()  // 1. 로드
history.insert(newItem, at: 0)                 // 2. 수정
try saveSmartClipboardHistory(history)         // 3. 저장
// → 로드와 저장 사이에 다른 스레드가 파일 수정 가능

// ✅ 해결: 파일 락 또는 직렬 큐 사용
private let fileQueue = DispatchQueue(label: "com.app.fileQueue")
fileQueue.sync {
    // 파일 작업
}
```

---

## 🟠 높은 우선순위 문제

### 5. 성능 이슈

#### 5.1 N+1 쿼리 패턴 (MemoStore.swift)
```swift
// ❌ 문제: 라인 177-184 - 한 항목 업데이트에 전체 로드/저장
func incrementClipCount(for memoId: UUID) throws {
    var memos = try load(type: .tokenMemo)  // 전체 로드
    memos[index].clipCount += 1
    try save(memos: memos, type: .tokenMemo)  // 전체 저장
}
```

**영향**: 메모 100개일 때 불필요한 99개 직렬화/역직렬화

#### 5.2 정규식 반복 컴파일
| 파일 | 라인 |
|------|------|
| `MemoStore.swift` | 537 |
| `KeyboardViewController.swift` | 490-507 |
| `MemoAdd.swift` | 747-748 |

```swift
// ❌ 문제: 매번 컴파일
guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

// ✅ 해결: static으로 캐싱
private static let placeholderRegex: NSRegularExpression? = {
    try? NSRegularExpression(pattern: "\\{([^}]+)\\}")
}()
```

#### 5.3 과도한 로깅 (KeyboardViewController.swift:438-459)
```swift
// ❌ 문제: 메모 100개 = 1500줄 로그
for (index, item) in temp.enumerated() {
    print("   [\(index)] ID: \(item.id)")
    print("       제목: \(item.title)")
    // ... 15줄 이상
}

// ✅ 해결: DEBUG 빌드에서만 로깅
#if DEBUG
print("📋 메모 \(temp.count)개 로드됨")
#endif
```

---

### 6. 코드 구조 문제

#### 6.1 God Object (Memo.swift)
- **라인 216-410**: 하나의 파일에 Memo, ComboItem, Combo 등 18개+ 필드
- **문제**: 단일 책임 원칙(SRP) 위반

#### 6.2 거대한 파일
| 파일 | 라인 수 | 권장 |
|------|---------|------|
| `MemoAdd.swift` | 2,050줄 | 300줄 |
| `ClipKeyboardList.swift` | 900줄+ | 300줄 |
| `MemoStore.swift` | 1,100줄+ | 300줄 |

#### 6.3 과도한 @State 변수
- `ClipKeyboardList.swift`: 25개+ @State
- `MemoAdd.swift`: 25개+ @State

```swift
// ❌ 문제: 라인 14-59
@State private var showAlert = false
@State private var alertMessage = ""
@State private var selectedMemo: Memo?
// ... 20개 이상

// ✅ 해결: ViewModel로 분리
class ClipKeyboardListViewModel: ObservableObject {
    @Published var showAlert = false
    @Published var alertMessage = ""
}
```

---

### 7. CloudKitBackupService 문제

#### 7.1 임시 파일 정리 누락 (라인 224-231)
```swift
// ❌ 문제: 업로드 후 임시 파일 미삭제
let fileURL = tempDir.appendingPathComponent(filename)
try data.write(to: fileURL)
return CKAsset(fileURL: fileURL)
// 임시 파일 누적 → 디스크 공간 낭비

// ✅ 해결: defer로 정리
defer {
    try? FileManager.default.removeItem(at: fileURL)
}
```

#### 7.2 버전 호환성 검증 없음 (라인 437-439)
```swift
// ❌ 문제: 버전 읽기만 하고 검증 안 함
if let version = record["version"] as? String {
    print("📦 백업 버전: \(version)")
}
// 다른 버전 백업 복원 시 데이터 손상 가능
```

---

## 🟡 중간 우선순위 문제

### 8. 키보드 익스텐션 특수 문제

#### 8.1 메인 스레드 동기 I/O
```swift
// ❌ 문제: viewDidLoad에서 동기 파일 로드
override func viewDidLoad() {
    super.viewDidLoad()
    loadMemos()  // 키보드 표시 지연
}

// ✅ 해결: 백그라운드에서 로드
DispatchQueue.global(qos: .userInitiated).async { [weak self] in
    self?.loadMemos()
    DispatchQueue.main.async {
        self?.updateUI()
    }
}
```

#### 8.2 NotificationCenter 옵저버 누수
```swift
// ❌ 문제: 라인 159-232 - weak self 미사용
NotificationCenter.default.addObserver(...) { notification in
    self.textDocumentProxy.insertText(currentValue)  // 강한 참조
}

// ✅ 해결
NotificationCenter.default.addObserver(...) { [weak self] notification in
    self?.textDocumentProxy.insertText(currentValue)
}

// deinit에서 제거
deinit {
    NotificationCenter.default.removeObserver(self)
}
```

---

### 9. 다국어 지원 불완전

| 파일 | 라인 | 하드코딩된 문자열 |
|------|------|------------------|
| `KeyboardViewController.swift` | 595 | "Nothing to Paste" |
| `KeyboardViewController.swift` | 103 | "Enter text" |
| `KeyboardViewController.swift` | 78 | "Space" |
| `MemoStore.swift` | 1072-1075 | 한국어 주소 키워드만 |

---

### 10. 접근성 문제

- 버튼에 `accessibilityLabel` 누락
- 동적 타입(Dynamic Type) 미지원
- 색상 대비 검토 필요

---

## 📊 종합 요약

### 심각도별 분류

| 심각도 | 개수 | 주요 내용 |
|--------|------|-----------|
| 🔴 Critical | 12 | 메모리 누수, 크래시, Race Condition |
| 🟠 High | 15 | 성능, 에러 핸들링, 코드 구조 |
| 🟡 Medium | 10 | 다국어, 접근성, 코드 중복 |

### 파일별 문제 개수

| 파일 | Critical | High | Medium |
|------|----------|------|--------|
| `MemoStore.swift` | 3 | 5 | 2 |
| `KeyboardViewController.swift` | 4 | 3 | 3 |
| `ClipKeyboardList.swift` | 2 | 4 | 2 |
| `MemoAdd.swift` | 2 | 3 | 2 |
| `CloudKitBackupService.swift` | 1 | 3 | 1 |

---

## ✅ 권장 액션 아이템

### Phase 1: 긴급 수정
- [ ] 강제 언래핑 모두 제거 → guard let 사용
- [ ] 키보드 익스텐션 전역 변수 제거
- [ ] `[weak self]` 누락된 클로저 수정
- [ ] fatalError() 제거 → 사용자 친화적 에러 처리

### Phase 2: 성능 개선
- [ ] 정규식 캐싱 구현
- [ ] N+1 쿼리 패턴 개선
- [ ] 키보드 Lazy Loading 구현
- [ ] DEBUG 로깅 분리

### Phase 3: 리팩토링
- [ ] 거대 파일 분할 (MemoAdd → 컴포넌트 분리)
- [ ] ViewModel 패턴 도입
- [ ] 임시 파일 정리 로직 추가
- [ ] 다국어 지원 완성

### Phase 4: 품질 향상
- [ ] 단위 테스트 작성
- [ ] 접근성 개선
- [ ] 문서화

---

## 📝 참고 사항

- **프로젝트 경로**: `~/Documents/code/Token-memo`
- **App Group**: `group.com.Ysoup.TokenMemo`
- **최소 지원 버전**: iOS 17+
- **아키텍처**: Manager/Service 패턴

---

*이 문서는 코드 리뷰 결과를 기반으로 작성되었으며, 지속적인 업데이트가 필요합니다.*