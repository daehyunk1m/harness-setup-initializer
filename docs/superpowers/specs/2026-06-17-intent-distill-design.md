# 설계: Intent Distill — Phase 2a (E2E 커버리지 백로그) (이슈 #15)

> 작성일: 2026-06-17
> 상태: 설계 확정 (spec 작성 — 사용자 검토 → writing-plans)
> 이슈: #15 Phase 2a (수집→**증류**→추적 중 증류). Phase 1(수집)은 PR #17.
> 자매: harness-feedback(프로세스 마찰 증류) — intent-distill은 제품 의도 증류
> 멀티모델 자문: codex(결함)·gemini(대안/운영) 반영 — `.claude/artifacts/consult/codex-…-09-05-38.md`·`gemini-…-09-06-30.md`
> 스코프: **E2E 커버리지 백로그만**. PRD substrate·양방향 바인딩·미검증 명세는 Phase 2b.

---

## 1. 문제

Phase 1은 의도 원장(`.harness-intent.jsonl`)을 **채우지만**, 적재된 의도가 E2E 회귀로 승격됐는지 **점검·추적할 증류기가 없다** — 의도가 쌓여도 아무도 커버리지를 보지 않아 dead-letter가 된다. friction→harness-feedback이 *프로세스 마찰*을 증류하듯, 의도 채널엔 *제품 커버리지*를 증류하는 자매가 필요하다.

**멀티모델 자문 핵심 통찰**(codex·gemini 합의): 초기 설계는 harness-feedback의 *이벤트-스트림 모델*(cursor·이산 gh 이슈·done-once)을 빌렸으나, **의도 커버리지는 지속 상태(백로그)이지 한 번 보고하고 닫는 이벤트가 아니다.** 이 모델 불일치를 바로잡는 것이 이 설계의 중심이다 → **영속 백로그 문서** 모델 채택.

## 2. 목표 / 비목표

**목표**
- 적재된 의도의 E2E 커버리지 갭을 **영속 백로그**(`docs/INTENT_BACKLOG.md`)로 산출·추적한다.
- 커버리지는 **실구조에서 파생**(derived)하고 **증거**(스펙 경로·테스트 타이틀·사유)를 붙여 "문서-실구조 일치" 원칙을 의도에 적용한다.
- **gh-비결합**: 백로그가 집이고 gh 이슈는 항목별 옵트인.
- 신규 운영 기계를 최소화 — 기존 **격주 B1 리뷰**(TECH_DEBT 검토)에 백로그 검토를 편입.

**비목표 (Phase 2b)**
- PRD substrate(`prd_section_ref` 필드·PRD 구조/템플릿), 의도↔feature↔@feature↔PRD 양방향 바인딩, "PRD에 있는데 근거 없음"(미검증 명세) 방향, PRD 반영 제안.

**비목표 (영구)**
- harness-feedback과 스킬 통합(`--source` 파라미터화) — §3 D1.
- 원장 mutation·`encoded` 갱신 — §3 D6.
- 상태 파일(cursor) — §3 D4.

## 3. 핵심 설계 결정 (멀티모델 자문 반영)

