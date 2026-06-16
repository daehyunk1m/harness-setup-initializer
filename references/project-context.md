# 하네스 셋업 스킬 — 프로젝트 컨텍스트

> 이 문서는 하네스 셋업 스킬의 설계 결정 기록이다.
> 스킬 개선 작업 시 배경 맥락으로 참조한다.
>
> 마지막 업데이트: 2026-06-13 (1.8.0 — 자동 커밋 confirm 모드)

---

## 1. 프로젝트 목적

하네스가 없는 프로젝트에 **에이전트 작업 환경(하네스)**을 자동으로 셋업해주는 Claude Code 스킬.

목표는 oh-my-claudecode 같은 대규모 시스템이 아니라, **작지만 직접 만든 하네스 셋업 도구**를 점진적으로 발전시키는 것이다.

### 핵심 설계 철학

하네스는 **특정 프레임워크나 아키텍처에 종속되지 않는다**. 하네스의 뼈대(AGENTS.md, progress, feature_list, 세션 루틴)는 어떤 스택이든 동일하며, 아키텍처 세부사항(레이어 규칙, 네이밍, 검증 패턴)만 프로젝트마다 다르다. SKILL.md는 범용 뼈대를 담당하고, 프리셋이 아키텍처 지식을 담당한다.

### 이론적 배경

- **Anthropic** "Effective Harnesses for Long-Running Agents" — Initializer + Coding Agent 2단계 패턴, feature_list.json 기반 점진적 진행, 세션 간 핸드오프
- **OpenAI** "Harness Engineering" — 컨텍스트 엔지니어링 + 아키텍처 제약 + 엔트로피 관리 3기둥 체계

통합 가이드: `references/harness-guide.md`

---

## 2. 스킬 디렉토리 구조

```
~/.claude/skills/harness-setup/
├── SKILL.md                      # 분석 스킬 (Phase 1 + Stop hook 오케스트레이션)
├── harness-scaffold/
│   └── SKILL.md                  # 스캐폴딩 스킬 (install.sh로 심볼릭 링크, user-invocable: false)
├── install.sh                    # 심볼릭 링크 생성 스크립트
├── presets/                      # 스택별 프리셋
│   ├── react-next.json           # React + Next.js (App Router) + 레이어 기반
│   ├── react-router-fsd.json     # React Router v7 + FSD
│   ├── react-vite.json           # React + Vite (SPA) + 레이어 기반
│   └── express-api.json          # Express + TypeScript API + 레이어 기반
├── templates/                    # 생성 파일 템플릿
│   ├── structural-test-layer.ts  # 레이어 기반 아키텍처 검증
│   ├── structural-test-fsd.ts    # FSD 아키텍처 검증
│   ├── structural-test-domain.ts # 도메인 기반 아키텍처 검증
│   ├── harness-check.sh          # 하네스 자가진단 (체크리스트 §8 구현)
│   ├── agents/                   # TDD subagent 정의 템플릿
│   │   ├── architect.md
│   │   ├── test-engineer.md
│   │   ├── implementer.md
│   │   ├── reviewer.md
│   │   ├── simplifier.md
│   │   ├── debugger.md
│   │   └── security-reviewer.md
│   └── rules/                    # .claude/rules/ 템플릿
│       ├── session-routine.md    # TDD 오케스트레이션 플로우
│       └── coding-standards.md   # 아키텍처/네이밍 규칙
├── companion-skills/             # 컴패니언 스킬
│   ├── harness-feedback/         # 마찰 로그 분석 → GitHub Issue (install.sh 글로벌 링크)
│   ├── harness-cleanup/          # 엔트로피 정리 — 운영 사이클 실행 주체 (install.sh 글로벌 링크)
│   └── multi-model-consult/      # 멀티모델 합성 자문 — 하네스 비의존 범용 (install.sh 심링크, 글로벌)
└── references/                   # 배경 문서 (스킬 실행 시 자동 로드 안 됨)
    ├── harness-guide.md          # Anthropic + OpenAI 통합 가이드
    ├── harness-checklist.md      # 하네스 구성 체크리스트 (생성 하네스 판정 기준)
    ├── versioning-policy.md      # semver 버전 관리 정책
    ├── upgrade-system-design.md  # 업그레이드 시스템 설계
    ├── integrations/             # 외부 패키지 연계 매핑 정본
    │   └── superpowers-mapping.md
    └── project-context.md        # 이 파일
```

### 작업 환경

- **개발**: `cd ~/.claude/skills/harness-setup && claude`
- **테스트**: `cd ~/projects/haja && claude --add-dir ~/.claude/skills/harness-setup` (단일 등록으로 두 스킬 자동 디스커버리)
- **호출**: 프로젝트에서 "하네스 셋업해줘" 또는 `/harness-setup`

---

## 3. 설계 결정 사항

