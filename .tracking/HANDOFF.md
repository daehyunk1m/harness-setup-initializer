# harness-setup 스킬 개선 핸드오프 문서

> 작성일: 2026-06-10 (갱신 2026-06-14 — 1.9.0 보장 정직화 + 의미검증, 멀티모델 자문 반영)
> 목적: 다음 세션에서 남은 개선 작업을 이어받기 위한 컨텍스트 전달

---

## 1. 현재 상태 요약

### 완료된 작업 (TODO-01 ~ TODO-90 대부분 완료 — TODO-91 보류, TODO-92 후속)

- **Session 1~2 (04-04)**: SKILL.md 사양 갭 메우기, 템플릿 생성, 프리셋 정합성, CLAUDE.md 생성 규칙 (TODO-01~22)
- **Session 3 (04-05~06)**: 전체 코드베이스 분석 → 20개 이슈 발견 → 4단계(Phase A~D) 수정 (TODO-23~35)
  - Phase A: 템플릿 정규식 버그 수정, re-export 감지, CLAUDE.md 아키텍처 분기
  - Phase B: passes 판정 기준, 문답 종료 조건/우선순위, readyCheck, 동점 해소, mkdir 보장, 누락 레이어 경고
  - Phase C: 프리셋 버전 체크, 다중 pathAlias, docFreshnessDays, 재스캔/재생성 플로우
  - Phase D: 프리셋 작성 가이드, 역할 경계 source of truth, 섹션 재정렬
- **Session 9 (04-07)**: 업그레이드 시스템 설계 (TODO-43)
  - `.harness-manifest.json` 매니페스트 스키마 (전체 프로필 + 파일별 해시/카테고리)
  - 파일 카테고리: managed(13) / custom(4) / data(5)
  - 업그레이드 Phase U1~U5 + 부트스트랩 마이그레이션 (v0→v3.3)
  - 마이그레이션 레지스트리 형식 + 체이닝 규칙
  - 설계 문서: `references/upgrade-system-design.md`
- **Session 10 (04-07)**: 업그레이드 시스템 SKILL.md 구현 (TODO-44)
  - § 2 업그레이드 트리거, § 3 Step 0 모드 판별 분기
  - § 5.13 manifest 생성 규칙, § 5 생성순서 18번 추가
  - § 6.12 manifest 검증, § 7 보고 업데이트
  - § 14 업그레이드 시스템 전체 (14.1~14.6): 매니페스트, 카테고리, U1~U5, 레지스트리, 부트스트랩, 엣지케이스
- **Session 12 (04-08)**: 2-스킬 분리 — GitHub Issue #1 해결 (TODO-52)
  - SKILL.md를 분석 스킬(SKILL.md) + 스캐폴딩 스킬(harness-scaffold/SKILL.md)로 분리
  - `context: fork`와 멀티턴 Q&A 비호환 문제 해결
  - `.harness-profile.json` 중간 포맷으로 두 스킬 간 계약 수립
- **Session 13 (04-08)**: Hook-driven continuation + 디렉토리 재구조화 (TODO-55)
  - 스킬 체이닝을 프롬프트 지시 → **Stop hook `decision: "block"` + `additionalContext`** 이중 안전장치로 강화
  - scaffold를 리포 루트 `harness-scaffold/`에 배치 → `install.sh`로 심볼릭 링크 생성
  - scaffold에 `!command` 프로필 주입 + `user-invocable: false` 적용
  - SKILL.md에 `!command` 상태 감지 (§ 0) 추가 → 중단 후 재개 지원
  - 커뮤니티 패턴 반영: oh-my-claudecode ralph, barkain/workflow-orchestration, planning-with-files
- **Session 14 (04-09)**: 이슈 보고 프로세스 + README 재작성
  - harness-feedback 컴패니언 스킬: 스텁 → 실제 구현 (파싱→패턴 분석→초안→gh issue create)
  - HARNESS_FRICTION.md 이슈 카테고리 7종 + 이슈 보고 안내 추가
  - README를 2-스킬 구조 기반으로 재작성 (Mermaid stateDiagram, 시나리오별 동작)
- **Session 15 (04-09)**: Issue #2 수정 — `!command` 블록 권한 에러. frontmatter `allowed-tools` 추가
- **Session 16 (04-09)**: Issue #2, #3 해결 (TODO-55, 56)
  - scaffold 심볼릭 링크 디스커버리 실패 → `harness-scaffold/` 리포 루트 배치 + `install.sh`
- **Session 17 (04-10)**: Issue #5 해결 + 모델 선택 가이드 (TODO-57)
  - Plan 모드 TDD 우회 방지 — Bridge 패턴 (Plan = PRE-RED 대체, RED부터 TDD 합류)
  - session-routine.md "Plan 모드 통합" 섹션 + CLAUDE.md/coding-standards.md 금지 규칙
  - `references/model-selection-guide.md` 리서치 문서 추가
- **Session 18 (04-11)**: 업그레이드 자동 감지 메커니즘 (TODO-58)
  - 근본 원인 분석: 빈 마이그레이션 레지스트리 + 템플릿 변경 감지 부재 + 아키텍처 불일치
  - § 12.6 managed 파일 자동 변경 감지 — 소스 템플릿 재렌더링 비교로 마이그레이션 없이 템플릿 변경 감지
  - 4-상태 판정 매트릭스: 템플릿 변경 × 사용자 수정 조합으로 스킵/자동 덮어쓰기/선택 결정
  - 역할 분리: managed 파일 = 자동 감지 전담, custom/new/remove/profile/data = 마이그레이션 전담
  - fileActions 스키마에 `source` 필드 추가 (auto-detect/migration/category)
  - 양쪽 SKILL.md + upgrade-system-design.md + versioning-policy.md 동기화
- **Session 19 (05-28)**: 외부 통합 기획 PRD 초안 2건 (멀티모델 합성 자문, superpowers 옵트인)
- **Session 20 (06-10)**: 1.1.0 — 하네스 구성 체크리스트 기반 검토·개선 (TODO-59~67)
  - `references/harness-checklist.md` 편입 — Phase 3 검증·단계 판정·자가진단의 판정 기준 SSoT
  - `templates/harness-check.sh` + `npm run harness:check` — 체크리스트 §8 자가진단 구현 (구조/품질/경고 구분), 플레이스홀더 24개로 확장
  - 명령어 SoT를 CLAUDE.md → AGENTS.md "## 명령어"로 이동 (범용 에이전트 접근성), 역할 분리 테이블 3곳 동기화
  - ESLint 보조 규칙 Q&A 옵트인 (`eslintAssist` 프로필 필드, § 5.15 마커 블록 + 멱등 + 폴백)
  - 승격 루프: TECH_DEBT 승격 대기 큐 + reviewer 반복 지적 감지 + session-routine Phase 4 기록·제안
  - 검증 레벨 4단계(coding-standards) + steps↔E2E 1:1 매핑, 세션 루틴 보강(5분 목표, 회귀 우선), 운영 사이클 문서화(CLAUDE.md)
  - 생성 순서 18→20단계, Phase 3 검증 12→14항목, M-1.0.0-to-1.1.0 마이그레이션 등록
- **Session 21 (06-10)**: 1.2.0 — 실전 테스트(TODO-66) + watch 모드 가드 (TODO-69)
  - haja-web-fe에서 1.0.0 → 1.1.0 업그레이드 실전 테스트 성공: 자동 감지·마이그레이션·단계 판정·구조/품질 구분 모두 사양대로. 멱등성만 미검증 (TODO-70)
  - 발견된 갭 수정: watch 기본 test 명령(vitest 단독)이 validate 조합에 들어가 검증 루프 53분 영구 대기 → scripts.test 비대화형 원칙 + 조건부 test:run 키 + M-1.1.0-to-1.2.0
