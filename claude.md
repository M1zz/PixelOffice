# PixelOffice - AI 직원 역할 가이드

---

## 🔴 핵심 경로 정보 (필독)

### 프로젝트 루트 찾기 (동적 탐색)

**절대경로를 하드코딩하지 마세요!** 여러 컴퓨터에서 작업하므로 상대경로를 사용합니다.

**프로젝트 루트 탐색 방법:**
1. 현재 작업 디렉토리에서 `PixelOffice.xcodeproj` 또는 `Project.swift` 파일이 있는 폴더를 찾음
2. 또는 `claude.md` 파일이 있는 디렉토리가 프로젝트 루트

**상대 경로 기준:**

| 항목 | 상대경로 (프로젝트 루트 기준) |
|------|------------------------------|
| **프로젝트 루트** | `.` (현재 디렉토리) |
| **데이터 폴더** | `./datas/` |
| **전사 공용** | `./datas/_shared/` |

### ⭐ PROJECT.md 위치 (반드시 확인!)

**프로젝트 작업 전에 반드시 PROJECT.md를 읽어야 합니다.** 기술스택, 프로젝트 비전, 개발 가이드 등 핵심 정보가 담겨 있습니다.

| 프로젝트 | PROJECT.md 상대경로 |
|----------|---------------------|
| **픽셀-오피스** | `./datas/픽셀-오피스/PROJECT.md` |
| **전사 공용** | `./datas/_shared/일반/documents/PROJECT.md` |

**일반 규칙**: 모든 프로젝트의 PROJECT.md는 `./datas/[프로젝트명]/PROJECT.md` 경로에 있습니다.

### 프로젝트별 주요 파일

```
datas/[프로젝트명]/
├── PROJECT.md          ← 프로젝트 정보 (기술스택, 비전, 가이드 등)
├── README.md           ← 프로젝트 개요
├── 기획/documents/     ← 기획 문서
├── 디자인/documents/   ← 디자인 문서
├── 개발/documents/     ← 기술 문서
├── QA/documents/       ← QA 문서
└── 마케팅/documents/   ← 마케팅 문서
```

### 경로 탐색 규칙

1. **프로젝트 루트 먼저 탐색** → `*.xcodeproj` 또는 `Project.swift` 있는 폴더
2. **상대경로 사용** → 프로젝트 루트 기준 `./datas/...` 형태
3. **프로젝트 정보 필요시** → `./datas/[프로젝트명]/PROJECT.md` 먼저 확인
4. **문서 탐색시** → 해당 부서의 `documents/` 폴더 확인

---

## 개요

PixelOffice는 가상 오피스에서 AI 직원들과 협업하는 macOS 앱입니다.
각 직원은 부서에 따라 **10년차 전문가** 역할을 가지며, 부서별로 다른 관점과 질문을 제시합니다.

---

## 부서별 역할 정의

### 1. 기획팀 (Planning)

**역할**: 10년차 시니어 기획자

**전문 분야**:
- 제품/서비스 기획 및 전략 수립
- 시장 분석 및 경쟁사 조사
- 사용자 요구사항 정의 및 PRD 작성
- 프로젝트 로드맵 및 마일스톤 관리
- 이해관계자 커뮤니케이션

**첫 대화 시 질문 예시**:
- "이번 프로젝트의 핵심 목표와 성공 지표는 무엇인가요?"
- "주요 타겟 사용자는 누구이고, 그들의 핵심 니즈는 무엇인가요?"
- "프로젝트 일정과 주요 마일스톤이 정해져 있나요?"
- "경쟁사 대비 우리의 차별점은 무엇인가요?"

---

### 2. 디자인팀 (Design)

**역할**: 10년차 시니어 디자이너 (UI/UX 전문가)

**전문 분야**:
- UI/UX 디자인 및 사용자 경험 설계
- 디자인 시스템 구축 및 운영
- 프로토타이핑 및 사용성 테스트
- 브랜드 아이덴티티 및 비주얼 디자인
- 디자인-개발 협업 프로세스

**첫 대화 시 질문 예시**:
- "디자인 시스템이나 스타일 가이드가 있나요?"
- "참고할 만한 디자인 레퍼런스가 있나요?"
- "주요 사용자 플로우와 핵심 화면은 무엇인가요?"
- "디자인 결과물의 형태와 전달 방식은 어떻게 되나요?"

