# Phase 2b-3 Increment 2 설계 — PRD 빈 섹션 정적 검사 (이슈 #15)

> 작성일: 2026-06-18
> 상태: **설계 승인 대기 → 구현 계획(writing-plans)**
> 선행: 2b-1(substrate, v1.26.0) · 2b-2(forward derive, v1.27.0) · 2b-3 Inc1(마커 위생, v1.28.0)
> 진입 핸드오프: `docs/superpowers/specs/2026-06-18-phase-2b-3-inc2-handoff.md`
> 목표 버전: **v1.29.0** (MINOR, 하위 호환, 마이그레이션 불필요)
> 멀티모델 자문 아티팩트: `.claude/artifacts/consult/codex-…02-39-39.md` · `gemini-…02-41-15.md`

---

## 0. 한 줄 요약

`harness-check.sh` ⑩ "PRD 위생"에 두 번째 함수 `prd_content_hygiene`을 추가해, *작성된* PRD의 **필수 `Edge Cases` 섹션이 비어 있으면**(헤딩/주석/공백/단독 placeholder만) `awk`(섹션 본문 추출) + bash 로컬 후처리로 상시 ⚠️ 경고한다. exit 0 경고-전용. **신규 managed 파일·플레이스홀더·프로필 필드 0.**

## 1. 배경 & 동기

이슈 #15 파이프라인: `대화 → 영속 원장 → 증류(LLM) → 추적(Phase 2b)`.

- **2b-1**(v1.26.0): PRD substrate — `_template.md`의 `⚠️ Edge Cases & Out-of-Scope` 섹션에 **`[필수]`** 표시. "명세 안 된 제외 규칙 = 가장 흔한 버그 원천"(F007류)이라는 anti-blank 가이드를 산문으로 명시.
- **2b-2**(v1.27.0): intent-distill forward derive가 빈 섹션을 `covered` 금지하는 **수동 가드**(런타임·LLM).
- **2b-3 Inc1**(v1.28.0): 마커 위생 5종(순수 grep/node, awk-free).
- **2b-3 Inc2**(이 문서): anti-blank 가이드의 **능동적·상시 기계 검사**. 작성 시점에 마찰을 주어 "빈 Edge Cases"를 선제 차단한다. Inc1이 *마커* 위생을, Inc2가 *내용* 위생(빈 섹션)을 담당 — "마커 먼저, 내용 나중" 분해의 완결.

## 2. 멀티모델 자문 요지 (설계 근거)

codex(결함/정확성)·gemini(단순화/운영) 자문이 수렴:

- **awk는 정당하다** — 단순 grep/sed로는 멀티라인 HTML 주석을 안전하게 못 가른다. 템플릿의 긴 안내 주석을 본문으로 오인하는 *false-covered*, 또는 실내용을 주석으로 오인하는 누락 위험. 검증된 `prd_section_body`를 그대로 쓴다(gemini Q1).
- **(a) 신규 헬퍼 파일·(b) 단순 중복 기각** — (a)는 상속 제약 정면 위반(신규 managed·마이그레이션·standalone 깨짐), (b)는 awk 상태머신이라 작은 차이가 판정 차이로 이어지는 drift(codex).
- **검사 대상은 edge-cases만** — `[필수]`가 거기에만 있다. intent/behavior 확장은 "보수성이 아니라 정책 확장"(codex Q3). 확장하려면 템플릿에 마커 먼저 추가하는 게 순서.
- **별도 함수 `prd_content_hygiene`** — 마커 검사(grep)와 내용 검사(awk)는 리스크 프로파일이 달라 응집도 위해 분리(gemini Q3).
- **경고 메시지에 행동 지침** — "예외가 없다면 그 이유를 한 문장으로 명시하세요"(gemini Q4). TBD/None을 허용하는 순간 우회로가 생겨 빈 PRD 양산.
- **placeholder 필터는 awk 밖** — `prd_section_body`는 N/A·TBD·None을 "본문 있음"으로 본다. 단독 placeholder를 "빈"으로 취급하려면 **소비 측 로컬 필터**가 필요(codex Q2).

