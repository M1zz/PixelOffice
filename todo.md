# PixelOffice Todo

## 완료된 작업

- [x] Claude Code CLI 통합 (API 키 없이 대화 가능)
  - ClaudeCodeService.swift 추가: Claude Code CLI를 subprocess로 실행
  - EmployeeChatView.swift: Claude 타입 직원은 Claude Code CLI 우선 사용
- [x] 대화 열기 시 AI가 먼저 인사하도록 구현
  - EmployeeChatView.swift: onAppear에서 messages가 비어있으면 sendGreeting() 호출
  - ClaudeService.swift: isGreeting 파라미터 추가 (인사 프롬프트는 히스토리에 저장하지 않음)
- [x] 회사 워크플로우 시스템 (기획→디자인/개발→QA→마케팅)
- [x] 직원 온보딩 질문 시스템 (물음표 표시)
- [x] 데이터 저장 (직원 추가 후 재빌드해도 유지)
- [x] 밝은 UI 테마
- [x] 네비게이션 클리핑 수정
- [x] 글자 크기 .body 이상으로 확대
- [x] 대화창/직원추가창 독립 윈도우로 변경 (이동/최소화 가능)
- [x] AI 직원이 위키 문서 생성 가능 (~/Documents/PixelOffice-Wiki/)
- [x] 대화 초기화 기능 추가
- [x] 캐릭터 선택 시 우측 상태 패널 실시간 동기화
- [x] 회사 위키 마크다운 렌더링 및 편집 기능
- [x] AI 직원 문서를 부서별 카테고리에 저장 및 부서별 필터 추가

## 예정된 작업

- [ ] 온보딩 질문 답변 UI 구현
- [ ] 프로젝트/태스크 워크플로우 진행 UI

## 진행 중

- [x] 프로젝트별 오피스 분리 구현
  - [x] ProjectEmployee.swift 모델 생성
  - [x] ProjectDepartment.swift 모델 생성
  - [x] Project.swift에 departments 필드 추가 (하위 호환)
  - [x] CompanyStore에 프로젝트 직원 관리 메서드 추가
  - [x] ProjectOfficeView.swift 생성
  - [x] ProjectDepartmentView.swift 생성
  - [x] AddProjectEmployeeView.swift 생성
  - [x] SidebarItem enum 수정 (projectOffice 추가)
  - [x] SidebarView에 프로젝트 하위 메뉴 추가
  - [x] ContentView 라우팅 추가
  - [x] ProjectEmployeeChatView.swift 생성
  - [x] PixelOfficeApp.swift에 새 윈도우 등록
