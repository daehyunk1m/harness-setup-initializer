# harness-setup 스킬 개선 TODO

> 마지막 업데이트: 2026-04-08
> 분석 기반: SKILL.md + harness-scaffold/SKILL.md (2-스킬 분리), presets/ 2개, references/ 3개, templates/ 17개

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

---

## Session 11: 실전 적용 준비도 분석 — 리스크/제한사항 정리 (2026-04-07)

> SKILL.md, 템플릿, 프리셋의 전수 분석 결과 발견된 향후 개선 항목. 실전 테스트 전 준비도 평가에서 도출.

### TODO-45: react-router-fsd 프리셋 versionConstraints 추가
- **상태**: [x] 완료 (2026-06-11, 1.3.0)
- **파일**: `presets/react-router-fsd.json`
- **문제**: `react-next.json`에는 `"next >= 13.0.0"` versionConstraints가 있지만, react-router-fsd에는 없음. React Router v6 이하에서도 프리셋이 매칭되어 v7 전용 패턴(loader/action)이 잘못 적용될 수 있음
- **해결**: `"versionConstraints": { "react-router": ">=7.0.0" }` 추가

### TODO-46: domain-based / custom structural-test 동적 생성 알고리즘 구체화
- **상태**: [x] 완료 (2026-06-11, 1.3.0)
- **파일**: `templates/structural-test-domain.ts` (신규), `harness-scaffold/SKILL.md` § 5.4, `SKILL.md` § 12.6.1
- **문제**: layer-based(`structural-test-layer.ts`)와 FSD(`structural-test-fsd.ts`)는 전용 템플릿이 있지만, domain-based와 custom은 "동적 생성"이라고만 명시되어 있어 구체적 생성 로직이 불명확
- **해결**: domain-based는 전용 템플릿 신설 — 도메인 간 직접 import 금지 + 공유 모듈→도메인 역방향 금지, 도메인 목록은 실행 시점 발견(하드코딩 없음), `{{SHARED_DIRS}}` 플레이스홀더 + 프로필 `sharedDirs` 필드. 템플릿화로 § 12.6 자동 감지 대상에 편입. custom은 4단계 동적 생성 알고리즘 명문화 (layers.rules 재사용 → extraArchitectureRules 기계화 → 주석 나열 → 최소 스크립트 폴백, 자동 감지 제외). 픽스처 기능 테스트 통과 (위반 감지 exit 1 / 통과 exit 0)

### TODO-47: feature_list.json 기존 프로젝트 추론 알고리즘 구체화
- **상태**: [x] 완료 (2026-06-11, 1.3.0)
- **파일**: `harness-scaffold/SKILL.md` § 5.3
- **문제**: "기존 프로젝트는 소스 코드 분석하여 추론"이라고만 되어 있으나 구체적 추론 알고리즘이 없음. 빈 배열 `[]`로 생성될 가능성 높음
- **해결**: 3단계 추론 정책 명문화 — ① 라우트 기반 (Next.js app/pages, React Router 설정, Express 라우트 등록) ② 기능 모듈 기반 (features/services/controllers) ③ 빈 배열 폴백 + 보고 안내. 상한 15개 + 초과분 보고 명시(침묵 누락 금지), priority 기준, 셋업 직후 사용자 검토 안내

### TODO-48: 추가 프리셋 — react-vite.json
- **상태**: [x] 완료 (2026-06-11, 1.3.0)
- **파일**: `presets/react-vite.json` (신규), `SKILL.md` § 6 (detection.exclude 필드)
- **문제**: Vite + React 조합이 프리셋 없이 전부 문답 폴백. 의존성 규칙이 "규칙 없음"으로 생성됨
- **해결**: layer-based 7레이어 (react-next에서 app 제외), devServer 5173. required ["react","vite"]가 범용 패키지라서 **detection.exclude 필드를 프리셋 스키마에 신설** — next/react-router/@remix-run 존재 시 후보 제외 (오매칭 방지)

### TODO-49: 추가 프리셋 — express-api.json
- **상태**: [x] 완료 (2026-06-11, 1.3.0)
- **파일**: `presets/express-api.json` (신규), `harness-scaffold/SKILL.md` § 5.6 (readyCheck 정규화)
- **문제**: 백엔드 API 프로젝트는 프론트엔드 중심 질문 풀(컴포넌트, 라우팅 등)이 적합하지 않음. 프리셋 없으면 소크라테스 문답에서 불필요한 질문이 나올 수 있음
- **해결**: layer-based 8레이어 (types→config→lib→models→services→middlewares→controllers→routes), exclude ["next","react"]. API 루트가 404일 수 있어 readyCheck를 연결 성공 정규화 형태(`curl ... && echo 200 || echo 000`)로 작성 — § 5.6 파싱 규칙에 허용 형태로 명문화. testFramework: vitest + supertest

