# Phase 2b-3 Increment 1 설계 — PRD 마커 정적 위생 검사 (이슈 #15)

> 작성일: 2026-06-18
> 상태: **설계 승인 대기 → 구현 계획(writing-plans)**
> 선행: Phase 2b-1(PRD substrate, v1.26.0) + Phase 2b-2(forward PRD 커버리지 derive, v1.27.0)
> 진입 핸드오프: `docs/superpowers/specs/2026-06-18-phase-2b-3-handoff.md`
> 목표 버전: **v1.28.0** (MINOR, 하위 호환, 마이그레이션 불필요)

---

## 0. 한 줄 요약

`harness-check.sh`에 **경고-전용 섹션 ⑩ PRD 위생**을 추가해, *이미 작성된* PRD 파일의 **결정적 마커 위반 5종**을 `grep` + `node -e`만으로 상시 잡는다. awk·신규 파일·신규 플레이스홀더 0.

## 1. 배경 & 동기

이슈 #15 파이프라인: `대화 → 영속 원장(.harness-intent.jsonl) → 증류(intent-distill, LLM) → 추적(Phase 2b)`.

- **2b-1** (v1.26.0): PRD substrate — `docs/product-specs/{id}-{slug}.md` + whole-line `@feature:{id}` 바인딩(`grep -Fx`) + 섹션 앵커 + anti-blank 가이드. managed 템플릿 README.md·_template.md.
- **2b-2** (v1.27.0): intent-distill에 forward PRD 커버리지 derive(런타임·LLM·시맨틱).
- **2b-3** (이 문서, Increment 1): 그 **정적·결정적 보완**. derive(LLM)는 비용·비결정성이 있고 의도→PRD 매핑의 *의미*를 본다. 반면 substrate **구조 위생**(orphan 마커, 중복 바인딩, 파일명-마커 불일치 등)은 **결정적·저비용**이라 `npm run harness:check`가 상시 잡는 게 옳다. 2b-1은 substrate **존재**(README/_template)만 구조 검사했고, *작성된 PRD*의 마커 위생은 미검증으로 남겼다 — 그 갭이 2b-3 Increment 1이다.

## 2. 멀티모델 자문 요지 (설계 근거)

codex(결함)·gemini(대안/단순화) 자문 결과(아티팩트: `.claude/artifacts/consult/codex-…16-09-17.md`·`gemini-…16-10-45.md`)가 강하게 수렴:

- **exit 0 경고-전용** — PRD 위생 위반을 exit 1로 올리면 "PRD를 실험적으로 작성하는 순간 `harness:check`가 깨져 adoption 방해". managed substrate 부재만 기존대로 exit 1.
- **8-상태 taxonomy는 과설계(YAGNI)** — 결정적으로 판정 가능한 위반만 라벨로 출력, **상태 영속화 금지**. `ambiguous-marker`·`stub-only`는 시맨틱이라 정적 판정 시 오탐.
- **doc-freshness 글로빙은 빼거나 분리** — mtime 기준이라 "완료·안정된 PRD"가 계속 stale 경고 → 개발자가 경고를 무시하게 됨. PRD 품질은 시간이 아니라 *내용*으로 봐야 함.
- **스코프 분해 필수** — 결정적 검사 + 시맨틱-경계 검사 + 운영 정책 변경을 한 릴리스에 섞지 말 것.
- **awk 인라인 3중화 금지** — `prd_section_body`를 harness-check.sh에 또 복붙하면 intent-distill과 같은 PRD를 다르게 판정할 위험.

**합성 통찰(핸드오프·자문을 넘는 결정)**: Increment 1의 5종 마커 검사는 **전부 순수 grep + 파일명 파싱 + feature_list 집합 조회**라 `prd_section_body` awk가 필요 없다. 따라서 awk 3중화·bash 파싱 한계 우려는 Increment 1엔 적용되지 않고, 모두 *내용 파싱*이 필요한 **Increment 2(빈 섹션)**로 미뤄진다. 이것이 "마커 위생 먼저, 내용 위생 나중" 분해의 근거다.

## 3. 스코프 & 경계

### 3.1 검사 대상 집합
`docs/product-specs/*.md` 중 `README.md`·`_template.md` **제외** (기존 ① 구조검사의 `grep -cvE '/(README|_template)\.md$'` 미러 — 템플릿의 `@feature:F000` 예시 오탐 방지).

### 3.2 보류(⏸️, exit 0)
- substrate 부재(`docs/product-specs/` 또는 README/_template 없음) → ⑩ 자체 보류. (substrate 부재의 exit 1 판정은 기존 ① 소관이며 ⑩은 중복 판정하지 않는다.)
- 작성된 PRD 0개 → ⑩ 보류 ("새 프로젝트 정상" — 기존 ① 정책 미러).

