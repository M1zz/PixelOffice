# PixelOffice 리팩토링 진행 상황

## 📅 시작일: 2026-02-05

---

## ✅ Phase 1: Repository Layer (진행 중)

### 목표
- Thread-safe 파일 I/O 레이어 구축
- 캐싱 기능 제공
- 데이터 접근 추상화

### 완료된 작업

#### 1. Base 레이어 생성 ✅
- **RepositoryProtocol.swift** (55줄)
  - 모든 Repository의 기본 프로토콜 정의
  - CRUD 인터페이스 표준화
  - RepositoryError enum 정의

- **FileRepository.swift** (185줄)
  - Thread-safe actor 기반 구현
  - 60초 캐싱 메커니즘
  - 자동 디렉토리 생성
  - Pretty-printed JSON 저장
  - 풍부한 로깅

#### 2. Domain-specific Repositories ✅

**EmployeeRepository.swift** (95줄)
- 부서별 직원 저장소 관리
- 경로: `datas/_shared/{부서}/people/employees.json`
- 멀티-Repository 패턴 (부서별 독립)

**ProjectRepository.swift** (160줄)
- 프로젝트 저장소 관리
- 경로: `datas/projects.json`
- 프로젝트 직원 저장소 (ProjectEmployeeRepository)
- 프로젝트별 디렉토리 자동 생성

**TaskRepository.swift** (95줄)
- 프로젝트별 태스크 저장소 관리
- 경로: `datas/{프로젝트}/tasks/tasks.json`
- 상태/부서/담당자별 필터링 지원

**WikiRepository.swift** (155줄)
- 위키 문서 저장소 관리
- JSON + Markdown 이중 저장
- 부서/프로젝트별 문서 분류
- 검색 기능

### 파일 구조

```
PixelOffice/Repositories/
├── Base/
│   ├── RepositoryProtocol.swift      ✅ (55줄)
│   └── FileRepository.swift          ✅ (185줄)
├── EmployeeRepository.swift          ✅ (95줄)
├── ProjectRepository.swift           ✅ (160줄)
├── TaskRepository.swift              ✅ (95줄)
└── WikiRepository.swift              ✅ (155줄)
```

**총 라인 수**: 745줄

### 핵심 기능

#### Thread-Safety
```swift
actor FileRepository<T: Codable & Identifiable> {
    // 모든 파일 I/O가 actor 내부에서 순차 실행
    // 동시성 문제 완전 해결
}
```

#### 캐싱
```swift
private var cache: [T.ID: T] = [:]
private var cacheTimestamp: Date?
private let cacheExpiration: TimeInterval = 60

// 60초 이내 재조회 시 파일 I/O 없이 캐시 사용
```

#### 에러 처리
```swift
enum RepositoryError: LocalizedError {
    case fileNotFound(path: String)
    case decodingFailed(String)
    case encodingFailed(String)
    case saveFailed(String)
    case deleteFailed(String)
    case invalidData(String)
}
```

### 남은 작업

- [ ] Xcode 프로젝트에 파일 추가 (REPOSITORY_SETUP.md 참고)
- [ ] 빌드 테스트
- [ ] 기존 코드와 통합 테스트 (Phase 3에서)

---

## ⏳ Phase 2: Models 정리 (예정)

### 목표
- Employee.swift: 689줄 → 150줄
- Department.swift: 357줄 → 60줄
- UI 속성 분리 (Presentation 폴더)
- 생성 로직 분리 (Factory 패턴)

### 계획된 작업

1. **순수 데이터 모델**
   - `Employee.swift` 순수 데이터만 (150줄)
   - `Department.swift` 순수 데이터만 (60줄)
   - `EmployeeProtocol.swift` 공통 인터페이스

2. **Factory 레이어**
   - `EmployeeFactory.swift` (200줄) - 직원 생성 로직
   - `DepartmentPromptBuilder.swift` (150줄) - 프롬프트 생성

3. **Presentation 레이어**
   - `AITypePresentation.swift` - icon, color 등
   - `DepartmentTypePresentation.swift` - UI 속성
   - `EmployeeStatusPresentation.swift` - 상태 UI

---

## ⏳ Phase 3: Services 분리 (예정)

### 목표
- CompanyStore 분해: 961줄 → 8개 Store (평균 ~150줄)
- EventBus 패턴 도입
- Repository 통합

### 계획된 Store 구조

```
AppStore (Root)
├── EmployeeStore         (~150줄)
├── ProjectStore          (~200줄)
├── TaskStore             (~150줄)
├── WikiStore             (~100줄)
├── CommunityStore        (~150줄)
├── PermissionStore       (~100줄)
├── CompanySettingsStore  (~100줄)
└── CollaborationStore    (~80줄)
```

---

## ⏳ Phase 4-6: ViewModels & Views & Tests (예정)

- EmployeeChatView: 1,740줄 → 300줄
- ViewModel 레이어 도입
- 컴포넌트 분리
- 테스트 커버리지 80%+

---

## 📊 전체 진행률

- **Phase 1**: 95% ✅ (파일 생성 완료, Xcode 추가 대기)
- **Phase 2**: 0% ⏳
- **Phase 3**: 0% ⏳
- **Phase 4**: 0% ⏳
- **Phase 5**: 0% ⏳
- **Phase 6**: 0% ⏳

**전체 진행률**: ~15%

---

## 🎯 다음 액션

1. **즉시**: Xcode에서 Repository 파일 추가 (REPOSITORY_SETUP.md 참고)
2. **빌드 테스트**: 컴파일 에러 없는지 확인
3. **Phase 2 시작**: Employee.swift 리팩토링

---

## 📝 학습 내용 (MEMORY.md에 추가 예정)

### Actor 기반 Thread-safe Repository 패턴
```swift
actor FileRepository<T: Codable & Identifiable> {
    // ✅ 모든 메서드가 자동으로 thread-safe
    // ✅ await로 순차 실행 보장
    // ✅ 캐싱으로 성능 최적화
}
```

### Repository 설계 원칙
1. **단일 책임**: 각 Repository는 하나의 엔티티만 관리
2. **추상화**: 파일 I/O 세부사항 숨김
3. **Thread-safe**: Actor로 동시성 문제 해결
4. **캐싱**: 불필요한 파일 I/O 최소화
5. **에러 처리**: 명확한 에러 타입과 메시지

### 성능 최적화
- 60초 캐시로 반복 조회 시 파일 I/O 제거
- Actor 큐로 순차 처리하여 파일 손상 방지
- Pretty-printed JSON으로 디버깅 용이성 확보
