# harness-setup 스킬 개선 TODO

> 마지막 업데이트: 2026-04-07
> 분석 기반: SKILL.md(~1300줄), presets/ 2개, references/ 3개, templates/ 17개

---

## Session 1: SKILL.md 사양 갭 메우기 (Critical)

### TODO-01: doc-freshness.ts 생성 규칙 추가
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `SKILL.md` — 새 섹션 5.7 추가 (5.6 이후)
- **문제**: doc-freshness.ts는 Phase 2에서 생성하지만, 무엇을 검사하고 어떻게 출력하는지 사양이 전혀 없음
- **해결**: 검사 대상(AGENTS.md, ARCHITECTURE.md, docs/ 하위), staleness 기준(14일), 출력 형식(파일별 상태), exit 동작(항상 0) 명시
- **참조**: `references/harness-guide.md` P10 섹션

### TODO-02: init.sh 생성 규칙 보강
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `SKILL.md` — 섹션 5.6 확장
- **문제**: "설치→실행→확인"만 명시, "확인"의 의미가 모호
- **해결**: lockfile 기반 패키지매니저 감지, devServer.readyCheck로 HTTP 200 확인, set -e, chmod +x 명시
- **참조**: `references/harness-guide.md` P5 섹션 (lines 564-592)

### TODO-03: QUALITY_SCORE.md 생성 규칙 추가
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `SKILL.md` — 새 섹션 5.8 추가
- **문제**: "품질 점수표 초기값"이라고만 기술, 구조/카테고리/형식 없음
- **해결**: 6개 카테고리(타입 안전성 20, 테스트 커버리지 20, 아키텍처 준수 20, 접근성 15, 성능 15, 문서 최신성 10) + 점수표 + known issues 섹션

### TODO-04: TECH_DEBT.md 생�� 규칙 추가
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `SKILL.md` — 새 섹션 5.9 추가
- **문제**: "기술 부채 빈 템플릿"이라고만 기술, 구조 없음
- **해결**: 4단계 심각도(긴급/높음/보통/낮음) 섹션 + 리팩터링 대상 테이블

### TODO-05: 기본값 테이블 추가
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `SKILL.md` — 새 섹션 4.4 (4.3 이후)
- **문제**: 사용자가 "몰라"라고 답할 때 적용할 기본값이 정의되지 않음 (lines 645, 660)
- **해결**: 프로필 항목별 기본값+근거 테이블, "기본값 사용 항목은 보고서에 명시" 규칙

### TODO-06: feature_list.json 모순 해결
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `SKILL.md` — 섹션 5.3 수정
- **문제**: line 377 "기존 코드는 passes: true" vs line 388 예시의 `passes: false` 충돌
- **해결**: "코드 존재+동작 확인 → true / 코드 존재+미확인 → false+notes '검증 필요' / 새 프로젝트 → 빈 배열"

### TODO-07: references/ 참조 지침 추가
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `SKILL.md` — 섹션 12 수정
- **문제**: references/가 실행 시 로드 안 됨이라고 명시, 하지만 structural-test.ts 구현 등 핵심 참조가 여기에만 존재
- **해결**: 스캐폴딩 시 어떤 파일의 어떤 섹션을 참조할지 구체적 지침 + "SKILL.md가 guide보다 우선" 규칙

---

## Session 2: 핵심 템플릿 파일 생성 (Important)

### TODO-08: structural-test-layer.ts 템플릿 생성
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `templates/structural-test-layer.ts` (신규)
- **문제**: templates/ 비어있음, harness-guide.md에만 구현 코드 존재
- **해결**: guide P8 코드 기반 파라미터화, {{LAYER_RULES}} 플레이스홀더, getFilesRecursive 포함, alias+상대경로 감���

### TODO-09: structural-test-fsd.ts 템플릿 생성
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `templates/structural-test-fsd.ts` (���규)
- **해결**: FSD 전용 — 상위 레이어 import, 동일 레이어 cross-import, public API 검증

### TODO-10: SKILL.md 5.4절에 템플릿 참조 규칙 추가
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `SKILL.md` — 섹션 5.4 수정
- **해결**: "templates/ 파일 기반으로 LAYER_RULES 치환하여 생성, 템플릿 없는 유형은 동적 생성"

