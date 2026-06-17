# 설계: Intent→PRD Coverage Derive — Phase 2b-2 (이슈 #15)

> 작성일: 2026-06-17
> 상태: 설계 확정 (spec 작성 — 사용자 검토 → writing-plans)
> 이슈: #15 Phase 2b (추적). Phase 2b-1(PRD substrate)의 fast-follow — substrate를 live하게 만드는 derive.
> 스코프: **intent-distill의 forward PRD 커버리지 방향만**. 역방향("미검증 명세")·정적 harness-check 검증·binding index·PRE-RED 게이트는 비-스코프.
> 멀티모델 자문 1회: codex(결함)·gemini(단순화/운영) 반영 — `.claude/artifacts/consult/codex-…13-32-37.md`·`gemini-…13-33-16.md`.

---

## 1. 문제

Phase 2b-1은 PRD substrate(`docs/product-specs/{id}-{slug}.md` + whole-line `@feature` 바인딩 + 섹션 앵커)를 깔았지만 **derive가 없어 inert하다** — 두 멀티모델 자문 모두 "substrate만으론 빈 디렉토리 + README 연극"이라 경고했고, 그 해소가 이 fast-follow다. Phase 2a가 의도↔`@feature` **E2E** 커버리지를 `INTENT_BACKLOG.md`로 derive하듯, 2b-2는 의도↔`@feature` **PRD** 커버리지를 같은 백로그에 derive해 추적을 출력단까지 닫는다.

핵심 가치 = **비대칭 신호**: 한 의도가 PRD엔 있으나 E2E엔 없으면(specced-but-untested) "테스트를 짜야 한다", E2E엔 있으나 PRD엔 없으면(tested-but-unspecced = F007 클래스) "명세를 박아야 한다" — 서로 다른 행동. Phase 1의 `encoded:{prd,e2e,test}` 스키마가 이미 이 다차원을 예고했다(2a가 e2e, 2b-2가 prd).

## 2. 목표 / 비목표

**목표 (2b-2)**
- intent-distill에 **forward PRD 커버리지 derive**를 추가한다 — 각 의도가 해당 feature PRD에 반영됐는지 실구조에서 파생(증거 필수, 저장 flag 불신 — 2a 원칙 상속).
- `INTENT_BACKLOG.md`를 **2차원**(prd_state + e2e_state)으로 확장하되, substrate 부재를 미커버와 **명확히 구분**한다.
- PRD 산문의 약한 증거력을 보수적 판정(불확실=ambiguous, 빈 섹션·템플릿 주석 covered 금지)으로 방어한다.
- 기존 운영 기계 재사용 — 새 루틴 0(격주 B1에 PRD 차원 자연 편입), waiver로 dead-letter 방지.

**비목표 (별도 증분/이연)**
- **역방향 "미검증 명세"**(PRD에 있으나 의도 근거 없음) — 두 자문 모두 노이즈 폭탄으로 지목. 가치 입증 시 codex식 보수적 "claim 후보(저신뢰 리포트)"로 별도 증분(2b-4 후보).
- 정적 harness-check 검증(빈 섹션 경고·feature↔PRD 교차·마커 검증·8-상태 taxonomy) → **2b-3**.
- doc-freshness 글로빙 · binding index(중복 PRD canonical override) · Architect PRE-RED **강제** PRD 작성(게이트).

**비목표 (영구)**
- `encoded` 갱신(비권위 capture-time 스냅샷, derived-live — 2a 선례). 원장 스키마 변경. 프로필 필드 추가(always-on). harness-feedback 통합.

## 3. 핵심 설계 결정 (멀티모델 자문 반영)

