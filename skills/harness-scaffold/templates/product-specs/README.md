# 제품 명세 (Product Specs)

이 디렉토리는 각 feature의 **제품 요구사항 명세(PRD)**를 담는다. 의도·동작·제외 규칙을 산문으로 기록하는 곳이며, `feature_list.json`(기능 레지스트리)과 `@feature` E2E(회귀 가드)를 잇는 추적의 출력단이다.

## 작성 방법

1. `_template.md`를 복사해 `docs/product-specs/{featureID}-{slug}.md`로 만든다.
   - 예: feature `F007`의 진행률 차트 → `docs/product-specs/F007-progress-chart.md`
   - `{slug}`은 사람이 찾기 위한 힌트일 뿐 **바인딩 권위가 아니다**.
2. 파일에 `@feature:{featureID}` **전체줄**을 1개 넣는다(보통 상단). 이 줄이 PRD↔feature 바인딩 권위다.
   - 바인딩은 `grep -Rl -Fx "@feature:{id}" docs/product-specs/`로 발견된다(전체줄 리터럴 매칭 — 커스텀 ID 안전, 본문 예시 오탐 방지).
3. 각 섹션을 채운다. 특히 **⚠️ Edge Cases & Out-of-Scope**는 빈칸으로 두지 않는다 — 명세 안 된 제외 규칙이 가장 흔한 버그 원천이다.

## 기능 레지스트리

기능 목록의 권위는 `feature_list.json`이다. 각 PRD는 거기 등록된 feature 하나를 산문으로 명세한다. PRD 없는 feature가 있어도 정상이다(온디맨드 작성 — 작업 시점에 만든다).

## 운영 노트

- intent-distill("의도 정리")이 `docs/INTENT_BACKLOG.md`에 올린 `missing`/`partial` 항목은, 해당 feature의 PRD `Edge Cases`/`Acceptance` 섹션에 반영해 닫는다 — 의도→E2E 백로그와 의도→PRD 명세를 잇는 운영 규칙.
- 의도↔PRD 커버리지 자동 점검·미검증 명세 표면화는 후속 단계에서 배선된다(현재는 작성 관례·템플릿만 제공).
