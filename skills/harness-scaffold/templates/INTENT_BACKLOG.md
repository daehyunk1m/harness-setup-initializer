# 의도 커버리지 백로그

> `intent-distill`이 `.harness-intent.jsonl` ↔ `@feature` E2E를 대조해 동기화하는 영속 백로그다.
> 커버된 의도는 제거되고, 미커버 갭만 남는다. 사용자가 추가한 `priority/비고`·waiver는 보존된다.
> "의도 정리" / "커버리지 분석"으로 동기화한다.

## 열린 백로그

| key(ts) | feature | surface | kind | statement | state | evidence | priority/비고 |
|---------|---------|---------|------|-----------|-------|----------|---------------|
<!-- intent-distill이 미커버 의도(missing/partial/ambiguous/invalid-feature)를 여기에 동기화한다. key=의도 ts. priority/비고 열은 사용자 소유(머지 보존). -->

## waiver (재추가 안 함)

| key(ts) | statement | 사유 |
|---------|-----------|------|
<!-- "안 함"으로 판정한 의도를 사용자가 여기에 옮기면 distill이 열린 백로그에 재추가하지 않는다. -->
