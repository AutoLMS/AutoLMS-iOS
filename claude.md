# Claude Code Configuration

This file contains configuration and commands for Claude Code to help with this iOS project.

## Commands

### Build Commands
```bash
# Build the project
xcodebuild -project AutoLMS-iOS.xcodeproj -scheme AutoLMS-iOS -destination 'platform=iOS Simulator,name=iPhone 15'

# Clean build
xcodebuild clean -project AutoLMS-iOS.xcodeproj -scheme AutoLMS-iOS
```

### Test Commands
```bash
# Run tests
xcodebuild test -project AutoLMS-iOS.xcodeproj -scheme AutoLMS-iOS -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Lint/Format Commands
```bash
# SwiftLint (if installed)
swiftlint

# SwiftFormat (if installed)
swiftformat .
```

## Project Structure
- iOS project using Xcode
- Main scheme: AutoLMS
- Target platform: iOS
- "- 복잡한 문제는 단계별로 생각하세요.
- 큰 작업을 세분화하고 필요한 경우 명확히 하기 위한 질문을 하세요. 
- Notion-MCP를 통해 Notion에 접근하는 경우, '📋 Notion 페이지 및 데이터베이스 ID 목록' 을 통해 각 페이지나 DB의 ID를 얻어 직접 접근하세요.
- AutoLMS의 기능적 요구사항은 Notion의 페이지를 통해 확인 가능합니다."
- ⏺ AutoLMS iOS 클라이언트 구현 계획 v3.1 (강의자료 중심)

  📋 요구사항 재정의

  - 백엔드 서버 별도 존재: 크롤링/동기화는 서버에서 처리
  - iOS 앱 역할: 사용자 인터페이스 및 동기화 상태 확인
  - 지원 플랫폼: iPhone + iPad 유니버설 앱
  - 1차 MVP 범위: 강의자료(Materials)에만 집중 (공지사항, 과제 제외)

  🎯 MVP 구현 목표 (4주) - 강의자료 중심

  Week 1: 프로젝트 기반 및 인증

  🔧 프로젝트 설정
  ├── iOS 16.0+ 유니버설 앱 설정 (iPhone + iPad)
  ├── Clean Architecture 폴더 구조
  └── 필수 라이브러리 설정

  🔐 인증 시스템
  ├── 로그인 화면 (iPhone/iPad 반응형)
  ├── 백엔드 API 연동 (/auth/login, /auth/me)
  ├── JWT 토큰 KeyChain 저장
  └── 자동 로그인 처리

  Week 2: 강의자료 동기화 및 상태 관리

  🔄 강의자료 동기화 클라이언트
  ├── 강의 목록 API 연동 (/courses)
  ├── 강의자료 API 연동 (/courses/{id}/materials)
  ├── 강의자료 동기화 트리거 (/courses/{id}/materials/refresh)
  └── 동기화 상태 확인 (/crawl/status/{task_id})

  💾 로컬 데이터 관리 (단순화)
  ├── Core Data 모델 (Course, Material만)
  ├── API 응답 캐싱
  └── 오프라인 데이터 접근

  Week 3: iOS 유니버설 UI 구현 (강의자료 중심)

  📱 iPhone UI
  ├── 강의 목록 화면 (List View)
  ├── 강의자료 목록 화면
  ├── 강의자료 상세/뷰어 화면
  └── 설정 화면

  📱 iPad UI
  ├── Split View: 강의 목록 (Sidebar) + 강의자료 목록 (Main)
  ├── 3-column 레이아웃: 강의 | 자료 목록 | 자료 뷰어
  ├── 멀티태스킹 지원
  └── 드래그 앤 드롭 지원

  🎨 공통 컴포넌트
  ├── 동기화 상태 인디케이터
  ├── 로딩 및 에러 처리
  └── 반응형 레이아웃

  Week 4: 강의자료 파일 관리 및 완성

  📁 강의자료 파일 시스템
  ├── 첨부파일 다운로드 (/attachments/{id}/download)
  ├── PDF/이미지/동영상 뷰어 (iPhone/iPad 최적화)
  ├── 파일 공유 ("다른 앱에서 열기" - 굿노트, 노타빌리티)
  └── 오프라인 강의자료 관리

  ✅ 앱 완성도
  ├── 강의자료 동기화 버튼 및 상태 표시
  ├── 실시간 동기화 진행률 표시
  ├── 사용성 테스트 및 버그 수정
  └── 실제 강의자료 사용 검증

  🏗️ 핵심 기술 구현 (강의자료 중심)

  1. 단순화된 데이터 모델

  // Core Data Models
  @Model
  class Course {
      var id: String
      var name: String
      var courseCode: String
      var professor: String
      var materials: [Material] = []
  }

  @Model
  class Material {
      var id: String
      var title: String
      var content: String?
      var postedAt: Date
      var attachments: [Attachment] = []
      var course: Course?
  }

  @Model
  class Attachment {
      var id: String
      var filename: String
      var fileSize: Int64
      var downloadURL: String?
      var localPath: String?
      var material: Material?
  }

  2. 강의자료 전용 API 서비스

  class MaterialsAPIService {
      // 인증
      func login(studentID: String, password: String) async throws -> AuthResponse

      // 강의 관리
      func getCourses() async throws -> [Course]
      func getCourseMaterials(courseID: String) async throws -> [Material]
      func refreshCourseMaterials(courseID: String) async throws -> RefreshResponse

      // 파일 다운로드
      func downloadMaterialAttachment(attachmentID: String) async throws -> URL
  }

  3. 강의자료 중심 UI 구조

  struct ContentView: View {
      @Environment(\.horizontalSizeClass) var horizontalSizeClass

      var body: some View {
          if horizontalSizeClass == .regular {
              // iPad: 3-Column Layout
              NavigationSplitView {
                  CourseListSidebar()
              } content: {
                  MaterialsListView()
              } detail: {
                  MaterialViewerView()
              }
          } else {
              // iPhone: Navigation Stack
              NavigationStack {
                  CourseListView()
              }
          }
      }
  }

  4. 강의자료 동기화 상태 관리

  @MainActor
  class MaterialsSyncManager: ObservableObject {
      @Published var isSyncing = false
      @Published var syncProgress: Double = 0.0
      @Published var lastSyncTime: Date?

      func syncAllCourseMaterials() async {
          isSyncing = true
          // 모든 강의의 강의자료 동기화
          for course in courses {
              await syncCourseMaterials(courseID: course.id)
              syncProgress += 1.0 / Double(courses.count)
          }
          isSyncing = false
          lastSyncTime = Date()
      }
  }

  📱 강의자료 중심 사용자 플로우

  iPhone 플로우

  1. 로그인
  2. 강의 목록 화면
  3. 강의 선택 → 강의자료 목록
  4. 자료 선택 → PDF/파일 뷰어
  5. "다른 앱에서 열기" → 굿노트/노타빌리티

  iPad 플로우

  1. 로그인
  2. 3분할 화면: [강의 목록] [자료 목록] [뷰어]
  3. 강의 선택 → 자료 목록 업데이트
  4. 자료 선택 → 뷰어에서 바로 표시
  5. 드래그 앤 드롭으로 다른 앱에 자료 전달

  🎯 단순화된 성공 지표

  - ✅ 핵심 목표: 강의자료 자동 다운로드 및 뷰어 기능
  - ✅ iPhone/iPad 모두에서 강의자료 열람 가능
  - ✅ 굿노트/노타빌리티와 연동 가능
  - ✅ 오프라인에서 다운로드된 강의자료 접근 가능
  - ✅ 본인이 실제로 강의자료 관리용으로 사용 가능

  📊 향후 확장 계획

  - Phase 2: 공지사항 추가
  - Phase 3: 과제 관리 추가
  - Phase 4: 위젯 및 외부 서비스 연동

  이렇게 강의자료에만 집중함으로써 4주 안에 실제 사용 가능한 핵심 기능을 완성할 수 있습니다.