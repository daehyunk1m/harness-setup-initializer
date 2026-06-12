# PRD: Superpowers 플러그인 옵트인 통합

> 작성일: 2026-05-28 (초안) / 구체화: 2026-06-12
> 상태: **Implemented (1.5.0, 2026-06-12)** — M1~M3 구현 완료. 실전 테스트는 superpowers 설치 환경 확보 후 (TODO-73 참조)
> 참고: obra/superpowers (Jesse Vincent의 Claude Code 스킬 모음)
> 조사 근거 (2026-06-12): GitHub 저장소 skills/ 디렉토리 전수 확인 (14개 스킬), 설치 방식·버전 확인 (v5.1.0, 공식 마켓플레이스), 로컬 플러그인 인프라 구조 확인 (`~/.claude/plugins/installed_plugins.json` v2 포맷)

---

## 1. 배경 및 문제 정의

### 1.1 문제
- 하네스가 생성하는 산출물(AGENTS.md, .claude/rules, TDD subagent 등)은 **프로젝트 골격**을 잡아주지만, 작업 중 반복되는 **워크플로 패턴**(브레인스토밍 구조화, 디버깅 루틴, 플랜 작성 절차 등)은 별도 스킬로 보완할 여지가 있다
- obra/superpowers 같은 외부 스킬 패키지가 이 영역에서 검증된 패턴을 제공한다
- 그러나 외부 의존성을 **하네스에 강제로 묶으면** 사용자 설치 부담, 버전 드리프트, 철학 충돌이 발생한다

### 1.2 해결 방향
- 하네스 코어는 **자급자족(self-contained)**을 유지한다
- superpowers 같은 외부 스킬 패키지는 **옵트인 통합 레이어**로 분리한다
- 프로필에 `integrations.<name>` 플래그를 두고, 켜졌을 때만 AGENTS.md/세션 루틴에 연계 가이드를 삽입한다

### 1.3 현황 (2026-06-12 조사)
- 하네스 1.4.0 — 코어 산출물 범위 확정, eslintAssist로 옵트인 통합 선례 확보 (마커 블록·멱등·폴백 패턴)
- superpowers **v5.1.0** (2026-05 릴리스) — 공식 마켓플레이스 플러그인으로 배포, 스킬 14종. 초안 작성 시점의 "v0.x 후반" 전제는 스테일이었음
- 향후 다른 외부 패키지(예: multi-model-consult) 통합의 **선례**가 필요하다

---

## 2. 목표

### 2.1 핵심 목표
1. 하네스 셋업 시 superpowers 연계 여부를 **소크라테스 문답**에서 묻고 (감지 시에만), 프로필에 기록한다
2. 옵트인된 경우 AGENTS.md/세션 루틴에 **연계 호출 지점**을 명시적으로 삽입한다
3. 코어 산출물과 **겹치는 영역**은 끌어오지 않는다 (TDD, 코드 리뷰, 검증 루프, git 워크플로는 우리 것이 우선)
4. 외부 패키지 버전이 바뀌어도 **하네스 코어는 깨지지 않는다**

### 2.2 비목표 (Non-goals)
- superpowers 자체를 하네스가 설치/관리하지 않는다 (사용자가 직접 설치)
- superpowers 스킬을 우리 templates/ 안에 복제하지 않는다 (라이선스/유지보수 부담)
- 모든 superpowers 스킬을 다 연계하지 않는다 (보완 영역만 선별 — 14종 중 기본 3종)
- 다른 외부 패키지도 동일 메커니즘으로 다룬다 — 단, 이번 PRD는 superpowers만 대상

---

## 3. 사용자 및 사용 시나리오

### 3.1 타깃 사용자
- 이미 superpowers를 설치해 쓰는 개발자 — 하네스가 이 도구들과 자연스럽게 엮이길 원함
- 새로 하네스를 셋업하면서 superpowers도 함께 고려하는 개발자
- 외부 의존을 싫어해 코어만 쓰고 싶은 개발자 — 이들은 옵트아웃이 기본

### 3.2 사용 시나리오

**시나리오 A — 기존 superpowers 사용자**
```
사용자: /harness-setup
스킬: (Q&A 중) "superpowers 플러그인을 감지했습니다 (v5.1.0).
       AGENTS.md에 brainstorming/systematic-debugging/writing-plans 연계 가이드를 삽입할까요?"
사용자: 네
→ 프로필: integrations.superpowers.enabled = true
→ AGENTS.md에 "보조 스킬" 섹션 + session-routine에 연계 라인 삽입
```