---

## Session 3: 프리셋 & 스키마 정합성 (Important)

### TODO-11: validate 스크립트 충돌 해결
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `presets/react-next.json`, `presets/react-router-fsd.json`, `SKILL.md` 5.5절
- **문제**: 프리셋은 validate를 하드코딩, SKILL.md는 동적 조합 규정 — 충돌
- **해결**: 프리셋에서 validate 키 제거, SKILL.md의 동적 조합만 사용

### TODO-12: detection.optional 활용
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `SKILL.md` 8절 매칭 로직
- **문제**: 프리셋에 정의되어 있지만 매칭 로직에서 미사용 (데드 코드)
- **해결**: 4.5단계 추가 — 최종 후보 여러 개일 때 optional 매칭 수로 순위 결정

### TODO-13: 아키텍처 type 명칭 통일
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `SKILL.md` 2.4절
- **문제**: 프리셋 스키마는 "custom", SKILL.md는 "자유 구조" — 명칭 불일치
- **해결**: 분류 테이블에 영문 type 값 병기

### TODO-14: docs/ 하위 디렉토리 명시
- **상태**: [x] 완료 (2026-04-04)
- **파일**: `SKILL.md` 생성 순서 1번 (line 306)
- **문제**: "빈 폴더"라고만 기술, 어떤 폴더인지 불명
- **해결**: product-specs/, design-docs/, exec-plans/, references/ 명시

---

## Session 4: 품질 개선 (Nice-to-have)

### TODO-15: 실행 흐름 다이어그램에 Step 5 추가
- **파일**: `SKILL.md` lines 40-54
- **상태**: [x] 완료 (2026-04-04)

### TODO-16: 자동 수정 전략 테이블 추가
- **파일**: `SKILL.md` Phase 3 검증 결과 판정 이후
- **상태**: [x] 완료 (2026-04-04)

### TODO-17: import 감지 개선 (alias + 상대경로)
- **파일**: `SKILL.md` 2.2절, 5.4절
- **상태**: [x] 완료 (2026-04-04)

### TODO-18: Node.js 전용 scope 명시
- **파일**: `SKILL.md` 개요 (line 24 이후)
- **상태**: [x] 완료 (2026-04-04)

### TODO-19: SKILL.md ↔ harness-guide.md 우선순위 명시
- **파일**: `SKILL.md` 12절, `references/harness-guide.md` 서두
- **상태**: [x] 완료 (2026-04-04)

### TODO-20: harness-guide.md 예시에 "가상 프로젝트" 안내 추가
- **파일**: `references/harness-guide.md` 서두
- **상태**: [x] 완료 (2026-04-04) — TODO-19와 함께 처리

---

## Session 5: 코드 품질 + 스펙 보완 + 기능 강화 (2026-04-05~06)

> 전체 코드베이스 분석 후 20개 이슈 발견, 우선순위별 수정.

### Phase A: 버그 픽스

### TODO-23: 템플릿 정규식 버그 + re-export 감지 + CLAUDE.md 아키텍처 분기
- **상태**: [x] 완료 (2026-04-05)
- **파일**: `templates/structural-test-layer.ts`, `templates/structural-test-fsd.ts`, `SKILL.md`
- **문제**: `\w+`가 하이픈 포함 폴더명 매칭 불가, `export { } from` 미감지, CLAUDE.md 규칙이 아키텍처 타입 무시
- **해결**: `[\w-]+`로 수정, re-export 감지 추가, 아키텍처 유형별 코드 규칙 분기 테이블 추가

### Phase B: 스펙 보완

### TODO-24: feature_list.json passes 판정 기준 구체화
- **상태**: [x] 완료 (2026-04-05)
- **파일**: `SKILL.md` 5.3절
- **해결**: passes: true 조건 3가지 명시 (테스트 통과, 수동 확인, steps 수행)

### TODO-25: 소크라테스 문답 종료 조건 + 질문 우선순위
- **상태**: [x] 완료 (2026-04-05)
- **파일**: `SKILL.md` 4.1절
- **해결**: 5단계 우선순위 테이블 + 종료 조건 3가지 (프로필 완성/3라운드/사용자 요청)

