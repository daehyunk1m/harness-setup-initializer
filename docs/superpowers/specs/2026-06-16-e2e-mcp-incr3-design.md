# 설계: Playwright MCP 연계 (이슈 #12 증분 3)

> 작성일: 2026-06-16
> 목표 버전: **1.15.0** (MINOR — 신규 플레이스홀더 +1, 프로필 서브필드 추가)
> 범위: 이슈 #12의 **증분 3** (MCP Layer A — 에이전트 인-더-루프 브라우저 진단). 증분 1·2(E2E 스캐폴드·TDD 배선·pre-push)가 전제.
> 선행 설계 정본: `docs/superpowers/specs/2026-06-15-e2e-scaffold-module-design.md` § 11(증분 3 개요), `2026-06-16-e2e-tdd-wiring-design.md`(debugger 재현 §0).
> 멀티모델 자문: codex(결함·보안) + gemini(대안·운영) 적대적 자문 후 합성 — `.claude/artifacts/consult/` 2건.

---

## 1. 배경 & 동기

증분 1(1.11.0)은 E2E 스캐폴드를, 2a(1.12.0)는 TDD 배선(VERIFY Phase 4.7 + `@critical` + debugger 재현 §0)을, 2b(1.14.0)는 pre-push 게이트를 채웠다. 그러나 모두 **이미 작성된 `.e2e.ts` 스펙을 실행/재현**하는 경로다. debugger.md §0도 *실패한 known 스펙*을 `--headed`/trace로 재현할 뿐이다.

빠진 것: **스펙이 아직 없는 UI 증상**(사용자 버그 리포트, 재현 스펙 부재)을 에이전트가 **라이브 브라우저로 탐색·진단**하는 경로. 이슈 #12 Layer A의 핵심 가치 — "에이전트가 사람이 하던 브라우저 작업을 대신". 이것이 Playwright MCP(접근성 트리 스냅샷·저토큰)가 필요한 지점이다.

**증분 2b에서 3으로 분리한 이유**: MCP는 검증(validation) 인프라가 아니라 에이전트 **진단 도구**다. 실패 도메인·생명주기가 다르고(2b=git/push 게이트, 3=세션 내 진단), 독립 옵트인이다.

---

## 2. 핵심 설계 결정 (헤드라인)

| # | 결정 | 근거 |
|---|------|------|
| D1 | **배치 = e2e 모듈 확장** (외부 통합 규약 `integrations.<name>` 안 씀) | debugger는 코어 SoT — integrations 규약 원칙 #3(코어 제외)과 충돌. integrations는 doc-text 링크 전용, MCP는 코어 에이전트 배선. e2e 스캐폴드 선례(모듈, 통합 아님)와 일관 |
| D2 | **산출물 = 비커밋** — 공유 `.mcp.json`을 생성·커밋하지 않는다. 진짜 산출물은 debugger.md 진단 지침 + 개발자 로컬 등록 명령 | gemini: Claude Code는 프로젝트 `.mcp.json`에 협업자 1회 보안 승인을 요구(코드 실행 동의 게이트) → MCP 미사용자에겐 마찰. 관심사 분리(E2E=팀 검증 SoT vs MCP=개인 진단). codex가 나열한 `.mcp.json` 머지 지옥(malformed/스키마 변형/기존 충돌/monorepo 루트)을 통째로 회피 |
| D3 | **게이팅 = 분리 옵트인** — 프론트엔드면 E2E 스펙 작성과 독립으로 MCP를 묻는다. 프로필 `e2e.mcp`, `e2e.enabled` 없이 단독 가능 | 이슈 Layer A를 독립 가치(Phase 1, 러너 없이 동작)로 명시. E2E 스펙 안 써도 브라우저 진단만 원하는 경우 커버 |
| D4 | **MCP 패키지 = 공식 `@playwright/mcp` 하나 표준**, **exact 버전 핀**(`@latest` 금지) | 둘 다 동의(gemini "매우 훌륭" — 접근성 트리·저토큰 / codex 동의). `@latest`는 매 실행 의미 변동 = 비결정성·공급망 위험 |
| D5 | **신규 플레이스홀더 +1** — `{{MCP_DEBUG_PROTOCOL}}`(30→31). debugger.md(managed)의 조건부 텍스트 블록 | managed 조건부 텍스트는 플레이스홀더로(`{{INTEGRATION_NOTES}}` 선례 = §12.6 자동 감지 안전). scaffold 임의 삽입 금지 |
| D6 | **MCP-vs-러너 = 명시적 분기** — known `.e2e.ts` 실패는 러너/아티팩트가 정본(MCP 제한), 스펙 없는 UI 증상만 MCP 허용 | codex: 오용 시나리오(스펙 있는데 MCP로 헤맴, MCP 재현을 스펙화 안 함, 관찰 환각)가 실재. 러너/validate가 authoritative |

