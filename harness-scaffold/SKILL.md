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
- 프로필 데이터를 기반으로 19개 파일을 의존 순서대로 생성한다 (+ package.json scripts 수정, 옵트인 시 ESLint 설정 수정·외부 통합 연계 렌더링)
- 생성 후 15항목 검증 체크리스트를 자동 실행한다
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
  "version": "1.17.0",
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
  "sharedDirs": ["shared"],
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
  "autoCommit": {
    "mode": "confirm",
    "pushAfterCommit": true
  },
  "docFreshnessDays": 14,
  "eslintAssist": {
    "enabled": true,
    "configFile": "eslint.config.js",
    "configFormat": "flat",
    "layerRules": true,
    "maxLines": 300
  },
  "e2e": {
    "enabled": true,
    "framework": "playwright",
    "playwrightVersion": "1.48.0",
    "prePush": true,
    "mcp": { "enabled": true, "version": "0.0.76" }
  },
  "integrations": {
    "superpowers": {
      "enabled": true,
      "source": "plugin",
      "detectedVersion": "5.1.0",
      "installPath": "~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0",
      "linkedSkills": ["brainstorming", "systematic-debugging", "writing-plans"]
    },
    "multiModelConsult": {
      "enabled": true,
      "source": "companion",
      "detectedVersion": null,
      "installPath": "~/.claude/skills/multi-model-consult"
    }
  },
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
- `scripts.test`는 **비대화형(단발 실행) 명령**이다 — watch 기본 러너(예: `vitest` 단독)는 분석 단계에서 `npm run test:run` 형태로 기록되며, § 5.5가 `test:run` 키를 package.json에 추가한다. `{{TEST_COMMAND}}`와 `{{VALIDATE_COMMAND}}`의 안전성이 이 규칙에 의존한다.
- `sharedDirs`는 **domain-based 전용** 선택 필드다 — structural-test-domain의 `{{SHARED_DIRS}}` 원천. 생략 시 기본 `["shared"]`.
- `integrations`는 사용자가 문답에서 옵트인한 경우에만 존재한다 (선택 필드, `integrations.<name>` 구조). 생략 시 외부 연계 산출물을 생성하지 않는다 (§ 5.16). 통합 메커니즘 규약: `references/integrations/_protocol.md`. 각 통합의 연계 내용은 `references/integrations/<name>-mapping.md`가 정본. superpowers의 `linkedSkills`는 매핑 정본의 연계/선택 목록에 있는 것만 렌더링된다.
- `e2e`는 사용자가 문답에서 옵트인한 경우에만 존재한다 (선택 필드). 생략 시 E2E 스캐폴드 산출물을 생성하지 않는다 (§ 5.17). 프론트엔드 프로젝트에서만 제안된다(프론트엔드 프리셋이 `enabled:true` 권장 기본을 제공할 수 있으나, 최종적으로 프로필에 `e2e`가 있을 때만 생성한다 — 옵트인 계약 불변). `playwrightVersion`은 핀 버전이며 § 5.5가 package.json devDependencies에 직접 사용한다 (`scripts.lint:arch`와 동일하게 프로필에서 읽음 — 새 플레이스홀더 아님). `prePush`는 선택 하위 필드(생략=false)로 pre-push 게이트 생성 여부를 결정한다 (§ 5.18). `e2e.enabled` 없이 `prePush`만 있을 수 없다. `mcp`는 선택 객체(`enabled`/`version`)로 브라우저 MCP 탐색 진단 배선 여부를 결정한다 — `e2e.enabled`와 **독립**(스펙 없이 mcp만 가능). 신규 파일 없이 debugger.md `{{MCP_DEBUG_PROTOCOL}}` 치환만 발생(§ 5.19). `version`은 `@playwright/mcp` exact 핀.
- `autoCommit`은 사용자가 옵트인한 경우에만 존재한다 (선택 필드). 생략 시 `mode: "off"`로 간주하여 git-workflow.md의 `{{AUTO_COMMIT_MODE}}`를 `off`로 치환한다 (제안만 — 기존 동작).
- `extras`의 각 항목은 문답에서 확인된 경우에만 존재한다. 없는 키는 해당 섹션 생략을 의미한다.
- `eslintAssist`는 사용자가 문답에서 옵트인한 경우에만 존재한다 (선택 필드 — 프리셋 비대상, 감지+문답 전용). 생략 시 ESLint 설정을 수정하지 않는다 (§ 5.15). `configFormat`은 설정 파일 형식: `"flat"`(eslint.config.*) 또는 `"legacy"`(.eslintrc.*).
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
14. scripts/harness-check.sh (하네스 자가진단 — § 5.14, 검사 대상 스크립트들 뒤에 생성)
15. docs/QUALITY_SCORE.md (품질 점수표 초기값)
16. docs/TECH_DEBT.md (기술 부채 빈 템플릿)
17. docs/HARNESS_FRICTION.md (마찰 이벤트 정적 참조 문서 — § 5.12)
17-b. .harness-friction.jsonl (빈 마찰 로그 싱크 — 프로젝트 루트, data 카테고리; harness-feedback이 파일 부재와 0건을 구분하도록 빈 파일로 생성 — § 5.12.1)
18. package.json scripts 추가 (harness:check 포함; e2e 옵트인 시 test:e2e + @playwright/test devDep — § 5.5)
19. E2E 스캐폴드 모듈 (e2e 옵트인 시에만 — § 5.17): playwright.config.ts + e2e/ 디렉토리(+ e2e/README.md 작성 가이드)
19-b. pre-push 게이트 (e2e.prePush 옵트인 시에만 — § 5.18): .githooks/pre-push 생성/주입 (git config 미실행)
20. ESLint 보조 규칙 수정 (eslintAssist 옵트인 시에만 — § 5.15)
21. .harness-manifest.json (버전 추적 매니페스트 — § 5.13, 항상 마지막 — Stop hook 종료 조건)
```

**skipFiles 처리**: `skipFiles` 배열에 포함된 파일은 생성을 건너뛴다. 해당 파일이 다른 파일의 의존 대상이면 기존 파일이 존재한다고 가정하고 진행한다.

### 5.1 AGENTS.md 생성 규칙

- 100줄 이내로 작성한다
- 백과사전이 아니라 **목차(Table of Contents)** 역할을 한다
- 프로필에서 확인된 실제 정보를 사용한다
- 플레이스홀더를 남기지 않는다
- AGENTS.md는 **프로젝트 구조와 현재 상태를 안내**하는 문서이다 (범용 에이전트용)
- 빌드/테스트/검증 **명령어는 AGENTS.md의 "## 명령어" 섹션이 source of truth**이다 — CLAUDE.md를 읽지 않는 범용 에이전트(Codex 등)도 명령을 알 수 있어야 한다
- 세션 루틴, 에이전트 디스패치 등 **행동 지침은 CLAUDE.md에** 작성한다

포함해야 할 섹션:
```markdown
# AGENTS.md
## 프로젝트 개요        ← 프로젝트명, 스택, 한 줄 설명
## 명령어                ← 개발 서버(+포트), 테스트, 전체 검증(validate), 아키텍처 검증(lint:arch), 자가진단(harness:check) — 명령어의 source of truth
## 아키텍처              ← ARCHITECTURE.md 링크 + 의존성 방향 한 줄 요약
## 현재 상태             ← claude-progress.txt, feature_list.json 링크
## 주요 규칙             ← 5개 이내의 핵심 규칙
## 문서 맵               ← docs/ 하위 문서 테이블
```

- "주요 규칙"에는 다음 2개를 **반드시 포함**한다 (체크리스트 § 2.1 요건). 나머지(3개 이내)는 프로필에서 추출한다:
  1. feature_list.json의 기능 설명을 수정/삭제하지 않는다
  2. passes는 실제 검증 통과 후에만 true로 바꾼다
- **조건부 — 보조 스킬 섹션**: 프로필 `integrations`에 `enabled == true`인 통합이 있으면 "문서 맵" 앞에 "## 보조 스킬" 섹션을 삽입한다 — 렌더링 규칙: § 5.16. 없으면 섹션 자체를 생성하지 않는다. 줄수는 통합 수에 비례하며, **두 통합(superpowers 3~4줄 + consult 1줄 + 안내 2줄 ≈ 9줄) 합산해도 100줄 예산 내**다 (harness-check ②가 상시 감시)
- 명령어 섹션 추가로 100줄 예산이 줄어들었다 — 문서 맵 테이블과 규칙 설명을 압축하여 100줄 제한을 지킨다 (보조 스킬 섹션 포함 시에도)

### 5.1.1 CLAUDE.md 생성 규칙

CLAUDE.md는 **Claude Code가 세션 시작 시 자동으로 읽는 지침서**이다. AGENTS.md가 "이 프로젝트는 무엇인가"를 설명한다면, CLAUDE.md는 "이 프로젝트에서 어떻게 작업할 것인가"를 지시한다.

- 150줄 이내로 작성한다 (상세 규칙은 `.claude/rules/`로 분리)
- `@AGENTS.md`로 AGENTS.md를 import하여 프로젝트 개요를 중복 작성하지 않는다
- AGENTS.md에 이미 있는 정보(프로젝트 개요, 아키텍처 설명, 문서 맵, **명령어**)를 반복하지 않는다 — 명령어 값의 source of truth는 AGENTS.md "## 명령어"이며 @AGENTS.md import로 자동 로딩된다
- **행동 지침 중심**으로 작성한다: 에이전트 디스패치, 세션 루틴, 운영 사이클, 금지 사항
- 코드 규칙과 세션 루틴 상세는 `.claude/rules/`에 위임한다

포함해야 할 섹션:
```markdown
# CLAUDE.md

@AGENTS.md

<!-- 명령어 섹션 없음 — AGENTS.md "## 명령어"가 source of truth (@AGENTS.md import로 로딩됨) -->

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

## 운영 사이클

| 주기 | 작업 |
|------|------|
| 일간 | `npm run validate` (CI 자동화 권장) |
| 주간 | `npm run doc:check` + docs/QUALITY_SCORE.md 갱신 |
| 격주 | docs/TECH_DEBT.md 검토 (자동 검사 승격 대기 큐 포함) + 리팩터링 세션 |
| 월간 | AGENTS.md/ARCHITECTURE.md 전면 검토 + feature_list passes 재검증 + `npm run harness:check` |

주간/격주/월간 작업은 harness-cleanup 컴패니언 스킬로 실행할 수 있다 (--add-dir 등록 후 "하네스 정리" 요청).

## 금지 사항
- feature_list.json의 기능 설명을 수정/삭제하지 않는다
- 한 번에 여러 기능을 구현하지 않는다
- 테스트 없이 기능을 완료 처리하지 않는다
- 기존에 passes: true였던 기능의 회귀를 무시하고 새 기능을 진행하지 않는다 (회귀 복구 우선)
- Plan 모드 승인 후에도 TDD 사이클(최소 RED → GREEN)을 거치지 않고 기능을 완료하지 않는다
{프로필의 "에이전트가 하면 안 되는 것"에서 추출}

