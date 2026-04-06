# harness-setup 스킬 변경 이력

> 이 파일은 개선 작업의 변경 사항을 추적한다.
> 각 TODO 완료 시 변경 내용을 여기에 기록한다.

---

## [미출시] — 진행 중 (2026-04-04~)

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
