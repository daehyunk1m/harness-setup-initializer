# 설계: E2E pre-push 인프라 (이슈 #12 증분 2b)

> 작성일: 2026-06-16
> 목표 버전: **1.14.0** (MINOR — 신규 managed 파일 발생)
> 범위: 이슈 #12의 **증분 2b** (pre-push 강제 인프라). 증분 2a(TDD 배선)가 전제.
> 선행 설계 정본: `docs/superpowers/specs/2026-06-16-e2e-tdd-wiring-design.md` § 8 (2b 난제 9건).

---

## 1. 배경 & 동기

증분 1(1.11.0)은 E2E 스캐폴드(playwright.config + `e2e/` + `test:e2e`)를, 증분 2a(1.12.0)는 이를 TDD 사이클에 배선(VERIFY Phase 4.7 + `@critical` 정의 + debugger 재현)했다. 그러나 **`@critical` 태그는 정의·작성 규율만 도입됐고 실제 게이팅 경로가 없다.**

하네스 타깃 프로젝트는 **CI가 없는 경우가 많다**(양 모델 합의: "안 보이는 테스트는 죽은 테스트"). VERIFY(E2E) Phase 4.7은 *해당 feature의 스펙만* 실행하므로, **누적된 `@critical` 회귀가 cross-feature로 깨지는 것**을 push 시점에 막을 마지막 방어선이 없다. 증분 2b는 이 방어선을 **무의존 pre-push 훅**으로 채운다.

**증분 2a에서 2b로 분리한 이유**(적대적 자문 결론): pre-push는 git config·외부 상태를 건드리는 인프라 변경이라 에이전트/룰 변경과 **실패 도메인이 다르다**. 인프라가 깨져 롤백하면 안전한 2a 변경까지 잃으므로 독립 릴리스한다.

---

## 2. 핵심 설계 결정 (헤드라인)

| # | 결정 | 근거 |
|---|------|------|
| D1 | **활성화 = 수동** — 스캐폴드는 `.githooks/pre-push`만 생성, `git config core.hooksPath`는 실행하지 않는다. Phase 4가 명령 1줄 + 보안 고지를 출력하고 사용자가 실행 | git-workflow.md "승인 없이 git 실행 금지" 절대 규칙과 정합. harness-check ⑨의 활성/비활성 보고가 의미를 가짐 |
| D2 | **게이팅 = `validate` → `@critical` E2E** (fail-fast 순서) | 이슈 #12 본문 의도. validate(빠른 정적+유닛) 통과 후 느린 E2E 실행 |
| D3 | **옵트인 = 신규 선택 필드 `e2e.prePush`** (기본 생략=off), `e2e.enabled` 그리고 git 저장소일 때만 질문 | autoCommit·e2e.enabled 옵트인 선례. 기존 하네스 무영향 |
| D4 | **eslint e2e override 드롭 (YAGNI)** — 2b 범위에서 제외 | assist 규칙은 `{srcRoot}`만 타깃 → `e2e/`(srcRoot 밖)에 이미 안 닿음. Playwright-aware 린팅은 새 의존성 필요(원칙 충돌). 실제 마찰 시 핵심원칙 #5로 승격 |
| D5 | **신규 플레이스홀더 0개** (30 불변) | validate는 기존 `{{VALIDATE_COMMAND}}` 재사용, @critical은 `node_modules/.bin/playwright` 리터럴 |

> **정본 §8 대비 변경**: §8은 eslint e2e override(난제 ⑥)를 2b에 묶었으나, 본 설계는 D4로 드롭한다(실효 없음 + 원칙 충돌). 나머지 8개 난제(①②③④⑤⑦⑧⑨)는 §8 방향대로 해소한다.

---

## 3. 프로필 스키마 — `e2e.prePush`

```jsonc
"e2e": {
  "enabled": true,
  "prePush": true        // 선택 — 생략 시 false. e2e.enabled && git repo일 때만 질문
}
```

- **필드 규칙**: `e2e.prePush`는 선택 필드. 생략 = `false` = pre-push 산출물 0건.
- **질문 조건** (SKILL.md Phase 1): `e2e.enabled: true`로 확정 **그리고** `git rev-parse --is-inside-work-tree`가 참일 때만 옵트인 질문. git 저장소가 아니면 질문 자체를 생략(훅을 설치할 곳이 없음).
- **두 SKILL.md 동기**: SKILL.md 출력 스키마 = harness-scaffold/SKILL.md 입력 스키마. `e2e` 블록에 `prePush` 추가(양쪽 동일 텍스트).
- **manifest.profile 저장**: 기존 `e2e`(있는 경우만) 저장 규칙이 `prePush`를 포함(중첩 필드라 자동 포함).

---

## 4. 훅 파일 & 활성화 (D1)