### TODO-50: 컴패니언 스킬 harness-feedback 구현
- **상태**: [x] 완료 (Session 14, 2026-04-09 — 상태 누락을 2026-06-11에 정정)
- **파일**: `companion-skills/harness-feedback/SKILL.md`
- **문제**: Phase 4 보고에서 피드백 스킬 안내가 나오지만 실제로는 스텁이라 동작하지 않음
- **해결**: Session 14에서 실제 구현 완료 (159줄 — 마찰 로그 파싱 → 환경 수집 → 패턴 분석 → Issue 초안 → 확인 → gh issue create). CHANGELOG v5.2 "이슈 보고 프로세스" 항목 참조. 이 TODO의 체크 표시가 누락되어 있었음

### TODO-51: 실전 테스트 결과 기록 체계
- **상태**: [x] 완료 (2026-06-11 — TODO-66 선례로 프로세스 확립)
- **파일**: `.tracking/TODO.md` (이 프로세스 정의), `.tracking/HANDOFF.md` (관찰 포인트 사전 정의)
- **문제**: 실전 테스트에서 발견되는 문제를 체계적으로 기록하고 개선에 반영하는 프로세스가 없음
- **해결**: TODO-66에서 확립한 패턴을 표준 프로세스로 확정 —
  1. **사전**: 테스트용 TODO에 관찰 포인트를 표로 정의 (HANDOFF 우선순위 목록에도 반영)
  2. **기록**: 테스트 완료 시 해당 TODO에 "결과" 섹션을 추가 — 관찰 포인트별 ✅/⚠️/🐛 판정 + 근거
  3. **승격**: 발견된 스킬 갭(🐛)은 즉시 새 TODO로 승격하고 수정 버전을 명시, 미검증 항목(⚠️)은 새 TODO로 이월
  4. 대상 프로젝트의 마찰 로그(HARNESS_FRICTION.md)가 1차 수집 채널, TODO 결과 기록이 스킬 저장소의 영구 기록

---

## Session 12: 2-스킬 분리 — GitHub Issue #1 해결 (2026-04-08)

> SKILL.md를 분석 스킬(SKILL.md)과 스캐폴딩 스킬(SKILL-SCAFFOLD.md)로 분리.
> `context: fork` + 멀티턴 Q&A 비호환 문제 해결.

### TODO-52: SKILL.md → 2-스킬 분리 (Issue #1)
- **상태**: [x] 완료 (2026-04-08)
- **파일**: `SKILL.md`, `SKILL-SCAFFOLD.md` (신규), `CLAUDE.md`
- **문제**: `context: fork`는 서브에이전트로 분리 실행하므로 멀티턴 Q&A(소크라테스 문답)가 불가. Phase 1(분석+문답)과 Phase 2~4(스캐폴딩+검증+보고)가 같은 스킬 안에서 충돌
- **해결**: 2-스킬 분리
  - `SKILL.md` (harness-setup): Phase 1 분석 + Q&A → `.harness-profile.json` 출력. `context: fork` 제거, `model: sonnet` 제거
  - `SKILL-SCAFFOLD.md` (harness-scaffold): `.harness-profile.json` 읽기 → Phase 2~4 스캐폴딩 + 검증 + 보고. `context: fork` + `model: sonnet` 유지
  - `.harness-profile.json`이 두 스킬 간 계약(contract) 역할
  - `CLAUDE.md` 파일 맵에 SKILL-SCAFFOLD.md 추가, 개발 규칙/테스트/원칙 업데이트

### TODO-53: 2-스킬 플로우 실전 테스트 (신규 셋업 경로)
- **상태**: [ ] 미완료
- **파일**: 실제 프로젝트에서 테스트
- **문제**: 분리된 2-스킬 플로우의 신규 셋업 경로가 실전에서 정상 동작하는지 검증 필요 (업그레이드 경로는 TODO-66/70/73에서 검증 완료)
- **해결**: `/harness-setup` → `.harness-profile.json` 생성 확인 → `/harness-scaffold` → 19개 파일 생성 확인. 특히 프로필 JSON 스키마 정합성, scaffold 스킬의 프로필 읽기, 누락 필드 기본값 처리 검증. 잔여 관찰 포인트: 신규 프리셋 매칭(exclude), eslintAssist 마커 블록, feature_list 라우트 추론, harness-cleanup 첫 실행
- **픽스처 매트릭스 확장** (2026-06-12 멀티모델 자문 권고 병합): React SPA 1종 검증에서 다양화 — 후보: 빈 TS 패키지, Next.js, Express 백엔드, pnpm workspace 모노레포, ESLint 없는 프로젝트, CRLF 줄바꿈, 손상된 package.json. 전부를 한 번에 하지 말고 신규 셋업 테스트 1~2종부터

