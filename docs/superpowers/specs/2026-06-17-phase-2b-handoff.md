# Phase 2b Handoff — Traceability Substrate (이슈 #15)

> 작성일: 2026-06-17
> 상태: **미착수** — 다음 세션의 brainstorming 진입점
> 선행: Phase 1(수집, v1.24.0) + Phase 2a(증류, v1.25.0) **main 머지 완료**

---

## 1. 현재 상태 (where things stand)

이슈 #15는 `대화 → 영속 원장 → 주기적 증류`의 3단계 파이프라인이다. 진행:

| 페이즈 | 내용 | 산출물 | 상태 |
|--------|------|--------|------|
| Phase 1 | **수집** | `.harness-intent.jsonl`(append-only, always-on) · `INTENT_LEDGER.md` · session-routine § 의도 로그 Step 4.2 | ✅ main (v1.24.0, PR #17 MERGED) |
| Phase 2a | **증류** | `intent-distill` 스킬 · `INTENT_BACKLOG.md`(영속 백로그) · 5-상태 derive · 세션종료 nudge · 격주 B1 | ✅ main (v1.25.0, PR #18 main 경유 머지) |
| **Phase 2b** | **추적** | PRD substrate · 양방향 바인딩 · 미검증 명세 방향 | ⬜ **이 문서** |

현재 코드는 모두 `main`에 있다. `intent-distill`이 의도→`@feature` E2E 커버리지를 백로그로 산출하지만, **PRD 쪽은 아직 비어 있다**.

## 2. Phase 2b가 무엇인가 (scope)

Phase 2a는 의도의 **E2E 커버리지**만 다뤘다(의도적 비-스코프). Phase 2b는 **PRD 출력단**을 채우고 추적을 양방향으로 닫는다:

1. **PRD substrate 구축** — `docs/product-specs/`를 *구조화된 링크 가능 아티팩트*로 만든다(현재 빈 디렉토리).
2. **`feature_list.id → PRD 섹션` 링크 필드** — 현재 부재. (예: `prd_section_ref`)
3. **양방향 바인딩** — 의도 ↔ `feature_list.steps` ↔ `@feature:{id}` ↔ PRD 섹션을 ID로 묶어 양방향 추적.
4. **intent-distill 확장 — PRD 커버리지 방향** — 의도가 PRD에 반영됐는지 derive(2a의 E2E 방향과 평행).
5. **"미검증 명세" 방향** — "PRD에 있는데 의도 원장에 근거 없음" = 검증되지 않은 명세를 표면화(2a는 이 방향이 불가능했음 — 구조화 PRD 부재).

## 3. 왜 (motivation) — 발견된 갭

Phase 1 컨텍스트 매핑에서 확정(`2026-06-17-intent-ledger-capture-design.md §12.1`):

- ❌ `docs/product-specs/`·`docs/design-docs/`·`docs/exec-plans/`는 scaffold가 **빈 디렉토리**로만 생성(내용 템플릿·구조 없음 — harness-scaffold §5 Phase 2, line ~202).
- ❌ `feature_list.json` 스키마 `{id, category, priority, description, steps, passes, last_session, notes}`에 **PRD 링크 필드 없음**(harness-scaffold §5.3, line ~403).
- ✅ 반면 `feature_list.id ↔ @feature:{id} ↔ E2E` 추적은 **실재·동작**(coding-standards.md steps↔L4 E2E 1:1, test-engineer `@feature` 태그).

즉 "의도 ↔ PRD" 바인딩은 단순 배선이 아니라 **빠진 프리미티브**다. 근거 사례 HAJA F007: PRD가 "각 날만 집계 / someday 제외"를 한 번도 명세하지 않아 버그가 2개월 생존 — *PRD를 의도로부터 채우는* 경로가 이 페이즈의 핵심 가치.

## 4. 상속된 결정·제약 (Phase 1/2a에서)

Phase 2b는 다음을 *반드시* 따른다(이미 확립·검증됨):

- **derive + 증거**(stored flag 신뢰 금지) — "문서-실구조 일치" 원칙. 2a의 5-상태(covered/partial/missing/ambiguous/invalid-feature) 패턴.
- **영속 백로그 모델**(`INTENT_BACKLOG.md`, 머지·idempotent·키=ts·waiver/주석 보존) — 이산 gh 이슈 아님.
- **`encoded` 비권위** — distill 미갱신. 권위는 derive된 백로그/리포트.
- **harness-feedback과 분리** — intent-distill 별도 lean 스킬. (Phase 2b도 별도 스킬 신설보다 intent-distill 확장이 자연스러울 가능성 — brainstorming에서 판단.)
- **gh 비결합**(항목별 옵트인, 현재 repo) · **always-on**(프로필 필드 0 지향) · **이스케이프**(gh/markdown 안전).
- **멀티모델 자문 권장** — 2a에서 codex/gemini가 설계를 크게 개선(이벤트→백로그 모델 전환). 2b도 PRD 구조 결정 전 자문 권장.

## 5. 핵심 미결정 (brainstorming에서 풀 것)

- **PRD 구조**: per-feature 파일(`docs/product-specs/{featureID}-prd.md`)인가, 단일 PRD에 섹션인가, frontmatter 규약인가? (스택 비종속 유지 필요.)
- **링크 필드 위치**: `feature_list.prd_section_ref`(스키마 변경 — `data` 아티팩트)인가, PRD frontmatter의 `feature: F007`인가, 별도 매핑 파일인가?
- **PRD 커버리지 derive**: intent-distill의 5-상태를 PRD 방향으로 확장(intent→PRD 반영 여부)인가, 별도 분석 단계인가?
- **백로그 통합**: `INTENT_BACKLOG.md`에 PRD 컬럼 추가인가, 별도 "미검증 명세" 리포트인가?
- **PRD 섹션 ID 스킴**: `@feature:{id}`는 존재. PRD 섹션은 어떻게 식별·앵커하나?
- **scaffold 범위**: PRD 템플릿을 scaffold가 생성하나(빈 구조), 아니면 intent-distill이 첫 실행 시 생성하나?
- **스코프 분해**: 2b도 클 수 있다 — PRD substrate(구조+필드) / 양방향 바인딩+미검증 명세 방향을 2b-1, 2b-2로 더 쪼갤지 판단.

## 6. 진입점 (다음 세션 시작 방법)

1. 세션 시작 루틴: `.tracking/HANDOFF.md` → 이 문서.
2. **brainstorming 스킬**로 Phase 2b 설계 시작 — 스코프 분해부터(§5 미결정 다수).
3. PRD 구조 결정 전 **multi-model-consult** 권장(2a 선례 — 자문이 설계를 크게 바꿨음).
4. 선행 읽기:
   - `docs/superpowers/specs/2026-06-17-intent-ledger-capture-design.md` (Phase 1, 특히 §12.1 PRD 갭)
   - `docs/superpowers/specs/2026-06-17-intent-distill-design.md` (Phase 2a, 특히 §14 비-스코프 = 2b 범위)
   - `skills/intent-distill/SKILL.md` (확장 지점 = §4 커버리지 파생, §6 리포트)

## 7. 관련 파일·앵커 (Phase 2b가 만질 곳)

| 영역 | 파일·앵커 | 비고 |
|------|-----------|------|
| feature_list 스키마 | `harness-scaffold/SKILL.md §5.3`(~line 403) `{id,category,priority,description,steps,passes,...}` | `prd_section_ref` 추가 후보. `data` 아티팩트 |
| docs 디렉토리 생성 | `harness-scaffold/SKILL.md §5` Phase 2(~line 202) `docs/product-specs/`·`design-docs/`·`exec-plans/` 빈 생성 | PRD 구조/템플릿 추가 지점 |
| E2E 추적 규약 | `templates/rules/coding-standards.md` (steps↔L4 E2E 1:1, `@feature:{id}`) · `templates/agents/test-engineer.md` | 기존 추적 프리미티브(재사용) |
| distill 확장 | `skills/intent-distill/SKILL.md` §4 파생 / §6 리포트 | PRD 방향 추가 |
| 운영 사이클 | `harness-cleanup` 월간 M1(문서-실구조)·격주 B1 | PRD 검토 편입 후보 |
| 능력 게이팅 | `harness-scaffold/SKILL.md §7` | PRD 추적 능력 줄 |

## 8. 별개 cleanup (Phase 2b와 무관 — 기존 드리프트)

최종 리뷰에서 발견(비차단, 후속 docs-hygiene 또는 harness-cleanup doc-freshness 항목으로):

- `skills/harness-setup/SKILL.md`·`CLAUDE.md`의 **"19개 파일" 생성 수 표기** — 실제 22개(Phase 1이 +2, Phase 2a가 +1). `harness-scaffold/SKILL.md:36`은 22로 정정됨. 세 파일 카운트 불일치(19/22)는 Phase-1 이전부터의 기존 드리프트 — 전수 스윕 필요.

---

## 참고
- 이슈 #15 (3단계 파이프라인 원 제안), Phase 1 PR #17(merged), Phase 2a PR #18(main 경유 머지)
- 태그: v1.24.0(Phase 1) · v1.25.0(Phase 2a)
- 멀티모델 자문 아티팩트(Phase 2a): `.claude/artifacts/consult/codex-…-09-05-38.md` · `gemini-…-09-06-30.md`