## 하네스 이슈 보고
- 하네스 관련 문제 발생 시 `docs/HARNESS_FRICTION.md`에 기록한다
- 반복되는 문제는 "하네스 피드백 분석해줘"로 자동 Issue 생성 가능
- 수동 보고: https://github.com/daehyunk1m/harness-setup-initializer/issues
```

**AGENTS.md와 CLAUDE.md의 역할 분리:**

원칙: **AGENTS.md = "이 프로젝트는 무엇인가" (맥락)**, **CLAUDE.md = "어떻게 작업할 것인가" (행동)**. 동일한 정보를 두 파일에 모두 적지 않는다. 충돌 시 CLAUDE.md가 행동 지침의 source of truth이다. 단, **명령어 값의 source of truth는 AGENTS.md "## 명령어"**이다 (범용 에이전트 접근성). 코드 규칙과 세션 루틴 상세는 `.claude/rules/`에 위임한다.

| 내용 | CLAUDE.md | .claude/rules/ | AGENTS.md |
|------|-----------|----------------|-----------|
| 프로젝트 개요, 스택 | ❌ (@AGENTS.md import) | ❌ | ✅ (source of truth) |
| 아키텍처 설명, 문서 맵 | ❌ | ❌ | ✅ + ARCHITECTURE.md |
| 빌드/테스트/검증 명령 | ❌ (@AGENTS.md import) | ❌ | ✅ (source of truth) |
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
- 기존 프로젝트 (소스 코드 있음): 아래 **추론 정책**에 따라 현재 구현된 기능을 추론하고 항목을 생성

**기존 프로젝트 추론 정책** (우선순위 순):
1. **라우트 기반 추출** (1순위): 라우팅 정의에서 화면/엔드포인트 단위로 기능 후보를 추출한다
   - Next.js: `app/` 또는 `pages/` 디렉토리의 라우트 파일
   - React Router: 라우트 설정 (routes.ts, createBrowserRouter 등)
   - Express: 라우트 등록 (`app.use`, `router.get/post` 등)
2. **기능 모듈 기반** (2순위): 라우트가 없거나 너무 적으면 features/, services/, controllers/ 등 기능 단위 폴더에서 추출한다
3. **빈 배열** (폴백): 위 방법으로 신뢰할 만한 후보를 얻지 못하면 빈 배열 `[]`로 생성하고, Phase 4 보고에 "feature_list.json에 기능을 직접 추가하세요"를 안내한다

추론 규칙:
- **상한 15개** — 초과분은 핵심 흐름(진입점, 인증, 메인 CRUD) 우선으로 잘라내고, Phase 4 보고에 잘린 개수를 명시한다 (침묵 누락 금지)
- priority: 진입점/핵심 흐름을 1로, 부가 기능일수록 낮게
- 추론된 기능 목록은 Phase 4 보고에 표시하여 사용자가 설명(description, steps)을 검토하도록 안내한다 — "기능 설명 수정 금지" 규칙은 셋업 완료 이후의 에이전트에게 적용되는 것이므로, 셋업 직후 사용자 검토·수정은 권장된다
- passes 필드 설정 기준:
  - `passes: true` — 에이전트가 기능 동작을 **직접 확인**한 경우. 다음 중 하나 이상을 만족해야 한다:
    - 해당 기능의 테스트가 존재하고, 테스트 실행 결과 통과
    - 개발 서버에서 해당 기능을 직접 동작시켜 확인 (E2E, 수동 확인)
    - 기능에 해당하는 steps를 모두 수행하여 통과 확인
  - `passes: false` — 코드는 존재하지만 위 조건을 충족하지 못한 경우. 이 때 `notes: "코드 존재 — 검증 필요"` 기록
  - 하네스 셋업 시점에는 직접 확인이 불가하므로, **기존 코드 기반 추론 항목은 모두 `passes: false`로 설정**한다
  - 이후 에이전트가 세션 종료 루틴에서 검증한 기능만 `passes: true`로 전환한다
- steps는 사용자 관점의 검증 시나리오로 작성하며, **E2E 테스트와 1:1 매핑 가능**해야 한다 — 한 step = 검증 가능한 한 동작 (추상적 설명 금지). 검증 레벨 분류는 생성되는 `.claude/rules/coding-standards.md` § 검증 레벨 참조
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

### 5.3.1 claude-progress.txt 생성 규칙

- 템플릿 없이 프로필 기반으로 직접 생성한다 (data 카테고리 — 이후 에이전트가 세션마다 갱신하며, 업그레이드에서 절대 덮어쓰지 않는다)
- 초기 내용:

```
# Claude Progress

## {YYYY-MM-DD} — 하네스 셋업
- harness-setup {버전}으로 하네스 생성 (프리셋: {프리셋명 또는 "커스텀"})
- feature_list.json: {N}개 기능 (모두 passes: false — 검증 필요)
- 다음 작업: feature_list.json에서 최고 priority 기능 선택 후 TDD 사이클 시작

<!-- TDD STATE 블록 포맷 (사이클 중단 시에만 기록 — 상세: .claude/rules/session-routine.md § TDD STATE 블록)
=== TDD STATE ===
feature: {feature ID}
phase: {PRE-RED | RED | GREEN | REVIEW | SECURITY | REFACTOR}
attempt: {현재 시도 횟수}
plan_ref: {계획 참조}
=== END TDD STATE ===
-->
```

- TDD STATE 블록은 초기에 포함하지 않는다 — 포맷은 주석으로만 안내하고, 사이클 중단 시에 에이전트가 실제 블록을 추가한다
- 이후 갱신(세션 요약 추가, TDD STATE 관리)은 `.claude/rules/session-routine.md`의 세션 종료 절차가 담당한다

### 5.4 structural-test.ts 생성 규칙

- 이 스킬의 `templates/` 디렉토리에서 아키텍처 유형에 맞는 템플릿을 기반으로 생성한다
- 템플릿의 치환 대상:
  - `LAYER_RULES` — 프로필의 `layers.rules` 값으로 치환 (layer-based, fsd)
  - `SHARED_DIRS` — 프로필의 `sharedDirs` 값으로 치환, 생략 시 `['shared']` (domain-based 전용)
  - `PATH_ALIAS` — 프로필의 `pathAlias` 값으로 치환. 배열인 경우 각 alias에 대해 regex를 생성하여 모두 검사한다 (예: `['@/', '~/']` → `@/` 또는 `~/`로 시작하는 import 모두 감지)
  - `SRC_ROOT` — 프로필의 `srcRoot` 값으로 치환
  - `{{Q2_ENFORCEMENT}}` — **Q2(아키텍처 제약) 강제 여부**를 산정하여 `enforced` 또는 `unenforced`로 치환한다 (생성 스크립트 헤더의 `// HARNESS:Q2_ENFORCEMENT=...` 마커가 됨). 산정 규칙:
    - layer/fsd: `layers.rules`에 비어있지 않은 제약(=금지 관계)이 1개 이상이면 `enforced`, 모든 레이어가 빈 배열이면 `unenforced`
    - domain: 항상 `enforced` (도메인 간/역방향 금지 규칙을 코드로 보유)
    - custom: 아래 동적 생성 알고리즘이 기계 검사 규칙을 1개 이상 만들면 `enforced`, 4번 폴백(규칙 없음)이면 `unenforced`
    - harness-check.sh ④-b가 이 마커를 grep하여 단계 판정에 사용한다 (미강제 → MVH 강등, exit 0 경고). manifest `harness.structuralTestEnforcement`에도 같은 값을 기록한다 (§ 5.13)

| 아키텍처 유형 | 사용 템플릿 | 검증 항목 |
|--------------|-----------|----------|
| 레이어 기반 (`layer-based`) | `templates/structural-test-layer.ts` | 레이어 의존성 방향 (alias + 상대경로) |
| FSD (`fsd`) | `templates/structural-test-fsd.ts` | 레이어 의존성 + cross-slice import + public API |
| 도메인 기반 (`domain-based`) | `templates/structural-test-domain.ts` | 도메인 간 직접 import 금지 + 공유 모듈 → 도메인 역방향 금지 (도메인 목록은 실행 시점에 srcRoot 하위 디렉토리에서 발견 — 도메인 추가/삭제 시 스크립트 수정 불필요) |
| 자유 구조 (`custom`) | 동적 생성 (아래 알고리즘) | 프로필에서 기계 검사 가능한 규칙만 |

**custom 유형 동적 생성 알고리즘** (템플릿 없음):
1. 프로필에 `layers.rules`가 있으면 → `structural-test-layer.ts`와 동일한 검사 엔진으로 생성 (LAYER_RULES 치환과 동일 효과)
2. `extraArchitectureRules` 중 기계 검사로 변환 가능한 규칙("X에서 Y를 import하지 않는다" 패턴)을 import 검사로 추가한다
3. 기계 검사로 변환 불가능한 규칙은 스크립트 상단 주석에 나열한다 (수동 리뷰 대상임을 명시)
4. 1~2에 해당하는 규칙이 하나도 없으면: "ℹ️ 기계 검사 가능한 아키텍처 규칙 없음 — ARCHITECTURE.md를 수동으로 준수하세요"를 출력하고 exit 0하는 최소 스크립트를 생성한다 (validate 체인이 깨지지 않도록). **이 폴백 스크립트 헤더에는 반드시 `// HARNESS:Q2_ENFORCEMENT=unenforced` 마커를 직접 기입한다** (1~2로 규칙을 생성한 경우는 `enforced`). 템플릿이 없으므로 마커 줄을 직접 작성한다 — harness-check이 이 마커로 Q2 미강제를 감지해 MVH로 강등한다
5. 동적 생성된 custom용 structural-test.ts는 템플릿 매핑이 없으므로 § 12.6 자동 감지 대상에서 제외된다 — 변경이 필요하면 마이그레이션으로 처리한다

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
  - `harness:check`: 하네스 자가진단 — `bash scripts/harness-check.sh`
  - `test:run` (조건부): 기존 `test` 스크립트가 watch 기본(예: `vitest` 단독)일 때만 추가 — 단발 실행 형태 (예: `vitest run`). 기존 `test` 키는 수정하지 않는다
  - `test:e2e` (조건부): 프로필에 `e2e.enabled`가 있을 때만 추가 — `playwright test`
- 기존에 같은 이름의 script가 있으면 스킵한다
- Node 스크립트로 안전하게 수정한다:

```bash
node -e "
const fs = require('fs');
const pkg = require('./package.json');
const toAdd = {
  'lint:arch': '{프로필에서 가져온 lint:arch 명령}',
  'validate': '{프로필에서 가져온 validate 명령}',
  'doc:check': '{프로필에서 가져온 doc:check 명령}',
  'harness:check': 'bash scripts/harness-check.sh'
};
// 기존 test가 watch 기본일 때만: toAdd['test:run'] = '{단발 실행 명령, 예: vitest run}';
// e2e 옵트인 시에만: toAdd['test:e2e'] = 'playwright test';
let changed = false;
for (const [key, val] of Object.entries(toAdd)) {
  if (!pkg.scripts[key]) { pkg.scripts[key] = val; changed = true; }
}
// e2e 옵트인 시: @playwright/test devDependency add-only 머지 (설치는 실행하지 않음 — Phase 4 안내)
// const PW_VERSION = '{프로필 e2e.playwrightVersion}';
// pkg.devDependencies = pkg.devDependencies || {};
// if (!pkg.devDependencies['@playwright/test']) { pkg.devDependencies['@playwright/test'] = '^' + PW_VERSION; changed = true; }
if (changed) {
  fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
  console.log('✅ package.json 업데이트 완료');
} else {
  console.log('ℹ️ 추가할 항목 없음 (이미 존재)');
}
"
```

**E2E 머지 (e2e 옵트인 시에만)**:
- `scripts.test:e2e` ← `playwright test` (키 부재 시에만 추가)
- `devDependencies['@playwright/test']` ← `^{profile.e2e.playwrightVersion}` (키 부재 시에만 추가). **install은 실행하지 않는다** — Phase 4에서 `npm i && npx playwright install` 안내
- `test:e2e`는 **validate에 포함하지 않는다** — 전체 E2E는 빠른 검증 루프와 분리한다 (브라우저·dev 서버 기동 비용). E2E는 별도 VERIFY(E2E) 단계(증분 2a — session-routine Phase 4.7, validate 비편입)에서 TDD 사이클에 배선되고, @critical 기반 pre-push 강제는 증분 2b에서 다룬다

validate 명령 조합 규칙:
- typecheck 명령이 package.json scripts에 있으면 포함, 없으면 생략
- lint 명령이 있으면 포함, 없으면 생략
- lint:arch는 항상 포함
- test 명령이 있으면 포함, 없으면 생략
- **validate를 구성하는 모든 명령은 비대화형(단발 실행)이어야 한다** — watch/serve 모드 명령이 섞이면 에이전트 검증 루프와 harness:check가 영구 대기한다. 기존 `test`가 watch 기본이면 `npm run test` 대신 `npm run test:run`을 조합에 사용한다
- `harness:check`는 validate에 **포함하지 않는다** — harness-check.sh가 validate를 호출하므로 순환이 생긴다
- 예시: `npm run typecheck && npm run lint && npm run lint:arch && npm run test`
- 예시 (typecheck 없는 경우): `npm run lint && npm run lint:arch && npm run test`
- 예시 (test가 watch 기본인 경우): `npm run lint && npm run lint:arch && npm run test:run`

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
  - API 서버처럼 루트 경로가 404를 반환할 수 있는 경우, **연결 성공 자체를 200으로 정규화**하는 형태를 허용한다 (예: `curl -s -o /dev/null URL && echo 200 || echo 000` — curl은 `-f` 없이는 404에도 exit 0이므로 "서버 응답 = 준비 완료"로 판정된다)
  - readyCheck 명령이 exit 0이지만 "200"이 없으면 준비 미완료로 간주한다
  - 30초(30회 반복) 내 "200"이 나오지 않으면 경고를 출력하고 계속 진행한다 (중단하지 않음)

### 5.7 doc-freshness.ts 생성 규칙

- 이 스킬의 `templates/doc-freshness.ts` 템플릿을 기반으로 생성하고, 플레이스홀더를 프로필 값으로 치환한다
- 템플릿 치환 대상:
  - `{{DOC_FRESHNESS_DAYS}}` — 프로필의 docFreshnessDays 값 (기본값: 14)
  - `{{DOC_CHECK_TARGETS}}` — 검사 대상 파일 경로 배열 (TypeScript 배열 리터럴로 치환, 예: `['AGENTS.md', 'ARCHITECTURE.md', 'docs/QUALITY_SCORE.md', 'docs/TECH_DEBT.md']`)
