# 하네스 업그레이드 시스템 설계

> 작성일: 2026-04-07
> 상태: 설계 완료, 구현 대기
> 관련: SKILL.md 섹션 14로 구현 예정
>
> **2026-04-11**: 버전 체계가 semver로 전환되었다. 이 문서의 예시에 등장하는 "3.3", "4.0" 등은 설계 형식 설명용이며, 실제 버전은 `references/versioning-policy.md`를 참조한다.

---

## 1. 매니페스트 스키마

대상 프로젝트 루트에 `.harness-manifest.json`을 생성한다. 하네스의 버전과 생성 이력을 추적하는 **단일 참조 파일**이다.

### 1.1 스키마

```json
{
  "harness": {
    "version": "4.0",
    "skillVersion": "4.0",
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

### 1.2 필드 설명

| 필드 | 용도 |
|------|------|
| `harness.version` | 하네스 스키마 버전. 마이그레이션 적용 기준 |
| `harness.skillVersion` | 마지막으로 사용된 스킬 버전 |
| `harness.installedAt` | 최초 셋업 시각 (ISO 8601) |
| `harness.upgradedAt` | 마지막 업그레이드 시각 (없으면 `null`) |
| `harness.upgradeInProgress` | 업그레이드 중단 감지용 플래그 |
| `harness.preset` | 사용된 프리셋 name (`"custom"` if 프리셋 없음) |
| `profile` | 플레이스홀더 치환에 필요한 **전체 프로필**. 업그레이드 시 재스캔 없이 재치환 가능 |
| `files.{path}.category` | `managed` / `custom` / `data` |
| `files.{path}.templateHash` | 생성 시점 파일 내용의 SHA-256 해시. 사용자 수정 여부 판별 |
| `files.{path}.generatedAt` | 해당 파일의 마지막 생성/갱신 시각 |

### 1.3 설계 결정

- **전체 프로필 저장**: 초기 설계에서는 `architectureType`, `srcRoot`, `pathAlias` 3개만 저장하려 했으나, SKILL.md의 플레이스홀더가 21개이고 소스가 `devServer`, `scripts`, `tdd`, `git`, `naming`, `layers` 등에 분산되어 있어 전체 프로필을 저장한다. 이렇게 해야 업그레이드 시 재스캔/재문답 없이 managed 파일을 재생성할 수 있다.
- **templateHash + 자동 감지**: 버전 번호 대신 해시를 사용한다. 현재 파일 해시와 manifest 해시를 비교하면 사용자 수정 여부를 판별할 수 있다. 추가로, 소스 템플릿을 재렌더링한 해시와 manifest 해시를 비교하면 템플릿 변경 여부도 자동 감지할 수 있다. 이로써 managed 파일은 마이그레이션 없이도 자동 갱신되며, 마이그레이션은 custom/new/remove/profile/data 변경 전용으로 역할이 분리된다.
- **단일 파일**: 파일별 주석 스탬프 대신 하나의 JSON 파일로 관리한다. LLM이 한 번에 전체 상태를 파악할 수 있고, 생성 파일에 불필요한 주석을 남기지 않는다.

### 1.4 해시 계산

```bash
node -e "const c=require('crypto'),f=require('fs'); console.log('sha256:'+c.createHash('sha256').update(f.readFileSync(process.argv[1],'utf8')).digest('hex'))" {file}
```

---

## 2. 파일 카테고리

### 2.1 카테고리 정의

| 카테고리 | 소유권 | 업그레이드 동작 |
|----------|--------|----------------|
| **managed** | 스킬 소유 | 최신 템플릿 + profile 값으로 재생성하여 덮어쓰기 |
| **custom** | 사용자 소유 | 덮어쓰지 않음. 마이그레이션 지시에 따라 외과적 수정 (섹션 추가/변경) |
| **data** | 사용자 소유 | 절대 수정 안 함. 스키마 변경 시에만 필드 추가 (기본값 적용) |

### 2.2 파일별 분류

| # | 파일 | 카테고리 | 근거 |
|---|------|----------|------|
| 1 | `docs/` 하위 디렉토리 (4개) | managed | 구조적 스캐폴딩, 사용자 콘텐츠 없음 |
| 2 | `ARCHITECTURE.md` | **custom** | 사용자가 도메인별 설명 추가, 의존 규칙 조정 |
| 3 | `AGENTS.md` | **custom** | 사용자가 프로젝트 맥락 추가, 섹션 수정 |
| 4 | `CLAUDE.md` | **custom** | 가장 많이 커스터마이징되는 파일. 명령, 규칙, 금지사항 추가 |
| 5 | `.claude/rules/session-routine.md` | managed | 템플릿 기반 TDD 오케스트레이션. 구조가 스킬 버전을 따라야 함 |
| 6 | `.claude/rules/coding-standards.md` | managed | 템플릿 기반. 플레이스홀더 값만 프로젝트별로 다름 |
| 7 | `.claude/rules/git-workflow.md` | managed | 템플릿 기반 |
| 8-14 | `agents/*.md` (7개) | managed | 템플릿 기반 subagent 정의. 구조 변경이 전파되어야 함 |
| 15 | `feature_list.json` | **data** | 런타임 데이터. 사용자/에이전트가 기능 항목 축적 |
| 16 | `claude-progress.txt` | **data** | 세션 상태 누적. 절대 덮어쓰면 안 됨 |
| 17 | `init.sh` | managed | 템플릿 기반 초기화 스크립트 |
| 18 | `scripts/structural-test.ts` | managed | 템플릿 기반 아키텍처 검증 |
| 19 | `scripts/doc-freshness.ts` | managed | 템플릿 기반 문서 최신성 검사 |
| 20 | `docs/QUALITY_SCORE.md` | **data** | 사용자/에이전트가 점수 기록 |
| 21 | `docs/TECH_DEBT.md` | **data** | 사용자/에이전트가 부채 항목 축적 |
| 22 | `docs/HARNESS_FRICTION.md` | **data** | session-routine이 마찰 이벤트 기록 |
| 23 | `package.json` (scripts) | **custom** | 스킬은 특정 키만 추가. 사용자가 수정했을 수 있음 |

### 2.3 managed 파일의 변경 감지 및 대응

managed 파일의 업그레이드 판정은 **템플릿 자동 감지**를 사용한다. 소스 템플릿을 manifest.profile 값으로 재렌더링한 해시(`expectedHash`)와 manifest의 `templateHash`를 비교하여 템플릿 변경 여부를, 현재 파일 해시와 `templateHash`를 비교하여 사용자 수정 여부를 동시에 판정한다.

| 템플릿 변경? | 사용자 수정? | 판정 |
|---|---|---|
| No | No | 스킵 (변경 불필요) |
| No | Yes | 스킵 (사용자 변경 유지) |
| Yes | No | 자동 덮어쓰기 (안전) |
| Yes | Yes | 사용자 선택 (아래 3가지) |

템플릿이 변경되었고 사용자도 파일을 수정한 경우, 3가지 선택지를 제시한다:

1. **덮어쓰기** — 최신 템플릿으로 교체 (사용자 변경 소실)
2. **스킵** — 현재 파일 유지. manifest에 `"userOverride": true` 표시하여 향후 업그레이드에서도 스킵
3. **병합** — LLM이 구조적 변경만 적용하고 사용자 추가분 보존 (best-effort)

---

## 3. 업그레이드 실행 흐름

### 3.1 모드 판별

스킬 실행 시 최초에 모드를 판별한다:

```
Step 0: 모드 판별
  ├── 하네스 파일 없음 → Setup 모드 (기존 Phase 1~4)
  ├── 하네스 파일 있음 + .harness-manifest.json 없음 → Bootstrap + Upgrade
  └── 하네스 파일 있음 + .harness-manifest.json 있음 → Upgrade 모드
```

### 3.2 트리거

다음 표현으로 업그레이드 모드를 트리거한다:
- "하네스 업그레이드", "harness upgrade"
- "하네스를 최신 버전으로 업데이트해줘"
- `/harness-setup upgrade`

### 3.3 업그레이드 페이즈 (U1~U5)

```
Phase U1: 분석
  ├── .harness-manifest.json 읽기
  ├── 버전 갭 계산: installed → current
  ├── 적용할 마이그레이션 목록 로드 (순서대로)
  ├── managed 파일 템플릿 자동 변경 감지:
  │     각 managed 파일에 대해:
  │       1. 소스 템플릿을 manifest.profile로 렌더링 → expectedHash
  │       2. expectedHash vs templateHash → 템플릿 변경 여부
  │       3. 현재 파일 해시 vs templateHash → 사용자 수정 여부
  └── 파일별 상태 판별 (4-상태):
        ├── data → 스킵
        ├── managed + 템플릿 변경 없음 → 스킵 (변경 불필요)
        ├── managed + 템플릿 변경 + 사용자 미수정 → 자동 덮어쓰기
        ├── managed + 템플릿 변경 + 사용자 수정 → 선택 필요
        ├── managed + userOverride: true → 자동 스킵
        └── custom → 마이그레이션 지시에 따라 외과적 수정 예정
         ↓
Phase U2: 계획 제시
  사용자에게 테이블 형태로 보여준다:
  ┌──────────────────────────────────────┬──────────┬──────────────────────────────────┐
  │ 파일                                 │ 작업     │ 이유                             │
  ├──────────────────────────────────────┼──────────┼──────────────────────────────────┤
  │ agents/architect.md                  │ 덮어쓰기 │ 템플릿 변경 감지, 사용자 수정 없음 │
  │ .claude/rules/session-routine.md     │ 덮어쓰기 │ 템플릿 변경 감지, 사용자 수정 없음 │
  │ agents/reviewer.md ⚠️                │ 사용자 선택│ 템플릿 변경 + 사용자 수정 감지    │
  │ agents/test-engineer.md              │ 스킵     │ 템플릿/프로필 변경 없음            │
  │ CLAUDE.md                            │ 부분 수정│ 마이그레이션 지시                  │
  │ feature_list.json                    │ 스킵     │ data                             │
  └──────────────────────────────────────┴──────────┴──────────────────────────────────┘
  → 사용자 승인 대기
         ↓
Phase U3: 실행
  1. 새 디렉토리 생성 (있으면)
  2. managed 파일 재생성 (최신 템플릿 + profile 값)
  3. custom 파일 외과적 수정 (마이그레이션 지시 따름)
  4. data 스키마 패치 (필요 시 필드 추가)
  5. package.json scripts 추가 (기존 키 삭제 안 함)
  6. .harness-manifest.json 갱신:
     - harness.version ← current
     - harness.upgradedAt ← now
     - harness.upgradeInProgress ← false
     - files 항목 갱신 (해시, 신규 파일, 삭제 파일)
         ↓
Phase U4: 검증
  기존 Phase 3 검증 체크리스트 + manifest 정합성:
  - 모든 managed 파일 존재
  - JSON 유효성
  - 플레이스홀더 미치환 잔존 검사
  - manifest.harness.version == 현재 스킬 버전
         ↓
Phase U5: 보고
  ## 하네스 업그레이드 완료
  - 버전: {old} → {new}
  - 덮어쓰기: N개 managed 파일
  - 부분 수정: N개 custom 파일
  - 신규 생성: N개 파일
  - 스킵: N개 data 파일
  - 주의 사항: {migration-specific notes}
```

---

## 4. 마이그레이션 레지스트리

### 4.1 형식

SKILL.md 섹션 14.4에 마이그레이션 레지스트리를 작성한다. 각 마이그레이션은 다음 구조를 따른다:

```markdown
#### M-{from}-to-{to}: {title}

**조건**: harness.version == "{from}"
**결과**: harness.version → "{to}"

**변경 목록**:

1. [managed] {file}: {description}
   - 작업: overwrite
   - 상세: {what changes in the template}

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

### 4.2 변경 항목 타입 정리

| 타입 | 대상 | LLM 실행 방법 |
|------|------|---------------|
| `[managed] overwrite` | managed 파일 | 템플릿 읽기 → profile로 플레이스홀더 치환 → 파일 쓰기 |
| `[custom] add-section` | custom 파일 | 파일 읽기 → 지정 위치 찾기 → 내용 삽입 → 파일 쓰기 |
| `[custom] modify-section` | custom 파일 | 파일 읽기 → 지정 섹션 찾기 → 변경 적용 (주변 보존) → 파일 쓰기 |
| `[new]` | 신규 파일 | 초기 셋업과 동일하게 생성 |
| `[remove] delete` | 삭제 파일 | 사용자 확인 후 삭제, manifest에서 제거 |
| `[remove] deprecate` | 폐기 파일 | manifest에 `deprecated: true` 표시, 사용자에게 알림 |
| `[data] add-field` | data 파일 | JSON 읽기 → 필드 추가 (기본값) → JSON 쓰기 |
| `[profile] add` | manifest profile | 새 profile 필드 추가 (기본값 또는 사용자 질문) |

### 4.3 체이닝

버전 갭이 여러 단계일 때 마이그레이션을 순차 적용한다:

```
M-3.3-to-4.0 → M-4.0-to-4.1 → M-4.1-to-5.0
```

각 마이그레이션이 완료되면 manifest의 `harness.version`을 해당 단계의 `{to}` 값으로 갱신한 뒤 다음 마이그레이션으로 진행한다. 중단 시 현재까지 적용된 버전이 manifest에 기록되어 있으므로 재시작이 안전하다.

### 4.4 예시: M-3.3-to-4.0

```markdown
#### M-3.3-to-4.0: (예시) QA 에이전트 추가 + 세션 루틴 개선

**조건**: harness.version == "3.3"
**결과**: harness.version → "4.0"

**변경 목록**:

1. [new] agents/qa-engineer.md
   - 카테고리: managed
   - 템플릿: templates/agents/qa-engineer.md
   - 플레이스홀더: {{VALIDATE_COMMAND}}, {{TEST_COMMAND}}

2. [managed] .claude/rules/session-routine.md: QA 에이전트 dispatch 행 추가
   - 작업: overwrite

3. [managed] agents/reviewer.md: Output Format에 NEEDS_QA 판정 추가
   - 작업: overwrite

4. [custom] CLAUDE.md: Agent Dispatch 테이블에 QA 행 추가
   - 작업: add-section
   - 위치: "Agent Dispatch" 또는 "TDD Subagent" 테이블 내
   - 내용: `| Post-Green | QA Engineer | agents/qa-engineer.md |` 행 추가
   - 보존: 기존 테이블 행 + 사용자 추가 행

5. [custom] AGENTS.md: 에이전트 참조 추가
   - 작업: modify-section
   - 위치: "주요 규칙" 또는 에이전트 관련 섹션
   - 내용: QA 에이전트 참조 (없으면 추가)
   - 보존: 전체 기존 내용
```

> **참고**: 위 예시는 형식 설명용이다. 실제 M-3.3-to-4.0 마이그레이션은 v4.0의 변경사항이 확정된 후 작성한다.

---

## 5. 부트스트랩 마이그레이션 (v0 → v3.3)

manifest 없이 셋업된 기존 프로젝트를 버전 관리 체계에 편입시키는 절차.

### 5.1 흐름

```
Step 1: 기존 하네스 파일 탐색
  - AGENTS.md, CLAUDE.md, ARCHITECTURE.md, agents/*.md,
    .claude/rules/*.md, scripts/*.ts, docs/*.md, init.sh,
    feature_list.json, claude-progress.txt 존재 여부 확인

Step 2: 프로필 추론
  - coding-standards.md → architectureType
  - structural-test.ts → pathAlias, srcRoot, layers
  - init.sh → devServer (command, port)
  - package.json scripts → validate, test 명령
  - CLAUDE.md → tdd 설정, git 설정
  추론 실패 시 → 사용자에게 질문 (재스캔 아닌 포커스드 질문)

Step 3: 초기 manifest 생성
  - harness.version = "3.3" (마지막 pre-versioning 릴리스)
  - 모든 기존 파일의 현재 내용을 해시하여 templateHash로 기록
  - 카테고리는 § 2.2 테이블에 따라 할당

Step 4: 사용자 확인
  "기존 하네스를 감지했습니다. 버전 추적을 위한
   .harness-manifest.json을 생성합니다."
  추론된 프로필 표시 → 사용자 확인/수정

Step 5: manifest 쓰기 → 정상 업그레이드 플로우 (3.3 → current) 진입
```

### 5.2 설계 결정

- **v3.3 고정**: pre-versioning 시절의 구조적 변경은 없었으므로 모든 기존 프로젝트를 v3.3으로 간주한다. 실제로 v3.0이든 v3.2이든 v3.3이든 마이그레이션 관점에서 차이가 없다.
- **해시 = 현재 상태**: 부트스트랩 시 기록되는 templateHash는 "원래 생성된 상태"가 아니라 "현재 파일 상태"이다. 따라서 첫 업그레이드에서 managed 파일의 해시가 불일치할 수 있고, 이 경우 § 2.3의 3가지 선택지를 제시한다.

---

## 6. 엣지 케이스

### 6.1 managed 파일 사용자 수정

**감지**: `sha256(현재 파일) != files[path].templateHash`
**대응**: § 2.3의 3택 (덮어쓰기/스킵/병합)

`userOverride: true`로 표시된 파일은 이후 업그레이드에서 자동 스킵한다. 사용자가 다시 managed로 돌리고 싶으면 manifest에서 해당 플래그를 제거하면 된다.

### 6.2 중단된 업그레이드

**감지**: `harness.upgradeInProgress == true`
**대응**: "이전 업그레이드가 중단된 것 같습니다. 처음부터 다시 진행할까요?"

Phase U3 시작 전에 `upgradeInProgress`를 `true`로 설정하고, 완료 시 `false`로 되돌린다. managed 파일 재생성은 멱등이므로 재실행이 안전하다. custom 파일 외과적 수정도 멱등으로 설계한다 ("이 행이 없으면 추가" 패턴).

### 6.3 새 플레이스홀더 등장

스킬 업데이트로 새 플레이스홀더 `{{NEW_FIELD}}`가 추가된 경우:
- 마이그레이션에 `[profile] add` 항목으로 기술
- 기본값이 있으면 자동 적용, 없으면 Phase U1에서 사용자에게 포커스드 질문
- manifest의 `profile`에 새 필드 추가

### 6.4 preset 삭제/변경

사용된 프리셋이 스킬에서 삭제된 경우:
- manifest의 `profile`에 저장된 값으로 폴백 (프리셋 없이도 동작)
- 경고: "프리셋 '{name}'을 찾을 수 없습니다. 매니페스트의 프로필 값을 사용합니다."

### 6.5 파일 삭제 (신규 버전에서 제거)

마이그레이션의 `[remove]` 항목:
- `delete`: 사용자 확인 후 삭제, manifest에서 제거
- `deprecate`: manifest에 `deprecated: true` 표시, 삭제 여부는 사용자 결정
- 자동 삭제하지 않는다 — 항상 사용자 확인

### 6.6 아키텍처 유형 변경

사용자가 셋업 후 아키텍처를 변경한 경우 (예: layer-based → FSD):
- Phase U1에서 확인: "현재 아키텍처 유형이 {manifest value}으로 기록되어 있습니다. 맞나요?"
- 변경 시: profile 갱신 → 아키텍처 의존 파일 재생성 (structural-test.ts, coding-standards.md, ARCHITECTURE.md)

### 6.7 팀 환경

`.harness-manifest.json`을 git에 커밋하는 경우:
- 한 팀원이 업그레이드 → 커밋 → 다른 팀원이 pull하면 업그레이드된 하네스를 받음
- 두 팀원이 동시에 업그레이드하면 manifest에 머지 충돌 발생 → 높은 버전 쪽을 수용
- Phase U5 보고에서 "manifest를 커밋하면 팀 전체에 반영됩니다" 안내

### 6.8 신규 파일 추가

마이그레이션의 `[new]` 항목:
- 초기 셋업과 동일하게 생성 (템플릿 + profile 치환)
- manifest의 `files`에 새 항목 추가
- 이미 같은 경로에 파일이 있으면: "이미 {path}가 존재합니다. 덮어쓸까요?" 확인

---

## 7. SKILL.md 통합 포인트 (구현 시 참고)

### 7.1 수정 대상 섹션

| 섹션 | 수정 내용 |
|------|----------|
| **§ 2 트리거 조건** | 업그레이드 트리거 추가 |
| **§ 3 실행 흐름** | Step 0 모드 판별 분기 추가 |
| **§ 5 Phase 2 끝** | 새 항목 5.13: `.harness-manifest.json` 생성 규칙 |
| **§ 6 Phase 3** | 새 항목 6.12: manifest 검증 |
| **§ 7 Phase 4** | 버전 관리 안내 추가 |
| **§ 12 확장 포인트** | 업그레이드 시스템을 "구현 완료"로 이동 |
| **새 § 14** | 업그레이드 시스템 전체 (매니페스트, 카테고리, 플로우, 레지스트리) |

### 7.2 구현 순서

1. **Phase 2에 manifest 생성 추가** — 모든 신규 셋업이 manifest를 갖도록
2. **파일 카테고리 테이블** — § 14.2로 추가
3. **모드 판별 로직** — § 2 + § 3 수정
4. **부트스트랩 마이그레이션** — § 14.5 (기존 프로젝트 대응)
5. **업그레이드 Phase U1~U5** — § 14.3
6. **마이그레이션 레지스트리** — § 14.4 (첫 번째 마이그레이션은 v4.0 변경사항 확정 후)
7. **검증 + 보고 업데이트** — § 6, § 7 수정