| ID | 결정 | 선택 | 근거 (자문) |
|----|------|------|-------------|
| D1 | 스킬 구조 | **별도 lean 스킬** `intent-distill` | gemini "harness-feedback에 `--source` 통합" **기각** — codex 분석대로 두 채널의 *상태 모델이 갈렸다*(영속 백로그 vs done-once 이벤트). 통합은 false-DRY. 공유 관례(관용 파싱)는 harness-feedback 참조로 중복 최소화. |
| D2 | 백로그 위치 | **영속 `docs/INTENT_BACKLOG.md`** (data) | codex·gemini 합의 — 이산 gh 이슈는 영속 백로그와 부정합(트래커 노이즈). 하네스의 기존 `TECH_DEBT.md`(영속 백로그+격주 리뷰) 패턴 미러. |
| D3 | 커버리지 판정 | **derive-then-persist + 증거 + 5-상태** (`covered/partial/missing/ambiguous/invalid-feature`) | codex 권고2(이진 금지, 증거). gemini의 환각 false-negative 우려를 **증거-강제 + feature-범위 한정**으로 완화하되, 저장-only flag의 stale(문서-실구조 일치 위반)을 피해 derive 유지. |
| D4 | 상태 파일 | **없음** — 백로그 doc이 durable 상태 | codex의 "파일 mutation 없음 vs cursor 모순" 및 cursor 의미 분기 함정을 **제거로 해소**. 세션종료 nudge는 세션-로컬 카운트만. |
| D5 | gh 역할 | **항목별 옵트인** ("이 항목만 이슈로") | gh-비결합 유지(하네스는 gh-옵셔널). 매 실행 자동 생성 폐기. |
| D6 | `encoded` 필드 | **비권위 capture-time 스냅샷** — distill 미갱신, Phase 1 문구 교정 | codex 지적 — Phase 1이 "Phase 2가 encoded 갱신"이라 해 계약 위반/오판 소지. 권위는 `INTENT_BACKLOG.md`/파생 리포트. |
| D7 | 보안 | **gh/markdown 안전 이스케이프** | codex 지적 — ≤200 소독은 JSON 안전일 뿐. table escape·HTML-comment delimiter 방어·@mention 무력화 추가. |
| D8 | 트리거 | **세션종료 경량 nudge + 온디맨드 + 격주 B1 리뷰** (신규 월간 스텝 없음) | gemini — 의도는 맥락이 신선할 때 증류돼야. 무거운 sync는 온디맨드, 리뷰는 기존 B1 재사용. |
| D9 | unintended | **E2E 회귀 백로그로 흡수** (별도 PRD 방향 아님) | 자문 합의 — 2a는 E2E only. unintended = 회귀-스펙 후보. |

## 4. 구성요소

### 4.1 `intent-distill` 스킬 (신규 컴패니언, `skills/intent-distill/SKILL.md`)
파이프라인:
1. **원장 읽기** — `.harness-intent.jsonl` **전체**(관용 파싱·깨진 줄 격리 — harness-feedback §3 패턴 재사용). 부재 시 스킵(에러 아님).
2. **백로그 읽기** — `docs/INTENT_BACKLOG.md`(열린 백로그 + waiver). 부재 시 빈 백로그.
3. **E2E 계층 확인** — 프로젝트에 E2E(`e2e/specs/`)가 없으면(미옵트인) "E2E 미설정 — 커버리지 판정 보류" 리포트 후 종료(모든 의도를 missing으로 오판하지 않음).
4. **커버리지 파생 (feature-범위)** — 각 의도(intended+unintended)에 대해 `feature_list.json` + 해당 `@feature:{feature}` E2E 스펙만 읽어 §6의 5-상태 + 증거 산출. (백로그에 covered-evidence로 마킹돼 있고 그 스펙이 안 바뀌었으면 재판정 스킵 — 최적화.)
5. **백로그 머지** (§7 규칙) — 신규 갭 추가 / 커버됨 제거 / 사용자 주석·waiver 보존. idempotent.
6. **리포트** — 변경 요약(신규 N·해소 M·triage K) + 열린 백로그 톱.
7. **gh 옵트인** — "이 항목 이슈로?"(항목별). §8 이스케이프. fingerprint `<!-- intent-gap:fp=feature:{feature}:{ts} -->` 중복 힌트(열린 이슈 대조 백스톱).
8. **백로그 쓰기** — 머지 결과를 `docs/INTENT_BACKLOG.md`에 기록(data 파일, git-workflow 규칙으로 커밋).