- 문서 최신성을 검사하는 스크립트를 생성한다: `npx tsx scripts/doc-freshness.ts`
- 검사 대상 문서 (**정적 목록** — `{{DOC_CHECK_TARGETS}}`에 명시된 파일만 검사한다):
  - AGENTS.md
  - ARCHITECTURE.md
  - docs/ 하위 문서 중 **갱신 의무가 있는 것** (QUALITY_SCORE.md, TECH_DEBT.md)
  - **이벤트 로그는 제외한다** (docs/HARNESS_FRICTION.md, docs/CLEANUP_LOG.md 등) — 추가형(append-only) 로그는 오래됨이 문제가 아니므로 staleness 경고가 무의미하다
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
- "자동 검사 승격 대기 큐" 섹션은 리뷰에서 반복된 지적의 승격 후보를 기록한다 — Reviewer가 표시하고 오케스트레이터가 기록한다 (상세: 생성되는 `.claude/rules/session-routine.md` § Phase 4)

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
| `{{MCP_DEBUG_PROTOCOL}}` | `e2e.mcp.enabled`면 § 5.19 블록으로 치환(`version` 인라인), 아니면 빈 문자열. debugger.md 전용 | (§ 5.19 블록 또는 빈칸) | debugger |

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
| `{{E2E_COMMAND}}` | 패키지매니저 run + `test:e2e` 스크립트 (e2e.enabled 시 § 5.5가 생성, scripts.test/validate와 동일한 패키지매니저 prefix — 예: `yarn test:e2e`) — VALIDATE/TEST_COMMAND처럼 **항상 치환**한다(e2e 미옵트인이어도 Phase 4.7이 런타임 게이트라 무해, 미치환 잔존은 6.11에서 에러). 유닛 러너(TEST_COMMAND)와 구분: VERIFY(E2E)는 반드시 E2E 러너로 실행해야 `.e2e.ts`를 수집한다 | `npm run test:e2e` |
| `{{SECURITY_CATEGORIES}}` | 프로필 tdd.securityCategories | `auth, security, api, payment` |
| `{{MAX_IMPLEMENTER_ATTEMPTS}}` | 프로필 tdd.maxImplementerAttempts | `3` |
| `{{MAX_DEBUGGER_ATTEMPTS}}` | 프로필 tdd.maxDebuggerAttempts | `2` |
| `{{INTEGRATION_NOTES}}` | 프로필 integrations — session-routine 연계 문구가 있는 생존 통합들(superpowers의 `writing-plans`, multiModelConsult 등)의 문구를 합산. 해당 통합 없음/integrations 생략 시 **빈 문자열** | 빈 문자열 |

> `{{INTEGRATION_NOTES}}`는 **반드시 치환**한다 (빈 값이어도) — 미치환 잔존은 6.11에서 에러. 빈 문자열 치환으로 남는 빈 줄 1개는 무해하다. 조건부 텍스트를 플레이스홀더로 처리하는 이유: scaffold가 템플릿 밖 텍스트를 임의 삽입하면 § 12.6 자동 감지(템플릿 재렌더링 해시 비교)가 깨진다.

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
| `{{AUTO_COMMIT_MODE}}` | 프로필 autoCommit.mode | `off` |
| `{{AUTO_COMMIT_PUSH}}` | 프로필 autoCommit.pushAfterCommit → 라벨 (`true` → `예 (커밋 후 자동 push)`, `false` → `아니오 (push는 수동)`) | `예 (커밋 후 자동 push)` |

#### 5.11.4 CLAUDE.md와의 역할 분리

`.claude/rules/` 파일이 생성되면 CLAUDE.md에서 해당 내용을 제거한다:

| 내용 | CLAUDE.md | .claude/rules/ | 비고 |
|------|-----------|----------------|------|
| TDD 플로우 상세 | ❌ | session-routine.md | Agent Dispatch 테이블만 CLAUDE.md에 유지 |
| 에스컬레이션 규칙 | ❌ | session-routine.md | |
| 코드 규칙 (네이밍 등) | ❌ | coding-standards.md | |
| 아키텍처 유형별 핵심 규칙 | ❌ | coding-standards.md | |
| 명령어 | ❌ | ❌ | AGENTS.md "## 명령어"가 source of truth (@AGENTS.md import로 로딩) |
| @AGENTS.md import | ✅ | ❌ | |
| Agent Dispatch 테이블 | ✅ | ❌ | 간략 버전 (어떤 에이전트가 있는지) |
| 금지 사항 | ✅ | coding-standards.md에도 포함 | 중요한 것은 양쪽 모두 |

### 5.12 docs/HARNESS_FRICTION.md 생성 규칙

- 이 스킬의 `templates/HARNESS_FRICTION.md` 템플릿을 그대로 복사하여 생성한다 (플레이스홀더 없음)
- **정적 참조 문서**다 — 더 이상 마찰 로그 테이블을 담지 않는다. 마찰 이벤트는 `.harness-friction.jsonl`(프로젝트 루트, 진실 원본)에 한 줄씩 append되며, session-routine.md가 기록 주체다 (§ 5.12.1)
- 담는 내용: 이벤트 유형/심각도 참조표, 하네스 이슈 보고 안내, 그리고 "마찰 이벤트는 `.harness-friction.jsonl`에 자동 기록되며 '하네스 피드백 분석해줘'로 분석한다"는 포인터
- 이벤트 유형 (참조용): TDD — `implementer-retry`(high), `debugger-escalation`(critical), `user-escalation`(critical), `review-fix`(medium), `refactor-rollback`(high), `e2e-fail`(high), `session-incomplete`(low); 하네스 이슈 — `setup-mismatch`, `structural-test-false-positive/negative`, `init-failure`, `rule-conflict`, `agent-hallucination`, `doc-stale`(harness-cleanup가 기록)

### 5.12.1 .harness-friction.jsonl 생성 규칙

- 마찰 이벤트의 **진실 원본**이다 — 프로젝트 루트에 둔다(`docs/` 아래가 아님). append-only, git 커밋 대상
- 스캐폴드 시 **빈 파일**로 생성한다: `: > .harness-friction.jsonl` (또는 `touch .harness-friction.jsonl`). harness-feedback이 파일 부재("not found")와 0건("기록된 이벤트 없음")을 구분할 수 있도록 빈 줄도 넣지 않는다
- session-routine.md가 마찰 이벤트 감지 시 한 줄을 append한다. 한 줄 = 1 이벤트, JSON 객체:
  ```json
  {"ts":"2026-06-16T12:34:56Z","session":"2026-06-16T09-12-03Z-a3f9","event":"implementer-retry","severity":"high","feature":"F-12","detail":"타입 에러 3회 반복"}
  ```
  필드: `ts`(이벤트 발생 시각 ISO8601 UTC), `session`(세션 고유 ID — `{ISO 시각}-{4자 난수}` 예 `2026-06-16T09-12-03Z-a3f9`), `event`(이벤트 유형 enum), `severity`(`low`|`medium`|`high`|`critical`), `feature`(feature ID 또는 `""`), `detail`(소독된 원인 한 줄 ≤50자). 기록 시점·소독 규칙·세션 ID 생성은 생성되는 `.claude/rules/session-routine.md`가 정본
- manifest category는 **`data`**다 (§ 5.13·§ 10.1) — 템플릿 해시 드리프트 검사 제외(feature_list.json과 동일 취급). harness-feedback이 직접 읽고 분석하는 입력이다
- **이 증분에서 Stop hook / `.claude/settings.json` / friction-detect.mjs는 생성하지 않는다** (옵션 i — 오케스트레이터의 저비용 append가 주 메커니즘)

### 5.13 .harness-manifest.json 생성 규칙

Phase 2의 **마지막 단계**로, 모든 파일 생성이 완료된 후 `.harness-manifest.json`을 생성한다. 이 파일은 하네스의 버전과 생성 이력을 추적하는 **단일 참조 파일**이다.

#### 스키마

```json
{
  "harness": {
    "version": "1.0.0",
    "skillVersion": "1.0.0",
    "installedAt": "2026-04-07T09:30:00Z",
    "upgradedAt": null,
    "upgradeInProgress": false,
    "preset": "react-next",
    "structuralTestEnforcement": "enforced",
    "semanticApprovalAt": null
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
    "autoCommit": {
      "mode": "confirm",
      "pushAfterCommit": true
    },
    "docFreshnessDays": 14,
    "eslintAssist": {
      "enabled": true,
      "configFile": "eslint.config.js",
      "configFormat": "flat",
      "layerRules": true,
      "maxLines": 300
    }
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
| `harness.structuralTestEnforcement` | structural-test가 기계 검사 규칙을 실제로 강제하는지: `"enforced"` 또는 `"unenforced"` (§ 5.4 `{{Q2_ENFORCEMENT}}`와 동일값). 미강제면 harness:check이 MVH로 강등. 감사·업그레이드용 파생 기록 — 런타임 SSoT는 생성 스크립트 헤더 마커 |
| `harness.semanticApprovalAt` | Phase 4 "아키텍처 정확성 확인" 게이트에서 사용자가 생성된 규칙의 의미 정확성을 승인한 시각 (ISO 8601). 미확인이면 `null`. 구조 검증이 보장 못 하는 의미 정확성의 사람 확인 기록 |
| `profile` | 입력 프로필 중 **재치환에 필요한 부분집합** (아래 생성 규칙 1의 필드 목록). 업그레이드 시 재스캔 없이 managed 파일 재생성·custom 외과 수정에 사용 |
| `files.{path}.category` | `managed` / `custom` / `data` (§ 10.1 참조) |
| `files.{path}.templateHash` | 생성 시점 파일 내용의 SHA-256 해시. 사용자 수정 여부 판별 |
| `files.{path}.generatedAt` | 해당 파일의 마지막 생성/갱신 시각 |

#### 생성 규칙

1. **profile 저장**: `.harness-profile.json`의 프로필 데이터 중 다음 필드를 `profile`에 저장한다 — 모든 플레이스홀더 재치환과 업그레이드 외과 수정의 원천이다: `architectureType`, `srcRoot`, `pathAlias`, `layers`, `naming`, `devServer`, `scripts`, `tdd`, `git`, `autoCommit`, `docFreshnessDays`, `eslintAssist`(있는 경우만), `sharedDirs`(있는 경우만), `e2e`(있는 경우만), `integrations`(있는 경우만).
2. **해시 계산**: 각 생성 파일의 내용을 SHA-256으로 해싱하여 `files.{path}.templateHash`에 기록한다.
   ```bash
   node -e "const c=require('crypto'),f=require('fs'); console.log('sha256:'+c.createHash('sha256').update(f.readFileSync(process.argv[1],'utf8')).digest('hex'))" {file}
   ```
3. **카테고리 할당**: § 10.1 파일 카테고리 테이블에 따라 각 파일의 `category`를 설정한다.
4. **files 항목**: 생성한 모든 파일(디렉토리 제외)을 `files`에 기록한다. 키는 프로젝트 루트 기준 상대 경로이다.
5. **version**: 프로필의 `version` 필드를 `harness.version`과 `harness.skillVersion`에 설정한다.
6. **preset**: 프로필의 `preset` 필드를 설정한다.
7. **structuralTestEnforcement**: § 5.4에서 산정한 `{{Q2_ENFORCEMENT}}` 값(`enforced`/`unenforced`)을 `harness.structuralTestEnforcement`에 기록한다.
8. **semanticApprovalAt**: 생성 시 `null`로 초기화한다. Phase 4 "아키텍처 정확성 확인" 게이트(§ 7)에서 사용자가 승인하면 그 시각(ISO 8601)으로 갱신한다.

#### 후처리

`.harness-manifest.json` 생성이 완료되면, `.harness-profile.json`은 더 이상 필요하지 않다. Phase 4 보고에서 사용자에게 안내한다: "프로필은 `.harness-manifest.json`에 보존되었습니다. `.harness-profile.json`은 삭제해도 됩니다."

### 5.14 scripts/harness-check.sh 생성 규칙

- 이 스킬의 `templates/harness-check.sh` 템플릿을 기반으로 생성하고, 플레이스홀더를 프로필 값으로 치환한다
- 실행 권한을 부여한다: `chmod +x scripts/harness-check.sh`
- 하네스 자가진단 스크립트이다 — `references/harness-checklist.md` § 8 (빠른 자가진단)의 구현이며, 사용자가 `npm run harness:check`로 반복 실행할 수 있다
- 템플릿 치환 대상:

| 플레이스홀더 | 소스 | 기본값 |
|-------------|------|--------|
| `{{LINT_ARCH_COMMAND}}` | 고정 규칙 (§ 5.5에서 추가한 스크립트 호출) | `npm run lint:arch` |
| `{{VALIDATE_COMMAND}}` | 프로필 scripts.validate | `npm run validate` |
| `{{DOC_CHECK_COMMAND}}` | 고정 규칙 (§ 5.5에서 추가한 스크립트 호출) | `npm run doc:check` |
| `{{PATH_ALIAS_LIST}}` | 프로필 pathAlias — 문자열이면 단일(`"@/"`), 배열이면 공백 구분(`"@/" "~/"`)으로 렌더 (bash for-in용) | `"@/"` |

- 검사 8항목과 exit 규칙:
  - ① 필수 파일 존재, ② AGENTS.md 100줄 이내, ③ feature_list.json 유효 JSON — **하네스 구조** 항목. 실패 시 exit 1
  - ④ lint:arch 실행, ⑤ validate 실행 — **프로젝트 품질** 항목. 실패 시 exit 1 (exit code 전파)
  - ⑥ doc:check 실행, ⑦ tsconfig paths에 pathAlias 존재, ⑧ E2E 스캐폴드 구조(playwright.config.ts 존재 시) — **경고 전용**. exit code에 영향 없음
- 전체 통과 시 "✅ 표준 하네스 가동"을 출력한다 (harness-checklist.md § 7의 단계 판정)
- **skipFiles 주의**: 사용자가 skipFiles로 생성을 건너뛴 필수 파일은 ① 검사에서 실패로 잡힌다. Phase 3 (6.13)과 Phase 4 보고에서 해당 실패가 skipFiles에 의한 의도적 부재임을 구분하여 안내한다

### 5.15 ESLint 보조 규칙 추가 (옵트인)

프로필에 `eslintAssist` 필드가 있고 `enabled: true`일 때만 실행한다. 필드가 없으면 이 단계 전체를 건너뛴다.

> **원칙 예외**: "기존 설정 파일을 덮어쓰지 않는다" 원칙의 명시적 예외이다. 사용자가 Phase 1 문답에서 **옵트인한 경우에 한해**, package.json scripts 추가와 동급의 외과적 수정만 수행한다. tsconfig는 어떤 경우에도 수정하지 않는다 — pathAlias 존재 여부는 harness-check.sh ⑦이 검사만 한다.

#### 추가하는 규칙

- `no-restricted-imports` — 프로필 `layers.rules`에서 각 레이어가 import할 수 **없는** 레이어의 pathAlias 패턴을 생성하여 레이어 위반을 이중 차단한다 (`eslintAssist.layerRules: true`일 때). structural-test가 주 검사이고 이것은 에디터 실시간 피드백용 보조 검사다
- `max-lines` — 파일당 줄수 제한. `eslintAssist.maxLines` 값(기본 300), `false`면 미추가

#### 수정 방법 (형식별)

**flat config** (`eslint.config.{js,mjs,cjs}`, `configFormat: "flat"`): export되는 config 배열의 끝에 마커 주석으로 감싼 항목을 추가한다.

```js
// harness-setup:eslint-assist:start — harness upgrade가 이 블록을 관리한다. 직접 수정 시 업그레이드에서 보존되지 않을 수 있다
{
  files: ['{srcRoot}{layer}/**'],
  rules: {
    'no-restricted-imports': ['error', { patterns: [{ group: [/* 비허용 레이어의 alias 패턴 */], message: '레이어 의존성 위반 — ARCHITECTURE.md 참조' }] }],
  },
},
{
  files: ['{srcRoot}**'],
  rules: {
    'max-lines': ['warn', { max: {maxLines}, skipBlankLines: true, skipComments: true }],
  },
},
// harness-setup:eslint-assist:end
```

- 레이어별로 `files` + `no-restricted-imports` 항목을 하나씩 생성한다 (레이어 수만큼). `max-lines`는 srcRoot 전체 대상 항목 1개

**legacy** (`.eslintrc.json` / `.eslintrc`, `configFormat: "legacy"`): `overrides` 배열에 동일 구조를 추가한다 (배열이 없으면 생성). 마커는 `_harness_setup_eslint_assist` 키로 표시한다. `.eslintrc.js` 등 JS 형식 legacy 설정은 폴백 처리한다.

#### 멱등성과 폴백

- **멱등**: 마커(`harness-setup:eslint-assist:start` 또는 `_harness_setup_eslint_assist`)가 이미 존재하면 수정하지 않고 스킵한다
- **비실행 원칙**: 삽입 지점을 찾기 위해 설정 파일을 **직접 실행/평가하지 않는다** (import, require, eval 금지) — 텍스트 파싱만 한다. 설정 JS는 임의 코드이므로 스킬 프로세스에서의 평가는 공급망 공격 표면이 된다. 텍스트만으로 구조를 확신할 수 없으면 폴백한다. (수정 후 검증에서 프로젝트 자체의 eslint 실행은 validate 실행과 동급으로 허용 — 아래 항목)
- **폴백**: 설정 파일 구조가 비표준(파싱 불가, 복잡한 래퍼/spread, 동적 생성 등)이어서 안전한 삽입 지점을 확신할 수 없으면 **수정하지 않고**, Phase 4 보고에 권고 스니펫(위 마커 블록)을 출력한다. 폴백은 정상 경로이다 — 에러가 아니다
- 수정 후 ESLint 설정이 로드 가능한지 확인한다 (예: `npx eslint --print-config {srcRoot 임의 파일}` 또는 간단한 lint 실행). 깨졌으면 즉시 수정 전 내용으로 되돌리고 폴백으로 전환한다

### 5.16 외부 통합 연계 렌더링 (옵트인)

프로필 `integrations`에 `enabled: true`인 통합이 하나라도 있을 때 실행한다. `integrations`가 없으면 연계 산출물을 일절 생성하지 않는다 (AGENTS.md 섹션 없음, `{{INTEGRATION_NOTES}}`는 빈 문자열).

통합 메커니즘 규약: `references/integrations/_protocol.md`. 각 통합의 연계 내용 정본: `references/integrations/<name>-mapping.md` — 이 파일들을 읽어 렌더링한다.

#### 렌더링 절차 (enabled인 각 통합에 대해)

1. **실존 검증**:
   - superpowers류(다중 스킬): `linkedSkills`의 각 스킬에 대해 `{installPath}/skills/{스킬명}/` 디렉토리 존재 확인 → 없는 스킬 **드롭** + Phase 4 경고. installPath 자체가 없으면(제거됨) 해당 통합 전체 스킵 + 안내
   - multiModelConsult류(단일·CLI): `installPath` 심링크 + 자문 CLI(codex/gemini) 1개 이상 존재 확인 → 없으면 통합 스킵 + 안내
2. **제외 필터**: 매핑 정본의 "연계"/"선택" 목록에 없는 항목은 렌더링하지 않는다 (코어 충돌 스킬 차단 — TDD·코드 리뷰 등). 단일 연계 통합은 제외 목록이 비어 있다
3. **AGENTS.md 렌더링**: 모든 생존 통합의 연계 문구를 **단일 "## 보조 스킬" 섹션에 합산**한다 (§ 5.1 위치 — 문서 맵 앞). 항목 끝에 출처를 괄호로 표기:

```markdown
## 보조 스킬