> **gemini 결함 1건 교정(합성자 판단)**: gemini는 "debugger가 `npx @playwright/mcp` ad-hoc 실행"을 권했으나 — MCP **도구**는 세션 시작 시 등록돼야 에이전트가 호출 가능하다. Bash로 `npx`를 띄우는 건 프로세스일 뿐 MCP 툴이 아니다. 그래서 올바른 경로는 **개발자가 `claude mcp add`로 자기 로컬 설정(프로젝트/유저 스코프)에 등록**하는 것. debugger.md 지침은 이 등록 명령을 안내하고, 등록된 MCP 도구를 사용하는 워크플로를 기술한다.

---

## 3. 프로필 스키마 — `e2e.mcp`

```jsonc
"e2e": {
  "enabled": true,        // 선택 — E2E 스펙 스캐폴드 (증분 1)
  "prePush": true,        // 선택 — pre-push 게이트 (증분 2b)
  "mcp": {                // 선택 — 신규(증분 3). enabled와 독립
    "enabled": true,
    "version": "x.y.z"    // @playwright/mcp exact 핀 (codex: 객체형 — 향후 보안 옵션 확장 여지)
  }
}
```

- **필드 규칙**: `e2e.mcp`는 선택 객체. 생략 = MCP 산출물 0건. `bare mcp: true` 대신 객체형(codex 권고 — `version`·향후 옵션 확장).
- **`enabled` 없이 `mcp`만 가능**: E2E 스펙 스캐폴드 없이 MCP 진단만 옵트인. `e2e` 블록은 `enabled`·`prePush`·`mcp` 중 하나라도 있으면 존재.
- **`package`는 파라미터화 안 함**: 공식 `@playwright/mcp` 하나 고정(YAGNI — gemini). 코드에 리터럴.
- **`version` 단일 소스**: debugger.md 등록 명령에 인라인되는 핀 버전의 SoT. `e2e.playwrightVersion`(러너)과 **별개 생명주기**(codex — 같은 버전 가정 금지).
- **두 SKILL.md 동기**: SKILL.md 출력 스키마 = harness-scaffold/SKILL.md 입력 스키마. `e2e` 블록에 `mcp` 추가(양쪽 동일 텍스트).
- **manifest.profile 저장**: 기존 `e2e` 저장 규칙이 `mcp`를 포함(중첩 필드 자동 포함).

---

## 4. 산출물 — debugger.md `{{MCP_DEBUG_PROTOCOL}}` 블록 (D2·D5)

`templates/agents/debugger.md`(managed)에 플레이스홀더 1개를 §0 뒤(일반 진단 프로토콜 §1 앞)에 추가한다. scaffold가 `e2e.mcp.enabled`면 아래 블록으로 치환, 아니면 **빈 문자열**.

블록 구성(치환 시):

### 4.1 로컬 등록 (개발자 1회)

> MCP는 세션 시작 시 등록돼야 도구로 사용 가능하다. 공유 `.mcp.json`을 만들지 않으므로, 브라우저 진단이 필요한 개발자가 자기 로컬에 1회 등록한다:
>
> ```sh
> claude mcp add playwright-harness -- npx -y @playwright/mcp@{{핀버전}} --headless --isolated
> ```
>
> - 프로젝트 스코프(`--scope project`, 팀 공유 .mcp.json 생성) 대신 **기본(로컬/유저 스코프)** 권장 — 개인 진단 도구.
> - 등록 후 Claude Code 세션을 재시작하면 `playwright-harness` MCP 도구가 활성화된다.

