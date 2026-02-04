# PixelOffice Todo

## 완료된 작업

- [x] 직원 간 멘션 협업 시스템
  - 시스템 프롬프트에 멘션 기능 설명 추가
  - `<<<MENTION:@부서명>>>...<<<END_MENTION>>>` 형식 지원
  - 멘션 감지 시 해당 부서 직원에게 자동 요청 전달
  - 응답을 원래 대화에 통합 표시
  - EmployeeChatView, ProjectEmployeeChatView 모두 적용
- [x] @ 멘션 자동완성 피커 추가
  - @ 입력 시 멘션 가능한 부서 목록 표시
  - MentionPickerView 컴포넌트 추가
  - ChatInputView에 @ 버튼 추가
- [x] 부서 간 협업 기록 시스템
  - CollaborationRecord.swift 모델 생성
  - 멘션 요청/응답 자동 기록
  - CollaborationHistoryView 뷰 생성
  - 사이드바에 "협업 기록" 메뉴 추가
  - 부서/프로젝트별 필터, 검색 기능
  - 협업 상세 보기 및 복사 기능
- [x] 직원 상태 변경 시 UI 동기화 및 알림
  - 상태 변경 시 company 재할당으로 @Published 트리거
  - ToastManager 추가: 토스트 메시지 표시
  - 시스템 알림(UserNotifications) 연동
  - ContentView에 토스트 오버레이 적용
- [x] 오피스 탭 제거 및 UI 정리
  - 상단 "오피스" 탭 제거
  - "전체 프로젝트" → "오피스"로 변경 (building.2.fill 아이콘)
  - SidebarItem enum에서 office case 제거
  - 기본 탭을 projects로 변경
- [x] 직원 상태 중앙 집중식 관리
  - CompanyStore에 `employeeStatuses: [UUID: EmployeeStatus]` 추가
  - 상태 변경 시 중앙 저장소 + 데이터 모델 동시 업데이트
  - `objectWillChange.send()` 호출로 UI 동기화 보장
  - 직원 추가 시 중앙 저장소에 자동 등록
- [x] 업무 결과 문서화 기능 강화
  - 시스템 프롬프트에 부서별 문서 형식 가이드 추가
  - 대화창 헤더에 "문서화" 버튼 추가 (📄 아이콘)
  - 버튼 클릭 시 AI가 대화 내용을 정리하여 위키에 자동 저장
  - EmployeeChatView, ProjectEmployeeChatView 모두 적용
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

## 최근 완료 (2024-02-04)

- [x] 직원 사고 축적 & 커뮤니티 게시 시스템
  - EmployeeThinking.swift 모델 생성 (사고 과정, 입력, 추론, 결론)
  - CommunityPost.swift 모델 생성 (게시글, 댓글, 좋아요)
  - Company 모델에 employeeThinkings, communityPosts 추가
  - CompanyStore에 사고/게시글 관리 메서드 추가
  - CommunityView "생각" 탭에서 직원 게시글 표시
  - CommunityPostCard, CommunityPostDetailView 컴포넌트 추가
  - 가이드 탭 추가 (사장님 매뉴얼 접근)

- [x] EmployeeChatView 사고 축적 연동
  - 시스템 프롬프트에 <<<INSIGHT>>>...<<<END_INSIGHT>>> 형식 추가
  - extractAndProcessInsights() 메서드로 인사이트 자동 추출
  - 준비도 점수 계산 (인사이트 수, 입력 수, 포화 상태 기반)
  - 8/10 이상 시 자동 결론 생성 및 커뮤니티 게시
  - ChatHeader에 사고 상태 표시 (인사이트 수, 준비도)

- [x] 사이드바 정리
  - 회사 위키 탭 제거 (프로젝트별 위키로 이동)
  - 협업 기록 탭 제거 (프로젝트 오피스 버튼으로 이동)

- [x] 프로젝트별 위키 시스템
  - ProjectWikiView.swift 생성 (프로젝트별 독립 위키)
  - DataPathService에 projectWikiPath() 추가
  - ProjectOfficeView 헤더에 "위키" 버튼 추가 (칸반 보드 옆)
  - 툴바에도 위키 버튼 추가
  - PixelOfficeApp.swift에 프로젝트 위키 윈도우 등록
  - 위키 경로: datas/[프로젝트명]/wiki/