### 4.1 신규 파일

| 파일 | 카테고리 | 템플릿 | 치환 |
|------|---------|--------|------|
| `.githooks/pre-push` | **managed** | `templates/githooks/pre-push` | `{{VALIDATE_COMMAND}}` ← 프로필 scripts.validate |

- 생성 조건: `e2e.prePush: true`일 때만 (harness-scaffold 신규 § 5.18).
- managed 카테고리 → § 12.6 자동 감지로 템플릿 변경 전파. file→template 매핑 테이블에 등록.

### 4.2 훅 본문 (fail-fast, POSIX sh)

마커 블록 `harness-setup:e2e-prepush:start/end`로 감싼다(공존성·멱등성·업그레이드 보존). `set -e` 대신 **명시적 `|| exit 1`** — 동일 블록이 standalone 파일과 기존 훅 주입 양쪽에서 호스트 동작을 바꾸지 않도록.

```sh
#!/bin/sh
# harness-setup:e2e-prepush:start — harness가 관리하는 블록. 직접 수정 시 업그레이드에서 보존되지 않을 수 있다.
# pre-push 게이트: validate → @critical E2E.
# ⚠️ 보안: 이 훅은 push 시 임의 코드를 실행한다 (Phase 4 고지 참조).
ROOT=$(git rev-parse --show-toplevel) || exit 1
cd "$ROOT" || exit 1

# ① validate (빠른 정적+유닛, fail-fast) — 스캐폴드 시점 PM으로 치환됨
{{VALIDATE_COMMAND}} || exit 1

# ② @critical E2E — playwright 실제 설치 + 매칭 스펙 존재 시에만 (PM 비종속)
PW="$ROOT/node_modules/.bin/playwright"
if [ -x "$PW" ]; then
  # --list --grep으로 실제 매칭 판정 (소스 grep 오탐 회피). 0개면 no-op.
  if "$PW" test --list --grep @critical 2>/dev/null | grep -q '\.e2e\.ts'; then
    "$PW" test --grep @critical || exit 1
  else
    echo "ℹ️ @critical E2E 스펙 없음 — pre-push E2E 게이트 건너뜀"
  fi
else
  echo "ℹ️ playwright 미설치 — pre-push E2E 게이트 건너뜀 (의존성 설치 후 활성)"
fi
# monorepo 하위 패키지: 이 훅은 repo-root 기준. 하위 패키지의 playwright는 미탐지될 수 있음(명시적 한계).
# harness-setup:e2e-prepush:end
```

> `--list --grep @critical` 출력 파싱(`.e2e.ts` 매칭)의 정확한 형태와 0-exit 동작은 **골든 픽스처로 검증**한다(§ 11).

### 4.3 공존성 — 적응형 마커 주입 (난제 ②)

스캐폴드/업그레이드가 기존 git hook 환경을 감지하여 분기한다(텍스트 파싱만 — eslintAssist 비실행 원칙 준용):

| 환경 | 동작 |
|------|------|
| **그린필드** (hooksPath 미설정 + `.git/hooks/pre-push` 없음 + `.githooks/` 없음) | `.githooks/pre-push` 신규 생성. Phase 4가 `git config core.hooksPath .githooks` 안내 |
| **기존 hooksPath/Husky** (`core.hooksPath` 설정됨 또는 `.husky/pre-push` 존재) | **그 경로의 pre-push에 마커 블록만 주입**(git config 변경 불필요 — 이미 활성). 파일 없으면 생성 |
| **`.git/hooks/pre-push` 존재** (기본 hooks 경로에 사용자 훅) | core.hooksPath로 전환하면 기본 훅이 무력화되므로 **자동 전환하지 않는다** → 폴백 |
| **비표준/파싱 불가/판단 불가** | **폴백**: 수정하지 않고 Phase 4에 권고 스니펫(마커 블록) + 수동 안내 출력. 비활성 보고. 에러 아님 |

- **멱등**: 마커 `harness-setup:e2e-prepush:start`가 이미 존재하면 스킵.
- **활성 여부 정직 보고**: 주입은 했으나 hooksPath가 그 경로를 가리키지 않으면 "비활성"으로 보고(harness-check ⑨).

### 4.4 활성화 = 수동 (D1)

- 스캐폴드는 **어떤 경우에도 `git config`를 실행하지 않는다.**
- Phase 4 보고가 출력: ① 활성화 명령(`git config core.hooksPath .githooks` — 그린필드만, 기존 hooksPath면 이미 활성) ② **보안 고지**(git hook은 push 시 임의 코드 실행, 신뢰할 수 있는 저장소에서만) ③ 비활성화 방법(`git config --unset core.hooksPath`).

---

## 5. 견고성 난제 해소 (③④⑤⑧)