- **Session 22 (06-11)**: 1.3.0 — 잔여 TODO 일괄 처리
  - TODO-70 종결: haja 1.1.0→1.2.0 업그레이드 최종 상태 검증 (manifest 1.2.0, test:run 가드 동작, 중복 섹션 없음)
  - TODO-45~49 구현: react-router-fsd versionConstraints / domain 템플릿(+sharedDirs, {{SHARED_DIRS}}) + custom 동적 생성 알고리즘 / feature_list 3단계 추론 정책 / react-vite·express-api 프리셋 (+detection.exclude 필드 신설)
  - TODO-50(Session 14 기구현 정정)·51(기록 프로세스 확정)·54(스키마 정합성) 종결
- **Session 23 (06-11)**: 1.4.0 — harness-cleanup 컴패니언 스킬 (TODO-71)
  - 운영 사이클(주간/격주/월간) 실행 주체 — 문서 부식·QUALITY_SCORE 재측정·엔트로피 스캔·TECH_DEBT/승격 큐 검토·문서-실구조 일치·passes 재검증
  - CLEANUP_LOG.md 경과 시간 기반 루틴 판별, 삭제 우선·승인 필수·소스 코드 비수정(TDD 위임) 원칙
  - scaffold 연계: Phase 4 운용 스킬 안내 + CLAUDE.md 운영 사이클 안내 1줄 + M-1.3.0-to-1.4.0
  - P10 엔트로피 관리: "범위 밖" → "컴패니언 스킬로 커버"
- **Session 24 (06-12)**: harness-cleanup 첫 실전 실행 — haja-web-fe (TODO-72, 기록 전용)
  - 7개 섹션 전부 사양대로 동작. 발견 11건, QUALITY_SCORE 첫 측정 74/100, 승격 큐 첫 가동(no-console 횟수 1)
  - scope 제한 준수 확인 — 적용 5건 모두 문서·데이터, 코드 수정은 TECH_DEBT 8건으로 TDD 위임. 스킬 갭 없음
  - 2회차 관찰 포인트: CLEANUP_LOG 경과 시간 기반 루틴 판별, 승격 큐 누적 → 승격 제안 발동
- **Session 25 (06-12)**: 1.5.0 — superpowers 옵트인 통합 (TODO-73, E2E까지 종결)
  - PRD 구체화: 미결정 이슈 6건 해소 + 실물 검증 (v5.1.0, 스킬 14종 — 초안 스킬명 3건 정정), F2.2 버전 매트릭스 폐기 → 실존 검증
  - 구현: `integrations.superpowers` 선택 필드, Step 1.6 감지(installed_plugins.json + 폴백), § 5.16 렌더링(실존 검증→제외 필터→AGENTS.md 보조 스킬 섹션), `{{INTEGRATION_NOTES}}` 26번째 플레이스홀더(managed 템플릿 조건부 텍스트의 정규 방법), U1 재감지
  - 매핑 정본: references/integrations/superpowers-mapping.md (연계 3/선택 1/제외 10)
  - **실전 검증 완료**: 감지 표면 실물 일치 (설치 후 대조) + haja 1.2.0→1.5.0 업그레이드 E2E — 다중 홉 체인, U1 재감지 옵트인, 렌더링(69줄), {{INTEGRATION_NOTES}} 치환, harness:check "표준 하네스 가동" 승격. 관찰: 1.2.0 마이그레이션의 문서 본문 표기 미수정 잔존을 업그레이드가 자기 치유 (doc-stale 마찰 기록)
- **Session 26 (06-12)**: 1.6.0 — multi-model-consult 컴패니언 스킬 (TODO-74)
  - PRD 구체화 (미결정 5건 해소 + codex 0.134.0 실측): 위험 플래그 폐기 → `-s read-only --ephemeral`, codex `-o` 캡처, 병렬=병렬 도구 호출, 2파일 구조
  - 구현: SKILL.md(분해 가이드·합성 포맷·degradation·인젝션 방어) + run-advisor.js(env 스트립·차단 스위치·타임아웃·아티팩트). install.sh 글로벌 심링크 (하네스 비의존 범용)
  - 실측: 종료 코드 4경로 + env 스트립 단위 + codex 실호출 E2E(5초) + 디스커버리 확인. gemini 미설치 → degradation 경로 실측 검증
  - Public API 변경 없음 — 스키마 version 1.6.0 동기만 (업그레이드 no-op). 하네스 연계는 안정화 후

  - 1.6.1 (핫픽스): install.sh `ln -sf` → `ln -sfn` 멱등성 수정 — 재실행 시 자기참조 심링크 생성 버그 (v1.6.0 커밋에 잔여물 포함됐었음, 제거 완료). 설치는 v1.6.1 이상
- **Session 27 (06-12)**: 1.6.2 — 멀티모델 자문 권고 반영 (TODO-76~78)
  - **multi-model-consult 첫 실사용**: 자문 대상 = 이 스킬 구조 자체. codex(결함 관점, 61초) + Claude(대안 관점) 합성, gemini 부재 degradation 경로 실동작. 10개 권고 중 4건 선별 수용 — "판단은 LLM, 계약-임계 역학은 코드" 경계
  - 적용: Stop hook `approved` 검사 (TODO-76, 5케이스 시뮬레이션), § 5.15 ESLint 비실행 원칙 (TODO-78), .gitignore에 .claude/artifacts/
  - 등록: TODO-77 (§ 12.6 해시 재현성 결정화 — 오탐 마찰 누적 시 착수), TODO-53에 픽스처 매트릭스 병합
- **Session 28 (06-13)**: 1.6.3 — gemini trust 게이트 수정 + 첫 3중 합성 (TODO-77/79)
  - **gemini CLI 설치 후 첫 3중 합성**: 자문 대상 = TODO-77 설계 결정. gemini 헤드리스 trusted-directory 게이트(exit 55) 갭 발견·수정 (TODO-79: `--approval-mode plan --skip-trust`, plan=codex -s read-only 대응). 실측 exit 55→0
  - **TODO-77 C안 확정**: 3중 합성(codex source-fingerprint + gemini 멱등성)이 단일 모델의 A/B 이분법보다 나은 제3안 도출. `templateSourceHash`로 템플릿 변경 판정 → LLM 재렌더링 암묵 계약 제거. 구현은 별도 (manifest 스키마 MINOR)
  - 도그푸딩 성과: 자문 스킬이 자기 설계 결정에 실제로 기여 + 자기 갭을 발견

- **Session 29 (06-13)**: 1.6.4 — 누적 정합성 감사 (TODO-80)
  - 워크플로 적대적 감사(5개 관점 병렬)로 1.0.0→1.6.3 누적 드리프트 전수 점검. 도그푸딩 연장
  - 진짜 드리프트 4건: 현재 시제 "24개"→26개, SKILL.md 교차참조 명확화, 버전 히스토리 순서 재정렬+1.6.3 누락 추가, 마이그레이션 "1.4.0 이후 불필요" 안내
  - 오탐 3건 식별(수정 안 함): 역사 기록 "24개/12→14"·"15항목"(6.0 제외 정확)·마이그레이션 의도적 불필요 — 감사 에이전트의 "현재 시제 vs 역사 기록" 미구분이 오탐 원천