**합성 통찰 — 공유 헬퍼**: codex는 (d)(단일 실행 소스, intent-distill을 doc 참조로 강등)를, gemini는 (e)(self-contained + drift-guard)를 권고. gemini가 더 날카로운 제약을 짚었다 — **intent-distill SKILL.md는 마크다운이라 런타임 `source` 불가**(LLM이 awk 텍스트를 인라인 실행하므로 doc 안에 awk가 남아야 함). 따라서 codex의 "doc 참조만"은 그대로 불가. 두 안의 교집합 = **§4의 (c)+(e) 합성**.

## 3. 스코프 & 경계

### 3.1 검사 대상
`docs/product-specs/*.md` 중 `README.md`·`_template.md` **제외**(Inc1 ① 미러). **검사 섹션 = `edge-cases` 단독**(`_template.md`에서 유일한 `[필수]`).

### 3.2 비-스코프 (이연/기각)
- **feature↔PRD 교차**(PRD 없는 feature 표면화) → **2b-4**(역방향 "미검증 명세"와 묶어 재설계). README "PRD 없음=정상(온디맨드)"과 충돌해 노이즈 폭탄 위험(사용자 결정: Inc2 제외).
- **intent/behavior/acceptance 빈 검사** → 이연. `[필수]` 마커 부재 → 검사하면 "명세 안 된 필수 섹션"을 새로 만드는 셈(codex). 확장 시 템플릿에 마커 먼저.
- **doc-freshness 글로빙** → 기각 유지(mtime 노이즈).

### 3.3 검사 위치
⑩ "PRD 위생" 섹션 내부, `prd_marker_hygiene` **다음**에 `prd_content_hygiene` 호출. 종합 판정 전, ⑥⑦⑧⑨ 동급 경고 전용 — `STRUCT_FAIL`/`QUALITY_FAIL`/exit code에 **무영향**.

## 4. 공유 헬퍼 전략 — (c)+(e) 합성

`prd_section_body` awk는 현재 **2곳에 logic-identical**(들여쓰기만 다름, 정규화 후 byte-identical 실측 확인): `skills/intent-distill/SKILL.md §4.1` + `test/intent-prd-coverage-fixtures.sh`. Inc2가 harness-check에 추가하면 3-way.

**결정**:
1. **canonical 실행 소스 = harness-check.sh** — `prd_section_body`를 추출 마커 `# --- harness:prd-section-body:start/end ---`로 감싼다. 새 `prd_content_hygiene`이 같은 파일 내에서 호출.
2. **현재 awk는 한 글자도 안 고친다** — 현 intent-distill 버전과 byte-identical 유지(들여쓰기 자유). → intent-distill 의미로의 blast radius 0. CRLF·placeholder 보강은 전부 harness-check **로컬 후처리**(§5).
3. **coverage 픽스처는 source로 전환** — `test/intent-prd-coverage-fixtures.sh`의 awk 복사본을 제거하고 harness-check.sh 마커 블록에서 `sed` 추출·source. → **실행 복사본 2개 → 1개로 수렴**(codex (d) 방향).
4. **intent-distill SKILL.md는 인라인 awk 유지**(LLM 런타임 필요) + 매칭 마커로 감싸고, **drift-guard 테스트**가 정규화 후 harness-check 블록과 동일한지 단언. doc 옆에 "실행 정본은 harness-check.sh" 주석.

**순효과**: 실행 SSoT 1개(harness-check) + 가드된 doc 복사본 1개(SKILL.md). **현 상태(미가드 2복사본)보다 개선** — coverage 복사본 제거 + 잔여 doc 복사본을 기계적 가드로 잠금. 신규 managed 파일 0, harness-check standalone 유지, 마이그레이션 불필요.

**drift-guard 정규화 규칙**(brittle 회피 — codex 우려 반영): 선행 공백 제거 + 내부 연속 공백 1칸 축약 + trailing 공백 제거 후 비교. (실측: 들여쓰기만 다른 현 2복사본이 이 정규화로 IDENTICAL 판정됨.)

## 5. `prd_content_hygiene` 판정 로직

각 대상 PRD에 대해:

| 단계 | 동작 | 근거 |
|------|------|------|
| **앵커 게이트** | `^<!--[[:space:]]*harness:section=edge-cases` 앵커 **없으면 침묵** | 템플릿 복사 PRD엔 항상 존재. 부재=pre-template/수작성 → 벌하지 않음(codex 보수성). "앵커 있는데 빈" vs "앵커 부재"를 구분 |
| **CRLF 정규화** | `tr -d '\r'` 후 `prd_section_body edge-cases` 호출 | 공유 awk 안 건드리고 로컬에서 `\r` 중화(codex: awk `[[:space:]]`의 `\r` 처리 구현 의존) |
| **본문 추출** | `prd_section_body`가 주석(멀티라인 포함)·헤딩·공백 제거 | 공유 awk |
| **placeholder 필터** | 각 본문 줄에서 리스트마커(`-`/`*`/`>`)·따옴표·둘러싼 구두점 트림 후, **단독** placeholder 토큰과 정확히 일치하면 비실질 | codex: awk는 placeholder를 본문으로 봄 |
| **판정** | 실질 줄 0개 **AND 앵커 존재** → ⚠️ 경고 | |

**placeholder 집합**(보수적·타이트, **단독 줄만** 매칭): `TBD` `TODO` `TBA` `N/A` `NA` `N.A.` `None` `없음` `미정` `해당 없음` `해당없음`. ASCII 대소문자 무시. 문장형은 생존:
- 템플릿 권장 `"명시적 제외 사항 없음"`(문장) → **침묵**(올바름).
- `"없음 — someday 태스크는 제외"`(이유 동반) → **침묵**.
- bare `없음` / `N/A` / `TBD` 단독 줄 → **경고**(템플릿이 권장하는 이유-동반 형태 작성 유도).

**경고 메시지**(gemini DX): `⚠️ empty-edge-cases: {basename} — Edge Cases 섹션이 비어있음. 제외할 사항이 없다면 그 이유를 한 문장으로 명시하세요.`

위반 0건 → ⑩ 종합에서 마커 위생 ✅와 함께 정상 표기.

### 5.1 보류(⏸️/침묵)
- substrate 부재 / 작성 PRD 0개 → ⏸️ 보류(마커 위생과 동일 가드, 함수 self-guard).
- **feature_list 불필요** — 내용 검사는 id 대조가 없다(마커 위생과 다른 점).