| 난제 | 해소 |
|------|------|
| ③ PM/설치 판정 | playwright는 `node_modules/.bin/playwright` 직접 호출(npm/pnpm/yarn 비종속 + 실제 설치 판정 = 실행 가능 바이너리 존재). package.json 존재로 판정하지 않음 |
| ④ @critical 탐지 | `playwright test --list --grep @critical`로 실제 매처 사용. 소스 `grep`(주석/문자열 오탐, Playwright `--grep` 의미와 상이) 미사용 |
| ⑤ 실제 설치 판정 | `[ -x "$PW" ]` (실행 가능 바이너리). 0개 매칭/미설치 → no-op exit 0(push 차단 안 함) |
| ⑧(monorepo) | repo-root = `git rev-parse --show-toplevel`. **하위 패키지 단독은 명시적 한계로 보류** — 훅 주석 + Phase 4 고지(침묵 누락 금지) |

---

## 6. harness-check ⑨ (경고 전용)

`templates/harness-check.sh`에 ⑨ 추가. **경고 전용** — exit code·"표준 하네스 가동" 판정과 **분리**(난제 ⑦⑨: harness-check 통과 ≠ pre-push 활성/통과).

- 실행 조건: `.githooks/pre-push` 존재 또는 `core.hooksPath` 설정 시(둘 다 없으면 항목 자체 생략).
- 검사·보고:
  - pre-push 마커(`harness-setup:e2e-prepush`) 존재 여부.
  - `core.hooksPath`가 마커 보유 경로를 가리키는지 → **활성/비활성** 명시 보고(외부 상태, manifest 밖 — 난제 ⑦).
  - `node_modules/.bin/playwright` 실행 가능 여부(미설치면 게이트 무력 안내).
- 헤더 주석의 "경고 전용 (⑥⑦⑧)" → "(⑥⑦⑧⑨)" 갱신. 판정 로직(STRUCT_FAIL/QUALITY_FAIL) 불변.

---

## 7. eslint e2e override — 드롭 (D4, 결정 기록)