| ID | 결정 | 선택 | 근거 (자문) |
|----|------|------|-------------|
| D1 | 스킬 배치 | **intent-distill 단일 스킬에 PRD derive 스테이지 추가**(E2E와 병렬) | gemini·codex 합의 — 스킬 분리는 I/O 마찰·컨텍스트 비용. "원장→현재 워크스페이스 상태 증류" 본질 동일. |
| D2 | PRD 상태 모델 | **5-상태(covered/partial/missing/ambiguous/invalid) + substrate-부재 전용 `blocked:no-prd-substrate`** | codex(critical) — `docs/product-specs/` 부재를 `prd_state=missing`으로 찍으면 "PRD에 반영 안 됨"이라는 거짓 제품 결론. `missing`(substrate 有, 미커버) ≠ `blocked`(substrate 無, 판정 불가). gemini의 3-상태(Missing/Present/Outdated)는 5-상태를 런타임 Failing/Flaky로 오해한 전제라 기각 — 5-상태는 *커버리지*라 PRD에도 유효. |
| D3 | derive 보수성 | **불확실=ambiguous 기본 · 빈 섹션·템플릿 주석 covered 절대 금지** | codex — PRD 산문은 E2E 테스트 타이틀보다 약한 증거. covered 문턱 상향(핵심 행위+대상+조건/예외 명시 시에만). 2b-1 anti-blank 가이드 텍스트·HTML 주석을 명세로 오인하면 false-covered 직결. |
| D4 | derive 탐색 | **kind↔섹션 기대 매핑** — `intended`→behavior/acceptance, `unintended`→edge-cases/open-questions | codex — 엉뚱한 섹션 매칭·excluded-behavior 오탐 방지. 섹션 앵커는 경계로만 사용. |
| D5 | 백로그 표현 | **2차원 압축 + derived/user 분리** — `prd_state`·`e2e_state` 컬럼 + 통합 `evidence`, 사용자 편집은 `priority/비고` 단일 | gemini(4컬럼 가독성 훼손→압축) + codex(derived 재작성 vs 사용자 영역 분리→idempotency). 둘 다 수용. |
| D6 | 게이팅 | **차원별 독립** — e2e/specs · docs/product-specs 각자 자기 차원 게이트. 4조합 매트릭스, 둘 다 無=판정 불가 | codex — `missing`/`보류` 절대 동일 표면 금지. 2a의 "E2E 부재→전체 보류"를 차원별로 분해. |
| D7 | 마이그레이션 | **skill-내부 one-way 승격** — 첫 derive가 기존 E2E-only 행 변환, **미지 컬럼 보존** | codex — `state→e2e_state`/구 `evidence`→통합 `evidence`의 e2e 부분/`prd_state`→`blocked:no-prd-substrate` 후 재derive. key=ts만으론 불충분(사용자 표 확장 대비 미지 컬럼 보존). INTENT_BACKLOG는 data 파일이라 scaffold 레지스트리 항목 불필요. |
| D8 | waiver | **기존 `## waiver` 재사용 + "PRD 불필요" 메모 존중** | gemini — dead-letter 방지. 사소한 변경에 PRD 강제 안 함. waiver/비고가 다음 derive에서 `missing` 재출현 차단. |
| D9 | 역방향 | **2b-2에서 제외(forward-only)** | codex·gemini 강한 합의 — PRD는 의도보다 풍부가 정상, 역방향은 90%+ 오탐. 가치 입증 시 별도 증분. |

## 4. 구성요소

### 4.1 `skills/intent-distill/SKILL.md` (주 변경)

현재 파이프라인(8단계)을 2차원으로 확장한다. **§ 번호는 구현 시 확정**(현 구조: §1 원장→§2 백로그→§3 E2E 계층→§4 derive→§5 머지→§6 리포트→§7 이스케이프→§8 gh).

**(a) §3 substrate 확인 — 차원별로 일반화**
- 기존 "E2E 계층 확인(e2e/specs 없으면 전체 보류 종료)"을 **두 독립 확인**으로:
  - `e2e/specs/*.e2e.ts` 존재 → E2E derive 가능, 아니면 모든 의도 `e2e_state = blocked:no-e2e-substrate`.
  - `docs/product-specs/` 존재(README/_template 외 바인딩 가능한 PRD 또는 최소 substrate) → PRD derive 가능, 아니면 `prd_state = blocked:no-prd-substrate`.
- **둘 다 부재** → "판정 불가(substrate 없음)" 리포트 후 종료(2a의 단일 보류 종료를 매트릭스로 대체).
- 한쪽만 있으면 그 차원만 derive, 다른 차원은 `blocked:*`.

