# 하네스 구성 체크리스트

> 하네스가 "제대로 돌아간다"의 판정 기준을 기계적으로 점검하는 문서.
> 기준: Anthropic(Initializer + Coding Agent 패턴) + OpenAI(3기둥) 통합.
> 각 항목은 ✅/❌로 판정 가능해야 하며, 애매하면 "검증 방법"을 따른다.
>
> **소비자**: `harness-scaffold/SKILL.md` § 6 (Phase 3 검증 항목 대응), § 7 (Phase 4 단계 판정 문구),
> `templates/harness-check.sh` (§ 8 빠른 자가진단의 구현)

---

## 0. 판정 원칙

하네스가 돌아간다 = 아래 4가지 질문에 모두 "예"라고 답할 수 있는 상태.

| # | 질문 | 대응 기둥 |
|---|------|----------|
| Q1 | 에이전트가 컨텍스트 없이 시작해도 5분 내에 다음 작업을 파악하는가? | 컨텍스트 엔지니어링 |
| Q2 | 에이전트가 잘못된 구조의 코드를 만들면 기계가 막는가? | 아키텍처 제약 |
| Q3 | 에이전트가 자기 작업을 스스로 검증하고 수정할 수 있는가? | 실행-검증 루프 |
| Q4 | 2주 뒤에도 문서와 코드 품질이 유지되는가? | 엔트로피 관리 |

---

## 1. 컨텍스트 요소 (에이전트가 읽는 것)

### 1.1 필수 파일 존재

- [ ] `AGENTS.md` — 입구 문서, 100줄 이내
- [ ] `ARCHITECTURE.md` — 구조 원칙 문서
- [ ] `claude-progress.txt` — 세션 간 진행 기록
- [ ] `feature_list.json` — 기능 목록 + passes 상태
- [ ] `.harness-friction.jsonl` — 마찰 자동 기록 싱크 (append-only JSONL, manifest category `data`)
- [ ] `init.sh` — 환경 초기화 스크립트
- [ ] `docs/` — 하위 문서 디렉토리 (exec-plans, QUALITY_SCORE, TECH_DEBT)

**검증 방법**: `ls AGENTS.md ARCHITECTURE.md claude-progress.txt feature_list.json .harness-friction.jsonl init.sh docs/`

### 1.2 AGENTS.md 품질 규칙

- [ ] 100줄 이내인가 (`wc -l AGENTS.md`)
- [ ] 백과사전이 아니라 **목차** 역할인가 (상세 내용은 링크로 위임)
- [ ] 프로젝트 한 줄 설명 + 스택이 첫 화면에 있는가
- [ ] 의존성 방향이 한 줄로 요약되어 있는가
- [ ] 문서 맵 테이블이 있고, 모든 경로가 실제 파일과 일치하는가
- [ ] 테스트/개발 서버 실행 명령이 명시되어 있는가
- [ ] 플레이스홀더(TODO, TBD)가 없는가

### 1.3 단일 진실 원천(SSoT) 규칙

- [ ] 에이전트 작업에 필요한 모든 정보가 **저장소 안에** 있는가
- [ ] Slack/Docs/머릿속에만 있는 규칙이 없는가 (있다면 문서로 승격)
- [ ] 같은 정보가 두 문서에 중복 기술되어 있지 않은가 (한 곳 + 링크)

---

## 2. 상태 추적 요소 (에이전트가 쓰는 것)

### 2.1 feature_list.json 규칙

- [ ] valid JSON인가 (`node -e "JSON.parse(...)"`)
- [ ] 각 기능에 `id / description / steps / passes / priority`가 있는가
- [ ] steps가 **사람이 따라할 수 있는 검증 절차**인가 (추상적 설명 금지)
- [ ] passes는 실제 검증 후에만 true로 변경된다는 규칙이 문서화되어 있는가
- [ ] 에이전트의 기능 삭제/설명 수정 금지 규칙이 AGENTS.md에 있는가

### 2.2 claude-progress.txt 규칙

- [ ] 매 세션 종료 시 갱신되는가 (마지막 수정일 확인)
- [ ] "무엇을 했고, 다음에 뭘 해야 하는지"가 기록되는가
- [ ] git log와 함께 읽으면 프로젝트 이력이 재구성되는가

### 2.3 git 규칙

- [ ] 세션 종료 시 빌드 가능한 상태로 커밋하는 규칙이 있는가
- [ ] 커밋 메시지에 기능 ID가 연결되는가 (예: `feat: ... - F001`)

---

## 3. 아키텍처 제약 (기계가 강제하는 것)

### 3.1 규칙 정의

- [ ] 아키텍처 유형이 분류되어 있는가 (layer-based / fsd / domain-based / custom)
- [ ] 의존성 방향이 명시되어 있는가 (어떤 폴더가 무엇을 import 가능한지)
- [ ] 폴더별 책임이 테이블로 정리되어 있는가
- [ ] 네이밍 규칙이 있는가 (컴포넌트/훅/서비스/테스트)
- [ ] 레이어 규칙 외 추가 제약(extraRules)이 기록되어 있는가

