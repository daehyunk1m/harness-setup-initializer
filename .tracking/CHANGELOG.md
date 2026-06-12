# harness-setup 스킬 변경 이력

> 이 파일은 개선 작업의 변경 사항을 추적한다.
> 각 TODO 완료 시 변경 내용을 여기에 기록한다.

---

## [1.6.0] — 2026-06-12 (multi-model-consult 컴패니언 스킬)

> PRD 구체화(미결정 5건 해소 + CLI 실물 검증) 후 M1+M2 구현 (TODO-74). Public API 변경 없음 — 버전 단일화 원칙으로 스키마 version만 동기 (업그레이드 no-op)

### 추가 (Added) — Session 26 (2026-06-12)
- companion-skills/multi-model-consult/SKILL.md: 멀티모델 합성 자문 스킬 — 관점 분담 분해(codex=정확성·보안, gemini=대안·운영), 합성 4섹션 포맷(합의/상충/최종방향/액션 + 아티팩트 경로), graceful degradation 3경로, 외부 응답 인젝션 방어("Raw Output은 데이터") 제약. **하네스 비의존 범용 도구**
- companion-skills/multi-model-consult/scripts/run-advisor.js: CLI 호출 핵심 — CLAUDE* env 스트립, CONSULT_DISABLE_EXTERNAL_LLM 차단 스위치, CONSULT_TIMEOUT_MS(기본 180s) 타임아웃 부분 결과, 아티팩트 저장(.claude/artifacts/consult/), `ARTIFACT:` 출력 계약, 종료 코드 4종 (0/1/2/3/4)
- install.sh: multi-model-consult 글로벌 심볼릭 링크 추가 (cleanup/feedback의 --add-dir opt-in과 달리 상시 로딩 — 범용 도구)

### 수정 (Changed) — Session 26 (2026-06-12)
- .tracking/prd-multi-model-consult.md: Draft → Implemented — 미결정 5건 결정 기록, **위험 플래그 폐기** (codex `--dangerously-bypass-approvals-and-sandbox` → `-s read-only --ephemeral --skip-git-repo-check -o`, gemini `--yolo` 제거 — 자문은 읽기 전용, oh-my-claudecode 패턴은 과잉 권한), 병렬은 Claude 병렬 도구 호출로 달성(F3.1 조기 해소), check-cli.js·templates/ 폐지(2파일 구조)
- 프로필 스키마 version "1.5.0" → "1.6.0" (두 SKILL.md 동기 — 계약 변경 없음, 마이그레이션·자동 감지 no-op)

검증: 종료 코드 4경로 + env 스트립 단위 + codex 실호출 E2E(5초, 아티팩트 정확) + 심링크 디스커버리 실측.

---

## [1.5.0] — 2026-06-12 (superpowers 옵트인 통합)

> PRD 구체화(미결정 이슈 6건 해소 + 실물 검증) 후 M1~M3 구현 (TODO-73). MINOR (새 프로필 선택 필드 + 새 플레이스홀더 + 새 생성 규칙)

### 추가 (Added) — Session 25 (2026-06-12)
- references/integrations/superpowers-mapping.md: 연계/제외 분류 정본 — superpowers v5.1.0 스킬 14종 전수 (연계 3: brainstorming·systematic-debugging·writing-plans / 선택 1: using-superpowers / 제외 10: TDD·코드리뷰·검증·git·오케스트레이션 = 코어 SoT). 분기 리뷰 갱신 절차 포함
- 프로필 선택 필드 `integrations.superpowers`: enabled/source/detectedVersion/installPath/linkedSkills — 생략 = 미연계 (eslintAssist 패턴). 두 SKILL.md 스키마 동기 + manifest profile 보존
- SKILL.md Step 1.6: 외부 통합 감지 — installed_plugins.json `superpowers@*` 키(1순위, version·installPath 추출) + ~/.claude/skills/superpowers* 폴백. 미감지 시 질문 생략 (모르는 도구 비노출)
- SKILL.md § 4.2: superpowers 연계 옵트인 질문 (감지 시에만, 우선순위 5)
- harness-scaffold/SKILL.md § 5.16(신설): 렌더링 절차 — ① linkedSkills 실존 검증 (installPath/skills/{name}, 없으면 드롭+경고) ② 매핑 정본 밖 스킬 비렌더링 (제외 필터) ③ AGENTS.md "보조 스킬" 섹션 (문서 맵 앞, ~8줄) ④ session-routine 연계 라인
- 새 플레이스홀더 `{{INTEGRATION_NOTES}}` (25 → 26개): session-routine.md Plan 모드 통합 끝 — writing-plans 연계 시 1줄, 미연계 시 빈 문자열. **managed 템플릿에 조건부 텍스트를 넣는 정규 방법** (scaffold 임의 삽입은 § 12.6 자동 감지의 재렌더링 해시 비교를 깨뜨림)
- harness-scaffold/SKILL.md § 6.15: 연계 검증 (옵트인 시 섹션 존재 / 옵트아웃 시 "superpowers" 문자열 부재) — Phase 3 검증 14 → 15항목
- SKILL.md § 12.3 U1: 업그레이드 시 외부 통합 재감지 — 신규 감지 → 추가 제안, 기존 통합 → linkedSkills 실존 재검증·제거 지원

### 수정 (Changed) — Session 25 (2026-06-12)
- .tracking/prd-superpowers-integration.md: Draft → Implemented — 미결정 이슈 6건을 결정 기록으로 전환, 스킬명 실물 정정(debugging→systematic-debugging, using-skills→using-superpowers, code-review→requesting/receiving-code-review), F2.2 버전 호환 매트릭스 폐기(F1.7 실존 검증으로 대체 — semver 범위는 스킬 이름 변경을 못 잡음), 초안의 agents/red-green-refactor.md 오참조 정정
- 프로필 스키마 version "1.4.0" → "1.5.0" (두 SKILL.md 동기). 마이그레이션 등록 불필요 (integrations는 생략이 기본값, session-routine 템플릿 변경은 자동 감지로 전파)