**(b) §4 derive — PRD 방향 추가(forward, feature-범위, 증거 필수)**
각 의도(intended+unintended)에 대해 `prd_state` 산출(`e2e_state`는 기존 로직 유지):
1. `feature`가 `""`/feature_list 부재 → `invalid-feature`.
2. PRD substrate 부재 → `blocked:no-prd-substrate`.
3. `grep -Rl -Fx "@feature:{feature}" docs/product-specs/`로 바인딩 PRD 찾기(whole-line 리터럴, 2b-1 규칙). 없으면 → `missing`(substrate 有, 이 feature PRD 없음).
4. 바인딩 PRD 있으면 그 파일**만** 읽어 섹션 앵커(`<!-- harness:section=… -->`)로 경계 분할. **HTML 주석·템플릿 안내문·README/_template는 본문에서 제외.** kind에 맞는 섹션에서 statement 근거 탐색(D4):
   - `covered`: statement의 핵심 행위+대상+조건/예외가 PRD claim에 명시(증거: PRD 경로 + 섹션 앵커명 + 요지).
   - `partial`: feature PRD는 있으나 조건/예외/부정 방향 일부 누락.
   - `missing`: feature PRD 있으나 관련 claim 전무.
   - `ambiguous`: 표현 일반적/상위 개념뿐 또는 매칭 불확실 — **불확실 시 기본값**.
   - **빈 섹션 가드**: 기대 섹션이 주석/공백뿐이면 `covered` **절대 금지** → `missing`(증거: "기대 섹션 비어있음 — 명세 누락"). 빈 섹션 전용 *경고*는 2b-3; 여기선 false-covered 방지 목적의 derive 가드다(신규 상태 추가 없음).
5. **모든 판정 증거 필수** — 증거 없는 covered/missing 단정 금지.
- 최적화(2a 미러): 백로그에 `covered` 증거로 기록됐고 그 PRD 파일이 안 바뀌었으면 재판정 스킵.

**(c) §5 백로그 머지 — 2차원 + 마이그레이션(§5 상세)**
- 키=ts. 각 의도의 `prd_state`·`e2e_state` 모두 갱신. **둘 다 covered(또는 waiver)면 열린 백로그에서 제거**; 하나라도 actionable 갭(missing/partial/ambiguous/invalid)이면 행 유지(차원별 상태 표시). `blocked:*`만 남은 행은 "판정 불가/보류"로 유지.
- 기존 E2E-only 백로그 첫 만남 시 §5 승격 규칙 적용.
- 사용자 `priority/비고`·미지 컬럼 보존, `## waiver` 미수정.

**(d) §6 리포트 — 2차원**
- 차원별 카운트(PRD: covered/partial/missing/ambiguous/blocked · E2E: 동일) + **비대칭 하이라이트**(specced-untested: prd≥covered & e2e=missing / tested-unspecced: e2e≥covered & prd=missing) + 보류(substrate 부재) 구분.

**(e) §8 gh 옵트인** — 기존 항목별 옵트인 유지. PRD 갭 항목도 동일 이스케이프(§7).

### 4.2 `skills/harness-scaffold/templates/INTENT_BACKLOG.md` (헤더 변경)

신규 셋업이 2차원 헤더로 생성되도록 템플릿 표 헤더를 갱신:
```markdown
## 열린 백로그
> derived 컬럼(prd_state·e2e_state·evidence)은 intent-distill이 매 실행 재산출. 사용자 편집은 priority/비고 컬럼만.
| key(ts) | feature | surface | kind | statement | prd_state | e2e_state | evidence | priority/비고 |
|---------|---------|---------|------|-----------|-----------|-----------|----------|---------------|

## waiver (재추가 안 함)
| key(ts) | statement | 사유 |
```
- 카테고리 `data` 불변(§10.1 22-f). 기존 target 파일은 다음 derive가 §5로 마이그레이션. 신규 플레이스홀더 0(정적 헤더).

### 4.3 `skills/harness-scaffold/SKILL.md` §7 capability (정직 문구 갱신)

- 2b-1 "의도 증류" 줄: "@feature E2E와 대조" → **"@feature PRD·E2E와 대조해 2차원 커버리지 동기화"**.
- 2b-1 "PRD 명세" 줄의 "커버리지 derive는 후속" → **derive 출시 반영**("의도↔PRD 커버리지는 '의도 정리'가 derive").
- always-on 불변. 순수 투영(미와이어 능력 광고 불가) 규칙 유지.