**시나리오 B — 미설치 사용자**
```
스킬: (Q&A 중) superpowers 미감지 → 질문 생략 (모르는 도구를 노출하지 않음)
→ 하네스는 코어 산출물만 생성
→ 나중에 superpowers 설치 후 "하네스 업그레이드"로 통합 추가 가능
```

**시나리오 C — 옵트아웃**
```
스킬: superpowers 감지됨, 그러나 사용자가 "연계 안 함" 선택
→ 프로필: integrations 필드 생략 (eslintAssist와 동일 — 생략 = 미적용)
→ 코어 산출물만 생성. AGENTS.md에 superpowers 언급 없음
```

---

## 4. 기능 요구사항

### 4.1 MVP (Phase 1)
| ID | 요구사항 | 우선순위 |
|----|---------|---------|
| F1.1 | 프로필 스키마에 `integrations.superpowers` 선택 필드 추가 (생략 = 미적용, eslintAssist 패턴) | P0 |
| F1.2 | Phase 1 스캔에서 superpowers 감지 — `installed_plugins.json`의 `superpowers@*` 키 (1순위) + `~/.claude/skills/superpowers*` (폴백) | P0 |
| F1.3 | 감지 시에만 Q&A에서 연계 여부 질의 (우선순위 5, 옵트인) | P0 |
| F1.4 | 옵트인 시 scaffold가 AGENTS.md "보조 스킬" 섹션 + session-routine 연계 라인 삽입 | P0 |
| F1.5 | 연계 화이트리스트 — `references/integrations/superpowers-mapping.md` (14종 전수 분류) | P0 |
| F1.6 | 코어 충돌 영역 제외 규칙 — 매핑에 없는 스킬은 linkedSkills에 있어도 렌더링하지 않음 | P0 |
| F1.7 | 스캐폴딩 시점 **스킬 실존 검증** — installPath/skills/{name} 확인, 없으면 해당 항목 드롭 + 경고 | P0 |

### 4.2 확장 (Phase 2)
| ID | 요구사항 | 우선순위 |
|----|---------|---------|
| F2.1 | 업그레이드 경로에서 integration 추가/제거 지원 | P1 |
| F2.3 | 다른 외부 패키지 연계를 같은 `integrations.<name>` 메커니즘으로 확장 | P2 |
| F2.4 | 사용자 정의 매핑 — 사용자가 "이 스킬을 여기에 끼워달라" 지정 | P3 |

> 초안의 F2.2(버전 호환 매트릭스)는 **폐기** — F1.7 스킬 실존 검증이 같은 문제(이름/구성 드리프트)를 더 직접적으로 해결한다. semver 범위 검사는 스킬 이름 변경을 못 잡는다.

---

## 5. 아키텍처

### 5.1 프로필 스키마 확장

```jsonc
{
  // ... 기존 필드 ...
  "integrations": {                    // 선택 필드 — 생략 시 연계 없음
    "superpowers": {
      "enabled": true,
      "source": "plugin",              // "plugin" (installed_plugins.json) | "skill-dir" (~/.claude/skills)
      "detectedVersion": "5.1.0",      // 감지 시점 버전 (정보용 — plugin이면 installed_plugins.json에서, skill-dir이면 null)
      "installPath": "~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0",  // 실존 검증용
      "linkedSkills": ["brainstorming", "systematic-debugging", "writing-plans"]
    }
  }
}
```

- 매니페스트 profile에도 보존한다 (업그레이드 시 재렌더링·제거 지원의 원천)

### 5.2 감지 로직 (SKILL.md Step 1.4 확장)

```
1. ~/.claude/plugins/installed_plugins.json 파싱 (v2 포맷):
   plugins 객체에서 "superpowers@" 접두 키 검색
   → 발견 시 source: "plugin", version·installPath 추출 (배열 첫 항목의 scope: user 우선)
2. 미발견 시 ~/.claude/skills/superpowers* 디렉토리 확인
   → 발견 시 source: "skill-dir", version: null, installPath: 해당 경로
3. 둘 다 미발견 → 질문 생략, integrations 필드 생략
4. 발견 → Q&A 질문 풀에 연계 질문 추가 (우선순위 5, 옵트인)
```

### 5.3 연계 매핑 테이블 (14종 전수 — 2026-06-12 실물 검증)

> 정본 위치: `references/integrations/superpowers-mapping.md` (구현 시 생성).
> 수동 큐레이션 — superpowers 신규 스킬은 검토 후 추가/제외 결정.