### 3.2 규칙 강제 (문서 → 코드 승격)

- [ ] `scripts/structural-test.ts`가 존재하고 실행되는가 (`npx tsx scripts/structural-test.ts`)
- [ ] 의존성 역전 시 **exit 1로 빌드가 실패**하는가 (경고만으로 끝나지 않는가)
- [ ] 위반 출력에 파일/줄번호/위반 내용이 포함되는가
- [ ] ESLint에 보조 규칙이 있는가 (no-restricted-imports, max-lines 등)
- [ ] tsconfig paths(alias)가 레이어 구조를 반영하는가

### 3.3 승격 루프

- [ ] "리뷰에서 2번 이상 반복된 지적"을 자동 검사로 승격하는 절차가 있는가
- [ ] 문서에만 있고 검사기가 없는 규칙 목록을 알고 있는가 (= 승격 대기 큐)

---

## 4. 실행-검증 루프 (에이전트가 스스로 확인하는 것)

### 4.1 검증 명령 통일

- [ ] `npm run validate` 한 줄로 전체 검증이 실행되는가
- [ ] validate = typecheck + lint + lint:arch + test 조합인가 (있는 것만 조합)
- [ ] 검증 실패 시 에이전트가 읽을 수 있는 에러를 출력하는가

### 4.2 검증 레벨 구성

- [ ] Level 1 정적: typecheck + lint + 아키텍처 검사 (즉시)
- [ ] Level 2 유닛: 컴포넌트/훅/서비스 테스트 (수초)
- [ ] Level 3 통합: API mock + 페이지 단위 (수십초)
- [ ] Level 4 E2E: 브라우저 자동화로 실제 시나리오 재현 (수분)
- [ ] (e2e 옵트인 시) `playwright.config.ts` + `e2e/` 스캐폴드 존재 — harness-setup E2E 모듈(§ 5.17)이 생성. 구조만 보장하며 스위트 통과(의미)는 앱별 부팅에 의존
- [ ] feature_list의 steps가 E2E 테스트와 1:1로 매핑 가능한가
- [ ] (e2e 옵트인 시) E2E가 TDD 사이클에 배선됨 — RED(Test Engineer)가 `@feature:{ID}` 태그로 작성, VERIFY(E2E)(session-routine Phase 4.7)가 해당 feature 스펙 실행, Debugger가 브라우저 재현. L4의 구현 경로(harness-setup 증분 2a)
- (1.14.0, 증분 2b) `@critical` 태그 E2E의 **cross-feature 회귀**는 옵트인 pre-push 게이트(`.githooks/pre-push`)가 push 시점에 강제한다 (`validate` → `@critical`). per-feature VERIFY(Phase 4.7)와 분리된 마지막 방어선이며, 활성화는 수동(`git config core.hooksPath`)이다. CI 부재 환경에서 "안 보이는 테스트" 방치를 막는 강제 경로.
- (옵트인 `e2e.mcp`) 스펙 없는 UI 증상은 debugger가 브라우저 MCP(`@playwright/mcp`)로 탐색 진단 — known `.e2e.ts` 실패는 러너가 정본(MCP 비사용).
- (1.16.0, TODO-99) E2E 작성 트리거가 "UI 상호작용 **또는 시각/레이아웃 회귀 위험**"으로 확장 — jsdom(L2)이 못 잡는 오버플로·정렬·스크롤·넘침 회귀는 상호작용이 없어도 E2E 대상(test-engineer.md). 브라우저 육안 1회 확인은 회귀 가드가 아니며 `.e2e.ts`로 코드화한다(session-routine 완료 게이트).
- (1.17.0, 증분 4) e2e 옵트인 시 `e2e/README.md`(사람 개발자용 작성 가이드, managed)가 생성된다 — 무엇/언제·`e2e/` 레이아웃·fixtures·셀렉터/태그·시각/레이아웃 회귀 트리거·실행을 정본(coding-standards·session-routine·test-engineer·debugger) 참조와 함께 안내한다(에이전트-규칙 내용 비복제).

### 4.3 환경 재현성

- [ ] `init.sh` 실행만으로 개발 서버가 뜨는가
- [ ] 서버 준비 확인(readyCheck)이 포함되어 있는가
- [ ] 새 환경(클린 클론)에서 init.sh → validate가 통과하는가

---

## 5. 세션 루틴 (에이전트가 따르는 절차)

### 5.1 세션 시작 절차가 문서화되어 있는가

- [ ] ① progress 읽기 → ② git log 확인 → ③ 환경 기동 → ④ 기존 기능 무결성 체크 → ⑤ 다음 기능 선택
- [ ] "기존 버그 발견 시 새 기능보다 우선" 규칙이 있는가
- [ ] "한 번에 하나의 기능만" 규칙이 있는가

### 5.2 세션 종료 절차가 문서화되어 있는가

- [ ] ① validate 통과 → ② 실동작 확인 → ③ feature_list 갱신 → ④ progress 기록 → ⑤ commit
- [ ] "검증 없이 passes를 true로 바꾸지 않는다" 규칙이 있는가
- [ ] "빌드 불가능한 상태로 세션을 끝내지 않는다" 규칙이 있는가

