# 설계 — 이슈 #12 증분 4 (TODO-97): E2E 모듈 마감 → 1.17.0

> 작성: 2026-06-16 (Session 42). 스코핑 핸드오프(`2026-06-16-e2e-incr4-handoff.md`)의 4개 작업 + 사용자 확정 결정을 구현 설계로 고정한다.
> 이 문서는 핸드오프를 대체하지 않는다 — 핸드오프의 file:line 앵커·근거를 전제로 하고, **확정 결정**과 **핸드오프가 과소명세한 발견 2건**만 기록한다.

---

## 0. 사용자 확정 결정 (AskUserQuestion, 2026-06-16)

| 결정 | 확정값 | 의미 |
|------|--------|------|
| **D1** 프리셋 e2e 기본값 | **pre-seed (Option B)** | 프리셋이 `"e2e": {"enabled": true}`를 "권장 기본 답"으로 제공. §4.2 옵트인 질문은 **그대로 뜨되** 권장 기본이 "예"로 뒤집힘. 거부/무응답이면 필드 생략·모듈 미생성(옵트인 계약 보존). |
| **D2** 가이드 문서 위치 | **`e2e/README.md`, category=managed, `e2e.enabled` 엄격 게이트** | dev가 일하는 곳(e2e/). §12.6 자동 감지로 최신 유지. 1.11.0/1.14.0 "마이그레이션 없음" 속성 상속(비-e2e 하네스 산출물 0). |
| **D3** U1 cascade | **cascade** | 업그레이드 U1에서 base E2E 수락 직후 같은 패스에서 pre-push 재감지(1743)로 이어짐(신규셋업 SKILL.md:357 미러). MCP 재감지(1744)는 `e2e.enabled` 무관이라 독립 유지. |
| **D4** 릴리스 | **단일 1.17.0** | A·B·C·D 한 릴리스. 전 항목 신규 플레이스홀더 0·마이그레이션 불필요로 안전. |

---

## 1. 핸드오프가 과소명세한 발견 (구현 전 확정)

### 발견 1 — `e2e/README.md`(managed)는 §12.6.1 매핑에 **반드시** 추가해야 한다

D2가 README를 managed로 택한 이유는 "§12.6 자동 감지 재렌더 → 업그레이드 시 최신 유지"다. 그런데 §12.6 자동 감지는 `manifest.files[]`의 managed 항목을 **§12.6.1 파일-템플릿 매핑 테이블에서 소스 템플릿을 찾아** 재렌더한다(SKILL.md:1128-1150, 1454). 매핑에 없는 managed 파일(`docs/` 하위 등)은 자동 감지에서 **제외**되어 마이그레이션으로만 관리된다(SKILL.md:1150).

따라서 `e2e/README.md`를 §12.6.1에 등록하지 않으면 "managed인데 unmapped" 상태가 되어 README가 manifest에 있는 하네스(신규 셋업)에서도 **§12.6 자동 감지(갱신 전파)를 못 받는다**. → **§12.6.1에 `e2e/README.md | templates/e2e/README.md` 1행 추가**(item A의 e2e config 2행과 동일 맥락의 3번째 e2e managed 파일).

**전파 경계 (정직)**: §12.6 자동 감지는 `manifest.files[]`에 **이미 기록된** managed 파일의 `templateHash`를 재렌더 해시와 비교한다(SKILL.md:1454) — 즉 **업데이트 전용, 신규 파일 생성 불가**(신규 파일은 `[new]` 마이그레이션 영역, harness-scaffold/SKILL.md:1575 "초기 셋업과 동일하게 생성"). 따라서:
- **신규 셋업 하네스**: 셋업 시 README가 생성·manifest 기록 → 이후 업그레이드에서 §12.6이 최신 유지. ✅ D2 freshness 약속 성립.
- **기존(1.11.0~1.16.0) e2e 옵트인 하네스**: manifest에 README 없음 → §12.6이 **소급 생성하지 않음**. `[new]` 마이그레이션을 추가하면 비-e2e 하네스 오주입/프로필-게이트 복잡성이 생겨 비침습·옵트인 원칙과 충돌하므로 **추가하지 않는다**(무마이그레이션 트레이드오프 — 동일 내용이 그들이 이미 가진 test-engineer.md·coding-standards.md에 있음). harness-scaffold §10.3 1.17.0 노트에 파일별로 명시.
- 반면 **playwright.config.ts·e2e/tsconfig.json**은 기존 e2e 하네스 manifest에 이미 있으므로, §12.6.1 편입으로 다음 업그레이드부터 자동 감지를 **새로 받는다**(업데이트 경로 — 정상).

