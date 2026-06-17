# 설계: PRD Substrate — Phase 2b-1 (이슈 #15)

> 작성일: 2026-06-17
> 상태: 설계 확정 (spec 작성 — 사용자 검토 → writing-plans)
> 이슈: #15 Phase 2b (수집→증류→**추적** 중 추적의 출력단). Phase 1(수집)·2a(E2E 커버리지 증류)는 main 머지 완료(v1.24.0·v1.25.0).
> 스코프: **PRD substrate(구조·바인딩·템플릿·capability)만**. 의도↔PRD 커버리지 derive·미검증 명세 방향은 Phase 2b-2(fast-follow).
> 멀티모델 자문 2회: codex(결함)·gemini(대안/운영) 반영 — `.claude/artifacts/consult/codex-…11-15-21.md`·`gemini-…11-16-10.md`(1차: 접근법 결정), `codex-…11-29-49.md`·`gemini-…11-30-35.md`(2차: 확정 설계 리뷰).

---

## 1. 문제

이슈 #15는 `대화 → 영속 원장 → 주기적 증류`의 3단계 파이프라인이다. Phase 1(수집)·2a(증류)는 의도의 **E2E 커버리지**를 다뤘으나 **PRD 출력단은 비어 있다**:

- ❌ scaffold가 `docs/product-specs/`를 **빈 디렉토리**로만 생성(내용 템플릿·구조 없음 — harness-scaffold §5 생성순서 1번).
- ❌ `feature → PRD` 링크·PRD 섹션 ID/앵커 스킴 **부재**(파일명 관례만 암묵적).
- ✅ 반면 `feature_list.id ↔ @feature:{id} ↔ E2E` 추적은 **실재·동작**(coding-standards steps↔L4 E2E 1:1, test-engineer `@feature` 태그, distill grep derive).

즉 "의도 ↔ PRD" 바인딩은 단순 배선이 아니라 **빠진 프리미티브**다.

**근거 사례 — HAJA F007(진행률 파이차트)**: PRD가 "각 날의 태스크만 집계 / someday 제외"라는 **제외 규칙**을 한 번도 명세하지 않아 someday 누수 버그가 ~2개월 생존했다. 유닛 통과·리뷰 무사통과·프로세스 마찰 0으로 통과 — 순수 제품-의도 갭. PRD substrate의 가치 = 의도(특히 **엣지케이스 제외 규칙**)가 명세로 인코딩되는 장소를 만드는 것.

## 2. 목표 / 비목표

**목표 (2b-1)**
- `docs/product-specs/`를 빈 디렉토리에서 → **구조화·링크가능·스택비종속 PRD substrate**로 전환한다.
- feature↔PRD를 E2E와 **동일한 grep `@feature` 프리미티브**로 바인딩해, 2b-2의 derive가 가능한 기반을 만든다.
- F007류 버그(명세 안 된 제외 규칙)를 줄이는 템플릿 — **Out-of-Scope/Edge Cases 섹션을 구조적으로 강제**하고 빈칸 침묵 실패를 저-마찰로 방지한다.
- **always-on이므로 기존 하네스에도 소급 설치**된다(마이그레이션). 자립 가치를 위해 capability 광고 + 관례 선언을 포함하되 파이프라인 게이트는 추가하지 않는다.

**비목표 (Phase 2b-2 — fast-follow)**
- 의도↔PRD 커버리지 **derive**(5-상태 미러), "PRD에 있는데 의도 근거 없음"(미검증 명세) 방향, intent-distill의 PRD 방향 확장, `INTENT_BACKLOG.md` PRD 통합.
- harness-check의 **빈 섹션 감지**, **feature↔PRD 교차 derive**(PRD 없는 feature 경고), **마커 검증 경고**(파일명-마커 불일치·중복 마커·orphan/invalid-feature 마커), 8-상태 taxonomy.
- doc-freshness 글로빙(`product-specs/**`), binding index 파일(중복 PRD canonical override — feature_list 필드가 아님), Architect PRE-RED **강제** PRD 작성(게이트).

**비목표 (영구)**
- `feature_list.json` 스키마 변경(전방 `prd_section_ref` 필드 — §3 D8). always-on 프로필 필드 추가(§3 D8).
- Phase 1/2a 변경(원장 스키마·intent-distill·harness-feedback 불변).