### 5.2 오탐 가드 분석 (codex 엣지케이스 대응)
- **멀티라인 주석이 텍스트를 감쌈**(`<!-- \n real \n -->`) → 주석은 본문 아님 → "빈" 판정. **의도대로**(보수적).
- **코드펜스만 있는 섹션** → 펜스 구분선(```` ``` ````)이 비주석·비헤딩·비공백이라 본문으로 카운트 → **침묵**. codex의 false-positive 우려는 실제 발생 안 함(분석 결과 moot — 테스트로 고정).
- **앵커 줄에 텍스트 동반**(`<!-- …edge-cases --> 실내용`) → awk가 앵커 줄 `next` → 텍스트 누락 가능. 템플릿이 앵커 단독 줄을 보장하므로 **수용**(알려진 한계, 문서화).
- **앵커 중복/누락** → 앵커 부재는 침묵(게이트). 중복은 마지막 블록 기준 — "모호하면 침묵" 정신상 허용.

## 6. 동기화 지점 (계약 — 반드시 함께 수정)

| 영역 | 파일·앵커 | 변경 |
|------|-----------|------|
| 검사 본체 | `skills/harness-scaffold/templates/harness-check.sh` ⑩ | `prd_section_body`(추출 마커) + `prd_content_hygiene` 신규, ⑩에서 호출 |
| 검사 SSoT | `skills/harness-setup/references/harness-checklist.md` §1.1·§8 | ⑩ 내용 위생(빈 edge-cases) 항목 + 경고-전용 정책 |
| scaffold 사양 | `skills/harness-scaffold/SKILL.md` §5.14·§6.13 | ⑩ 내용 위생 기술, 카운트 정합 |
| awk 정본 동기 | `skills/intent-distill/SKILL.md §4.1` | awk를 매칭 마커로 래핑 + "실행 정본=harness-check" 주석(로직 불변) |
| coverage 픽스처 | `test/intent-prd-coverage-fixtures.sh` | awk 복사본 제거 → harness-check 마커 블록 source |
| 신규 픽스처 | `test/prd-content-hygiene-fixtures.sh` (신규) | §7 케이스 |
| drift-guard | `test/` (신규 또는 run-fixtures 편입) | harness-check ↔ SKILL.md `prd_section_body` 정규화 동일 단언 |
| 픽스처 러너 | `test/run-fixtures.sh` | 신규 픽스처 + drift-guard 등록 |

**신규 플레이스홀더 0**(검사 경로·앵커·placeholder 집합은 하드코딩 상수). 프로필 필드 0, 카테고리 불변. harness-check.sh = managed → §12.6 재렌더링 전파, 마이그레이션 불필요.

## 7. 검증 계획 — `test/prd-content-hygiene-fixtures.sh`

추출-source 패턴(Inc1 `prd-marker-hygiene-fixtures.sh` 미러). `prd_section_body` + `prd_content_hygiene`을 harness-check.sh에서 추출·source.

| # | 케이스 | 기대 |
|---|--------|------|
| C1 | 정상(edge-cases에 이유-동반 문장) | 무경고 ✅ |
| C2 | 헤딩만(앵커+빈 본문) | ⚠️ empty-edge-cases, exit 0 |
| C3 | 공백만 | ⚠️ |
| C4 | 주석만(단일+멀티라인) | ⚠️ |
| C5 | bare `TBD` 단독 | ⚠️ |
| C6 | bare `N/A` 단독 | ⚠️ |
| C7 | bare `없음` 단독 | ⚠️ |
| C8 | `"명시적 제외 사항 없음"`(문장) | 침묵 |
| C9 | `"없음 — someday 제외"`(이유 동반) | 침묵 |
| C10 | edge-cases 앵커 **부재** | 침묵(게이트) |
| C11 | 코드펜스 예시만(펜스 구분선 존재) | 침묵(moot 확인) |
| C12 | CRLF 빈 edge-cases | ⚠️(정규화 후 검출) |
| C13 | substrate 부재 | ⏸️ 보류, exit 0 |
| C14 | 작성 PRD 0개 | ⏸️ 보류, exit 0 |
| C15 | README/_template의 예시 | 검사 제외(경고 0) |
| C16 | render-after 와이어링 — no-op 치환 후 전체 harness-check.sh 실행 | exit 0 + ⑩ 출력 + 정상 판정 |

**drift-guard 테스트**: harness-check.sh의 `prd_section_body` 블록 vs `skills/intent-distill/SKILL.md §4.1` 블록을 §4 정규화 후 동일 단언 → 다르면 실패. (coverage 픽스처는 source 전환으로 자동 일치.)

**회귀**: `bash test/run-fixtures.sh` + 기존 PRD 픽스처(`prd-substrate-fixtures.sh`·`prd-marker-hygiene-fixtures.sh`·`intent-prd-coverage-fixtures.sh`) 통과.

**렌더 후 실측**: harness-check.sh 치환본을 픽스처 프로젝트에 두고 ⑩ 출력·exit code 직접 확인(구조 정상 시 exit 0 유지).

## 8. 진입점 (다음 단계)

1. 이 설계 사용자 리뷰 → 승인.
2. **writing-plans 스킬**로 구현 계획 작성.
3. 구현 후 골든 픽스처 + drift-guard + 렌더 후 실측 → v1.29.0 범프(project-context·CHANGELOG·plugin.json·README·git tag) + HANDOFF/TODO 갱신.

## 9. 참고
- 이슈 #15(3단계 파이프라인). Inc2 핸드오프 `2026-06-18-phase-2b-3-inc2-handoff.md`.
- Inc1 설계 `2026-06-18-phase-2b-3-prd-hygiene-design.md` §9(비-스코프=Inc2 씨앗).
- 멀티모델 자문: `.claude/artifacts/consult/codex-…02-39-39.md` · `gemini-…02-41-15.md`.
