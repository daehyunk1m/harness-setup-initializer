# 루트 배치 계약 (Root Placement Contract)

> 하네스가 **대상 프로젝트**에 생성하는 파일/폴더의 배치 위치 계약이다. 어떤 산출물이 프로젝트 루트에 고정되어야 하는지, 왜 그런지, 무엇이 이동 가능한지를 박아둔다. **루트 정돈/재배치를 시도하기 전에 이 문서를 먼저 본다.**
>
> 전체 인벤토리·카테고리(managed/custom/data)는 `harness-scaffold/SKILL.md` § 10.1이 정본이다. 이 문서는 거기에 **배치 제약**이라는 직교 차원을 더한다.
>
> 근거: 멀티모델 자문(codex 결함 관점 + gemini 대안/운영 관점 + Claude 합성, 2026-06-18). 결론 — "전체 `.harness/` 이동은 정돈 이득 < 깨질 표면 + 마이그레이션 비용. 부분 이동도 실 대상이 작아 현재는 보류."

## 배치 제약 등급

| 등급 | 의미 | 이동 가능성 |
|------|------|------------|
| **🔒 고정-디스커버리** | 외부 도구가 고정 경로에서 읽음 — 옮기면 도구가 못 찾음 | 불가 |
| **🔒 고정-훅/상태** | 스킬의 Stop hook·`!command` 상태감지가 루트 경로에 묶임 | 스킬 자체 개정 없이는 불가 |
| **📁 루트 관례** | 생태계 보편 관례 — 사람·CI가 루트에서 기대 | 이동 비권장(DX 손실) |
| **📦 이동 가능(보류)** | 기술적으로 이동 가능하나 참조 결합도·비용 대비 이득 없음 | 보류 |

## 파일별 계약

| 파일/그룹 | 등급 | 사유 |
|-----------|------|------|
| `CLAUDE.md` | 🔒 디스커버리 | Claude Code가 루트에서 자동 로드 + 본문 `@AGENTS.md` import 기준점 |
| `AGENTS.md` | 🔒 디스커버리 | agents.md 관례 — Codex 등 범용 에이전트가 루트에서 읽음. 빌드/테스트 **명령어의 SoT** |
| `.claude/` (rules·settings) | 🔒 디스커버리 | Claude Code가 `.claude/`에서 rules/settings 디스커버리 |
| `package.json`·`.gitignore`·`tsconfig.json` | 🔒 디스커버리 | npm/git/ts 도구 관례 |
| `.harness-profile.json` | 🔒 훅/상태 | setup/scaffold § 0 `!command` 상태감지 + Stop hook이 루트에서 확인 |
| `.harness-manifest.json` | 🔒 훅/상태 | Stop hook 종료 조건 + 업그레이드가 deployed 경로로 파일 추적 |
| `ARCHITECTURE.md` | 📁 관례 | 루트 문서 관례, AGENTS.md/CLAUDE.md가 참조 |
| `docs/` (특히 `product-specs/` PRD) | 📁 관례 | 사람 가시성·최소 놀람의 법칙 — PRD/설계 문서를 dot-folder에 숨기지 않는다 |
| `scripts/` | 📁 관례 | 보편 관례 — 사람·CI가 직접 실행(`npm run`) |
| `agents/*.md` | 📦 이동가능(보류) | ⚠️ `.claude/agents/`로 옮기면 Claude Code **네이티브 subagent 디스커버리**가 켜져 호출 시맨틱이 바뀐다 — 중립 이동이 아님, PoC 필요 |
| `feature_list.json`·`claude-progress.txt` | 📦 이동가능(보류) | data SoT, 참조 결합도 높음(session-routine·agents·harness-check) |
| `.harness-friction.jsonl`·`.harness-feedback-cursor`·`.harness-intent.jsonl` | 📦 이동가능(보류) | 이미 dotfile이라 시각적 클러터가 거의 없음 → 이동 이득 적음 |

## 재배치 결정 — 현재 보류

전체/부분 `.harness/` 이동을 **현재 보류**한다. 사유:

1. must-stay(🔒) + 관례 폴더(📁)를 빼면 순수 이동 후보가 작다(`agents/` + 느슨한 2파일).
2. 이동은 매니페스트 § 10.1 경로 + § 12.6 파일↔템플릿 매핑 + `harness-check.sh` ① 하드코딩 + `doc-freshness.ts` 타깃 + 규칙/에이전트 문서 경로 + 골든 픽스처 + 업그레이드 rename-migration을 **한 세트로** 건드린다(블래스트 반경 큼).
3. `.harness-friction.jsonl`에 "루트 클러터"가 실제 마찰로 기록된 적 없다(pull 수요 없음).

이는 이슈 #15 Phase 2b-4 이연과 같은 보수성 게이트 논리다 — 입증된 pull이 없으면 빼둔다.

### 재검토 트리거 (하나 충족 시)
- 루트 클러터가 `.harness-friction.jsonl`에 실제 마찰로 ≥2회 기록.
- 어차피 마이그레이션을 동반하는 MAJOR 릴리스에 편승 가능.

### 재배치를 강행한다면
- **범위 최소화** — `agents/`만 후보. `.harness/agents/`보다 `.claude/agents/`(생태계 응집)를 우선 검토하되 **호출 시맨틱 PoC**를 선행한다. data 싱크·`docs/`·`scripts/`는 제외.
- 업그레이드는 **별도 rename-migration 버전**으로 — manifest에 `movedFrom`/`movedTo`/`preserveData: true` + 4경우(원본/대상 존재·수정 조합)를 처리한다. 단순 재스캐폴드 금지(멱등성·data 손실 위험).
- base-dir 변수 주입(`HARNESS_DATA_DIR` 등)은 지양 — 하드코딩 경로는 **결정론 자산**(grep 가능·골든 픽스처 정적 검증)이라 간접층이 단순성을 해친다.

> 자문 원본 아티팩트: `.claude/artifacts/consult/`(codex·gemini, 2026-06-18). 이 계약은 `project-context.md` § 설계 결정 "카운트 표기 SSoT 참조"와 같은 드리프트-방지 철학을 공유한다.
