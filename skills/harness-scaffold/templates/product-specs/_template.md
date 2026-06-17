@feature:F000
<!-- ↑ 이 파일이 명세하는 feature_list.json의 id로 교체한다. 전체줄 리터럴(grep -Fx 매칭). 파일명 slug가 아니라 이 줄이 PRD↔feature 바인딩 권위다. -->

# {기능 제목}

<!-- harness:section=intent -->
## Intent / 의도
<!-- 이 기능이 왜 존재하는가 — 해결하는 사용자 문제. -->

<!-- harness:section=behavior -->
## Behavior / 동작 규칙
<!-- 사용자 관점 동작. feature_list.steps ↔ @feature E2E 시나리오와 1:1 매핑되게 적는다. -->

<!-- harness:section=edge-cases -->
## ⚠️ Edge Cases & Out-of-Scope / 제외·엣지케이스  (필수)
<!-- [필수] 이 기능이 다루지 않는 상황·제외 조건·무시할 입력을 명시한다.
     제외할 사항이 전혀 없다면 그 판단 근거와 함께 "명시적 제외 사항 없음"이라고 적는다.
     빈칸·TBD·N/A로 두지 않는다 — 명세 안 된 제외 규칙이 가장 흔한 버그 원천이다.
     예) "진행률은 각 날의 태스크만 집계 — someday는 제외" -->

<!-- harness:section=acceptance -->
## Acceptance / 수용 기준
<!-- 검증 가능한 기준. steps ↔ @feature E2E 시나리오로 확인 가능해야 한다. -->

<!-- harness:section=open-questions -->
## Open Questions / 미결
<!-- 아직 결정되지 않은 사항. 없으면 "없음". -->