- **결정론 안전**: README는 플레이스홀더 0인 순수 정적 템플릿 → 재렌더 항상 byte-identical → expectedHash 안정(e2e/tsconfig.json과 동급).
- **사용자 커스터마이즈 시**: 4-상태 매트릭스가 "템플릿 변경 × 사용자 수정 → 사용자 선택"으로 안전 처리(managed 파일 표준 동작). README를 managed로 택한 D2의 트레이드오프를 그대로 수용.

### 발견 2 — README의 명령 참조는 **정적 리터럴** `npm run test:e2e` (플레이스홀더 미사용)

핸드오프 D2 하위결정은 `{{E2E_COMMAND}}` 재사용 vs 일반 문구를 열어뒀다. **정적 리터럴 선택**:
- 장점: README가 플레이스홀더 0인 순수 정적 managed 템플릿 유지 → §12.6 결정론 자명, **§6.11 grep에 `e2e/README.md` 추가 불필요**(미치환 잔존 가능성 0), 31 플레이스홀더 불변에 기여 0(영향 없음).
- 패키지매니저 차이(yarn/pnpm)는 README 산문에 1회 "(프로젝트 패키지매니저에 맞춰 `npm`/`yarn`/`pnpm`)"로 흡수.

---

## 2. 항목별 편집 요약 (확정)

### A. §12.6.1 e2e managed 매핑 정렬 — 무결정, 먼저
- `SKILL.md:1146` 뒤(`.githooks/pre-push` 행 다음)에 2행 추가: `playwright.config.ts`·`e2e/tsconfig.json`. (README 행은 item D에서 추가.)
- `SKILL.md:1148` deferral 노트를 **갱신** — "e2e managed 파일 부재" 단언을 "이제 매핑됨, 기존 e2e 하네스는 다음 업그레이드부터 자동 감지 대상"으로. custom 3개(fixtures/test·seed·smoke)는 user-owned로 **제외 유지** 명시.

### B. 프리셋 e2e 기본값 (D1=pre-seed)
- `presets/react-next.json`·`react-router-fsd.json`·`react-vite.json`에 `"e2e": {"enabled": true}` 추가(`docFreshnessDays` 뒤). **express-api.json 비변경**.
- `SKILL.md:725-782` §6 프리셋 스키마에 선택 `e2e` 필드 문서화(`{"enabled": true}` shape, playwrightVersion 하드핀 금지).
- `SKILL.md:851-869` §9 커스텀 프리셋 가이드에 선택 필드 1줄.
- `SKILL.md:666` 필드 규칙 + `SKILL.md:354-356` §4.2 + `harness-scaffold/SKILL.md:183` 미러: "프리셋 비대상" → "프리셋이 **권장 기본** 제공, 여전히 옵트인 확인(거부=생략)". 세 곳 content 일관.
- `SKILL.md:433` 머지 우선순위가 프리셋 e2e 기본을 지배함을 확인(기존 문구로 충분하면 무변경).
- **프리셋 필드는 플레이스홀더 아님 → 31 불변**. JSON 프로필 스키마 블록 무변경(byte-identical 유지).

