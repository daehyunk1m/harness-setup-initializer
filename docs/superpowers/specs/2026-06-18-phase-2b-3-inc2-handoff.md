# Phase 2b-3 Increment 2 Handoff — PRD 내용 위생 (빈 섹션 + feature↔PRD 교차) (이슈 #15)

> 작성일: 2026-06-18
> 상태: **미착수** — 다음 세션의 brainstorming 진입점
> 선행: 2b-1(substrate, v1.26.0) · 2b-2(forward derive, v1.27.0) · **2b-3 Inc1(마커 위생, v1.28.0, PR #20)**
> 설계 정본(Inc1): `docs/superpowers/specs/2026-06-18-phase-2b-3-prd-hygiene-design.md` §9(비-스코프=Inc2 씨앗)

---

## 1. 현재 상태 (where things stand)

이슈 #15 파이프라인: `대화 → 영속 원장 → 증류 → 추적(Phase 2b)`. 추적의 정적 검증(2b-3)을 증분으로 나눠 진행 중:

| 증분 | 내용 | 산출물 | 상태 |
|------|------|--------|------|
| 2b-3 Inc1 | **마커 위생**(결정적·awk-free) | harness-check ⑩ `prd_marker_hygiene` — 5종(unbound/multiple/invalid-feature/file-marker-mismatch/duplicate-binding), exit 0 경고, 골든 픽스처 T1~T14(추출-source 단일소스) | ✅ v1.28.0 (PR #20, base=2b-1) |
| **2b-3 Inc2** | **내용 위생** | 빈 섹션 경고(awk 필요) + feature↔PRD 교차 | ⬜ **이 문서** |

Inc1은 **순수 grep/파일명/feature_list 집합**만 써서 `prd_section_body` awk를 의도적으로 회피했다(awk 3중화 부채 차단). Inc2는 awk(섹션 본문 파싱)가 필요한 검사를 다루므로 **공유 헬퍼 결정**이 핵심 미결정이 된다.

## 2. Increment 2가 무엇인가 (scope)

Inc1 설계 §9에서 Inc2로 이연된 두 검사:

1. **빈 섹션 경고** — PRD의 필수 섹션(특히 `⚠️ Edge Cases & Out-of-Scope`)이 헤더만/`TBD`/`N/A`/`None`/주석뿐이면 harness-check가 선제 경고. anti-blank 가이드(`_template.md`·README가 "빈칸 금지"라 명시)의 **능동적 기계 검사**. F007류 "명세 안 된 제외 규칙" 버그의 능동 방어.
   - 2b-2 derive(intent-distill §4.1)는 이미 빈 섹션을 `covered` 금지하는 *수동 가드*가 있다. Inc2는 *상시·선제 경고* — 작성 시점에 마찰을 준다.
2. **feature↔PRD 교차** — `feature_list.json`의 feature 중 바인딩 PRD가 없는 것을 표면화. grep 결정적이나 **노이즈 위험**이 큼(§5 참조).

## 3. 상속된 결정·제약 (Inc1/2b-1/2b-2에서 — 반드시 따름)

- **exit 0 경고-전용** — Inc1과 동일. PRD 내용 위생 위반은 경고. managed substrate(README/_template) 부재만 기존 harness-check ①에서 exit 1.
- **substrate/작성 PRD 부재 ≠ missing → 보류**(⏸️). 빈 feature_list(`[]`)도 id-의존 검사는 보류(ℹ️) — Inc1의 `prd_marker_hygiene` empty-ids 가드 선례.
- **오탐 보수성** — 결정적·명확한 위반만 경고, 모호하면 침묵. `TBD`/`TODO`/`N/A`/`None` 단독만 "빈" 취급, 문장 있으면 침묵(Inc1 설계 §9·codex 자문).
- **whole-line `@feature` 바인딩**(2b-1 `grep -Rl -Fx`) — 교차 검사의 권위. 파일명 slug는 비권위.
- **신규 플레이스홀더 0 지향, 프로필 필드 0, 카테고리 불변, MINOR.**
- **추출-source 단일소스 패턴** — Inc1이 `prd_marker_hygiene`를 추출 마커(`# --- harness:prd-marker-hygiene:start/end ---`)로 감싸 픽스처가 sed 추출·source. Inc2도 동일 패턴(새 함수 또는 헬퍼).
- **멀티모델 자문 권장** — Inc1 자문(codex·gemini)이 설계를 크게 개선. Inc2의 공유 헬퍼·교차 노이즈 결정 전 자문 권장. 아티팩트: `.claude/artifacts/consult/codex-…16-09-17.md`·`gemini-…16-10-45.md`.

## 4. 핵심 미결정 (brainstorming에서 풀 것)

- **★ awk 공유 헬퍼 결정 (Inc2 최대 결정)**: 빈 섹션 검사는 `prd_section_body` awk가 필요하다. 이 awk는 현재 **2곳**에 logic-identical로 존재(`skills/intent-distill/SKILL.md §4.1` + `test/intent-prd-coverage-fixtures.sh`). harness-check.sh에 또 넣으면 **3-way 동기화**. 선택지:
  - (a) **공유 bash 헬퍼 파일**(`scripts/harness-prd-utils.sh`, managed) — codex Inc1 자문 권고. scaffold가 생성, harness-check가 source, intent-distill 문서는 "이 헬퍼와 동일 로직" 참조로 전환, 테스트도 source → **단일 소스**. 비용: 신규 managed 파일 1개 + scaffold 생성 규칙 + manifest files 등록 + §12.6 자동 감지.
  - (b) **중복 허용**(정적 idiom) — 기존 2곳 관례 연장. 3곳 동기화 부채를 수동/리뷰로 관리. 비용: drift 위험.
  - (c) **harness-check 전용 추출 마커 + 픽스처 추출-source**(Inc1 패턴) — harness-check.sh 안에 awk를 두되 추출 마커로 감싸 픽스처가 source. 단 intent-distill의 awk와는 여전히 별개 소스(2→3곳).
- **★ feature↔PRD 교차 노이즈 (가치 입증 필요)**: README가 "PRD 없는 feature는 정상(온디맨드)"이라 명시 → 새 프로젝트에서 모든 feature가 경고 대상 = 폭탄. Inc1에서 이 이유로 제외했다. 보수적 설계 옵션:
  - 개별 경고 금지 → **요약 정보줄만**(`ℹ️ PRD 바인딩 N/M feature`).
  - **고신뢰 대상만** 경고(예: `passes:true`인데 PRD 없음 — 검증됐는데 명세 없음).
  - 아예 **2b-4로 이연**(역방향 "미검증 명세"와 묶어 재설계). 보수성 입증 못하면 빼는 게 맞다(codex 일관 테마).
- **빈 섹션: 어느 섹션을 필수-비공백으로?**: `_template.md` 섹션 앵커는 intent/behavior/edge-cases/acceptance/open-questions. anti-blank "[필수]"는 **edge-cases**에만 붙어 있다 → edge-cases만 검사할지, behavior/acceptance도 포함할지. 보수적이면 edge-cases 우선.
- **배치/함수 구조**: harness-check.sh ⑩을 확장(서브검사 추가)할지, 새 섹션/새 함수(`prd_content_hygiene`)를 둘지. 교차(순수 grep)는 `prd_marker_hygiene`에 자연스럽고, 빈 섹션(awk)은 헬퍼 의존이라 분리가 깔끔할 수 있다.
- **스코프 분해**: 빈 섹션(명확·가치 큼)과 교차(노이즈 위험)는 리스크 프로파일이 다르다. **빈 섹션만 Inc2, 교차는 별도/이연**으로 더 쪼갤지 brainstorming에서 결정.

## 5. 진입점 (다음 세션 시작 방법)

1. 세션 시작 루틴: `.tracking/HANDOFF.md` → 이 문서.
2. **brainstorming 스킬**로 시작 — 스코프 분해(빈섹션 vs 교차) + 공유 헬퍼 결정(a/b/c)부터.
3. 공유 헬퍼·교차 노이즈 결정 전 **multi-model-consult** 권장.
4. 선행 읽기:
   - Inc1 설계 `2026-06-18-phase-2b-3-prd-hygiene-design.md`(특히 §5 오탐 가드·§9 비-스코프) + 계획 `docs/superpowers/plans/2026-06-18-phase-2b-3-prd-marker-hygiene.md`(픽스처 추출-source 패턴)
   - `skills/intent-distill/SKILL.md §4.1`의 `prd_section_body` awk(빈 섹션 가드 — 재사용/공유 대상)
   - `skills/harness-scaffold/templates/harness-check.sh` ⑩ 섹션(`prd_marker_hygiene` — 확장/이웃 함수의 모델)
   - `skills/harness-scaffold/templates/product-specs/{README,_template}.md`(anti-blank "[필수]" 위치, 섹션 앵커)

## 6. 관련 파일·앵커 (Inc2가 만질 곳)

| 영역 | 파일·앵커 | 비고 |
|------|-----------|------|
| 정적 검사 본체 | `skills/harness-scaffold/templates/harness-check.sh` ⑩ | 빈섹션/교차 추가(⑩ 확장 또는 새 함수) |
| 공유 awk 헬퍼(옵션 a) | `scripts/harness-prd-utils.sh`(신규 managed) + scaffold 생성 규칙 + manifest files | 결정 시에만 |
| awk 정본 | `skills/intent-distill/SKILL.md §4.1` `prd_section_body` + `test/intent-prd-coverage-fixtures.sh` | 3-way 동기 주의 |
| 검사 SSoT | `skills/harness-setup/references/harness-checklist.md` §1.1·§8 | ⑩ 항목 갱신 |
| scaffold 사양 | `skills/harness-scaffold/SKILL.md` §5.14·§6.13 | 동기 |
| 픽스처 | `test/prd-marker-hygiene-fixtures.sh`(확장) 또는 신규 `test/prd-content-hygiene-fixtures.sh` | 추출-source 패턴 미러 |
| 바인딩 권위 | `templates/product-specs/README.md`(whole-line `@feature` `grep -Fx`) | 교차 검사 권위 |

## 7. 잔여 (Inc2와 별개 — 더 이후)

- **역방향 "미검증 명세"**(PRD claim 후보 + 저신뢰 리포트, codex 보수안) → **2b-4 후보**. feature↔PRD 교차가 이쪽으로 흡수될 수도 있음(brainstorming 판단).
- **binding index**(중복 PRD canonical override) — YAGNI, 중복이 실제 문제 될 때.
- **Architect PRE-RED 강제 PRD 작성**(게이트) — 파이프라인 동작 변경. gemini 경고(검증 도구 없이 PRD 양산=환각). 신중히.
- **doc-freshness 글로빙**(`product-specs/**`) — Inc1에서 mtime 노이즈로 기각. 가치 입증 시 PRD 전용 별도 출력으로 재검토.
- 별개 cleanup(비차단, docs-hygiene): `harness-setup/SKILL.md`·`CLAUDE.md` "19개 파일" → 실제 24개 드리프트 + scaffold §5.14 "8항목"·⑨ 인라인 갭(Inc1 최종 리뷰 Minor #2).

---

## 참고
- 이슈 #15(3단계 파이프라인). Inc1 = PR #20(base=`feature/phase-2b-1-prd-substrate`), v1.28.0 태그는 머지 시점.
- 머지 순서: PR #19(2b-1+2b-2) → PR #20(2b-3 Inc1) → (Inc2 PR).
- Inc1 멀티모델 자문 아티팩트: `.claude/artifacts/consult/codex-…16-09-17.md`·`gemini-…16-10-45.md`.