### TODO-26: init.sh readyCheck 파싱 규칙 명시
- **상태**: [x] 완료 (2026-04-05)
- **파일**: `SKILL.md` 5.6절
- **해결**: stdout "200" 포함 판정, 30초 타임아웃 시 경고 후 계속 진행

### TODO-27: 프리셋 매칭 동점 해소 규칙
- **상태**: [x] 완료 (2026-04-05)
- **파일**: `SKILL.md` 3.3절
- **해결**: optional 수 → required 수 → 사용자 선택 3단계

### TODO-29: ARCHITECTURE.md 누락 레이어 경고
- **상태**: [x] 완료 (2026-04-05)
- **파일**: `SKILL.md` 5.2절
- **해결**: 의존 규칙에 참조되나 폴더 미존재 시 ⚠️ 표시 규칙

### TODO-30: scripts/ 디렉토리 생성 보장
- **상태**: [x] 완료 (2026-04-05)
- **파일**: `SKILL.md` 6절
- **해결**: Phase 3 검증에 `mkdir -p scripts/ docs/` 단계 추가

### Phase C: 기능 강화

### TODO-31: 프리셋 버전 체크
- **상태**: [x] 완료 (2026-04-05)
- **파일**: `SKILL.md`, `presets/react-next.json`
- **해결**: `detection.versionConstraints` 필드 + 매칭 3.5단계 + react-next에 `>=13.0.0`

### TODO-32: 다중 pathAlias 지원
- **상태**: [x] 완료 (2026-04-05)
- **파일**: `SKILL.md`, `templates/structural-test-layer.ts`, `templates/structural-test-fsd.ts`
- **해결**: pathAlias를 `string | string[]`로 확장, 템플릿에서 배열 → alternation regex

### TODO-33: doc-freshness 임계값 파라미터화
- **상태**: [x] 완료 (2026-04-05)
- **파일**: `SKILL.md`
- **해결**: `docFreshnessDays` 프리셋/프로필 필드 추���, 기본값 14일 유지

### TODO-34: 재스캔/재생성 플로우
- **상태**: [x] 완료 (2026-04-05)
- **파일**: `SKILL.md` 10절
- **해결**: Phase 1 중/Phase 4 후 분기 + 재생성 가능 항목 목록

### Phase D: 문서 보강

### TODO-35: 프리셋 가이드 + 역할 경계 재정립 + 섹션 재정렬
- **상태**: [x] 완료 (2026-04-05)
- **파일**: `SKILL.md`
- **해결**: 섹션 11(프리셋 가이드) 신설, 역할 분리 테이블에 source of truth, 섹션 번호 재정렬

---

## Session 6: 정합성 점검 수정 (2026-04-06)

> Phase A~D 수정 후 전체 정합성 감사(audit)를 실행하여 발견된 3건 수정.

### TODO-36: 섹션 5.1.5 → 5.1.1 번호 수정
- **상태**: [x] 완료 (2026-04-06)
- **파일**: `SKILL.md`
- **문제**: 5.1.1~5.1.4 없이 5.1.5만 존재하는 번호 체계 오류
- **해결**: `### 5.1.5 CLAUDE.md 생성 규칙` → `### 5.1.1 CLAUDE.md 생성 규칙`

### TODO-37: pathAlias 스키마 JSON 문법 오류 수정
- **상태**: [x] 완료 (2026-04-06)
- **파일**: `SKILL.md`
- **문제**: `"pathAlias": "@/" | ["@/", "~/"]` — JSON에서 `|` 유니온 불가
- **해결**: 코드블록 내 `"pathAlias": "@/"`, 코드블록 외부에 "string 또는 string[] 가능" 타입 설명 추가

### TODO-38: 프리셋에 docFreshnessDays 누락 추가
- **상태**: [x] 완료 (2026-04-06)
- **파일**: `presets/react-next.json`, `presets/react-router-fsd.json`
- **문제**: SKILL.md 스키마에 `docFreshnessDays` 정의했으나 실제 프리셋 파일에 없음
- **해결**: 두 프리셋에 `"docFreshnessDays": 14` 추가

---

## Session 7: 템플릿 완비 + 트래킹 정리 (2026-04-07)