### TODO-54: .harness-profile.json 스키마 문서화
- **상태**: [x] 완료 (2026-06-11)
- **파일**: `SKILL.md` § 5, `harness-scaffold/SKILL.md` § 4
- **문제**: 두 스킬 간 계약인 `.harness-profile.json`의 정확한 스키마(필수/선택 필드, 타입, 기본값)가 양쪽 스킬에서 일관되게 문서화되어 있는지 확인 필요
- **해결**: 양쪽에 동일 텍스트로 스키마 문서화 (필드 규칙/필드 참조 규칙 테이블 포함). 1.1.0~1.3.0 릴리스마다 JSON 블록 diff 기계 검증(python difflib)을 릴리스 절차로 수행하여 동일성 확인 — 3회 연속 IDENTICAL. 선택 필드(eslintAssist, sharedDirs)의 생략 시 동작도 양쪽에 명시

---

## Session 16: Issue #2, #3 해결 (2026-04-09)

### TODO-55: scaffold 디스커버리 실패 해결 (Issue #3)
- **상태**: [x] 완료 (2026-04-09)
- **파일**: `harness-scaffold/SKILL.md`, `install.sh`, `SKILL.md`, `CLAUDE.md`, `README.md`, `.tracking/HANDOFF.md`, `references/project-context.md`
- **문제**: `.claude/skills/harness-scaffold/`가 `--add-dir`로 추가한 디렉토리에서 자동 디스커버리되지 않아 `Skill(skill: "harness-scaffold")`가 `Unknown skill` 에러 발생
- **해결**: scaffold를 리포 루트 `harness-scaffold/`로 이동 + `install.sh` 생성하여 `~/.claude/skills/harness-scaffold` 심볼릭 링크 자동 생성. 설치: `git clone ... && ./install.sh`

### TODO-56: Issue #2 닫기
- **상태**: [x] 완료 (2026-04-09)
- **문제**: Session 15에서 `allowed-tools` 추가로 이미 수정되었지만 이슈가 열려있음
- **해결**: 이슈 닫기 (커밋 53b23a0 참조)

---

## Session 17: Issue #5 해결 — Plan 모드 TDD 우회 (2026-04-10)

### TODO-57: Plan 모드 진입 시 TDD subagent 파이프라인 우회 해결 (Issue #5)
- **상태**: [x] 완료 (2026-04-10)
- **파일**: `templates/rules/session-routine.md`, `harness-scaffold/SKILL.md`, `templates/rules/coding-standards.md`
- **문제**: `/plan` 모드로 기능 구현 시 Plan 모드 시스템 프롬프트가 하네스의 TDD 파이프라인보다 우선되어, Plan 승인 후 TDD 사이클(Red → Green → Refactor) 없이 직접 코딩 진행. 테스트 미작성, feature_list.json/claude-progress.txt 미갱신
- **해결**: Bridge 패턴 — Plan 모드를 PRE-RED(Architect) 대체로 취급. session-routine.md에 "Plan 모드 통합" 섹션 + PRE-RED 바이패스 규칙 + TDD STATE plan_ref 확장. CLAUDE.md 생성 템플릿과 coding-standards.md에 금지 사항 추가

---

## Session 18: 업그레이드 자동 감지 메커니즘 (2026-04-11)

> 업그레이드 시 "실질적 변경 없이 버전 레이블만 변경" 문제 해결.

### TODO-58: managed 파일 템플릿 자동 변경 감지 (§ 12.6)
- **상태**: [x] 완료 (2026-04-11)
- **파일**: `SKILL.md`, `harness-scaffold/SKILL.md`, `references/upgrade-system-design.md`, `references/versioning-policy.md`
- **문제**: 업그레이드 시스템이 순수 마이그레이션 주도(migration-driven)로 설계되어, 마이그레이션 레지스트리가 비어있으면 템플릿이 아무리 변경되어도 "변경 없음"으로 판정. 3가지 근본 원인: (1) 빈 마이그레이션 레지스트리, (2) templateHash가 사용자 수정만 감지하고 템플릿 변경은 감지 불가, (3) managed 파일의 재생성을 마이그레이션에 의존하는 아키텍처 불일치
- **해결**: 
  - § 12.6 "managed 파일 자동 변경 감지" 신설 — 소스 템플릿을 manifest.profile로 재렌더링한 해시(expectedHash)와 manifest.templateHash를 비교하여 템플릿 변경 자동 감지
  - 4-상태 판정 매트릭스: 템플릿 변경 여부 × 사용자 수정 여부 → 스킵/자동 덮어쓰기/선택
  - 역할 분리: managed 파일 = 자동 감지 전담, custom/new/remove/profile/data = 마이그레이션 전담
  - Phase U1 흐름 수정 (2-상태 → 4-상태), Phase U2 테이블 예시 갱신
  - fileActions 스키마에 `source` 필드 추가 (auto-detect/migration/category)
  - 파일-템플릿 매핑 테이블 (13개 managed 파일 ↔ 소스 템플릿)
  - harness-scaffold/SKILL.md Phase U3/U5/마이그레이션 안내 동기화
  - upgrade-system-design.md § 2.3, § 3.3 동기화
  - versioning-policy.md PATCH 트리거 테이블 보완

---

## Session 20: 하네스 구성 체크리스트 기반 검토·개선 — 1.1.0 (2026-06-10)