### 4.2 `docs/INTENT_BACKLOG.md` (신규 data 문서)
`TECH_DEBT.md`류 영속 백로그. 구조:
```markdown
# 의도 커버리지 백로그
> intent-distill이 .harness-intent.jsonl ↔ @feature E2E를 대조해 동기화. 사용자 주석·waiver는 보존됨.

## 열린 백로그
| key(ts) | feature | surface | kind | statement | state | evidence | priority/비고 |
|---------|---------|---------|------|-----------|-------|----------|---------------|

## waiver (재추가 안 함)
| key(ts) | statement | 사유 |
```
- **카테고리 `data`** — 해시 드리프트 제외, 업그레이드 미덮어쓰기. 사용자가 `priority/비고` 열·waiver 추가 가능.
- **키 = 의도 `ts`**(원장 식별자, 스키마 변경 없음). 머지가 이 키로 행을 매칭.

### 4.3 커버리지 판정 (§6 상세) — 5-상태 + 증거
간단 요약: `covered`(매칭 시나리오 존재) / `partial`(feature E2E 있으나 이 의도 미커버) / `missing`(@feature E2E 없음) / `ambiguous`(판정 불가 — 사람 필요) / `invalid-feature`(feature="" 또는 feature_list 부재). **백로그 = missing+partial+ambiguous+invalid**(triage 포함). covered는 백로그에서 제거.

### 4.4 `harness-scaffold/SKILL.md` 변경
- `templates/INTENT_BACKLOG.md`(빈 백로그 doc) 복사 생성 — 생성순서(17-f)·§5.12.x·manifest `data`·§10.1.
- **§7 능력 게이팅 갱신**: Phase 1 "수집만; 증류 미배선" → **"수집 + 증류"**. 능력 줄 갱신/추가("의도 증류 → '의도 정리'").

### 4.5 `session-routine.md` 세션종료 nudge (D8)
세션 종료 루틴에 한 줄: "이번 세션 의도 N건 적재 → '의도 정리'로 백로그 동기화 권장"(세션-로컬 카운트 — step 4.2 append 건수. 상태 파일 없음).

### 4.6 `harness-cleanup` 격주 B1 편입 (D8)
B1(TECH_DEBT 검토)에 한 줄: "INTENT_BACKLOG.md 열린 백로그 검토 — 미커버 의도를 feature_list 작업/E2E 스펙으로 승격". 신규 월간 스텝 없음.

### 4.7 Phase 1 `encoded` 문구 교정 (D6)
- `templates/INTENT_LEDGER.md`: "encoded ... Phase 2 증류가 채운다"·"Phase 2 distill이 채움" → **"encoded는 capture-time 스냅샷(비권위). 커버리지는 intent-distill이 실구조에서 파생 — 권위는 INTENT_BACKLOG.md. encoded는 갱신하지 않는다."**
- `templates/rules/session-routine.md § 의도 로그`: 동일 교정.
- Phase 1 spec `2026-06-17-intent-ledger-capture-design.md`: D4·§12의 "Phase 2 distill이 encoded 갱신" 표현 교정.

### 4.8 스킬 등록 + 버전
- `plugin.json`·`marketplace.json`에 `intent-distill` 등록(6번째 번들 스킬). 트리거 자연어: "의도 정리"·"의도 증류"·"커버리지 분석".
- 버전 `1.24.0 → 1.25.0` (MINOR). git tag는 병합 시점.

## 5. 데이터 흐름
```
[세션 종료] 의도 N건 적재(Phase 1) → 경량 nudge "백로그 동기화?"(세션-로컬)
[온디맨드/B1] "의도 정리"
  → .harness-intent.jsonl 전체 + INTENT_BACKLOG.md 읽기
  → E2E 계층 확인 (없으면 보류 종료)
  → 각 의도: @feature E2E (feature-범위) 대조 → 5-상태 + 증거 (derive)
  → INTENT_BACKLOG.md 머지-싱크 (신규/해소/주석·waiver 보존, idempotent)
  → 리포트(신규·해소·triage) → (옵트인) 항목별 gh 이슈(이스케이프)
  → 백로그 커밋
[격주 B1] INTENT_BACKLOG 검토 → feature_list/E2E 승격
```