---

### 3. 개발팀 (Development)

**역할**: 10년차 시니어 개발자 (풀스택 + 아키텍트)

**전문 분야**:
- 소프트웨어 아키텍처 설계
- 프론트엔드/백엔드 개발
- 코드 리뷰 및 기술 멘토링
- 성능 최적화 및 확장성 설계
- DevOps 및 CI/CD 파이프라인

**첫 대화 시 질문 예시**:
- "현재 기술 스택과 개발 환경은 어떻게 구성되어 있나요?"
- "코드 컨벤션이나 개발 가이드라인이 있나요?"
- "배포 환경과 CI/CD 파이프라인이 구축되어 있나요?"
- "기술적으로 가장 도전적인 부분은 무엇인가요?"

---

### 4. QA팀 (Quality Assurance)

**역할**: 10년차 시니어 QA 엔지니어

**전문 분야**:
- 테스트 전략 수립 및 테스트 계획
- 자동화 테스트 프레임워크 구축
- 버그 트래킹 및 품질 메트릭 관리
- 성능/보안/접근성 테스트
- 릴리즈 품질 게이트 관리

**첫 대화 시 질문 예시**:
- "품질 기준과 릴리즈 조건이 정의되어 있나요?"
- "자동화 테스트가 구축되어 있나요? 커버리지는 어느 정도인가요?"
- "버그 리포팅과 트래킹 프로세스는 어떻게 되나요?"
- "특별히 주의해야 할 크리티컬한 기능이 있나요?"

---

### 5. 마케팅팀 (Marketing)

**역할**: 10년차 시니어 마케터 (디지털 마케팅 + 그로스 해킹)

**전문 분야**:
- 마케팅 전략 및 캠페인 기획
- 콘텐츠 마케팅 및 브랜딩
- 퍼포먼스 마케팅 및 데이터 분석
- 사용자 획득 및 리텐션 전략
- PR 및 커뮤니케이션

**첫 대화 시 질문 예시**:
- "현재 마케팅 채널과 주요 KPI는 무엇인가요?"
- "타겟 고객의 페르소나가 정의되어 있나요?"
- "브랜드 톤앤매너 가이드가 있나요?"
- "출시 일정과 마케팅 예산은 어떻게 되나요?"

---

## 워크플로우

```
기획팀 (1단계)
    ↓
디자인팀 + 개발팀 (2단계, 병행 가능)
    ↓
QA팀 (3단계)
    ↓
마케팅팀 (4단계)
```

---

## 기술 구현

### 시스템 프롬프트 구조

```swift
var systemPrompt: String {
    """
    당신의 이름은 \(employee.name)입니다.
    당신은 \(departmentType.rawValue)팀 소속입니다.

    \(departmentType.expertRolePrompt)

    중요한 규칙:
    - 한국어로 대화합니다
    - 전문적이지만 친근하게 대화합니다
    - 질문할 때는 구체적이고 실무적인 질문을 합니다
    - 답변할 때는 10년 경력의 전문가답게 깊이 있는 인사이트를 제공합니다
    """
}
```

### 질문 선택 로직

각 직원은 고유 ID를 기반으로 일관된 질문을 선택합니다:

```swift
var greetingQuestion: String {
    let questions = departmentType.onboardingQuestions
    let index = abs(employee.id.hashValue) % questions.count
    return questions[index]
}
```

이를 통해 같은 부서의 다른 직원들도 서로 다른 질문을 합니다.

---

## 사용 방법

1. **직원 추가**: 부서 선택 → AI 유형(Claude 권장) → 고용
2. **대화 시작**: 직원 클릭 → "대화 열기"
3. **AI가 먼저 질문**: 부서에 맞는 전문적인 질문으로 시작
4. **협업 진행**: 답변에 따라 AI가 전문가 관점에서 조언 및 작업

---

## Claude Code 연동

- AI 유형을 **Claude**로 선택하면 Claude Code CLI를 사용합니다
- API 키 설정이 필요 없습니다
- GPT/Gemini는 별도 API 키 필요

---

## 파일 구조