- [x] 커뮤니티 탭 "사원증" → "사원들" 변경
  - CommunityFilter enum에서 badges → employees로 변경
  - 아이콘 person.crop.rectangle → person.2로 변경

- [x] 직원 클릭 시 사원증 보기 기능
  - OfficeView.swift ActionsCard에 "사원증 보기" 버튼 추가
  - ProjectOfficeView.swift ProjectEmployeeActionsCard에 "사원증 보기" 버튼 추가
  - 클릭 시 sheet으로 EmployeeBadgeView 표시

- [x] 사장님 매뉴얼 문서 작성
  - 문서 기반 협업 원칙 설명
  - 프로젝트 구조 가이드
  - 부서별 업무 가이드 (기획/디자인/개발/QA/마케팅)
  - 워크플로우 파이프라인 설명
  - 실전 예시 및 고급 팁
  - 저장 위치: datas/_shared/documents/사장님-매뉴얼.md

- [x] 직원 사원번호 시스템
  - Employee.swift에 employeeNumber 필드 추가 (EMP-XXXX 형식)
  - ProjectEmployee.swift에 employeeNumber 필드 추가 (PRJ-XXXX 형식)
  - UUID 기반 자동 생성 (기존 데이터 호환)

- [x] 사원증 뷰 생성
  - EmployeeBadgeView.swift 생성
  - 픽셀 캐릭터 사진, 이름, 사원번호, 부서, AI타입, 입사일 표시
  - PixelCharacterLarge 컴포넌트 (사원증용 큰 픽셀 캐릭터)
  - 하단 바코드 디자인

- [x] 커뮤니티 탭 추가
  - CommunityView.swift 생성 (직원 생각, 소통, 사원증 보기)
  - SidebarItem에 community case 추가
  - SidebarView에 "커뮤니티" 버튼 추가 (협업 기록 아래)
  - 필터 탭: 전체, 생각, 소통, 사원증

- [x] 문서 작성 시 README 참조 안내
  - EmployeeChatView.swift: documentsInfo에 README.md 필수 확인 안내 추가
  - ProjectEmployeeChatView.swift: projectDocumentsInfo에 README.md 경로 및 필수 확인 안내 추가
  - 모든 직원이 문서 작성 전 프로젝트 README.md를 참조하도록 시스템 프롬프트 업데이트

## 최근 완료

- [x] 휴식 중인 직원 걸어다니기 애니메이션
  - WalkingCharacter.swift 생성 (다리 움직임 애니메이션)
  - WalkingEmployeesLayer.swift 생성 (휴식 중인 직원들 관리)
  - 직원이 휴식 중(idle)일 때 자기 책상 주변을 걸어다님
  - 각 직원의 책상 위치 기억하여 반경 60px 내에서만 이동
  - OfficeView, ProjectOfficeView에 적용
  - 직원에 마우스 호버 시 이름 표시
  - 작업 중일 때는 책상에 앉아있고, 휴식 중일 때만 걸어다님 (DeskView 수정)
  - 걸어다니는 직원 클릭 시 상세 패널 표시 (책상 클릭과 동일)
  - onEmployeeSelect 콜백 추가 (OfficeView, ProjectOfficeView)
  - X축 또는 Y축 한 방향으로만 이동 (대각선 이동 제거)
  - 각 직원이 랜덤한 타이밍에 독립적으로 움직임 (걷다 멈추다 반복)
  - 멈췄을 때 걷기 애니메이션 정지 (서있는 자세 유지)

- [x] 픽셀아트 생각 말풍선 추가
  - PixelThoughtBubble 컴포넌트 추가 (구름 모양 픽셀아트)
  - 부서별 업무 관련 생각 목록 (기획, 디자인, 개발, QA, 마케팅)
  - 랜덤 타이밍으로 생각 말풍선 표시 (3~6초 표시, 5~15초 간격)
  - WalkingEmployeeState에 생각 상태 관리 추가

- [x] 위키 문서 부서별 documents 폴더 동기화
  - AI가 작성한 문서를 datas/[프로젝트]/[부서]/documents/에도 저장
  - 전사 직원 문서는 datas/_shared/[부서]/documents/에 저장
  - 앱 시작 시 기존 위키 문서 파일 시스템에 자동 동기화
  - DataPathService에 부서별 공용 문서 폴더 자동 생성 추가