### 4.4 `harness-cleanup` 격주 B1 (편입 — 텍스트 1줄)

- 기존 B1(INTENT_BACKLOG 검토)에 "PRD 차원도 검토 — specced-untested→E2E 작성, tested-unspecced→PRD 작성" 한 줄. **신규 루틴 0**(D7/gemini).

## 5. 백로그 스키마 + 마이그레이션 (one-way 승격)

첫 2b-2 derive가 기존 E2E-only 백로그를 만나면(헤더에 `state`/`evidence` 단일 컬럼):
1. `state` → `e2e_state`로 승격(값 그대로).
2. `evidence` → `evidence`의 e2e 부분으로 이동.
3. `prd_state` 신규 컬럼 → 이번 실행에서 derive(substrate 없으면 `blocked:no-prd-substrate`).
4. `priority/비고` → key=ts 매칭 보존. **헤더에 없던 사용자 추가 컬럼은 그대로 보존**(끝에 유지).
5. waiver 표는 미수정.
- → 멱등: 같은 입력 = 같은 백로그(derived 컬럼만 재작성, 사용자 컬럼 불변). PRD 산문 요지 증거는 안정적 표현 규칙(핵심 명사·조건 인용)으로 diff 최소화.

## 6. 데이터 흐름
```
[온디맨드/B1] "의도 정리"
  → .harness-intent.jsonl + INTENT_BACKLOG.md 읽기(+ 구 포맷 감지)
  → substrate 차원별 확인 (e2e/specs · docs/product-specs — 독립)
  → 각 의도: PRD derive(@feature PRD, feature-범위, 5-상태+blocked, 보수적) ∥ E2E derive(2a)
  → 백로그 머지(2차원, one-way 승격, 미지 컬럼·priority/비고·waiver 보존, idempotent)
  → 리포트(차원별 카운트 + 비대칭 하이라이트 + 보류 구분) → (옵트인) 항목별 gh 이슈
  → 백로그 커밋
[격주 B1] 2차원 백로그 검토 → specced-untested→E2E / tested-unspecced→PRD 승격
```

## 7. degradation / 엣지 케이스

| 상황 | 처리 |
|------|------|
| `docs/product-specs/` 부재 | `prd_state=blocked:no-prd-substrate` (≠ missing). e2e만 derive |
| `e2e/specs` 부재 | `e2e_state=blocked:no-e2e-substrate`. prd만 derive |
| 둘 다 부재 | "판정 불가(substrate 없음)" 리포트 종료 |
| feature PRD 없음(substrate 有) | `prd_state=missing` (작성 후보) |
| 빈 Edge Cases(주석/공백뿐) | `covered` 절대 금지 → `missing`(증거: 섹션 비어있음). 빈섹션 *경고*는 2b-3 |
| 한 feature에 PRD 복수 | 모두 대조, 하나라도 매칭 시 covered. 중복 자체 경고는 2b-3 |
| PRD 본문에 `@feature:` 인라인/코드블록 예시 | whole-line `-Fx`라 미매칭(2b-1 가드) |
| 구 포맷 백로그(E2E-only) | §5 one-way 승격(미지 컬럼 보존) |
| 사용자 "PRD 불필요" 메모/waiver | 다음 derive가 missing 재출현 안 시킴(D8) |
| PRD 산문 약한 증거 | 기본 `ambiguous`(covered 문턱 상향) |

## 8. 계약·정합성 (CLAUDE.md 개발 규칙)

- ✅ **원장 스키마 불변** · `encoded` 미갱신(derived-live). 프로필 필드 0 · 신규 플레이스홀더 0.
- ✅ **2b-1 substrate 계약 재사용**(whole-line `@feature` 바인딩·섹션 앵커) — 새 바인딩 프리미티브 도입 0.
- ✅ harness-feedback 불변 · 골든 픽스처(structural-test) 무영향.
- ✅ INTENT_BACKLOG `data` 카테고리 불변 — 스키마 확장은 distill 내부 마이그레이션(scaffold 레지스트리 무변경).
- ✅ E2E derive(2a) 회귀 0 — 기존 로직 유지, PRD는 병렬 추가.

## 9. 버전 / 마이그레이션