> 미생성 템플릿 4개 추가, 트래킹 문서 현행화, P10 범위 확정.

### TODO-39: 트래킹 문서 현행화
- **상태**: [x] 완료 (2026-04-07)
- **파일**: `.tracking/HANDOFF.md`, `references/project-context.md`
- **문제**: HANDOFF 섹션 5가 이미 완료된 작업을 남은 작업으로 기술, P10이 "미완"으로 표시
- **해결**: P10을 "범위 밖"으로 확정, 섹션 5를 실제 향후 작업으로 업데이트, 파일 트리 현행화

### TODO-40: 미생성 템플릿 4개 추가
- **상태**: [x] 완료 (2026-04-07)
- **파일**: `templates/init.sh`, `templates/doc-freshness.ts`, `templates/QUALITY_SCORE.md`, `templates/TECH_DEBT.md`, `SKILL.md`
- **문제**: SKILL.md 5.6~5.9에 상세 생성 규칙이 있으나 대응하는 템플릿 파일이 없어 출력 일관성 부족
- **해결**: 4개 템플릿 생성, SKILL.md에 템플릿 참조 + 플레이스홀더 치환 규칙 추가, Phase 3 검증 6.11 범위 확장, 참고자료 테이블 업데이트

---

## Session 8: 피드백 수집 시스템 (2026-04-07)

> 하네스에 마찰 자동 감지 + 로깅 시스템 추가, 컴패니언 스킬 배치 구조 도입.

### TODO-41: 마찰 로그 템플릿 + session-routine 로깅 지시
- **상태**: [x] 완료 (2026-04-07)
- **파일**: `templates/HARNESS_FRICTION.md`, `templates/rules/session-routine.md`, `SKILL.md`
- **문제**: 하네스 사용 중 발생하는 마찰(에스컬레이션, 검증 실패 등)을 수집하는 메커니즘이 없음
- **해결**: HARNESS_FRICTION.md 템플릿 생성, session-routine에 6개 마찰 이벤트 로깅 지시 추가, SKILL.md에 5.12절/생성순서/검증/보고/참조테이블 반영

### TODO-42: 컴패니언 스킬 배치 구조
- **상태**: [x] 완료 (2026-04-07)
- **파일**: `companion-skills/harness-feedback/SKILL.md`, `SKILL.md`
- **문제**: 피드백 분석→Issue 등 운용 스킬을 배치할 구조가 없음
- **해결**: companion-skills/ 디렉토리 도입, harness-feedback 스킬 스텁 생성, Phase 4 보고에 운용 스킬 안내 추가, 섹션 12 확장 포인트에 반영

---

## Session 9: 업그레이드 시스템 설계 (2026-04-07)

> 이미 셋업된 프로젝트에 스킬 업데이트를 반영하는 업그레이드 메커니즘 설계.

### TODO-43: 업그레이드 시스템 설계 문서 작성
- **상태**: [x] 완료 (2026-04-07)
- **파일**: `references/upgrade-system-design.md` (신규)
- **문제**: 스킬이 발전해도 기존 프로젝트에 변경사항을 반영할 방법이 없음
- **해결**: A(마이그레이션 레지스트리) + B(파일 카테고리 분리) 조합 설계. `.harness-manifest.json`으로 버전 추적, managed/custom/data 3단계 분류, Phase U1~U5 업그레이드 플로우, 부트스트랩 마이그레이션 (v0→v3.3)

### TODO-44: 업그레이드 시스템 SKILL.md 구현
- **상태**: [x] 완료 (2026-04-07)
- **파일**: `SKILL.md` — 섹션 2, 3, 5, 6, 7, 12, 13 수정 + 새 섹션 14 추가
- **의존**: TODO-43 완료 (설계 문서 기반 구현)
- **해결**: frontmatter 업데이트, § 2 업그레이드 트리거, § 3 Step 0 모드 판별, § 5.13 manifest 생성 규칙, § 5 생성순서 18번 추가, § 6.12 manifest 검증, § 7 보고에 manifest/커밋 안내, § 12 구현 완료 표시, § 13 참조 추가, § 14 업그레이드 시스템 전체(14.1~14.6)