> 사용자 제공 "하네스 구성 체크리스트"(Anthropic+OpenAI 통합 판정 기준)와 스킬을 전수 대조하여 갭 8건 수정.

### TODO-59: 체크리스트 기준 문서 편입
- **상태**: [x] 완료 (2026-06-10)
- **파일**: `references/harness-checklist.md` (신규), `SKILL.md` § 11, `harness-scaffold/SKILL.md` § 6/§ 7/§ 11, `CLAUDE.md`
- **문제**: 하네스가 "제대로 돌아간다"의 판정 기준이 여러 문서에 산점되어 있고 기계 판정 불가
- **해결**: 체크리스트 원문을 references/에 편입, Phase 3 검증·Phase 4 단계 판정·harness-check.sh가 이 문서를 기준으로 참조

### TODO-60: harness:check 자가진단 스크립트 (체크리스트 §8)
- **상태**: [x] 완료 (2026-06-10)
- **파일**: `templates/harness-check.sh` (신규), `harness-scaffold/SKILL.md` § 5.5/§ 5.14(신설)/§ 6.13/§ 7, `SKILL.md` § 12.2/§ 12.6.1
- **문제**: 스캐폴딩 직후 Phase 3 검증만 있고, 사용자가 이후 반복 실행할 자가진단 수단이 없음
- **해결**: bash 자가진단 스크립트 (진단 대상인 tsx/node_modules에 비의존). 검사 7항목 — 구조(①②③, 실패 시 exit 1) / 품질(④⑤, exit 전파) / 경고(⑥⑦). 새 플레이스홀더 3종({{LINT_ARCH_COMMAND}}, {{DOC_CHECK_COMMAND}}, {{PATH_ALIAS_LIST}}). 전체 통과 시 "표준 하네스 가동" 판정

### TODO-61: 명령어 SoT를 AGENTS.md로 이동 (체크리스트 §1.2)
- **상태**: [x] 완료 (2026-06-10)
- **파일**: `harness-scaffold/SKILL.md` § 5.1/§ 5.1.1/§ 5.11.4, § 10.3 (M-1.0.0-to-1.1.0)
- **문제**: 명령어 SoT가 CLAUDE.md여서 범용 에이전트(Codex 등)가 테스트/개발 서버 명령을 알 수 없음
- **해결**: AGENTS.md에 "## 명령어" 섹션 신설(SoT), CLAUDE.md는 @AGENTS.md import로 참조. 역할 분리 서술 3곳 동기 수정. AGENTS.md 주요 규칙에 feature_list 보호 + passes 검증 필수 2종 명시 (§2.1)

### TODO-62: ESLint 보조 규칙 Q&A 옵트인 (체크리스트 §3.2)
- **상태**: [x] 완료 (2026-06-10)
- **파일**: `SKILL.md` § 4(Step 1.4, § 4.2~4.4, Step 5)/§ 5, `harness-scaffold/SKILL.md` § 4/§ 5.15(신설)/§ 6.14/§ 8
- **문제**: ESLint 보조 규칙(no-restricted-imports, max-lines)·tsconfig paths가 미커버. 기존 설정 수정은 원칙과 충돌
- **해결**: 프로필 선택 필드 `eslintAssist` + ESLint 설정 감지 시에만 옵트인 질문. 마커 블록 외과 수정 + 멱등 + 권고 스니펫 폴백. tsconfig는 수정하지 않고 harness-check ⑦이 검사만

### TODO-63: 승격 루프 (체크리스트 §3.3)
- **상태**: [x] 완료 (2026-06-10)
- **파일**: `templates/TECH_DEBT.md`, `templates/agents/reviewer.md`, `templates/rules/session-routine.md`, `templates/rules/coding-standards.md`
- **문제**: "리뷰 2회 반복 지적 → 자동 검사 승격" 절차와 승격 대기 큐가 생성 하네스에 없음
- **해결**: TECH_DEBT.md에 "자동 검사 승격 대기 큐" 섹션, reviewer.md에 반복 지적 감지 + 승격 후보 출력(read-only 유지), session-routine.md Phase 4에 큐 기록·횟수 2 이상 시 승격 제안, coding-standards.md에 원칙 1줄

### TODO-64: 검증 레벨 4단계 + steps↔E2E 매핑 (체크리스트 §4.2)
- **상태**: [x] 완료 (2026-06-10)
- **파일**: `templates/rules/coding-standards.md`, `harness-scaffold/SKILL.md` § 5.3, `templates/agents/test-engineer.md`
- **문제**: L1 정적/L2 유닛/L3 통합/L4 E2E 분류와 steps↔E2E 1:1 매핑 규칙이 미문서화
- **해결**: coding-standards.md에 검증 레벨 테이블, feature_list 생성 규칙과 test-engineer.md에 1:1 매핑 규칙 반영