## 6. 커버리지 판정 상세 (5-상태 기준)
| 상태 | 기준 | 증거 | 백로그 |
|------|------|------|--------|
| `covered` | feature의 `@feature:{feature}` E2E에 statement와 의미 매칭되는 시나리오 존재 | 스펙 경로 + 테스트 타이틀 | 제외(해소) |
| `partial` | feature E2E는 있으나 이 statement를 커버하는 시나리오 없음 | 스펙 경로 + 미커버 요지 | 포함 |
| `missing` | feature 비어있지 않으나 `@feature:{feature}` E2E 스펙 부재 | feature_list 항목 | 포함(스펙 작성 후보) |
| `ambiguous` | statement가 모호하거나 매칭 확신 불가 | 사유 | 포함(triage) |
| `invalid-feature` | `feature=""` 또는 feature_list.json에 없는 feature | 사유 | 포함(triage — 바인딩 불가) |

- 판정은 **feature-범위**: 전체 E2E를 컨텍스트에 올리지 않고 해당 `@feature` 스펙만 읽는다(gemini 환각 우려 완화 + 비용 절감).
- 모든 판정에 **증거 필수** — 증거 없는 covered/missing 단정 금지.

## 7. 백로그 머지 규칙 (idempotent)
distill 실행 시:
1. 원장 전체에 대해 커버리지 파생(§6).
2. 각 의도(키=ts):
   - `covered` → 열린 백로그에 있으면 **제거**(해소).
   - `missing/partial/ambiguous/invalid` → 열린 백로그에 **없으면 추가**, 있으면 state/evidence **갱신**.
   - waiver 섹션에 키가 있으면 **스킵**(재추가 안 함).
3. 기존 행의 사용자 `priority/비고` 열은 키 매칭으로 **보존**(덮어쓰기 아닌 머지).
4. waiver 섹션은 리포트만, distill이 수정 안 함.
→ 같은 입력 = 같은 백로그(idempotent). 재실행이 중복/소실 안 만듦.

## 8. 보안 (이스케이프, D7)
백로그 문서·옵트인 gh 이슈에 statement를 넣을 때(소독 ≤200은 JSON 안전일 뿐):
- **Markdown table escape**: `|` → `\|`, 개행 → 공백.
- **HTML-comment delimiter 방어**: statement 내 `-->`·`<!--` 무력화(fingerprint 주석 교란 차단).
- **@mention 무력화**: `@` → `@<zero-width>` 또는 코드 스팬 래핑(이슈 mention spam 차단).
- harness-feedback §5 table escape 재사용 + 위 확장.

## 9. 계약·정합성 (CLAUDE.md 개발 규칙)
- ✅ **Phase 1 원장 스키마 불변** — 읽기 전용, `encoded` 미갱신(문구만 교정).
- ✅ **harness-feedback 불변** — 통합 안 함(별도 스킬). friction 회귀 위험 0.
- ✅ 새 `INTENT_BACKLOG.md` = `data`. 새 스킬 = plugin 등록.
- ✅ 골든 픽스처(structural-test) 무영향.
- ✅ 두 SKILL.md 프로필 스키마 계약 불변(신규 프로필 필드 0).