- **드롭 근거**: (1) eslintAssist의 `no-restricted-imports`는 `{srcRoot}{layer}/**`, `max-lines`는 `{srcRoot}**` 대상 → `e2e/`(srcRoot 밖)에 **이미 닿지 않음**. (2) "Playwright-aware" 린팅은 `eslint-plugin-playwright`(새 의존성) 필요 → no-new-deps 원칙 충돌. (3) 프로젝트 base eslint가 e2e를 오플래그하는 건 우리가 관리하는 설정이 아님.
- **승격 조건**: 프로젝트 base config가 e2e를 실제로 오플래그하는 마찰이 반복되면(핵심원칙 #5) 별도 마커 `harness-setup:e2e-eslint:start/end`로 최소 방어 블록을 증분 4에서 도입.
- 정본 §8의 난제 ⑥(별도 마커)은 **승격 시 적용할 해소 방향으로 보존**(폐기 아님).

---

## 8. 마이그레이션 / manifest / U1 재감지

### 8.1 마이그레이션 — 1.11.0 옵트인 선례 (별도 M-엔트리 불필요)

증분 1(1.11.0)도 신규 파일(playwright.config 등)을 추가했으나 "옵트인·생략 기본 → 마이그레이션 불필요"로 처리됐다. 2b도 동일:

- 기존 하네스 업그레이드: `e2e.prePush` 필드 없음 → 신규 파일 미생성 → 버전 레이블만 1.14.0(managed 자동 감지가 harness-check.sh ⑨ 추가분을 전파).
- 신규 파일 생성은 **U1 재감지 옵트인** 경로로만 발생(아래 8.3).
- 결론: **별도 마이그레이션 레지스트리 엔트리 없음.** (플랜에서 최종 확인 — §10.3 "M-1.4.0 이후 마이그레이션 불필요" 주석에 1.14.0 추가.)

### 8.2 manifest 등록

- `.githooks/pre-push`를 manifest.files에 **managed**로 등록(생성된 경우만).
- § 12.6 file→template 매핑 테이블에 `.githooks/pre-push ↔ templates/githooks/pre-push` 추가 → 템플릿 변경 자동 감지 대상.
- 카테고리 계약(정합성 §9): config·훅 = managed.

### 8.3 U1 재감지

- 기존 `e2e.enabled` 하네스 업그레이드 시 `prePush` 옵트인 **제안**(superpowers/consult U1 재감지 패턴 준용). 수락 시 § 5.18 생성 로직(§ 4.3 공존성 포함) 실행 + manifest 등록.
- 생략 기본 → 무강제. 거절/미응답 시 산출물 0건.

---

## 9. 정합성 계약 (구현 시 동시 갱신 필수)

1. **프로필 스키마**: SKILL.md 출력 = harness-scaffold/SKILL.md 입력 (`e2e.prePush`).
2. **생성 파일 목록**: harness-scaffold § 5 목록 = `templates/` 구조 = manifest.files = § 12.6 매핑 = harness-check 타깃.
3. **카탈로그 렌더링 규칙**(Phase 4): @critical pre-push 게이트 광고 줄은 산출물 게이트 신호(`e2e.prePush`)를 동일하게 가진다 — **순수 투영**(미와이어 능력 광고 금지). prePush 미옵트인이면 카탈로그/보고에 pre-push 줄 없음.
4. **플레이스홀더**: 신규 0개. `{{VALIDATE_COMMAND}}` 재사용을 치환표에 별도 추가하지 않음(이미 존재).
5. **버전**: project-context.md·CHANGELOG.md·프로필/매니페스트 version·versioning-policy.md·git tag 동시 1.14.0.

---

## 10. 수정 / 신규 파일

**신규**:
- `templates/githooks/pre-push` (훅 템플릿, § 4.2)
- `test/` 골든 픽스처: `@critical` 매칭 케이스 + 0-매칭 no-op 케이스 (§ 11)

**수정**:
- `SKILL.md` (Phase 1: e2e.prePush 옵트인 질문 — git repo 게이트, 프로필 출력 스키마)
- `harness-scaffold/SKILL.md` (입력 스키마, 신규 § 5.18 pre-push 생성 + 공존성 분기, manifest 카테고리, 생성 순서, Phase 4 보고 — 활성화 명령+보안 고지+monorepo 한계, § 12.6 매핑, Phase 3 검증 항목, U1 재감지, § 10.3 "M-1.4.0 이후 마이그레이션 불필요" 주석에 1.14.0 추가)
- `templates/harness-check.sh` (⑨ 경고 전용 검사 + 헤더 주석)
- `references/harness-checklist.md` (§ 4.2 — @critical pre-push 게이트 = L4 강제 경로 명시)
- `references/versioning-policy.md` (1.14.0 — 신규 managed 파일 = MINOR, 플레이스홀더 30 불변 확인)
- `references/project-context.md`, `.tracking/{HANDOFF,CHANGELOG,TODO}.md`

**변경 없음**: 레이어 아키텍처 린터(`./src`만 스캔), 7개 에이전트(런타임 조건부 — 2a에서 배선 완료), vitest/tsconfig(비침습 유지).

---

## 11. 테스트 (골든 픽스처)

`test/` 또는 신규 `test/prepush-fixtures.sh`에 다음을 검증(템플릿 회귀):

1. **@critical 탐지 양성**: `@critical` 태그 스펙이 있는 픽스처에서 `playwright test --list --grep @critical`가 매칭 → 훅이 E2E 실행 경로 진입.
2. **0-매칭 no-op**: `@critical` 없는 픽스처에서 매칭 0개 → 훅이 exit 0(push 차단 안 함).
3. **미설치 no-op**: `node_modules/.bin/playwright` 부재 시 exit 0.
4. **마커 멱등**: 마커 존재 시 재주입 스킵.

기존 `test/run-fixtures.sh`·`test/e2e-fixtures.sh`와 동일 러너 패턴. 릴리스 전 실행.

> **검증 한계**(2a 교훈): harness-check(정적)는 런타임 훅 동작을 검증하지 못한다. 실제 push 게이팅은 파일럿(haja) 도그푸딩으로 확인 — 신규 파일·git config라 업그레이드 경로 실측 필요.

---

## 12. 9개 난제 ↔ 해소 매핑 (정본 §8 대조)

| 난제(§8) | 본 설계 해소 | 절 |
|----------|-------------|-----|
| ① 신규 managed 파일 마이그레이션 | 1.11.0 옵트인 선례 → 별도 M-엔트리 불필요, manifest 등록 + U1 재감지 | 8 |
| ② core.hooksPath 공존 | 적응형 마커 주입 + 4-환경 분기 + 폴백 | 4.3 |
| ③ PM 비종속 | `node_modules/.bin/playwright` 직접 | 5 |
| ④ @critical 탐지 | `--list --grep @critical` 실제 매처 | 5 |
| ⑤ 실제 설치 판정 | `[ -x "$PW" ]` 실행 가능 바이너리 | 5 |
| ⑥ eslint e2e override | **드롭(YAGNI)** — 승격 조건 보존 | 7 |
| ⑦ 멱등성/외부 상태 | harness-check ⑨ 활성/비활성 보고 | 6 |
| ⑧ 보안 고지 | Phase 4 git hook 임의 코드 실행 고지 | 4.4 |
| ⑨ "표준 하네스 가동" 분리 | ⑨ 경고 전용, 판정 미반영 | 6 |
| (추가) monorepo | repo-root 계산 + 하위 패키지 명시적 한계 | 5 |

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