### TODO-65: 세션 루틴 보강 + 운영 사이클 (체크리스트 §5.1/§5.3/§6.3)
- **상태**: [x] 완료 (2026-06-10)
- **파일**: `templates/rules/session-routine.md`, `harness-scaffold/SKILL.md` § 5.1.1, `templates/QUALITY_SCORE.md`, `templates/TECH_DEBT.md`
- **문제**: "기존 버그 우선"/"시작 5분 내" 규칙과 운영 사이클(일/주/격주/월)이 생성 하네스에 없음
- **해결**: session-routine.md에 5분 목표 + 회귀 우선 규칙, CLAUDE.md에 운영 사이클 테이블 + 금지 사항 회귀 규칙, QUALITY_SCORE/TECH_DEBT 헤더에 갱신 주기 (실행은 사용자 몫 — 체크리스트 §7)

### TODO-66: 1.1.0 신기능 실전 테스트
- **상태**: [x] 완료 (2026-06-10, haja-web-fe 업그레이드 경로)
- **파일**: ~/Desktop/side-project/haja-web-fe (1.0.0 → 1.1.0 업그레이드)
- **문제**: 신규 메커니즘의 실전 검증 필요
- **결과**:
  - ✅ M-1.0.0-to-1.1.0 + managed 자동 감지(4개 템플릿) 사양대로 적용. manifest 1.1.0, 22개 파일 추적, 플레이스홀더 잔존 0
  - ✅ [custom] AGENTS.md 명령어 SoT + 필수 규칙 2종 (60줄 ≤ 100), CLAUDE.md 명령어 제거 + 운영 사이클 + 회귀 규칙, [data] TECH_DEBT 큐·QUALITY_SCORE 헤더
  - ✅ harness:check 7항목 + 단계 판정 동작 — 구조 통과/품질 2건 실패를 정확히 구분하여 "MVH 가동" 판정 (품질 실패는 haja 프로젝트 문제: 레이어 위반 1건, 잔존 .js 테스트 1건)
  - ✅ eslintAssist는 업그레이드에서 질문되지 않음 (설계 의도). eslintAssist 옵트인/마커 블록은 신규 셋업 경로 테스트로 이월 (TODO-53)
  - ⚠️ 멱등성(재실행 시 변경 0건)은 미검증 → TODO-70
  - 🐛 스킬 갭 발견: watch 기본 test 명령이 validate에 조합되어 53분 영구 대기 → TODO-69 (1.2.0에서 수정)

### TODO-67: eslintAssist legacy JS 형식 전략
- **상태**: [ ] 미완료
- **파일**: `harness-scaffold/SKILL.md` § 5.15
- **문제**: `.eslintrc.js` 등 JS 형식 legacy 설정은 현재 일괄 폴백 처리 — 수정 전략 부재
- **해결**: 실전 폴백 발동률 관찰 후, 필요하면 JS legacy 형식의 안전한 삽입 전략 설계 (또는 폴백 유지 확정)

### TODO-68: harness-check 검사 항목 확장 검토
- **상태**: [ ] 미완료
- **파일**: `templates/harness-check.sh`
- **문제**: 현재 7항목은 체크리스트 §8(빠른 자가진단) 범위. §6 엔트로피 항목(문서-실구조 일치, passes 재검증)은 미포함
- **해결**: 운영 경험 후 확장 여부 결정 — AGENTS.md 경로 실존 검사, ARCHITECTURE.md 폴더 일치 검사 등 후보

### TODO-69: 비대화형 검증 명령 보장 — watch 모드 가드 (1.2.0)
- **상태**: [x] 완료 (2026-06-10)
- **파일**: `SKILL.md` Step 1.2/§ 4.4/§ 5 필드 규칙, `harness-scaffold/SKILL.md` § 4/§ 5.5/§ 10.3
- **문제**: `"test": "vitest"`(watch 기본)를 validate에 그대로 조합 → harness:check와 에이전트 검증 루프(implementer/debugger/simplifier)가 비대화형 환경에서 영구 대기. 실전 테스트에서 53분 멈춤으로 발견 (마찰 로그 경유)
- **해결**: ① 분석 단계에서 watch 기본 러너 감지 → 프로필 scripts.test를 `npm run test:run`으로 기록 ② scaffold가 조건부 `test:run` 키 추가 (기존 test 키 비수정) ③ "validate 구성 명령은 모두 비대화형" 조합 규칙 ④ M-1.1.0-to-1.2.0으로 기존 하네스의 validate 재조합 + profile 갱신

### TODO-70: 업그레이드 멱등성 실전 재검증
- **상태**: [x] 완료 (2026-06-11, haja-web-fe 1.1.0 → 1.2.0 업그레이드)
- **파일**: ~/Desktop/side-project/haja-web-fe
- **문제**: TODO-66에서 멱등성(업그레이드 직후 재실행 → 변경 0건, 중복 섹션 없음)이 검증되지 않음
- **결과**: 사용자가 haja에서 1.2.0 업그레이드 + 잔여 작업 수행 완료. 스킬 저장소 세션에서 최종 상태 검증 —
  - ✅ manifest 1.2.0 (upgradeInProgress: false), files 22개
  - ✅ `test:run: vitest run` 추가, validate가 `yarn test:run` 사용, profile.scripts.test 갱신 (M-1.1.0-to-1.2.0 조건부 가드 동작)
  - ✅ 중복 섹션 없음 — AGENTS.md "## 명령어" 1개, CLAUDE.md "## 운영 사이클" 1개, TECH_DEBT 승격 큐 1개
  - ✅ AGENTS.md 60줄 유지