---

## [1.4.0] — 2026-06-11 (harness-cleanup 컴패니언 스킬)

> 체크리스트 § 6.3 운영 사이클의 실행 주체 구현 (TODO-71). P10 엔트로피 관리: "범위 밖" → "컴패니언 스킬로 커버". MINOR (생성 CLAUDE.md/보고에 안내 추가 + 새 마이그레이션)

### 추가 (Added) — Session 23 (2026-06-11)
- companion-skills/harness-cleanup/SKILL.md: 엔트로피 정리 스킬 신설 — 주간(doc:check, QUALITY_SCORE 재측정 — 카테고리별 측정 방법 명세, 코드 엔트로피 스캔, harness:check) / 격주(TECH_DEBT 검토, 승격 큐 횟수 ≥ 2 승격 제안) / 월간(문서-실구조 일치, passes 재검증 — 회귀 시 되돌림 제안 + TDD 위임, 종합 판정). docs/CLEANUP_LOG.md 경과 시간 기반 루틴 판별. 원칙: 삭제 우선·승인 필수·scope 제한(소스 동작 변경 금지)·기록 보존
- harness-scaffold/SKILL.md § 10.3: M-1.3.0-to-1.4.0 — 기존 하네스 CLAUDE.md 운영 사이클에 cleanup 안내 1줄 ([custom], 멱등)

### 수정 (Changed) — Session 23 (2026-06-11)
- harness-scaffold/SKILL.md § 5.1.1: 생성 CLAUDE.md 운영 사이클 테이블 아래 harness-cleanup 안내 1줄
- harness-scaffold/SKILL.md § 7: Phase 4 "운용 스킬 (선택)" 안내에 harness-cleanup 추가
- 프로필 스키마 version "1.3.0" → "1.4.0" (두 SKILL.md 동기)
- CLAUDE.md(저장소): harness-feedback "(스텁)" 표기 정정(구현됨) + harness-cleanup 파일 맵 행 추가
- SKILL.md § 10: 향후 확장 포인트의 Cleanup/피드백 스킬 구현 완료 표시
- harness-scaffold/SKILL.md § 5.7: doc-freshness 검사 대상 명확화 (교차 검증 발견) — "docs/ 하위 모든 .md" 문구와 정적 치환 예시의 모순 해소. 정적 목록으로 확정하고 이벤트 로그(HARNESS_FRICTION, CLEANUP_LOG)는 제외 (추가형 로그는 staleness 무의미)

---

## [1.3.0] — 2026-06-11 (프리셋 확장 + domain 템플릿 + 추론 정책)

> 잔여 TODO 일괄 처리 (TODO-45~49 구현, TODO-50/51/54/70 종결). MINOR (새 프리셋 2종, 새 detection 필드, 새 템플릿, 새 플레이스홀더, 새 프로필 필드)

### 추가 (Added) — Session 22 (2026-06-11)
- presets/react-vite.json: React + Vite SPA 프리셋 — layer-based 7레이어, devServer 5173 (TODO-48)
- presets/express-api.json: Express + TypeScript API 프리셋 — layer-based 8레이어 (routes→controllers→services→models 흐름), readyCheck 연결 성공 정규화 형태, testFramework vitest+supertest (TODO-49)
- SKILL.md § 6: 프리셋 detection에 `exclude` 선택 필드 신설 — 나열 패키지 존재 시 후보 제외 (범용 required의 오매칭 방지). 매칭 로직 3.3 단계 + Step 3.2 + § 9 가이드 4.5 반영
- templates/structural-test-domain.ts: domain-based 검증 템플릿 신설 — 도메인 간 직접 import 금지 + 공유 모듈→도메인 역방향 금지, 도메인 목록 실행 시점 발견. 픽스처 기능 테스트 통과 (TODO-46)
- 새 플레이스홀더 `{{SHARED_DIRS}}` (24 → 25개) + 프로필 선택 필드 `sharedDirs` (domain-based 전용, 기본 ["shared"]) — § 4.2 질문/§ 4.4 기본값/스키마/manifest 저장 필드 연결
- harness-scaffold/SKILL.md § 5.4: custom 유형 동적 생성 4단계 알고리즘 명문화 (layers.rules 재사용 → extraArchitectureRules 기계화 → 주석 나열 → 최소 스크립트 폴백, § 12.6 자동 감지 제외 명시) (TODO-46)
- harness-scaffold/SKILL.md § 5.3: feature_list 기존 프로젝트 3단계 추론 정책 — 라우트 기반 → 기능 모듈 기반 → 빈 배열 폴백, 상한 15개 + 초과분 보고, 셋업 직후 사용자 검토 안내 (TODO-47)
- harness-scaffold/SKILL.md § 10.3: M-1.2.0-to-1.3.0 마이그레이션 ([profile] sharedDirs, domain-based 한정)

### 수정 (Changed) — Session 22 (2026-06-11)
- presets/react-router-fsd.json: versionConstraints `react-router >= 7.0.0` 추가 — v6 이하 오매칭 방지 (TODO-45)
- harness-scaffold/SKILL.md § 5.6: readyCheck 파싱 규칙에 API 정규화 형태 허용 명문화 (`curl ... && echo 200 || echo 000`)
- 프로필 스키마 version "1.2.0" → "1.3.0" (두 SKILL.md 동기)
- 플레이스홀더 카운트 24 → 25 (SKILL.md § 12.1, versioning-policy.md)
- TODO 정리: TODO-50(harness-feedback)은 Session 14 구현 완료 — 상태 누락 정정. TODO-51(기록 체계 — TODO-66 패턴을 표준 프로세스로 확정), TODO-54(스키마 정합성 — 3회 연속 기계 검증 IDENTICAL), TODO-70(멱등성 — haja 1.2.0 업그레이드 최종 상태 검증) 종결

---

## [1.2.0] — 2026-06-10 (비대화형 검증 명령 보장)

> 실전 테스트(haja-web-fe 업그레이드, TODO-66)에서 발견된 watch 모드 영구 대기 문제 수정. MINOR (새 조합 규칙 + 조건부 test:run 키 + 새 마이그레이션)

