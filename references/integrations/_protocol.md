# 외부 통합 규약 (integrations protocol)

> 하네스에 외부 보조 스킬/도구를 **옵트인으로 연계**하는 일반 규약.
> 소비자: `SKILL.md`(Step 1.6 감지, § 4.2 질문, § 5 스키마), `harness-scaffold/SKILL.md`(§ 5.16 렌더링)
> 선례 2종: superpowers(외부 플러그인·다중 스킬 화이트리스트), multi-model-consult(자체 컴패니언·단일 연계)
> 정본 우선순위: 이 문서가 통합 *메커니즘*의 정본, 각 통합의 *내용*은 `<name>-mapping.md`가 정본

---

## 1. 핵심 원칙 (모든 통합 불변)

1. **옵트인 — 생략이 기본**: 프로필에 `integrations.<name>`가 없으면 미연계. 명시적 false 대신 **필드 생략**으로 옵트아웃을 표현한다 (eslintAssist 패턴과 동일)
2. **미감지 시 질문 생략**: 사용자가 설치하지 않은 도구는 Q&A에서 묻지 않는다 (모르는 도구 비노출)
3. **코어 SoT 영역 제외**: TDD·코드 리뷰·검증 루프·git 워크플로·오케스트레이션은 코어가 source of truth — 어떤 통합도 이 영역을 끌어오지 않는다. 보완 영역(브레인스토밍, 일반 디버깅, 계획 문서, 교차 자문 등)만 연계
4. **본문 비복제**: 외부 스킬/도구의 본문을 templates/에 복제하지 않는다 — 이름과 호출 시점 안내만 (라이선스·유지보수 부담 회피)
5. **미설치 환경 무시**: 연계 안내는 "미설치 시 무시된다"를 명시 — 옵트인 후 도구를 제거해도 안내문은 무해하게 잔류
6. **옵트아웃 시 흔적 0**: 필드 생략 시 어떤 산출물에도 통합명이 나타나지 않는다 (AGENTS.md 섹션 없음, `{{INTEGRATION_NOTES}}` 빈 문자열)
7. **버전 비차단**: `detectedVersion`은 정보용 표기일 뿐 — 버전 비교로 연계를 막지 않는다. 드리프트는 **실존 검증**이 잡는다 (§ 4)
8. **managed 템플릿 조건부 텍스트는 플레이스홀더로**: session-routine.md 같은 managed 파일에 조건부 연계 문구를 넣을 때는 scaffold 임의 삽입이 아니라 `{{INTEGRATION_NOTES}}` 치환으로 처리한다 — 임의 삽입은 § 12.6 자동 감지(재렌더링 해시 비교)를 깨뜨린다

---

## 2. 프로필 스키마 (`integrations.<name>`)

```jsonc
"integrations": {                  // 선택 필드 — 생략 시 연계 없음
  "<name>": {
    "enabled": true,               // 공통: 옵트인 여부
    "source": "plugin | skill-dir | companion | cli",  // 공통: 감지 출처
    "detectedVersion": "5.1.0",    // 공통(선택): 정보용. 추출 불가 시 null
    "installPath": "~/.claude/...",// 공통(선택): 실존 검증용. 해당 없으면 null
    "linkedSkills": ["..."]        // 통합별(선택): 다중 스킬 화이트리스트 (superpowers 전용)
  }
}
```

- `source` 값: `plugin`(마켓플레이스 플러그인) / `skill-dir`(수동 스킬 디렉토리) / `companion`(하네스 자체 컴패니언 스킬) / `cli`(CLI 도구 존재)
- 통합별 필드는 해당 통합에만 존재 — 공통 4필드(enabled/source/detectedVersion/installPath)는 모든 통합이 공유
- 매니페스트 profile에 보존 (업그레이드 재감지·제거의 원천)

---

## 3. 통합 추가 4단계 절차

새 통합 `<name>`을 추가하려면:

### 단계 1 — 감지 (SKILL.md Step 1.6)
글로벌 설치 여부를 감지하는 셸 로직을 Step 1.6에 추가한다. 감지 성공 시 `source`·`installPath`·`detectedVersion`을 추출한다. 미감지 시 § 4.2 질문을 트리거하지 않는다.

### 단계 2 — 옵트인 질문 (SKILL.md § 4.2)
감지된 경우에만 우선순위 5(선택)로 묻는다. 동의 시 `integrations.<name>` 기록, 거부 시 필드 생략. 질문에 **연계 대상(보완 영역)과 제외(코어 SoT)를 명시**한다.

### 단계 3 — 연계 정본 (`references/integrations/<name>-mapping.md`)
연계 문구(AGENTS.md에 들어갈 1줄들)와 제외 규칙을 정의한다. 다중 스킬이면 화이트리스트(연계/선택/제외) 분류, 단일 연계면 문구 1개. 분기 리뷰로 카탈로그 드리프트 갱신.

### 단계 4 — 렌더링 (harness-scaffold/SKILL.md § 5.16)
§ 5.16의 일반 렌더링 절차를 따른다 (아래 § 4). 통합별 특이사항만 추가.

---

## 4. 렌더링 절차 (§ 5.16 일반 규칙)

`integrations.<name>.enabled == true`인 각 통합에 대해:

1. **실존 검증**: `installPath`(또는 감지 경로)가 실재하는지 확인. 다중 스킬이면 각 `linkedSkills` 항목의 디렉토리 존재 확인 → 없는 항목 드롭 + 보고 경고. 경로 자체가 없으면(제거됨) 해당 통합 전체 스킵 + 안내
2. **제외 필터**: 매핑 정본의 "연계/선택" 목록에 없는 항목은 `linkedSkills`에 있어도 렌더링하지 않음 (코어 충돌 차단)
3. **AGENTS.md 렌더링**: 생존 항목으로 "## 보조 스킬" 섹션을 구성 (§ 5.1 위치 — 문서 맵 앞). **여러 통합이 옵트인되면 단일 섹션에 합산**한다:

```markdown
## 보조 스킬

{각 통합의 연계 문구 — 1줄씩, 항목 끝에 (출처) 표기}

> 외부 보조 스킬 연계 — 미설치 환경에서는 무시된다.
> TDD·코드 리뷰·검증은 본 하네스 자체 워크플로를 사용한다.
```

4. **session-routine 렌더링**: 매핑 정본에 session-routine 연계 문구가 있는 통합이 있으면, 그 문구들을 합쳐 `{{INTEGRATION_NOTES}}`로 치환 (§ 5.11.3). 없으면 빈 문자열

**100줄 예산**: 통합이 늘어도 AGENTS.md 100줄을 지킨다 — 각 통합 연계는 1~몇 줄로 압축

---

## 5. 등록된 통합

| name | source | 연계 정본 | 성격 |
|------|--------|----------|------|
| `superpowers` | plugin / skill-dir | `superpowers-mapping.md` | 외부 플러그인 — 14종 중 연계 3·선택 1·제외 10 (화이트리스트) |
| `multiModelConsult` | companion + cli | `multi-model-consult-mapping.md` | 자체 컴패니언 스킬 — 단일 연계 (codex/gemini CLI 1개 이상 필요) |

> 두 통합의 감지 모델은 다르지만(플러그인 vs 컴패니언+CLI) 같은 규약(옵트인→매핑→§ 5.16 렌더링)으로 표현된다. 이것이 규약 일반화의 검증 기준이다.

---

## 6. 업그레이드 시 재감지 (SKILL.md § 12.3 U1)

- 기존 manifest.profile에 `integrations.<name>`이 없고 새로 감지되면 → U2에서 통합 추가를 제안 (옵트인)
- 기존 통합이 있으면 → 실존 재검증 (없어진 항목 드롭). 사용자가 제거를 요청하면 fileActions로 AGENTS.md 보조 스킬 섹션에서 해당 항목 제거
- integrations는 생략이 기본값이라 마이그레이션 [profile] add는 불필요