---

## Session 23: harness-cleanup 컴패니언 스킬 — 1.4.0 (2026-06-11)

### TODO-71: harness-cleanup 컴패니언 스킬 구현
- **상태**: [x] 완료 (2026-06-11, 1.4.0)
- **파일**: `companion-skills/harness-cleanup/SKILL.md` (신규), `harness-scaffold/SKILL.md` § 5.1.1/§ 7/§ 10.3, `CLAUDE.md`, `references/project-context.md`
- **문제**: 체크리스트 § 6.3 운영 사이클(주간/격주/월간)의 실행 주체가 없음 — P10 엔트로피 관리가 "범위 밖"으로만 분류되어 문서화(운영 사이클 테이블)와 감지(doc-freshness)만 있고 실행 루프가 부재
- **해결**: harness-feedback과 동일한 배포 모델(--add-dir opt-in)의 컴패니언 스킬 구현
  - 루틴: 주간 W1~W4 (doc:check / QUALITY_SCORE 재측정 — 카테고리별 측정 방법 명세 / 코드 엔트로피 스캔 — 잔존 산출물·300줄 초과·금지 패턴·미사용 의존성 / harness:check) · 격주 B1~B2 (TECH_DEBT 검토 / 승격 큐 횟수 ≥ 2 승격 제안) · 월간 M1~M3 (문서-실구조 일치 / passes 재검증 — 회귀 시 false 되돌림 제안 + TDD 위임 / 종합 판정)
  - 루틴 판별: docs/CLEANUP_LOG.md(스킬이 생성·행 추가) 경과 시간 기반 자동 + 사용자 명시 우선
  - 원칙: 삭제 우선, 모든 적용은 승인 후, scope 제한(소스 동작 변경 금지 — TECH_DEBT/feature_list 항목화로 TDD 사이클 위임), 기록 보존, 적용 후 validate 확인
  - scaffold 연계: Phase 4 운용 스킬 안내, CLAUDE.md 운영 사이클 안내 1줄, M-1.3.0-to-1.4.0 ([custom] 멱등 추가)

---

## Session 24: harness-cleanup 첫 실전 실행 기록 (2026-06-12)

### TODO-72: harness-cleanup 첫 실전 실행 (haja-web-fe)
- **상태**: [x] 완료 (2026-06-12, 기록 전용 — 스킬 변경 없음)
- **파일**: ~/Desktop/side-project/haja-web-fe (하네스 1.2.0)
- **결과** (TODO-51 기록 프로세스):
  - ✅ §1~2: manifest 확인 → CLEANUP_LOG 부재 → 첫 실행 판별 → W+B 수행, M 제외 (사양 그대로)
  - ✅ §3 주간: doc:check(ARCHITECTURE 63일 stale 감지) / QUALITY_SCORE 첫 측정 74/100 (측정 방법 준수 — any 0건→19, lint:arch 0건→20, 접근성 5, 커버리지 9) / 엔트로피 스캔 — 발견 11건 (버그 1, 실험 코드 노출 1, 문서 부식 1, 죽은 디렉토리 1, console.log 6곳, 미사용 의존성 5종, ESLint 경고 4, 접근성, 크기 위반 2, .d.ts 비표준, stale TODO) / harness:check "표준 하네스 가동"
  - ✅ §4 격주: TECH_DEBT 8건 등록 + **승격 큐 첫 가동** (no-console 횟수 1 — 리뷰에서 재지적 시 승격 제안 발동 예정)
  - ✅ §6 원칙 준수: 적용 5건 모두 문서·데이터·빈 디렉토리만 (소스 비수정 — 누수/실험 코드는 TECH_DEBT로 TDD 위임), 적용 후 validate+doc:check 재확인 그린
  - ✅ §7: CLEANUP_LOG 생성, 커밋 제안만 (자동 커밋 없음)
  - 스킬 갭 발견 없음. W3 목록 밖의 버그 발견(모달 리스너 누수)도 scope 제한을 지키며 TECH_DEBT로 처리 — 사양 변경 불필요로 판단
  - 다음 관찰 기회: 2회차 실행에서 CLEANUP_LOG 기반 루틴 판별(경과 시간), 승격 큐 횟수 누적 → 승격 제안 발동

---

## Session 25: superpowers 옵트인 통합 — 1.5.0 (2026-06-12)