- **Session 30 (06-13)**: 1.7.0 — 외부 통합 규약 일반화 + multi-model-consult 등록 (TODO-81)
  - superpowers·consult 두 선례에서 공통 패턴 추출 → `integrations.<name>` 메커니즘 일반화. references/integrations/_protocol.md 규약 정본 신설
  - §5.16 "외부 통합 연계 렌더링"으로 일반화 (다중 스킬/단일 CLI 분기, 단일 "## 보조 스킬" 섹션 합산), multiModelConsult 두 번째 통합 등록
  - AGENTS.md 섹션 형식 "## 보조 스킬 (superpowers 연계)" → "## 보조 스킬" + 출처 표기. M-1.6.4-to-1.7.0 마이그레이션(기존 하네스 정규화)
  - 검증 기준: superpowers(복잡·14종)와 consult(단순·단일)가 같은 규약으로 표현 — 규약 일반화 실증

  - **실전 검증 완료** (haja 1.5.0→1.7.0 업그레이드): M-1.6.4-to-1.7.0 적용, U1 재감지 → consult 두 번째 통합 옵트인, 두 통합 합산 섹션 + {{INTEGRATION_NOTES}} 2줄, AGENTS.md 70줄(dual에도 100줄 여유), 해시 재현성 일치, "표준 하네스 가동". 1.5.0~1.6.4 마이그레이션 불필요도 실증. 스킬 갭 없음 (TODO-81 잔여 종결)

- **Session 32 (06-13)**: 1.7.1 — 깃 이슈 정리 (TODO-82~86)
  - 열린 이슈 5건 1.7.0 기준 대조: #7(부트스트랩 버전, 해결)·#8(컴패니언 링크, 해결) 수정·닫기 / #9·#6·#4 구현 항목 등록
  - #8: install.sh companion-skills/* 루프 → feedback/cleanup 글로벌 링크 (CLAUDE.md 안내와 일치). #7: 부트스트랩 "3.3"→"1.0.0" 문서 정정
  - 미해결 3건 구현 항목: TODO-84(마찰 자동 기록), TODO-85(인프라 트랙), TODO-86(자동 커밋 confirm 모드 — 방향 확정)