{각 통합 매핑 정본의 연계 문구 — 1줄씩, 끝에 (출처) 표기}

> 외부 보조 스킬 연계 — 미설치 환경에서는 무시된다.
> TDD·코드 리뷰·검증은 본 하네스 자체 워크플로를 사용한다.
```

4. **session-routine 렌더링**: 매핑 정본에 session-routine 연계 문구가 있는 생존 통합들의 문구를 **합쳐** `{{INTEGRATION_NOTES}}`로 치환한다 (superpowers의 writing-plans, multiModelConsult 등 — 둘 다면 2줄). 해당 통합이 없으면 빈 문자열 (§ 5.11.3)

**렌더링 순서** (결정적 출력): 통합은 `superpowers` → `multiModelConsult` 순으로 렌더링한다. superpowers의 linkedSkills 내부 순서는 매핑 정본 순서(brainstorming → systematic-debugging → writing-plans)를 따른다. AGENTS.md와 `{{INTEGRATION_NOTES}}` 모두 이 순서로 — § 12.6 재렌더링 재현성을 위해 순서가 고정되어야 한다

#### 원칙

- 외부 스킬/도구 본문을 복제하지 않는다 — 이름과 호출 시점 안내만
- `detectedVersion`은 정보용 표기일 뿐, 버전 비교/차단을 하지 않는다 (드리프트는 실존 검증이 잡는다)
- 옵트아웃(해당 통합 필드 생략) 시 그 통합명이 어떤 산출물에도 나타나지 않는다. `integrations` 전체가 없으면 "## 보조 스킬" 섹션 자체가 없다

### 5.17 E2E 스캐폴드 모듈 (옵트인)

프로필에 `e2e` 필드가 있고 `enabled: true`일 때만 실행한다. 필드가 없으면 이 단계 전체를 건너뛴다 (산출물 0건).

> **원칙 준수**: 비침습 — 기존 `vitest.config`·`tsconfig`를 수정하지 않는다. 새 파일만 생성하고, package.json은 § 5.5의 add-only 머지만 수행한다.

#### 생성 파일

| 파일 | 카테고리 | 템플릿 | 치환 |
|------|---------|--------|------|
| `playwright.config.ts` | managed | `templates/playwright.config.ts` | `{{DEV_SERVER_COMMAND}}` ← devServer.command, `{{DEV_SERVER_PORT}}` ← devServer.port |
| `e2e/tsconfig.json` | managed | `templates/e2e/tsconfig.json` | 없음 |
| `e2e/README.md` | managed | `templates/e2e/README.md` | 없음 |
| `e2e/fixtures/test.ts` | custom | `templates/e2e/fixtures/test.ts` | 없음 |
| `e2e/fixtures/seed.ts` | custom | `templates/e2e/fixtures/seed.ts` | 없음 |
| `e2e/specs/smoke.e2e.ts` | custom | `templates/e2e/specs/smoke.e2e.ts` | 없음 |

#### 규칙

- `playwright.config.ts`의 `testMatch`는 `**/*.e2e.ts`이고, Vitest 기본 글롭(`**/*.{test,spec}.ts`)은 `.e2e.ts`를 수집하지 않는다 — 따라서 vitest.config 수정이 불필요하다 (이슈 #12의 load-bearing 결정).
- `e2e/tsconfig.json`은 root tsconfig를 `extends`하고 e2e 디렉토리만 컴파일한다. **root tsconfig는 수정하지 않는다.** root의 include가 e2e를 포함하면 harness-check ⑧이 경고한다 (§ 5.14).
- custom 파일(fixtures/seed/smoke)은 이미 존재하면 덮어쓰지 않는다 (사용자 소유). managed 파일(config/tsconfig/README)은 § 12.6 자동 감지로 템플릿 변경을 전파한다.
- `e2e/README.md`는 **사람 개발자용** 정적 작성 가이드다(managed, 플레이스홀더 0 — 순수 정적 템플릿이라 재렌더 결정론 자명). 에이전트/TDD 규칙 내용을 복제하지 않고 정본(coding-standards.md·session-routine.md·test-engineer.md·debugger.md)을 **참조**한다. 조건부 절(MCP·pre-push)은 프로필 게이트 렌더가 아니라 정적 "if wired" 산문이다(§ 12.6 결정론 보존).
- E2E 그린은 앱별 부팅(env/route-block)에 의존하므로 **스위트를 실행하지 않는다** — 구조(파일·스크립트 존재)만 보장한다 (의미 비보장, harness-checklist § 7 일관).

---

### 5.18 pre-push 게이트 (옵트인 — e2e.prePush)

프로필에 `e2e.prePush: true`일 때만 실행한다. 없으면 이 단계 전체를 건너뛴다 (산출물 0건). `e2e.enabled`가 전제다.

> **원칙 준수**: 스캐폴드는 **`git config`를 설정(write)하지 않는다** — `git config --get`으로 환경을 읽어 감지하는 것만 허용한다(읽기 전용·비실행). `.githooks/pre-push` 파일만 생성/주입하고, 활성화(`core.hooksPath` 설정)는 Phase 4 안내로 사용자가 직접 수행한다 ("승인 없이 git 실행 금지" 절대 규칙).

#### 생성 파일

| 파일 | 카테고리 | 템플릿 | 치환 |
|------|---------|--------|------|
| `.githooks/pre-push` | managed | `templates/githooks/pre-push` | `{{VALIDATE_COMMAND}}` ← 프로필 scripts.validate |

> 위 경로(`.githooks/pre-push`)는 **그린필드 분기의 타깃**이다. 기존 hooksPath/Husky 분기에서는 마커 블록을 기존 훅 경로(`{core.hooksPath}/pre-push` 또는 `.husky/pre-push`)에 주입하므로 타깃 경로가 달라진다 — manifest 등록·Phase 4 보고에는 실제 타깃 경로를 사용한다 (아래 공존성 분기 참조).

#### 공존성 분기 (기존 git hook 환경 감지 — 텍스트 파싱만, 비실행 원칙)

생성 전에 기존 환경을 감지한다 (`git config --get core.hooksPath` 읽기, `.husky/` 디렉토리·`.git/hooks/pre-push` 존재 여부 — 파일 실행/평가 금지). **아래 표를 위에서 아래로 순서대로 평가하며, 첫 번째로 일치하는 환경에서 멈춘다 (우선순위 고정).**

| # | 환경 (조건) | 동작 |
|---|------------|------|
| 1 | **기존 hooksPath/Husky**: `core.hooksPath` 설정됨 **또는** `.husky/` 디렉토리 존재 | 대상 훅의 `pre-push`에 **마커 블록(`harness-setup:e2e-prepush:start`~`end`)만 주입**(파일 끝 append; 파일 없으면 shebang+블록으로 생성). git config 변경 불필요 — 이미 활성. **타깃 결정**: `core.hooksPath` 값이 있으면 그 경로 우선, 없으면 `.husky/`. 타깃 디렉토리가 없으면 생성한다 |
| 2 | **기본 경로 사용자 훅**: hooksPath 미설정 **그리고** `.git/hooks/pre-push` 존재 | core.hooksPath로 전환하면 기본 훅이 무력화되므로 **자동 전환·생성하지 않는다** → 폴백 |
| 3 | **그린필드**: 위 1·2 어디에도 해당 없음 | `.githooks/pre-push`를 템플릿으로 신규 생성(`chmod +x`). Phase 4가 `git config core.hooksPath .githooks` 안내 |
| 폴백 | **비표준/파싱 불가/판단 불가**: 어느 분기든 안전한 주입 지점을 확신 못 함 | **수정하지 않고** Phase 4에 권고 스니펫(마커 블록 + 활성화 명령)을 출력한다. 비활성 보고. 에러 아님 |

#### 규칙

- **멱등**: 마커 `harness-setup:e2e-prepush:start`가 대상 파일에 이미 있으면 스킵.
- 주입 시 **shebang은 복제하지 않는다** — 마커 블록(start~end)만 기존 훅 뒤에 붙인다(호스트 훅의 shebang/로직 보존). 신규 생성 시에만 템플릿 전체(shebang 포함)를 쓴다.
- 훅 본문은 `set -e`가 아니라 명시적 `|| exit 1`을 쓴다 — 주입 시 호스트 훅 동작을 바꾸지 않기 위해 (템플릿이 이미 그렇게 작성됨).
- **주입 경로는 자동 감지 제외**: §12.6.1 매핑 키는 `.githooks/pre-push`(그린필드)이므로, 기존 hooksPath/Husky에 주입한 훅(타깃 경로가 다름)은 §12.6 자동 감지 대상이 아니다 — 템플릿 보안·정확성 업데이트가 주입 훅에는 자동 전파되지 않는다(호스트 훅 비침습 보장의 대가). 그린필드 `.githooks/pre-push`만 자동 전파된다.

### 5.19 MCP 진단 배선 (옵트인)

프로필에 `e2e.mcp.enabled: true`일 때만 실행한다. 신규 파일을 생성하지 않는다 — debugger.md(managed)의 `{{MCP_DEBUG_PROTOCOL}}`를 아래 블록으로 치환하고, `version`을 인라인한다. `e2e.mcp`가 없으면 빈 문자열로 치환한다(`e2e.enabled`와 무관).

치환 블록(`@playwright/mcp@{버전}`은 `e2e.mcp.version` 인라인):

````markdown
### 0.5 브라우저 MCP 탐색 진단 (스펙 없는 UI 증상, 해당 시)

재현 스펙이 아직 없는 UI 증상(사용자 버그 리포트 등)은 **라이브 브라우저로 탐색·진단**한다. 이미 실패하는 `.e2e.ts`가 있으면 § 0(러너 재현)이 정본이며 이 절을 쓰지 않는다.

**로컬 등록 (개발자 1회)** — MCP 도구는 세션 시작 시 등록돼야 사용 가능하다. 공유 `.mcp.json`을 만들지 않으므로, 진단이 필요한 개발자가 자기 로컬에 1회 등록한다:

```sh
claude mcp add playwright-harness -- npx -y @playwright/mcp@0.0.76 --headless --isolated
```

등록 후 세션을 재시작하면 `playwright-harness` MCP 도구가 활성화된다. 기본 `local` 스코프라 커밋되지 않는다(팀 공유 `--scope project`는 권장하지 않음 — 개인 진단 도구).

**MCP vs 러너 (정본 구분)**
- **known `.e2e.ts` 실패** → § 0 적용. 러너/아티팩트(trace·report·screenshot)가 **정본**. MCP 탐색을 시작하지 않는다.
- **스펙 없는 UI 증상** → MCP 허용. 목적은 **관찰 + 최소 재현 수집**.
- 모호하면 러너/스펙 우선, MCP는 마지막 수단.

**보안 기본값** — `--headless --isolated`(영속 프로필 금지 → 쿠키/세션 노출 차단). **localhost/devServer origin만** 기본, 외부 URL은 사용자 명시 승인. exact 핀만(`@latest` 금지). (참고: `--allowed-origins`는 도구 자체 설명상 보안 경계가 아니므로 localhost 제한은 지침으로 강제한다.)

**사용 후 의무** — MCP로 찾은 재현을 `.e2e.ts`로 코드화(E2E 모듈 옵트인 시) 또는 명시적 재현 단계로 기록한다. **최종 완료 판단은 항상 § 3의 검증 명령(validate/E2E) 통과** — MCP 관찰만으로 "수정 완료" 단정 금지.

**관찰 로그 필수** — URL · 시작 상태 · 클릭/입력 순서 · actual vs expected · console/network 근거. 본 것만 기록, 추정은 추정 표시(§ 0 플레이키니스 환각 금지 연장).
````

> Task 1에서 확인: `--headless`·`--isolated`는 `@playwright/mcp@0.0.76`에 실재한다. 버전이 바뀌면 등록 명령의 핀과 플래그를 그 버전 `--help`로 재검증한다.

---

## 6. Phase 3: 검증

생성이 완료되면 자동으로 검증한다. 검증 항목은 `references/harness-checklist.md`(하네스 구성 체크리스트)의 판정 기준에 대응한다.

### 검증 체크리스트

```bash
# 6.0 필요한 디렉토리 생성 보장
mkdir -p scripts/ docs/ agents/ .claude/rules/

