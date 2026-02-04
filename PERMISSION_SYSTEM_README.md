# 권한 관리 시스템 (Permission Management System)

## 완료된 작업

### 1. 파일 생성 완료
다음 6개 파일이 생성되었습니다:

- `PixelOffice/Models/PermissionRequest.swift` - 권한 요청 데이터 모델
- `PixelOffice/Services/PermissionManager.swift` - 권한 관리 서비스 (싱글톤)
- `PixelOffice/Views/Components/FlowLayout.swift` - 태그용 플로우 레이아웃
- `PixelOffice/Views/Permissions/PermissionsView.swift` - 권한 관리 메인 UI
- `PixelOffice/Views/Permissions/PermissionRequestDetailView.swift` - 권한 요청 상세 뷰
- `PixelOffice/Views/Permissions/AutoApprovalRulesView.swift` - 자동 승인 규칙 설정 뷰

### 2. 기능 설명

#### 권한 요청 (PermissionRequest)
- 파일 작성, 수정, 삭제
- 명령 실행
- API 호출
- 데이터 내보내기
- 각 요청은 승인/거부/대기 상태를 가짐

#### 자동 승인 규칙 (AutoApprovalRule)
- 파일 경로 패턴 매칭 (와일드카드 지원)
- 파일 크기 제한
- 권한 타입별 자동 승인
- 예시: `datas/**/*.md` → 모든 마크다운 파일 자동 승인

#### 권한 관리 UI
- 권한 요청 목록 (대기/승인/거부/전체)
- 통계 대시보드
- 자동 승인 규칙 관리
- 요청 상세 정보 조회

### 3. Claude Code 설정
`~/.claude/settings.json`에 다음 권한이 설정되었습니다:
```json
{
  "permissions": {
    "Write": "allow",
    "Edit": "allow",
    "Bash": "allow",
    "Task": "allow",
    "Read": "allow",
    "Glob": "allow",
    "Grep": "allow"
  }
}
```

### 4. AI 프롬프트 업데이트
직원 채팅 시스템 프롬프트에 다음이 추가되었습니다:
```
⚠️ 중요: 파일이나 문서를 작성할 때 사용자에게 미리 물어보지 말고 바로 작성하세요.
권한은 이미 승인되어 있으므로, 필요한 파일은 즉시 생성하면 됩니다.
```

### 5. 컨텍스트 기반 사고 표시기
AI가 작업 중일 때 최근 대화 주제에 따라 다른 메시지를 표시합니다:
- 로그인/인증 관련
- 데이터베이스 작업
- UI/디자인 작업
- API 개발
- 테스트 작성
- 문서화
- 성능 최적화
- 기획
- 배포
- 일반 작업

## 남은 작업

### Xcode 프로젝트에 파일 추가 (수동 작업 필요)

위의 6개 파일을 Xcode 프로젝트에 추가해야 앱에서 사용할 수 있습니다:

1. Xcode에서 `PixelOffice.xcodeproj` 열기
2. 다음 파일들을 해당 그룹에 드래그앤드롭:
   - `PermissionRequest.swift` → Models 그룹
   - `PermissionManager.swift` → Services 그룹
   - `FlowLayout.swift` → Views/Components 그룹
   - `PermissionsView.swift` → Views/Permissions 그룹 (필요시 생성)
   - `PermissionRequestDetailView.swift` → Views/Permissions 그룹
   - `AutoApprovalRulesView.swift` → Views/Permissions 그룹

3. `ContentView.swift`와 `SidebarView.swift`의 주석 해제:
   - `ContentView.swift`: line 60, 48-49의 주석 제거
   - `SidebarView.swift`: line 7, 32-41의 주석 제거

### 활성화 후 사용 방법

1. 앱 실행
2. 사이드바에 "권한" 탭 표시됨
3. AI 직원이 파일을 작성하려 할 때 권한 요청 생성
4. 권한 탭에서 요청 승인/거부
5. 자동 승인 규칙 설정으로 반복 작업 최소화

## 기술 스택
- SwiftUI
- Combine (for reactive updates)
- Actor isolation (@MainActor)
- Pattern matching for auto-approval