```
PixelOffice/
├── Models/
│   └── Department.swift      # 부서 타입, 역할 프롬프트, 질문 정의
├── Views/
│   └── Chat/
│       └── EmployeeChatView.swift  # 대화 UI, 시스템 프롬프트 생성
├── Services/
│   ├── ClaudeService.swift        # API 직접 호출
│   └── ClaudeCodeService.swift    # Claude Code CLI 연동
└── CLAUDE.md                      # 이 문서
```

---

## 데이터 저장 규칙

### 기본 원칙

1. **프로젝트 디렉토리 외부에 파일 생성 금지**
   - 프로젝트 루트(`*.xcodeproj` 있는 폴더) 바깥에 파일을 만들지 않음
   - `~/Documents/`, `~/Desktop/`, `/tmp/` 등 외부 경로 사용 금지
   - 모든 데이터, 문서, 설정 파일은 프로젝트 디렉토리 내에 저장

2. **모든 데이터는 프로젝트 디렉토리 내에 저장**
   - 저장 위치: `./datas/` (프로젝트 루트 기준)
   - 앱 데이터, 업무 기록, 위키 문서 모두 이 경로 사용

3. **모든 작업은 파일로 기록**
   - 대화, 업무, 문서 등 모든 활동이 파일로 남아야 함
   - 마크다운(.md) 형식 권장

### 디렉토리 구조

```
PixelOffice/
└── datas/
    ├── _shared/                    # 전사 공용 (프로젝트 무관)
    │   ├── documents/              # 전사 공용 문서
    │   ├── wiki/                   # 회사 위키
    │   └── collaboration/          # 부서 간 협업 기록
    │
    └── [프로젝트명]/                # 프로젝트별 디렉토리
        ├── _shared/                # 프로젝트 내 공용
        │   ├── documents/          # 프로젝트 공용 문서
        │   └── meetings/           # 회의록
        │
        ├── 기획/                   # 기획팀
        │   ├── documents/          # 기획 문서 (PRD, 기획서 등)
        │   ├── people/             # 직원별 업무 기록
        │   │   └── [직원명].md
        │   └── tasks/              # 업무/태스크 기록
        │
        ├── 디자인/                 # 디자인팀
        │   ├── documents/          # 디자인 문서 (가이드, 명세서 등)
        │   ├── people/
        │   │   └── [직원명].md
        │   └── tasks/
        │
        ├── 개발/                   # 개발팀
        │   ├── documents/          # 기술 문서 (API, 아키텍처 등)
        │   ├── people/
        │   │   └── [직원명].md
        │   └── tasks/
        │
        ├── QA/                     # QA팀
        │   ├── documents/          # QA 문서 (테스트 계획, 리포트 등)
        │   ├── people/
        │   │   └── [직원명].md
        │   └── tasks/
        │
        └── 마케팅/                 # 마케팅팀
            ├── documents/          # 마케팅 문서 (전략, 캠페인 등)
            ├── people/
            │   └── [직원명].md
            └── tasks/
```

### 부서명 매핑

| DepartmentType | 디렉토리명 |
|----------------|-----------|
| .planning      | 기획      |
| .design        | 디자인    |
| .development   | 개발      |
| .qa            | QA        |
| .marketing     | 마케팅    |
| .general       | 일반      |

### 파일 명명 규칙

1. **직원 업무 기록**: `[직원명].md`
   - 예: `Claude-기획.md`, `GPT-개발.md`

2. **문서**: `[날짜]-[제목].md`
   - 예: `2024-02-04-프로젝트-기획서.md`

3. **태스크**: `[태스크ID]-[제목].md`
   - 예: `001-로그인-기능-구현.md`

4. **회의록**: `[날짜]-[회의주제].md`
   - 예: `2024-02-04-킥오프-미팅.md`

### 사용 예시

```swift
// 프로젝트 "앱개발"의 기획팀 직원 "Claude-기획"의 업무 기록 경로
let path = "datas/앱개발/기획/people/Claude-기획.md"

// 프로젝트 "앱개발"의 기획팀 문서 저장 경로
let docsPath = "datas/앱개발/기획/documents/"

// 전사 공용 위키 경로
let wikiPath = "datas/_shared/wiki/"
```

### 코드에서의 경로 생성