- intent-distill 스킬 derive 확장 + INTENT_BACKLOG 템플릿 헤더 + capability 문구 + B1 1줄. 기존 호환(가산). **MINOR: 1.26.0 → 1.27.0**.
- 범프 동시 대상: project-context.md·CHANGELOG.md·plugin.json·marketplace.json(버전 필드 부재 시 스킵)·README.md·git tag(병합 시).
- **scaffold 마이그레이션 레지스트리 불필요**: INTENT_BACKLOG는 data 파일이라 업그레이드가 덮어쓰지 않고, 첫 derive가 skill-내부에서 승격. 신규 셋업은 2차원 헤더 템플릿 사용. intent-distill SKILL.md 자체는 플러그인 번들이라 설치 시 갱신.

## 10. 검증 계획

- **PRD derive**(시나리오): covered/partial/missing/ambiguous/invalid 각 + 증거 / 빈 Edge Cases→covered 금지 / 템플릿 주석·README 제외 / kind↔섹션 기대 / feature-범위 한정 / 보수적 ambiguous 기본.
- **게이팅 매트릭스**: 4조합(PRD有E2E有 / PRD有E2E無 / PRD無E2E有 / PRD無E2E無) 각각 상태·리포트 구분(missing≠blocked).
- **백로그 마이그레이션**: 구 E2E-only→2차원 승격 / 미지 컬럼 보존 / priority·비고·waiver 보존 / idempotent(재실행 동일).
- **2차원 머지**: 둘 다 covered 제거 / 한 차원 갭 유지 / blocked-only 보류 유지.
- **계약 회귀**: 원장 스키마·encoded 불변 / E2E derive 무회귀 / 골든 픽스처 무영향 / 신규 플레이스홀더 0.
- 신규 픽스처: `test/intent-prd-coverage-fixtures.sh`(가칭) — feedback-cursor·prd-substrate 픽스처 패턴 미러(derive 판정 로직은 LLM이라 픽스처는 grep 바인딩·섹션 파싱·마이그레이션 등 결정적 부분 검증).

## 11. 수용 기준

- [ ] "의도 정리"가 각 의도의 `prd_state`를 forward derive(5-상태+blocked, 증거 필수, feature-범위)한다.
- [ ] substrate 부재가 `blocked:no-prd-substrate`로 기록되고 `missing`과 구분된다(거짓 제품 결론 방지).
- [ ] 빈 Edge Cases·템플릿 주석·README가 `covered`로 오판되지 않는다.
- [ ] INTENT_BACKLOG가 2차원(prd_state+e2e_state)이고 derived/user 컬럼이 분리·문서화된다.
- [ ] 구 E2E-only 백로그가 one-way 승격되고 priority/비고·미지 컬럼·waiver가 보존된다(idempotent).
- [ ] 리포트가 비대칭(specced-untested/tested-unspecced)과 보류를 구분 표시한다.
- [ ] 역방향("미검증 명세")은 구현하지 않는다(forward-only). encoded·원장 스키마·프로필 불변, 신규 플레이스홀더 0.
- [ ] E2E derive(2a) 회귀 없음.

## 12. 명시적 비-스코프 (별도 증분)

- **역방향 "미검증 명세"**(PRD claim 후보 + 저신뢰 리포트, codex 보수안) → 가치 입증 시 2b-4.
- 정적 harness-check 검증(빈 섹션 경고·feature↔PRD 교차 derive·마커 검증·8-상태 taxonomy) → **2b-3**.
- doc-freshness 글로빙(`product-specs/**`) · binding index(중복 PRD canonical override) · Architect PRE-RED **강제** PRD 작성(게이트).

---

## 참고
- 멀티모델 자문: `.claude/artifacts/consult/codex-…2026-06-17T13-32-37.md` · `gemini-…2026-06-17T13-33-16.md`.
- 선행: Phase 2b-1 spec `docs/superpowers/specs/2026-06-17-phase-2b-1-prd-substrate-design.md`(substrate·바인딩·섹션 앵커), Phase 2a `…intent-distill-design.md`(E2E derive 패턴·백로그 모델).
- 현행: `skills/intent-distill/SKILL.md`(확장 대상), `templates/INTENT_BACKLOG.md`(헤더), `harness-cleanup`(B1).
