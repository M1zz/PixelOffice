# Repository Layer 설정 가이드

## 📁 생성된 파일

다음 Repository 레이어 파일들이 생성되었습니다:

```
PixelOffice/Repositories/
├── Base/
│   ├── RepositoryProtocol.swift  ✅
│   └── FileRepository.swift      ✅
├── EmployeeRepository.swift      ✅
├── ProjectRepository.swift       ✅
├── TaskRepository.swift          ✅
└── WikiRepository.swift          ✅
```

## 🔧 Xcode 프로젝트에 파일 추가하기

### 방법 1: Xcode에서 수동 추가 (권장)

1. Xcode를 엽니다:
   ```bash
   open PixelOffice.xcodeproj
   ```

2. Project Navigator에서 `PixelOffice` 그룹을 우클릭 → "New Group" → "Repositories" 생성

3. `Repositories` 그룹 우클릭 → "Add Files to PixelOffice..."

4. 다음 파일들을 선택하여 추가:
   - `PixelOffice/Repositories/Base/RepositoryProtocol.swift`
   - `PixelOffice/Repositories/Base/FileRepository.swift`
   - `PixelOffice/Repositories/EmployeeRepository.swift`
   - `PixelOffice/Repositories/ProjectRepository.swift`
   - `PixelOffice/Repositories/TaskRepository.swift`
   - `PixelOffice/Repositories/WikiRepository.swift`

5. "Add to targets"에서 `PixelOffice` 체크되어 있는지 확인

6. "Add" 클릭

### 방법 2: 드래그 앤 드롭

1. Finder에서 `PixelOffice/Repositories` 폴더를 엽니다

2. Xcode Project Navigator의 `PixelOffice` 그룹으로 드래그 앤 드롭

3. "Copy items if needed" 체크 해제 (이미 프로젝트 내부에 있음)

4. "Add to targets"에서 `PixelOffice` 체크

5. "Finish" 클릭

## 🧪 빌드 확인

파일 추가 후 빌드하여 에러 없는지 확인:

```bash
xcodebuild -project PixelOffice.xcodeproj -scheme PixelOffice -configuration Debug clean build
```

## 📝 다음 단계

Repository 레이어가 추가되면:

1. **Phase 2: Models 정리**
   - Employee.swift 순수 데이터 모델로 변환
   - EmployeeFactory.swift 생성
   - Presentation 레이어 분리

2. **Phase 3: Services 분리**
   - EventBus.swift 생성
   - CompanyStore를 8개 Store로 분해
   - Repository를 사용하도록 변경

## ❓ 문제 해결

### 컴파일 에러: Cannot find type 'XXX' in scope

Repository 파일들이 Xcode 프로젝트에 추가되면 자동으로 해결됩니다.
파일이 추가되었는데도 에러가 발생하면:

1. Xcode 재시작
2. Product → Clean Build Folder (⌘ + Shift + K)
3. 다시 빌드 (⌘ + B)

### 파일이 Project Navigator에 보이지 않음

1. File → Add Files to "PixelOffice"...
2. 해당 파일 선택하여 추가

## ✅ 완료 체크리스트

- [ ] Repositories 그룹 생성
- [ ] RepositoryProtocol.swift 추가
- [ ] FileRepository.swift 추가
- [ ] EmployeeRepository.swift 추가
- [ ] ProjectRepository.swift 추가
- [ ] TaskRepository.swift 추가
- [ ] WikiRepository.swift 추가
- [ ] 빌드 성공 확인
- [ ] todo.md 업데이트 (Phase 1 완료 체크)
