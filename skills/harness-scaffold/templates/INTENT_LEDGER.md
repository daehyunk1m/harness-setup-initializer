# 하네스 의도 원장 (Intent Ledger)

> 이 파일은 제품 의도(intended/unintended) 레코드의 **스키마/유형 참조표**다 (정적 문서).
> 실제 의도는 프로젝트 루트의 `.harness-intent.jsonl`에 한 줄씩 기록되며(세션 종료 시 오케스트레이터가 증류 적재),
> 누적된 원장은 추후 PRD 반영·E2E 스펙 근거로 증류한다(Phase 2 — 미배선).
>
> 자매 채널: `.harness-friction.jsonl`(프로세스 마찰) ↔ 이 원장(제품 의도). 같은 인프라, 다른 페이로드.

## kind 유형

| kind | 의미 | 예 |
|------|------|----|
| `intended` | 사용자가 원하는 동작 진술 | "진행률은 각 날의 태스크만 집계한다" |
| `unintended` | 사용자가 관찰한 오작동 | "파이차트에 someday가 섞인다" |

## friction 채널과의 경계

`.harness-intent.jsonl`(제품 의도)과 `.harness-friction.jsonl`(프로세스 마찰)은 **직교**한다:

| 채널 | 기록 대상 | 예 |
|------|----------|----|
| 마찰(`.harness-friction.jsonl`) | TDD 기계가 저항한 **프로세스** 사건 | Implementer 재시도, Reviewer NEEDS_FIX, E2E FAIL, 리팩터 롤백 |
| 의도(`.harness-intent.jsonl`) | 제품이 무엇을 해야 하는지에 대한 **제품** 진술 | "각 날만 집계", "someday 제외", "버튼이 두 번 눌린다" |

한 버그가 둘 다 유발하면 각 채널이 각자의 면을 기록한다(중복 아님 — 다른 싱크·다른 분석기). 제품 버그는 프로세스 마찰 0으로 통과할 수 있다(유닛 통과·재시도 0). 그래서 별도 채널이 필요하다.

## 스키마 (한 줄 = 1 의도, JSON Lines)

```json
{"ts":"2026-06-17T04:30:00Z","session":"2026-06-17T04-12-03Z-a3f9","kind":"intended","surface":"progress","feature":"F007","statement":"진행률 파이차트는 각 날의 태스크만 집계하고 someday는 제외한다","encoded":{"prd":false,"e2e":false,"test":false}}
```

| 필드 | 의미 |
|------|------|
| `ts` | 적재 시각 (ISO8601 UTC) |
| `session` | 세션 고유 ID (`{ISO 시각}-{4자 난수}`) — 마찰 로그와 **동일 값 공유** |
| `kind` | `intended` \| `unintended` |
| `surface` | 영역 태그 (소문자-kebab, 예: `progress`, `section-expand`) — 증류 grouping용 |
| `feature` | 관련 feature ID 또는 `""` |
| `statement` | 소독된 의도 한 줄 (≤200자). 소독 규칙은 session-routine § 의도 로그 참조 |
| `encoded` | `{prd, e2e, test}` 승격 상태 — **현재 항상 all-false**. Phase 2 증류가 채운다 |

오케스트레이터(`.claude/rules/session-routine.md § 의도 로그` 참조)가 세션 종료 시 그 세션의 `claude-progress.txt` `요구:` 줄 + 오작동 발화를 증류해 append한다. 의도 발화가 없는 세션은 0줄(정상).

## 증류 (Phase 2 — 예정, 미배선)

누적된 `.harness-intent.jsonl`은 추후:
- `intended` 의도 → PRD 해당 섹션 반영
- E2E 미커버 `intended` → "스펙 작성 후보"로 목록화
- `unintended` → "왜 이 의도가 명세에 없었나" 역추적 → PRD 보강

> 이 증류 단계와 `encoded` 갱신은 아직 배선되지 않았다 (Phase 2). 현재는 **수집만** 한다.