| 항목 | 결정 | 근거 |
|------|------|------|
| 실행 환경 | Claude Code CLI | 스킬 시스템과 동일 생태계 |
| 지원 스택 | 프리셋으로 확장 가능한 범용 구조 | v2에서 범용화 |
| 기존 코드 처리 | 안 건드림 — 문서/설정만 추가 | 안전 최우선 |
| 인터랙션 수준 | 소스 분석 → 소크라테스 문답 → 승인 → 생성 | v2에서 문답 단계 추가 |
| 프리셋 시스템 | JSON 프리셋 + 프리셋 없이도 동작 | 문답으로 즉석 프로필 구성 가능 |
| 에이전트 구조 | TDD subagent 파이프라인 (7 agents) | oh-my-claudecode 참조, Coding 그룹 우선 구현 |
| Orchestrator 위치 | CLAUDE.md + .claude/rules/ (subagent 아님) | 핸드오프 비용 최소화, 상태 머신 단순화 |
| TDD 워크플로 | Red → Green → Refactor 강제 | 테스트 없는 기능 완료 방지 |
| 배포 위치 | `~/.claude/skills/` | 글로벌 스킬, 모든 프로젝트에서 사용 |
| 실행 모델 | 분석: 메인 세션 / 스캐폴딩: 메인 세션 (fork 제거) | fork는 권한/디렉토리/타임아웃 문제로 Skill 도구 체이닝 비호환. 두 스킬 모두 메인 세션에서 실행 |
| 피드백 수집 | session-routine 지시 기반 (hook 아님) | TDD 내부 이벤트에 hook 불가, 오케스트레이터 지시로 충분 |
| 컴패니언 스킬 배치 | companion-skills/ + **install.sh 글로벌 링크** (1.7.1~ — 구 Issue #8) | 초기엔 --add-dir opt-in이었으나, 생성 CLAUDE.md가 "하네스 피드백 분석해줘"를 안내하는데 스킬이 디스커버 안 되는 불일치 발생. install.sh가 companion-skills/* 전부를 ~/.claude/skills/에 루프 링크하여 자연어 호출 가능 (사용자 결정) |
| 업그레이드 시스템 | A(마이그레이션 레지스트리) + B(파일 카테고리 분리) | 사용자 커스터마이징 보존 + managed 파일 자동 갱신. 상세: `references/upgrade-system-design.md` |
| 버전 추적 | `.harness-manifest.json` (단일 파일) | 파일별 주석 스탬프 대신 하나의 JSON으로 전체 상태 파악. 전체 profile 저장으로 재스캔 없이 재치환 |
| 실전 테스트 전 준비도 | 전수 분석 후 바로 실행 가능 판정 | SKILL.md 100%, 템플릿 17/17, 플레이스홀더 21/21 매핑 완료. 7개 리스크는 TODO-45~51로 추적 |
| 2-스킬 분리 (분석 + 스캐폴딩) | SKILL.md → 분석+Q&A, harness-scaffold/SKILL.md → 스캐폴딩+검증+보고 | 분석은 멀티턴 Q&A 필요, 스캐폴딩은 구조화된 파일 생성. 두 스킬 모두 메인 세션에서 실행 (fork 제거 — 권한/디렉토리/타임아웃 문제). Phase 1 완료 후 Skill 도구로 자동 체이닝. `.harness-profile.json`이 두 스킬 간 계약 (GitHub Issue #1) |
| Hook-driven continuation | Stop hook `decision: "block"` + `additionalContext`로 체이닝 강제 | 프롬프트 기반 체이닝은 비결정적. Stop hook은 시스템 레벨 강제로 더 결정적. oh-my-claudecode ralph, barkain/workflow-orchestration 패턴 참조. 프롬프트 지시는 이중 안전장치로 유지 |
| `!command` 상태 감지/프로필 주입 | SKILL.md § 0에서 상태 감지, scaffold § 0에서 프로필 데이터 주입 | 셸 커맨드는 결정론적. 스킬 프롬프트에 사전 렌더된 상태/데이터를 주입하여 LLM의 판단 부담 감소. planning-with-files 패턴 참조 |
| scaffold 심볼릭 링크 디스커버리 | `harness-scaffold/`를 리포 루트에 배치 + `install.sh`로 `~/.claude/skills/harness-scaffold` 심볼릭 링크 생성 | `--add-dir`의 중첩 `.claude/skills/` 디스커버리가 동작하지 않는 문제 해결 (Issue #3). `install.sh` 원커맨드 설치로 UX 마찰 최소화 |
| scaffold `user-invocable: false` | 사용자 `/` 메뉴에서 숨김 | scaffold는 오케스트레이터(setup)가 호출하는 내부 스킬. 사용자가 직접 호출할 필요 없음. 자연어 요청 시에는 Claude가 여전히 호출 가능 |
| 체크리스트 기준 문서 편입 | `references/harness-checklist.md`를 Phase 3 검증·단계 판정·harness-check.sh의 판정 기준으로 사용 | 하네스가 "제대로 돌아간다"의 기준을 기계 판정 가능하게 문서화 (MVH/표준/운영 단계). 산점된 체크포인트를 단일 기준으로 통합 |
| 명령어 SoT 위치 | AGENTS.md "## 명령어" (CLAUDE.md는 @AGENTS.md import로 참조) | 범용 에이전트(Codex 등)는 CLAUDE.md를 읽지 않음. agents.md 표준 관행과 일치. 체크리스트 §1.2 충족. 행동 지침 SoT는 여전히 CLAUDE.md |
| 자가진단 스크립트 언어 | bash (`templates/harness-check.sh`, `npm run harness:check`) | 진단 도구는 진단 대상(tsx/node_modules)에 의존하면 안 됨 — 깨진 상태에서도 구조 항목은 보고 가능. init.sh와 일관. 구조 항목(①②③)과 품질 항목(④⑤)을 구분 보고 |
| ESLint 보조 규칙 | Q&A 옵트인 → 마커 블록 외과 수정, 실패 시 권고 스니펫 폴백 | "기존 설정 비수정" 원칙의 예외는 사용자 명시 동의 기반으로만 허용 (package.json scripts와 동급). structural-test가 주 검사, ESLint는 에디터 실시간 보조. tsconfig는 검사만(harness-check ⑦) |
| 비대화형 검증 명령 원칙 | 프로필 `scripts.test`와 validate 구성 명령은 모두 단발 실행이어야 한다. watch 기본 러너는 `test:run` 키 추가로 우회 (기존 `test` 키는 비수정) | 실전 테스트(haja-web-fe)에서 `vitest`(watch 기본)가 validate에 조합되어 검증 루프가 53분 영구 대기. 에이전트 검증 루프 전체가 validate에 의존하므로 치명적 |
| detection.exclude 필드 | 프리셋 detection에 선택 필드 `exclude` — 나열된 패키지가 존재하면 후보 제외 | required가 범용 패키지(react, vite)인 프리셋이 더 구체적인 스택(next, react-router)을 오매칭하는 것을 방지. react-vite/express-api 프리셋 추가의 전제 조건 |
| domain-based 검증 템플릿 | 동적 생성 → `templates/structural-test-domain.ts` 템플릿 채택. 도메인 목록은 실행 시점에 srcRoot 하위 디렉토리에서 발견 | 템플릿이 있어야 § 12.6 자동 감지가 동작 (해시 추적). 도메인 목록을 하드코딩하지 않아 도메인 추가/삭제 시 스크립트 수정 불필요. 공유 모듈은 프로필 `sharedDirs`(기본 ["shared"])로 치환. custom 유형만 동적 생성으로 남김 (자동 감지 제외) |
| feature_list 추론 정책 | 라우트 기반(1순위) → 기능 모듈 기반(2순위) → 빈 배열(폴백). 상한 15개, 초과분은 보고에 명시 | 추론 기준이 모호하면 스캐폴딩마다 결과가 달라진다. 라우트가 사용자 관점 기능 단위와 가장 가깝고, 침묵 누락 금지 원칙(no silent caps) 적용 |
| Cleanup 스킬 배치 | `companion-skills/harness-cleanup/` (별도 저장소 아님) | harness-feedback과 동일한 배포/호출 모델. "별도 스킬" 결정(P10 범위 분리)은 유지하되 저장소는 단일화. 1.7.1부터 install.sh 글로벌 링크 |
| Cleanup 스킬 scope | 하네스 문서·상태 필드·잔존 산출물만 직접 수정. 소스 코드 동작 변경은 TECH_DEBT/feature_list 항목화로 TDD 사이클에 위임 | 정리 루프가 코드를 직접 고치면 TDD 파이프라인(테스트 우선)을 우회하게 된다. oh-my-claudecode ai-slop-cleaner의 "삭제 우선 + scope 제한" 패턴 채용. 루틴 판별은 docs/CLEANUP_LOG.md 경과 시간 기반 |
| 외부 통합 메커니즘 | 프로필 선택 필드 `integrations.<name>` — 감지 시에만 질문(옵트인), 생략 = 미적용, 코어 충돌 영역 제외, 매핑 정본은 references/integrations/ | 코어 자급자족 유지. eslintAssist의 "감지 → 옵트인 → 생략 = 미적용" 패턴 재사용. 규약 문서화는 두 번째 통합 구현 시 일반화 (선례 1개로 규약화 안 함) |
| superpowers 드리프트 대응 | 버전 호환 매트릭스 대신 **스캐폴딩 시점 스킬 실존 검증** (installPath/skills/{name} 확인 → 드롭+경고) | semver 범위 검사는 스킬 이름 변경을 못 잡는다. 실존 검증이 드리프트를 직접 잡음. detectedVersion은 정보용만 |
| 통합의 managed 템플릿 처리 | 조건부 텍스트는 scaffold 임의 삽입이 아니라 **템플릿 플레이스홀더**(`{{INTEGRATION_NOTES}}`, 미연계 시 빈 문자열)로 | scaffold가 템플릿 밖 텍스트를 삽입하면 § 12.6 자동 감지(재렌더링 해시 비교)가 깨진다. 재렌더링 재현성 유지 |
| multi-model-consult 배치 | companion-skills/ + **install.sh 심볼릭 링크** (글로벌 상시 로딩) | 하네스 비의존 범용 도구라 프로젝트 무관 상시 가용이 맞음. 저장소·버전·배포는 일원화 (사용자 결정). 1.7.1에서 feedback/cleanup도 같은 글로벌 링크로 일원화 (구 Issue #8) |
| 자문 CLI 권한 최소화 | codex `-s read-only --ephemeral`, gemini `--yolo` 없이 — oh-my-claudecode의 dangerous 플래그 패턴 폐기 | 자문은 읽기 전용. 컨텍스트는 Claude가 프롬프트에 포함 (자문 모델에 저장소 쓰기 권한 불필요). codex `-o`로 최종 응답 파일 캡처 |
| 외부 응답의 인젝션 방어 | 아티팩트 Raw Output은 데이터 — 합성 시 외부 응답 내 지시문 비추종 (SKILL.md 제약 명시) | 외부 모델 출력은 신뢰 경계 밖 |
| 보장 표현 정직화 (1.9.0) | "표준 하네스 가동"에 "구조 설치+실행 가능성만 의미, 의미 정확성 비판정" 캐비엇 (checklist §7, Phase 4, harness-check.sh). 과장 표현("구조 위반이 기계적으로 차단") 완화 | codex+gemini 자문 공통 결론: 보장되는 것은 구조뿐. harness:check 통과는 "규칙이 옳다"는 보장이 아님 |
| Q2 미강제 단계 강등 (1.9.0) | custom/빈 규칙 structural-test는 `{{Q2_ENFORCEMENT}}=unenforced` 마커 → harness-check ④-b가 grep해 MVH 강등(exit 0 경고), manifest `structuralTestEnforcement` 기록 | codex: exit-0 폴백이 "표준 하네스"로 오판정되는 silent failure. 표준=§3.2(규칙 강제) 충족 전제. 하드 실패 대신 강등+경고(자유 구조의 정당한 약한 상태 — 사용자 선택) |
| structural-test 골든 픽스처 (1.9.0) | 스킬 레벨 `test/fixtures/` + `test/run-fixtures.sh` (생성 프로젝트 footprint 0). 6/6 통과 실측 | codex 메타테스트 + gemini negative testing 권고. "템플릿 자체의 정확성/회귀"를 검증 (프로젝트별 규칙 오설정은 의미 게이트가 보완). 프로젝트별 selftest 대신 스킬 레벨 택해 타겟 청결 유지 (사용자 선택) |
| 의미론적 승인 게이트 (1.9.0) | scaffold Phase 4 "아키텍처 정확성 확인" — 생성 제약 재요약+사용자 확인(비차단), manifest `semanticApprovalAt` | 구조 검증은 의미 정확성을 보장 못 함(자문 공통). Step 5 승인은 프로필 대상이고 문서는 그 이후 생성되므로 의미 게이트가 부재했음 (gemini 권고) |
| 프로필 스키마 검증 보류 (1.9.0) | gemini의 ".harness-profile.json 경량 JSON Schema 결정화" 제안 보류 | 1.6.2에서 "JSON Schema 분리=과한 코드화"로 이미 비수용. 산문 사양+LLM 실행 철학 유지. 두 스킬 간 계약 드리프트가 실제 마찰로 누적되면 재검토 (사용자 선택) |
| 첫 셋업 능력 카탈로그 (1.10.0) | scaffold Phase 4 보고에 "이제 할 수 있는 일" 블록(≤12줄, 신규 파일 0) — 와이어된 능력만 조건부 렌더하는 **순수 투영**, U5(업그레이드)는 미출력 | 첫 셋업 직후 "무엇을→어떻게"가 불명확(이슈 #11). 새 손-관리 목록은 최대 드리프트 위험 → 산출물 게이트 신호(`integrations`/생존 `linkedSkills`/`tdd.securityCategories`) 재사용해 미와이어 능력 광고 차단. Security Reviewer는 §5.10 게이트가 아니라 session-routine Phase 4.5 호출 조건이 실제 게이트(이슈 표기 교정) — 카탈로그는 파이프라인을 열거하지 않고 정본을 가리킴 |
| E2E TDD 배선 (1.12.0, 증분 2a) | E2E를 TDD에 배선: test-engineer가 작성(결정 a — 신규 에이전트 아님, 7개 불변), VERIFY(E2E) Phase 4.7이 해당 feature 스펙만 실행, debugger 재현. 게이트는 명시적 E2E 판정(침묵=BLOCK)+TDD STATE+`@feature:` grep 키로 결정화(LLM 기억 비의존). pre-push는 증분 2b로 분리 | 멀티모델 적대적 검증(codex/gemini): 암묵적 "RED가 E2E 썼나" 게이트는 재개 세션·컨텍스트 밀림에 취약. VERIFY 전체 스위트는 플레이키니스 환각 루프 → feature 스펙만+시도 한도. 인프라(pre-push)와 워크플로(배선)는 실패 도메인이 달라 분할. 전부 managed 편집 → §12.6 자동 전파, 플레이스홀더 0(29 불변) |
| E2E VERIFY 러너 정합 (1.13.0) | VERIFY(E2E) 실행 명령을 `{{TEST_COMMAND}}`(유닛 러너)→신규 `{{E2E_COMMAND}}`(E2E 러너, `<pm> run test:e2e`)로 교체. 새 프로필 필드 없이 `e2e.enabled`+`test:e2e` 스크립트에서 도출(29→30) | haja 1.9→1.12 파일럿 적대적 검증: 유닛 러너로는 `.e2e.ts`가 글롭에 미수집 → 0개 실행 후 exit 0(거짓 PASS)로 게이트 무력화. "계열" 헷지는 하드 치환 토큰 앞에서 무의미(§6.11이 이미 치환). 동반 수정: seed.ts `void payload`(F1, no-unused-vars), harness-check ⑧ references 위임루트 short-circuit(F2). harness:check가 런타임 Phase 4.7을 안 거쳐 못 잡음 → 실전 기능 주행이 검증에 필수임을 입증 |
| 이슈 #12 증분 2b 게이트 (1.14.0) | 활성화 수동(D1 — git config 비실행, "승인 없이 git 실행 금지" 정합), 게이팅 `validate`→`@critical`(D2), 옵트인 `e2e.prePush`(D3), eslint override 드롭(D4 — e2e/는 srcRoot 밖이라 assist 규칙 미도달, 승격 조건만 보존), 신규 플레이스홀더 0(D5). 공존성 4-환경 분기(그린필드/기존 hooksPath·Husky/기본 hooks/폴백) + 적응형 마커 주입. harness-check ⑨ 경고 전용(판정 분리) | 설계 정본: `docs/superpowers/specs/2026-06-16-e2e-prepush-2b-design.md` |
| 이슈 #12 증분 3 MCP 진단 (1.15.0) | 배치 = e2e 모듈 확장(integrations 규약 비사용 — debugger가 코어 SoT라 통합 규약 #3 "코어 충돌 영역 제외"와 충돌). 산출물 = 공유 `.mcp.json` 비커밋(Claude Code 승인 nagware·머지 지옥·관심사 분리 회피) → debugger.md 지침 + 개발자 로컬 `claude mcp add`. 분리 옵트인 `e2e.mcp`(`enabled`/`version`, `e2e.enabled`와 독립). 공식 `@playwright/mcp` exact 핀 `0.0.76`. `{{MCP_DEBUG_PROTOCOL}}`(30→31) | 멀티모델 자문(codex·gemini)이 비커밋 B안 권고 — 공유 .mcp.json 미생성. gemini의 "ad-hoc npx" 오류는 MCP 등록 메커니즘 오해라 합성자가 교정. 설계 정본: `docs/superpowers/specs/2026-06-16-e2e-mcp-incr3-design.md` |

---

## 4. 버전 히스토리

### v1 (초기)
- SKILL.md 초안, react-next.json 프리셋
- Next.js 레이어 기반에 하드코딩

### v2 (리팩터링)
- SKILL.md 범용화 — 아키텍처 종속 제거
- 소스 코드 딥스캔 + 소크라테스 문답 단계 추가
- 프로젝트 프로필 개념 도입
- 아키텍처 유형 분류 체계 (layer-based / fsd / domain-based / custom)
- react-router-fsd.json 프리셋 추가
- 프리셋 스키마에 architecture 필드 추가

### v2.1 (Claude Code 스킬 이전)
- `{SKILL_DIR}` 플레이스홀더 → 상대 경로 참조로 변경
- frontmatter description 트리거 최적화
- 디렉토리 구조를 `~/.claude/skills/harness-setup/`에 맞게 정리
- references/ 섹션 추가
- claude.ai 프로젝트에서 Claude Code 스킬로 개발 환경 이전

### v3 (TDD Subagent 파이프라인)
- Coding Agent 그룹을 7개 subagent로 분리 (Architect, Test Engineer, Implementer, Reviewer, Simplifier, Debugger, Security Reviewer)
- TDD Red → Green → Refactor 사이클 기반 오케스트레이션
- `.claude/rules/` 분리 — session-routine.md (TDD 플로우), coding-standards.md (코드 규칙)
- CLAUDE.md 슬림화 (200줄 → 150줄) — 상세 규칙을 .claude/rules/로 이관
- Agent Dispatch 테이블 도입 — 어떤 에이전트를 언제 호출하는지 명시
- 에스컬레이션 체인 — Implementer 3회 → Debugger 2회 → 사용자
- claude-progress.txt에 TDD STATE 블록 포맷 추가 (세션 간 사이클 이어받기)
- oh-my-claudecode 참조 — 에이전트 전문화 패턴, 에스컬레이션 패턴 채용

### v3.3 (피드백 수집 시스템)
- 마찰 자동 감지: session-routine.md에 6개 마찰 이벤트 로깅 지시 추가
- HARNESS_FRICTION.md 템플릿: 기계 파싱 가능한 마크다운 테이블 형식
- 컴패니언 스킬 구조: companion-skills/ 디렉토리 도입, harness-feedback 스킬 스텁
- Phase 4 보고에 운용 스킬 안내 추가 (--add-dir opt-in 방식)

### v3.2 (템플릿 완비 + 트래킹 정리)
- 미생성 템플릿 4개 추가: init.sh, doc-freshness.ts, QUALITY_SCORE.md, TECH_DEBT.md
- SKILL.md 5.6~5.9절에 템플릿 참조 + 플레이스홀더 치환 규칙 추가
- Phase 3 검증 6.11에 새 템플릿 파일 포함
- P10 엔트로피 관리를 "범위 밖"으로 확정 (별도 cleanup 스킬로 분리)
- 트래킹 문서(HANDOFF, project-context, TODO) 현행화

### v4.0 (구현 완료 — 업그레이드 시스템)
- `.harness-manifest.json`: 버전 추적 + 전체 프로필 저장 + 파일별 해시/카테고리
- 파일 카테고리: managed(13개) / custom(4개) / data(5개) 분류
- 업그레이드 모드: Phase U1~U5 (분석 → 계획 → 실행 → 검증 → 보고)
- 마이그레이션 레지스트리: 버전 간 변경을 구조화된 지시로 기술, 순차 적용
- 부트스트랩: manifest 없는 기존 프로젝트를 v3.3으로 간주하여 편입
- SKILL.md § 14로 구현 완료 (TODO-44)
- 설계 문서: `references/upgrade-system-design.md`

### v5.0 (2-스킬 분리 — Issue #1 해결)
- 단일 SKILL.md → SKILL.md(분석) + harness-scaffold/SKILL.md(스캐폴딩) 분리
- 원인: `context: fork`가 서브에이전트로 분리 실행하여 멀티턴 Q&A(소크라테스 문답)가 불가
- SKILL.md: `context: fork` + `model: sonnet` 제거, Phase 1(분석+Q&A)만 담당
- harness-scaffold/SKILL.md: `context: fork` + `model: sonnet` 유지, Phase 2~4(스캐폴딩+검증+보고) 담당
- `.harness-profile.json`: 두 스킬 간 계약(contract) — 분석 스킬 출력 → 스캐폴딩 스킬 입력
- SKILL.md § 5에 프로필 출력 스키마 추가, 섹션 번호 § 6~12 재정렬
- CLAUDE.md: 파일 맵에 harness-scaffold/SKILL.md 추가, 개발 규칙/테스트/원칙 업데이트

### v5.1 (Hook-driven Continuation — 체이닝 결정론 강화)
- **Stop hook**: SKILL.md 프론트매터에 `hooks.Stop` 추가. 프로필 존재 + 매니페스트 미존재 → `decision: "block"` + `additionalContext`로 scaffold 호출 강제
- **`!command` 상태 감지**: SKILL.md § 0에 셸 전처리기 추가. 프로필/매니페스트 존재 여부를 결정론적으로 감지 → 중단 후 재개 지원
- **`!command` 프로필 주입**: scaffold § 0에서 프로필 JSON을 프롬프트에 사전 주입. Read 도구 호출 불필요
- **디렉토리 재구조화**: `harness-scaffold/`를 리포 루트에 배치. `install.sh`로 `~/.claude/skills/harness-scaffold` 심볼릭 링크 생성 (Issue #3 해결)
- **scaffold `user-invocable: false`**: 사용자 `/` 메뉴에서 숨김. 오케스트레이터 또는 자연어 요청으로만 호출
- **scaffold Stop hook**: 매니페스트 미존재 → `decision: "block"`으로 완료까지 강제
- 커뮤니티 패턴 참조: oh-my-claudecode ralph (boulder pattern), barkain/workflow-orchestration (hook-driven continuation), OthmanAdi/planning-with-files (skill-scoped hooks)

### v5.2 (안정화 + Plan 모드 통합)
- **Issue #2 수정**: `!command` 블록 실행 시 권한 에러 — SKILL.md, harness-scaffold/SKILL.md, harness-feedback/SKILL.md frontmatter에 `allowed-tools` 추가
- **Issue #3 수정**: scaffold 심볼릭 링크 디스커버리 실패 — `harness-scaffold/`를 리포 루트에 배치 + `install.sh` 심볼릭 링크 생성 스크립트
- **Issue #5 수정**: Plan 모드 진입 시 TDD subagent 파이프라인 우회 — Bridge 패턴 도입. Plan 모드를 PRE-RED(Architect) 대체로 취급, Plan 승인 후 RED부터 TDD 사이클 합류. session-routine.md에 "Plan 모드 통합" 섹션, CLAUDE.md/coding-standards.md에 금지 규칙 추가
- **이슈 보고 프로세스**: harness-feedback 컴패니언 스킬 스텁 → 실제 구현 (파싱→패턴 분석→초안→확인→gh issue create). HARNESS_FRICTION.md에 이슈 카테고리 7종 + 보고 안내 추가
- **리서치**: Opus vs Sonnet 모델 선택 가이드 (`references/model-selection-guide.md`) — 벤치마크, 하네스-Sonnet 연계 효과, opusplan 하이브리드, 서브에이전트 라우팅 전략
- **README 재작성**: 2-스킬 구조/Stop hook 체이닝 기반, Mermaid stateDiagram 실행 흐름, 시나리오별 동작 4가지

### 1.0.0 (semver 전환)
- **버전 체계 전환**: 레거시 이원 버전(스킬 v5.2 + 하네스 스키마 "3.3") → **단일 semver 1.0.0** 통합
- **semver 정책 수립**: `references/versioning-policy.md` — Public API 4개 계약(프로필/매니페스트/프리셋/생성파일) 선언, MAJOR/MINOR/PATCH 판단 기준, 릴리스 프로세스
- **스키마 버전 전환**: `.harness-profile.json` version "3.3" → "1.0.0", `.harness-manifest.json` version/skillVersion "3.3" → "1.0.0"
- **부트스트랩 업데이트**: 기존 프로젝트 편입 대상 버전을 "3.3" → "1.0.0"으로 변경
- v1~v5.2는 레거시 참조 기록으로 유지. 이후 모든 버전은 semver X.Y.Z 형식을 따른다.

### 1.1.0 (하네스 구성 체크리스트 기반 보강)
- **체크리스트 편입**: `references/harness-checklist.md` 신설 — 생성 하네스의 판정 기준 (Q1~Q4, §1~§8, MVH/표준/운영 단계). Phase 3 검증과 Phase 4 단계 판정이 이 문서를 기준으로 동작
- **자가진단 스크립트**: `templates/harness-check.sh` 신설 (managed) + `npm run harness:check` — 체크리스트 §8의 구현. 검사 7항목(구조 ①②③ / 품질 ④⑤ / 경고 ⑥⑦), 전체 통과 시 "표준 하네스 가동" 판정. 새 플레이스홀더 3종(`{{LINT_ARCH_COMMAND}}`, `{{DOC_CHECK_COMMAND}}`, `{{PATH_ALIAS_LIST}}`) — 총 24개
- **명령어 SoT 이동**: AGENTS.md에 "## 명령어" 섹션 신설 (source of truth), CLAUDE.md는 @AGENTS.md import로 참조. 역할 분리 테이블 갱신 (체크리스트 §1.2)
- **AGENTS.md 주요 규칙 필수 2종**: feature_list 보호 + passes 검증 규칙을 반드시 포함 (체크리스트 §2.1)
- **ESLint 보조 규칙 옵트인**: 프로필 선택 필드 `eslintAssist` 추가, Q&A 옵트인 질문(ESLint 설정 감지 시에만), scaffold §5.15 — 마커 블록 외과 수정 + 멱등 + 폴백 (체크리스트 §3.2)
- **승격 루프**: TECH_DEBT.md에 "자동 검사 승격 대기 큐" 섹션, reviewer.md에 반복 지적 감지 + 승격 후보 출력, session-routine.md Phase 4에 큐 기록·2회 이상 승격 제안 (체크리스트 §3.3)
- **검증 레벨 4단계**: coding-standards.md에 L1 정적/L2 유닛/L3 통합/L4 E2E 테이블 + steps↔E2E 1:1 매핑 규칙 (feature_list 생성 규칙, test-engineer.md에도 반영) (체크리스트 §4.2)
- **세션 루틴 보강**: 시작 절차 5분 목표, 회귀 우선 규칙 (session-routine.md, CLAUDE.md 금지 사항) (체크리스트 §5.1/§5.3)
- **운영 사이클 문서화**: CLAUDE.md에 일간/주간/격주/월간 테이블, QUALITY_SCORE/TECH_DEBT 헤더에 갱신 주기 (체크리스트 §6.3 — 실행은 사용자 몫)
- **마이그레이션**: M-1.0.0-to-1.1.0 등록 (harness-check 신설, AGENTS/CLAUDE 외과 수정, TECH_DEBT/QUALITY_SCORE data 패치, eslintAssist 프로필 필드)
- **스테일 참조 수정**: SKILL.md 내부 §14 → §12 참조 잔존분 정리, Step 5 생성 예정 파일 목록 누락분(git-workflow.md, HARNESS_FRICTION.md) 보완

### 1.2.0 (비대화형 검증 명령 보장)
- **실전 테스트 결과 (haja-web-fe, M-1.0.0-to-1.1.0 업그레이드)**: 자동 감지·마이그레이션·단계 판정 모두 사양대로 동작. AGENTS.md 60줄, manifest 22개 파일 추적. 자가진단이 프로젝트 품질 문제 2건(레이어 위반, 잔존 테스트 산출물)을 구조 문제와 정확히 구분 — "MVH 가동" 판정
- **발견된 스킬 갭**: `"test": "vitest"`(watch 기본)가 validate에 그대로 조합 → 비대화형 검증 루프 53분 영구 대기 (마찰 로그 경유 발견)
- **수정**: 프로필 `scripts.test` 비대화형 원칙 (SKILL.md Step 1.2 감지 + § 4.4 + 필드 규칙), scaffold § 5.5에 조건부 `test:run` 키 추가 + "validate 구성 명령은 모두 비대화형" 규칙, M-1.1.0-to-1.2.0 마이그레이션 등록 (기존 하네스의 validate 재조합 + profile 갱신)

### 1.3.0 (프리셋 확장 + domain 템플릿 + 추론 정책)
- **프리셋 2종 추가**: `react-vite.json`(React+Vite SPA, layer-based 7레이어), `express-api.json`(Express API, layer-based 8레이어 — routes→controllers→services→models 흐름, readyCheck 연결 성공 정규화)
- **detection.exclude 필드**: 프리셋 스키마에 선택 필드 추가 — 나열 패키지 존재 시 후보 제외 (범용 required의 오매칭 방지). 매칭 로직 3.3 단계 + 작성 가이드 갱신
- **react-router-fsd versionConstraints**: `react-router >= 7.0.0` (v6 이하 오매칭 방지, TODO-45)
- **domain-based 검증 템플릿**: `templates/structural-test-domain.ts` 신설 — 도메인 간 직접 import 금지 + 공유→도메인 역방향 금지, 도메인 목록 실행 시점 발견. 새 플레이스홀더 `{{SHARED_DIRS}}`(25번째) + 프로필 선택 필드 `sharedDirs` (TODO-46)
- **custom 동적 생성 알고리즘 구체화**: layers.rules 재사용 → extraArchitectureRules 기계화 → 최소 스크립트 폴백 4단계 (TODO-46)
- **feature_list 추론 정책**: 라우트 기반 → 기능 모듈 기반 → 빈 배열 3단계 + 상한 15개 + 보고 검토 안내 (TODO-47)
- **마이그레이션**: M-1.2.0-to-1.3.0 ([profile] sharedDirs, domain-based 한정)
- **TODO 정리**: TODO-50(harness-feedback)은 Session 14에 이미 구현 완료 — 상태 누락 정정. TODO-51(기록 체계), TODO-54(스키마 정합성), TODO-70(멱등성 — haja 1.2.0 업그레이드로 검증) 종결

### 1.4.0 (harness-cleanup 컴패니언 스킬)
- **harness-cleanup 신설** (`companion-skills/harness-cleanup/SKILL.md`): 운영 사이클(체크리스트 § 6.3)의 실행 주체 — P10 엔트로피 관리가 "범위 밖"에서 "컴패니언 스킬로 커버"로 전환
  - 루틴: 주간(doc:check, QUALITY_SCORE 재측정, 코드 엔트로피 스캔, harness:check) / 격주(TECH_DEBT 검토, 승격 큐 점검 — 횟수 ≥ 2 승격 제안) / 월간(문서-실구조 일치, passes 재검증, 종합 판정)
  - 루틴 판별: `docs/CLEANUP_LOG.md` 경과 시간 기반 자동 + 사용자 명시 우선
  - 원칙: 삭제 우선·승인 필수·scope 제한(소스 동작 변경은 TDD 위임)·기록 보존
- **scaffold 연계**: Phase 4 운용 스킬 안내에 추가, CLAUDE.md 운영 사이클에 안내 1줄, M-1.3.0-to-1.4.0 ([custom] 안내 추가, 멱등)
- **정정**: 저장소 CLAUDE.md의 harness-feedback "(스텁)" 표기 → 구현됨

### 1.5.0 (superpowers 옵트인 통합)
- **PRD 구체화** (.tracking/prd-superpowers-integration.md): 미결정 이슈 6건 해소 — 감지 경로(installed_plugins.json 1순위 + skills 폴백), 버전 추출(plugin manifest), 매핑 위치(references/integrations/), 스킬명 영어 유지, 삭제 시 안내문 잔류, 규약 일반화 보류. 실물 검증: superpowers v5.1.0, 스킬 14종 전수 (초안의 debugging/using-skills/code-review는 부정확한 이름이었음 — systematic-debugging/using-superpowers/requesting·receiving-code-review로 정정)
- **프로필 선택 필드 `integrations`**: superpowers — enabled/source/detectedVersion/installPath/linkedSkills. 생략 = 미연계
- **감지·질문**: SKILL.md Step 1.6 신설 (미감지 시 질문 생략 — 모르는 도구 비노출), § 4.2 옵트인 질문
- **렌더링**: scaffold § 5.16 신설 — 실존 검증(F1.7, 드롭+경고) → 제외 필터(F1.6, 매핑 정본 밖 비렌더링) → AGENTS.md "보조 스킬" 섹션 + session-routine `{{INTEGRATION_NOTES}}`(26번째 플레이스홀더, 미연계 시 빈 문자열)
- **매핑 정본**: references/integrations/superpowers-mapping.md — 연계 3(brainstorming, systematic-debugging, writing-plans) + 선택 1(using-superpowers) + 제외 10 (TDD·코드리뷰·검증·git·오케스트레이션 = 코어 SoT)
- **업그레이드**: U1에 외부 통합 재감지 (신규 감지 시 추가 제안, 기존 통합 제거 지원). 마이그레이션 등록 불필요 (생략이 기본값, 템플릿 변경은 자동 감지)
- Phase 3 검증 14 → 15항목 (6.15 연계/옵트아웃 양방향 검증)

### 1.6.0 (multi-model-consult 컴패니언 스킬)
- **PRD 구체화** (.tracking/prd-multi-model-consult.md): 미결정 이슈 5건 해소 (배치=companion+심링크, 하네스 연계=안정화 후, 아티팩트=수동 관리, 타임아웃=180s+env, 경로=기본 노출). CLI 실물 검증 — codex 0.134.0 로컬 실측으로 **위험 플래그 폐기** (`--dangerously-bypass-approvals-and-sandbox` → `-s read-only --ephemeral`, gemini `--yolo` 제거), `-o` 최종 응답 캡처 발견, 병렬은 Claude 병렬 도구 호출로 달성 (async 인프라 불필요)
- **구현 (M1+M2)**: `companion-skills/multi-model-consult/` — SKILL.md(분해 가이드 + 합성 포맷 + degradation 3경로 + 인젝션 방어 제약) + scripts/run-advisor.js (env 스트립, 비활성화 스위치, 타임아웃 부분 결과, 아티팩트 저장, `ARTIFACT:` 출력 계약). install.sh에 글로벌 심링크 추가
- **실측 테스트**: 종료 코드 4경로(사용법/비활성화/미설치/성공) + env 스트립 단위 검증 + **codex 실호출 E2E 성공** (5초, 아티팩트 포맷 정확). gemini 미설치 환경이라 degradation 경로가 실측으로 검증됨
- Public API(프로필/매니페스트/프리셋/생성 파일) 변경 없음 — 버전 단일화 원칙에 따라 스키마 version만 1.6.0 동기 (업그레이드 시 마이그레이션·자동 감지 모두 no-op)
- 하네스 연계(integrations.multiModelConsult + 통합 규약 일반화)는 스킬 안정화 후 별도 릴리스

### 1.6.1 (install.sh 멱등성 수정)
- `ln -sf` → `ln -sfn`: 대상 심링크 존재 시 따라 들어가 자기참조 심링크를 만드는 함정 수정. v1.6.0 커밋에 포함된 `harness-scaffold/harness-scaffold` 잔여물 제거. 2회 연속 실행 멱등성 검증

### 1.6.2 (멀티모델 자문 권고 반영)
- **multi-model-consult 첫 실사용** — 자문 대상은 이 스킬 구조 자체 (도그푸딩). codex 결함 관점 + Claude 대안 관점 합성, gemini 부재 degradation 실동작 확인
- 선별 수용 4건: Stop hook `approved: true` 검사 (초안/손상 프로필 오발동 방지), § 5.15 ESLint 비실행 원칙 명문화, .gitignore에 .claude/artifacts/, TODO-77(§ 12.6 해시 재현성 결정화 검토 — codex·Claude 합의된 유일한 코드화 후보) + TODO-53 픽스처 매트릭스 병합
- 비수용 (추측 설계 금지): 전면 코드화·JSON Schema 분리·마이그레이션 executable화·프리셋 confidence 모델 — 스킬 철학(산문 사양 + LLM 실행 + 마찰 루프 안전망)과 비용 대비 과함. 실전 마찰 누적 시 재검토

### 1.6.3 (gemini trust 게이트 수정 + 첫 3중 합성)
- **multi-model-consult 첫 3중 합성** — gemini CLI(v0.46.0) 설치 후. 자문 대상은 TODO-77 설계 결정. codex(source-fingerprint) + gemini(멱등성·운영) + Claude(합성)가 단일 모델의 A/B 이분법보다 나은 C안 도출 — 도그푸딩 성과
- **gemini trust 게이트 갭 수정** (TODO-79): 헤드리스 trusted-directory 게이트(exit 55)로 비신뢰 디렉토리 자문이 전부 실패하던 버그. `--approval-mode plan`(읽기전용 — codex `-s read-only` 대응) + `--skip-trust`(세션 한정). 실측 exit 55→0
- **TODO-77 C안 확정**: 템플릿 변경 판정을 "LLM 재렌더링 해시"에서 "소스 템플릿 파일 해시(`templateSourceHash`)"로 → LLM 바이트 재현 암묵 계약 제거. 구현은 별도 (manifest 스키마 MINOR), 실제 해시 오탐 마찰 누적 시 착수
- Public API 변경 없음 — 스키마 version 1.6.3 동기만

### 1.6.4 (누적 정합성 감사)
- **워크플로 적대적 감사** (TODO-80): 1.0.0→1.6.3 13회 릴리스 누적 드리프트를 기계적 사실 수집 → 5개 관점 병렬(카운트/섹션참조/계약동기화/파일인벤토리/트래킹일관성) 점검. 도그푸딩의 연장 (multi-model-consult에 이은 자기 검증 패턴)
- 진짜 드리프트 4건 수정: 현재 시제 "24개"→26개, SKILL.md 교차참조 명확화, 버전 히스토리 순서 재정렬+1.6.3 누락 추가, 마이그레이션 레지스트리 "1.4.0 이후 불필요" 안내
- **감사 방법론 교훈**: 감사 에이전트는 "현재 시제 서술 vs 역사 기록(버전 히스토리/CHANGELOG/세션 기록의 그 시점 사실)"을 구분 못 해 오탐을 낸다(이번 3건). 카운트 감사 시 이 구분이 핵심 — 자동 감사 결과는 맥락 검증 후 수용

### 1.7.0 (외부 통합 규약 일반화 + multi-model-consult 등록)
- **규약 정본** `references/integrations/_protocol.md`: superpowers(1.5.0)·multi-model-consult(1.6.0) 두 선례에서 공통 패턴 추출 → `integrations.<name>` 메커니즘 일반화. 통합 추가 4단계 절차 + 불변 원칙 8개 + 다중 통합 합산 형식
- **§5.16 일반화**: "superpowers 연계 렌더링" → "외부 통합 연계 렌더링". 두 감지 모델(superpowers=플러그인·다중 스킬 화이트리스트 / consult=컴패니언 심링크+CLI·단일 연계)을 같은 규약이 흡수 — 이것이 일반화 검증 기준
- **multiModelConsult 등록**: 두 번째 통합. 1.6.0 PRD의 "안정화 후 연계" 계획 실행 (3중 합성 실측 후)
- **AGENTS.md 섹션 형식 변경**: "## 보조 스킬 (superpowers 연계)" → "## 보조 스킬"(다중 통합 합산) + 항목 출처 표기. M-1.6.4-to-1.7.0이 기존 하네스 정규화
- **설계 절제**: _protocol.md는 실제 2선례에만 근거 — 플러그인 시스템류 미래 추측 설계 배제 (추측 설계 금지 원칙)

### 1.7.1 (깃 이슈 정리: #7·#8 해결)
- 열린 이슈 5건을 1.7.0 기준 대조 — 해결 2건 수정·닫기, 미해결 3건 구현 항목 등록(TODO-84~86)
- #8: install.sh를 companion-skills/* 루프로 → feedback/cleanup 글로벌 링크 (생성 CLAUDE.md "하네스 피드백 분석해줘" 안내와 디스커버리 일치). #7: 부트스트랩 "3.3"→"1.0.0" 문서 정정 (실질 버그는 semver 전환으로 해결됨)
- 컴패니언 배치 설계 결정: opt-in → install.sh 글로벌 링크 일원화

### 1.8.0 (자동 커밋 confirm 모드)
- **구 Issue #4 구현** (TODO-86): 프로필 선택 필드 `autoCommit: { mode: off|confirm|auto, pushAfterCommit }` — 생략=off(기존 제안만). confirm=메시지+diff 승인 후 commit+push, auto=승인 없이
- 새 플레이스홀더 2종(`{{AUTO_COMMIT_MODE}}`·`{{AUTO_COMMIT_PUSH}}`, 26→28) → git-workflow.md "## 자동 커밋 정책" 섹션. session-routine 커밋 단계가 모드 참조
- **절대 규칙과의 양립**: "승인 없이 git 실행 금지"는 off=제안만으로, confirm=승인이 곧 확인, auto=명시 옵트인=사전 포괄 승인으로 호환. 위험 작업(force/reset/대규모)은 어느 모드든 항상 제안. 마이그레이션 불필요(managed 자동 감지 + 생략 기본)

### 1.9.0 (보장 정직화 + 의미검증 — 멀티모델 자문 반영)
- **배경**: codex(결함)+gemini(검증/운영) 멀티모델 자문 — "이 스킬은 *의미적으로 올바른 하네스*를 보장하지 않는다". harness:check 통과는 구조 설치+실행 가능성만 보장하고, 규칙의 의미 정확성은 LLM 판단+마찰 루프에 의존. 두 진짜 갭(custom exit-0 silent pass, 의미 게이트 부재) + 메타테스트 부재 식별. 자문 아티팩트: `.claude/artifacts/consult/`
- **보장 정직화**: "표준 하네스 가동" 판정에 "구조 설치+실행 가능성만 의미, 문서·규칙 의미 정확성 비판정" 캐비엇 (harness-checklist §7, scaffold Phase 4, harness-check.sh). 과장 표현 완화
- **Q2 미강제 강등**: 새 플레이스홀더 `{{Q2_ENFORCEMENT}}`(28→29) — structural-test 헤더 마커. layer/fsd 빈 규칙·custom 폴백이면 `unenforced` → harness-check ④-b가 grep해 MVH 강등(exit 0 경고). manifest `harness.structuralTestEnforcement` 기록. 표준=체크리스트 §3.2 충족 전제 명문화. exit 0(강등+경고) vs 하드 실패는 사용자 선택 — 자유 구조의 정당한 약한 상태로 취급
- **골든 픽스처**: `test/fixtures/{layer,fsd,domain}/`(src-pass/src-fail) + `test/run-fixtures.sh` — 템플릿이 허용 통과/금지 차단하는지 스킬 레벨 검증(생성 프로젝트 footprint 0). 6/6 통과 실측. CLAUDE.md 테스트 섹션·파일 맵 등록
- **의미 게이트**: scaffold Phase 4 "아키텍처 정확성 확인" — 생성 제약 재요약+사용자 확인(비차단). manifest `harness.semanticApprovalAt`. Step 5(프로필 승인)와 구분 명문화
- **item 5 보류**: 프로필 JSON Schema 검증은 1.6.2 "과한 코드화" 비수용 유지 — 계약 드리프트 마찰 누적 시 재검토
- MINOR, 마이그레이션 불필요 (managed 자동 감지 + 선택 필드/마커 기본값 흡수). 도그푸딩: multi-model-consult 4번째 실사용 (자문 대상이 스킬 구조 자체)
- **실전 검증** (1.7.0→1.9.0 업그레이드 E2E): 마이그레이션 0, managed 자동 감지로 1.7.1·1.8.0·1.9.0 일괄 전파, 해시 재현성 일치, "표준 하네스 가동"+"Q2 강제". 무마이그레이션 설계 실물 입증. 관찰: 업그레이드 경로는 의미 게이트 미발동(`semanticApprovalAt=null`) — 규칙 불변이라 의도된 동작 (TODO-92 검토 항목)

### 1.10.0 (첫 셋업 능력 카탈로그 — 이슈 #11)
- **배경**: 첫 셋업 직후 사용자가 "이 하네스로 무엇을→어떻게 할 수 있나"를 빠르게 알기 어려움. Phase 4 보고에 능력 안내가 산점(다음 단계·TDD 워크플로·운용 스킬)되어 액션 지향 통합 뷰가 없었음
- **전달**: scaffold Phase 4 보고 fenced 블록에 `### 이제 할 수 있는 일`(≤12줄) 신설 + 영속 포인터 1줄. 기존 "운용 스킬 (선택)" 블록을 흡수(cleanup/feedback 2줄로). **신규 생성 파일 0** — harness-check ①·doc-freshness 타깃·manifest files{}·"19개 파일" 카운트·마이그레이션 레지스트리 전부 무변경
- **순수 투영(projection)**: 새 게이트 로직·플레이스홀더 없음. 산출물 생성을 결정한 프로필 신호(`integrations.multiModelConsult`+§5.16 실존 검증 / 생존 `linkedSkills` / 컴패니언 글로벌 설치 전제)를 재사용해 조건부 렌더 → 미와이어 능력 광고 불가
- **의미 정확성 교정**: 이슈가 "Security Reviewer는 §5.10 게이트와 동일"이라 했으나 §5.10은 7개 에이전트를 항상 생성 — 실제 게이트는 session-routine Phase 4.5 SECURITY 호출 조건(`tdd.securityCategories` 매칭). 카탈로그는 파이프라인을 열거하지 않고 session-routine.md를 가리켜 미호출 가능 단계 비광고
- **U5 비대칭**: 업그레이드 보고는 카탈로그 미출력(첫 셋업 전용) — §10.2에 1문장 명문화. NET-NEW 능력 1줄 델타는 OUT-OF-SCOPE 후속
- MINOR, Public API 4계약(프로필/매니페스트/프리셋/생성파일) 무변경 — 휘발성 Phase 4 보고 enrichment(선례 1.5.0/1.9.0). 마이그레이션 불필요. 부수 수정: README 버전 표기 1.8.0(드리프트)→1.10.0

### 1.11.0 (E2E 스캐폴드 모듈 — 이슈 #12 증분 1)
- **1.11.0** (2026-06-15) — E2E 스캐폴드 모듈 (이슈 #12 증분 1). 프론트엔드 옵트인으로 Playwright 기반 E2E 셋업(playwright.config.ts + e2e/ + test:e2e + @playwright/test devDep) 생성. Vitest 충돌은 `*.e2e.ts` 네이밍으로 회피(vitest.config 미수정), tsconfig 절대 비수정(e2e/tsconfig.json 자체 경계), config=managed/스타터=custom. harness-check ⑧ 구조 검사. 신규 플레이스홀더 0개, 마이그레이션 불필요(옵트인·생략 기본). 설계 정본: docs/superpowers/specs/2026-06-15-e2e-scaffold-module-design.md

### 1.16.0 (E2E 레이아웃 회귀 트리거 확장 — 이슈 #12, TODO-99)
- **1.16.0** (2026-06-16) — E2E 작성 트리거를 "UI 상호작용"에서 "UI 상호작용 **또는 시각/레이아웃 회귀 위험**"으로 확장(TODO-99 보류→승격). **동기**: 2b 하네스(1.14.0) 도그푸딩에서 컨테이너 내부 스크롤/공간 분배(레이아웃) 작업이 `shouldAutoExpand` 헬퍼 유닛 테스트만 TDD하고, 정작 load-bearing한 레이아웃 동작(페이지 스크롤 0·peek 3행·공간 흡수)은 ad-hoc 브라우저 스크린샷으로 1회 확인 후 `.e2e.ts` 미코드화 — jsdom-blind 회귀의 가드 공백. 1.13.1 haja TaskItem 레이아웃에 이은 **2번째 데이터포인트**라 핵심원칙 #5(반복=승격)로 착수. **변경**: test-engineer.md(트리거+verdict created/not_applicable 미러+시각/레이아웃 정의·"브라우저 1회 확인은 가드 아님→코드화" 규칙), coding-standards.md(jsdom 한계 명시 — 레이아웃 엔진 부재로 오버플로·정렬·스크롤 검증 불가), session-routine.md(완료 게이트에 "브라우저 검증→스펙 코드화" 전제), harness-checklist.md §4.2. **부수**: stale "(후속) 증분 2b" 참조 3건 정리(2b는 1.14.0 출하). 신규 프로필 필드·플레이스홀더·파일 0(31 불변) — 전부 managed 편집이라 §12.6 자동 감지 전파, `e2e.enabled` 게이트라 미옵트인 하네스 무영향, 마이그레이션 불필요. MINOR.

### 1.15.0 (Playwright MCP 진단 배선 — 이슈 #12 증분 3)
- **1.15.0** (2026-06-16) — Playwright MCP 진단 배선 (이슈 #12 증분 3). 배치는 e2e 모듈 확장(integrations 규약 비사용 — debugger가 코어 SoT라 통합 규약 #3 충돌). `e2e.mcp` 분리 옵트인 스키마(`enabled`/`version`, `e2e.enabled`와 독립), 신규 플레이스홀더 `{{MCP_DEBUG_PROTOCOL}}`(30→31)로 debugger.md 조건부 MCP 진단 블록 — 스펙 없는 UI 증상을 라이브 브라우저로 진단(known `.e2e.ts` 실패는 §0 러너가 정본). 공유 `.mcp.json` **비커밋**(Claude Code 승인 nagware·머지 지옥·관심사 분리 회피) → 개발자 로컬 `claude mcp add` 등록. 공식 `@playwright/mcp` exact 핀 `0.0.76`. harness-scaffold §5.19 배선 + Phase 4 카탈로그/보고 + U1 재감지, 골든 픽스처 `test/mcp-fixtures.sh`. 멀티모델 자문(codex·gemini)이 비커밋 B안 권고(gemini의 "ad-hoc npx" 오류는 합성자가 교정). MINOR, 신규 산출물 파일 0(픽스처 제외)·옵트인·생략 기본 → 마이그레이션 불필요. 설계 정본: docs/superpowers/specs/2026-06-16-e2e-mcp-incr3-design.md, 계획: docs/superpowers/plans/2026-06-16-e2e-mcp-incr3.md

### 1.14.0 (E2E pre-push 게이트 — 이슈 #12 증분 2b)
- **1.14.0** (2026-06-16) — E2E pre-push 게이트 (이슈 #12 증분 2b): 옵트인 `e2e.prePush` → `.githooks/pre-push`(managed) 생성. `validate` → `@critical` E2E fail-fast 게이팅. 무의존 git hook(POSIX sh), PM 비종속(`node_modules/.bin/playwright`), `--list --grep @critical` 실제 매처. 수동 활성화(D1 — git config 비실행, "승인 없이 git 실행 금지" 정합). 공존성 4-환경 분기(그린필드/기존 hooksPath·Husky/기본 hooks/폴백) + 적응형 마커 주입. eslint override 드롭(D4 — e2e/는 srcRoot 밖, 승격 조건 보존). harness-check ⑨ 경고 전용(판정 분리). 골든 픽스처 `test/prepush-fixtures.sh`. MINOR, 신규 플레이스홀더 0, 마이그레이션 불필요(옵트인·생략 기본).

### 1.13.1 (E2E 판정 의미 명확화 — haja TaskItem 도그푸딩)
- **1.13.1** (2026-06-16) — haja TaskItem 레이아웃 수정 도그푸딩에서 에이전트가 `@critical` 여부로 E2E 판정을 도출하고 `not_applicable`을 즉흥 분류 → test-engineer.md §3.5에 3개 status 기준 명시: `not_applicable`은 UI/사용자 표면이 전혀 없을 때만(UI 표면 있는데 미작성=`skipped`), 판정은 `@critical`과 무관(@critical은 2b pre-push 전용). PATCH(산문 명확화, 플레이스홀더·필드 0). **보류(TODO-99)**: E2E 트리거가 "UI 상호작용" 중심이라 시각/레이아웃 회귀(jsdom 유닛 검증 불가)의 사각 존재 — 스코프 확장은 의견 개입이라 데이터포인트 더 수집 후 결정.

### 1.13.0 (E2E VERIFY 러너 정합 + 파일럿 마찰 — haja 업그레이드 검증)
- **1.13.0** (2026-06-16) — haja 1.9→1.12 실전 업그레이드 파일럿에서 발견한 3건 반영. **F3(high)**: VERIFY(E2E) Phase 4.7이 유닛 러너(`{{TEST_COMMAND}}`, 예 `vitest run`)로 E2E를 실행해 `.e2e.ts` 0개 수집 후 거짓 PASS로 게이트 무력화 → 신규 `{{E2E_COMMAND}}`(29→30, `e2e.enabled`+`test:e2e`에서 도출, 새 프로필 필드 없음)로 교체 + test-engineer 교차참조 정합. **F1(medium)**: seed.ts `_payload` 미사용이 `no-unused-vars` 위반(argsIgnorePattern 미설정 프로젝트) → `void payload`. **F2(low)**: harness-check ⑧이 `files:[]`+`references` 위임 루트를 오경고 → short-circuit. MINOR(신규 플레이스홀더, 후방호환), 마이그레이션 불필요. 골든 픽스처 6/6. 교훈: harness:check(정적)는 런타임 Phase 4.7을 안 거쳐 F3를 못 잡음 — 실전 기능 주행이 검증에 필수.

### 1.12.0 (E2E TDD 배선 — 이슈 #12 증분 2a)
- **1.12.0** (2026-06-16) — E2E를 TDD 사이클에 배선 (이슈 #12 증분 2a). test-engineer 확장(결정 a)이 `e2e/specs/{ID}-*.e2e.ts`를 `@feature:{ID}` 태그로 작성, session-routine VERIFY(E2E) Phase 4.7이 해당 feature 스펙만 실행(FAIL→GREEN 시도 누적), debugger 브라우저 재현(플레이키니스 환각 금지), coding-standards `@critical` 정의. 게이트는 명시적 E2E 판정(침묵=BLOCK)+TDD STATE 보존+grep 키로 결정화. pre-push 강제는 증분 2b로 분리. 멀티모델 적대적 검증(codex/gemini) 반영, 도그푸딩 6회차. 전부 managed 템플릿 편집 → §12.6 자동 감지 전파, 신규 파일·git config·플레이스홀더 0(29 불변), 마이그레이션 불필요. 설계 정본: docs/superpowers/specs/2026-06-16-e2e-tdd-wiring-design.md, 계획: docs/superpowers/plans/2026-06-16-e2e-tdd-wiring-2a.md

---

## 5. 향후 확장 가능 항목

| 항목 | 역할 | 우선순위 |
|------|------|---------|
| ~~업그레이드 시스템 구현~~ | ~~SKILL.md § 14 추가~~ — **구현 완료** (TODO-44) | ~~높음~~ |
| Initializer 그룹 subagent | 하네스 셋업 내부의 subagent 분리 (Scanner/Scaffolder) | 낮음 |
| ~~Cleanup 스킬~~ | ~~엔트로피 관리 — 주기적 정리 루프~~ — **구현 완료** (1.4.0, companion-skills/harness-cleanup) | ~~보통~~ |
| ~~추가 프리셋~~ | ~~react-vite.json, express-api.json~~ — **구현 완료** (1.3.0) | ~~보통~~ |
| ~~superpowers 옵트인 통합~~ | ~~옵트인 연계 레이어~~ — **구현 완료** (1.5.0) | ~~보통~~ |
| ~~멀티모델 합성 자문~~ | ~~Codex + Gemini + Claude 합성 자문~~ — **구현 완료** (1.6.0, multi-model-consult) | ~~보통~~ |
| 외부 통합 규약 일반화 | integrations.multiModelConsult 연계 + 통합 규약 문서화 (통합 선례 2개 확보됨 — consult 스킬 안정화 후) | 낮음 |

---

## 6. 다음 단계

> 2026-06-11 1.4.0 후 업데이트. 상세: `.tracking/TODO.md`, `.tracking/HANDOFF.md` § 5.2

1. **신규 셋업 경로 실전 테스트** (TODO-53) — 신규 프리셋 매칭(exclude 동작), eslintAssist 옵트인/마커 블록, feature_list 라우트 추론, harness-cleanup 첫 실행
2. **에이전트 템플릿 실전 조정** — TDD subagent 프롬프트 최적화 (실전 피드백 기반)
3. **eslintAssist legacy JS 형식 전략** (TODO-67) — 폴백 발동률 관찰 후 결정
4. **harness-check 검사 항목 확장 검토** (TODO-68) — 체크리스트 §6 엔트로피 항목 (harness-cleanup M1과 역할 중복 주의 — 스크립트는 기계 검사, 스킬은 판단 검사)
5. **multi-model-consult 실사용 안정화** — 실전 자문 사용 후 피드백 반영 (gemini 설치 시 양 CLI 경로 추가 검증). 안정화 후 integrations.multiModelConsult 연계 + "외부 패키지 통합 규약" 일반화 (선례 2개 확보됨)

---

## 7. 핵심 원칙

1. 하네스는 스택에 종속되지 않는다
2. 기존 소스 코드를 수정하지 않는다
3. AGENTS.md는 100줄 이내, 목차 역할
4. 소스 코드를 직접 읽고 분석한다
5. 확신 없는 부분은 사용자에게 묻는다
6. 사용자 승인 없이 파일을 생성하지 않는다
7. 리뷰에서 반복되는 문제는 자동 검사로 승격한다
8. 한 번에 하나의 기능만, 점진적으로
9. 프리셋이 없어도 동작한다

---

## 8. 참고 링크

- Anthropic 공식: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- Anthropic 퀵스타트: https://github.com/anthropics/claude-quickstarts/tree/main/autonomous-coding
- OpenAI 원문: https://openai.com/index/harness-engineering/
- FSD 공식: https://feature-sliced.design/
- Claude Code 스킬 문서: https://code.claude.com/docs/en/skills