# 6.1 생성된 파일 존재 확인
ls -la CLAUDE.md AGENTS.md ARCHITECTURE.md claude-progress.txt feature_list.json init.sh

# 6.2 docs/ 구조 확인 (HARNESS_FRICTION.md 포함) + 마찰 싱크 확인
ls -la docs/ docs/HARNESS_FRICTION.md .harness-friction.jsonl

# 6.3 scripts/ 확인
ls -la scripts/structural-test.ts scripts/doc-freshness.ts scripts/harness-check.sh

# 6.4 agents/ 확인
ls -la agents/architect.md agents/test-engineer.md agents/implementer.md agents/reviewer.md agents/simplifier.md agents/debugger.md agents/security-reviewer.md

# 6.5 .claude/rules/ 확인
ls -la .claude/rules/session-routine.md .claude/rules/coding-standards.md .claude/rules/git-workflow.md

# 6.6 AGENTS.md 내부 참조 경로 검증
# AGENTS.md에 명시된 모든 파일 경로가 실제로 존재하는지 확인

# 6.7 ARCHITECTURE.md의 폴더 목록이 실제 디렉토리와 일치하는지 확인

# 6.8 package.json scripts 확인
node -e "const pkg=require('./package.json'); for (const k of ['lint:arch','validate','doc:check','harness:check']) console.log(pkg.scripts[k] ? '✅ '+k : '❌ '+k+' 누락');"

# 6.9 structural-test.ts 실행 가능 여부 (dry run)
npx tsx scripts/structural-test.ts 2>&1 || echo "⚠️ structural-test 실행 실패 — 수동 확인 필요"

# 6.9b structural-test Q2 강제 마커가 치환되었는지 확인 (enforced/unenforced 중 하나여야 함 — 미치환 {{Q2_ENFORCEMENT}} 잔존 방지)
grep -Eq 'HARNESS:Q2_ENFORCEMENT=(enforced|unenforced)' scripts/structural-test.ts 2>/dev/null && echo "✅ Q2 강제 마커 정상" || echo "❌ Q2 강제 마커 누락/미치환 — // HARNESS:Q2_ENFORCEMENT을 enforced 또는 unenforced로 치환하세요"

# 6.10 feature_list.json이 valid JSON인지 확인
node -e "JSON.parse(require('fs').readFileSync('feature_list.json','utf8')); console.log('✅ feature_list.json valid');" 2>&1 || echo "❌ feature_list.json invalid"

# 6.11 템플릿 기반 파일에 미치환 플레이스홀더가 없는지 확인
grep -r '{{.*}}' agents/ .claude/rules/ init.sh scripts/doc-freshness.ts scripts/harness-check.sh docs/TECH_DEBT.md .githooks/pre-push 2>/dev/null && echo "❌ 미치환 플레이스홀더 발견" || echo "✅ 플레이스홀더 모두 치환됨"

# 6.12 .harness-manifest.json 검증
node -e "
const m=JSON.parse(require('fs').readFileSync('.harness-manifest.json','utf8'));
console.log(m.harness?.version ? '✅ harness.version: '+m.harness.version : '❌ harness.version 누락');
console.log(m.profile?.architectureType ? '✅ profile 존재' : '❌ profile 누락');
const files=Object.keys(m.files||{});
const missing=files.filter(f=>!require('fs').existsSync(f));
console.log(missing.length===0 ? '✅ files 항목 정합 ('+files.length+'개)' : '❌ 누락 파일: '+missing.join(', '));
" 2>&1 || echo "❌ .harness-manifest.json 검증 실패"

# 6.13 harness-check 실행 (자가진단 — references/harness-checklist.md § 8)
[ -x scripts/harness-check.sh ] || chmod +x scripts/harness-check.sh
npm run harness:check 2>&1 || echo "⚠️ harness:check 실패 — 하네스 구조 항목(①②③)과 프로젝트 품질 항목(④⑤)을 구분하여 보고"

# 6.14 ESLint 보조 규칙 검증 (eslintAssist 옵트인 시에만 실행)
grep -q "harness-setup:eslint-assist" {eslintAssist.configFile} 2>/dev/null && echo "✅ ESLint 보조 규칙 마커 존재" || echo "⚠️ ESLint 보조 규칙 미적용 (폴백) — Phase 4 보고에 권고 스니펫 포함"

# 6.15 외부 통합 연계 검증 (integrations 옵트인 시에만 실행)
# (a) 보조 스킬 섹션 존재
grep -q "^## 보조 스킬" AGENTS.md && echo "✅ 보조 스킬 섹션 존재" || echo "❌ 보조 스킬 섹션 누락"
# (b) 옵트인한 각 통합의 연계 항목이 실제 렌더링됐는지 (통합별로)
#     - superpowers 옵트인 → linkedSkills 생존 항목이 AGENTS.md에 존재
#     - multiModelConsult 옵트인 → "multi-model-consult" 연계 항목이 AGENTS.md에 존재
#     - writing-plans/consult가 session-routine 연계 대상이면 .claude/rules/session-routine.md에 {{INTEGRATION_NOTES}} 치환 결과 존재
# (c) 옵트아웃/미감지 통합은 반대로 — 해당 통합명이 AGENTS.md·.claude/rules/ 어디에도 없어야 한다
#     (예: superpowers만 옵트인 → "multi-model-consult" 문자열 0건, 그 역도 동일)
# 항목 수는 통합/스킬 수에 비례하므로 고정 카운트로 검증하지 않는다 (통합 추가 시 깨지지 않도록)

# 6.16 E2E 스캐폴드 검증 (e2e 옵트인 시에만 실행)
if [ -f playwright.config.ts ]; then
  ls -la playwright.config.ts e2e/tsconfig.json e2e/specs/smoke.e2e.ts 2>&1
  node -e "const p=require('./package.json'); console.log(p.scripts['test:e2e'] ? '✅ test:e2e script' : '❌ test:e2e 누락'); console.log(p.devDependencies && p.devDependencies['@playwright/test'] ? '✅ @playwright/test devDep' : '⚠️ @playwright/test devDep 미기록');"
  grep -q '{{' playwright.config.ts && echo "❌ playwright.config.ts 미치환 플레이스홀더" || echo "✅ playwright.config.ts 치환 완료"
fi

# 6.17 pre-push 게이트 검증 (e2e.prePush 옵트인 시에만 — 그린필드/주입 타깃 모두)
PREPUSH_TARGET=""
for cand in .githooks/pre-push .husky/pre-push "$(git config --get core.hooksPath 2>/dev/null)/pre-push"; do
  if [ -f "$cand" ] && grep -q "harness-setup:e2e-prepush" "$cand" 2>/dev/null; then PREPUSH_TARGET="$cand"; break; fi
done
if [ -n "$PREPUSH_TARGET" ]; then
  echo "✅ pre-push 마커 존재 ($PREPUSH_TARGET)"
  grep -q '{{' "$PREPUSH_TARGET" && echo "❌ pre-push 미치환 플레이스홀더" || echo "✅ pre-push 플레이스홀더 치환됨"
elif [ -f .githooks/pre-push ]; then
  echo "❌ pre-push 마커 누락"
fi
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
| harness:check 구조 항목 실패 (6.13 ①②③) | 해당 파일 재생성/수정 후 1회 재실행 |
| 보조 스킬 섹션 누락 (6.15, 옵트인 시) | § 5.16 렌더링 재실행 |

### 자동 수정 불가 항목 (사용자 보고)

| 검증 항목 | 사용자에게 보고할 내용 |
|-----------|---------------------|
| ARCHITECTURE.md 폴더 불일치 (6.7) | 어떤 폴더가 불일치하는지 목록 제시 |
| structural-test.ts 실행 실패 (6.9) | 에러 메시지와 함께 수동 수정 제안 |
| harness:check 품질 항목 실패 (6.13 ④⑤) | 하네스 문제가 아니라 프로젝트 품질 문제(기존 테스트/린트 실패)로 구분하여 에러 내용 보고 |
| ESLint 보조 규칙 미적용 (6.14) | 폴백 발생 — 권고 스니펫과 함께 수동 적용 안내 (정상 경로, 에러 아님) |

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
| scripts/harness-check.sh | ✅ | 하네스 자가진단 (npm run harness:check) |
| docs/HARNESS_FRICTION.md | ✅ | 마찰 이벤트 정적 참조 문서 |
| .harness-friction.jsonl | ✅ | 마찰 로그 싱크 (빈 파일 — 자동 기록 대상) |
| package.json | ✅ 수정 | lint:arch, validate, doc:check, harness:check 추가 |
| {ESLint 설정 파일} | ✅ 수정 또는 ⚠️ 폴백 | eslintAssist 옵트인 시에만 표시 — 적용 시 "보조 규칙 추가 (마커 블록)", 폴백 시 "수동 적용 필요 — 아래 권고 스니펫" |
| .harness-manifest.json | ✅ | 버전 추적 매니페스트 (v{version}) |