- **Session 33 (06-13)**: 1.8.0 — 자동 커밋 confirm 모드 (TODO-86, 이슈 #4)
  - 프로필 선택 필드 `autoCommit`(mode off/confirm/auto + pushAfterCommit), 생략=off(기존 제안만). 새 플레이스홀더 2종(26→28), git-workflow.md 자동 커밋 정책 섹션
  - "승인 없이 git 실행 금지" 절대 규칙과 호환: confirm=승인이 곧 확인, auto=명시 옵트인, 위험 작업은 항상 제안. 마이그레이션 불필요(managed 자동 감지 + 생략 기본)

- **Session 34 (06-14)**: 1.9.0 — 보장 정직화 + 의미검증 (TODO-87~92, 멀티모델 자문)
  - codex(결함)+gemini(검증/운영) 자문 결론 "구조만 보장, 의미 정확성 비보장" → 4 구현 + 1 보류 + 1 후속. 진짜 갭 2건(custom exit-0 silent pass, 의미 게이트 부재) 폐기
  - Q2 미강제 강등(`{{Q2_ENFORCEMENT}}` 마커 28→29, manifest `structuralTestEnforcement`, harness-check ④-b → MVH 강등 exit 0), 골든 픽스처(`test/`, **6/6 통과 실측**), 의미 게이트(Phase 4 "아키텍처 정확성 확인" + `semanticApprovalAt`), 보장 문구 정직화
  - item 5(프로필 JSON Schema 검증) 보류(1.6.2 비수용 유지). MINOR, 마이그레이션 불필요. 도그푸딩 4회차(자문 대상=스킬 구조 자체)
  - **실전 검증 완료** (1.7.0→1.9.0 업그레이드 E2E, 사용자 실행): 마이그레이션 0 — 1.7.1·1.8.0·1.9.0 모두 managed 자동 감지로 전파, 영향 managed 4개 사용자 수정 없어 재생성 + 해시 재현성 일치. harness:check "표준 하네스 가동" + "Q2 강제"(enforced 프로젝트). auto 모드 자동 커밋(190fbef). **검증 범위 한계**: enforced+업그레이드 경로라 Q2 미강제 강등·setup 의미 게이트는 미발동(시뮬레이션 검증 유지). **관찰**: 업그레이드 경로(U1~U5)는 의미 게이트 미경유 → `semanticApprovalAt=null` 유지(규칙 불변이라 의도된 동작, TODO-92 검토)

- **Session 35 (06-15)**: 1.10.0 — 첫 셋업 능력 카탈로그 (TODO-93, 이슈 #11)
  - scaffold Phase 4 보고 fenced 블록에 `### 이제 할 수 있는 일`(≤12줄, 8능력+영속 포인터) 신설 — 기존 "운용 스킬 (선택)" 흡수. 각 줄 = `[능력]→[트리거](상세: 정본)`
  - 펜스 직후 "카탈로그 렌더링 규칙" 산문(의미 게이트 앞): **순수 투영** — 산출물 게이트 신호(`integrations.multiModelConsult`+§5.16, 생존 `linkedSkills`, 컴패니언 글로벌 전제) 재사용, 새 게이트 로직·플레이스홀더 0 → 미와이어 능력 광고 불가. §10.2 U5 비대칭 1문장(카탈로그 미출력)
  - **의미 정확성 교정**: 이슈 #11의 "Security Reviewer = §5.10 게이트" 거짓 확인(§5.10은 7개 에이전트 항상 생성) → 실제 게이트는 session-routine Phase 4.5 SECURITY 호출 조건(`tdd.securityCategories` 매칭). 카탈로그는 파이프라인 비열거·정본 지시. 부수: README 버전 드리프트 1.8.0→1.10.0 정정
  - **신규 생성 파일 0** — harness-check ①·doc-freshness 타깃·manifest files{}·"19개 파일" 카운트·§10.3 레지스트리 무변경. Public API 4계약 무변경(MINOR). 마이그레이션 불필요

- **Session 36 (06-15)**: 1.11.0 — E2E 스캐폴드 모듈 (이슈 #12 증분 1)
  - 프론트엔드 옵트인 시 Playwright 기반 E2E 셋업(`playwright.config.ts` + `e2e/` + `test:e2e` + `@playwright/test` devDep) 생성 — harness-scaffold §5.17 + package.json 머지 확장. 템플릿 5종 + 골든 픽스처(`test/e2e-fixtures.sh`)
  - e2e 프로필 스키마(`e2e: { enabled }`, 두 SKILL.md 동기), manifest 카테고리 계약(config=managed/스타터=custom), harness-check ⑧ 구조 검사(경고 전용·자기 게이트), Phase 4 카탈로그 E2E 줄(순수 투영, `e2e.enabled` 게이트)
  - Vitest 충돌은 `*.e2e.ts` 네이밍 회피(vitest.config 미수정), tsconfig 절대 비수정(e2e/tsconfig.json 자체 경계). **신규 플레이스홀더 0개**(29개 불변), 옵트인·생략 기본 → 마이그레이션 불필요. MINOR

- **Session 37 (06-16)**: 1.12.0 — E2E TDD 배선 (이슈 #12 증분 2a)
  - 증분 1의 E2E 스캐폴드를 TDD 사이클에 배선: coding-standards `@critical` 정의, architect E2E 슬롯 완성, test-engineer E2E 작성 심화 + **E2E 판정 Output(created/skipped/not_applicable, 침묵=BLOCK)**, debugger 브라우저 재현(플레이키니스 환각 금지), session-routine VERIFY(E2E) Phase 4.7(해당 feature 스펙만 실행, FAIL→GREEN 시도 누적) + TDD STATE 보존 + `e2e-fail` 마찰
  - 결정: (a) E2E 작성 주체 = **Test Engineer 확장**(신규 에이전트 아님, 7개 불변), (b) pre-push = **무의존 git hook**(증분 2b로 분리)
  - **멀티모델 적대적 검증**(codex 결함/gemini 운영): 게이트를 LLM 기억 → 명시적 판정+TDD STATE+`@feature:` grep 키로 결정화, VERIFY 범위 축소(feature 스펙만), 증분 2 → 2a/2b 분할. 도그푸딩 6회차
  - 전부 managed 템플릿 편집 → §12.6 자동 감지 전파, **신규 파일·git config·플레이스홀더 0(29 불변)**, 마이그레이션 불필요. 골든 픽스처 회귀 통과

- **Session 48 (06-17)**: 1.22.0 — 피드백 보고 트리거 (이슈 #14 종결). 마지막 열린 마찰 이슈. 마찰 **기록**은 1.18.0(jsonl)으로 자동화됐으나 **보고**(harness-feedback) 호출 트리거가 없어 dead-letter이던 문제를 마감. **해결(5부)**: ① 신규 `data` 파일 `.harness-feedback-cursor`(1줄 JSON `{processedLines, lastReportedAt}` — 보고 위치 북마크·단일 상태원, `processedLines`=처리 물리 줄 수 `grep -c ''`) ② session-routine § 세션 종료 트리거 — cursor 이후 미보고 마찰을 보고 기준(`critical≥1 OR 동일 event≥2 OR high≥2`, `infra-track-entry`·`session-incomplete` 제외)으로 평가해 충족 시 **한 줄 제안만**(무-훅·gh 무호출·자동 실행 없음, 보고 시 cursor 전진 → nagware 방지) ③ harness-feedback cursor 이후만 분석 + 보고/무시 시 cursor EOF 전진(§6 3분기 y/d/n) + fingerprint `<!-- harness-friction:fp=event:{event} -->` 백스톱 dedup·race 재조회 ④ 월간 운영 사이클 보조 net(harness-cleanup M4) ⑤ graceful degradation(cursor 부재=`processedLines:0`). **설계 결정(멀티모델 자문)**: stateless gh-dedup 초안 → codex 결함 + gemini 대안 자문이 stateless 3약점(제목 매칭 취약·닫힌 Issue 재분석 루프·교차세션 drip) 드러냄 → **cursor 북마크 상태 결정**으로 셋 다 해소. 트리거 기준을 harness-feedback 보고 기준과 **동일** 정렬(제안=반드시 보고 가능). **마이그레이션 불필요**(cursor 부재 graceful, 기존 하네스 첫 보고 시 자동 생성, 업그레이드 직후 첫 세션 종료에 누적 백로그가 "미보고 N건" 노출=의도). 신규 플레이스홀더 0. **검증**: 골든 픽스처 `test/feedback-cursor-fixtures.sh` 12 케이스(T1~T12) + 태스크별 2단계 subagent 리뷰(**라이브 하네스 실주행 미수행** — 픽스처+리뷰 검증). MINOR. **이슈 #14 닫힘 → 열린 이슈 0**.
- **Session 47 (06-17)**: 1.21.0 — E2E 아티팩트 .gitignore 머지 (이슈 #13). 열린 마찰 이슈 2건(#13 low·#14 보고 트리거) 중 **리소스 적은 #13부터** 착수. E2E 스캐폴드가 `playwright.config.ts`는 만들면서 실행 산출물(`test-results/`·`playwright-report/`) gitignore 처리를 누락해 스모크 후 untracked로 남던 마찰(haja 파일럿 수동 추가, #12 의도의 구현 누락분)을 마감. harness-scaffold §5.17에 **멱등 add-only 마커 머지**(`harness-setup:e2e-artifacts:start~end`) 추가 — `/test-results/`·`/playwright-report/`(Playwright 공식 루트앵커). **중복 회피**(마커 밖 사용자 수동 항목 토큰 매칭 → 둘 다 있으면 no-op), 비실행(텍스트 R/W만), 비침습(기존 항목 불변). **카테고리**: 사용자 소유 마커 블록 → manifest files 미기록(§10.1 #33, ESLint·package.json 동급), §12.6 비대상. **소급**: §10.2 U3 step 6-b — add-only·멱등이라 기존 e2e 하네스에 업그레이드 시 멱등 소급(1.17.0 README 무소급과 대비). §6.16 검증 + 자동수정 항목. **적대적 리뷰(3관점 워크플로, 확정 12건)로 4건 수용**: dedup을 **루트 앵커 첫 세그먼트 매칭**으로 강화(글로브 `test-results/*`·`**/test-results/` 인식, 중첩경로 leak 방지 미일치, 음수패턴 존중) + §5.17 문구 정확화(playwright-report는 html/show-report 시 생성) + cross-ref §10.3→§10.1 정정 + U1 재감지 출력목록 명시. **실측 12 시나리오**(6 회귀 + 6 글로브) 전부 설계대로 + 골든 픽스처(e2e·structural) 회귀 통과. 신규 필드·플레이스홀더·파일 0, 옵트인. MINOR. **이슈 #13 닫힘 → 열린 이슈 #14(보고 트리거 미정의)만 잔존**.
- **Session 46 (06-17)**: 1.20.0 — 인프라/설정 트랙 (이슈 #6, TODO-85 종결). Plan 모드 인프라 작업(AuthProvider 배선 등) 시 TDD 전면 우회 문제. 세션루틴 우회는 Plan 통합(이슈 #5)으로 차단됐고, 잔존(infra category 부재·설정작업 TDD 부적합·전체 스킵 경로 부재)을 `## 인프라/설정 트랙`으로 해소 — category `infra`/`config`에 Architect·유닛 RED 스킵 + 통합 검증(빌드+실동작) 대체. **남용 방지(사용자 '최대 엄격')**: 사전 선언(재분류 금지)+부정 테스트(조건3 우선)+범위 한정+모호→TDD, Reviewer 필수·분류 감사, 보안 표면 트리거(infra라도 .env/auth/provider 닿으면 Security 필수 — 이슈 #6 AuthProvider 사례), 감사 이중 기록(claude-progress + `.harness-friction.jsonl` `infra-track-entry`), 다단계는 Phase별 분해(문제점 #5). "전체 스킵 유일 경로=인프라 트랙" 노트로 임의 우회 차단. **설계 검증**: 4-관점 적대적 워크플로(우회/정합성/완결성/계약) → 발견 10건(HIGH 4) 전부 반영 후 릴리스. 신규 필드·플레이스홀더 0(always-on), managed 자동 감지 전파·마이그레이션 불필요. MINOR. **이슈 #6 닫힘 → 열린 이슈 0**.
- **Session 45 (06-17)**: 1.19.0 — harness-check 의존성 미설치 사전 감지 (TODO-100). `node_modules` 부재 시 `harness:check`이 ④ 아키텍처 검사·⑤ 통합 검증을 `vitest: command not found`(exit 127)로 실패시켜 **MVH/품질-실패로 오라벨링**하던 문제(TODO-53 신규셋업 실주행 발견 — `npm install` 1회로 표준 승격 확인됨)를 완화. **해결**: `templates/harness-check.sh`가 ④⑤ 실행 앞에서 `node_modules` 사전 감지(`DEPS_MISSING`) → 부재 시 ④⑤⑥를 "⏸️ 의존성 미설치로 보류"로 표기, 종합 판정에 **"의존성 미설치 (구조 정상)" exit 0** 브랜치 신설. 구조 항목(①②③) 판정 불변(구조 실패가 우선), exit 코드 정책은 checklist §8과 정합(exit 0=구조 정상의 정당한 상태, exit 1=진짜 점검 실패). **자동 설치 금지 절대 규칙 보존**. 판정 식별은 출력 텍스트(`⏸️ 의존성 미설치`)로 — exit code만으론 표준과 구분 불가(scaffold §7 판정 행·§6.13 주석 명시). checklist §7·§8 "의존성 미설치 — 판정 보류" 노트(Q2 미강제와 평행). **렌더 후 5 시나리오 실측** 전부 설계대로(정상=표준 exit0 / deps부재=보류 exit0 / 진짜품질실패=exit1 / 구조실패=exit1 / 구조실패+deps부재=구조우선 exit1). 신규 프로필 필드·플레이스홀더 0, managed 자동 감지 전파·마이그레이션 불필요. MINOR.
- **Session 44 (06-16)**: 1.18.0 — 마찰 자동 기록(저비용 JSONL 싱크, 이슈 #9, TODO-84 종결). 근본 원인: 마찰 이벤트는 오케스트레이터가 즉시 알지만 마크다운 테이블 행 삽입(읽기→탐색→삽입→재작성)이 무거워 부하 시 건너뛰어짐 → haja-web-fe 1개월 실사용에서 로그 헤더만 남고 0건, harness-feedback dead-letter. **해결**: session-routine 마찰 기록을 단일 JSON 라인 append(`echo '{...}' >> .harness-friction.jsonl`) + detail 소독(`"`→`'`·줄바꿈/CR 제거·`\` 제거·≤50자), 세션 시작 `SESSION_ID`(`{ISO 시각}-{4자 난수}`)→claude-progress.txt, 종료 미완료 시 session-incomplete append. `HARNESS_FRICTION.md` 정적 참조 문서로 격하(테이블·렌더러 개념 제거, manifest `data`→`managed`). scaffold가 빈 `.harness-friction.jsonl` 생성 + manifest category **`data`**. harness-feedback 입력 jsonl 전환 + 관용 파싱(깨진 줄 스킵·스킵 수 보고)·escape. 두 SKILL.md 계약 동기화 — **프로필 신규 필드 없음(always-on)**, 스키마 version 1.17.0→1.18.0. checklist·harness-check.sh 필수 파일 추가. **아키텍처(옵션 i — Stop hook 없음)**: 멀티모델 자문(codex 정확성/gemini 단순화) 종합 — gemini 단순화 주축 + codex 견고성 디테일(깨진 줄 격리·고유 SESSION_ID·detail 소독) 흡수; Stop hook은 발화 비보장·settings.json 끌고옴으로 v1 비채택(measure-first). MINOR, 하위 호환, 업그레이드 마이그레이션 불필요. Subagent-driven 실행(각 Task spec 리뷰). 설계 정본: `.tracking/specs/2026-06-16-friction-auto-logging-design.md`.
- **Session 43 (06-16)**: TODO-53 신규 셋업 경로 실전 테스트 완료 (스킬 사양 무변경 — 버전 유지 1.17.0). `_sandbox/vite-spa`(react-vite) 픽스처 신규 생성 + 사전 적대적 검증(7-에이전트 워크플로, 픽스처 소스 수정 불필요 확정) → **2회 실주행(Opus급 + Sonnet 4.6 1M high) 둘 다 "표준 하네스 가동" 9/9**. **교차 모델 핵심**: 결정적 게이트(표준 판정·structural-test 0위반·Q2 enforced·100줄 예산·JSON 유효성)는 모델 독립 동일, 모델 판단 출력(feature_list 5↔3·AGENTS.md 69↔59줄)만 가드 내 변동 → Session 34 "구조 보장/의미 비보장" 설계 실증. 라이브 첫 검증 2건: 셋업 의미 게이트(semanticApprovalAt — 이전 시뮬레이션만) + eslintAssist flat surgical insertion(§5.15, Sonnet 옵트인). 발견: node_modules 부재 시 ⑤ validate 실패로 일시 MVH 오라벨링 → **TODO-100**(개선 후보, 구현 별도). 픽스처/가이드는 `_sandbox/`(부모 gitignore, 자체 git repo). 미검증 이월: Q2 미강제 강등·superpowers 미설치 경로·harness-cleanup 첫 실행·픽스처 매트릭스 확장(express-api/엣지케이스).
- **Session 42 (06-16)**: 1.17.0 — E2E 모듈 마감 (이슈 #12 증분 4, TODO-97). 스코핑 핸드오프(`docs/superpowers/specs/2026-06-16-e2e-incr4-handoff.md`) 4작업 + 사용자 확정 결정(AskUserQuestion: D1=pre-seed·D2=e2e/README.md managed·D3=cascade·D4=단일)을 design doc + plan으로 확정 후 inline 실행. **A** §12.6.1에 e2e managed 3파일 매핑 편입(증분 2b 이월 정렬, deferral 제거). **B** 프론트엔드 프리셋 3종 `e2e:{enabled:true}` 권장 기본(옵트인 질문 유지·기본답 "예", express 비대상). **C** U1 base-E2E 재감지 + pre-push cascade. **D** 사람 개발자용 `templates/e2e/README.md`(managed·정적·8절·정본 참조 비복제). **핵심 설계 발견(핸드오프 과소명세)**: §12.6 자동 감지는 manifest 기록 파일 **업데이트 전용**(신규 파일은 `[new]` 마이그레이션 영역) → README는 신규셋업·U1 재감지 옵트인 경로로만 생성, 기존 e2e 하네스 소급 생성 안 함(비침습·옵트인 보존). §10.3 1.17.0 노트에 파일별 전파 경계 정직 명시. 신규 플레이스홀더 0(31 불변)·프로필 스키마 byte-identical·마이그레이션 불필요·골든 픽스처 4종 통과. MINOR. 적대적 검증(워크플로) 후 태그.
- **Session 41 (06-16)**: 1.16.0 — E2E 레이아웃 회귀 트리거 확장 (이슈 #12, TODO-99 보류→승격). 2b 하네스(1.14.0) 도그푸딩에서 레이아웃 작업(컨테이너 내부 스크롤·독립 토글·공간 분배)이 `shouldAutoExpand` 헬퍼 유닛만 TDD하고 load-bearing 레이아웃(페이지 스크롤 0·peek 3행·50/50 분배)은 ad-hoc 스크린샷 1회 확인 후 `.e2e.ts` 미코드화 — 1.13.1 TaskItem에 이은 **2번째 데이터포인트** → 핵심원칙 #5(반복=승격), 사용자 "지금 승격" 결정. E2E 트리거를 "UI 상호작용 **또는 시각/레이아웃 회귀 위험**"으로 확장 + jsdom 한계 명시(coding-standards) + 완료 게이트 "브라우저 검증→스펙 코드화"(session-routine) + verdict created/not_applicable 미러(test-engineer) + checklist §4.2. 부수: stale "(후속) 증분 2b" 참조 3건 정리. 신규 필드·플레이스홀더·파일 0(31 불변), managed 자동 감지 전파, 마이그레이션 불필요. MINOR. **태그 보정 동반**: 누락된 v1.13.0(34f03e1)·v1.13.1(1c4ae90) annotated 태그 생성·원격 푸시 → v1.9.0~v1.16.0 연속.
- **Session 40 (06-16)**: 1.15.0 — Playwright MCP 진단 배선 (이슈 #12 증분 3). 배치 = e2e 모듈 확장(integrations 규약 비사용 — debugger가 코어 SoT). 비커밋 B안(공유 `.mcp.json` 미생성 — 멀티모델 자문 codex·gemini의 nagware·머지 회피 권고). `e2e.mcp` 분리 옵트인(`enabled`/`version`, `e2e.enabled`와 독립). `{{MCP_DEBUG_PROTOCOL}}`(30→31) — debugger.md 조건부 MCP 진단 블록 + 개발자 로컬 `claude mcp add` 등록. harness-scaffold §5.19 + Phase 4 카탈로그/보고 + U1 재감지, `test/mcp-fixtures.sh` 골든 픽스처. 신규 산출물 파일 0·옵트인·생략 기본 → 마이그레이션 불필요.

- **Session 39 (06-16)**: 1.14.0 — E2E pre-push 게이트 (이슈 #12 증분 2b). 옵트인 e2e.prePush → .githooks/pre-push, validate→@critical, 수동 활성화(D1), eslint override 드롭(D4), harness-check ⑨, 골든 픽스처. Subagent-driven 실행, 각 Task 2단계 리뷰.

- **Session 38 (06-16)**: 1.13.0 — E2E VERIFY 러너 정합 + 파일럿 마찰 수정 (haja 1.9→1.12 업그레이드 검증)
  - **F3(high)**: VERIFY(E2E) Phase 4.7이 유닛 러너(`{{TEST_COMMAND}}`)로 E2E 실행 → `.e2e.ts` 0개 수집 후 거짓 PASS로 게이트 무력화. 신규 `{{E2E_COMMAND}}`(29→30, `e2e.enabled`+`test:e2e`에서 도출, 새 프로필 필드 없음)로 교체 + test-engineer 교차참조 정합
  - **F1(medium)**: seed.ts `_payload` 미사용 → `void payload`(no-unused-vars 설정 무관 통과). **F2(low)**: harness-check ⑧ `files:[]`+`references` 위임 루트 오경고 → short-circuit
  - 교훈: harness:check(정적)는 런타임 Phase 4.7 미경유로 F3 미검출 — 실전 기능 주행이 검증에 필수. MINOR, 마이그레이션 불필요, 골든 픽스처 6/6
  - **증분 2b(TODO-95b) 타깃 1.13.0→1.14.0 재지정**(1.13.0이 본 릴리스에 소비됨)
  - **1.13.1**: haja TaskItem 레이아웃 수정 도그푸딩 발견 — 에이전트가 `@critical`로 E2E 판정 도출 + `not_applicable` 즉흥 분류. test-engineer.md §3.5에 3 status 기준 명시(not_applicable=UI 표면 전무 시만, UI 있는데 미작성=skipped) + @critical은 verdict와 무관(2b 전용) 명기. PATCH. **보류 TODO-99**: 시각/레이아웃 회귀 사각(jsdom 검증 불가) — E2E 스코프 확장은 데이터 더 모은 뒤

**현재 버전: 1.22.0** (피드백 보고 트리거 — 이슈 #14)
**열린 이슈: 0건** (#14 종결 — cursor 북마크 기반 무-훅 세션 종료 트리거로 dead-letter·nagware·닫힌이슈 재분석 동시 차단)

상세 변경 이력: `.tracking/CHANGELOG.md` 참조
투두 상태: `.tracking/TODO.md` 참조

### 현재 스킬 구조 (hook-driven continuation)

**SKILL.md (harness-setup)** — 분석 + Q&A + 오케스트레이션
- `!command` 상태 감지 (§ 0): 프로필/매니페스트 존재 여부에 따라 분기
- 프로젝트를 스캔 → 소크라테스 문답 → `.harness-profile.json` 저장
- **Stop hook**: 프로필 존재 + 매니페스트 미존재 → `decision: "block"` + scaffold 호출 강제
- 프롬프트 지시 (§ 4 Step 5)도 병행 — 이중 안전장치

**harness-scaffold/SKILL.md (harness-scaffold)** — 스캐폴딩 + 검증 + 보고 전용
- `!command` 프로필 주입 (§ 0): 프로필 JSON을 프롬프트에 사전 주입, 미존재 시 에러
- `user-invocable: false`: 사용자 메뉴에 숨김, Claude/오케스트레이터만 호출
- **Stop hook**: 매니페스트 미존재 → `decision: "block"` + 스캐폴딩 계속 강제
- **디스커버리**: `install.sh`가 `~/.claude/skills/harness-scaffold` 심볼릭 링크 생성
- 생성 파일: CLAUDE.md, AGENTS.md, ARCHITECTURE.md, agents/*.md (7개), .claude/rules/ (3개), feature_list.json, claude-progress.txt, init.sh, scripts/structural-test.ts, scripts/doc-freshness.ts, scripts/harness-check.sh, docs/QUALITY_SCORE.md, docs/TECH_DEBT.md, docs/HARNESS_FRICTION.md, docs/ 하위 디렉토리, package.json scripts, (옵트인 시) ESLint 보조 규칙, .harness-manifest.json

**`.harness-profile.json`** — 두 스킬 간 계약(contract)
- 분석 스킬이 출력하고 스캐폴딩 스킬이 입력으로 사용하는 중간 포맷

**자동 디스커버리**
- `--add-dir ~/.claude/skills/harness-setup` 하나로 두 스킬 모두 로딩
- `.claude/skills/` 하위 디렉토리는 자동 디스커버리됨

### 업그레이드 시스템 (v1.0.0+)
- Step 0 모드 판별: Setup / Bootstrap+Upgrade / Upgrade
- `.harness-manifest.json`으로 버전 추적 (프로필, 파일 해시, 카테고리)
- 파일 카테고리: managed(13) / custom(4) / data(5) — 카테고리별 업그레이드 동작 차별화
- Phase U1~U5: 분석→계획제시→실행→검증→보고
- **managed 파일 자동 감지 (§ 12.6)**: 소스 템플릿 재렌더링 → expectedHash vs templateHash로 템플릿 변경 자동 감지. 마이그레이션 없이도 동작
- **4-상태 판정**: 템플릿 변경 × 사용자 수정 조합 → 스킵/자동 덮어쓰기/선택
- 마이그레이션 레지스트리: custom/new/remove/profile/data 변경 전용. M-{from}-to-{to} 형식, 체이닝 지원
- 부트스트랩: manifest 없는 기존 프로젝트를 1.0.0으로 편입
- 엣지 케이스 6개 처리 (중단, 새 플레이스홀더, 프리셋 삭제, 파일 삭제, 아키텍처 변경, 팀 환경)

### 피드백 수집 시스템 (v3.3)
- session-routine.md가 6개 마찰 이벤트(에스컬레이션, 검증 실패 등)를 자동 감지하여 `docs/HARNESS_FRICTION.md`에 기록
- 컴패니언 스킬 구조: `companion-skills/harness-feedback/` (스텁, 향후 구현)
- Phase 4 보고에서 컴패니언 스킬 `--add-dir` 안내

### 체이닝 메커니즘 (hook-driven continuation)
- **SKILL.md (harness-setup)**: 메인 세션에서 실행. Stop hook이 프로필 저장 후 scaffold 호출을 강제
- **harness-scaffold/SKILL.md**: `user-invocable: false`, `!command`로 프로필 주입. Stop hook이 매니페스트 생성까지 완료 강제
- 이중 안전장치: Stop hook (`decision: "block"`) + 프롬프트 지시 (§ 4 Step 5)
- 등록: `git clone` + `install.sh`로 심볼릭 링크 생성하여 두 스킬 디스커버리

### 하네스 엔지니어링 P1-P10 대비 커버리지

| 프로세스 | 상태 | 비고 |
|----------|------|------|
| P1 저장소 뼈대 | ✅ 완료 | |
| P2 문서 체계 | ✅ 완료 | AGENTS.md + CLAUDE.md 역할 분리 + source of truth 명시. 1.1.0: 명령어 SoT를 AGENTS.md로 이동 |
| P3 아키텍처 레이어 | ✅ 완료 | 다중 alias, 하이픈 폴더명, re-export 지원 |
| P4 기능 리스트 | ✅ 완료 | passes 판정 기준 구체화 |
| P5 Initializer Agent | ✅ 스킵 | 스킬 자체가 초기화 역할 — 별도 프롬프트 불필요 |
| P6 Coding Agent 루틴 | ✅ 완료 | TDD subagent 파이프라인 (7 agents) + .claude/rules/ 분리. 1.20.0: 인프라/설정 트랙(category infra/config → 유닛 RED→GREEN을 통합 검증 대체, 남용 방지 게이트·Reviewer 독립 감사·보안 표면 트리거, 이슈 #6) |
| P7 검증 피드백 루프 | ✅ 완료 | 재스캔/재생성 플로우 추가. 1.11.0: E2E L4 스캐폴드(옵트인) — Playwright 구조 생성, 스위트 통과는 앱별 부팅 의존. 1.12.0: E2E TDD 배선(VERIFY Phase 4.7 + @critical + debugger 재현, 증분 2a). 1.13.0: VERIFY(E2E) 러너 정합(`{{E2E_COMMAND}}`) — 유닛 러너 거짓 PASS 차단(haja 파일럿). 1.14.0: pre-push 게이트(@critical cross-feature 강제, 옵트인·수동 활성화). 1.15.0: MCP 탐색 진단 배선(옵트인, 증분 3) — 공유 .mcp.json 없이 debugger 지침+로컬 등록. 1.16.0: E2E 작성 트리거에 시각/레이아웃 회귀 위험 포함 — jsdom-blind 회귀 가드(TODO-99 승격). 1.17.0: E2E 모듈 마감(증분 4) — §12.6.1 매핑 정렬·프리셋 권장 기본·U1 base-E2E 재감지(cascade)·사람 개발자 작성 가이드(e2e/README.md managed). **신규셋업 경로 실전 검증(Session 43, TODO-53): react-vite 2회 실주행(Opus급·Sonnet 4.6 1M high) 둘 다 "표준 하네스 가동" — 결정적 게이트 model-robust, 셋업 의미게이트·eslintAssist·E2E pre-seed 라이브 검증**. 1.21.0: E2E 아티팩트 `.gitignore` 멱등 add-only 머지(이슈 #13 — 스모크 후 untracked 마찰, U3 step 6-b 소급). 1.22.0: 피드백 보고 트리거(이슈 #14) — cursor 북마크(`.harness-feedback-cursor`, data) 기반 세션 종료 무-훅 제안으로 마찰 보고 dead-letter 마감 + harness-feedback cursor 추적·fingerprint dedup·3분기 확인 + 월간 보조 net(트리거↔보고 기준 정합, 마이그레이션 불필요) |
| P8 아키텍처 자동 검사 | ✅ 완료 | 버전 체크, 동점 해소, 누락 레이어 경고 |
| P9 품질/부채 관리 | ✅ 완료 | docFreshnessDays 파라미터화. 1.1.0: 자동 검사 승격 대기 큐 + 승격 루프 (체크리스트 §3.3) |
| P10 엔트로피 관리 | ✅ 컴패니언 커버 | doc-freshness.ts 감지 + 운영 사이클 문서화 + harness:check 자가진단 + **harness-cleanup 스킬(1.4.0)이 주간/격주/월간 루틴 실행** (--add-dir opt-in) |

---

## 2. 완료된 작업: TDD Subagent 파이프라인 (P6) — 2026-04-06

### 구현 내용

Coding Agent 그룹을 **TDD 중심의 Claude Code subagent 시스템**으로 구체화했다.

**추가된 템플릿:**
- `templates/agents/` — 7개 subagent 정의 (architect, test-engineer, implementer, reviewer, simplifier, debugger, security-reviewer)
- `templates/rules/session-routine.md` — TDD 오케스트레이션 플로우, 상태 머신, 에스컬레이션 규칙
- `templates/rules/coding-standards.md` — 아키텍처/네이밍 규칙 (CLAUDE.md에서 이관)

**SKILL.md 수정:**
- 섹션 5.10 (agents/ 생성 규칙) 추가
- 섹션 5.11 (.claude/rules/ 생성 규칙) 추가
- 섹션 5.1.1 (CLAUDE.md 생성 규칙) 업데이트 — Agent Dispatch 테이블, 코드 규칙을 rules/로 이관
- Phase 2 생성 순서 12 → 15 항목으로 확장
- Phase 3 검증에 agents/, .claude/rules/, 플레이스홀더 치환 검사 추가
- Phase 4 보고에 TDD 워크플로 안내 추가

**TDD 사이클 (Red → Green → Refactor):**
```
Architect (설계) → Test Engineer (Red) → Implementer (Green)
  → Reviewer (리뷰) → Simplifier (Refactor, 조건부)
  → Security Reviewer (보안, 조건부)
  → Debugger (에스컬레이션, on-demand)
```

**핵심 설계 결정:**
- Orchestrator는 subagent가 아님 — CLAUDE.md + .claude/rules/session-routine.md
- CLAUDE.md는 150줄 이내로 슬림화 (상세는 .claude/rules/에 위임)
- 에이전트 호출은 Claude Code의 Agent tool 사용
- 에스컬레이션: Implementer 3회 → Debugger 2회 → 사용자

---

## 3. 범위 밖으로 확정된 항목

### P10 엔트로피 관리 → 별도 스킬로 분리 (→ 1.4.0에서 구현 완료)

**결정 (2026-04-07)**: 하네스 셋업 스킬의 범위는 "초기 환경 구성"이다. 주기적 정리 루프는 운영 영역이므로 별도 cleanup 스킬로 분리한다.

**구현 (2026-06-11, 1.4.0)**: `companion-skills/harness-cleanup/`으로 구현 — "별도 스킬" 결정은 유지하되 저장소는 단일화 (harness-feedback과 동일 배포 모델). oh-my-claudecode ai-slop-cleaner 패턴(삭제 우선, scope 제한) 채용.

---

## 4. 참고: oh-my-claudecode 핵심 패턴

다음 세션에서 참고할 수 있도록 핵심 패턴을 정리한다.

### 디렉토리 구조

```
oh-my-claudecode/
├── CLAUDE.md                  # 프로젝트 "헌법" (에이전트 카탈로그, 품질 규칙, 운영 원칙)
├── .claude/settings.json      # 환경 설정
├── agents/                    # 19개 에이전트 정의 (executor, architect, verifier 등)
│   ├── executor.md            # 구현 전문 (최소 변경, 3회 실패 시 에스컬레이션)
│   ├── architect.md           # 읽기 전용, 아키텍처 분석/지침
│   └── ...
├── skills/                    # 36개 스킬 (autopilot, ralph, team 등)
│   ├── ralph/SKILL.md         # 검증/수정 루프 (Story 선택 → 구현 → 검증 → deslop)
│   ├── ai-slop-cleaner/       # 엔트로피 정리 (4유형, 삭제 우선)
│   └── cancel/                # 의존성 인식 정리 + resume
├── hooks/hooks.json           # 20개 훅 (11개 라이프사이클 이벤트)
└── .omc/                      # 상태 관리
    ├── state/                 # 실행 모드 추적
    ├── sessions/              # 세션 요약
    └── project-memory.json    # 크로스세션 규칙
```

### 핵심 패턴 요약

| 패턴 | 설명 | 우리 스킬 적용 가능성 |
|------|------|---------------------|
| **Rules 분리** | CLAUDE.md는 간결, 상세는 rules/로 | ✅ 바로 적용 |
| **3회 실패 에스컬레이션** | 반복 실패 시 접근 전환 | session-routine.md에 포함 가능 |
| **검증/수정 루프** (Ralph) | 구현→검증→실패시 수정→재검증 | session-routine.md에 포함 가능 |
| **삭제 우선 정리** (ai-slop-cleaner) | 추가보다 삭제 선호 | 향후 cleanup 스킬로 |
| **상태 영속성** (.omc/state/) | 세션 간 상태 보존 | 현재 claude-progress.txt로 커버 |
| **Hook 기반 자동화** | 라이프사이클 이벤트에 스크립트 연결 | 향후 확장 |
| **에이전트 전문화** | executor/architect/verifier 분리 | 현재 범위 밖 (단일 에이전트) |

### `.claude/rules/` 활용 방법 (Claude Code 공식)

```markdown
---
paths:
  - "src/features/**/*.ts"
---

# Feature Module Rules
- exports는 파일 끝에 배치
- barrel export는 index.ts에서만
```

- `paths` 없으면: 세션 시작 시 항상 로딩
- `paths` 있으면: 해당 경로 파일 접근 시 on-demand 로딩
- 형식: Markdown + YAML frontmatter
- `.claude/rules/` 하위 재귀 탐색

---

## 5. 향후 작업 (우선순위)

### 5.1 실전 적용 준비도 분석 결과 (2026-04-07)

Session 11에서 SKILL.md/템플릿/프리셋 전수 분석을 수행했다. **결론: 수정 없이 바로 실행 가능하지만, 7개 리스크/제한사항이 있다.**

- SKILL.md 100% 완성 (14개 섹션, TODO/FIXME 없음)
- 템플릿 17개 전부 존재 + 실제 내용 (스텁 아님)
- 플레이스홀더 21개 전부 소스→기본값 매핑 완료
- 프리셋 2개 (react-next, react-router-fsd) — 커버리지가 좁은 것이 주요 제한

상세: `.claude/plans/humble-dancing-pine.md`

### 5.2 우선순위 목록

~~**이슈 #12 증분 2b (TODO-95b)**: 완료 — 1.14.0. pre-push 게이트 구현(옵트인 e2e.prePush → .githooks/pre-push, @critical 게이팅, 수동 활성화, 골든 픽스처).~~

~~**이슈 #12 증분 3 (TODO-96)**: 완료 — 1.15.0. Playwright MCP 진단 배선(`e2e.mcp` 분리 옵트인, `{{MCP_DEBUG_PROTOCOL}}` 30→31, 공유 .mcp.json 비커밋 → debugger 지침+로컬 `claude mcp add`, harness-scaffold §5.19 + Phase 4 + U1 재감지, 골든 픽스처). integrations 규약 비사용(debugger 코어 SoT). 멀티모델 자문(codex·gemini) 반영.~~

~~**이슈 #12 증분 4 (TODO-97)**: 완료 — 1.17.0. E2E 모듈 마감. **A** §12.6.1 e2e managed 3파일 매핑 편입(deferral 제거) · **B** 프론트엔드 프리셋 3종 `e2e:{enabled:true}` 권장 기본(pre-seed, express 제외) · **C** U1 base-E2E 재감지 + pre-push cascade · **D** `templates/e2e/README.md`(managed·정적·8절). 결정 D1=pre-seed·D2=managed·D3=cascade·D4=단일. 설계 발견: §12.6은 업데이트 전용이라 README는 기존 e2e 하네스 소급 생성 안 함(§10.3 1.17.0 노트 정직 명시). 신규 플레이스홀더 0(31 불변)·마이그레이션 불필요. 설계: `docs/superpowers/specs/2026-06-16-e2e-incr4-design.md`, 계획: `docs/superpowers/plans/2026-06-16-e2e-incr4.md`.~~

**▶ 즉시 다음 후보** (이슈 #12 증분 4 종결 — E2E 모듈 1.11.0~1.17.0 완성, **이슈 #9/TODO-84 마찰 자동 기록은 1.18.0에서 종결·닫힘**). **1번(TODO-53)은 Session 43에서 완료** — E2E 옵트인 경로(프리셋 권장 기본·§4.2 질문·README 생성)가 실전 2회 주행으로 검증됨. **TODO-100(1.19.0)·TODO-85(1.20.0, 이슈 #6)까지 종결 — 열린 GitHub 이슈 0건, 미완료 구현 항목 0건.** 남은 것은 트리거 대기/보류(TODO-67·68·77·91)와 관찰 이월뿐. 남은 후보:

1. ~~**신규 셋업 경로 실전 테스트** (TODO-53)~~ — **완료 (Session 43)**: react-vite 신규 생성 경로 2회 실주행(Opus급·Sonnet 4.6 1M high) 둘 다 표준 가동, 결정적 게이트 model-robust 실증. **잔여(이월)**: 픽스처 매트릭스 확장(express-api/엣지케이스), superpowers **미설치** 경로(질문 생략+산출물 0건, TODO-73 잔여), harness-cleanup 첫 실행(CLEANUP_LOG 생성), Q2 미강제 강등 라이브.
2. **multi-model-consult 실사용 안정화** — 실전 자문 사용 + gemini 설치 시 양 CLI/합성 경로 검증. 안정화 후 integrations.multiModelConsult 연계 + "외부 패키지 통합 규약" 일반화 (선례 2개 확보)
3. **에이전트 템플릿 실전 조정** — TDD subagent 프롬프트 최적화 (실전 사용 피드백 기반)
4. **eslintAssist legacy JS 형식 전략** (TODO-67) — 폴백 발동률 관찰 후 결정
5. **harness-check 검사 항목 확장 검토** (TODO-68) — 체크리스트 §6 엔트로피 항목. harness-cleanup M1(문서-실구조 일치)과 역할 분담 주의: 스크립트=기계 검사, 스킬=판단 검사

---

## 6. 파일 위치 안내

```
~/.claude/skills/harness-setup/
├── SKILL.md                          # 분석 스킬 (Phase 1 + Stop hook 오케스트레이션)
├── harness-scaffold/
│   └── SKILL.md                      # 스캐폴딩 스킬 (심볼릭 링크 디스커버리, user-invocable: false)
├── install.sh                        # 심볼릭 링크 생성 스크립트
├── presets/
│   ├── react-next.json               # React+Next.js 프리셋
│   ├── react-router-fsd.json         # React Router+FSD 프리셋
│   ├── react-vite.json               # React+Vite SPA 프리셋
│   └── express-api.json              # Express API 프리셋
├── templates/
│   ├── structural-test-layer.ts      # 레이어 기반 구조 테스트
│   ├── structural-test-fsd.ts        # FSD 구조 테스트
│   ├── structural-test-domain.ts     # 도메인 기반 구조 테스트
│   ├── init.sh                       # 환경 초기화 스크립트
│   ├── doc-freshness.ts              # 문서 최신성 검사 스크립트
│   ├── harness-check.sh              # 하네스 자가진단 (체크리스트 §8)
│   ├── QUALITY_SCORE.md              # 품질 점수표
│   ├── TECH_DEBT.md                  # 기술 부채 문서 (+ 승격 대기 큐)
│   ├── HARNESS_FRICTION.md           # 마찰 로그
│   ├── agents/                       # TDD subagent 정의 (7개)
│   └── rules/                        # .claude/rules/ 템플릿 (3개)
├── test/                             # 스킬 자체 검증 (1.9.0)
│   ├── fixtures/                     # structural-test 골든 픽스처 (layer/fsd/domain, src-pass/src-fail)
│   ├── run-fixtures.sh               # 픽스처 러너 (템플릿 회귀 검증)
│   └── README.md
├── companion-skills/
│   ├── harness-feedback/             # 피드백 분석→Issue 스킬 (구현됨)
│   ├── harness-cleanup/              # 엔트로피 정리 스킬 (운영 사이클 실행 주체)
│   └── multi-model-consult/          # 멀티모델 합성 자문 (하네스 비의존 범용, install.sh 심링크)
├── references/
│   ├── harness-guide.md              # 이론적 기반 (P1-P10)
│   ├── harness-checklist.md          # 하네스 구성 체크리스트 (판정 기준)
│   ├── versioning-policy.md          # semver 버전 관리 정책
│   ├── model-selection-guide.md      # Opus vs Sonnet 모델 선택 가이드
│   ├── project-context.md            # 설계 결정 기록
│   └── upgrade-system-design.md      # 업그레이드 시스템 설계
└── .tracking/
    ├── TODO.md                       # 투두 상태 (01-44,52,55 완료)
    ├── CHANGELOG.md                  # 변경 이력
    └── HANDOFF.md                    # 이 파일
```