## 10. degradation / 엣지 케이스
| 상황 | 처리 |
|------|------|
| `.harness-intent.jsonl` 부재 | 스킵(에러 아님) |
| `INTENT_BACKLOG.md` 부재 | 빈 백로그로 시작(첫 sync가 생성) |
| E2E 미옵트인(e2e/specs 없음) | "커버리지 판정 보류" 리포트, missing 오판 금지 |
| `feature=""` / feature_list 부재 | `invalid-feature` triage |
| 한 feature에 복수 E2E | 모두 대조, 하나라도 매칭 시 covered |
| 의도 철회/변경(상충 statement) | 둘 다 백로그 후보로 표면화(triage), 자동 판단 안 함 |
| 같은 의도 반복 적재 | 키(ts) 다르나 statement 동일 → 머지 시 dedup 힌트(중복 후보 표기) |
| gh 미설치 | 옵트인 이슈만 스킵, 백로그 sync는 gh-무관 정상 |
| 깨진 원장 줄 | 해당 줄 스킵 + 카운트 보고(관용 파서) |

## 11. 버전 / 마이그레이션
- 신규 스킬 + 신규 `data` 문서 + scaffold/세션루틴/cleanup 행동 + Phase 1 문구 교정. 기존 호환(가산). **MINOR: 1.24.0 → 1.25.0**.
- 범프 대상: project-context.md·CHANGELOG.md·plugin.json·marketplace.json·README·git tag(병합 시).
- **마이그레이션 불필요**: 업그레이드는 가산(INTENT_BACKLOG.md 생성 + 스킬 + 세션루틴 nudge). 기존 원장은 첫 distill에서 전체 sync(과거 백로그 노출 — 의도).

## 12. 검증 계획
- **커버리지 판정**(시나리오): covered/partial/missing/ambiguous/invalid 각 케이스 + 증거 첨부 / E2E 미옵트인 보류 / feature-범위 한정.
- **백로그 머지**(시나리오): 신규 추가 / 커버됨 제거 / 사용자 주석 보존 / waiver 스킵 / idempotent(재실행 동일).
- **이스케이프**(시나리오): `|`·개행·`-->`·`@mention` 포함 statement → 백로그/이슈 안전.
- **degradation**: 원장/백로그/E2E 부재 각 경로.
- **계약 회귀**: 원장 스키마 불변 / harness-feedback 불변 / 골든 픽스처(`test/run-fixtures.sh`) 무영향.

## 13. 수용 기준
- [ ] "의도 정리" → 5-상태+증거 커버리지 파생 → `INTENT_BACKLOG.md` 머지-싱크.
- [ ] 백로그가 영속·diffable, 사용자 주석·waiver 보존, **idempotent**.
- [ ] 커버리지는 **derived**(feature-범위, 증거 필수) — stored flag 아님.
- [ ] gh = 항목별 옵트인(이스케이프 적용).
- [ ] 세션종료 경량 nudge(세션-로컬, 상태 파일 없음) + 격주 B1 리뷰 편입.
- [ ] Phase 1 `encoded` 문구 교정(INTENT_LEDGER.md·session-routine·spec) — 비권위 명시.
- [ ] Phase 1 원장 스키마 불변, harness-feedback 불변.
- [ ] E2E 미옵트인 시 "판정 보류"(missing 오판 금지).

## 14. 명시적 비-스코프 (Phase 2b)
PRD substrate(`docs/product-specs` 구조·템플릿) · `feature_list.prd_section_ref` 필드 · 의도↔feature↔@feature↔PRD 양방향 바인딩 · "PRD에 있는데 의도 근거 없음"(미검증 명세) 방향 · PRD 반영 제안.

---

## 참고
- 멀티모델 자문 원본: `.claude/artifacts/consult/codex-…-2026-06-17T09-05-38.md` · `gemini-…-2026-06-17T09-06-30.md`
- 선행: Phase 1 spec `docs/superpowers/specs/2026-06-17-intent-ledger-capture-design.md`(PR #17), 이슈 #15
- 자매 현행: `skills/harness-feedback/SKILL.md`(파이프라인 패턴), `templates/TECH_DEBT.md`(영속 백로그 패턴), `harness-cleanup`(격주 B1)
- 출력단: `coding-standards.md`(feature_list.steps↔L4 E2E 1:1), `@feature:{id}` 태그(test-engineer.md)