### 검증 결과
- ✅ 파일 경로 일관성: 통과
- ✅ JSON 유효성: 통과
- ✅ structural-test: 통과 (위반 {N}건)
- ✅ Q2 강제: structural-test 규칙 활성 (또는 ⚠️ 미강제 — MVH 강등)
- ✅ package.json scripts: 정상
- ✅ agents/ 파일 (7개): 정상
- ✅ .claude/rules/ 파일 (3개): 정상
- ✅ 플레이스홀더 치환: 완료
- ✅ .harness-manifest.json: 정상
- ✅ harness:check: 통과 (8항목 — ⑧ E2E 스캐폴드는 playwright.config.ts 존재 시에만 검사)
- ✅ 보조 스킬 연계: {N}종 렌더링 (드롭 {M}종 — 실존 검증 실패 시 스킬명과 함께 표시. integrations 옵트인 시에만 이 행 표시)

### 하네스 단계 판정

harness:check(6.13) 결과로 단계를 판정한다 (기준: `references/harness-checklist.md` § 7):

- 전체 통과 → "**표준 하네스 가동** — 하네스 골격이 설치되고 검증 명령이 정상 동작합니다"
  - ⚠️ 이 판정은 *구조 설치 + 기계적 실행 가능성*만 의미한다. 생성된 문서·아키텍처 규칙의 **의미 정확성**(분류가 맞는지, 의존성 규칙이 옳은지, feature_list 상태가 진짜인지)은 판정 대상이 아니므로, 아래 '다음 단계'의 검토 항목(②·⑤)을 반드시 함께 안내한다 (기준: `references/harness-checklist.md` § 7 "판정의 범위 — 구조 vs 의미")
- 전체 통과(구조+품질) + Q2 미강제(structural-test 마커 `unenforced`) → "**MVH 가동 (Q2 미강제)** — 구조·실행은 통과하나 structural-test에 기계 검사 규칙이 없어 아키텍처 제약이 강제되지 않습니다 (체크리스트 §3.2 미충족 → 표준 아님). ARCHITECTURE.md 수동 준수 또는 규칙 추가 권장". harness:check은 exit 0 (자유 구조의 정당한 약한 상태)
- 구조 항목(①②③)만 통과, 품질 항목(④⑤) 실패 → "**MVH(최소 하네스) 가동** — 실패 항목: {목록}. 기존 코드의 검증 실패가 원인이며, validate가 통과해야 표준 하네스입니다"
- 구조 항목 실패 → 판정 보류, 실패 항목과 수정 방법 보고

### 다음 단계
1. `npm run validate`를 실행하여 전체 검증이 동작하는지 확인하세요
2. AGENTS.md를 읽고 프로젝트 설명이 정확한지 확인하세요
3. `.harness-manifest.json`을 커밋하세요 — 향후 `harness upgrade`로 자동 업그레이드할 수 있습니다
   - 팀 환경에서는 커밋하면 팀 전체에 반영됩니다
4. `.harness-profile.json`은 삭제해도 됩니다 — 프로필은 `.harness-manifest.json`에 보존되었습니다
5. feature_list.json에 구현할 기능을 추가하세요
6. 첫 번째 기능을 선택하고 TDD 사이클을 시작하세요
7. 정기 운영은 CLAUDE.md의 "운영 사이클" 섹션을 따르세요 (일간 validate / 주간 품질 / 격주 부채 / 월간 전면 검토 + `npm run harness:check`)

### TDD 워크플로 안내
기능 구현은 TDD subagent 파이프라인을 따릅니다:

**사이클**: Architect → Test Engineer (Red) → Implementer (Green) → Reviewer → Simplifier (Refactor)
**상세 플로우**: `.claude/rules/session-routine.md` 참조
**에이전트 정의**: `agents/` 디렉토리

**세션 시작**: claude-progress.txt → git status → git log → feature_list.json → validate (회귀 체크) → TDD 사이클
**세션 종료**: validate → feature_list.json 업데이트 → progress 기록 → git-workflow.md 규칙에 따라 커밋 제안

### 이제 할 수 있는 일
- TDD 사이클 → feature_list.json 첫 기능 선택 (또는 `/plan`이 Architect 대체) (상세: 위 '다음 단계' 5·6 · .claude/rules/session-routine.md)
- 검증 게이트 → `npm run validate` · `lint:arch` · `doc:check` (상세: AGENTS.md "## 명령어")
- 자가진단 → `npm run harness:check` (상세: references/harness-checklist.md §8)
- 품질·부채 추적 → docs/QUALITY_SCORE.md · docs/TECH_DEBT.md 갱신 (상세: docs/TECH_DEBT.md 승격 대기 큐)
- 하네스 정리 → "하네스 정리" / "월간 점검" (상세: CLAUDE.md 운영 사이클 — 컴패니언, 글로벌 설치 전제)
- 피드백 분석 → "하네스 피드백 분석해줘" (상세: CLAUDE.md 하네스 이슈 보고 — 컴패니언, 글로벌 설치 전제)
- 마찰 자동 기록 → TDD 마찰 이벤트(implementer-retry 등)가 발생 시 `.harness-friction.jsonl`에 자동 기록 (상세: .claude/rules/session-routine.md § 마찰 로그) — always-on
- 멀티모델 자문 → `/consult` (상세: references/integrations/multi-model-consult-mapping.md) — multiModelConsult 옵트인 + 실존 검증 통과 시에만 표시
- 보조 스킬(brainstorming 등) → 자연어 호출 (상세: AGENTS.md "## 보조 스킬") — 생존 linkedSkills 1개 이상일 때만 표시
- 브라우저 E2E 회귀 작성 → `npm run test:e2e` (상세: e2e/README.md · playwright.config.ts) — e2e 옵트인 시에만 표시
- 브라우저 MCP 진단 → debugger가 스펙 없는 UI 증상을 라이브 브라우저로 탐색 (상세: agents/debugger.md § 0.5) — e2e.mcp 옵트인 시에만 표시
- pre-push 게이트 → 활성화 후 `git push` 시 `@critical` 자동 검증 (활성화 방법: 아래 'pre-push 게이트 활성화 안내'; 상세: .githooks/pre-push · references/harness-checklist.md §4.2) — e2e.prePush 옵트인 + 훅 생성 시에만 표시
> 위 줄은 정본을 가리킬 뿐 능력을 재정의하지 않는다 — 상세는 .claude/rules/session-routine.md · AGENTS.md · CLAUDE.md 참조.
```

#### pre-push 게이트 활성화 안내 (e2e.prePush 옵트인 시에만)

`e2e.prePush` 옵트인 시 보고 말미에 다음을 **반드시** 출력한다 (생성·주입·폴백 분기 모두 해당 — 스킬은 git 설정을 변경하지 않았다). 해당 분기에 맞는 항목만 출력한다:

1. **활성화** (그린필드 생성 시): `git config core.hooksPath .githooks` — 기존 hooksPath/Husky에 주입한 경우 이미 활성이므로 이 명령을 안내하지 않고 "기존 훅에 주입됨(이미 활성)"으로 보고한다. 폴백한 경우 권고 스니펫과 수동 안내를 출력한다.
2. **보안 고지**: "이 훅은 `git push` 시 `validate` → `@critical` E2E를 실행합니다 (임의 코드 실행). 신뢰할 수 있는 저장소에서만 활성화하세요."
3. **monorepo 한계**: repo-root 기준으로 동작하므로 하위 패키지에 설치된 playwright는 미탐지될 수 있다 (명시적 한계).
4. **비활성화**: `git config --unset core.hooksPath`.

#### 브라우저 MCP 진단 안내 (e2e.mcp 옵트인 시에만)

`e2e.mcp` 옵트인 시 보고 말미에 다음을 출력한다 (스킬은 `.mcp.json`을 만들지 않으므로 개발자가 로컬 1회 등록해야 한다):

- (e2e.mcp 옵트인 시) 브라우저 MCP 진단: 로컬 1회 등록 `claude mcp add playwright-harness -- npx -y @playwright/mcp@{version} --headless --isolated` (기본 local 스코프=커밋 안 됨). ⚠️ MCP 서버는 세션에서 코드를 실행한다 — 신뢰할 수 있는 환경에서만. 상세: agents/debugger.md § 0.5

#### "이제 할 수 있는 일" 카탈로그 렌더링 규칙

이 카탈로그는 **첫 셋업 보고 전용이며**(업그레이드 U5는 § 10.2 참조), 새 사실을 만들지 않는 **순수 투영(projection)**이다 — 산출물 생성을 결정한 바로 그 프로필 신호를 그대로 재사용해 각 줄을 조건부 렌더링한다. 새 게이트 로직·플레이스홀더를 도입하지 않는다:

- **멀티모델 자문 줄**: `integrations.multiModelConsult.enabled === true`이고 § 5.16 실존 검증(글로벌 심링크 + codex/gemini CLI ≥ 1)을 통과한 경우에만 렌더. 둘 중 하나라도 실패하면 줄 자체를 생략한다.
- **보조 스킬 줄**: § 5.16 실존 검증을 통과한 생존 `linkedSkills`가 1개 이상일 때만 렌더 (AGENTS.md "## 보조 스킬" 섹션과 **동일 생존 집합**). 생존 스킬 0개면 생략한다.
- **TDD 사이클 줄**: 항상 렌더하되 파이프라인 단계를 열거하지 않고 session-routine.md를 가리킨다. Security Reviewer는 7개 에이전트의 하나로 **항상 생성**되지만 `tdd.securityCategories`에 매칭되는 feature가 있을 때만 호출되므로(session-routine Phase 4.5 SECURITY 호출 조건 — 빈 배열이면 매칭 feature가 없어 실호출되지 않음), 미호출 가능한 단계를 상시 능력으로 광고하지 않는다.
- **하네스 정리 · 피드백 분석 줄**: 컴패니언 스킬(install.sh로 `~/.claude/skills/`에 글로벌 설치)이므로 "글로벌 설치 전제"로 제시한다 — 글로벌 미설치 환경에서는 호출되지 않을 수 있다.
- **검증 게이트 · 자가진단 · 품질·부채 추적 · 마찰 자동 기록 줄**: 항상 생성되는 산출물이므로 무조건 렌더.
- **브라우저 E2E 줄**: `e2e.enabled === true`이고 § 5.17 산출물(`playwright.config.ts`)이 생성된 경우에만 렌더 — 산출물 생성을 결정한 바로 그 신호를 재사용하는 순수 투영. 미옵트인 시 줄 자체를 생략한다 (미와이어 능력 광고 불가).
- **브라우저 MCP 줄**: `e2e.mcp.enabled === true`일 때만 렌더 — debugger.md MCP 블록 치환을 결정한 바로 그 신호를 재사용하는 순수 투영. 미옵트인 시 줄 생략(미와이어 능력 광고 불가).
- **pre-push 게이트 줄**: `e2e.prePush === true`이고 § 5.18 산출물(`.githooks/pre-push`)이 생성/주입된 경우에만 렌더 — 산출물 생성 신호를 재사용하는 순수 투영. 미옵트인·폴백 시 줄 자체를 생략한다 (미와이어/미활성 능력 광고 불가).

언어는 보고 전체와 동일하게 § 8 "문서 품질"의 언어 규칙(한국어 기본, 사용자 요청 시 예외)을 따른다 — 한국어를 하드코딩하지 않는다. 각 줄은 정본(session-routine.md / 통합 매핑 / 컴패니언 SKILL.md)을 가리킬 뿐 능력 사실을 복제하지 않는다 — **새 손-관리 능력 목록이 아니다.**

### 아키텍처 정확성 확인 (의미 게이트)

보고를 출력한 뒤, **셋업을 종결하기 전에** 생성된 아키텍처 제약이 프로젝트 의도와 일치하는지 사용자에게 확인받는다. 구조 검증(Phase 3)과 harness:check은 "파일이 있고 스크립트가 돈다"만 보장하고 규칙의 *의미 정확성*은 보장하지 않으므로(§ 7 단계 판정 캐비엇), **이것이 유일한 의미 확인 지점이다** — Step 5 승인은 프로필(분류·계획) 대상이고, AGENTS.md/ARCHITECTURE.md 문서는 그 승인 이후 생성되기 때문이다.

생성된 핵심 제약을 재요약하여 제시한다:
- 아키텍처 유형 + 의존성 방향 한 줄 (`architectureType`, layers.order)
- 상위 폴더 역할 2~3개 (folderRoles)
- 핵심 추가 규칙(extraArchitectureRules)이 있으면 1~2개
- **Q2 강제 상태** (`enforced`/`unenforced` — 미강제면 "아키텍처 제약이 기계로 강제되지 않음"을 명시)

그리고 묻는다: **"이 규칙이 프로젝트의 아키텍처 의도와 일치합니까? (y / 수정 요청)"**

- **y** → `.harness-manifest.json`의 `harness.semanticApprovalAt`를 현재 시각(ISO 8601)으로 갱신하고 종료
- **수정 요청 / 불일치** → 무엇이 틀렸는지 듣고, ARCHITECTURE.md를 직접 수정하거나 `/harness-setup`을 재실행하여 분류를 교정하도록 안내한다. `docs/HARNESS_FRICTION.md`에 의미 불일치를 기록하도록 권유한다(마찰 루프 입력). `semanticApprovalAt`는 `null`로 둔다
- 사용자가 응답 없이 종료하면 `semanticApprovalAt`는 `null`(미확인)로 남는다 — **비차단** (게이트는 강제가 아니라 권유)

---

## 8. 절대 규칙

### 파일 보호
- 기존 소스 코드 (.ts, .tsx, .js, .jsx, .css 등)를 수정하지 않는다
- 기존 설정 파일을 덮어쓰지 않는다 — merge만 허용하며, 대상은 package.json scripts 필드와 **사용자가 옵트인한 ESLint 보조 규칙**(§ 5.15, 마커 블록 추가 방식)에 한정한다
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
| 22 | `docs/HARNESS_FRICTION.md` | managed | 정적 참조 문서(이벤트 유형/심각도 참조표). 템플릿 기반, 사용자 콘텐츠 없음 |
| 22-b | `.harness-friction.jsonl` | data | 마찰 이벤트 진실 원본(프로젝트 루트). 런타임 데이터 축적, 해시 드리프트 검사 제외 — feature_list.json과 동일 취급 |
| 23 | `package.json` (scripts) | custom | 스킬은 특정 키만 추가, 사용자가 수정했을 수 있음 |
| 24 | `scripts/harness-check.sh` | managed | 템플릿 기반 자가진단 스크립트 |
| 25 | ESLint 설정 파일 (`eslint.config.*` / `.eslintrc.*`) | custom | 옵트인 시 마커 블록만 추가. manifest files에 기록하지 않음 (package.json과 동급) |
| 26 | `playwright.config.ts` | managed | 템플릿 기반 E2E 설정 (e2e 옵트인 시에만) |
| 27 | `e2e/tsconfig.json` | managed | 템플릿 기반 e2e 컴파일 경계 (e2e 옵트인 시에만) |
| 28 | `e2e/README.md` | managed | E2E 작성 가이드 (사람 개발자용 정적 문서, e2e 옵트인 시에만) |
| 29 | `e2e/fixtures/test.ts` | custom | per-test fixture, 사용자가 시드 훅 추가 (e2e 옵트인 시에만) |
| 30 | `e2e/fixtures/seed.ts` | custom | 앱별 시드 로직, 사용자 소유 (e2e 옵트인 시에만) |
| 31 | `e2e/specs/smoke.e2e.ts` | custom | 스타터 스모크, 사용자가 회귀 스펙 축적 (e2e 옵트인 시에만) |
| 32 | `.githooks/pre-push` | managed | 옵트인(e2e.prePush) 시에만. 그린필드=`.githooks/pre-push`, 기존 hooksPath/Husky 주입 시 호스트 훅 경로 |

#### managed 파일의 사용자 수정 대응

managed 파일의 템플릿 변경은 SKILL.md § 12.6의 자동 감지 메커니즘으로 판별된다. Phase U1에서 소스 템플릿을 manifest.profile로 렌더링한 결과(`expectedHash`)와 manifest의 `templateHash`를 비교하여, 템플릿 변경 여부와 사용자 수정 여부를 동시에 판정한다.

프로필의 `fileActions`에 판정 결과가 기록되어 있으므로, scaffold는 이 필드를 따른다:

- `action: "overwrite"` → 최신 템플릿 + profile 값으로 재생성
- `action: "skip"` → 건드리지 않음
- `action: "user-choice"` → 사용자가 Phase U2에서 선택한 결과에 따라:
  1. **덮어쓰기** — 최신 템플릿으로 교체 (사용자 변경 소실)
  2. **스킵** — 현재 파일 유지. manifest에 `"userOverride": true` 표시
  3. **병합** — 구조적 변경만 적용하고 사용자 추가분 보존 (best-effort)

### 10.2 업그레이드 Phase U3~U5

프로필의 `fileActions` 필드에 따라 실행한다.

```
Phase U3: 실행
  1. manifest.harness.upgradeInProgress ← true
  2. 새 디렉토리 생성 (필요 시)
  3. fileActions에 따라 managed 파일 처리:
     - action: "overwrite" → 최신 템플릿 + manifest.profile 값으로 재생성
     - action: "skip" → 건드리지 않음
     - action: "user-choice" → 사용자가 Phase U2에서 선택한 결과에 따라 처리
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
| 작업 | 파일 수 | 소스 |
|------|---------|------|
| 덮어쓰기 (managed, 자동 감지) | {N}개 | 템플릿 변경 감지 |
| 덮어쓰기 (managed, 마이그레이션) | {N}개 | 마이그레이션 지시 |
| 부분 수정 (custom) | {N}개 | 마이그레이션 지시 |
| 신규 생성 | {N}개 | 마이그레이션 지시 |
| 스킵 (변경 없음) | {N}개 | — |
| 스킵 (data) | {N}개 | — |
| 사용자 스킵 (userOverride) | {N}개 | — |