### 4.2 MCP-vs-러너 분기 (D6 — codex 강한 버전)

- **known `.e2e.ts` 실패** → §0 적용. 러너/아티팩트(trace·report·screenshot)가 **정본**. MCP 라이브 탐색을 **시작하지 않는다**(시간 낭비·SoT 우회 방지).
- **스펙 없는 UI 증상**(사용자 리포트, 재현 스펙 부재) → MCP 허용. 목적은 **관찰 + 최소 재현 수집**.
- 판단 모호 시 기본은 **러너/스펙 우선**, MCP는 마지막 수단.

### 4.3 보안 기본값 (codex)

- 등록 명령에 `--headless --isolated` 강제 — **영속 프로필 금지**(기존 쿠키/로그인 세션 노출 차단).
- **localhost/devServer origin만** 기본. 외부 URL 탐색은 **사용자 명시 승인** 필요.
- exact 핀만(`@playwright/mcp@x.y.z`), `@latest`·범위 지정 금지.

### 4.4 사용 후 의무 + 관찰 로그 (codex)

- **코드화 의무**: MCP로 찾은 재현 경로를 `.e2e.ts`로 코드화(`e2e.enabled` 시) 또는 명시적 재현 단계로 기록. **최종 완료 판단은 항상 `{{E2E_COMMAND}}`/`{{VALIDATE_COMMAND}}` 통과.** MCP 관찰만으로 "수정 완료" 단정 금지.
- **관찰 로그 필수**: URL · 시작 상태 · 클릭/입력 순서 · actual vs expected · console/network 근거. (§0 플레이키니스 환각 금지 연장 — 본 것만 기록, 추정은 추정 표시.)

> 핀 버전은 scaffold가 `e2e.mcp.version`에서 읽어 `{{핀버전}}` 자리에 인라인한다(치환 시점). 위 블록은 치환 결과 예시이며, 템플릿 본문의 플레이스홀더는 `{{MCP_DEBUG_PROTOCOL}}` 하나다.

---

## 5. 감지 & 옵트인 질문 (SKILL.md Phase 1)

- **감지 불요**: `@playwright/mcp`는 npx 실행이라 전역 설치 판정 대상이 아니다. 프론트엔드 프로젝트면 옵트인을 **제안**한다(설치 여부 묻지 않음).
- **질문**(우선순위 5·선택): E2E 스펙 옵트인 질문과 **별개로** "브라우저 MCP 진단을 셋업할까요?(에이전트가 라이브 브라우저로 스펙 없는 UI 증상을 탐색·진단)". 동의 시 `e2e.mcp.enabled: true` 기록. **`version`은 사용자에게 묻지 않는다** — 스킬이 검증·핀한 기본 버전(§10.1, `playwrightVersion` 기본값 패턴과 동일)을 scaffold가 사용한다.
- **프론트엔드 게이트**: e2e 옵트인과 동일한 프론트엔드 감지 분기에서 묻는다. 백엔드/비프론트는 질문 생략.

---

## 6. 렌더링 & 카탈로그 (harness-scaffold/SKILL.md)

