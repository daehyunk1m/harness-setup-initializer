# 설계: Intent Ledger — Phase 1 수집 인프라 (이슈 #15)

> 작성일: 2026-06-17
> 상태: 설계 확정 (spec 작성 — 사용자 검토 → writing-plans)
> 이슈: #15 feat: 제품 의도(intended/unintended) 수집 → PRD·E2E 증류 파이프라인 (intent ledger)
> 스코프: **Phase 1 (수집)만**. 증류·추적·PRD 바인딩은 명시적 비-스코프(§12, Phase 2)
> 자매 채널: friction(`.harness-friction.jsonl` → harness-feedback, #9/#14) — 같은 인프라, 다른 페이로드

---

## 1. 문제

대화 중 사용자가 자연어로 주는 **제품 의도**(intended: "각 날의 태스크만 집계돼야 한다")와 **오작동 관찰**(unintended: "파이차트에 someday가 섞인다")이 현재 **세 군데에 흩어져** 휘발한다 — `claude-progress.txt`의 `요구:` 줄, git 커밋 메시지, `feature_list.json`의 description/steps. 한 곳에서 "이 의도가 PRD에 반영됐나? E2E로 커버되나?"를 점검할 단일 원장이 없어, 의도가 명세(PRD)·회귀 가드(E2E)로 승격되지 못하고 같은 클래스의 버그가 재발한다.

**근거 사례 — HAJA F007(진행률 파이차트)**: "각 날만 집계 / someday 제외" 의도가 PRD·E2E 어디에도 박히지 않아 someday 누수 버그가 약 2개월 생존했다. 결정적 관찰 — 이 버그는 유닛 통과·구현 재시도 0·리뷰 무사통과로 **프로세스 마찰(friction)을 0으로 통과**했다. friction 채널은 이 버그 클래스를 구조적으로 못 잡는다. 순수 제품-의도 갭이기 때문이다 → 별도 채널이 필요한 정확한 근거.

마찰 인프라(#9 기록 + #14 보고 트리거)는 *프로세스 마찰*의 `대화 → 영속 원장 → 주기적 증류` 파이프라인을 이미 완성했다. 이 설계는 그 **자매 채널**로 *제품 의도*에 같은 아키텍처를 적용하되, Phase 1에서는 **입력단(수집)**만 배선한다.

## 2. 목표 / 비목표

**목표**
- 세션 종료 시 그 세션의 제품 의도/오작동 발화를 `.harness-intent.jsonl`(append-only, git 추적)에 0줄 이상 적재한다.
- friction의 검증된 저수준 기계(SESSION_ID·소독·append·`data` 카테고리·git 전략)를 **의도적으로 동일하게** 재사용해 두 채널의 유지보수가 갈라지지 않게 한다.
- Phase 2a(intent-distill)가 스키마 마이그레이션 없이 커버리지를 실구조에서 파생하도록 원장 스키마를 처음부터 안정화한다(`encoded`는 비권위 capture-time 스냅샷 — distill은 갱신하지 않는다).
- friction 채널과 **분리 운영** — `unintended`(제품 버그 관찰)가 friction 이벤트와 혼선되지 않는다.

**비목표 (Phase 2로 이월)**
- PRD diff 제안, E2E 백로그 생성. (intent-distill은 Phase 2a에서 배선됨 — encoded는 비권위 capture-time 스냅샷이라 갱신 안 함.)
- 의도 ↔ `feature_list.steps` ↔ `@feature:{id}` ↔ PRD 섹션 양방향 추적, 커버리지 리포트.
- 매핑에서 발견한 **PRD 출력단 갭** 해소(빈 `docs/product-specs/`·`feature_list.id→PRD` 링크 필드 부재 — §12.1).

**비목표 (영구)**
- Stop hook 자동 캡처 (무-훅·에이전트 주도 원칙 유지, 노이즈 위험).
- 중간세션 실시간 적재 (의도 발화는 결정론적 트리거 지점이 없음 — §3 D1).
- 프로필 스키마 변경 (always-on이라 신규 프로필 필드 0 — §7).

## 3. 핵심 설계 결정

| ID | 결정 | 선택 | 근거 |
|----|------|------|------|
| D1 | 적재 주체/시점 | **세션 종료 배치 (오케스트레이터)** | friction은 기계적 트리거(재시도/리뷰실패)에서 즉시 기록하나, "의도 발화"는 의미적 사건이라 결정론적 트리거 지점이 없다. 세션 종료 시 `요구:` 줄 + 오작동 발화를 1회 증류 → 노이즈 최소·훅 불필요·결정론적 단일 지점. claude-progress가 이미 `요구:`를 쓰므로 파생이지 중복작성 아님. (실시간/Stop훅 기각.) |
| D2 | 활성화 | **always-on (friction 병렬)** | 프로필 플래그 없음. friction이 process friction을 무조건 기록하듯 product intent도 보편적. 의도 없는 세션은 0줄(graceful)이라 부담 0. 프로필 스키마·게이팅·scaffold 분기 추가를 피하고 friction과 대칭. |
| D3 | 레코드 스키마 | **`{ts, session, kind, surface, feature, statement, encoded}`** | friction의 `ts/session/feature`·소독·append를 상속. `event`+`severity` 자리를 `kind`+`surface`로 치환(의도 채널 의미), `detail`(≤50)을 `statement`(≤200)로 확장 — 의도는 부차가 아니라 **주 페이로드**. |
| D4 | `encoded` 필드 | **지금 포함, Phase 1 항상 all-false** | 원장이 git 추적 PRD 근거라 스키마 안정성에 가치. `encoded`는 비권위 capture-time 스냅샷 — Phase 2a(intent-distill)는 커버리지를 실구조에서 파생하며 encoded를 갱신하지 않는다(derived-live, 멀티모델 자문 반영). 비용은 항상 같은 dead 값 1개. |
| D5 | `unintended` ↔ friction 경계 | **직교 (프로세스 vs 제품)** | friction = TDD 기계가 저항(재시도/리뷰실패/E2E실패/롤백). intent(unintended) = 제품이 무엇을 해야 하는지에 대한 진술. F007처럼 한 버그가 프로세스 마찰 0으로 통과 가능 → 겹치지 않음. 한 버그가 둘 다 유발하면 각자 다른 면을 기록(중복 아님 — 다른 싱크·다른 분석기). |
| D6 | 위치 | **`.harness-intent.jsonl` (프로젝트 루트)** | friction 대칭. `data` 카테고리, cursor·scaffold 단계·검증이 모두 루트 배치를 전제. 정적 참조 doc만 `docs/INTENT_LEDGER.md`(HARNESS_FRICTION.md 평행). |

## 4. 구성요소

### 4.1 `.harness-intent.jsonl` (신규 `data` 싱크)

- **위치**: 프로젝트 루트. **형식**: append-only JSON Lines, 1줄 = 1 의도.
  ```json
  {"ts":"2026-06-17T04:30:00Z","session":"2026-06-17T04-12-03Z-a3f9","kind":"intended","surface":"progress","feature":"F007","statement":"진행률 파이차트는 각 날의 태스크만 집계하고 someday는 제외한다","encoded":{"prd":false,"e2e":false,"test":false}}
  ```
- **필드**:
  | 필드 | 값 | 비고 |
  |------|----|------|
  | `ts` | ISO8601 UTC | friction과 동일 |
  | `session` | SESSION_ID | friction과 **동일 값 공유**(claude-progress.txt `SESSION_ID:` 줄, Step 1.5) |
  | `kind` | `intended` \| `unintended` | friction `event` 자리. intended=원하는 동작 진술, unintended=오작동 관찰 |
  | `surface` | 영역 태그(kebab, 예: `progress`, `section-expand`) | friction `severity` 자리. Phase 2 grouping용. 자유 소문자 |
  | `feature` | 관련 feature ID 또는 `""` | friction과 동일 |
  | `statement` | 소독된 의도 한 줄, **≤200자** | friction `detail`(≤50) 자리. 주 페이로드라 확장 |
  | `encoded` | `{"prd":false,"e2e":false,"test":false}` | 승격 상태. **Phase 1 항상 all-false**(D4). 비권위 capture-time 스냅샷 — distill은 갱신하지 않는다(derived-live) |
- **카테고리**: `data` (feature_list.json·.harness-friction.jsonl·.harness-feedback-cursor와 동급, §5.13·§10.1) — 커밋되어 살아남고, 템플릿 해시 드리프트 검사 제외, 업그레이드 시 덮어쓰지 않음.
- **git 추적**: `.gitignore` 미추가. git-workflow.md 커밋 규칙에 따라 적재 시 커밋(friction과 동일).
- **빈 파일 초기화**: 분석기가 파일 부재와 0건을 구분하도록 빈 줄 없이 생성(친 채널과 동일 — §4.4).

### 4.2 `templates/rules/session-routine.md` (managed 템플릿 편집)

**(a) 세션 종료 루틴 — Step 4.2 「의도 적재」 삽입**
- 위치: `§ 세션 종료`의 Step 4(TDD STATE 저장 + `session-incomplete` 마찰 기록) 블록 **후**, 기존 `4.5 피드백 보고 트리거` **전**. (4.5는 재번호하지 않음 — #14 트리거 참조 정합 보존.)
- 동작:
  1. 그 세션의 `claude-progress.txt` `요구:` 줄 + 세션 중 사용자의 오작동 발화를 수집한다.
  2. 각 의도를 1줄로 증류 — `kind`(intended/unintended) 분류, `surface` 태그, 관련 `feature` 결부(없으면 `""`).
  3. `statement`를 소독(§ 의도 로그 규칙)하고 `encoded`는 all-false로 고정.
  4. friction과 동일 SESSION_ID로 `echo '{...}' >> .harness-intent.jsonl` append.
  5. 제품 의도 발화가 없으면 **0줄**(graceful, 에러 아님). 같은 statement는 세션 내 1회만.
- **신규 `{{...}}` 플레이스홀더 없음** — 모든 텍스트 정적(경로·스키마 리터럴). 치환 규칙 테이블(§5.11.3) 변경 불필요.

**(b) 신규 `§ 의도 로그` 서브섹션 (기존 `§ 마찰 로그`와 평행)**
- 스키마 정의(§4.1 필드표), `kind` enum 의미, `surface` 태깅 가이드.
- **소독 규칙**(friction 상속): 따옴표 `"`→`'`, 개행/CR→공백, 백슬래시 제거, **≤200자 절단**(friction은 ≤50 — 유일한 수치 차이).
- **friction 경계 규칙**(D5): 프로세스 마찰은 `§ 마찰 로그`로, 제품 의도/오작동 관찰은 `§ 의도 로그`로. 판별 기준 명시.
- `encoded` 항상 all-false 규칙(Phase 2 표지).

### 4.3 `templates/INTENT_LEDGER.md` (신규 managed 템플릿, 정적·비치환) → `docs/INTENT_LEDGER.md`

- `HARNESS_FRICTION.md`(§5.12)와 평행한 **정적 참조 문서**(플레이스홀더 없음, 그대로 복사 생성).
- 담는 내용: 스키마 참조표, `kind` enum(intended/unintended) 정의, `surface` 태그 가이드, **friction-경계 설명**, `.harness-intent.jsonl` 포인터, `encoded`에 대한 "비권위 capture-time 스냅샷 — distill 미갱신(derived-live)" 주석.
- doc-freshness(§5.7)는 HARNESS_FRICTION.md와 **동일 취급**(이벤트-로그 인접 정적 참조 — staleness 제외 또는 동일 분류).

### 4.4 `harness-scaffold/SKILL.md` (정규 사양 편집)

- **§5 생성 순서**: friction(17=doc, 17-b=sink, 17-c=cursor) 패턴을 미러링 —
  - **17-d**: `docs/INTENT_LEDGER.md` (정적 참조 — 신규 §5.12.3)
  - **17-e**: `.harness-intent.jsonl` (빈 싱크 — 신규 §5.12.4, `: > .harness-intent.jsonl`)
  - 둘 다 18(package.json) 전. cursor(`.harness-intent-cursor`)는 소비자(Phase 2 distill)가 없으므로 Phase 1에 **생성하지 않음**.
- **§5.13 manifest**: `.harness-intent.jsonl`(category=`data`) + `docs/INTENT_LEDGER.md`(category=`managed`) 파일 엔트리 추가. §5.13·§10.1 data 파일 목록 행에 `.harness-intent.jsonl` 추가. **프로필 스냅샷 변경 없음**(D2).
- **§6 Phase 3 검증**: 친 채널 확인 라인(§6.2 `ls -la docs/ docs/HARNESS_FRICTION.md .harness-friction.jsonl`)에 `docs/INTENT_LEDGER.md .harness-intent.jsonl` 추가.
- **§7 능력 게이팅 (중요)**: always-on이므로 능력 라인 **무조건 표시**. 의도 적재(수집) + 의도 증류(intent-distill 번들 스킬) 모두 광고한다 — intent-distill이 Phase 2a에서 배선됨. `encoded`는 비권위 capture-time 스냅샷이라 distill이 갱신하지 않음(derived-live, 멀티모델 자문 반영).
- **(선택) 생성 CLAUDE.md/AGENTS.md 포인터**: friction이 §5.1.1에 "`.harness-friction.jsonl`에 append" 1줄을 두듯, 의도 적재 1줄 포인터를 평행 추가할 수 있다(수집만 — session-routine이 권위 정본).

### 4.5 검증 배선 (harness-check.sh / harness-checklist.md)

- `harness-check.sh`(§5.14) + `harness-checklist.md`(§8): **friction 싱크 체크와 동일 패턴**으로 `.harness-intent.jsonl` 존재 + session-routine `§ 의도 로그` 규칙 상주를 확인. friction이 체크되는 만큼만 추가(비대칭 금지).

## 5. 데이터 흐름

```
[세션 중]   사용자 의도/오작동 발화 → claude-progress.txt '요구:' 줄 (기존, 변경 없음)
[세션 종료] Step 4.2 「의도 적재」: '요구:' 줄 + 오작동 발화를 N줄(0+)로 증류
              → kind/surface/feature 분류 + 소독(friction 규칙) + encoded all-false
              → echo '{...}' >> .harness-intent.jsonl   (friction과 동일 SESSION_ID)
[영속]      git 추적 (PRD 근거 누적). encoded는 비권위 스냅샷 — distill이 갱신 안 함(derived-live).
[Phase 2a]  intent-distill → .harness-intent.jsonl ↔ @feature E2E 대조 → docs/INTENT_BACKLOG.md 커버리지 동기화("의도 정리")
```

의도 없는 세션 → 0줄(graceful). friction의 "종료 시 1회 기록" 패턴과 동형.

## 6. friction 대비 재사용 / 차이

| 항목 | friction | intent | |
|------|----------|--------|---|
| 싱크 위치·빈 초기화 | 루트, `: >` | 동일 | ♻️ |
| SESSION_ID | claude-progress Step 1.5 | **동일 값 공유** | ♻️ |
| 소독 | 따옴표/개행/백슬래시 | 동일 + 길이 ≤200 | ♻️/✏️ |
| append | Bash `echo >>` | 동일 | ♻️ |
| git / manifest | tracked / `data` | 동일 | ♻️ |
| 정적 참조 doc | HARNESS_FRICTION.md | INTENT_LEDGER.md | ♻️ |
| 페이로드 | `event`+`severity`+`detail`(≤50) | `kind`+`surface`+`statement`(≤200) | ✏️ |
| 추가 필드 | — | `encoded:{prd,e2e,test}` | ➕ |
| 적재 시점 | 기계적 트리거(즉시) | 세션 종료 배치 | ✏️ |
| cursor | `.harness-feedback-cursor` | (Phase 2까지 없음) | ⏸️ |

## 7. 계약·정합성 영향 (CLAUDE.md 개발 규칙)

- ✅ **프로필 계약 불변**: 신규 프로필 필드 0(D2) → SKILL.md §5 프로필 출력 ≡ harness-scaffold §4 프로필 입력 계약 그대로.
- ✅ **치환 규칙 불변**: 신규 `{{...}}` 0(§4.2 정적, §4.3 비치환).
- ✅ **생성 순서 안전**: 17-d/17-e는 무의존(빈 싱크·정적 복사); session-routine 규칙은 런타임에 경로 참조(생성시점 결합 없음).
- ✅ **hooks 영향 없음**: Stop hook 미사용.
- ✅ **프로필 스키마 동기화 불요**: 두 SKILL.md의 프로필 스키마 동일성 계약이 변경 없이 유지.

## 8. degradation / 엣지 케이스

| 상황 | 처리 |
|------|------|
| 제품 의도 발화 없는 세션 | 0줄 적재 (정상) |
| `.harness-intent.jsonl` 부재(비-하네스 환경) | Step 4.2 스킵 (에러 아님 — friction과 동일 graceful) |
| `statement` 200자 초과 | 절단 (소독 규칙) |
| statement에 따옴표/개행 | 소독(`'`/공백) — friction 규칙 상속 |
| 한 발화가 의도+마찰 동시 유발 | 각 싱크에 각자 기록(직교, D5) — 중복 아님 |
| 업그레이드 직후 첫 세션 | 빈 싱크 신규 생성 + 그 세션부터 적재(과거 소급 없음 — 의도) |
| 같은 의도 반복 발화 | 세션 내 1회만(중복 방지) |

## 9. 버전 / 마이그레이션

- 신규 `data` 싱크 + 정적 참조 doc(managed) + session-routine(managed) 행동 추가 + scaffold 생성 규칙. 기존 호환(가산). **MINOR: 1.23.0 → 1.24.0**.
- 범프 동시 대상(CLAUDE.md 버전 정책): `project-context.md`, `.tracking/CHANGELOG.md`, `.claude-plugin/plugin.json`, `marketplace.json`, `README.md` 버전 줄, `git tag`.
- **마이그레이션 불필요**: 프로필 변경 없어 업그레이드는 순수 가산(싱크 생성 + session-routine `§ 의도 로그` 추가 + INTENT_LEDGER.md 생성). managed(session-routine·doc) 변경은 §12.6 자동 감지로 전파. 과거 세션 소급 적재 없음.

## 10. 검증 계획

- **session-routine 적재 규칙**(픽스처/리뷰): `요구:` 줄 N개 → N줄 적재 / 의도 없는 세션 → 0줄 / statement 200자 절단 / 소독(따옴표·개행) / 동일 SESSION_ID 공유 / 세션 내 중복 1회 / `.harness-intent.jsonl` 부재 시 스킵.
- **scaffold 생성**: 빈 싱크 생성(빈 줄 없음) / INTENT_LEDGER.md 정적 복사 / manifest에 `data`·`managed` 등록 / 프로필 스냅샷 불변 / §6 검증 라인 통과.
- **능력 게이팅**: §7 능력 라인이 수집(적재) + 증류(intent-distill)를 광고 검증.
- **계약 회귀**: SKILL.md §5 ≡ harness-scaffold §4 프로필 스키마 동일성 / 신규 플레이스홀더 0 / 골든 픽스처(`test/run-fixtures.sh`) 무영향(structural-test 템플릿 미변경).
- **업그레이드**: 기존 하네스(intent 없음) 업그레이드 → 가산 배선, 프로필 불변 확인.

## 11. 수용 기준

- [ ] 세션 종료 시 제품 의도/오작동이 `.harness-intent.jsonl`에 0+줄 적재된다(의도 없으면 0줄).
- [ ] 레코드가 7-필드 스키마(`ts/session/kind/surface/feature/statement/encoded`)를 준수하고 friction과 동일 SESSION_ID·소독을 공유한다.
- [ ] `encoded`는 Phase 1에서 항상 all-false다.
- [ ] friction 채널과 분리 운영된다(`unintended` ↔ friction 이벤트 혼선 없음, 경계 규칙 문서화).
- [ ] scaffold가 빈 싱크 + `INTENT_LEDGER.md`를 생성하고 manifest에 등록한다(프로필 스냅샷 불변).
- [ ] §7 능력 안내가 수집(적재) + 증류(intent-distill)를 광고한다.
- [ ] 업그레이드 시 기존 하네스에 가산 배선된다(프로필 변경 없음).
- [ ] 신규 `{{...}}` 0, 두 SKILL.md 프로필 스키마 동일성 계약 유지.

## 12. 명시적 비-스코프 (Phase 2)

PRD diff 제안 · E2E 백로그 생성 · `encoded` 갱신(비권위 스냅샷이라 distill 미갱신 — derived-live) · `.harness-intent-cursor` · 의도↔`feature_list.steps`↔`@feature:{id}`↔PRD 양방향 추적 · 커버리지 리포트 · 월간 사이클 「의도 증류」(M3.5) 편입.
(intent-distill 분석 스킬은 Phase 2a에서 배선됨 — 이 비-스코프에서 제외.)

### 12.1 발견: PRD 출력단 갭 (Phase 2가 함께 해소)

컨텍스트 매핑에서 확인 — 이슈의 "출력단(PRD/E2E)은 사실상 완비" 전제는 절반만 맞다:
- ✅ `feature_list.id ↔ @feature:{id} ↔ E2E` 추적은 실재·동작(coding-standards.md steps↔L4 E2E 1:1 매핑, test-engineer `@feature` 태그, Phase 4.7 VERIFY `--grep @feature:{id}`).
- ❌ **PRD 쪽은 미완비**: `docs/product-specs/`·`docs/design-docs/`는 scaffold가 **빈 디렉토리**로만 생성(내용 템플릿 없음), `feature_list.id → PRD 섹션`을 잇는 **필드/규약 부재**(파일명 관례만 암묵적). 이슈가 원하는 *"의도 ↔ PRD 섹션"* 바인딩은 단순 배선 갭이 아니라 **빠진 프리미티브**다.

→ Phase 2 추적 단계는 `feature_list`에 `prd_section_ref` 필드 추가 + (선택) PRD 섹션 템플릿 생성을 함께 다뤄야 한다. Phase 1은 이를 건드리지 않는다.

---

## 참고
- 이슈 #15 (이 설계의 출처), 자매 이슈 #9(마찰 자동 기록)·#14(보고 트리거)·#12(E2E 계층)
- 자매 spec: `docs/superpowers/specs/2026-06-17-feedback-report-trigger-design.md`(#14), `.tracking/specs/2026-06-16-friction-auto-logging-design.md`(#9)
- 친 채널 현행: `templates/rules/session-routine.md § 마찰 로그`·`§ 세션 종료`, `templates/HARNESS_FRICTION.md`, `skills/harness-feedback/SKILL.md`
- scaffold 앵커: `harness-scaffold/SKILL.md` §5 생성순서(17~18)·§5.12~5.13·§7 능력 게이팅
- 컨텍스트 매핑 근거: 워크플로 `intent-ledger-context-map`(5개 하위 시스템 병렬 분석, 2026-06-17)