**연계 (기본 linkedSkills 3종):**

| superpowers 스킬 | 삽입 위치 | 이유 |
|-----------------|----------|------|
| `brainstorming` | AGENTS.md "보조 스킬" | 코어에 구조화된 브레인스토밍 가이드 없음 — 순수 보완 |
| `systematic-debugging` | AGENTS.md "보조 스킬" | 코어의 Debugger agent는 TDD 에스컬레이션 전용(validate 실패 시). 일반 버그 추적 루틴은 부재 — 보완. 단 TDD 사이클 중 validate 실패는 Debugger가 우선 |
| `writing-plans` | AGENTS.md "보조 스킬" + session-routine 연계 라인 | 계획 문서 작성 절차가 코어에 부재 — 보완. 단 PRE-RED 설계는 Architect/Plan 모드가 정규 경로이고, writing-plans는 계획 문서 품질 보조 |

**선택 (기본 미포함 — 사용자가 요청 시만):**

| 스킬 | 비고 |
|------|------|
| `using-superpowers` | 메타 가이드 — AGENTS.md에 한 줄. 기본 linkedSkills에는 미포함 |

**제외 (10종 — linkedSkills에 있어도 렌더링하지 않음):**

| 스킬 | 제외 사유 |
|------|----------|
| `test-driven-development` | **충돌** — TDD는 코어 정규 경로 (.claude/rules/session-routine.md + agents/ 7종) |
| `requesting-code-review`, `receiving-code-review` | **중복** — Reviewer agent + /review 빌트인 |
| `verification-before-completion` | **중복** — passes 검증 규칙 + validate 루프 + harness:check |
| `executing-plans` | **충돌** — 계획 실행 루프는 TDD 사이클이 정규 경로 (Plan 모드 통합 § 참조) |
| `subagent-driven-development` | **충돌** — 코어가 자체 subagent 파이프라인 보유 |
| `dispatching-parallel-agents` | **충돌 위험** — 오케스트레이션은 session-routine이 SoT |
| `using-git-worktrees` | **영역 겹침** — 브랜치 정책은 git-workflow.md가 SoT |
| `finishing-a-development-branch` | **충돌** — 세션 종료/커밋 절차는 git-workflow.md + session-routine |
| `writing-skills` | **무관** — 스킬 개발 메타, 하네스 산출물과 접점 없음 |

### 5.4 AGENTS.md 삽입 형식

옵트인 시 AGENTS.md "문서 맵" 앞에 삽입 (100줄 예산 내 — 약 8줄):

```markdown
## 보조 스킬 (superpowers 연계)

- 복잡한 설계 결정/트레이드오프 분석: `brainstorming`
- 재현 어려운 버그의 체계적 추적: `systematic-debugging` (TDD 중 validate 실패는 agents/debugger.md 우선)
- 다단계 작업의 계획 문서 작성: `writing-plans`

> superpowers 플러그인(v{detectedVersion}) 연계 — 미설치 환경에서는 무시된다.
> TDD·코드 리뷰·검증은 본 하네스 자체 워크플로를 사용한다.
```

session-routine.md (writing-plans 포함 시, Plan 모드 통합 섹션에 1줄):

```
계획 문서의 작성 절차가 필요하면 superpowers의 writing-plans 스킬을 보조로 활용할 수 있다 (PRE-RED 정규 경로는 Architect/Plan 모드).
```

### 5.5 스캐폴딩 흐름

```
프로필에 integrations.superpowers.enabled == true 이면:
  1. installPath/skills/{linkedSkill} 디렉토리 실존 검증 (F1.7)
     → 없는 스킬은 드롭하고 Phase 4 보고에 경고
  2. 매핑 테이블에서 linkedSkills 각 항목의 문구 조회
     → 매핑에 없는(제외 목록) 스킬은 렌더링하지 않음 (F1.6)
  3. AGENTS.md "보조 스킬" 섹션 + session-routine 연계 라인 렌더링
아니면:
  → 섹션/라인 자체를 생성하지 않음
```

- session-routine.md는 managed 템플릿이므로 조건부 라인은 **플레이스홀더가 아니라 scaffold의 조건부 삽입 규칙**으로 처리 (eslintAssist § 5.15와 동일하게 생성 규칙 분기)

---

## 6. 통합 정책

