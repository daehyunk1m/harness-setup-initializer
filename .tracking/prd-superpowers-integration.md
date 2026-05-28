# PRD: Superpowers 플러그인 옵트인 통합

> 작성일: 2026-05-28
> 상태: Draft — 추후 구현 대기
> 참고: obra/superpowers (Jesse Vincent의 Claude Code 스킬 모음)

---

## 1. 배경 및 문제 정의

### 1.1 문제
- 하네스가 생성하는 산출물(AGENTS.md, .claude/rules, TDD subagent 등)은 **프로젝트 골격**을 잡아주지만, 작업 중 반복되는 **워크플로 패턴**(브레인스토밍 구조화, 디버깅 루틴, 플랜 작성 절차 등)은 별도 스킬로 보완할 여지가 있다
- obra/superpowers 같은 외부 스킬 패키지가 이 영역에서 검증된 패턴을 제공한다
- 그러나 외부 의존성을 **하네스에 강제로 묶으면** 사용자 설치 부담, 버전 드리프트, 철학 충돌이 발생한다

### 1.2 해결 방향
- 하네스 코어는 **자급자족(self-contained)**을 유지한다
- superpowers 같은 외부 스킬 패키지는 **옵트인 통합 레이어**로 분리한다
- 프로필에 `integrations.<name>` 플래그를 두고, 켜졌을 때만 AGENTS.md/세션 루틴/.claude/rules에 연계 가이드를 삽입한다

### 1.3 왜 지금인가
- 하네스 v1.0.0이 안정화되어 코어 산출물 범위가 확정되었다
- superpowers가 v0.x 후반대에 진입하며 스킬 이름/동작이 어느 정도 안정화되었다
- 향후 다른 외부 패키지(예: multi-model-consult, awesome-claude-code-skills 류) 통합의 **선례**가 필요하다

---

## 2. 목표

### 2.1 핵심 목표
1. 하네스 셋업 시 superpowers 연계 여부를 **소크라테스 문답**에서 묻고, 프로필에 기록한다
2. 옵트인된 경우 AGENTS.md/세션 루틴에 **연계 호출 지점**을 명시적으로 삽입한다
3. 코어 산출물과 **겹치는 영역**은 끌어오지 않는다 (TDD, 코딩 표준 등은 우리 것이 우선)
4. 외부 패키지 버전이 바뀌어도 **하네스 코어는 깨지지 않는다**

### 2.2 비목표 (Non-goals)
- superpowers 자체를 하네스가 설치/관리하지 않는다 (사용자가 직접 설치)
- superpowers 스킬을 우리 templates/ 안에 복제하지 않는다 (라이선스/유지보수 부담)
- 모든 superpowers 스킬을 다 연계하지 않는다 (보완 영역만 선별)
- 다른 외부 패키지(예: oh-my-claudecode)도 동일 메커니즘으로 다룬다 — 단, 이번 PRD는 superpowers만 대상

---

## 3. 사용자 및 사용 시나리오

### 3.1 타깃 사용자
- 이미 superpowers를 설치해 쓰는 개발자 — 하네스가 이 도구들과 자연스럽게 엮이길 원함
- 새로 하네스를 셋업하면서 superpowers도 함께 고려하는 개발자
- 외부 의존을 싫어해 코어만 쓰고 싶은 개발자 — 이들은 옵트아웃이 기본

### 3.2 사용 시나리오

**시나리오 A — 기존 superpowers 사용자**
```
사용자: /harness-setup
스킬: (Q&A 중) "superpowers 플러그인을 감지했습니다.
       AGENTS.md에 brainstorming/debugging 호출 지점을 연계할까요?"
사용자: 네
→ 프로필: integrations.superpowers.enabled = true
→ AGENTS.md 세션 루틴에 "복잡한 설계 결정 시 /brainstorm 활용" 같은 가이드 삽입
```

**시나리오 B — 처음 듣는 사용자**
```
스킬: (Q&A 중) superpowers 미감지 → 질문 생략
→ 하네스는 코어 산출물만 생성
→ 나중에 사용자가 superpowers 설치 후 /harness-upgrade로 통합 추가 가능
```

**시나리오 C — 옵트아웃**
```
스킬: superpowers 감지됨, 그러나 사용자가 "연계 안 함" 선택
→ 프로필: integrations.superpowers.enabled = false
→ 코어 산출물만 생성. AGENTS.md에 superpowers 언급 없음
```