### 주의 사항
- {마이그레이션별 특이사항}

### 다음 단계
1. 변경된 파일을 확인하세요
2. `npm run validate`를 실행하여 검증하세요
3. `.harness-manifest.json`을 커밋하세요
```

> **U5 보고는 § 7의 "이제 할 수 있는 일" 능력 카탈로그를 출력하지 않는다** — 카탈로그는 첫 셋업(매니페스트 부재) 전용이고, U5는 버전 델타 + 변경 요약 표만 표시한다. (업그레이드가 순수 신규 능력을 와이어한 경우의 "새로 사용 가능" 1줄 델타는 별도 후속 항목 — 이슈 #11 OUT-OF-SCOPE.)

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

> managed 파일의 템플릿 변경은 자동 감지(SKILL.md § 12.6)로 처리된다.
> 마이그레이션은 다음 경우에만 등록한다:
> - `[custom]` 외과적 수정, `[new]` 신규 파일, `[remove]` 파일 삭제
> - `[profile]` 프로필 필드 변경, `[data]` data 스키마 변경

#### M-1.0.0-to-1.1.0: 체크리스트 기반 보강 (명령어 SoT 이동, 자가진단, 승격 큐)

**조건**: harness.version == "1.0.0"
**결과**: harness.version → "1.1.0"

**변경 목록**:

1. [new] scripts/harness-check.sh: 하네스 자가진단 스크립트
   - 카테고리: managed
   - 템플릿: templates/harness-check.sh (§ 5.14 치환 규칙, manifest.profile 값 사용)
   - package.json에 `harness:check` 스크립트 추가 (§ 5.5 방식, 이미 있으면 스킵)

2. [custom] AGENTS.md: "## 명령어" 섹션 추가 (명령어 source of truth 이동)
   - 작업: add-section
   - 위치: "## 프로젝트 개요" 섹션 뒤
   - 내용: 개발 서버(+포트)/테스트/validate/lint:arch/harness:check (manifest.profile 값으로 작성)
   - 보존: 기존 섹션 전체. "## 명령어" 섹션이 이미 있으면 스킵 (멱등). 추가 후 100줄 초과 시 문서 맵 압축을 제안

3. [custom] AGENTS.md: "## 주요 규칙"에 필수 규칙 2종 보장
   - 작업: modify-section
   - 위치: "## 주요 규칙"
   - 내용: "feature_list.json의 기능 설명을 수정/삭제하지 않는다", "passes는 실제 검증 통과 후에만 true로 바꾼다" — 없는 규칙만 추가
   - 보존: 기존 규칙 항목 전체

4. [custom] CLAUDE.md: "## 명령어" 섹션을 AGENTS.md 참조로 대체
   - 작업: modify-section
   - 위치: "## 명령어"
   - 내용: 표준 명령(개발 서버/테스트/타입 체크/validate/lint:arch)만 있으면 섹션을 제거한다 (@AGENTS.md import가 커버). **표준 외 사용자 정의 명령이 발견되면** AGENTS.md "## 명령어"로 이동을 제안하고 사용자 확인 후 처리한다
   - 보존: 사용자 정의 명령 (이동 확인 전까지 삭제 금지). 섹션이 이미 없으면 스킵 (멱등)

5. [custom] CLAUDE.md: "## 운영 사이클" 섹션 추가
   - 작업: add-section
   - 위치: "## 금지 사항" 앞
   - 내용: 일간 validate / 주간 doc:check+QUALITY_SCORE / 격주 TECH_DEBT(승격 큐) / 월간 전면 검토+passes 재검증+harness:check 테이블 (§ 5.1.1 참조)
   - 보존: 기존 섹션. 이미 있으면 스킵 (멱등)

6. [custom] CLAUDE.md: 금지 사항에 회귀 우선 규칙 추가
   - 작업: modify-section
   - 위치: "## 금지 사항"
   - 내용: "기존에 passes: true였던 기능의 회귀를 무시하고 새 기능을 진행하지 않는다 (회귀 복구 우선)" 행이 없으면 추가

7. [data] docs/TECH_DEBT.md: "자동 검사 승격 대기 큐" 섹션 추가
   - 작업: add-field (섹션)
   - 상세: "## 자동 검사 승격 대기 큐" 섹션이 없으면 파일 끝에 추가 (templates/TECH_DEBT.md의 해당 섹션 형식). 기존 부채 항목은 절대 수정하지 않는다

8. [data] docs/QUALITY_SCORE.md: 갱신 주기 헤더 추가
   - 작업: add-field (헤더 1줄)
   - 상세: "> 갱신 주기: 주간" 행이 헤더 블록에 없으면 추가. 기존 점수는 절대 수정하지 않는다

9. [profile] eslintAssist: ESLint 보조 규칙 옵트인 필드
   - 작업: add
   - 기본값: 필드 생략 (미적용)
   - 소스: 업그레이드 시 자동으로 질문하지 않는다 — 사용자가 원하면 ESLint 설정 감지 후 문답으로 옵트인 (§ 5.15)

> managed 템플릿 변경분(session-routine.md, coding-standards.md, reviewer.md, test-engineer.md)은 자동 감지(SKILL.md § 12.6)로 전파되므로 이 마이그레이션에 포함하지 않는다. TECH_DEBT/QUALITY_SCORE는 data 카테고리라 자동 감지 대상이 아니므로 7~8번 항목으로 처리한다.

#### M-1.1.0-to-1.2.0: 비대화형 검증 명령 보장 (watch 모드 영구 대기 방지)

**조건**: harness.version == "1.1.0"
**결과**: harness.version → "1.2.0"

> 배경: 실전 테스트(haja-web-fe)에서 `"test": "vitest"`(watch 기본)가 validate에 그대로 조합되어
> 비대화형 검증 루프(harness:check, 에이전트 검증)가 영구 대기하는 문제 발견.

**변경 목록**:

1. [custom] package.json: watch 기본 test 가드
   - 작업: modify-section (scripts)
   - 조건: 기존 `test` 스크립트가 watch 기본(예: `vitest` 단독, `--watch` 포함)일 때만 실행. 아니면 전체 스킵
   - 내용: ① `test:run` 키 추가 (단발 실행 형태, 예: `vitest run`, 이미 있으면 스킵) ② `validate` 스크립트의 `npm run test` 구간을 `npm run test:run`으로 교체 (validate를 사용자가 수정한 경우 교체 전 확인)
   - 보존: 기존 `test` 키는 수정하지 않는다 (사용자의 watch 워크플로 유지)

2. [profile] scripts.test: 비대화형 명령으로 갱신
   - 작업: rename (값 갱신)
   - 조건: manifest.profile.scripts.test가 watch 기본 명령일 때만
   - 내용: `npm run test:run`으로 갱신 — `{{TEST_COMMAND}}` 재치환의 원천이므로, 갱신 후 managed 자동 감지가 test-engineer.md/session-routine.md를 재생성한다

#### M-1.2.0-to-1.3.0: domain-based 템플릿 채택 + 프리셋 확장 대응

**조건**: harness.version == "1.2.0"
**결과**: harness.version → "1.3.0"

**변경 목록**:

1. [profile] sharedDirs: 도메인 간 공유 모듈 디렉토리 목록
   - 작업: add
   - 조건: manifest.profile.architectureType == "domain-based"일 때만 (그 외 유형은 필드 생략)
   - 기본값: srcRoot에서 `shared`/`common`/`core` 중 실제 존재하는 폴더, 없으면 `["shared"]`
   - 소스: 디렉토리 탐색, 불확실하면 사용자에게 질문

> 안내: domain-based 프로젝트는 이번 버전부터 structural-test.ts가 동적 생성 → `templates/structural-test-domain.ts` 기반으로 바뀐다. 자동 감지(SKILL.md § 12.6)가 템플릿 매핑(`structural-test-{architectureType}.ts`)으로 변경을 감지하므로 별도 마이그레이션 항목은 불필요하다 — 다만 기존 동적 생성본을 사용자가 수정했다면 "사용자 선택" 분기가 발생한다. 신규 프리셋(react-vite, express-api)과 detection.exclude 필드는 신규 셋업에만 영향이 있어 마이그레이션 대상이 아니다.

#### M-1.3.0-to-1.4.0: harness-cleanup 컴패니언 스킬 안내

**조건**: harness.version == "1.3.0"
**결과**: harness.version → "1.4.0"

**변경 목록**:

1. [custom] CLAUDE.md: 운영 사이클에 cleanup 스킬 안내 추가
   - 작업: modify-section
   - 위치: "## 운영 사이클" 테이블 아래
   - 내용: `주간/격주/월간 작업은 harness-cleanup 컴패니언 스킬로 실행할 수 있다 (--add-dir 등록 후 "하네스 정리" 요청).` 1줄 — 해당 문구가 없으면 추가 (멱등)
   - 보존: 기존 테이블과 섹션 전체. "## 운영 사이클" 섹션 자체가 없으면(1.1.0 미만에서 직접 올라온 비정상 경로) 이 항목을 건너뛰고 보고에 명시

> 안내: harness-cleanup 스킬 자체는 컴패니언 스킬(Public API 밖)이라 마이그레이션 대상이 아니다 — 이 마이그레이션은 기존 하네스의 CLAUDE.md에 안내 한 줄을 추가할 뿐이다.

#### M-1.4.0 이후 (1.5.0 ~ 현재): 마이그레이션 불필요

> **M-1.3.0-to-1.4.0 다음이 M-1.6.4-to-1.7.0인 것은 정상이다** — 1.5.0~1.6.4는 마이그레이션이 없다. 생성 하네스에 작업이 필요 없었다:
> - **1.5.0** (superpowers 옵트인): `integrations`는 생략이 기본값이라 기존 프로필에 추가 불필요. session-routine.md의 `{{INTEGRATION_NOTES}}` 추가는 managed 템플릿 변경이므로 § 12.6 자동 감지로 전파 (미연계 시 빈 문자열 치환). 신규 셋업/업그레이드 U1 재감지에서만 동작
> - **1.6.0** (multi-model-consult): 컴패니언 스킬 신설 — Public API(프로필/매니페스트/프리셋/생성 파일) 무변경
> - **1.6.1~1.6.4**: install.sh·run-advisor.js·Stop hook·문서 수정·정합성 감사 — 모두 스킬 인프라이고 생성 하네스 산출물에 영향 없음

#### M-1.6.4-to-1.7.0: 외부 통합 규약 일반화 (보조 스킬 섹션 다중 통합)

**조건**: harness.version == "1.6.4"
**결과**: harness.version → "1.7.0"

> 규약 일반화로 AGENTS.md "보조 스킬" 섹션이 단일 통합(superpowers) 전용에서 다중 통합 합산 형식으로 바뀐다. 기존 superpowers 옵트인 하네스의 섹션 형식을 정규화한다.

**변경 목록**:

1. [custom] AGENTS.md: 보조 스킬 섹션 다중 통합 형식으로 정규화
   - 작업: modify-section
   - 조건: `integrations.superpowers` 옵트인 하네스만 해당 (섹션이 없으면 = 미연계, 스킵)
   - 위치: "## 보조 스킬 (superpowers 연계)" 헤딩
   - 내용: ① 제목을 "## 보조 스킬"로 정규화 ② 각 연계 항목 끝에 "(superpowers)" 출처 표기 추가 ③ 안내문을 "외부 보조 스킬 연계 — 미설치 환경에서는 무시된다"로 일반화 (§ 5.16 형식)
   - 보존: 기존 연계 항목의 스킬 목록·문구. **멱등**: 제목이 이미 "## 보조 스킬"(괄호 없음)이고 출처 표기가 있으면 스킵

2. [profile] integrations.multiModelConsult: U1 재감지에서 새로 감지되면 연계 추가를 제안한다 (옵트인 — 자동 추가 아님). 동의 시 보조 스킬 섹션에 항목 합산
   - 기본값: 미연계 (생략) — 자동 추가하지 않음

> 새 버전을 추가할 때 마이그레이션이 필요한지 판단 기준: ① custom 파일 외과 수정 ② [new]/[remove] 파일 ③ [profile] 기본값 있는 새 필드 ④ [data] 스키마 변경 — 이 중 하나라도 해당하면 등록한다. managed 템플릿 변경·컴패니언 스킬·인프라 수정은 등록하지 않는다.
>
> **1.7.1**(이슈 정리·install.sh 인프라)과 **1.8.0**(autoCommit)도 위 기준상 마이그레이션이 없다 — autoCommit은 git-workflow.md(managed)에 `{{AUTO_COMMIT_MODE}}` 추가이므로 § 12.6 자동 감지로 전파되고(기존 하네스는 mode=off 섹션이 덧붙음, 무해), 프로필 필드는 생략=off라 기존 프로필에 추가 불필요.
>
> **1.9.0**(보장 정직화+의미검증)도 마이그레이션이 없다 — `{{Q2_ENFORCEMENT}}` 마커와 manifest 필드(`structuralTestEnforcement`/`semanticApprovalAt`)는 managed 템플릿(structural-test의 layer/fsd/domain, harness-check.sh)과 manifest 재렌더에 § 12.6 자동 감지로 전파된다. custom structural-test(자동 감지 제외)에 마커가 없으면 harness-check ④-b는 안전하게 `enforced`로 간주(기존 동작 유지). 골든 픽스처는 스킬 내부 테스트(test/)라 생성 하네스와 무관.
>
> **1.14.0**(이슈 #12 증분 2b, pre-push 게이트)도 마이그레이션이 없다 — `.githooks/pre-push`는 신규 managed 파일이지만 `e2e.prePush` 옵트인 시에만 생성되고 생략=off라(1.11.0 e2e 모듈과 동일 선례), 기존 하네스는 산출물 0건이다. harness-check.sh ⑨ 추가분은 § 12.6 자동 감지로 전파된다. 신규 파일 생성은 U1 재감지 옵트인 경로로만 발생한다 (Phase U1 재감지).
>
> **1.15.0**(이슈 #12 증분 3, MCP 진단 배선)도 마이그레이션이 없다 — `e2e.mcp`는 옵트인·생략 기본이라(1.11.0/1.14.0 선례) 기존 프로필에 추가 불필요하고, 신규 파일을 만들지 않는다(debugger.md의 `{{MCP_DEBUG_PROTOCOL}}` 치환만). debugger.md(managed) 템플릿 변경은 § 12.6 자동 감지로 전파되며(미옵트인 시 빈 문자열 치환), 산출물 0건이라 별도 M-엔트리가 없다. 재치환은 U1 재감지 옵트인 경로로만 발생한다 (Phase U1 재감지).
>
> **1.16.0**(이슈 #12, TODO-99 레이아웃 회귀 트리거 확장)도 마이그레이션이 없다 — 신규 프로필 필드·플레이스홀더·파일 0건이다. test-engineer.md·coding-standards.md·session-routine.md(managed)의 E2E 트리거 확장(시각/레이아웃 회귀 위험 포함)·jsdom 한계 명시·브라우저 검증→스펙 코드화 규율은 모두 § 12.6 자동 감지로 전파된다. e2e 미옵트인 하네스는 트리거가 `e2e.enabled` 게이트라 무영향이다.
>
> **1.17.0**(이슈 #12 증분 4, E2E 모듈 마감)도 마이그레이션이 없다 — §12.6.1 매핑 정렬(A)·프리셋 e2e 권장 기본(B)·U1 재감지(C)·가이드 문서(D) 모두 옵트인·생략 기본이라 기존 프로필에 추가가 불필요하고, 기존 **e2e 미옵트인** 하네스의 산출물은 0건이다. 전파 경로를 파일별로 명확히 한다:
> - **playwright.config.ts·e2e/tsconfig.json** (기존 매핑 부재 → 본 릴리스에서 §12.6.1 편입): 기존 **e2e 옵트인** 하네스의 manifest에 이미 이 파일들이 managed로 기록돼 있으므로, 매핑이 생기면서 **다음 업그레이드부터 § 12.6 자동 감지 대상**이 된다(이후 템플릿 변경이 전파됨). 신규 파일 생성 아님.
> - **e2e/README.md** (신규 managed 파일): **셋업 시점**(신규 하네스, § 5.17)과 **U1 E2E 재감지 옵트인**(비-e2e 하네스가 금번 수락) 경로로만 생성된다. 일단 생성되면 manifest에 기록되어 그 하네스의 이후 업그레이드에서 § 12.6 자동 감지로 최신 유지된다. **기존(1.11.0~1.16.0) e2e 옵트인 하네스에는 소급 생성하지 않는다** — `[new]` 마이그레이션을 추가하면 비-e2e 하네스에도 주입되거나 프로필-게이트 마이그레이션이라는 새 복잡성이 생겨 비침습·옵트인 원칙과 충돌하기 때문이다. 그 하네스들은 동일 가이드 내용을 이미 가진 에이전트-규칙 파일(test-engineer.md·coding-standards.md)로 커버되며, 가이드가 필요하면 셋업 재실행으로 받을 수 있다(의도된 무마이그레이션 트레이드오프).
>
> 추가 신규 파일 생성은 U1 재감지 옵트인 경로로만 발생한다 (Phase U1 재감지).

- **E2E 재감지** (1.17.0+ U1): 프론트엔드로 감지됐는데(SKILL.md § 1.4 = 신규셋업과 동일 신호 재사용 — testFramework.e2e가 playwright이거나 UI 프레임워크 감지) 프로필에 `e2e` 블록(특히 `e2e.enabled`)이 없으면, 업그레이드 U1 재감지에서 브라우저 E2E 계층(Playwright) 옵트인을 **제안**한다 (생략 기본 — 거절/무응답 시 산출물 0건). 수락 시 § 5.17 생성(playwright.config.ts·e2e/tsconfig.json·e2e/README.md = managed + fixtures/seed/smoke = custom 신규 파일) + manifest 등록(profile.e2e + 신규 templateHash). `@playwright/test`는 § 5.5 add-only 머지 후 Phase U5 수동 안내(스킬 미설치). **cascade**: 수락한 경우 이어서 아래 pre-push 재감지를 **같은 U1 패스에서** 평가한다(신규셋업의 SKILL.md § 4.2 E2E→pre-push 순서를 미러). MCP 재감지는 `e2e.enabled`와 무관하므로 독립 평가된다.
- **pre-push 재감지** (1.14.0+ U1): 기존(또는 금번 U1 패스에서 막 수락한) `e2e.enabled` 하네스에 `e2e.prePush`가 없고 git 저장소면, 업그레이드 U1 재감지에서 pre-push 게이트 옵트인을 **제안**한다 (생략 기본 — 거절/무응답 시 산출물 0건). 수락 시 § 5.18 생성 로직(공존성 분기 포함) 실행 + manifest 등록. 활성화는 Phase U5 보고에서 수동 안내(스킬은 git config 미실행).
- **MCP 재감지** (1.15.0+ U1): 기존 프론트엔드 하네스에 `e2e.mcp`가 없으면 업그레이드 U1에서 브라우저 MCP 진단 옵트인을 **제안**한다(생략 기본 — 거절/무응답 시 산출물 0건). 수락 시 debugger.md `{{MCP_DEBUG_PROTOCOL}}`를 § 5.19 블록으로 재치환(managed 재렌더링).

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
| scripts/harness-check.sh | `templates/harness-check.sh` | `references/harness-checklist.md` § 8 | § 5.14 치환 규칙 적용 |
| AGENTS.md | `references/harness-guide.md` P2 섹션 | 형식 참고 (내용은 프로필 기반으로 작성) |

### 파일 목록
- `references/harness-guide.md` — Anthropic + OpenAI 하네스 엔지니어링 통합 가이드 (P1~P10 프로세스)
- `references/harness-checklist.md` — 하네스 구성 체크리스트 (Phase 3 검증과 단계 판정의 기준 문서)
- `references/integrations/_protocol.md` — 외부 통합 규약 (§ 5.16 렌더링 메커니즘 정본)
- `references/integrations/superpowers-mapping.md` — superpowers 연계/제외 분류 정본 (§ 5.16 렌더링 소스)
- `references/integrations/multi-model-consult-mapping.md` — multi-model-consult 연계 정본
- `references/project-context.md` — 이 스킬의 설계 결정 기록, 버전 히스토리, 다음 단계
- `references/upgrade-system-design.md` — 업그레이드 시스템 설계 문서 (매니페스트, 카테고리, 마이그레이션)
- `references/versioning-policy.md` — semver 기반 버전 관리 정책 (Public API 정의, 범프 기준)

### 우선순위 규칙
**이 파일(harness-scaffold/SKILL.md)이 스캐폴딩의 정규 사양이다.** 이 파일과 harness-guide.md의 내용이 충돌하면 이 파일이 우선한다.