### 6.1 충돌 회피 원칙
1. **코어 우선**: TDD, 코드 리뷰, 검증 루프, git 워크플로, 오케스트레이션은 superpowers를 끌어오지 않는다
2. **보완만 끌어옴**: 코어에 없는 영역(브레인스토밍, 일반 디버깅 루틴, 계획 문서 작성)만 연계
3. **명시적 우선순위 표기**: 삽입문에 "TDD·코드 리뷰·검증은 본 하네스 사용" 명시

### 6.2 드리프트 대응 (버전 매트릭스 대신 실존 검증)
- **스캐폴딩/업그레이드 시점에 linkedSkills 각각의 스킬 디렉토리 실존을 확인** — 이름이 바뀌거나 제거된 스킬은 자동 드롭 + 경고 (F1.7)
- `detectedVersion`은 정보용으로만 기록 (보고·이슈 추적)
- superpowers 스킬 카탈로그 변경은 매핑 테이블 수동 갱신 (분기마다 리뷰 권장)

### 6.3 옵트아웃 보장
- 기본값: `integrations` 필드 **생략** (= 미적용. eslintAssist와 동일 패턴 — 명시적 false 대신 생략)
- 감지되더라도 사용자가 명시적으로 동의해야 활성화
- superpowers 제거 후에도 AGENTS.md 안내문은 잔류 — 삽입문에 "미설치 환경에서는 무시된다" 명시로 무해. 제거를 원하면 업그레이드 경로(F2.1)에서 integration 해제

---

## 7. 사용자 경험 (UX)

### 7.1 Q&A 메시지 (감지 시에만, 우선순위 5)
```
✓ superpowers 플러그인이 감지되었습니다 (v5.1.0).

AGENTS.md에 superpowers 연계 가이드를 삽입할까요?
연계 대상 (보완 영역만):
  - brainstorming (복잡한 설계 결정)
  - systematic-debugging (일반 버그 추적)
  - writing-plans (계획 문서 작성)

제외: TDD·코드 리뷰·검증·git 워크플로는 본 하네스 자체 워크플로 사용

[Y] 연계함 / [n] 연계 안 함
```

### 7.2 미감지 시
- 질문 자체를 생략 (모르는 도구를 노출하지 않음)

### 7.3 업그레이드 시
- 기존 프로필에 `integrations` 없음 = 미적용 — 마이그레이션에서 기본값 추가 **불필요** (생략이 곧 기본값)
- 업그레이드 중 superpowers가 새로 감지되면 통합 추가를 제안 (F2.1)

---

## 8. 검증 기준 (Acceptance Criteria)

- [ ] superpowers 미설치 환경에서 셋업 → 프로필에 `integrations` 키 없음, AGENTS.md에 superpowers 언급 없음, 질문도 없음
- [ ] superpowers 설치 환경에서 셋업 + 옵트인 → 프로필에 `enabled: true` + version/installPath, AGENTS.md에 "보조 스킬" 섹션 (100줄 이내 유지)
- [ ] superpowers 설치 환경 + 옵트아웃 → integrations 필드 생략, AGENTS.md에 언급 없음
- [ ] linkedSkills에 제외 목록 스킬(예: test-driven-development)을 넣어도 렌더링되지 않음 (F1.6)
- [ ] linkedSkills에 존재하지 않는 스킬명을 넣으면 드롭 + Phase 4 경고 (F1.7)
- [ ] 옵트인 후 superpowers 제거 → AGENTS.md 안내문 잔류, 호출 무시 (무해)
- [x] 매핑 테이블의 모든 스킬 이름이 실제 superpowers 스킬 디렉토리와 일치 — **2026-06-12 검증 완료** (14종 전수)
- [ ] 업그레이드 경로에서 integration 추가/제거 가능 (F2.1)

---

## 9. 한계 및 리스크

1. **수동 큐레이션**: 매핑 테이블은 우리가 직접 관리 — superpowers 신규 스킬 자동 반영 없음 (분기 리뷰)
2. **사용자 인지 부담**: AGENTS.md에 외부 스킬 호출이 섞임 — superpowers를 모르는 협업자 혼란 가능 → 삽입문에 "미설치 시 무시" 명시로 완화
3. **연계 확장의 유혹**: "이것도 좋은데 끼울까?" → 검증된 보완 영역만, 충돌 없는 것만 (매핑 테이블 PR 리뷰로 통제)
4. **라이선스**: 스킬 복제 없음 — 이름 인용만 (fair use)

---

## 10. 마일스톤 (구현 시 1.5.0 — MINOR: 새 프로필 필드 + 생성 규칙 추가)