---

## 4. 기능 요구사항

### 4.1 MVP (Phase 1)
| ID | 요구사항 | 우선순위 |
|----|---------|---------|
| F1.1 | 프로필 스키마에 `integrations.superpowers` 필드 추가 | P0 |
| F1.2 | Phase 1 스캔 단계에서 superpowers 설치 여부 감지 (`~/.claude/plugins/` 또는 `~/.claude/skills/superpowers*`) | P0 |
| F1.3 | 감지 시에만 Q&A에서 연계 여부 질의 | P0 |
| F1.4 | Phase 2 스캐폴딩 단계에서 옵트인 시 AGENTS.md에 연계 섹션 삽입 | P0 |
| F1.5 | 연계 스킬 화이트리스트(매핑 테이블) 정의 — 어떤 superpowers 스킬을 어떤 산출물의 어디에 언급할지 | P0 |
| F1.6 | 코어와 겹치는 영역(TDD, 코딩 표준) 제외 규칙 | P0 |

### 4.2 확장 (Phase 2)
| ID | 요구사항 | 우선순위 |
|----|---------|---------|
| F2.1 | `/harness-upgrade` 경로에서 integration 추가/제거 지원 | P1 |
| F2.2 | superpowers 버전 호환 매트릭스 (`compatible: ">=0.5,<1.0"`) | P1 |
| F2.3 | 다른 외부 패키지 연계 (multi-model-consult 등)를 같은 메커니즘으로 확장 | P2 |
| F2.4 | 사용자 정의 매핑 — 사용자가 "이 스킬을 여기에 끼워달라" 지정 | P3 |

---

## 5. 아키텍처

### 5.1 프로필 스키마 확장

```jsonc
{
  "version": "1.x.0",
  // ... 기존 필드 ...
  "integrations": {
    "superpowers": {
      "enabled": true,
      "detectedVersion": "0.7.2",     // 감지 시점의 버전 (정보용)
      "linkedSkills": [                // 실제 AGENTS.md에 언급할 스킬
        "brainstorming",
        "debugging",
        "writing-plans"
      ]
    }
    // 향후: "multi-model-consult": {...}, "oh-my-claudecode": {...}
  }
}
```

### 5.2 감지 로직 (SKILL.md Phase 1.5)

```
1. ~/.claude/plugins/ 아래에 superpowers 디렉토리/매니페스트 존재 여부 확인
2. ~/.claude/skills/ 아래에 superpowers-* 패턴 확인
3. plugin manifest가 있으면 버전 추출
4. 발견 시 Q&A 질문 풀에 "superpowers 연계 여부" 추가
5. 미발견 시 질문 자체를 생략 (사용자에게 모르는 도구 묻지 않음)
```

### 5.3 연계 매핑 테이블 (스킬 내부 상수)

| superpowers 스킬 | 우리가 끼우는 위치 | 끼우는 이유 | 충돌 영역? |
|-----------------|-------------------|------------|-----------|
| `brainstorming` | AGENTS.md "복잡한 설계 결정" 섹션 | 우리는 구조화된 브레인스토밍 가이드 없음 | 없음 |
| `debugging` | AGENTS.md "이슈 추적" 섹션 | 우리는 디버깅 루틴 산출물 없음 | 없음 |
| `writing-plans` | .claude/rules/session-routine.md | 우리 세션 루틴이 플랜 작성을 권장하나 절차는 부재 | 보완 (충돌 없음) |
| `test-driven-development` | **연계 안 함** | 우리 templates/agents/red-green-refactor.md와 충돌 | **충돌** |
| `code-review` | **연계 안 함** | /review 빌트인과 중복 | **중복** |
| `using-skills` | AGENTS.md "스킬 사용" 메타 섹션 (선택) | 메타 가이드 | 없음 |

> 매핑은 **수동 큐레이션**한다. superpowers 신규 스킬이 나오면 우리가 검토 후 추가/제외 결정.

### 5.4 AGENTS.md 삽입 형식

옵트인 시 AGENTS.md 끝부분에 다음 섹션을 삽입:

```markdown
## 보조 스킬 (Superpowers 연계)

> 이 프로젝트는 superpowers 플러그인과 연계됩니다.
> 다음 상황에서 해당 스킬을 호출하세요:

- **복잡한 설계 결정/트레이드오프 분석**: `/brainstorming`
- **재현 어려운 버그 추적**: `/debugging`
- **다단계 기능 구현 착수 전 플랜**: `/writing-plans`

> superpowers 미설치 시 이 섹션의 호출은 무시됩니다.
> TDD/코드 리뷰는 본 하네스의 자체 워크플로(`agents/red-green-refactor.md`, `/review`)를 우선 사용합니다.
```

### 5.5 스캐폴딩 흐름 변경

`harness-scaffold/SKILL.md § 5.1 AGENTS.md 생성 규칙`에 조건부 블록 추가:

```
프로필.integrations.superpowers.enabled == true 이면
  → AGENTS.md 끝에 "보조 스킬 (Superpowers 연계)" 섹션을 삽입
  → linkedSkills 배열을 순회하며 매핑 테이블에서 문구 조회 후 렌더링
아니면
  → 섹션 자체를 생성하지 않음
```

`.claude/rules/session-routine.md`도 동일 패턴으로 조건부 라인 추가:

```
프로필.integrations.superpowers.linkedSkills 가 "writing-plans" 포함 시
  → "다단계 작업 착수 전 /writing-plans 활용 권장" 라인 삽입
```

---

## 6. 통합 정책

### 6.1 충돌 회피 원칙
1. **코어 우선**: 하네스 코어가 다루는 영역(TDD, 코딩 표준, 커밋 규칙, 구조 검증)은 superpowers를 끌어오지 않는다
2. **보완만 끌어옴**: 코어에 없는 영역(브레인스토밍, 디버깅 루틴 등)만 연계
3. **명시적 우선순위 표기**: AGENTS.md에 "TDD/리뷰는 본 하네스 사용" 명시

### 6.2 버전 드리프트 대응
- 매핑 테이블에 `compatible` 필드를 두고, 감지된 버전이 범위를 벗어나면 연계 시 경고
- superpowers 스킬 이름이 바뀌면 우리 매핑 테이블도 업데이트 (수동)
- breaking change가 감지되면 `/harness-upgrade`에서 사용자에게 알림

### 6.3 옵트아웃 보장
- 기본값은 `enabled: false`
- 감지되더라도 사용자가 명시적으로 동의해야 활성화
- AGENTS.md에 한 줄 안내로 옵트아웃 방법 명시

---

## 7. 사용자 경험 (UX)

### 7.1 Q&A 메시지 (감지 시)
```
✓ superpowers 플러그인이 감지되었습니다 (v0.7.2).

이 하네스의 AGENTS.md에 superpowers 연계 가이드를 삽입할까요?
연계 대상:
  - /brainstorming (복잡한 설계 결정)
  - /debugging (버그 추적)
  - /writing-plans (다단계 작업 플랜)

제외:
  - TDD, 코드 리뷰는 본 하네스 자체 워크플로 사용

[Y] 연계함 / [n] 연계 안 함
```

### 7.2 미감지 시
- 질문 자체를 생략 (모르는 도구를 강제로 노출하지 않음)
- 단, references/harness-guide.md에 "외부 스킬 연계" 섹션을 두어 사후 인지 가능하게

### 7.3 업그레이드 시
- 기존 프로필에 `integrations` 필드가 없으면 마이그레이션 시 추가하고 기본값 `enabled: false`
- 이미 enabled면 매핑 테이블 변경 사항 적용

---

## 8. 검증 기준 (Acceptance Criteria)

- [ ] superpowers 미설치 환경에서 셋업 → 프로필에 `integrations` 키 없음(또는 빈 객체), AGENTS.md에 superpowers 언급 없음
- [ ] superpowers 설치 환경에서 셋업 + 옵트인 → 프로필에 `enabled: true`, AGENTS.md에 "보조 스킬" 섹션 존재
- [ ] superpowers 설치 환경 + 옵트아웃 → AGENTS.md에 언급 없음
- [ ] 옵트인 후 superpowers 제거 → AGENTS.md 안내문은 남아있고, 호출 시 자연스럽게 무시됨(스킬 부재로 fallback)
- [ ] `linkedSkills`에 TDD/code-review를 추가하려 해도 매핑 테이블에서 제외되어 렌더링 안 됨
- [ ] 업그레이드 경로에서 integration 추가/제거 가능
- [ ] 매핑 테이블의 모든 항목이 실제 superpowers 스킬 이름과 일치 (수동 검증)