### 추가 (Added) — Session 21 (2026-06-10)
- harness-scaffold/SKILL.md § 5.5: 조건부 `test:run` 스크립트 추가 규칙 — 기존 `test`가 watch 기본(예: `vitest` 단독)이면 단발 실행 키 추가 (기존 `test` 키는 비수정)
- harness-scaffold/SKILL.md § 10.3: M-1.1.0-to-1.2.0 마이그레이션 — 기존 하네스의 validate에서 `npm run test` → `npm run test:run` 교체 + manifest.profile.scripts.test 갱신
- .tracking/TODO.md: TODO-66 실전 테스트 결과 기록, TODO-69(watch 가드) 완료, TODO-70(업그레이드 멱등성 재검증) 신규

### 수정 (Changed) — Session 21 (2026-06-10)
- SKILL.md Step 1.2 / § 4.4 / § 5 필드 규칙: `scripts.test`는 비대화형(단발 실행) 명령이어야 한다 — watch 기본 러너 감지 시 `npm run test:run`으로 기록
- harness-scaffold/SKILL.md § 4 필드 참조 규칙: scripts.test 비대화형 계약 명시 ({{TEST_COMMAND}}/{{VALIDATE_COMMAND}} 안전성의 전제)
- harness-scaffold/SKILL.md § 5.5 validate 조합 규칙: "구성 명령은 모두 비대화형" 원칙 + watch 기본 예시 추가
- 프로필 스키마 version "1.1.0" → "1.2.0" (두 SKILL.md 동기)
- CLAUDE.md: 실전 테스트 경로 스테일 수정 (~/projects/haja → ~/Desktop/side-project/haja-web-fe, --add-dir 불필요 명시)

---

## [1.1.0] — 2026-06-10 (하네스 구성 체크리스트 기반 보강)

> Session 18~20을 하나의 릴리스로 묶음. 최고 수준 변경 = MINOR (새 파일, 새 프로필 필드, 새 플레이스홀더, 규칙 추가)