### 3.3 검사 위치
`harness-check.sh` 종합 판정 직전, ⑨ 다음에 **새 섹션 ⑩ PRD 위생**. ⑥⑦⑧⑨와 동급 경고 전용 — `STRUCT_FAIL`/`QUALITY_FAIL`/exit code에 **무영향**.

## 4. 검사 항목 5종 (전부 ⚠️ 경고, exit 0)

각 대상 PRD 파일의 전체줄 마커를 카운트한다:
```bash
# 전체줄 @feature 마커 카운트 (2b-1 grep -Fx 전체줄 규칙의 정규식 근사)
grep -cE '^@feature:[^[:space:]]+$' "$prd"
# 마커 id 추출 (마커 정확히 1개일 때)
grep -oE '^@feature:[^[:space:]]+$' "$prd" | head -1 | sed 's/^@feature://'
```
feature_list.json 유효 id 집합:
```bash
node -e "const a=require('./feature_list.json'); process.stdout.write(a.map(f=>f.id).join('\n'))"
```

| # | 라벨 | 결정적 규칙 | 잡는 실수 |
|---|------|------------|----------|
| 1 | `unbound-prd` | 전체줄 마커 **0개** | PRD 작성했는데 바인딩 누락 → derive에 안 보임 |
| 2 | `multiple-markers` | 전체줄 마커 **2개+** | 바인딩 모호 |
| 3 | `invalid-feature` | 마커 id ∉ feature_list.json id 집합 | 오타·`F000` 방치·미등록 |
| 4 | `file-marker-mismatch` | (§4.1 규칙) 파일명이 가리키는 유효 id ≠ 마커 id | 복사붙여넣기 id 오류 |
| 5 | `duplicate-binding` | 같은 마커 id를 PRD **2개+**가 바인딩 | canonical 불명 |

위반 0건 → `✅ PRD 마커 위생 정상`.

### 4.1 검사 4(file-marker-mismatch) 파일명 id 추출 규칙 — 하이픈 id 안전
feature id가 하이픈을 포함할 수 있으므로(`F-infra-0`) "첫 `-` 분리"는 **틀린다**. 대신 **유효 id 접두 매칭**:

1. 검사 대상은 마커가 **정확히 1개**인 파일만(0/2개는 검사 1·2 소관).
2. 파일명(`basename`)이 `{markerId}-`로 시작하거나 `{markerId}.md`와 같으면 → **일치, 무경고**.
3. 아니면 feature_list 유효 id 중 `{id}-`가 파일명 접두인 **가장 긴 id**를 찾는다.
   - 그런 id가 있고 markerId와 다르면 → **mismatch 경고**(파일명은 `{fileId}`, 마커는 `{markerId}`).
   - 어떤 유효 id도 접두가 아니면(slug-only 파일명, 예 `progress-chart.md`) → **침묵**. README가 slug 파일명을 허용하고 "slug는 바인딩 권위 아님"(README 작성방법 §9)이라 명시하므로 오탐 금지.

## 5. 오탐 가드 (보수성 — 자문 합의)
- README.md·_template.md 제외 → 템플릿 `@feature:F000` 예시 미오인.
- 검사 4는 파일명 선행 세그먼트가 **유효 feature id일 때만** 발동 → slug-only 파일명 침묵.
- **전체줄 마커만** 카운트(`^@feature:…$`) → 본문 인라인·코드블록·산문 속 `@feature:` 미오인 (2b-1 `grep -Fx` 원칙 계승).
- 모호하면 침묵 — 결정적·명확한 위반만 경고 (역방향 "미검증 명세"를 노이즈로 뺀 2b-2 원칙과 동일 테마).

## 6. exit 정책 & 8-상태 라벨 축소
- **전부 exit 0 경고** (⑥⑦⑧⑨ 동급). orphan/duplicate/mismatch도 exit 1 아님. managed substrate(README/_template) 부재만 기존 ① 그대로 exit 1.
- 핸드오프 **8-상태 중 5개만 정적 출력**: 위 표의 5라벨. **기각**: `ambiguous-marker`(시맨틱), `stub-only`(→ Inc2 빈섹션). 정상상태(`bound`/`no-prds-yet`/`substrate-missing`)는 라벨이 아니라 `✅`/`⏸️`로 표현.
- **상태 영속화 없음** — stdout 경고만. manifest 미기록, 별도 리포트 파일 없음 (운영 단순성 — gemini).

