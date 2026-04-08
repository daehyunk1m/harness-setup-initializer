# harness-setup 스킬 변경 이력

> 이 파일은 개선 작업의 변경 사항을 추적한다.
> 각 TODO 완료 시 변경 내용을 여기에 기록한다.

---

## [미출시] — 진행 중 (2026-04-04~)

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