### 추가 (Added) — Session 20 (2026-06-10): 체크리스트 기반 검토·개선
- references/harness-checklist.md: 하네스 구성 체크리스트 편입 — 생성 하네스의 판정 기준 (Q1~Q4, §1~§8, MVH/표준/운영 단계). Phase 3 검증·Phase 4 단계 판정·harness-check.sh의 SSoT
- templates/harness-check.sh: 하네스 자가진단 스크립트 (managed, 체크리스트 §8 구현) — 검사 7항목(구조 ①②③/품질 ④⑤/경고 ⑥⑦), 구조·품질 구분 보고, 전체 통과 시 "표준 하네스 가동" 판정
- 새 플레이스홀더 3종: `{{LINT_ARCH_COMMAND}}`, `{{DOC_CHECK_COMMAND}}`, `{{PATH_ALIAS_LIST}}` (21 → 24개), harness-scaffold/SKILL.md § 5.14 치환 테이블 신설
- 프로필 선택 필드 `eslintAssist`: ESLint 보조 규칙 옵트인 (no-restricted-imports 레이어 이중 차단 + max-lines) — SKILL.md § 4.2 옵트인 질문(ESLint 설정 감지 시에만), harness-scaffold/SKILL.md § 5.15 신설 (마커 블록 외과 수정 + 멱등 + 권고 스니펫 폴백). 체크리스트 §3.2
- package.json scripts에 `harness:check` 추가 (§ 5.5) — validate에는 포함하지 않음 (순환 방지)
- templates/TECH_DEBT.md: "자동 검사 승격 대기 큐" 섹션 — 문서 규칙이지만 검사기 없는 항목 추적. 체크리스트 §3.3
- templates/agents/reviewer.md: "반복 지적 감지" 단계 + Output에 "자동 검사 승격 후보" 섹션 (read-only 유지 — 기록은 오케스트레이터)
- templates/rules/session-routine.md: Phase 4에 승격 큐 기록·2회 이상 시 승격 제안, 시작 절차 5분 목표, 회귀 우선 규칙. 체크리스트 §5.1/§5.3
- templates/rules/coding-standards.md: "검증 레벨" 섹션 (L1 정적/L2 유닛/L3 통합/L4 E2E) + steps↔E2E 1:1 매핑 규칙 + 승격 원칙 1줄. 체크리스트 §4.2
- harness-scaffold/SKILL.md § 5.1.1: CLAUDE.md에 "운영 사이클" 섹션 (일간/주간/격주/월간) + 금지 사항 회귀 우선 규칙. 체크리스트 §6.3
- harness-scaffold/SKILL.md § 6: Phase 3 검증 6.13 (harness:check 실행) + 6.14 (ESLint 마커 검증) — 12 → 14항목
- harness-scaffold/SKILL.md § 7: "하네스 단계 판정" 신설 (표준 하네스 가동/MVH/판정 보류)
- harness-scaffold/SKILL.md § 10.3: M-1.0.0-to-1.1.0 마이그레이션 등록 (harness-check 신설, AGENTS/CLAUDE 외과 수정, TECH_DEBT/QUALITY_SCORE data 패치, eslintAssist 프로필 필드)
- harness-scaffold/SKILL.md § 5.3.1: claude-progress.txt 생성 규칙 신설 — 기존 사양 갭 (생성 순서 #10에는 있으나 규칙 섹션 부재). 초기 내용 + TDD STATE 포맷 주석 안내

### 수정 (Changed) — Session 20 (2026-06-10)
- **명령어 SoT 이동**: AGENTS.md에 "## 명령어" 섹션 신설 (source of truth), CLAUDE.md 생성 템플릿에서 명령어 섹션 제거 (@AGENTS.md import로 커버) — 범용 에이전트(Codex 등) 접근성. 역할 분리 테이블 3곳(§ 5.1 불릿, § 5.1.1 테이블, § 5.11.4 테이블) 동기 수정. 체크리스트 §1.2
- AGENTS.md "주요 규칙"에 필수 2종 명시: feature_list 보호 + passes 검증 규칙 반드시 포함. 체크리스트 §2.1
- harness-scaffold/SKILL.md § 5 생성 순서: 18 → 20단계 (14번 harness-check.sh, 19번 ESLint 옵트인 수정, manifest는 20번 마지막 유지)
- harness-scaffold/SKILL.md § 5.3: feature_list steps의 E2E 1:1 매핑 규칙 추가, templates/agents/test-engineer.md에도 반영
- 프로필 스키마 version "1.0.0" → "1.1.0" (SKILL.md § 5 + harness-scaffold/SKILL.md § 4 동기), 매니페스트 profile 예시에 eslintAssist 보존 추가
- templates/QUALITY_SCORE.md / TECH_DEBT.md 헤더에 갱신 주기(주간/격주) 명시
- SKILL.md § 8 / harness-scaffold/SKILL.md § 8 절대 규칙: 기존 설정 수정 허용 범위에 옵트인 ESLint 보조 규칙 명시
- 파일 카테고리 테이블(SKILL.md § 12.2, harness-scaffold § 10.1)에 24번 harness-check.sh(managed), 25번 ESLint 설정(custom) 추가. § 12.6.1 파일-템플릿 매핑에 harness-check.sh 추가
- versioning-policy.md / CLAUDE.md / project-context.md: 플레이스홀더 21→24, 생성 파일 18→19 카운트 갱신, 파일 맵에 신규 파일 2종 추가
- SKILL.md 스테일 내부 참조 수정 (§14 → §12 재번호 잔존분 7곳, § 9의 "섹션 8" → "§ 6"), Step 5 생성 예정 파일 목록 누락분(git-workflow.md, HARNESS_FRICTION.md) 보완
- 적대적 검증 워크플로(5관점) 발견 사항 수정: § 5.11.4 명령어 행 SoT 반영 누락, manifest profile 저장 필드 목록 명시(§ 5.13 — "전체 프로필" 모호성 해소), 승격 큐 기록 매핑 명세(session-routine.md), harness-check skipFiles 주의(§ 5.14), eslintAssist 필드 설명 보강(scaffold § 4)

### 추가 (Added) — Session 19 (2026-05-28): 외부 통합 기획 PRD
- .tracking/prd-multi-model-consult.md: Codex + Gemini + Claude 3중 합성 자문 스킬 PRD 초안 — oh-my-claudecode /ccg 패턴 차용
- .tracking/prd-superpowers-integration.md: obra/superpowers 옵트인 통합 PRD 초안 — 프로필 `integrations.superpowers` 필드, 매핑 테이블(brainstorming/debugging/writing-plans 연계, TDD·code-review 제외), 충돌 회피·버전 드리프트·옵트아웃 정책

### Session 18 (2026-04-11): 업그레이드 자동 감지 메커니즘

### 수정 (Changed)
- SKILL.md § 12.3: Phase U1 분석 흐름을 2-상태 → 4-상태 판정으로 개선. 소스 템플릿 재렌더링 비교 단계 추가
- SKILL.md § 12.2: managed 파일 변경 감지 설명을 § 12.6 자동 감지 알고리즘 기반으로 갱신
- SKILL.md § 12.1: 설계 결정 테이블에 "템플릿 자동 감지" 항목 추가, "해시 기반 변경 감지" 근거 보강
- SKILL.md § 5: fileActions 스키마에 `source` 필드(auto-detect/migration/category) 추가, 예시 갱신
- SKILL.md Phase U2: 계획 테이블 예시를 새 판정 로직 반영 (이유 컬럼: 템플릿 변경 감지, 마이그레이션 지시, 변경 없음 등)
- harness-scaffold/SKILL.md § 10.1: managed 파일 대응을 자동 감지 기반으로 재작성, fileActions 연동 설명
- harness-scaffold/SKILL.md § 10.2: Phase U3 실행 로직을 fileActions action 필드 기반으로 명확화
- harness-scaffold/SKILL.md § 10.2: Phase U5 보고 포맷에 소스 컬럼 추가 (자동 감지 vs 마이그레이션 구분)
- harness-scaffold/SKILL.md § 10.3: 마이그레이션 레지스트리 안내를 역할 분리 기반으로 갱신
- references/upgrade-system-design.md § 1.3: templateHash 설계 근거에 자동 감지 설명 추가
- references/upgrade-system-design.md § 2.3: managed 파일 대응을 4-상태 판정 매트릭스로 갱신
- references/upgrade-system-design.md § 3.3: Phase U1 흐름에 자동 감지 단계 추가
- references/versioning-policy.md § 2 PATCH: 템플릿 내용 보강이 자동 감지로 반영됨을 명시

### 추가 (Added)
- SKILL.md § 12.6: "managed 파일 자동 변경 감지" 섹션 신설 — 감지 알고리즘, 4-상태 판정 매트릭스, 파일-템플릿 매핑 테이블 (13개 managed 파일), 마이그레이션과의 역할 분리 테이블

---

## [1.0.0] — 2026-04-11 (semver 전환 + 안정화 + Plan 모드 통합)

### 추가 (Added) — Session 17 (2026-04-10~11)
- references/model-selection-guide.md: Opus vs Sonnet 모델 선택 가이드 리서치 — 벤치마크, 하네스-Sonnet 연계 효과, opusplan 하이브리드, 서브에이전트 라우팅 전략
- references/versioning-policy.md: semver 2.0.0 기반 버전 관리 정책 — Public API 4개 계약 정의, MAJOR/MINOR/PATCH 판단 기준, 판단 어려운 경우 가이드, 릴리스 프로세스
- CLAUDE.md: 파일 맵에 versioning-policy.md 추가, Git 워크플로에 "버전 관리 (semver)" 섹션 추가

### 수정됨 (Fixed) — Session 17 (2026-04-10): Issue #5 Plan 모드 TDD 우회 해결
- templates/rules/session-routine.md: "Plan 모드 통합" 섹션 추가 — Plan 모드를 PRE-RED(Architect) 대체로 취급, Plan 승인 후 RED부터 TDD 사이클 합류하는 브릿지 패턴
- templates/rules/session-routine.md: Phase 1 PRE-RED에 "Plan 모드 연계" 바이패스 규칙 추가
- templates/rules/session-routine.md: TDD STATE 블록 plan_ref에 `.claude/plans/` 경로 지원 추가
- harness-scaffold/SKILL.md: CLAUDE.md 생성 템플릿의 TDD 파이프라인 섹션에 Plan 모드 연계 안내 추가
- harness-scaffold/SKILL.md: CLAUDE.md 금지 사항에 "Plan 모드 후에도 TDD 필수" 규칙 추가
- templates/rules/coding-standards.md: 금지 사항에 동일 규칙 추가 (일관성)

### 수정됨 (Fixed) — Session 16 (2026-04-09): Issue #2, #3 해결
- Issue #3: `.claude/skills/harness-scaffold/` → `harness-scaffold/`(리포 루트)로 이동 + `install.sh` 심볼릭 링크 생성 스크립트 추가 — scaffold 디스커버리 실패 해결
- Issue #2: Session 15에서 이미 수정 완료, 이슈 닫기
- SKILL.md, CLAUDE.md, README.md, HANDOFF.md, project-context.md: scaffold 경로 참조 일괄 업데이트

### 수정됨 (Fixed) — Session 15 (2026-04-09): Issue #2 권한 에러
- SKILL.md, .claude/skills/harness-scaffold/SKILL.md, companion-skills/harness-feedback/SKILL.md: frontmatter에 `allowed-tools` 추가 — `` ```! `` 블록 실행 시 권한 체크 실패 해결 (Issue #2)

### 추가 (Added) — Session 14 (2026-04-09): 이슈 보고 프로세스
- companion-skills/harness-feedback/SKILL.md: 스텁 → 실제 구현 (파싱→패턴 분석→초안→확인→gh issue create)
- templates/HARNESS_FRICTION.md: 하네스 이슈 카테고리 7종 추가 + 이슈 보고 안내 섹션
- .claude/skills/harness-scaffold/SKILL.md: 생성 CLAUDE.md에 "하네스 이슈 보고" 섹션 추가

### 수정 (Changed) — Session 14 (2026-04-09): README 시나리오 기반 재작성
- README.md: 2-스킬 구조/Stop hook 체이닝 섹션 추가, Mermaid stateDiagram으로 실행 흐름 시각화, 시나리오별 동작 4가지 추가, 생성 파일 테이블 전면 갱신(18개), 디렉토리 구조·파일 역할 테이블 보완

### 추가 (Added) — Session 13 (2026-04-08): hook-driven continuation
- .claude/skills/harness-scaffold/SKILL.md: scaffold 스킬 이동 — `user-invocable: false`, Stop hook(매니페스트 미존재 시 block), `!command` 프로필 주입(§ 0)

### 수정 (Changed) — Session 13 (2026-04-08): hook-driven continuation
- SKILL.md frontmatter: `hooks.Stop` 추가 — 프로필 존재 + 매니페스트 미존재 시 scaffold 호출 강제 (`decision: "block"` + `additionalContext`)
- SKILL.md § 0: `!command` 상태 감지 블록 추가 — 신규/재개/완료 3-way 분기
- SKILL.md § 1: 자동 체이닝 이중 안전장치 설명 추가
- SKILL.md § 4 Step 5: 체이닝 지시를 3단계 절차로 구체화 + Stop hook 백업 안내
- CLAUDE.md: 파일 맵, 개발 규칙, 테스트 방법, 원칙 갱신 (신규 경로 반영)
- README.md: 등록 방법 단일 `--add-dir`로 변경, 디렉토리 구조 갱신

### 수정됨 (Fixed) — Session 13 (2026-04-08)
- 비결정적 체이닝 문제 해결 — Stop hook `decision: "block"`으로 시스템 레벨 강제
- 이중 `--add-dir` 등록 UX 마찰 해소 — `.claude/skills/` 자동 디스커버리로 단일 등록

### 수정 (Changed) — Session 13 (2026-04-08) (이전 항목)
- SKILL.md § 4: 프로필 승인 후 수동 안내 → Skill 도구로 harness-scaffold 자동 호출로 변경

### 추가 (Added) — Session 12 (2026-04-08): 2-스킬 분리 (Issue #1)
- SKILL-SCAFFOLD.md: 스캐폴딩 스킬 신규 생성 — Phase 2~4 (스캐폴딩 + 검증 + 보고) 추출, `context: fork` + `model: sonnet` frontmatter 유지
- `.harness-profile.json`: 두 스킬 간 중간 포맷(계약) 도입 — 분석 스킬 출력 → 스캐폴딩 스킬 입력

### 수정 (Changed) — Session 12 (2026-04-08)
- SKILL.md: Phase 2~4 제거, Phase 1(분석 + Q&A)만 남김. `context: fork` 및 `model: sonnet` frontmatter 제거 (멀티턴 Q&A 호환을 위해)
- SKILL.md § 5: 프로필 출력 스키마 추가 — `.harness-profile.json`으로 저장하는 구조 명시
- SKILL.md: 섹션 번호 재정렬 (§ 6~12)
- CLAUDE.md: 파일 맵에 SKILL-SCAFFOLD.md 추가, 개발 규칙/테스트/원칙 업데이트

### 수정됨 (Fixed) — Session 12 (2026-04-08)
- `context: fork`와 멀티턴 Q&A(소크라테스 문답) 비호환 문제 해결 — 분석 스킬에서 fork 제거, 스캐폴딩 스킬에서만 fork 사용 (GitHub Issue #1)

### 추가 (Added) — Session 11 (2026-04-07): 실전 적용 준비도 분석
- .tracking/TODO.md: Session 11 추가 — TODO-45~51 (실전 테스트 전 전수 분석에서 도출된 리스크/제한사항 7개)
- .tracking/HANDOFF.md: § 5를 준비도 분석 결과 + 우선순위 9개 목록으로 확장
- references/project-context.md: § 3 설계 결정에 준비도 분석 판정 추가, § 6 다음 단계를 TODO 번호와 연결하여 개정

### 추가 (Added) — Session 10 (2026-04-07): 업그레이드 시스템 구현
- SKILL.md § 2: 업그레이드 트리거 3개 추가 (harness upgrade, 최신 버전 업데이트, /harness-setup upgrade)
- SKILL.md § 3: Step 0 모드 판별 분기 추가 (Setup / Bootstrap+Upgrade / Upgrade)
- SKILL.md § 5.13: .harness-manifest.json 생성 규칙 신규 섹션 — 스키마, 필드 설명, 해시 계산, 카테고리 할당
- SKILL.md § 6.12: manifest 검증 항목 추가 (version, profile, files 정합성)
- SKILL.md § 14: 업그레이드 시스템 전체 신규 섹션 — 14.1 매니페스트 설계 결정, 14.2 파일 카테고리(managed 13/custom 4/data 5), 14.3 Phase U1~U5, 14.4 마이그레이션 레지스트리, 14.5 부트스트랩(v0→v3.3), 14.6 엣지 케이스 6개

### 수정 (Changed) — Session 10 (2026-04-07)
- SKILL.md frontmatter: description에 업그레이드 기능 추가
- SKILL.md § 5 생성 순서: 18번 .harness-manifest.json 추가
- SKILL.md § 7: 보고 포맷에 manifest 행, 검증 결과, 커밋 안내 추가
- SKILL.md § 12: 프로필 저장 항목 제거(구현 완료), 업그레이드 시스템 구현 완료 표시
- SKILL.md § 13: references/upgrade-system-design.md 참조 추가

### 추가 (Added) — Session 9 (2026-04-07): 업그레이드 시스템 설계
- references/upgrade-system-design.md: 업그레이드 시스템 설계 문서 신규 추가 — 매니페스트 스키마(.harness-manifest.json), 파일 카테고리(managed 13/custom 4/data 5), Phase U1~U5 업그레이드 플로우, 마이그레이션 레지스트리 형식, 부트스트랩 마이그레이션(v0→v3.3), 엣지 케이스 8개
- references/project-context.md: 업그레이드 시스템 설계 결정 2행, v4.0 버전 히스토리 예고, 확장 항목/다음 단계 업데이트
- .tracking/TODO.md: Session 9 추가 — TODO-43(설계 완료), TODO-44(구현 대기)
- .tracking/HANDOFF.md: Session 9 요약, 향후 작업 1번에 업그레이드 시스템 구현 추가

### 추가 (Added) — Session 8 (2026-04-07): 피드백 수집 시스템
- templates/HARNESS_FRICTION.md: 마찰 로그 템플릿 — 6개 이벤트 유형, 마크다운 테이블 형식, 기계 파싱 가능
- companion-skills/harness-feedback/SKILL.md: 피드백 분석→Issue 스킬 스텁 (향후 구현)
- SKILL.md 5.12: HARNESS_FRICTION.md 생성 규칙 신규 섹션
- SKILL.md 5: Phase 2 생성 순서에 HARNESS_FRICTION.md 추가 (16번)
- SKILL.md 7: Phase 4 보고에 HARNESS_FRICTION.md 행 + 운용 스킬 안내 섹션 추가
- SKILL.md 12: 향후 확장 포인트에 피드백 분석 스킬 추가
- SKILL.md 13: 참조 테이블에 HARNESS_FRICTION.md 행 추가

### 수정 (Changed) — Session 8 (2026-04-07)
- templates/rules/session-routine.md: 6개 마찰 이벤트 로깅 지시 추가 (GREEN 시도 루프, Debugger 에스컬레이션, 사용자 에스컬레이션, Review NEEDS_FIX, Refactor 롤백, 세션 미완료), 마찰 로그 섹션 신규 추가
- SKILL.md 6.2: Phase 3 검증에 HARNESS_FRICTION.md 존재 확인 추가

### 추가 (Added) — Session 7 (2026-04-07): 템플릿 완비
- templates/init.sh: 환경 초기화 스크립트 템플릿 — 패키지 매니저 자동 감지, devServer 플레이스홀더 (DEV_SERVER_COMMAND, READY_CHECK_COMMAND, DEV_SERVER_PORT)
- templates/doc-freshness.ts: 문서 최신성 검사 스크립트 템플릿 — DOC_FRESHNESS_DAYS, DOC_CHECK_TARGETS 플레이스홀더
- templates/QUALITY_SCORE.md: 품질 점수표 템플릿 — 6개 카테고리 고정 (플레이스홀더 없음)
- templates/TECH_DEBT.md: 기술 부채 문서 템플릿 — CREATED_DATE 플레이스홀더

### 수정 (Changed) — Session 7 (2026-04-07)
- SKILL.md 5.6: init.sh 생성 규칙에 템플릿 참조 + 3개 플레이스홀더 치환 규칙 추가
- SKILL.md 5.7: doc-freshness.ts 생성 규칙에 템플릿 참조 + 2개 플레이스홀더 치환 규칙 추가
- SKILL.md 5.8: QUALITY_SCORE.md 생성 규칙에 템플릿 복사 방식 명시
- SKILL.md 5.9: TECH_DEBT.md 생성 규칙에 템플릿 참조 + CREATED_DATE 치환 규칙 추가
- SKILL.md 6.11: 미치환 플레이스홀더 검사 범위를 init.sh, scripts/doc-freshness.ts, docs/TECH_DEBT.md로 확장
- SKILL.md 13: 스캐폴딩 참조 테이블을 1차 소스(템플릿) + 2차 참조(guide) 구조로 개편, QUALITY_SCORE.md/TECH_DEBT.md 행 추가
- .tracking/HANDOFF.md: P10 상태를 "범위 밖"으로 확정, 섹션 5 향후 작업 전면 업데이트, 파일 트리에 templates/ 하위 전체 반영
- references/project-context.md: v3.2 버전 추가, 섹션 5/6 업데이트

### 추가 (Added) — Session 6 (2026-04-06): Stop Hook
- .claude/hooks/auto-gc.sh: Stop hook 스크립트 — 미커밋 변경 감지 시 /gc 실행 지시 후 push, 60초 guard로 무한루프 방지

### 추가 (Added) — Session 6 (2026-04-06): Git 워크플로
- templates/rules/git-workflow.md: 대상 프로젝트용 Git 워크플로 템플릿 신규 생성 — Conventional Commits, 체크포인트, 브랜치 정책, 3단계 충돌 해결, 세션 경계
- SKILL.md 5: Phase 2 생성 순서에 git-workflow.md 추가 (15 → 16 항목)
- SKILL.md 5.11: git-workflow.md 생성 규칙, 플레이스홀더 치환 테이블(5개), 역할 분리 행 추가
- SKILL.md 8: 프리셋 스키마에 git 필드 추가 (mainBranch, branchPrefixes, commitLang)
- SKILL.md 6/7: Phase 3 검증 + Phase 4 보고에 git-workflow.md 반영

### 수정 (Changed) — Session 6 (2026-04-06)
- templates/rules/session-routine.md: 세션 시작에 git status 추가, 기능 완료/세션 종료에 git-workflow.md 참조 연결
- SKILL.md 5.1.1: CLAUDE.md 세션 루틴 요약에 git status 단계 추가, 커밋 제안을 git-workflow.md 기반으로 변경
- CLAUDE.md: 파일 맵에 git-workflow 템플릿 명시

### 수정 (Changed) — Session 5 (2026-04-06): 모델 최적화
- SKILL.md 프론트매터: `context: fork` + `model: sonnet` 추가 — 스킬 실행 시 Sonnet 서브에이전트로 자동 전환, 완료 후 기존 모델 복귀

### 추가 (Added) — Session 4 (2026-04-06): TDD Subagent 파이프라인
- CLAUDE.md: 스킬 개발 지침서 신규 생성 — 세션 루틴, 파일 맵, 개발 규칙, 트래킹 절차
- templates/agents/*.md: 7개 TDD subagent 정의 템플릿 — architect, test-engineer, implementer, reviewer, simplifier, debugger, security-reviewer
- templates/rules/session-routine.md: TDD 오케스트레이션 플로우, 상태 머신, 에스컬레이션 규칙
- templates/rules/coding-standards.md: 아키텍처/네이밍 규칙 템플릿 (CLAUDE.md에서 이관)
- SKILL.md 5.10: agents/ 생성 규칙 — 7개 에이전트 파일, 플레이스홀더 치환 규칙, 호출 방법
- SKILL.md 5.11: .claude/rules/ 생성 규칙 — session-routine.md, coding-standards.md, 도메인별 rules

### 수정 (Changed) — Session 4 (2026-04-06)
- SKILL.md 5.1.1: CLAUDE.md 생성 규칙 개편 — Agent Dispatch 테이블 추가, 코드 규칙을 .claude/rules/로 이관, 150줄 이내로 슬림화
- SKILL.md 5: Phase 2 생성 순서 12 → 15 항목으로 확장 (agents/, .claude/rules/ 추가)
- SKILL.md 6: Phase 3 검증에 agents/ 존재 확인(6.4), .claude/rules/ 확인(6.5), 플레이스홀더 치환 검사(6.11) 추가
- SKILL.md 7: Phase 4 보고에 TDD 워크플로 안내 추가, 세션 루틴을 TDD 기반으로 업데이트
- SKILL.md Step 5 계획 제시: 생성 예정 파일 목록에 agents/, .claude/rules/ 추가
- .tracking/HANDOFF.md: P6 완료 표시, 섹션 2를 완료 기록으로 전환
- references/project-context.md: v3 버전 히스토리, 설계 결정 3항목 추가, 디렉토리 구조 업데이트

### 추가 (Added) — Session 3 (2026-04-05~06)
- SKILL.md 5.1.5: 아키텍처 유형별 CLAUDE.md 코드 규칙 분기 테이블 추가 (TODO-23)
- SKILL.md 4.1.1: 질문 우선순위 테이블 (5단계) 추가 (TODO-25)
- SKILL.md 4.1.2: 소크라테스 문답 종료 조건 3가지 추가 (TODO-25)
- SKILL.md 3.3: 프리셋 매칭 동점 해소 규칙 3단계 추가 (TODO-27)
- SKILL.md 5.2: ARCHITECTURE.md 누락 레이어 ⚠️ 경고 규칙 추가 (TODO-29)
- SKILL.md 6절: Phase 3 검증에 `mkdir -p scripts/ docs/` 단계(6.0) 추가 (TODO-30)
- SKILL.md 프리셋 스키마: `detection.versionConstraints` 필드 추가 (TODO-31)
- SKILL.md 프리셋 매칭 로직: 3.5단계 버전 체크 추가 (TODO-31)
- presets/react-next.json: `versionConstraints: { "next": ">=13.0.0" }` 추가 (TODO-31)
- SKILL.md 프리셋 스키마: `docFreshnessDays` 필드 추가 (TODO-33)
- SKILL.md 10절: 재스캔/재생성 플로우 추가 — Phase 1 중/Phase 4 후 분기 (TODO-34)
- SKILL.md 11절(신규): 커스텀 프리셋 작성 가이드 + 필수 필드 체크리스트 (TODO-35)

### 수정 (Changed) — Session 3 (2026-04-05~06)
- templates/structural-test-layer.ts: 정규식 `\w+` → `[\w-]+` 하이픈 폴더명 지원 (TODO-23)
- templates/structural-test-fsd.ts: 동일 정규식 수정 (TODO-23)
- templates/structural-test-layer.ts: re-export 구문(`export { } from`) 감지 추가 (TODO-23)
- templates/structural-test-fsd.ts: re-export 구문 감지 추가 (TODO-23)
- templates/structural-test-layer.ts: 다중 pathAlias(배열) 지원 (TODO-32)
- templates/structural-test-fsd.ts: 다중 pathAlias(배열) 지원 + public-api 검사 반영 (TODO-32)
- SKILL.md 5.3: feature_list.json passes 판정 기준 3가지 구체화 (TODO-24)
- SKILL.md 5.6: init.sh readyCheck 파싱 규칙 4항목 명시 (TODO-26)
- SKILL.md 5.4: 다중 pathAlias 치환 규칙 설명 추가 (TODO-32)
- SKILL.md 5.7: doc-freshness staleness 기준을 `docFreshnessDays` 파라미터로 변경 (TODO-33)
- SKILL.md 5.1.5: AGENTS.md/CLAUDE.md 역할 분리 테이블에 source of truth 컬럼 추가 (TODO-35)
- SKILL.md 프리셋 스키마: `pathAlias` 타입을 `string | string[]`로 확장 (TODO-32)
- SKILL.md 섹션 번호 재정렬: 11→프리셋 가이드, 12→확장 포인트, 13→참고 자료 (TODO-35)

### 수정됨 (Fixed) — Session 3 정합성 점검 (2026-04-06)
- SKILL.md: 섹션 5.1.5 → 5.1.1로 번호 수정 — 5.1.1~5.1.4 없이 5.1.5만 있던 번호 체계 오류 (TODO-36)
- SKILL.md: 프리셋 스키마 `pathAlias` 유니온 문법(`|`) 제거 → JSON 유효 표기 + 코드블록 외부에 타입 설명 (TODO-37)
- presets/react-next.json: `docFreshnessDays: 14` 누락 추가 — 스키마-프리셋 불일치 해소 (TODO-38)
- presets/react-router-fsd.json: `docFreshnessDays: 14` 누락 추가 (TODO-38)

### 추가 (Added) — Session 1~2 (2026-04-04)
- SKILL.md 5.7: doc-freshness.ts 생성 규칙 — 검사 대상, staleness 14일, 출력 형식, exit 0 (TODO-01)
- SKILL.md 5.8: QUALITY_SCORE.md 생성 규칙 — 6개 카테고리 점수표 + known issues (TODO-03)
- SKILL.md 5.9: TECH_DEBT.md 생성 규칙 — 4단계 심각도 + 리팩터링 대상 테이블 (TODO-04)
- SKILL.md 4.4: 기본값 테이블 — 11개 프로필 항목의 기본값+근거, 보고서 명시 규칙 (TODO-05)
- SKILL.md 12: 스캐폴딩 시 references/ 참조 지침 테이블 + 우선순위 규칙 (TODO-07)
- templates/structural-test-layer.ts: 레이어 기반 아키텍처 검증 템플릿 (TODO-08)
- templates/structural-test-fsd.ts: FSD 아키텍처 검증 템플릿 — 레이어+cross-slice+public API (TODO-09)
- SKILL.md 5.4: 템플릿 기반 structural-test 생성 규칙 (TODO-10)
- SKILL.md Phase 3: 자동 수정 가능/불가 항목 테이블 (TODO-16)
- SKILL.md 1절: Node.js/TypeScript 전용 지원 범위 명시 (TODO-18)
- harness-guide.md: 우선순위 안내 + 가상 프로젝트 예시 주석 (TODO-19, TODO-20)

### 수정 (Changed)
- SKILL.md 5.6: init.sh 생성 규칙 보강 — 패키지매니저 감지, readyCheck, set -e, 스크립트 구조 명시 (TODO-02)
- SKILL.md 5.5: validate를 프리셋에서 제거, 동적 조합 전용으로 변경 (TODO-11)
- presets/react-next.json: validate 키 제거 (TODO-11)
- presets/react-router-fsd.json: validate 키 제거 (TODO-11)
- SKILL.md 8절: detection.optional을 매칭 5단계에서 tiebreaker로 활용 (TODO-12)
- SKILL.md 2.4절: 아키텍처 분류 테이블에 영문 type 값 병기 (TODO-13)
- SKILL.md 생성 순서: docs/ 하위 디렉토리 4개 명시 (TODO-14)
- SKILL.md 3절: 실행 흐름 다이어그램에 Step 5 추가 (TODO-15)
- SKILL.md 2.2절: import 감지 grep 패턴 개선 — re-export 포함 (TODO-17)
- SKILL.md 4.2절: 소크라테스 문답 질문 풀 확장 — 상태관리, 백엔드/DB, 도메인 모델, 라우팅 5개 카테고리 추가 (TODO-21)
- SKILL.md 4.3절: 프로필 필수 항목에 "해당 시 추가" 섹션 신설 (TODO-21)
- SKILL.md 5.2절: ARCHITECTURE.md에 프로필 추가 항목 반영 규칙 추가 (TODO-21)
- SKILL.md 5.1.5: CLAUDE.md 생성 규칙 신설 — @AGENTS.md import, 행동 지침 중심, 세션 루틴 포함 (TODO-22)
- SKILL.md 5.1: AGENTS.md에서 테스트/개발서버 섹션을 CLAUDE.md로 이관, 역할 분리 명확화 (TODO-22)
- SKILL.md 전체: CLAUDE.md를 생성 목록, 생성 순서, 검증, 보고, 에러 처리 7곳에 반영 (TODO-22)

### 수정됨 (Fixed)
- SKILL.md 5.3: feature_list.json passes 모순 해결 — "하네스 셋업 시점에는 모두 false" 원칙 확립 (TODO-06)

---

<!-- 작업 완료 후 아래 형식으로 기록:
## [v2.2] — 2026-04-0X

### 추가 (Added)
- SKILL.md: doc-freshness.ts 생성 규칙 (섹션 5.7) — TODO-01
- SKILL.md: 기본값 테이블 (섹션 4.4) — TODO-05

### 수정 (Changed)
- SKILL.md: init.sh 생성 규칙 보강 (섹션 5.6) — TODO-02

### 수정됨 (Fixed)
- SKILL.md: feature_list.json passes 모순 해결 (섹션 5.3) — TODO-06
-->