---

## 9. 한계 및 리스크

### 9.1 알려진 한계
1. **수동 큐레이션**: 매핑 테이블을 우리가 직접 관리해야 한다. superpowers 신규 스킬이 자동 반영되지 않음
2. **버전 락 없음**: superpowers가 호환성 깨면 우리가 따라가야 한다
3. **사용자 인지 부담**: AGENTS.md에 외부 스킬 호출이 섞여 있어, superpowers 모르는 협업자가 보면 혼란 가능

### 9.2 리스크
- **superpowers 철학 변화**: 도구가 방향을 바꾸면 우리 매핑이 무의미해질 수 있음 → 매핑 테이블을 references/에 두고 분기마다 리뷰
- **연계 확장의 유혹**: "이것도 좋은데 끼울까?" → 검증된 보완 영역만, 충돌 없는 것만 (PR 리뷰 체크리스트화)
- **라이선스**: superpowers 스킬을 복제하지 않으므로 라이선스 이슈 없음. 단, 매핑 테이블에서 스킬 이름 인용은 fair use 범위

---

## 10. 마일스톤

### M1 — 스키마/감지 (목표: 0.5일)
- [ ] 프로필 스키마에 `integrations.superpowers` 필드 추가 (SKILL.md, harness-scaffold/SKILL.md 동기)
- [ ] Phase 1 스캔에 superpowers 감지 로직 추가
- [ ] Q&A 질문 풀에 조건부 질문 추가
- [ ] 매핑 테이블 초안 (references/integrations/superpowers-mapping.md)

### M2 — 스캐폴딩 (목표: 0.5일)
- [ ] harness-scaffold/SKILL.md § 5.1, § 5.10에 조건부 분기 추가
- [ ] AGENTS.md 템플릿에 superpowers 섹션 플레이스홀더 정의
- [ ] .claude/rules/session-routine.md 조건부 라인 추가
- [ ] 옵트인 / 옵트아웃 양쪽 시나리오 수동 테스트

### M3 — 업그레이드 경로 (목표: 0.5일)
- [ ] `/harness-upgrade`에서 integration 추가/제거
- [ ] 기존 프로필 마이그레이션
- [ ] CHANGELOG/HANDOFF 업데이트

### M4 — 일반화 (보류)
- [ ] multi-model-consult 등 다른 외부 패키지로 동일 메커니즘 확장
- [ ] 사용자 정의 매핑 지원

---

## 11. 미결정 이슈 (Open Questions)

1. **감지 경로**: superpowers가 plugin으로 설치되는지 skill로 설치되는지 — 두 경로 다 확인해야 하는가?
2. **버전 추출**: superpowers manifest에 version 필드가 있는가? 없으면 어떻게 호환성 체크?
3. **매핑 테이블 위치**: SKILL.md 본문 vs references/ 별도 파일 — 유지보수 빈도 고려해 후자가 나아 보임
4. **다국어**: AGENTS.md 한국어인데 superpowers 스킬 이름은 영어 그대로 — 통일 안 해도 OK?
5. **삭제 경로**: 옵트인 후 사용자가 superpowers를 지웠을 때 AGENTS.md 안내문은 남기는가, 정리하는가?
6. **선례 정착**: 이 PRD를 일반 "외부 패키지 통합 규약"으로 승격할지, 패키지별 PRD를 각각 둘지?

이 질문들은 M1 착수 시 사용자와 확인 후 결정한다.

---

## 12. 참고 자료

### 12.1 원본 소스
- **superpowers**: https://github.com/obra/superpowers (Jesse Vincent)
  - 스킬 카탈로그 — brainstorming, debugging, writing-plans, test-driven-development 등
- 본 저장소 관련 문서:
  - `references/project-context.md` § 설계 결정
  - `references/versioning-policy.md` — Public API에 `integrations` 필드 포함 시 MINOR 범프
  - `.tracking/prd-multi-model-consult.md` — 유사 외부 통합 패턴의 선행 사례

### 12.2 관련 선행 논의
- 2026-05-09 세션 — 사용자가 "superpowers 같은 플러그인 연계가 워크플로를 더 강력하게 할 것 같다"고 제안
- 권장 방향: 하드 의존 X, 옵트인 통합 O, 코어와 겹치는 영역 제외
