# 의도 커버리지 백로그

> `intent-distill`이 `.harness-intent.jsonl` ↔ `@feature` PRD·E2E를 대조해 2차원 커버리지를 동기화하는 영속 백로그다.
> 두 차원(prd_state·e2e_state) 모두 covered(또는 waiver)인 의도는 제거되고, 갭만 남는다.
> **derived 컬럼(prd_state·e2e_state·evidence)은 매 실행 재산출 — 사용자 편집은 `priority/비고` 컬럼만.**
> "의도 정리" / "커버리지 분석"으로 동기화한다.

## 열린 백로그

| key(ts) | feature | surface | kind | statement | prd_state | e2e_state | evidence | priority/비고 |
|---------|---------|---------|------|-----------|-----------|-----------|----------|---------------|
<!-- intent-distill이 갭(둘 중 한 차원이라도 missing/partial/ambiguous/invalid-feature, 또는 blocked)을 여기에 동기화한다. key=의도 ts. prd_state/e2e_state는 5-상태 또는 blocked:no-*-substrate. priority/비고 열은 사용자 소유(머지 보존). -->

## waiver (재추가 안 함)

| key(ts) | statement | 사유 |
|---------|-----------|------|
<!-- "안 함"으로 판정한 의도를 사용자가 여기에 옮기면 distill이 열린 백로그에 재추가하지 않는다. (예: "PRD 불필요"·"E2E 불필요" 메모도 priority/비고에 남기면 해당 차원 갭이 다시 떠도 노이즈로 취급) -->