## 7. 동기화 지점 (계약 — 반드시 함께 수정)
| 영역 | 파일·앵커 | 변경 |
|------|-----------|------|
| 검사 본체 | `skills/harness-scaffold/templates/harness-check.sh` | ⑩ 섹션 신규 (⑨ 다음, 종합 판정 전) |
| 검사 SSoT | `skills/harness-setup/references/harness-checklist.md` §8·§1.1 | ⑩ 항목 + 판정 정책(경고 전용) 명시 |
| scaffold 사양 | `skills/harness-scaffold/SKILL.md` §5.14(harness-check 생성 규칙)·§6.13(자가진단 실행 검증) | ⑩ 추가 기술, 카운트 정합 |
| 골든 픽스처 | `test/prd-marker-hygiene-fixtures.sh` (신규) | 5종 위반 각 감지 + 정상 무경고 + 부재 보류 |
| 자동 감지 | harness-check.sh = managed → §12.6 재렌더링 전파 | **마이그레이션 불필요** |

**신규 플레이스홀더 0** — ⑩은 새 치환 토큰을 도입하지 않는다(검사 대상 경로·마커 패턴은 하드코딩 상수). 프로필 필드 0, 카테고리 불변.

## 8. 검증 계획
- **골든 픽스처** `test/prd-marker-hygiene-fixtures.sh` (기존 `test/prd-substrate-fixtures.sh` 패턴 미러):
  - T1 정상 PRD(마커 1개·유효 id·파일명 일치) → 무경고, ✅
  - T2 `unbound-prd`(마커 0) → 경고 1, exit 0
  - T3 `multiple-markers`(마커 2) → 경고 1, exit 0
  - T4 `invalid-feature`(마커 id ∉ feature_list) → 경고 1, exit 0
  - T5 `file-marker-mismatch`(파일명 `F001-…`, 마커 `F002`) → 경고 1, exit 0
  - T6 `duplicate-binding`(두 PRD 같은 id) → 경고, exit 0
  - T7 하이픈 id(`F-infra-0-…md`, 마커 `F-infra-0`) → 일치 무경고 (§4.1 회귀)
  - T8 slug-only 파일명(`progress-chart.md`, 마커 유효) → mismatch 침묵
  - T9 substrate 부재 → ⏸️ 보류, exit 0
  - T10 작성 PRD 0개 → ⏸️ 보류, exit 0
  - T11 README/_template의 `@feature:F000` → 검사 제외(경고 0)
- **회귀**: `bash test/run-fixtures.sh` + 기존 PRD 픽스처(`prd-substrate-fixtures.sh`·`intent-prd-coverage-fixtures.sh`) 통과.
- **렌더 후 실측**: harness-check.sh 치환본을 픽스처 프로젝트에 두고 ⑩ 출력·exit code 직접 확인(구조 정상 시 exit 0 유지).

## 9. 명시적 비-스코프 (이연/기각 — 추적용)
- **feature↔PRD 교차**(PRD 없는 feature 표면화) → **Increment 2**. README "PRD 없음 정상(온디맨드)"과 충돌해 새 프로젝트에서 경고 폭탄 위험. (사용자 결정: Increment 1 제외.)
- **빈 섹션 경고**(Edge Cases stub 탐지) → **Increment 2**. `prd_section_body` awk 필요 → 거기서 공유 헬퍼(`scripts/harness-prd-utils.sh` 등) vs 중복 결정.
- **doc-freshness 글로빙**(`product-specs/**`) → **기각**. mtime 노이즈(두 모델 반대). 필요 시 PRD 전용 별도 출력으로 재검토.
- **8-상태 영속화 / binding index(중복 PRD canonical override) / Architect PRE-RED 강제 PRD 작성** → 이연(YAGNI·파이프라인 동작 변경).

## 10. 진입점 (다음 단계)
1. 이 설계 사용자 리뷰 → 승인.
2. **writing-plans 스킬**로 구현 계획 작성.
3. 구현 후 골든 픽스처 + 렌더 후 실측 → v1.28.0 범프(project-context·CHANGELOG·plugin.json·README·git tag) + HANDOFF/TODO 갱신.

## 참고
- 이슈 #15(3단계 파이프라인). 핸드오프 `2026-06-18-phase-2b-3-handoff.md`(전체 2b-3 스코프 — 이 문서는 그중 Increment 1).
- 멀티모델 자문 아티팩트: `.claude/artifacts/consult/codex-…16-09-17.md`·`gemini-…16-10-45.md`.
- 선행 설계: `2026-06-17-phase-2b-1-prd-substrate-design.md` §11(2b-3 비-스코프)·D7, `2026-06-17-phase-2b-2-prd-coverage-derive-design.md` §12·§4.1.