### M1 — 스키마/감지/매핑
- [ ] 프로필 스키마 `integrations` 필드 (SKILL.md § 5 + harness-scaffold § 4 동기, 필드 규칙 포함)
- [ ] SKILL.md Step 1.4에 감지 로직 (installed_plugins.json + skills 폴백)
- [ ] § 4.2 질문 풀 조건부 질문 + § 4.4 기본값 (생략)
- [ ] `references/integrations/superpowers-mapping.md` 생성 (§ 5.3 테이블이 초안)

### M2 — 스캐폴딩
- [ ] harness-scaffold § 5.1 AGENTS.md 생성 규칙에 조건부 "보조 스킬" 섹션
- [ ] session-routine 조건부 연계 라인 (scaffold 생성 규칙 분기 — 템플릿 플레이스홀더 아님)
- [ ] F1.6 제외 필터 + F1.7 실존 검증 + Phase 3/4 반영
- [ ] manifest profile에 integrations 보존

### M3 — 업그레이드 경로
- [ ] 업그레이드 시 신규 감지 → 통합 추가 제안 / 기존 통합 제거 지원 (U1~U2)
- [ ] M-1.4.0-to-1.5.0 등록 (마이그레이션 필요 항목 확인 — integrations는 생략이 기본이라 [profile] add 불필요할 수 있음)
- [ ] CHANGELOG/HANDOFF/project-context 갱신

---

## 11. 결정 기록 (구 미결정 이슈 — 2026-06-12 전부 해소)

| # | 질문 | 결정 | 근거 |
|---|------|------|------|
| 1 | 감지 경로 — plugin vs skill? | **둘 다** — installed_plugins.json (`superpowers@*` 키) 1순위, ~/.claude/skills/superpowers* 폴백 | 공식 배포는 마켓플레이스 플러그인. 수동 클론 사용자 대비 폴백 |
| 2 | 버전 추출 방법? | installed_plugins.json의 `version` 필드 (skill-dir 폴백이면 null) | 로컬 인프라 실측 — v2 포맷에 version·installPath 포함 확인 |
| 3 | 매핑 테이블 위치? | `references/integrations/superpowers-mapping.md` 별도 파일 | 유지보수 빈도(분기 리뷰)가 SKILL.md보다 높음. SKILL.md는 참조만 |
| 4 | 다국어 — 스킬 이름 영어? | 스킬 이름은 영어 원형 유지, 설명은 한국어 | 호출 식별자이므로 번역 불가. 기존 문서 스타일과 일치 |
| 5 | 삭제 경로 — 안내문 잔류? | 잔류 + "미설치 시 무시" 명시. 제거는 업그레이드 경로(F2.1)에서 | 안내문은 무해하고, 자동 정리는 감지 오탐 위험 |
| 6 | 일반 "외부 통합 규약"으로 승격? | **보류** — `integrations.<name>` 스키마 자체가 일반 메커니즘. 규약 문서는 두 번째 통합(multi-model-consult) 구현 시 패턴이 2개 모이면 일반화 | 선례 1개로 규약화하면 추측 설계가 됨 |

추가 결정:
- **F2.2 버전 호환 매트릭스 폐기** → F1.7 스킬 실존 검증으로 대체 (이름 드리프트를 직접 잡음)
- **옵트아웃 표현**: `enabled: false` 저장 대신 **필드 생략** (eslintAssist 선례와 일관 — 생략 = 미적용 = 하위 호환)
- 초안 § 5.3의 `agents/red-green-refactor.md` 참조는 오류였음 — 실제 코어 TDD 산출물은 `.claude/rules/session-routine.md` + `agents/` 7종

---

## 12. 참고 자료

- **superpowers**: https://github.com/obra/superpowers — v5.1.0, 스킬 14종 (2026-06-12 확인)
  - 설치: `/plugin install superpowers@claude-plugins-official`
  - 스킬 전체: brainstorming, dispatching-parallel-agents, executing-plans, finishing-a-development-branch, receiving-code-review, requesting-code-review, subagent-driven-development, systematic-debugging, test-driven-development, using-git-worktrees, using-superpowers, verification-before-completion, writing-plans, writing-skills
- 본 저장소: `references/project-context.md` § 설계 결정, `references/versioning-policy.md` (integrations 필드 = MINOR), `.tracking/prd-multi-model-consult.md` (후속 통합 사례)
- 선행 논의: 2026-05-09 세션 — 옵트인 통합·코어 겹침 제외 방향 합의