- **입력 스키마**: `e2e.mcp` 추가(§4 입력 스키마 노트).
- **치환**: `e2e.mcp.enabled`면 `{{MCP_DEBUG_PROTOCOL}}` ← §4 블록(핀 버전 인라인), 아니면 빈 문자열. 치환 규칙 테이블에 1줄 추가(플레이스홀더 #31).
- **Phase 4 카탈로그**: "이제 할 수 있는 일"에 **브라우저 MCP 진단** 줄 추가 — 순수 투영, 게이트 신호 `e2e.mcp.enabled`. 미옵트인이면 줄 없음(미와이어 능력 광고 금지 — §7 렌더링 규칙).
- **Phase 4 보고**: MCP 옵트인 시 등록 명령 1줄 + 보안 요지(headless/isolated/localhost-only)를 안내.

---

## 7. manifest / 버전 / 검사

- **신규 파일 0** → manifest.files{} 불변. `.mcp.json` 생성 안 함 → §12.6.1 매핑·카테고리 계약 무변경.
- **debugger.md는 managed** — 템플릿에 플레이스홀더 추가 → §12.6 자동 감지가 기존 하네스에 전파(미옵트인은 빈 문자열 치환이라 무영향).
- **profile에 `e2e.mcp` 추가** — 옵트인·생략 기본 → **마이그레이션 불필요**(1.11.0/1.12.0/1.14.0 옵트인 선례 동일). §10.3 "M-1.4.0 이후 불필요" 주석에 1.15.0 추가.
- **harness-check 신규 항목 없음** — 기존 "잔여 `{{...}}` 0" 검사가 미치환을 잡는다. (MCP는 파일 산출물이 없어 구조 검사 대상이 없음.)
- **버전 = MINOR(1.15.0)** — 플레이스홀더 +1(신규 기능), 프로필 서브필드 추가. project-context.md·CHANGELOG.md·프로필/매니페스트 version·versioning-policy.md·git tag 동시 갱신.

---

## 8. U1 재감지 (업그레이드)

- 기존 프론트엔드 하네스 업그레이드 시 `e2e.mcp` 부재면 **MCP 옵트인 제안**(superpowers/consult/prePush U1 재감지 패턴 준용). 수락 시 debugger.md MCP 블록 치환(managed 재렌더링).
- 생략 기본 → 무강제. 거절/미응답 시 산출물 0건.

---

## 9. 정합성 계약 (구현 시 동시 갱신 필수)

1. **프로필 스키마**: SKILL.md 출력 = harness-scaffold/SKILL.md 입력 (`e2e.mcp`).
2. **플레이스홀더**: `{{MCP_DEBUG_PROTOCOL}}` 추가 → 치환 규칙 테이블 등록(30→31). debugger.md 템플릿에 정확히 1개.
3. **카탈로그 렌더링 규칙**(Phase 4): 브라우저 MCP 진단 줄은 산출물 게이트 신호(`e2e.mcp.enabled`)를 동일하게 가진다 — 순수 투영. 미옵트인이면 카탈로그/보고에 MCP 줄 없음.
4. **버전 동시 갱신**: §7 5개 위치.
5. **debugger.md 교차참조**: §0(known 스펙 재현)과 §4.2(MCP 분기)가 모순 없이 연결 — known 실패는 §0, 스펙 없음은 MCP.

---

## 10. 착수 전 확인 (구현 시점 — codex)

1. **핀 버전 확정**: 구현 시점 `@playwright/mcp` 안정 stable 버전 조사 → `e2e.mcp.version` 기본값 + 프리셋 기본값(있으면)에 반영.
2. **CLI 플래그 검증**: `--headless`·`--isolated`·도메인 제한 옵션의 **실제 옵션명을 그 핀 버전 `--help`로 검증**(codex — 버전별 옵션명 변동 가능). 도메인 제한 플래그 부재 시 §4.3 지침으로만 강제(코드 강제 불가 명시).
3. **`claude mcp add` 구문 검증**: 현재 Claude Code 버전의 `claude mcp add` 인자 형식(스코프 플래그 포함) 확인 후 등록 명령 확정.

---

## 11. 수정 / 신규 파일

**신규**: 없음.

**수정**:
- `templates/agents/debugger.md` — `{{MCP_DEBUG_PROTOCOL}}` 플레이스홀더 추가(§0 뒤). 조건부 치환 블록 내용(§4).
- `SKILL.md` — Phase 1: 프론트엔드 MCP 옵트인 질문(§5), 프로필 출력 스키마 `e2e.mcp`.
- `harness-scaffold/SKILL.md` — 입력 스키마 `e2e.mcp`, `{{MCP_DEBUG_PROTOCOL}}` 치환 규칙(치환표 +1), Phase 4 카탈로그 MCP 줄 + 보고 안내, U1 재감지, §10.3 마이그레이션 주석에 1.15.0.
- `references/harness-checklist.md` — §4.2 또는 디버깅 절에 MCP 탐색적 진단 경로 명시(선택 — 최소 1줄).
- `references/versioning-policy.md` — 1.15.0(플레이스홀더 +1 = MINOR, 30→31).
- `references/project-context.md`, `.tracking/{HANDOFF,CHANGELOG,TODO}.md`.

**변경 없음**: 레이어 아키텍처 린터, `.mcp.json`(생성 안 함), playwright.config/e2e/(증분 1 산출물 불변), manifest.files, harness-check 판정 로직, 7개 에이전트 중 debugger 외.

---

## 12. 테스트 (골든 픽스처)

신규 파일이 없어 구조 픽스처 신설은 불요. 대신 **치환 회귀**를 검증:

1. **MCP 옵트인 시 치환**: `e2e.mcp.enabled` 프로필 → debugger.md에 등록 명령(핀 버전)·분기·보안·의무 블록 렌더, 잔여 `{{MCP_DEBUG_PROTOCOL}}` 0.
2. **미옵트인 시 빈 문자열**: `e2e.mcp` 부재 → debugger.md에 MCP 블록 없음, 잔여 플레이스홀더 0.
3. 기존 `test/run-fixtures.sh`/`e2e-fixtures.sh` 패턴 — 필요 시 `test/mcp-fixtures.sh` 또는 기존 e2e 픽스처에 케이스 추가. 릴리스 전 실행.

> **검증 한계**(gemini 정직한 done): 위 픽스처는 **구조(블록 렌더)만 보장**한다. 에이전트가 실제로 MCP를 등록·구동해 UI 버그를 진단하는 것은 개발자 로컬 등록 + Claude Code MCP 지원 + 앱 부팅에 의존 — 파일럿(haja) 도그푸딩으로만 확인. (e2e 모듈 "구조 보장, 주행은 앱 의존" 정직화와 동일 톤.)

---

## 13. 멀티모델 자문 반영 (codex · gemini)

| 반영점 | 출처 | 결정 |
|--------|------|------|
| 공식 `@playwright/mcp` 하나 표준 | 합의 | D4 채택 |
| `@latest` 금지 → exact 핀, 별도 생명주기 | 합의(codex 상세) | D4·§3 `e2e.mcp.version` |
| MCP=탐색적, 러너=authoritative SoT | 합의 | D6·§4.2 |
| 진짜 산출물은 debugger.md 지침(파일 아님) | gemini | D2·§4 |
| 공유 `.mcp.json` 비커밋(nagware·관심사 분리·머지 지옥 회피) | gemini(+codex 머지 위험 열거) | D2 |
| `.mcp.json` 머지 정확성 난제(malformed/스키마변형/충돌/monorepo) | codex | **회피**(생성 안 함) — 승격 조건으로 보존(증분 4에서 공유 등록 수요 시 재검토) |
| 보안 기본값(headless/isolated/localhost-only) | codex | §4.3 |
| 사용 후 코드화 의무 + 관찰 로그 | codex | §4.4 |
| 정직한 done(진단 가능 여부, 파일 존재 아님) | gemini | §12 검증 한계 |
| "ad-hoc npx 실행" 오류 교정(MCP는 등록 필요) | 합성자 | D6 비고·§4.1 |

> **합성자 메모**: gemini의 "파일 생성 전면 취소"는 채택하되, 그 대안 "ad-hoc npx 실행"은 MCP 도구 등록 메커니즘을 오해한 것이라 `claude mcp add` 로컬 등록으로 교정했다. codex의 `.mcp.json` 안전 머지 설계는 **D2로 인해 불필요**해졌으나, 향후 팀 공유 등록 수요가 반복되면(핵심원칙 #5) codex의 custom·AST·ownedPaths 모델을 증분 4 이후 재검토 대상으로 보존한다.

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