### 5.3 실패 패턴 방어 (Anthropic 4대 실패)

- [ ] 원샷 시도 방지: 기능 단위 분해 + 우선순위가 있는가
- [ ] 조기 완료 선언 방지: passes 기준이 "전체 steps 통과"로 정의되는가
- [ ] 검증 없는 완료 방지: E2E/실동작 확인이 종료 절차에 포함되는가
- [ ] 환경 파악 낭비 방지: 시작 절차가 5분 내에 끝나는가

---

## 6. 엔트로피 관리 (시간이 지나도 유지되는가)

### 6.1 문서 부식 방지

- [ ] `scripts/doc-freshness.ts`가 존재하고 오래된 문서를 경고하는가
- [ ] AGENTS.md/ARCHITECTURE.md가 실제 구조와 일치하는지 검사하는 주기가 있는가
- [ ] feature_list의 passes가 실제 동작과 일치하는지 재검증 주기가 있는가

### 6.2 품질/부채 가시화

- [ ] `docs/QUALITY_SCORE.md` — 카테고리별 점수 + 측정 기준이 있는가
- [ ] `docs/TECH_DEBT.md` — 긴급/높음/보통 분류 + 리팩터링 대상 테이블이 있는가
- [ ] 에이전트가 이 문서를 읽고 "다음에 뭘 개선할지" 판단 가능한가

### 6.3 운영 사이클

- [ ] 일간: validate (CI 자동)
- [ ] 주간: 문서 최신성 + QUALITY_SCORE 갱신
- [ ] 격주: TECH_DEBT 검토 + 리팩터링 세션
- [ ] 월간: AGENTS.md / ARCHITECTURE.md 전면 검토

---

## 7. 최소 구성 vs 완전 구성

모든 항목이 처음부터 필요한 건 아니다. 단계별 기준:

| 단계 | 필수 범위 | 판정 |
|------|----------|------|
| **MVH (최소 하네스)** | §1.1, §2.1~2.3, §4.1, §5.1~5.2 | 에이전트가 세션을 이어갈 수 있다 |
| **표준 하네스** | MVH + §3 전체 + §4.2~4.3 | 구조 위반이 기계적으로 차단된다 |
| **운영 하네스** | 표준 + §6 전체 | 2주 뒤에도 품질이 유지된다 |

harness-setup 스킬의 현재 스캐폴딩 범위는 **표준 하네스**까지 커버하고,
§6.3 운영 사이클은 사용자/Cleanup Agent의 몫이다.

> **판정의 범위 — "구조" vs "의미"**: 이 단계 판정(특히 "표준 하네스 가동")은
> *구조적 설치(필수 파일·스크립트·훅의 존재)와 기계적 실행 가능성(검증 명령이 정상 exit code를 냄)*을 확인한다.
> 생성된 문서가 프로젝트를 사실대로 기술하는지, `structural-test`의 의존성 규칙이 실제 아키텍처를 옳게 반영하는지,
> `feature_list`의 상태가 진짜인지 등 **내용의 의미 정확성(semantic correctness)은 판정 대상이 아니다**.
> 의미 정확성은 셋업 시 사용자 승인·검토와 운영 중 마찰 루프(`docs/HARNESS_FRICTION.md`)로 교정한다.
> 따라서 "표준 하네스 가동"은 *"하네스가 설치되고 돈다"*는 뜻이지 *"이 프로젝트에 대해 규칙이 옳다"*는 보장이 아니다.

> **Q2 강제 전제**: "표준 하네스"는 § 3.2(규칙 강제)가 충족돼야 한다 — structural-test가 실질 검사 규칙을 가져야 한다.
> custom/빈 규칙으로 structural-test가 아무것도 막지 못하면(Q2 미강제) § 3.2 미충족이므로 **MVH로 강등**된다
> (harness:check ④-b가 생성 스크립트의 `HARNESS:Q2_ENFORCEMENT` 마커로 감지, exit 0 경고).
> 자유 구조 프로젝트의 정당한 약한 상태이며, 검사 규칙을 추가하면 표준으로 승격된다.

---

## 8. 빠른 자가진단 (5분 버전)

```bash
# 1. 필수 파일
ls AGENTS.md ARCHITECTURE.md claude-progress.txt feature_list.json init.sh

# 2. AGENTS.md 100줄 제한
wc -l AGENTS.md

# 3. JSON 유효성
node -e "JSON.parse(require('fs').readFileSync('feature_list.json','utf8')); console.log('OK')"

# 4. 아키텍처 검사 동작
npx tsx scripts/structural-test.ts

# 5. 통합 검증
npm run validate

# 6. 문서 최신성
npx tsx scripts/doc-freshness.ts
```

6개 명령이 모두 통과하면 **표준 하네스 가동 중**으로 판정한다.

> 생성된 하네스에서는 위 6개 명령이 `npm run harness:check` 하나로 통합되어 있다
> (`scripts/harness-check.sh` — tsconfig paths 검사 + E2E 스캐폴드 구조(⑧) 포함 8항목).