### TODO-73: superpowers 옵트인 통합 (PRD 구체화 + M1~M3 구현)
- **상태**: [x] 완료 (2026-06-12, 1.5.0 — 옵트인 E2E 실전 검증까지 종결)
- **파일**: `.tracking/prd-superpowers-integration.md` (Confirmed→Implemented), `references/integrations/superpowers-mapping.md` (신규), `SKILL.md` Step 1.6/§ 4.2~4.4/§ 5/§ 12.3, `harness-scaffold/SKILL.md` § 4/§ 5.1/§ 5.11.3/§ 5.16(신설)/§ 5.13/§ 6.15/§ 7, `templates/rules/session-routine.md`
- **PRD 구체화**: 미결정 이슈 6건 전부 해소 (감지=installed_plugins.json `superpowers@*` 키 + skills 폴백 / 버전=plugin manifest / 매핑 위치=references/integrations/ / 스킬명 영어 / 삭제 시 안내문 잔류 / 규약 일반화는 2번째 통합 때). 실물 검증: v5.1.0, 스킬 14종 전수 — 초안의 스킬명 3건 부정확 정정. F2.2 버전 매트릭스 폐기 → F1.7 실존 검증으로 대체
- **구현**:
  - 프로필 선택 필드 `integrations.superpowers` (생략 = 미연계, eslintAssist 패턴)
  - 매핑 정본: 연계 3종(brainstorming/systematic-debugging/writing-plans) + 선택 1 + 제외 10 (코어 SoT 영역)
  - scaffold § 5.16: 실존 검증(드롭+경고) → 제외 필터 → AGENTS.md "보조 스킬" 섹션 + session-routine `{{INTEGRATION_NOTES}}` 치환
  - `{{INTEGRATION_NOTES}}` (26번째 플레이스홀더): managed 템플릿에 조건부 텍스트를 넣는 정규 방법 확립 — scaffold 임의 삽입은 § 12.6 자동 감지를 깨뜨림
  - U1 외부 통합 재감지 (신규 감지 → 추가 제안, 기존 → 실존 재검증/제거 지원). 마이그레이션 등록 불필요
- **감지 표면 실물 검증 완료** (2026-06-12, superpowers v5.1.0 사용자 범위 설치 후): 감지 키 `superpowers@claude-plugins-official`·version·installPath 추출 ✓, `{installPath}/skills/{스킬명}/` 구조 ✓ (14개 디렉토리 — 매핑 정본 실명 전부 일치), 연계 3종 실존 ✓, Step 1.6 grep 명령 그대로 동작 ✓
- **옵트인 E2E 실전 검증 완료** (2026-06-12, haja-web-fe 1.2.0 → 1.5.0 업그레이드):
  - ✅ 다중 홉 마이그레이션 체인 (1.2.0→1.3.0→1.4.0→1.5.0): sharedDirs 조건부 스킵(layer-based), CLAUDE.md cleanup 안내 1줄, manifest 1.5.0 + profile.integrations 보존
  - ✅ U1 재감지 → superpowers 통합 옵트인 → AGENTS.md "보조 스킬" 섹션이 매핑 정본 문구 그대로 렌더링 (69줄 ≤ 100)
  - ✅ session-routine 재생성(managed 자동 감지)에서 `{{INTEGRATION_NOTES}}`가 writing-plans 연계 문구로 치환 — 미치환 플레이스홀더 0건
  - ✅ harness:check 7항목 전체 통과 → **"표준 하네스 가동"** (이전 MVH에서 승격 — 품질 실패 2건이 그 사이 해결됨)
  - 관찰: 업그레이드가 CLAUDE.md/AGENTS.md의 watch 체인 표기 잔존(1.2.0 마이그레이션이 package.json만 수정하고 문서 본문 표기는 미수정)을 발견·정정하고 doc-stale 마찰로 기록 — 마찰 루프의 자기 치유 사례. 1회 발생이라 스킬 변경 없음 (반복 시 harness-feedback 경유 검토)

---

## Session 26: multi-model-consult 컴패니언 스킬 — 1.6.0 (2026-06-12)