### C. U1 재감지 (D3=cascade)
- `harness-scaffold/SKILL.md:1743`(pre-push 재감지) **앞**에 "E2E 재감지" 불릿 prepend(읽기 순서 base→pre-push→MCP, 신규셋업 354/357/360 미러). cascade: 수락 시 §5.17 생성 + manifest 등록, **이어서 pre-push 재감지(1743) 평가** 절 명시. 프론트엔드 신호는 SKILL.md:180 재사용.
- `harness-scaffold/SKILL.md:1737-1741` 무마이그레이션 프로즈 블록에 `> **1.17.0** …` 추가 — **pre-push 프레이밍**(수락 시 신규 파일; MCP의 "신규 파일 0" 프레이밍 복사 금지).
- 정본은 scaffold §10.3에만(SKILL.md U1 박스 중복 안 함). 신규 프로필 필드·플레이스홀더 0.

### D. 사용자 E2E 작성 가이드 (D2=e2e/README.md managed)
- 신규 `templates/e2e/README.md` — 사람-온보딩 voice. 8섹션(핸드오프 §D 개요). 에이전트-규칙 내용은 **참조만**(test-engineer.md:19-41·coding-standards.md:24-44·playwright.config.ts:29-32 복제 금지). 명령은 정적 `npm run test:e2e`.
- `harness-scaffold/SKILL.md:1027-1033` §5.17 생성 테이블에 `e2e/README.md | managed | templates/e2e/README.md | 없음` 행 추가. §5.17 규칙(1037-1040)에 정적 prose·managed 1줄.
- `harness-scaffold/SKILL.md:1445-1450` §10.1 분류 테이블에 `e2e/README.md` managed 행 추가 → `.githooks/pre-push` #31→#32 이동(이름 참조라 번호 하드참조 없음 — grep 확인).
- `harness-scaffold/SKILL.md:223` 생성 순서 step 19 설명에 README 포함(`+ e2e/README.md`).
- `harness-scaffold/SKILL.md:1321` Phase 4 카탈로그 기존 E2E 줄에 `e2e/README.md` 상세 포인터 추가(신규 카탈로그 줄 불필요 — 순수 투영 유지).
- **§12.6.1(SKILL.md)에 `e2e/README.md` 매핑 행 추가**(발견 1).
- `references/harness-checklist.md` §4.2(118 근처) 1줄, `references/versioning-policy.md:224` 뒤 1.17.0 행.
- §6.11 grep 무변경(정적 리터럴이라 불필요 — 발견 2).

---

## 3. 불변 계약 체크 (릴리스 게이트)
- [ ] 플레이스홀더 **31개 불변**(`SKILL.md:919`, `versioning-policy.md:14,37` 프로즈 "31" 유지).
- [ ] 두 SKILL.md 프로필 스키마 JSON 블록 **byte-identical**(version 1.16.0→1.17.0 동시, e2e 블록 무변경).
- [ ] e2e 필드 규칙 prose(SKILL.md:666 ↔ scaffold:183) content 일관.
- [ ] 마이그레이션 레지스트리 **무변경**(전 항목 옵트인·생략 기본 → M-엔트리 없음).
- [ ] 골든 픽스처 6/6 + e2e/mcp/prepush 픽스처 통과(`bash test/*.sh`).
- [ ] `git grep "증분 4"` deferral 주석(SKILL.md:1148) 잔여 없음.
- [ ] express-api.json 등 e2e 없는 프리셋 호환(선택 필드).

## 4. 버전 범프 사이트
- `SKILL.md:549` `"version": "1.16.0"` → `1.17.0`
- `harness-scaffold/SKILL.md:77` `"version": "1.16.0"` → `1.17.0`
- `references/versioning-policy.md:224` 뒤 1.17.0 행
- `references/project-context.md` 버전 히스토리 1.17.0 엔트리
- `.tracking/CHANGELOG.md` 1.17.0 엔트리
- `.tracking/HANDOFF.md` Session 42 + 현재 버전 갱신, TODO-97 완료
- `.tracking/TODO.md` TODO-97 완료
- `git tag v1.17.0`
