---
name: harness-scaffold
description: "하네스 프로필(.harness-profile.json)을 읽어 파일을 생성하는 스킬. /harness-setup 완료 후 자동 실행되며, 직접 호출도 가능하다. 하네스 스캐폴딩, harness scaffold, 파일 생성, 하네스 파일 만들어줘 등을 언급할 때 이 스킬을 사용한다."
user-invocable: false
allowed-tools: Bash(cat *) Bash(echo *) Bash([ *) Bash(test *)
hooks:
  Stop:
    - type: command
      command: "bash -c 'if [ -f .harness-manifest.json ]; then printf \"{\\\"decision\\\":\\\"allow\\\"}\"; else printf \"{\\\"decision\\\":\\\"block\\\",\\\"reason\\\":\\\"파일 생성 미완료\\\",\\\"additionalContext\\\":\\\"아직 모든 하네스 파일과 .harness-manifest.json이 생성되지 않았다. 스캐폴딩을 계속 진행하라.\\\"}\"; fi'"
---

# Harness Scaffold Skill

## 0. 프로필 로드

```!
if [ -f .harness-profile.json ]; then
  cat .harness-profile.json
else
  echo '{"error": "PROFILE_NOT_FOUND"}'
fi
```

위 출력에 `"error"` 키가 있으면:
"프로필이 없습니다. `/harness-setup`을 먼저 실행하세요." 출력 후 **즉시 종료**한다.

위 출력이 정상 JSON이면 이것이 프로젝트 프로필이다. § 3 진입 검증으로 진행한다.

---

## 1. 개요

이 스킬은 `/harness-setup`이 생성한 **프로젝트 프로필**(`.harness-profile.json`)을 읽어 하네스 파일을 생성한다.

- § 0에서 프로필이 프롬프트에 이미 주입되었으므로, 별도로 파일을 읽을 필요 없이 위 데이터를 사용한다
- 프로필 데이터를 기반으로 18개 파일을 의존 순서대로 생성한다
- 생성 후 12항목 검증 체크리스트를 자동 실행한다
- 최종 결과를 사용자에게 보고한다

### 이 스킬이 하지 않는 일
- 프로젝트 분석이나 사용자 문답은 수행하지 않는다 (그것은 `/harness-setup`의 역할)
- 기존 소스 코드를 수정하거나 이동하지 않는다

---

## 2. 트리거 조건

- `/harness-setup`의 Stop hook 또는 프롬프트 지시에 의해 자동 호출될 때
- "하네스 파일 생성해줘", "스캐폴딩 실행" 등을 요청할 때

> 이 스킬은 `user-invocable: false`이므로 사용자 `/` 메뉴에 표시되지 않는다. `/harness-setup`이 자동으로 호출하거나, 자연어로 요청하면 Claude가 호출한다.

---

## 3. 진입 검증

§ 0에서 주입된 프로필 데이터를 검증한다:

1. **프로필 존재 확인**
   - § 0 출력이 `{"error": "PROFILE_NOT_FOUND"}`이면 이미 종료 처리됨
2. **JSON 유효성 확인**
   - § 0 출력이 유효한 JSON이 아니면: "프로필 파일이 유효한 JSON이 아닙니다. 파일을 확인하세요." 출력 후 종료
3. **`approved: true` 확인**
   - `approved`가 `false`이거나 없으면: "프로필이 아직 승인되지 않았습니다. `/harness-setup`을 다시 실행하세요." 출력 후 종료
4. **모드 판별**
   - `mode` 필드가 `"upgrade"`이면 § 10 업그레이드 실행으로 분기
   - 그 외(없거나 `"setup"`)이면 § 5 Phase 2로 진행

---

## 4. 프로필 입력 스키마

`.harness-profile.json`의 구조. `/harness-setup`이 이 스키마대로 파일을 생성한다.

```json
{
  "version": "3.3",
  "preset": "react-next | custom",
  "projectName": "프로젝트명",
  "description": "한 줄 설명",
  "stack": {
    "framework": "React 19",
    "language": "TypeScript",
    "libraries": ["React Router v7", "Zustand", "Supabase"]
  },
  "architectureType": "layer-based | fsd | domain-based | custom",
  "srcRoot": "src/",
  "pathAlias": "@/",
  "layers": {
    "order": ["types", "config", "lib", "services", "hooks", "components", "pages", "app"],
    "rules": {
      "types": { "allowedImports": [] },
      "config": { "allowedImports": ["types"] }
    },
    "descriptions": {
      "types": "공유 타입, enum, interface",
      "lib": "순수 유틸 함수"
    }
  },
  "folderRoles": {
    "src/types": "공유 타입, enum, interface",
    "src/lib": "순수 유틸 함수"
  },
  "extraArchitectureRules": [
    "컴포넌트에서 API를 직접 호출하지 않는다"
  ],
  "naming": {
    "components": "PascalCase",
    "hooks": "camelCase + use 접두사"
  },
  "devServer": {
    "command": "npm run dev",
    "port": 3000,
    "readyCheck": "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000"
  },
  "scripts": {
    "validate": "npm run validate",
    "test": "npm run test"
  },
  "tdd": {
    "securityCategories": "auth, security, api, payment",
    "maxImplementerAttempts": 3,
    "maxDebuggerAttempts": 2
  },
  "git": {
    "commitScopes": null,
    "commitLang": "ko",
    "branchPrefixes": ["feature/", "fix/", "docs/", "refactor/", "chore/"],
    "mainBranch": "main"
  },
  "docFreshnessDays": 14,
  "extras": {
    "stateManagement": {},
    "backendIntegration": {},
    "domainModel": {},
    "routing": {}
  },
  "existingFiles": ["AGENTS.md"],
  "skipFiles": ["AGENTS.md"],
  "approved": true,
  "approvedAt": "2026-04-08T09:30:00Z"
}
```

**필드 참조 규칙:**
- `extras`의 각 항목은 문답에서 확인된 경우에만 존재한다. 없는 키는 해당 섹션 생략을 의미한다.
- `existingFiles`에 포함된 파일은 이미 프로젝트에 존재하는 파일이다.
- `skipFiles`에 포함된 파일은 생성을 건너뛴다 (사용자가 Step 5에서 스킵을 선택한 항목).

---

## 5. Phase 2: 스캐폴딩

`.harness-profile.json`을 읽고 파일을 생성한다.

### 생성 순서

반드시 아래 순서대로 생성한다 (의존 관계 때문):

```
1. docs/ 디렉토리 구조 (빈 폴더):
   - `docs/product-specs/` — 제품 요구사항 문서
   - `docs/design-docs/` — 설계 결정 기록
   - `docs/exec-plans/` — 작업별 실행 계획
   - `docs/references/` — 참고 자료
2. ARCHITECTURE.md (아키텍처 규칙 — 다른 문서에서 참조)
3. AGENTS.md (전체 문서 맵 — ARCHITECTURE.md 경로 참조)
4. CLAUDE.md (Claude Code 전용 지침 — @AGENTS.md import + Agent Dispatch)
5. .claude/rules/session-routine.md (TDD 오케스트레이션 — CLAUDE.md가 참조)
6. .claude/rules/coding-standards.md (코드 규칙 — 프로필 기반)
7. .claude/rules/git-workflow.md (Git 규칙 — session-routine.md가 참조)
8. agents/*.md (7개 subagent 정의 — session-routine.md가 참조)
9. feature_list.json (빈 배열 또는 기존 코드 기반 추론)
10. claude-progress.txt (초기 상태 + TDD STATE 블록 포맷)
11. init.sh (스택에 맞는 초기화 스크립트)
12. scripts/structural-test.ts (아키텍처 규칙 검증)
13. scripts/doc-freshness.ts (문서 최신성 검사)
14. docs/QUALITY_SCORE.md (품질 점수표 초기값)
15. docs/TECH_DEBT.md (기술 부채 빈 템플릿)
16. docs/HARNESS_FRICTION.md (마찰 로그 — 피드백 수집)
17. package.json scripts 추가
18. .harness-manifest.json (버전 추적 매니페스트 — § 5.13)
```

**skipFiles 처리**: `skipFiles` 배열에 포함된 파일은 생성을 건너뛴다. 해당 파일이 다른 파일의 의존 대상이면 기존 파일이 존재한다고 가정하고 진행한다.

### 5.1 AGENTS.md 생성 규칙

- 100줄 이내로 작성한다
- 백과사전이 아니라 **목차(Table of Contents)** 역할을 한다
- 프로필에서 확인된 실제 정보를 사용한다
- 플레이스홀더를 남기지 않는다
- AGENTS.md는 **프로젝트 구조와 현재 상태를 안내**하는 문서이다 (범용 에이전트용)
- 빌드/테스트 명령, 세션 루틴 등 **행동 지침은 CLAUDE.md에** 작성한다

포함해야 할 섹션:
```markdown
# AGENTS.md
## 프로젝트 개요        ← 프로젝트명, 스택, 한 줄 설명
## 아키텍처              ← ARCHITECTURE.md 링크 + 의존성 방향 한 줄 요약
## 현재 상태             ← claude-progress.txt, feature_list.json 링크
## 주요 규칙             ← 5개 이내의 핵심 규칙 (프로필에서 추출)
## 문서 맵               ← docs/ 하위 문서 테이블
```

### 5.1.1 CLAUDE.md 생성 규칙

CLAUDE.md는 **Claude Code가 세션 시작 시 자동으로 읽는 지침서**이다. AGENTS.md가 "이 프로젝트는 무엇인가"를 설명한다면, CLAUDE.md는 "이 프로젝트에서 어떻게 작업할 것인가"를 지시한다.

- 150줄 이내로 작성한다 (상세 규칙은 `.claude/rules/`로 분리)
- `@AGENTS.md`로 AGENTS.md를 import하여 프로젝트 개요를 중복 작성하지 않는다
- AGENTS.md에 이미 있는 정보(프로젝트 개요, 아키텍처 설명, 문서 맵)를 반복하지 않는다
- **행동 지침 중심**으로 작성한다: 명령어, 에이전트 디스패치, 금지 사항
- 코드 규칙과 세션 루틴 상세는 `.claude/rules/`에 위임한다

포함해야 할 섹션:
```markdown
# CLAUDE.md

@AGENTS.md

## 명령어
- 개발 서버: {프로필의 devServer.command} (포트: {port})
- 테스트: {프로필의 테스트 명령}
- 타입 체크: {프로필의 typecheck 명령, 있을 경우}
- 전체 검증: npm run validate
- 아키텍처 검증: npm run lint:arch

## TDD Subagent 파이프라인

기능 구현은 TDD 사이클(Red → Green → Refactor)을 따른다.
각 단계의 전문 에이전트를 Agent tool로 호출한다.
상세 오케스트레이션: .claude/rules/session-routine.md
**Plan 모드 연계**: `/plan` 모드로 설계를 완료한 경우, Plan → RED → GREEN → REVIEW 순으로 진행한다. Plan 모드가 Architect(Pre-Red)를 대체한다. 상세: .claude/rules/session-routine.md § Plan 모드 통합

| TDD 단계 | Agent | 파일 |
|----------|-------|------|
| Pre-Red | Architect | agents/architect.md |
| Red | Test Engineer | agents/test-engineer.md |
| Green | Implementer | agents/implementer.md |
| Post-Green | Reviewer | agents/reviewer.md |
| Refactor | Simplifier | agents/simplifier.md |
| On-demand | Debugger | agents/debugger.md |
| Post-Green | Security Reviewer | agents/security-reviewer.md |

### 호출 방법
1. agents/{name}.md를 읽어 에이전트 정의를 확인한다
2. Input 섹션에 명시된 데이터를 수집한다
3. Agent tool로 subagent를 호출한다

## 세션 루틴 (요약)
### 시작
1. claude-progress.txt 읽기 (TDD STATE 블록 확인)
2. git status → 미커밋 변경 확인
3. git log --oneline -10
4. feature_list.json → passes: false 중 최고 우선순위 선택
5. npm run validate (회귀 체크)
6. TDD 사이클 시작 (상세: .claude/rules/session-routine.md)

### 종료
1. npm run validate
2. feature_list.json 업데이트
3. claude-progress.txt 세션 요약 + TDD STATE 갱신
4. git-workflow.md 규칙에 따라 커밋 제안

## 금지 사항
- feature_list.json의 기능 설명을 수정/삭제하지 않는다
- 한 번에 여러 기능을 구현하지 않는다
- 테스트 없이 기능을 완료 처리하지 않는다
- Plan 모드 승인 후에도 TDD 사이클(최소 RED → GREEN)을 거치지 않고 기능을 완료하지 않는다
{프로필의 "에이전트가 하면 안 되는 것"에서 추출}

## 하네스 이슈 보고
- 하네스 관련 문제 발생 시 `docs/HARNESS_FRICTION.md`에 기록한다
- 반복되는 문제는 "하네스 피드백 분석해줘"로 자동 Issue 생성 가능
- 수동 보고: https://github.com/daehyunk1m/harness-setup-initializer/issues
```

**AGENTS.md와 CLAUDE.md의 역할 분리:**

원칙: **AGENTS.md = "이 프로젝트는 무엇인가" (맥락)**, **CLAUDE.md = "어떻게 작업할 것인가" (행동)**. 동일한 정보를 두 파일에 모두 적지 않는다. 충돌 시 CLAUDE.md가 행동 지침의 source of truth이다. 코드 규칙과 세션 루틴 상세는 `.claude/rules/`에 위임한다.

| 내용 | CLAUDE.md | .claude/rules/ | AGENTS.md |
|------|-----------|----------------|-----------|
| 프로젝트 개요, 스택 | ❌ (@AGENTS.md import) | ❌ | ✅ (source of truth) |
| 아키텍처 설명, 문서 맵 | ❌ | ❌ | ✅ + ARCHITECTURE.md |
| 빌드/테스트/검증 명령 | ✅ (source of truth) | ❌ | ❌ |
| Agent Dispatch 테이블 | ✅ (요약) | session-routine.md (상세) | ❌ |
| 코드 스타일/네이밍 규칙 | ❌ | coding-standards.md (source of truth) | ❌ |
| TDD 오케스트레이션 상세 | ❌ | session-routine.md (source of truth) | ❌ |
| 세션 시작/종료 루틴 | ✅ (요약) | session-routine.md (상세) | ❌ |
| Git 워크플로 (커밋, 브랜치, 충돌) | ❌ | git-workflow.md (source of truth) | ❌ |
| 금지 사항 | ✅ | coding-standards.md에도 포함 | ❌ |
| 현재 상태 링크 | ❌ | ❌ | ✅ (source of truth) |

### 5.2 ARCHITECTURE.md 생성 규칙

- **프로필의 아키텍처 정보를 기반으로** 작성한다 (하드코딩하지 않음)
- 포함해야 할 내용:
  - 아키텍처 유형과 설명
  - 폴더별 역할 테이블 (프로필의 folderRoles 사용)
  - 의존성 방향 규칙 (프로필의 layers.rules 사용)
  - 네이밍 규칙 (프로필의 naming 사용)
  - 실제 존재하는 폴더는 ✅, 존재하지 않는 폴더는 "권장"으로 표시
  - 의존성 규칙에서 참조되는 레이어가 실제로 존재하지 않는 경우, 해당 레이어에 ⚠️ 표시와 함께 "의존 규칙에 포함되나 폴더 미존재 — 생성 권장" 메시지를 추가한다
- 프로필에 extras 항목이 있으면 해당 섹션도 포함한다:
  - stateManagement → "상태 관리" 섹션: 스토어 위치, 접근 규칙
  - backendIntegration → "데이터 계층" 섹션: 클라이언트 위치, API 호출 패턴
  - domainModel → "도메인 규칙" 섹션: 객체 관리 방식, 상태 전이, 변경 패턴
  - routing → "라우팅" 섹션: loader/action 규칙, 라우트 구조
- extras 항목이 없으면 해당 섹션은 생략한다 (빈 섹션을 만들지 않음)
- 폴더를 직접 생성하지 않는다 (문서에 기록만 한다)

아키텍처 유형별 ARCHITECTURE.md의 핵심 구조:

**레이어 기반**:
```
의존성 방향: {레이어1} → {레이어2} → ... → {레이어N}
각 레이어는 왼쪽(하위) 레이어만 import 가능
```

**FSD**:
```
의존성 방향: app → pages → widgets → features → entities → shared
각 레이어는 아래쪽 레이어만 import 가능
같은 레이어 내 슬라이스 간 cross-import 금지
```

**도메인 기반**:
```
공유 모듈(shared/)은 모든 도메인에서 import 가능
도메인 간 직접 import는 금지 (이벤트 또는 공유 인터페이스를 통해 통신)
```

**자유 구조**:
```
명시적 레이어 규칙 없음 — 문답에서 확인된 규칙만 기록
```

### 5.3 feature_list.json 생성 규칙

- 새 프로젝트 (소스 코드 없음): 빈 배열 `[]`로 생성
- 기존 프로젝트 (소스 코드 있음): 소스 코드를 분석하여 현재 구현된 기능을 추론하고 항목을 생성
- passes 필드 설정 기준:
  - `passes: true` — 에이전트가 기능 동작을 **직접 확인**한 경우. 다음 중 하나 이상을 만족해야 한다:
    - 해당 기능의 테스트가 존재하고, 테스트 실행 결과 통과
    - 개발 서버에서 해당 기능을 직접 동작시켜 확인 (E2E, 수동 확인)
    - 기능에 해당하는 steps를 모두 수행하여 통과 확인
  - `passes: false` — 코드는 존재하지만 위 조건을 충족하지 못한 경우. 이 때 `notes: "코드 존재 — 검증 필요"` 기록
  - 하네스 셋업 시점에는 직접 확인이 불가하므로, **기존 코드 기반 추론 항목은 모두 `passes: false`로 설정**한다
  - 이후 에이전트가 세션 종료 루틴에서 검증한 기능만 `passes: true`로 전환한다
- 형식:
```json
[
  {
    "id": "F001",
    "category": "카테고리",
    "priority": 1,
    "description": "기능 설명",
    "steps": ["검증 단계 1", "검증 단계 2"],
    "passes": false,
    "last_session": null,
    "notes": "코드 존재 — 검증 필요"
  }
]
```

### 5.4 structural-test.ts 생성 규칙

- 이 스킬의 `templates/` 디렉토리에서 아키텍처 유형에 맞는 템플릿을 기반으로 생성한다
- 템플릿의 치환 대상:
  - `LAYER_RULES` — 프로필의 `layers.rules` 값으로 치환
  - `PATH_ALIAS` — 프로필의 `pathAlias` 값으로 치환. 배열인 경우 각 alias에 대해 regex를 생성하여 모두 검사한다 (예: `['@/', '~/']` → `@/` 또는 `~/`로 시작하는 import 모두 감지)
  - `SRC_ROOT` — 프로필의 `srcRoot` 값으로 치환

| 아키텍처 유형 | 사용 템플릿 | 검증 항목 |
|--------------|-----------|----------|
| 레이어 기반 (`layer-based`) | `templates/structural-test-layer.ts` | 레이어 의존성 방향 (alias + 상대경로) |
| FSD (`fsd`) | `templates/structural-test-fsd.ts` | 레이어 의존성 + cross-slice import + public API |
| 도메인 기반 (`domain-based`) | 동적 생성 | 도메인 간 직접 import 감지 |
| 자유 구조 (`custom`) | 동적 생성 | 프로필에 명시된 금지 규칙만 (없으면 빈 검사) |

- 템플릿이 없는 유형(domain-based, custom)은 프로필의 규칙을 기반으로 동적으로 생성한다
- import 패턴 감지 시 다음 두 가지를 모두 검사한다:
  - alias import: `from '@/{layer}/...'` 등 pathAlias 기반
  - 상대 경로 import: `from '../../{layer}/...'` — srcRoot 기준으로 레이어 폴더를 추론
- 실행 가능한 스크립트로 만든다: `npx tsx scripts/structural-test.ts`
- 위반 발견 시 파일, 줄 번호, 위반 내용을 출력하고 exit 1로 종료

### 5.5 package.json scripts 추가 규칙

- 기존 scripts를 **절대 삭제하지 않는다**
- 다음 항목만 추가한다:
  - `lint:arch`: 프리셋 또는 프로필의 `scripts.lint:arch` 값 사용
  - `validate`: **항상 동적으로 조합한다** (프리셋에서 가져오지 않음 — 아래 조합 규칙 참조)
  - `doc:check`: 문서 최신성 검사
- 기존에 같은 이름의 script가 있으면 스킵한다
- Node 스크립트로 안전하게 수정한다:

```bash
node -e "
const pkg = require('./package.json');
const toAdd = {
  'lint:arch': '{프로필에서 가져온 lint:arch 명령}',
  'validate': '{프로필에서 가져온 validate 명령}',
  'doc:check': '{프로필에서 가져온 doc:check 명령}'
};
let changed = false;
for (const [key, val] of Object.entries(toAdd)) {
  if (!pkg.scripts[key]) {
    pkg.scripts[key] = val;
    changed = true;
  }
}
if (changed) {
  require('fs').writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
  console.log('✅ package.json scripts 추가 완료');
} else {
  console.log('ℹ️ 추가할 scripts 없음 (이미 존재)');
}
"
```

validate 명령 조합 규칙:
- typecheck 명령이 package.json scripts에 있으면 포함, 없으면 생략
- lint 명령이 있으면 포함, 없으면 생략
- lint:arch는 항상 포함
- test 명령이 있으면 포함, 없으면 생략
- 예시: `npm run typecheck && npm run lint && npm run lint:arch && npm run test`
- 예시 (typecheck 없는 경우): `npm run lint && npm run lint:arch && npm run test`

### 5.6 init.sh 생성 규칙

- 이 스킬의 `templates/init.sh` 템플릿을 기반으로 생성하고, 플레이스홀더를 프로필 값으로 치환한다
- 프로필의 개발 서버 정보를 사용한다
- 실행 권한을 부여한다: `chmod +x init.sh`
- 템플릿 치환 대상:
  - `{{DEV_SERVER_COMMAND}}` — 프로필의 devServer.command
  - `{{READY_CHECK_COMMAND}}` — 프로필의 devServer.readyCheck (없으면 `curl -s -o /dev/null -w '%{http_code}' http://localhost:{port}`)
  - `{{DEV_SERVER_PORT}}` — 프로필의 devServer.port
- 패키지 매니저는 템플릿 내에서 lockfile 기반으로 자동 감지한다 (치환 불필요)
- 스크립트 구조:

```bash
#!/bin/bash
set -e

echo "=== 환경 초기화 ==="

# 1. 패키지 매니저 감지 (lockfile 기반)
#    - pnpm-lock.yaml → pnpm install
#    - yarn.lock → yarn install
#    - package-lock.json 또는 기타 → npm install

# 2. 의존성 설치 (node_modules 없을 때만)
if [ ! -d "node_modules" ]; then
  echo "의존성 설치 중..."
  {감지된 패키지 매니저} install
fi

# 3. 개발 서버 실행 (백그라운드)
echo "개발 서버 시작..."
{프로필의 devServer.command} &
DEV_PID=$!

# 4. 서버 준비 대기
echo "서버 준비 대기 중..."
for i in $(seq 1 30); do
  if {프로필의 devServer.readyCheck} 2>/dev/null | grep -q "200"; then
    echo "✅ 서버 정상 동작 (http://localhost:{프로필의 devServer.port})"
    break
  fi
  sleep 1
done

echo "=== 초기화 완료 (PID: $DEV_PID) ==="
```

- `{...}` 부분은 프로필의 실제 값으로 치환한다
- readyCheck가 프로필에 없으면 기본 커맨드를 사용한다: `curl -s -o /dev/null -w '%{http_code}' http://localhost:{port}`
- readyCheck 파싱 규칙:
  - readyCheck 명령의 **stdout 출력에 "200"이 포함되면** 준비 완료로 판정한다
  - 프리셋의 readyCheck는 반드시 stdout에 HTTP 상태 코드를 출력하는 형태여야 한다 (예: `curl -w '%{http_code}'`)
  - readyCheck 명령이 exit 0이지만 "200"이 없으면 준비 미완료로 간주한다
  - 30초(30회 반복) 내 "200"이 나오지 않으면 경고를 출력하고 계속 진행한다 (중단하지 않음)

### 5.7 doc-freshness.ts 생성 규칙

- 이 스킬의 `templates/doc-freshness.ts` 템플릿을 기반으로 생성하고, 플레이스홀더를 프로필 값으로 치환한다
- 템플릿 치환 대상:
  - `{{DOC_FRESHNESS_DAYS}}` — 프로필의 docFreshnessDays 값 (기본값: 14)
  - `{{DOC_CHECK_TARGETS}}` — 검사 대상 파일 경로 배열 (TypeScript 배열 리터럴로 치환, 예: `['AGENTS.md', 'ARCHITECTURE.md', 'docs/QUALITY_SCORE.md', 'docs/TECH_DEBT.md']`)
- 문서 최신성을 검사하는 스크립트를 생성한다: `npx tsx scripts/doc-freshness.ts`
- 검사 대상 문서:
  - AGENTS.md
  - ARCHITECTURE.md
  - docs/ 하위의 모든 .md 파일
- 검사 로직:
  - 각 파일의 최종 수정일(`fs.statSync(file).mtimeMs`)을 현재 시간과 비교한다
  - staleness 기준: 프로필의 `docFreshnessDays` 값 (기본값: **14일**)
  - 기준일 이내 수정 → ✅ 최신 / 기준일 초과 → ⚠️ 오래됨
- 출력 형식:
  ```
  📄 문서 최신성 검사
  ✅ AGENTS.md — 3일 전 수정
  ✅ ARCHITECTURE.md — 1일 전 수정
  ⚠️ docs/QUALITY_SCORE.md — 21일 전 수정
  ⚠️ docs/TECH_DEBT.md — 45일 전 수정

  결과: 4개 문서 중 2개 오래됨
  ```
- exit 동작: **항상 exit 0** — 경고만 출력하고 validate를 차단하지 않는다
- 파일이 존재하지 않으면 해당 항목은 "❌ {파일명} — 파일 없음"으로 출력한다

### 5.8 docs/QUALITY_SCORE.md 생성 규칙

- 이 스킬의 `templates/QUALITY_SCORE.md` 템플릿을 그대로 복사하여 생성한다 (플레이스홀더 없음)
- 프로젝트 품질을 측정하는 점수표의 초기 템플릿을 생성한다
- 각 카테고리의 점수는 초기에 모두 "—"로 설정한다
- 에이전트 또는 사용자가 측정 후 점수를 업데이트한다

### 5.9 docs/TECH_DEBT.md 생성 규칙

- 이 스킬의 `templates/TECH_DEBT.md` 템플릿을 기반으로 생성하고, 플레이스홀더를 프로필 값으로 치환한다
- 템플릿 치환 대상:
  - `{{CREATED_DATE}}` — 생성 시점의 날짜 (YYYY-MM-DD 형식)
- 모든 섹션은 초기에 비어 있다 (주석만 포함)
- 에이전트가 작업 중 발견한 부채를 여기에 기록한다

### 5.10 agents/ 생성 규칙

프로젝트에 TDD subagent 파이프라인을 위한 에이전트 정의 파일을 생성한다.

#### 5.10.1 생성할 파일

| 파일 | 역할 | TDD 단계 | 접근 권한 |
|------|------|----------|----------|
| `agents/architect.md` | 기능 분석 + 구현 계획 수립 | Pre-Red | Read-only |
| `agents/test-engineer.md` | 실패하는 테스트 작성 | Red | Write (테스트만) |
| `agents/implementer.md` | 최소 구현으로 테스트 통과 | Green | Write (소스만) |
| `agents/reviewer.md` | 코드 리뷰 + 품질 게이트 | Post-Green | Read-only |
| `agents/simplifier.md` | 리팩터링 (테스트 유지) | Refactor | Write (소스만) |
| `agents/debugger.md` | 근본 원인 진단 + 수정 | On-demand | Write |
| `agents/security-reviewer.md` | 보안 취약점 점검 | Post-Green | Read-only |

#### 5.10.2 생성 방식

이 스킬의 `templates/agents/` 디렉토리에서 템플릿을 읽어 프로젝트의 `agents/` 디렉토리에 복사하며, 플레이스홀더를 프로필 값으로 치환한다.

#### 5.10.3 플레이스홀더 치환 규칙

| 플레이스홀더 | 소스 | 기본값 | 사용하는 에이전트 |
|-------------|------|--------|-----------------|
| `{{VALIDATE_COMMAND}}` | 프로필 scripts.validate | `npm run validate` | implementer, simplifier, debugger |
| `{{TEST_COMMAND}}` | 프로필 scripts.test | `npm run test` | test-engineer |
| `{{SECURITY_CATEGORIES}}` | 프로필 tdd.securityCategories | `auth, security, api, payment` | security-reviewer |
| `{{MAX_IMPLEMENTER_ATTEMPTS}}` | 프로필 tdd.maxImplementerAttempts | `3` | session-routine (참조) |
| `{{MAX_DEBUGGER_ATTEMPTS}}` | 프로필 tdd.maxDebuggerAttempts | `2` | session-routine (참조) |

치환 후 `{{...}}` 패턴이 남아 있으면 검증 단계에서 에러로 보고한다.

#### 5.10.4 에이전트 정의 파일 구조

모든 에이전트 파일은 다음 섹션을 포함한다:

```markdown
# {에이전트 이름}

## Role          ← 한 줄 역할 설명
## Access        ← Read-only | Read-write (범위 명시)
## Input         ← Orchestrator가 전달하는 데이터
## Instructions  ← 상세 행동 지침
## Output Format ← 구조화된 출력 형식 (Orchestrator가 파싱)
## Constraints   ← 절대 하지 않는 것
## Circuit Breaker ← 에스컬레이션 조건과 행동
```

#### 5.10.5 Subagent 호출 방법

CLAUDE.md 또는 `.claude/rules/session-routine.md`에서 에이전트를 호출할 때:

1. `agents/{name}.md` 파일을 읽는다
2. 에이전트의 Input 섹션에 명시된 데이터를 수집한다
3. **Claude Code의 Agent tool**로 subagent를 spawning한다:
   - prompt: 에이전트 정의 전체 + 입력 데이터
   - description: "{에이전트명}: {feature ID}"
4. subagent의 Output Format에 맞는 결과를 받아 다음 단계 결정에 사용한다

### 5.11 .claude/rules/ 생성 규칙

CLAUDE.md의 코드 규칙과 세션 루틴 상세를 `.claude/rules/` 파일로 분리하여 생성한다.

#### 5.11.1 생성할 파일

| 파일 | 역할 | paths 설정 |
|------|------|-----------|
| `.claude/rules/session-routine.md` | TDD 오케스트레이션 플로우, 상태 머신, 에스컬레이션 규칙 | 없음 (항상 로딩) |
| `.claude/rules/coding-standards.md` | 아키텍처 규칙, 네이밍 규칙, 코드 원칙 | 없음 (항상 로딩) |
| `.claude/rules/git-workflow.md` | Git 커밋 규칙, 브랜치 정책, 충돌 해결, 세션 경계 | 없음 (항상 로딩) |

프로필의 extras 항목에 따라 도메인별 rule 파일을 추가로 생성할 수 있다:

| 프로필 extras 항목 | 생성 파일 | paths 설정 |
|-------------------|----------|-----------|
| stateManagement | `.claude/rules/state-management.md` | 스토어 위치 경로 |
| backendIntegration | `.claude/rules/api-patterns.md` | API 클라이언트 위치 경로 |
| domainModel | `.claude/rules/domain-model.md` | 도메인 폴더 경로 |

도메인별 rule 파일은 해당 프로필 항목이 문답에서 확인된 경우에만 생성한다.

#### 5.11.2 생성 방식

이 스킬의 `templates/rules/` 디렉토리에서 템플릿을 읽어 프로젝트의 `.claude/rules/` 디렉토리에 복사하며, 플레이스홀더를 프로필 값으로 치환한다.

#### 5.11.3 플레이스홀더 치환 규칙

session-routine.md:

| 플레이스홀더 | 소스 | 기본값 |
|-------------|------|--------|
| `{{VALIDATE_COMMAND}}` | 프로필 scripts.validate | `npm run validate` |
| `{{TEST_COMMAND}}` | 프로필 scripts.test | `npm run test` |
| `{{SECURITY_CATEGORIES}}` | 프로필 tdd.securityCategories | `auth, security, api, payment` |
| `{{MAX_IMPLEMENTER_ATTEMPTS}}` | 프로필 tdd.maxImplementerAttempts | `3` |
| `{{MAX_DEBUGGER_ATTEMPTS}}` | 프로필 tdd.maxDebuggerAttempts | `2` |

coding-standards.md:

| 플레이스홀더 | 소스 | 기본값 |
|-------------|------|--------|
| `{{ARCHITECTURE_TYPE}}` | 프로필 architectureType | `custom` |
| `{{LAYER_RULES_SUMMARY}}` | 프로필 layers.order 배열을 `→`로 연결 | 없음 |
| `{{NAMING_RULES}}` | 프로필 naming 항목을 줄 단위로 조합 | React 커뮤니티 관행 |
| `{{PATH_ALIAS}}` | 프로필 pathAlias | `@/` |

git-workflow.md:

| 플레이스홀더 | 소스 | 기본값 |
|-------------|------|--------|
| `{{COMMIT_SCOPES}}` | 프로필 layers.order → scope 변환 + `docs`, `config`, `test` 추가. 프로필에 git.commitScopes가 명시되어 있으면 그것을 사용 | `core, ui, api, config, test, docs` |
| `{{COMMIT_LANG_LABEL}}` | 프로필 git.commitLang → 라벨 매핑 (`ko` → `한국어`, `en` → `English`) | `한국어` |
| `{{BRANCH_PREFIX_POLICY_FORMATTED}}` | 프로필 git.branchPrefixes 배열을 줄바꿈 + 주석 형식으로 렌더 | `feature/  # 새 기능`\n`fix/  # 버그 수정`\n`docs/  # 문서 변경`\n`refactor/  # 구조 개선`\n`chore/  # 설정/도구` |
| `{{MAIN_BRANCH}}` | 프로필 git.mainBranch 또는 `git branch` 감지 | `main` |
| `{{VALIDATE_COMMAND}}` | 프로필 scripts.validate | `npm run validate` |

#### 5.11.4 CLAUDE.md와의 역할 분리

`.claude/rules/` 파일이 생성되면 CLAUDE.md에서 해당 내용을 제거한다:

| 내용 | CLAUDE.md | .claude/rules/ | 비고 |
|------|-----------|----------------|------|
| TDD 플로우 상세 | ❌ | session-routine.md | Agent Dispatch 테이블만 CLAUDE.md에 유지 |
| 에스컬레이션 규칙 | ❌ | session-routine.md | |
| 코드 규칙 (네이밍 등) | ❌ | coding-standards.md | |
| 아키텍처 유형별 핵심 규칙 | ❌ | coding-standards.md | |
| 명령어 | ✅ | ❌ | |
| @AGENTS.md import | ✅ | ❌ | |
| Agent Dispatch 테이블 | ✅ | ❌ | 간략 버전 (어떤 에이전트가 있는지) |
| 금지 사항 | ✅ | coding-standards.md에도 포함 | 중요한 것은 양쪽 모두 |

### 5.12 docs/HARNESS_FRICTION.md 생성 규칙

- 이 스킬의 `templates/HARNESS_FRICTION.md` 템플릿을 그대로 복사하여 생성한다 (플레이스홀더 없음)
- TDD 세션 중 발생하는 마찰 이벤트를 자동으로 기록하는 로그 파일이다
- session-routine.md가 마찰 이벤트 감지 시 이 파일에 행을 추가한다
- 기록 형식: `| {날짜} | {이벤트} | {심각도} | {feature} | {상세} |`
- 이벤트 유형: `implementer-retry`, `debugger-escalation`, `user-escalation`, `review-fix`, `refactor-rollback`, `session-incomplete`

### 5.13 .harness-manifest.json 생성 규칙

Phase 2의 **마지막 단계**로, 모든 파일 생성이 완료된 후 `.harness-manifest.json`을 생성한다. 이 파일은 하네스의 버전과 생성 이력을 추적하는 **단일 참조 파일**이다.

#### 스키마

```json
{
  "harness": {
    "version": "3.3",
    "skillVersion": "3.3",
    "installedAt": "2026-04-07T09:30:00Z",
    "upgradedAt": null,
    "upgradeInProgress": false,
    "preset": "react-next"
  },
  "profile": {
    "architectureType": "layer-based",
    "srcRoot": "src/",
    "pathAlias": "@/",
    "layers": {
      "order": ["types", "config", "lib", "services", "hooks", "components", "pages", "app"],
      "rules": {
        "types": { "allowedImports": [] },
        "config": { "allowedImports": ["types"] }
      }
    },
    "naming": {
      "components": "PascalCase",
      "hooks": "camelCase + use 접두사"
    },
    "devServer": {
      "command": "npm run dev",
      "port": 3000,
      "readyCheck": "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000"
    },
    "scripts": {
      "validate": "npm run validate",
      "test": "npm run test"
    },
    "tdd": {
      "securityCategories": "auth, security, api, payment",
      "maxImplementerAttempts": 3,
      "maxDebuggerAttempts": 2
    },
    "git": {
      "commitScopes": null,
      "commitLang": "ko",
      "branchPrefixes": ["feature/", "fix/", "docs/", "refactor/", "chore/"],
      "mainBranch": "main"
    },
    "docFreshnessDays": 14
  },
  "files": {
    "ARCHITECTURE.md": {
      "category": "custom",
      "templateHash": "sha256:abc123...",
      "generatedAt": "2026-04-07T09:30:00Z"
    },
    "agents/architect.md": {
      "category": "managed",
      "templateHash": "sha256:def456...",
      "generatedAt": "2026-04-07T09:30:00Z"
    }
  }
}
```

#### 필드 설명

| 필드 | 용도 |
|------|------|
| `harness.version` | 하네스 스키마 버전. 마이그레이션 적용 기준 |
| `harness.skillVersion` | 마지막으로 사용된 스킬 버전 |
| `harness.installedAt` | 최초 셋업 시각 (ISO 8601) |
| `harness.upgradedAt` | 마지막 업그레이드 시각 (없으면 `null`) |
| `harness.upgradeInProgress` | 업그레이드 중단 감지용 플래그 |
| `harness.preset` | 사용된 프리셋 이름 (프리셋 없이 셋업했으면 `"custom"`) |
| `profile` | Phase 1에서 수집한 **전체 프로필**. 업그레이드 시 재스캔 없이 재치환에 사용 |
| `files.{path}.category` | `managed` / `custom` / `data` (§ 10.1 참조) |
| `files.{path}.templateHash` | 생성 시점 파일 내용의 SHA-256 해시. 사용자 수정 여부 판별 |
| `files.{path}.generatedAt` | 해당 파일의 마지막 생성/갱신 시각 |

#### 생성 규칙

1. **profile 저장**: `.harness-profile.json`의 프로필 데이터 중 manifest 스키마에 해당하는 필드를 `profile`에 저장한다.
2. **해시 계산**: 각 생성 파일의 내용을 SHA-256으로 해싱하여 `files.{path}.templateHash`에 기록한다.
   ```bash
   node -e "const c=require('crypto'),f=require('fs'); console.log('sha256:'+c.createHash('sha256').update(f.readFileSync(process.argv[1],'utf8')).digest('hex'))" {file}
   ```
3. **카테고리 할당**: § 10.1 파일 카테고리 테이블에 따라 각 파일의 `category`를 설정한다.
4. **files 항목**: 생성한 모든 파일(디렉토리 제외)을 `files`에 기록한다. 키는 프로젝트 루트 기준 상대 경로이다.
5. **version**: 프로필의 `version` 필드를 `harness.version`과 `harness.skillVersion`에 설정한다.
6. **preset**: 프로필의 `preset` 필드를 설정한다.

#### 후처리

`.harness-manifest.json` 생성이 완료되면, `.harness-profile.json`은 더 이상 필요하지 않다. Phase 4 보고에서 사용자에게 안내한다: "프로필은 `.harness-manifest.json`에 보존되었습니다. `.harness-profile.json`은 삭제해도 됩니다."

---

## 6. Phase 3: 검증

생성이 완료되면 자동으로 검증한다.

### 검증 체크리스트

```bash
# 6.0 필요한 디렉토리 생성 보장
mkdir -p scripts/ docs/ agents/ .claude/rules/

# 6.1 생성된 파일 존재 확인
ls -la CLAUDE.md AGENTS.md ARCHITECTURE.md claude-progress.txt feature_list.json init.sh

# 6.2 docs/ 구조 확인 (HARNESS_FRICTION.md 포함)
ls -la docs/ docs/HARNESS_FRICTION.md

# 6.3 scripts/ 확인
ls -la scripts/structural-test.ts scripts/doc-freshness.ts

# 6.4 agents/ 확인
ls -la agents/architect.md agents/test-engineer.md agents/implementer.md agents/reviewer.md agents/simplifier.md agents/debugger.md agents/security-reviewer.md

# 6.5 .claude/rules/ 확인
ls -la .claude/rules/session-routine.md .claude/rules/coding-standards.md .claude/rules/git-workflow.md

# 6.6 AGENTS.md 내부 참조 경로 검증
# AGENTS.md에 명시된 모든 파일 경로가 실제로 존재하는지 확인

# 6.7 ARCHITECTURE.md의 폴더 목록이 실제 디렉토리와 일치하는지 확인

# 6.8 package.json scripts 확인
node -e "const pkg=require('./package.json'); console.log(pkg.scripts['lint:arch'] ? '✅ lint:arch' : '❌ lint:arch 누락'); console.log(pkg.scripts['validate'] ? '✅ validate' : '❌ validate 누락');"

# 6.9 structural-test.ts 실행 가능 여부 (dry run)
npx tsx scripts/structural-test.ts 2>&1 || echo "⚠️ structural-test 실행 실패 — 수동 확인 필요"

# 6.10 feature_list.json이 valid JSON인지 확인
node -e "JSON.parse(require('fs').readFileSync('feature_list.json','utf8')); console.log('✅ feature_list.json valid');" 2>&1 || echo "❌ feature_list.json invalid"

# 6.11 템플릿 기반 파일에 미치환 플레이스홀더가 없는지 확인
grep -r '{{.*}}' agents/ .claude/rules/ init.sh scripts/doc-freshness.ts docs/TECH_DEBT.md 2>/dev/null && echo "❌ 미치환 플레이스홀더 발견" || echo "✅ 플레이스홀더 모두 치환됨"

# 6.12 .harness-manifest.json 검증
node -e "
const m=JSON.parse(require('fs').readFileSync('.harness-manifest.json','utf8'));
console.log(m.harness?.version ? '✅ harness.version: '+m.harness.version : '❌ harness.version 누락');
console.log(m.profile?.architectureType ? '✅ profile 존재' : '❌ profile 누락');
const files=Object.keys(m.files||{});
const missing=files.filter(f=>!require('fs').existsSync(f));
console.log(missing.length===0 ? '✅ files 항목 정합 ('+files.length+'개)' : '❌ 누락 파일: '+missing.join(', '));
" 2>&1 || echo "❌ .harness-manifest.json 검증 실패"
```

### 검증 결과 판정
- 모든 항목 통과 → Phase 4로 진행
- 일부 실패 → 아래 자동 수정 전략에 따라 1회 시도, 그래도 실패 시 사용자에게 보고
- 치명적 실패 (파일 생성 자체가 안 됨) → 즉시 사용자에게 보고

### 자동 수정 가능 항목

| 검증 항목 | 자동 수정 방법 |
|-----------|--------------|
| 파일 누락 (6.1/6.2/6.3/6.4/6.5) | 해당 파일을 다시 생성 |
| AGENTS.md 경로 불일치 (6.6) | AGENTS.md에서 잘못된 경로를 실제 경로로 수정 |
| package.json scripts 누락 (6.8) | 누락된 script를 다시 추가 |
| feature_list.json invalid JSON (6.10) | 파일을 빈 배열 `[]`로 재생성 |
| 미치환 플레이스홀더 (6.11) | 해당 파일의 플레이스홀더를 프로필 기본값으로 재치환 |
| manifest 누락/불일치 (6.12) | .harness-manifest.json을 프로필 기반으로 재생성 |

### 자동 수정 불가 항목 (사용자 보고)

| 검증 항목 | 사용자에게 보고할 내용 |
|-----------|---------------------|
| ARCHITECTURE.md 폴더 불일치 (6.7) | 어떤 폴더가 불일치하는지 목록 제시 |
| structural-test.ts 실행 실패 (6.9) | 에러 메시지와 함께 수동 수정 제안 |

---

## 7. Phase 4: 보고

최종 결과를 사용자에게 보고한다.

### 보고 포맷

```
## ✅ 하네스 셋업 완료

### 프로젝트 프로필
- 프로젝트: {프로젝트명}
- 아키텍처: {유형}
- 적용 프리셋: {프리셋명 또는 커스텀}

### 생성된 파일
| 파일 | 상태 | 설명 |
|------|------|------|
| CLAUDE.md | ✅ | Claude Code 지침서 ({N}줄) |
| AGENTS.md | ✅ | 에이전트 입구 문서 ({N}줄) |
| ARCHITECTURE.md | ✅ | {아키텍처 유형} 규칙 문서 |
| agents/*.md | ✅ | TDD subagent 정의 (7개) |
| .claude/rules/session-routine.md | ✅ | TDD 오케스트레이션 플로우 |
| .claude/rules/coding-standards.md | ✅ | 코드 규칙 |
| .claude/rules/git-workflow.md | ✅ | Git 워크플로 규칙 |
| feature_list.json | ✅ | 기능 {N}개 |
| claude-progress.txt | ✅ | 초기 기록 (TDD STATE 포맷 포함) |
| init.sh | ✅ | 환경 초기화 스크립트 |
| docs/ | ✅ | 하위 디렉토리 |
| scripts/structural-test.ts | ✅ | 아키텍처 규칙 검증 |
| scripts/doc-freshness.ts | ✅ | 문서 최신성 검사 |
| docs/HARNESS_FRICTION.md | ✅ | 마찰 로그 (피드백 수집) |
| package.json | ✅ 수정 | lint:arch, validate 추가 |
| .harness-manifest.json | ✅ | 버전 추적 매니페스트 (v{version}) |

### 검증 결과
- ✅ 파일 경로 일관성: 통과
- ✅ JSON 유효성: 통과
- ✅ structural-test: 통과 (위반 {N}건)
- ✅ package.json scripts: 정상
- ✅ agents/ 파일 (7개): 정상
- ✅ .claude/rules/ 파일 (3개): 정상
- ✅ 플레이스홀더 치환: 완료
- ✅ .harness-manifest.json: 정상

### 다음 단계
1. `npm run validate`를 실행하여 전체 검증이 동작하는지 확인하세요
2. AGENTS.md를 읽고 프로젝트 설명이 정확한지 확인하세요
3. `.harness-manifest.json`을 커밋하세요 — 향후 `harness upgrade`로 자동 업그레이드할 수 있습니다
   - 팀 환경에서는 커밋하면 팀 전체에 반영됩니다
4. `.harness-profile.json`은 삭제해도 됩니다 — 프로필은 `.harness-manifest.json`에 보존되었습니다
5. feature_list.json에 구현할 기능을 추가하세요
6. 첫 번째 기능을 선택하고 TDD 사이클을 시작하세요

### TDD 워크플로 안내
기능 구현은 TDD subagent 파이프라인을 따릅니다:

**사이클**: Architect → Test Engineer (Red) → Implementer (Green) → Reviewer → Simplifier (Refactor)
**상세 플로우**: `.claude/rules/session-routine.md` 참조
**에이전트 정의**: `agents/` 디렉토리

**세션 시작**: claude-progress.txt → git status → git log → feature_list.json → validate (회귀 체크) → TDD 사이클
**세션 종료**: validate → feature_list.json 업데이트 → progress 기록 → git-workflow.md 규칙에 따라 커밋 제안

### 운용 스킬 (선택)
하네스 운용에 도움이 되는 컴패니언 스킬을 사용할 수 있습니다:
- **피드백 분석**: `claude --add-dir ~/.claude/skills/harness-setup/companion-skills/harness-feedback`
  - docs/HARNESS_FRICTION.md에 누적된 마찰 이벤트를 분석하여 harness-setup 리포에 개선 Issue를 생성합니다
```

---

## 8. 절대 규칙

### 파일 보호
- 기존 소스 코드 (.ts, .tsx, .js, .jsx, .css 등)를 수정하지 않는다
- 기존 설정 파일을 덮어쓰지 않는다 (merge만 허용, 그것도 scripts 필드에 한정)
- 이미 존재하는 하네스 파일을 덮어쓰지 않는다 (skipFiles 대상)
- node_modules, .git, 프레임워크 캐시 디렉토리(.next, dist 등)에 접근하지 않는다

### 문서 품질
- AGENTS.md는 100줄을 넘기지 않는다
- 모든 문서의 경로 참조는 실제 파일/폴더와 일치해야 한다
- 플레이스홀더 텍스트(TODO, TBD, Lorem 등)를 남기지 않는다
- 한국어로 작성한다 (사용자 요청이 없는 한)

### 실행 안전
- git commit은 자동으로 하지 않는다 (사용자에게 제안만)
- npm install 등 의존성 설치는 자동으로 하지 않는다

---

## 9. 에러 처리

| 상황 | 대응 |
|------|------|
| `.harness-profile.json`이 없다 | "프로필 파일이 없습니다. `/harness-setup`을 먼저 실행하세요." 후 종료 |
| 프로필 JSON 파싱 실패 | "프로필 파일이 유효한 JSON이 아닙니다." 후 종료 |
| `approved: false` | "프로필이 승인되지 않았습니다. `/harness-setup`을 다시 실행하세요." 후 종료 |
| structural-test.ts 실행 실패 | 에러 내용을 보여주고 수동 수정 제안 |
| 템플릿 파일 누락 | 해당 템플릿의 경로를 보여주고 스킬 설치 확인 요청 |
| 파일 쓰기 권한 없음 | 에러 메시지와 함께 권한 확인 제안 |

---

## 10. 업그레이드 실행

`.harness-profile.json`의 `mode: "upgrade"` 시 이 섹션을 따른다.

### 10.1 파일 카테고리

#### 카테고리 정의

| 카테고리 | 소유권 | 업그레이드 동작 |
|----------|--------|----------------|
| **managed** | 스킬 소유 | 최신 템플릿 + profile 값으로 재생성하여 덮어쓰기 |
| **custom** | 사용자 소유 | 덮어쓰지 않음. 마이그레이션 지시에 따라 외과적 수정 (섹션 추가/변경) |
| **data** | 사용자 소유 | 절대 수정 안 함. 스키마 변경 시에만 필드 추가 (기본값 적용) |

#### 파일별 분류

| # | 파일 | 카테고리 | 근거 |
|---|------|----------|------|
| 1 | `docs/` 하위 디렉토리 (4개) | managed | 구조적 스캐폴딩, 사용자 콘텐츠 없음 |
| 2 | `ARCHITECTURE.md` | custom | 사용자가 도메인별 설명 추가, 의존 규칙 조정 |
| 3 | `AGENTS.md` | custom | 사용자가 프로젝트 맥락 추가, 섹션 수정 |
| 4 | `CLAUDE.md` | custom | 가장 많이 커스터마이징되는 파일 |
| 5 | `.claude/rules/session-routine.md` | managed | 템플릿 기반 TDD 오케스트레이션 |
| 6 | `.claude/rules/coding-standards.md` | managed | 템플릿 기반, 플레이스홀더 값만 다름 |
| 7 | `.claude/rules/git-workflow.md` | managed | 템플릿 기반 |
| 8–14 | `agents/*.md` (7개) | managed | 템플릿 기반 subagent 정의 |
| 15 | `feature_list.json` | data | 런타임 데이터, 기능 항목 축적 |
| 16 | `claude-progress.txt` | data | 세션 상태 누적, 절대 덮어쓰면 안 됨 |
| 17 | `init.sh` | managed | 템플릿 기반 초기화 스크립트 |
| 18 | `scripts/structural-test.ts` | managed | 템플릿 기반 아키텍처 검증 |
| 19 | `scripts/doc-freshness.ts` | managed | 템플릿 기반 문서 최신성 검사 |
| 20 | `docs/QUALITY_SCORE.md` | data | 사용자/에이전트가 점수 기록 |
| 21 | `docs/TECH_DEBT.md` | data | 사용자/에이전트가 부채 항목 축적 |
| 22 | `docs/HARNESS_FRICTION.md` | data | session-routine이 마찰 이벤트 기록 |
| 23 | `package.json` (scripts) | custom | 스킬은 특정 키만 추가, 사용자가 수정했을 수 있음 |

#### managed 파일의 사용자 수정 대응

managed 파일이라도 사용자가 수정했을 수 있다. `templateHash`와 현재 파일 해시가 다르면 3가지 선택지를 제시한다:

1. **덮어쓰기** — 최신 템플릿으로 교체 (사용자 변경 소실)
2. **스킵** — 현재 파일 유지. manifest에 `"userOverride": true` 표시하여 향후 업그레이드에서도 스킵
3. **병합** — 마이그레이션의 구조적 변경만 적용하고 사용자 추가분 보존 (best-effort)

### 10.2 업그레이드 Phase U3~U5

프로필의 `fileActions` 필드에 따라 실행한다.

```
Phase U3: 실행
  1. manifest.harness.upgradeInProgress ← true
  2. 새 디렉토리 생성 (필요 시)
  3. managed 파일 재생성 (최신 템플릿 + manifest.profile 값)
  4. custom 파일 외과적 수정 (마이그레이션 지시 따름)
  5. data 스키마 패치 (필요 시 필드 추가, 기본값 적용)
  6. package.json scripts 추가 (기존 키 삭제 안 함)
  7. manifest 갱신:
     - harness.version ← 현재 스킬 버전
     - harness.upgradedAt ← now (ISO 8601)
     - harness.upgradeInProgress ← false
     - files 항목 갱신 (해시 재계산, 신규 파일 추가, 삭제 파일 제거)
         ↓
Phase U4: 검증
  기존 Phase 3 (§ 6) 검증 체크리스트 + manifest 정합성:
  - 모든 managed 파일 존재
  - JSON 유효성
  - 플레이스홀더 미치환 잔존 검사
  - manifest.harness.version == 현재 스킬 버전
  - manifest.harness.upgradeInProgress == false
         ↓
Phase U5: 보고
```

#### Phase U5 보고 포맷

```
## ✅ 하네스 업그레이드 완료

### 버전
- {이전 버전} → {현재 버전}
- 적용된 마이그레이션: {N}개

### 변경 요약
| 작업 | 파일 수 |
|------|---------|
| 덮어쓰기 (managed) | {N}개 |
| 부분 수정 (custom) | {N}개 |
| 신규 생성 | {N}개 |
| 스킵 (data) | {N}개 |
| 사용자 스킵 (userOverride) | {N}개 |

### 주의 사항
- {마이그레이션별 특이사항}

### 다음 단계
1. 변경된 파일을 확인하세요
2. `npm run validate`를 실행하여 검증하세요
3. `.harness-manifest.json`을 커밋하세요
```

### 10.3 마이그레이션 레지스트리

#### 마이그레이션 형식

각 마이그레이션은 다음 구조를 따른다:

```markdown
#### M-{from}-to-{to}: {title}

**조건**: harness.version == "{from}"
**결과**: harness.version → "{to}"

**변경 목록**:

1. [managed] {file}: {description}
   - 작업: overwrite

2. [custom] {file}: {description}
   - 작업: add-section | modify-section
   - 위치: {heading or marker to locate}
   - 내용: {what to add or change}
   - 보존: {what NOT to touch}

3. [new] {file}: {description}
   - 카테고리: managed | custom | data
   - 템플릿: {template path or "dynamic"}

4. [remove] {file}: {reason}
   - 작업: delete | deprecate

5. [data] {file}: {schema change}
   - 작업: add-field | rename-field
   - 상세: {field name, default value}

6. [profile] {field}: {description}
   - 작업: add | rename | remove
   - 기본값: {value}
   - 소스: {where to derive, or "사용자에게 질문"}
```

#### 변경 항목 타입

| 타입 | 대상 | 실행 방법 |
|------|------|----------|
| `[managed] overwrite` | managed 파일 | 템플릿 읽기 → profile로 플레이스홀더 치환 → 파일 쓰기 |
| `[custom] add-section` | custom 파일 | 파일 읽기 → 지정 위치 찾기 → 내용 삽입 → 파일 쓰기 |
| `[custom] modify-section` | custom 파일 | 파일 읽기 → 지정 섹션 찾기 → 변경 적용 (주변 보존) → 파일 쓰기 |
| `[new]` | 신규 파일 | 초기 셋업과 동일하게 생성 |
| `[remove] delete` | 삭제 파일 | 사용자 확인 후 삭제, manifest에서 제거 |
| `[remove] deprecate` | 폐기 파일 | manifest에 `deprecated: true` 표시, 사용자에게 알림 |
| `[data] add-field` | data 파일 | JSON 읽기 → 필드 추가 (기본값) → JSON 쓰기 |
| `[profile] add` | manifest profile | 새 profile 필드 추가 (기본값 또는 사용자 질문) |

#### 체이닝

버전 갭이 여러 단계일 때 마이그레이션을 순차 적용한다:

```
M-3.3-to-4.0 → M-4.0-to-4.1 → M-4.1-to-5.0
```

각 마이그레이션이 완료되면 manifest의 `harness.version`을 해당 단계의 `{to}` 값으로 갱신한 뒤 다음 마이그레이션으로 진행한다. 중단 시 현재까지 적용된 버전이 manifest에 기록되어 있으므로 재시작이 안전하다.

#### 등록된 마이그레이션

> 현재 등록된 마이그레이션 없음. 다음 스킬 버전 변경 시 여기에 추가한다.

### 10.4 엣지 케이스

#### 중단된 업그레이드

**감지**: `harness.upgradeInProgress == true`
**대응**: "이전 업그레이드가 중단된 것 같습니다. 처음부터 다시 진행할까요?" — managed 파일 재생성은 멱등이므로 재실행이 안전하다. custom 파일 외과적 수정도 멱등으로 설계한다 ("이 행이 없으면 추가" 패턴).

#### 새 플레이스홀더 등장

스킬 업데이트로 새 플레이스홀더 `{{NEW_FIELD}}`가 추가된 경우:
- 마이그레이션에 `[profile] add` 항목으로 기술
- 기본값이 있으면 자동 적용, 없으면 프로필에서 사용자 응답을 확인
- manifest의 `profile`에 새 필드 추가

#### 프리셋 삭제/변경

사용된 프리셋이 스킬에서 삭제된 경우:
- manifest의 `profile`에 저장된 값으로 폴백 (프리셋 없이도 동작)
- 경고: "프리셋 '{name}'을 찾을 수 없습니다. 매니페스트의 프로필 값을 사용합니다."

#### 파일 삭제 (신규 버전에서 제거)

마이그레이션의 `[remove]` 항목:
- `delete`: 사용자 확인 후 삭제, manifest에서 제거
- `deprecate`: manifest에 `deprecated: true` 표시, 삭제 여부는 사용자 결정
- **자동 삭제하지 않는다** — 항상 사용자 확인

#### 신규 파일 추가

마이그레이션의 `[new]` 항목:
- 초기 셋업과 동일하게 생성 (템플릿 + profile 치환)
- manifest의 `files`에 새 항목 추가
- 이미 같은 경로에 파일이 있으면: "이미 {path}가 존재합니다. 덮어쓸까요?" 확인

---

## 11. 참고 자료

### 스캐폴딩 시 참조 지침
Phase 2에서 파일을 생성할 때, 다음 참조를 읽어 구현의 기본 구조를 가져온다:

| 생성 파일 | 1차 소스 (템플릿) | 2차 참조 | 참조 방법 |
|-----------|------------------|----------|----------|
| scripts/structural-test.ts | `templates/structural-test-*.ts` | `harness-guide.md` P8 | 아키텍처 유형에 맞는 템플릿 선택 후 LAYER_RULES 치환 |
| scripts/doc-freshness.ts | `templates/doc-freshness.ts` | `harness-guide.md` P10 | 템플릿의 DOC_FRESHNESS_DAYS, DOC_CHECK_TARGETS 치환 |
| init.sh | `templates/init.sh` | `harness-guide.md` P5 | 템플릿의 DEV_SERVER_COMMAND 등 치환 |
| docs/QUALITY_SCORE.md | `templates/QUALITY_SCORE.md` | — | 그대로 복사 (플레이스홀더 없음) |
| docs/TECH_DEBT.md | `templates/TECH_DEBT.md` | — | CREATED_DATE 치환 |
| docs/HARNESS_FRICTION.md | `templates/HARNESS_FRICTION.md` | — | 그대로 복사 (플레이스홀더 없음) |
| AGENTS.md | `references/harness-guide.md` P2 섹션 | 형식 참고 (내용은 프로필 기반으로 작성) |

### 파일 목록
- `references/harness-guide.md` — Anthropic + OpenAI 하네스 엔지니어링 통합 가이드 (P1~P10 프로세스)
- `references/project-context.md` — 이 스킬의 설계 결정 기록, 버전 히스토리, 다음 단계
- `references/upgrade-system-design.md` — 업그레이드 시스템 설계 문서 (매니페스트, 카테고리, 마이그레이션)

### 우선순위 규칙
**이 파일(harness-scaffold/SKILL.md)이 스캐폴딩의 정규 사양이다.** 이 파일과 harness-guide.md의 내용이 충돌하면 이 파일이 우선한다.