- [x] 프로젝트 문서 경로 시스템 프롬프트에 추가
  - 직원이 프로젝트 문서 위치를 인지하도록 시스템 프롬프트 업데이트
  - 부서별 문서 경로 안내 (documents/, people/, tasks/)
  - 다른 부서 문서 참고 경로 안내
  - 프로젝트 생성 시 README.md 자동 생성 (문서 구조 안내)

- [x] 걸어다니는 반경 확대
  - walkRadius를 60에서 120으로 확대

- [x] PixelOffice-Wiki 폴더 사용 제거
  - 문서를 wiki 폴더 대신 부서별 documents 폴더에만 저장
  - ProjectEmployeeChatView, EmployeeChatView에서 WikiService.saveDocument 호출 제거
  - 문서 경로: datas/[프로젝트]/[부서]/documents/ 또는 datas/_shared/[부서]/documents/

- [x] 직원 프로필 자동 생성 및 업무 기록
  - EmployeeProfile 구조체 추가 (이름, AI유형, 부서, 입사일, 외모 설명)
  - 직원 고용 시 자동으로 MD 프로필 파일 생성
  - 프로필에 외모 묘사 포함 (피부톤, 헤어스타일, 머리색, 셔츠색, 악세서리)
  - 대화할 때마다 업무 기록 및 통계 업데이트 (총 대화 수, 마지막 활동일)
  - 앱 시작 시 기존 직원 프로필 자동 생성 (없는 경우)
  - 저장 위치: datas/_shared/people/ (전사), datas/[프로젝트]/[부서]/people/ (프로젝트별)

- [x] 데이터 저장 경로 통합
  - DataPathService.swift 생성 (경로 관리 중앙화)
  - 모든 데이터를 프로젝트 디렉토리/datas/에 저장
  - 디렉토리 구조: datas/[프로젝트]/[부서]/{documents,people,tasks}
  - CLAUDE.md에 데이터 저장 규칙 문서화
  - EmployeeWorkLogService 업데이트 (새 경로 사용)
  - CompanyStore.init()에서 기존 프로젝트 디렉토리 자동 생성
  - CompanyStore.addProject()에서 새 프로젝트 디렉토리 자동 생성

- [x] 직원 업무 기록 뷰어
  - EmployeeWorkLogView.swift 생성
  - 직원 상세 패널에 "업무 기록" 버튼 추가
  - 프로젝트 직원에도 동일하게 적용
  - 목록 보기 / 마크다운 원본 보기 토글
  - 파일 열기 / Finder에서 보기 기능
  - PixelOfficeApp.swift에 윈도우 등록

- [x] 부서별 스킬 커스터마이징 시스템
  - DepartmentSkills.swift 모델 생성 (부서별 역할, 전문 분야, 작업 스타일)
  - DepartmentSkillsView.swift UI 생성 (보기/편집 모드)
  - CompanyStore에 스킬 관리 메서드 추가 (get/update/reset)
  - SettingsView에 "부서 스킬" 탭 추가
  - EmployeeChatView, ProjectEmployeeChatView에 커스텀 스킬 적용

- [x] 직원 업무 기록 MD 파일 시스템
  - EmployeeWorkLogService.swift 생성
  - ~/Documents/PixelOffice-WorkLogs/에 직원별 MD 파일 저장
  - 대화 저장 시 자동으로 업무 기록 추가
  - 시스템 프롬프트에 이전 업무 기록 요약 포함
  - EmployeeChatView, ProjectEmployeeChatView에 적용

- [x] 칸반 보드 태스크 관리 (프로젝트별)
  - KanbanView.swift 생성 (드래그앤드롭 지원)
  - KanbanColumn: 상태별 열 (할 일, 진행 중, 검토, 완료, 차단됨)
  - KanbanTaskCard: 태스크 카드 (부서, 담당자, 워크플로우 표시)
  - AddTaskView: 태스크 추가 폼
  - TaskDetailView: 태스크 상세/수정 뷰
  - ProjectOfficeView 툴바에 칸반 버튼 추가
  - ProjectCard에 칸반 바로가기 버튼 추가
  - PixelOfficeApp.swift에 칸반 윈도우 등록

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
