# Phase 2b-3 Handoff — PRD 정적 검증 (harness-check) (이슈 #15)

> 작성일: 2026-06-18
> 상태: **미착수** — 다음 세션의 brainstorming 진입점
> 선행: Phase 2b-1(PRD substrate, v1.26.0) + Phase 2b-2(forward PRD 커버리지 derive, v1.27.0)

---

## 1. 현재 상태 (where things stand)

이슈 #15는 `대화 → 영속 원장 → 증류 → **추적**` 파이프라인이다. 추적(Phase 2b) 진행:

| 페이즈 | 내용 | 산출물 | 상태 |
|--------|------|--------|------|
| 2b-1 | **PRD substrate** | `docs/product-specs/{id}-{slug}.md` + whole-line `@feature` 바인딩 + 섹션 앵커 + anti-blank 가이드 · `[new]` 소급 마이그레이션 | ✅ v1.26.0 (PR #19) |
| 2b-2 | **forward PRD 커버리지 derive** | intent-distill 2차원(prd_state+e2e_state) · substrate≠missing · 보수적 derive · 빈섹션 가드(awk) · 백로그 one-way 마이그레이션 | ✅ v1.27.0 (PR #19에 합산) |
| **2b-3** | **PRD 정적 검증** | harness-check 빈섹션 경고·feature↔PRD 교차·마커 검증·8-상태 taxonomy·doc-freshness | ⬜ **이 문서** |

derive(2b-2)는 의도→PRD/E2E 커버리지를 *런타임 시맨틱*으로 판정한다. 2b-3는 그 **정적·결정적 보완** — substrate 자체의 구조 위생(orphan/duplicate/mismatch/empty)을 harness-check가 기계적으로 잡는다.

## 2. Phase 2b-3가 무엇인가 (scope — spec §12 비-스코프에서 이월)

2b-1·2b-2가 derive 경로를 닫았다면, 2b-3는 **정적 harness-check 검증 클러스터**다:

1. **빈 섹션 경고** — PRD의 `⚠️ Edge Cases & Out-of-Scope`가 헤더만/`TBD`/`N/A`/주석뿐이면 harness-check가 경고. (2b-2 derive는 이미 빈 섹션을 `covered` 금지하는 *가드*가 있으나, 2b-3는 *선제적 경고* — F007류 방어의 능동화.)
2. **feature↔PRD 교차 검사** — `feature_list.json`의 feature 중 바인딩 PRD가 없는 것을 경고(작성 후보 표면화). grep 결정적.
3. **마커 검증 경고** — ① 파일명-마커 불일치(`F007-x.md`인데 `@feature:F008`), ② 한 파일 마커 복수, ③ orphan/invalid-feature 마커(feature_list에 없는 feature를 가리킴).
4. **8-상태 taxonomy** (codex 2b-1 1차 자문에서 도출, 미구현): `bound`/`no-prds-yet`/`unbound-prd`/`invalid-feature`/`duplicate-binding`/`ambiguous-marker`/`stub-only`/`substrate-missing`. harness-check의 PRD 진단 상태 모델.
5. **doc-freshness 글로빙** — `docs/product-specs/**/*.md`를 최신성 감시에 편입(2b-1이 노이즈 위험으로 이연 — `doc-freshness.ts`는 정적 목록 `{{DOC_CHECK_TARGETS}}`이라 글로빙은 동작 변경).

## 3. 왜 (motivation)

2b-2 derive는 **시맨틱**(LLM)이라 비용·비결정성이 있고, 매 실행 전체 의도를 판정한다. 반면 substrate **구조 위생**(orphan PRD, 중복 마커, 파일명-마커 불일치, 빈 필수 섹션)은 **결정적·저비용**이라 harness-check(`npm run harness:check`)가 상시 잡는 게 옳다. 2b-1이 substrate 존재(README/_template)만 구조 검사했고, 작성된 PRD의 위생은 미검증으로 남겼다 — 그 갭이 2b-3다.

## 4. 상속된 결정·제약 (2b-1/2b-2에서 — 반드시 따름)

- **substrate 부재 ≠ missing** — `docs/product-specs/` 없으면 판정 보류(`blocked`), 위반 아님. 작성된 PRD 부재도 보류(E2E "판정 보류" 미러). 2b-1: managed substrate(README/_template)만 구조-필수(exit 1), 작성 PRD는 보류.
- **whole-line `@feature` 바인딩** — `grep -Rl -Fx "@feature:{id}" docs/product-specs/`. 본문 인라인/코드블록 오탐 방지(2b-1 가드).
- **`prd_section_body` awk 추출기 재사용** — 빈 섹션 경고는 2b-2의 검증된 awk(섹션 앵커 경계·HTML주석/헤딩 제외·멀티라인주석 stripping)를 그대로 쓴다. **이 awk는 `test/intent-prd-coverage-fixtures.sh`와 `skills/intent-distill/SKILL.md §4.1`에 동일 로직(logic-identical — 들여쓰기만 다름)으로 존재** — 2b-3가 harness-check.sh에 또 넣으면 **3곳 동기화** 필요(또는 공유 헬퍼 전략 고려).
- **오탐 보수성** — 역방향 "미검증 명세"를 노이즈로 뺀 것과 같은 원칙. 마커 검증·교차 검사는 **결정적·명확한** 위반만 경고(모호하면 침묵). codex 일관 테마.
- **harness-check 경고-전용 분리 (PRD 도메인 한정)** — 작성 PRD 위생은 **경고/보류**(exit 0 유지), managed substrate(README/_template) 부재만 exit 1. (harness-check.sh 전체엔 STRUCT_FAIL ①②③·QUALITY_FAIL ④⑤ 별도 exit 1 경로가 있다 — 이 분리는 PRD 항목 내부 정책이지 harness-check 전역 정책이 아님.) checklist §8 SSoT와 정합. (2b-1 D7: 빈섹션·교차·마커 검증은 2b-3 — check에 시맨틱 derive를 넣으면 "동작변경 0" 전제와 충돌하므로 **결정적 grep/awk만**.)
- **always-on · 프로필 필드 0 · 신규 플레이스홀더 0 지향** · INTENT_BACKLOG/product-specs `data`/managed 카테고리 불변.
- **멀티모델 자문 권장** — 2b-1/2b-2 모두 자문이 설계를 크게 개선(2b-2: 역방향 제외·보수적 derive). 2b-3도 상태 taxonomy·doc-freshness 노이즈 결정 전 자문 권장.

## 5. 핵심 미결정 (brainstorming에서 풀 것)

- **배치**: 검사들이 `harness-check.sh`(정적, 대상 프로젝트 실행, 경고-전용)인가, intent-distill(derive 스킬)인가? 마커 검증·교차 검사·빈섹션은 결정적이라 harness-check.sh가 자연스럽지만, harness-check.sh는 bash라 PRD 파싱이 무겁다(awk 재사용 가능).
- **8-상태 taxonomy 채택 범위**: 8개 전부 vs 핵심만(orphan/duplicate/mismatch/empty)? 어디에 기록(harness-check 출력? manifest? 별도 리포트?).
- **exit-code 정책**: 어떤 위생 위반이 exit 1(구조 실패)이고 어떤 게 경고(exit 0)인가? orphan/duplicate은 강한 경고, 빈섹션·미작성은 보류? (2b-1: invalid/duplicate/ambiguous = 실패/강경고, no-prds-yet = 보류 — codex 1차 자문 권고.)
- **doc-freshness 노이즈**: product-specs 글로빙이 갓 작성된 PRD를 stale로 오탐? `doc-freshness.ts` 정적목록→글로빙 전환의 동작 변경 범위. 빼고 별도 항목으로 둘지.
- **awk 3-way 동기화**: 빈섹션 검사가 awk를 harness-check.sh에도 넣으면 fixture+§4.1+harness-check 3곳. 공유 헬퍼 파일 vs 중복 허용(정적 idiom)?
- **스코프 분해**: 2b-3도 클 수 있다(마커검증/교차/빈섹션/8상태/doc-freshness). 더 쪼갤지(예: 마커·구조 검증 먼저, doc-freshness 별도).

## 6. 진입점 (다음 세션 시작 방법)

1. 세션 시작 루틴: `.tracking/HANDOFF.md` → 이 문서.
2. **brainstorming 스킬**로 시작 — 스코프 분해 + 배치(harness-check vs distill) 결정부터.
3. 상태 taxonomy·doc-freshness 결정 전 **multi-model-consult** 권장.
4. 선행 읽기:
   - `docs/superpowers/specs/2026-06-17-phase-2b-1-prd-substrate-design.md` §11(2b-3 비-스코프 정의) + §3 D7(harness-check 경계)
   - `docs/superpowers/specs/2026-06-17-phase-2b-2-prd-coverage-derive-design.md` §12(비-스코프) + §4.1(빈섹션 가드 awk)
   - `skills/harness-scaffold/templates/harness-check.sh`(현 ① 구조 검사 — 2b-1이 README/_template 필수 + 작성 PRD 보류 추가)

## 7. 관련 파일·앵커 (Phase 2b-3가 만질 곳)

| 영역 | 파일·앵커 | 비고 |
|------|-----------|------|
| 정적 검사 본체 | `skills/harness-scaffold/templates/harness-check.sh`(① 필수 파일 — 2b-1이 product-specs substrate 검사 추가) | 마커 검증·교차·빈섹션 경고 추가 지점 |
| 검사 SSoT | `skills/harness-setup/references/harness-checklist.md` §1.1·§8 | harness-check.sh와 동기 |
| 빈섹션 awk | `skills/intent-distill/SKILL.md §4.1`의 `prd_section_body` + `test/intent-prd-coverage-fixtures.sh` | 재사용 추출기(byte-identical 2곳 — 3-way 동기 주의) |
| 바인딩 규칙 | 2b-1 `docs/product-specs/README.md`(whole-line `@feature` `grep -Fx`) | 마커 검증의 권위 |
| doc-freshness | `skills/harness-scaffold/templates/doc-freshness.ts`(`{{DOC_CHECK_TARGETS}}` 정적 목록) + harness-scaffold §5.7 치환 | 글로빙 시 동작 변경 |
| 픽스처 | `test/prd-substrate-fixtures.sh` · `test/intent-prd-coverage-fixtures.sh` | 마커검증/교차 결정적 테스트 추가(패턴 미러) |
| 운영 사이클 | `harness-cleanup` 월간 M1(문서-실구조 일치) | PRD 위생 편입 후보 |

## 8. 잔여 (2b-3와 별개 — 더 이후)

- **역방향 "미검증 명세"**(PRD claim 후보 + 저신뢰 리포트, codex 보수안) → **2b-4 후보**. 2b-2에서 노이즈로 제외. 가치 입증 시 착수.
- **binding index**(중복 PRD canonical override) — codex 1차 자문: YAGNI, 중복 PRD가 실제 문제 될 때만.
- **Architect PRE-RED 강제 PRD 작성**(게이트) — 파이프라인 동작 변경. gemini 경고(검증 도구 없이 PRD 양산=환각). 신중히.
- 별개 cleanup(비차단, docs-hygiene): `harness-setup/SKILL.md`·`CLAUDE.md` "19개 파일" → 실제 24개 드리프트 정정.

---

## 참고
- 이슈 #15 (3단계 파이프라인), Phase 2b PR #19(2b-1+2b-2 합산), 태그 v1.26.0·v1.27.0(병합 시).
- 멀티모델 자문 아티팩트: 2b-1 `.claude/artifacts/consult/codex-…11-15-21.md`·`…11-29-49.md`, 2b-2 `…13-32-37.md`·`gemini-…13-33-16.md`.