## 3. 핵심 설계 결정 (멀티모델 자문 2회 반영)

| ID | 결정 | 선택 | 근거 (자문) |
|----|------|------|-------------|
| D1 | PRD 구조 | **per-feature 파일** `docs/product-specs/{featureID}-{slug}.md` | E2E 스펙 네이밍 미러. gemini 1차 — 단일 문서는 컨텍스트 낭비·머지 충돌, feature_list 인라인은 JSON 경직. 분리가 grep·수정 경계 최선. 파일명 slug는 **탐색 힌트이며 바인딩 권위 아님**(README 명시). |
| D2 | 바인딩 마커 | **whole-line 리터럴 `@feature:{id}`** — `grep -Rl -Fx "@feature:{id}" docs/product-specs/` | codex 2차 — `^@feature:{id}$` regex는 커스텀 ID의 메타문자(`.`/`+`/`[`)에서 깨짐. `-Fx`(리터럴·전체줄)는 ID 형식 무관·본문 인라인 오탐(`@feature:F007를 추가하세요`) 방어를 동시 달성. 위치는 무관(전체줄이면 충분) — 템플릿은 관례상 상단 배치. E2E의 리터럴 `@feature` 태그와 **규칙 대칭**(위치 제약만 다름: E2E=제목, PRD=전체줄). |
| D3 | PRD 템플릿 | **`_template.md`(managed, 정적, 자기충족)** — 섹션 앵커 + anti-blank 가이드 | codex·gemini 2차 합의 — 섹션 강제만으론 "Edge Cases 빈칸" 침묵 실패. **정적 섹션 앵커 주석**(`<!-- harness:section=… -->`, 2b-2 섹션 evidence 안정화, 비용 0) + **anti-blank 마이크로가이드 주석**(빈칸 금지·제외 없음도 근거와 함께). 자기충족이라 작성 시 README 불필요(gemini 병합 우려 해소). |
| D4 | README | **`docs/product-specs/README.md`(managed, 정적)** | gemini 1차 — 전체 조망 진입점. 디렉토리 관례(경로·네이밍·마커 규칙·slug=비권위)·feature_list 진입점 + **운영 노트**(intent-distill missing/partial → 해당 feature PRD Edge Cases/Acceptance 반영, 두 백로그 연결 — codex 2차). |
| D5 | scaffold 범위 | **빈 디렉토리 생성 → README + _template 생성으로 교체. per-feature stub pre-seed 안 함** | codex·gemini 합의 — 빈 stub은 "거짓 안정감"·"가짜 완료 clutter". PRD는 온디맨드 작성. (design-docs/exec-plans/references는 기존대로 빈 디렉토리 — 이슈 #15는 PRD=product-specs 범위.) |
| D6 | capability·관례 | **§7 카탈로그 1줄 + coding-standards에 관례 선언. 파이프라인 게이트 변경 0** | gemini 1차 — "연극" 방지엔 관례 광고 필수. gemini 2차 — 소프트 트리거(권고, 게이트 아님)를 관례 선언에 흡수. PRE-RED **강제**는 2b-2(검증 도구 없이 PRD 양산=환각 위험, gemini 1차). |
| D7 | harness-check | **managed substrate는 구조 검사 + 작성 PRD는 보류** — README+_template 부재=구조 실패(타 managed 파일과 동일, exit 1) / 작성 PRD(`{id}-{slug}.md`) 부재=보류(정보, 실패 아님) | E2E "판정 보류" 미러. codex 2차 — "필수 substrate 목록에 두 파일을 넣되 작성 PRD 부재는 보류로 분리." 교차 derive·빈섹션·마커 검증은 2b-2(gemini 2차 — 최소 derive를 check에 넣으면 "동작변경 0" 전제와 충돌). |
| D8 | 계약 | **feature_list 스키마 불변 · 프로필 필드 0(always-on) · 신규 플레이스홀더 0 · README/_template=managed, 작성 PRD=비-manifest-추적** | codex·gemini — 2b-1엔 전방 필드 불필요(grep 충분). canonical override가 나중에 필요하면 feature_list 오염 대신 **별도 binding index**(2b-2). 작성 PRD는 작성 E2E 스펙 동급(업그레이드 미덮어쓰기). |
| D9 | 버전·마이그레이션 | **MINOR 1.25.0→1.26.0 + `[new]` 마이그레이션 M-1.25.0-to-1.26.0** | codex 2차(critical) — always-on인데 "소급 안 함"은 계약 불일치("1.26.0 기능인데 기존 하네스엔 없음"). e2e/README 선례(소급 안 함)는 **옵트인**이라 허용됐으나 PRD substrate는 **always-on** → 소급 설치 필수(idempotent·skip-if-exists). |

## 4. 구성요소

### 4.1 `templates/product-specs/_template.md` (신규 managed 템플릿, 정적·비치환)

자기충족 PRD 양식. 작성자는 복사 후 `F000`을 실제 ID로, 주석 가이드를 내용으로 대체한다. **신규 `{{...}}` 플레이스홀더 없음**(INTENT_LEDGER.md처럼 정적 복사 생성).

```markdown
@feature:F000
<!-- ↑ 이 파일이 명세하는 feature_list.json의 id로 교체. 전체줄 리터럴(grep -Fx 매칭). 파일명 slug가 아니라 이 줄이 바인딩 권위다. -->

# {기능 제목}

<!-- harness:section=intent -->
## Intent / 의도
<!-- 이 기능이 왜 존재하는가 — 해결하는 사용자 문제. -->

<!-- harness:section=behavior -->
## Behavior / 동작 규칙
<!-- 사용자 관점 동작. feature_list.steps ↔ @feature E2E 시나리오와 1:1 매핑되게. -->

<!-- harness:section=edge-cases -->
## ⚠️ Edge Cases & Out-of-Scope / 제외·엣지케이스  (필수)
<!-- [필수] 이 기능이 다루지 않는 상황·제외 조건·무시할 입력을 명시.
     제외할 사항이 전혀 없다면 그 판단 근거와 함께 "명시적 제외 사항 없음"이라고 적는다.
     빈칸·TBD·N/A로 두지 않는다 — F007류 버그(명세 안 된 제외 규칙)가 여기서 발생한다.
     예) "진행률은 각 날의 태스크만 집계 — someday는 제외" -->

<!-- harness:section=acceptance -->
## Acceptance / 수용 기준
<!-- 검증 가능한 기준. steps ↔ @feature E2E 시나리오로 확인 가능해야. -->

<!-- harness:section=open-questions -->
## Open Questions / 미결
<!-- 아직 결정되지 않은 사항. 없으면 "없음". -->
```

- **섹션 앵커 주석**(`<!-- harness:section=… -->`): 정적·불변. 2b-2 derive가 마크다운 헤더 텍스트(불안정 — 한글/이모지/공백 변경) 대신 이 앵커로 섹션 경계·evidence 위치를 안정적으로 잡는다. 2b-1은 앵커를 **놓기만** 하고 읽지 않는다.
- **anti-blank 가이드**(특히 edge-cases): 빈칸 침묵 실패를 저-마찰로 방지. 강제 실패가 아닌 작성 시점 인지 장치.

### 4.2 `templates/product-specs/README.md` (신규 managed 템플릿, 정적·비치환)

`docs/product-specs/`의 디렉토리 관례 문서. 담는 내용:
- **경로·네이밍**: PRD는 `docs/product-specs/{featureID}-{slug}.md`. slug는 사람 탐색용 힌트이며 **바인딩 권위 아님**(권위는 파일 안의 `@feature:{id}` 전체줄).
- **마커 규칙**: 각 PRD는 `@feature:{id}` 전체줄을 1개 포함한다(보통 파일 상단). `_template.md`를 복사해 작성한다.
- **feature_list 진입점**: 기능 목록의 권위는 `feature_list.json`. PRD는 그 feature를 산문으로 명세한다.
- **운영 노트(H7)**: intent-distill(2a)이 `INTENT_BACKLOG.md`에 올린 `missing`/`partial` 항목은, 해당 feature의 PRD `Edge Cases`/`Acceptance` 섹션에 반영해 닫는다 — 의도→E2E 백로그와 의도→PRD 명세를 연결하는 운영 규칙.
- **2b-2 예고**: 의도↔PRD 커버리지 자동 derive·미검증 명세 점검은 후속(fast-follow)에서 배선됨.

### 4.3 `harness-scaffold/SKILL.md` 변경 (정규 사양)

- **§5 생성 순서 1번**: `docs/product-specs/`를 빈 디렉토리 생성에서 → `docs/product-specs/README.md` + `docs/product-specs/_template.md` **정적 복사 생성**으로 교체. design-docs/exec-plans/references는 기존대로 빈 디렉토리. per-feature stub 생성 없음.
- **§5.12.x(신규 서브섹션)**: 두 managed 파일의 생성 규칙(정적 복사, 비치환) 명문화 — INTENT_LEDGER.md(§5.12.3) 패턴 미러.
- **§5.13 manifest**: `docs/product-specs/README.md`·`_template.md`를 category `managed`로 등록. 작성된 `{id}-{slug}.md`는 미등록(비추적). 프로필 스냅샷 변경 없음.
- **§6 Phase 3 검증**: 필수 파일 확인 라인에 두 파일 추가.
- **§7 능력 게이팅(H6 정직 문구)**: always-on 능력 라인 무조건 표시. 문구는 **"PRD 작성 관례·템플릿 제공"** — 의도↔PRD 추적 **derive는 2b-2**라고 명시(과장 금지). 예: "PRD 명세 → `docs/product-specs/{id}-{slug}.md`에 `@feature:{id}`로 작성(관례·템플릿; 커버리지 derive는 후속)".
- **§11 참고자료 표 (§12.6.1 제외)**: docs/*.md managed 정적 파일은 §12.6.1 자동 감지 매핑에서 **제외**한다(INTENT_LEDGER.md·HARNESS_FRICTION.md 관례 — 정적 복사 docs는 마이그레이션으로 관리). 두 파일은 harness-scaffold §11 참고자료 표에 "그대로 복사(플레이스홀더 없음)"로 등재한다. 초기 설치·기존 하네스 소급·향후 템플릿 변경은 모두 마이그레이션(§4.5 [new], 이후 변경은 후속 마이그레이션)으로 관리한다.

### 4.4 `templates/rules/coding-standards.md` 변경 (managed 템플릿, 관례 선언 — H5/D6)

- E2E `@feature` 관례가 이미 사는 곳에 **PRD 관례를 평행 선언**한다(자연스러운 형제 위치):
  - PRD는 `docs/product-specs/{id}-{slug}.md`에 작성하고 `@feature:{id}` 전체줄로 바인딩한다.
  - **소프트 트리거(권고, 게이트 아님)**: 새 `@feature` 작업을 시작할 때 `_template.md`를 복사해 PRD를 먼저 작성할 것을 **권장**한다. 이는 TDD 상태 게이트가 아니며 검증 주장도 아니다(파이프라인 동작 변경 0). PRE-RED **강제**·커버리지 검증은 2b-2.
- **경계 명시**: 2b-1은 관례를 *선언*만 한다. 작성된 PRD가 의도를 커버하는지의 *판정*(derive)은 2b-2.

### 4.5 마이그레이션 `M-1.25.0-to-1.26.0` (신규 `[new]` 마이그레이션 — H1/D9)

- 기존 하네스(1.25.0 이하)에 두 managed 파일을 **소급 설치**한다:
  - `docs/product-specs/README.md` 부재 시 생성, 존재 시 **skip + 보고**(사용자 파일 덮어쓰기 금지).
  - `docs/product-specs/_template.md` 동일.
- **idempotent**: 재실행해도 추가 변경 없음. 기존 빈 `docs/product-specs/`는 substrate를 얻고, 사용자가 이미 만든 동명 파일은 보존된다.
- §10.3 마이그레이션 레지스트리에 등록. always-on 기능이므로 소급은 **필수**(옵트인 e2e/README 선례와 대비 — §3 D9).

### 4.6 검증 배선 (harness-check.sh / harness-checklist.md — D7)

- **managed substrate = 구조 검사**: `docs/product-specs/README.md`·`_template.md`를 필수 파일 존재 검사(① 하네스 구조)에 추가 — 부재는 **구조 실패(exit 1)**, 타 managed 파일(AGENTS.md 등)과 동일 취급(1.26.0 하네스엔 반드시 존재).
- **작성 PRD = 보류**: 작성된 PRD(`{id}-{slug}.md`) **부재는 실패가 아니라 보류/정보**(E2E "판정 보류" 미러 — 새 프로젝트는 아직 PRD 0개가 정상).
- 교차 derive(PRD 없는 feature 경고)·빈섹션 감지·마커 검증은 **2b-2**(D7 — check에 derive를 넣으면 동작변경 0 전제와 충돌).
- checklist §8(자가진단 SSoT)에도 동일 분기를 반영(필수 substrate 존재 vs 작성 PRD 보류).

## 5. 데이터 흐름

```
[scaffold]   docs/product-specs/ → README.md + _template.md 생성(managed). per-feature stub 없음.
[작성(온디맨드)] 에이전트/사람이 feature 작업 시 _template 복사 → {id}-{slug}.md 작성,
                @feature:{id} 전체줄 바인딩, Edge Cases에 제외 규칙 명세(anti-blank 가이드).  ← 비추적 파일
[capability] §7 카탈로그 + coding-standards 관례 선언(소프트 트리거). 게이트 변경 0.
[업그레이드]  M-1.25.0-to-1.26.0 → 기존 하네스에 README/_template 소급(idempotent, 사용자 파일 보존).
[Phase 2b-2] intent-distill PRD 방향 derive → @feature 전체줄 + 섹션 앵커로 의도↔PRD 커버리지 산출(fast-follow).
```

## 6. 계약·정합성 영향 (CLAUDE.md 개발 규칙)

- ✅ **프로필 계약 불변**: 신규 프로필 필드 0(D8) → SKILL.md §5 프로필 출력 ≡ harness-scaffold §4 프로필 입력 계약 그대로.
- ✅ **치환 규칙 불변**: 신규 `{{...}}` 0(§4.1·4.2 정적 템플릿).
- ✅ **feature_list 스키마 불변**: 전방 필드 미추가 → data 계약·골든 픽스처 무영향.
- ✅ **Phase 1/2a 불변**: 원장 스키마·intent-distill·harness-feedback 미변경.
- ✅ **골든 픽스처(structural-test) 무영향**: structural-test 템플릿 미변경. PRD substrate용 **신규 픽스처** 별도 추가(§8).
- ✅ **두 SKILL.md 프로필 스키마 동기화 불요**.

## 7. degradation / 엣지 케이스

| 상황 | 처리 |
|------|------|
| `docs/product-specs/`에 작성 PRD 0개 | substrate 존재면 정상(보류) — "PRD 없음"은 실패 아님 |
| 기존 사용자 README/_template 존재 | 마이그레이션 skip + 보고(덮어쓰기 금지) |
| feature ID에 regex 메타문자(커스텀 ID) | `grep -Fx` 리터럴 매칭이라 안전(D2) |
| 본문에 인라인 `@feature:F007를 추가` / 코드블록 예시 | 전체줄 매칭 아니므로 바인딩으로 안 잡힘(오탐 방지) |
| 파일명 slug ≠ feature description | 무해 — slug는 비권위(README 명시). 불일치 경고는 2b-2 |
| 한 feature에 PRD 복수 / 마커 중복 / orphan 마커 | 2b-1은 통과(경량 check) — duplicate/invalid 판정은 2b-2 derive |
| `@feature` 없는 PRD 파일 | 2b-1은 unbound로 방치(허용) — 경고는 2b-2 |
| 비-웹/백엔드/라이브러리 프로젝트 | 무영향 — 마크다운+grep은 완전 스택비종속(gemini 2차: 위험 ~0) |

## 8. 검증 계획

- **마커 grep 견고성**(픽스처): 전체줄 `@feature:{id}` 매칭 / 커스텀 ID(메타문자) 안전 / 본문 인라인·코드블록 예시 **기각** / 전체줄 마커 발견.
- **scaffold 생성**(시나리오): `docs/product-specs/`에 README+_template 정적 생성 / per-feature stub 0 / manifest에 두 파일 `managed` 등록 / 프로필 스냅샷 불변 / §6 검증 라인 통과.
- **마이그레이션**(시나리오): 기존 빈 `docs/product-specs/`에 소급 생성 / 기존 사용자 README/_template **충돌 보존**(skip) / idempotent(재실행 동일).
- **능력 게이팅**(시나리오): §7 라인이 "관례·템플릿 제공"으로 표기(과장 없음), derive=2b-2 명시.
- **계약 회귀**: feature_list 스키마 불변 / 신규 플레이스홀더 0 / 프로필 스키마 동일성 / 골든 픽스처(`test/run-fixtures.sh`) 무영향 / Phase 1·2a 불변.

신규 픽스처는 `test/prd-substrate-fixtures.sh`(가칭) — e2e-fixtures.sh·feedback-cursor-fixtures.sh 패턴 미러.

## 9. 버전 / 마이그레이션

- 신규 managed 템플릿 2개 + scaffold 생성 규칙 + coding-standards 관례 선언 + capability 문구 + `[new]` 마이그레이션. 기존 호환(가산). **MINOR: 1.25.0 → 1.26.0**.
- 범프 동시 대상(CLAUDE.md 버전 정책): `project-context.md`, `.tracking/CHANGELOG.md`, `.claude-plugin/plugin.json`, `marketplace.json`, `README.md` 버전 줄, `git tag`(병합 시).
- **마이그레이션 필요**: always-on이라 기존 하네스에 소급 설치(M-1.25.0-to-1.26.0, `[new]`, idempotent·skip-if-exists). 프로필 변경 없어 managed 자동 감지(§12.6)는 *기존* 파일만 — 신규 파일은 마이그레이션 경로.

## 10. 수용 기준

- [ ] scaffold가 `docs/product-specs/`에 `README.md` + `_template.md`(managed)를 생성한다(빈 디렉토리 교체, per-feature stub 없음).
- [ ] `_template.md`가 `@feature` 마커 + 섹션 앵커 주석 + Edge Cases/Out-of-Scope **anti-blank 가이드**를 포함한다.
- [ ] 바인딩이 whole-line 리터럴 `@feature:{id}`(`grep -Fx`)로 정의되어 커스텀 ID 안전·본문 오탐 방지된다.
- [ ] capability 문구가 "관례·템플릿 제공"으로 정직하게 표기되고 derive=2b-2를 명시한다(과장 없음).
- [ ] coding-standards에 PRD 관례 + 소프트 트리거(권고, 게이트 아님)가 선언된다(파이프라인 동작 변경 0).
- [ ] `M-1.25.0-to-1.26.0`이 기존 하네스에 두 파일을 소급 설치하되 사용자 파일을 보존한다(idempotent).
- [ ] harness-check가 substrate 존재를 경량 확인하고, 작성 PRD 부재를 보류로 처리한다(실패 아님).
- [ ] feature_list 스키마 불변 · 신규 프로필 필드 0 · 신규 플레이스홀더 0 · 골든 픽스처 무영향.

## 11. 명시적 비-스코프 (Phase 2b-2 — fast-follow)

- intent-distill **PRD 방향 derive**(5-상태 미러: covered/partial/missing/ambiguous/invalid) — @feature 전체줄 + 섹션 앵커 기반 섹션-evidence.
- **"미검증 명세" 방향**(PRD에 있는데 의도 원장 근거 없음 표면화).
- harness-check **빈섹션 감지**(Edge Cases 헤더만/TBD/N/A 경고) · **feature↔PRD 교차 derive**(PRD 없는 feature 경고) · **마커 검증 경고**(파일명-마커 불일치·중복·orphan/invalid-feature).
- 8-상태 taxonomy · `INTENT_BACKLOG.md` PRD 통합 · doc-freshness 글로빙(`product-specs/**`) · binding index(canonical override — feature_list 필드 아님) · Architect PRE-RED **강제** PRD 작성(게이트).

---

## 참고
- 멀티모델 자문 원본(2회): 1차 `.claude/artifacts/consult/codex-…11-15-21.md`·`gemini-…11-16-10.md`(접근법 A 결정), 2차 `codex-…11-29-49.md`·`gemini-…11-30-35.md`(확정 설계 리뷰 — H1~H7 도출).
- 선행: Phase 1 `docs/superpowers/specs/2026-06-17-intent-ledger-capture-design.md`(§12.1 PRD 갭), Phase 2a `…intent-distill-design.md`(§14 비-스코프=2b 범위), Phase 2b 핸드오프 `…2026-06-17-phase-2b-handoff.md`.
- 출력단 현행: `coding-standards.md`(steps↔L4 E2E 1:1, `@feature` 관례), `test-engineer.md`(`@feature` 태그), `skills/intent-distill/SKILL.md`(2b-2 확장 지점 §4 derive/§6 리포트).
- 별개 cleanup(비차단, 핸드오프 §8): SKILL.md·CLAUDE.md "19개 파일" → 실제 22개 드리프트 — 이 spec과 무관, 후속 docs-hygiene.