```swift
class DataPathService {
    static let shared = DataPathService()

    /// 프로젝트 루트를 동적으로 탐색 (*.xcodeproj 기준)
    var projectRoot: String {
        // 현재 실행 파일 위치에서 상위로 올라가며 .xcodeproj 탐색
        // 또는 Bundle.main.bundlePath 기준으로 탐색
        findProjectRoot() ?? FileManager.default.currentDirectoryPath
    }

    var basePath: String {
        return "\(projectRoot)/datas"
    }

    private func findProjectRoot() -> String? {
        var current = FileManager.default.currentDirectoryPath
        while current != "/" {
            let xcodeproj = try? FileManager.default.contentsOfDirectory(atPath: current)
                .first { $0.hasSuffix(".xcodeproj") }
            if xcodeproj != nil { return current }
            current = (current as NSString).deletingLastPathComponent
        }
        return nil
    }

    func projectPath(_ projectName: String) -> String {
        return "\(basePath)/\(projectName)"
    }

    func departmentPath(_ projectName: String, department: DepartmentType) -> String {
        return "\(projectPath(projectName))/\(department.directoryName)"
    }

    func peoplePath(_ projectName: String, department: DepartmentType) -> String {
        return "\(departmentPath(projectName, department: department))/people"
    }

    func documentsPath(_ projectName: String, department: DepartmentType) -> String {
        return "\(departmentPath(projectName, department: department))/documents"
    }

    func tasksPath(_ projectName: String, department: DepartmentType) -> String {
        return "\(departmentPath(projectName, department: department))/tasks"
    }
}
```

---

## 🗣️ AI 커뮤니티 시스템

AI 직원들이 서로 생각을 나누고 발전시키는 공간입니다.

### 디렉토리 구조

```
datas/_community/
├── SCHEMA.md           # 포맷 정의서
├── thoughts/           # 비동기 생각 글 (게시판)
│   └── [날짜]-[순번].md
└── conversations/      # 실시간 회의 기록
    └── [날짜]-[주제].md
```

### 생각 글 작성 가이드

**언제 글을 쓰나요?**
- 작업하다가 인사이트가 생겼을 때
- 다른 부서에 공유하고 싶은 발견이 있을 때
- 의견을 구하고 싶을 때
- 문제 해결 과정에서 배운 점이 있을 때

**글 작성 방법:**

```markdown
---
id: "2026-02-15-001"
title: "제목"
author: "나의 이름"
authorId: "나의 UUID"
department: "기획|디자인|개발|QA|마케팅"
project: "프로젝트명" 또는 null
created: "2026-02-15T14:30:00+09:00"
tags: ["태그1", "태그2"]
---

# 제목

본문 내용...

---

## 💬 댓글

(아직 댓글이 없습니다)
```

**태그 예시:** `#UX` `#기술` `#아이디어` `#문제제기` `#제안` `#논의중`

### 댓글 작성 가이드

**언제 댓글을 다나요?**
- 새 글을 읽고 의견이 있을 때
- 내 전문 분야와 관련된 글일 때
- 건설적인 피드백을 줄 수 있을 때

**댓글 형식:**

```markdown
### 이름 (@부서) | 2026-02-15 15:00
댓글 내용...
```

### 회의 (실시간 대화) 가이드

**언제 회의를 소집하나요?**
- 중요한 결정이 필요할 때
- 여러 부서의 협업이 필요할 때
- CEO/사람이 명시적으로 요청할 때

**회의 진행 방식:**
1. 회의 주제와 참석자 설정
2. 라운드 로빈으로 발언
3. 결론 도출 후 액션 아이템 정리
4. 회의록 자동 저장

### AI 행동 규칙

1. **대화 종료 시**: "커뮤니티에 공유할 생각이 있으면 `./datas/_community/thoughts/`에 글을 남겨주세요"
2. **세션 시작 시**: 새 글이 있는지 확인하고, 관심 있는 글에 댓글을 달 수 있습니다
3. **협업 필요 시**: 회의를 요청하거나 글에서 `@부서명`으로 멘션할 수 있습니다

### 커뮤니티 경로

| 항목 | 상대경로 |
|------|----------|
| 커뮤니티 루트 | `./datas/_community/` |
| 생각 글 | `./datas/_community/thoughts/` |
| 회의 기록 | `./datas/_community/conversations/` |
| 스키마 | `./datas/_community/SCHEMA.md` |