### TODO-74: 멀티모델 합성 자문 스킬 (PRD 구체화 + M1+M2 구현)
- **상태**: [x] 완료 (2026-06-12, 1.6.0)
- **파일**: `.tracking/prd-multi-model-consult.md` (Draft→Confirmed→Implemented), `companion-skills/multi-model-consult/SKILL.md` + `scripts/run-advisor.js` (신규), `install.sh` (심링크 추가)
- **PRD 구체화**: 미결정 이슈 5건 해소 — 배치(companion+심링크, 사용자 결정), 하네스 연계(안정화 후, 사용자 결정), 아티팩트(수동 관리+.gitignore 제안), 타임아웃(180s+CONSULT_TIMEOUT_MS), 경로(기본 노출). 실물 검증 기반 추가 결정: **위험 플래그 폐기**(codex `-s read-only --ephemeral`, gemini `--yolo` 제거 — oh-my-claudecode 패턴은 자문에 과잉 권한), codex `-o` 최종 응답 캡처, 병렬=Claude 병렬 도구 호출, check-cli.js/templates/ 폐지(2파일 구조)
- **구현 (M1+M2)**: run-advisor.js — env 스트립(CLAUDE*), CONSULT_DISABLE_EXTERNAL_LLM 스위치, 타임아웃 부분 결과, 아티팩트 저장(.claude/artifacts/consult/), `ARTIFACT:` 출력 계약, 종료 코드 4종. SKILL.md — 관점 분담 분해 가이드, 합성 4섹션 포맷, degradation 3경로, 외부 응답 인젝션 방어 제약
- **실측 테스트**: ✅ 문법 / ✅ 종료 코드 경로(사용법 4, 비활성화 3, 미설치 2 — gemini 미설치로 실측) / ✅ env 스트립 단위 검증(CLAUDE* 제거, PATH·HOME 보존) / ✅ **codex 실호출 E2E** (5초, exit 0, 아티팩트 포맷 정확) / ✅ install.sh 심링크 → 스킬 디스커버리 즉시 확인
- **잔여**: gemini 설치 시 양 CLI + 합성 경로 실사용 검증. 안정화 후 integrations.multiModelConsult 연계 + 통합 규약 일반화 (project-context §5)

### TODO-75: install.sh 멱등성 버그 — ln -sf 자기참조 심링크 (1.6.1)
- **상태**: [x] 완료 (2026-06-12)
- **파일**: `install.sh`, `harness-scaffold/harness-scaffold` (잔여물 제거)
- **문제**: `ln -sf`는 대상이 기존 심볼릭 링크면 링크를 따라 들어가 **디렉토리 안에 자기참조 심링크를 생성**한다. install.sh 재실행(1.6.0에서 multi-model-consult 링크 추가를 위해) 시 잠복 버그 발현 — `harness-scaffold/harness-scaffold` 자기참조 링크가 생성되어 v1.6.0 커밋에 포함됨
- **해결**: `ln -sfn`(-n: 대상 심링크를 따라가지 않음)으로 교체 + 잔여물 git rm. 2회 연속 실행 멱등성 검증 통과. v1.6.0 태그에는 잔여물이 포함되어 있으므로 설치는 v1.6.1 이상 사용

---

## Session 27: 멀티모델 자문 권고 반영 — 1.6.2 (2026-06-12)

> multi-model-consult 첫 실사용 (자문 대상: 이 스킬 구조 자체). codex 결함 관점 + Claude 대안 관점 합성 → 4건 선별 수용. 아티팩트: .claude/artifacts/consult/ (gitignore 등록)

### TODO-76: Stop hook approved 검사 추가
- **상태**: [x] 완료 (2026-06-12, 1.6.2)
- **파일**: `SKILL.md` 프론트매터 hooks + § 1 자동 체이닝
- **문제**: Stop hook이 "프로필 존재+매니페스트 부재"만 검사 — 승인 전 초안, 손상, 수동 작성 프로필에서도 scaffold를 강제할 수 있음 (codex 자문 지적 #3)
- **해결**: hook 조건에 `grep -Eq '"approved"\s*:\s*true'` 추가. 승인은 § 4 Step 5에서만 기록되므로 정상 플로우 동작 동일. 5케이스 시뮬레이션 검증 (승인+무매니페스트→BLOCK, 미승인/필드없음/매니페스트존재/둘다없음→ALLOW)

### TODO-77: 템플릿 재렌더링 해시 재현성 결정화 검토
- **상태**: [ ] 미완료
- **파일**: `SKILL.md` § 12.6, (검토 시) `scripts/render-template.*` 신규
- **문제**: § 12.6 자동 감지가 "LLM이 템플릿을 바이트 단위로 동일하게 재렌더링한다"에 의존 — 산문 실행 중 가장 기계적 정밀성이 필요한 급소 (codex 자문 #1·#4, Claude도 동의한 유일한 코드화 후보). 공백/줄바꿈/치환 미세 차이가 오탐(템플릿 변경으로 오판)을 만들 수 있음
- **해결 후보**: ① § 12.6에 LF 정규화 + 비교 전 정규화 규칙 명시 (저비용) ② 치환 전용 결정적 스크립트(sed/node) 도입 — 렌더링만 코드화하고 판단은 LLM 유지 ("판단은 LLM, 계약-임계 역학은 코드" 경계). 실전 업그레이드에서 오탐 마찰이 기록되면 ② 착수, 그 전에는 ①만

### TODO-78: ESLint 설정 비실행 원칙 명문화
- **상태**: [x] 완료 (2026-06-12, 1.6.2)
- **파일**: `harness-scaffold/SKILL.md` § 5.15
- **문제**: 폴백 규칙은 있었으나 "삽입 지점 탐색을 위해 설정 JS를 실행/평가하지 않는다"가 명문화되지 않음 (codex 자문 #8 — codex·Claude 합의)
- **해결**: 비실행 원칙 추가 (import/require/eval 금지, 텍스트 파싱만). 수정 후 프로젝트 자체 eslint 실행은 validate와 동급으로 허용 — 경계 명시
