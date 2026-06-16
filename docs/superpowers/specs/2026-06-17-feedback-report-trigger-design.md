# 설계: 피드백 루프 보고 트리거 (이슈 #14)

> 작성일: 2026-06-17
> 상태: 설계 확정 (사용자 승인 대기 → writing-plans)
> 이슈: #14 [Friction] harness-feedback 호출 트리거 미정의 — 피드백 루프 보고 단계 미배선
> 멀티모델 자문: codex(결함)·gemini(대안/운영) 반영 — 원본 `.claude/artifacts/consult/codex-…-22-54-17.md`·`gemini-…-22-55-14.md`

---

## 1. 문제

마찰 **기록**은 자동화됨(1.18.0, 이슈 #9): TDD 사이클이 마찰을 만나면 session-routine이 `.harness-friction.jsonl`(프로젝트 루트, append-only, 한 줄=1 이벤트)에 append한다. 그러나 마찰 **보고**(harness-feedback 컴패니언 스킬이 jsonl→패턴→Issue 생성)를 **호출하는 트리거가 어디에도 없다** — 운영 사이클·session-routine 종료·harness-cleanup 어디에도. 결과적으로 harness-feedback은 사용자가 "하네스 피드백 분석해줘"로 명시 호출할 때만 동작하고, jsonl이 쌓여도 아무도 보고하지 않아 **dead-letter**가 된다. (파일럿 haja-web-fe에서 마찰 4건이 보고 없이 적체되다가, 사용자가 직접 요청한 시점에야 #13으로 보고됨.)

## 2. 목표 / 비목표

**목표**
- dead-letter 방지: 마찰이 쌓이면 자연스러운 경계(세션 종료)에서 보고를 **권장**한다.
- nagware 방지: 이미 보고(또는 명시 무시)한 마찰을 매 세션 다시 권하지 않는다.
- 교차세션 누적(세션마다 1건씩 쌓이는 drip) 포착.
- harness-feedback의 중복 Issue 생성 방지.

**비목표**
- 자동 Issue 생성 (승인 없이 실행 금지 — 항상 사용자 확인).
- Stop hook 도입 (1.18.0 무-훅·에이전트 주도 원칙 유지).
- jsonl 스키마 변경 (append-only 보존).

## 3. 핵심 설계 결정

| 결정 | 선택 | 근거 |
|------|------|------|
| 미보고 판별 메커니즘 | **`.harness-feedback-cursor` 북마크 파일** | 멀티모델 자문(codex·gemini 둘 다)이 순수 무상태 gh-dedup의 취약성(title 매칭·닫힌 이슈 재분석 무한루프·교차세션 drip 미포착)을 지적. cursor 하나가 **세 결함을 동시에** 단순 해소(아래 §3.1). gemini "압도적 우수" 평가. |
| 트리거 동작 | **제안만 (한 줄)** | 사용자 선택. 무-훅·비침습. 자동 실행은 종료 흐름을 방해. harness-feedback이 §6에서 생성 전 확인하므로 자동 호출해도 안전하나, "제안만"이 더 가볍다. |
| 트리거 기준 | harness-feedback 보고 기준(`critical≥1 OR 동일 event≥2 OR high≥2`)을 **cursor 이후 누적 윈도우**에 적용 | codex 지적: 기존 설계의 "세션 스코프 + 동일 event≥2"는 **세션 내 dedup**(같은 feature+event 1회만 기록)과 충돌해 사실상 발동 불가. **해소**: 세션 스코프 대신 cursor 이후 누적 윈도우로 평가 → 교차세션·다feature로 high≥2·동일 event≥2가 달성 가능해짐. 트리거 기준을 보고 기준과 **동일**하게 두어 "제안 떴는데 보고할 패턴 없음" mismatch 제거(제안=반드시 보고 가능). |
| 닫힌 Issue 재보고 | **cursor가 자동 처리** (closedAt 시간창 불요) | 처리한 이벤트는 cursor 뒤로 넘어가 재분석 안 됨 → 재발=cursor 이후 새 이벤트만. codex·gemini 둘 다 경고한 "닫힌 패턴 매월 재생성/무한루프"를 구조적으로 차단. |
| 월간 백업 | **보조로 유지(정직 표기)** | codex·gemini 둘 다 "월간은 신뢰 못 할 그물망". cursor 기반 세션 종료 트리거가 **주 그물망**이고, 월간은 belt-and-suspenders. 유일한 그물망으로 광고하지 않음. |
| gemini의 markdown-as-state(γ) | **기각** | 1.18.0이 HARNESS_FRICTION.md를 정적 참조 문서로 의도적 격하 + harness-feedback→gh 자동화를 채택. γ는 그 결정을 되돌림. |

### 3.1 cursor가 세 결함을 동시에 푸는 방식

| 자문 지적 | cursor 해소 |
|---|---|
| 교차세션 drip 트리거 안 됨 (세션 스코프 한계) | jsonl tail vs cursor 비교로 "미보고 누적"을 세션 무관하게 산출 — cursor가 곧 교차세션 메모리 |
| 닫힌 Issue 재분석 무한루프 | 처리분은 cursor 뒤 → 다시 안 읽음. 재발=cursor 이후 새 이벤트만 (closedAt 로직·라벨 필터 불요) |
| gh title 매칭 취약 | 트리거·재분석 방지가 gh 텍스트 매칭에 의존하지 않음 (gh-dedup은 경량 힌트로만 잔존) |

## 4. 구성요소

### 4.1 `.harness-feedback-cursor` (신규 data 파일)

- **위치**: 프로젝트 루트.
- **형식**: 단일 JSON 라인(자기서술·확장 가능):
  ```json
  {"processedLines": 42, "lastReportedAt": "2026-06-17T12:00:00Z"}
  ```
  - `processedLines`: harness-feedback이 처리(보고 또는 명시 무시)한 **물리적 줄 수**. append-only jsonl이므로 "줄 N까지 처리 → 다음은 N+1부터"가 모호하지 않다. 깨진(파싱 실패) 줄도 물리 줄 수에 포함(영구 스킵 — 어차피 분석 불가).
  - `lastReportedAt`: 사람/감사용 마지막 처리 시각(ISO8601, 첫 생성 시 `null`).
- **카테고리**: `data` (feature_list.json·claude-progress.txt와 동급) — 커밋되어 살아남고, 템플릿 해시 드리프트 검사 제외, 업그레이드 시 덮어쓰지 않음.
- **append-only jsonl 미변경**: jsonl과 **별개 파일**이라 1.18.0 append-only 원칙 보존.
- **팀 환경 caveat**: 커밋되므로 다중 개발자 시 cursor 라인 머지 충돌 가능(feature_list.json과 동일 성질) — 충돌 시 더 작은 `processedLines`로 해소(미보고를 재포착하는 안전 방향). 문서에 명시.

### 4.2 session-routine 세션 종료 트리거 (managed 템플릿 편집)

`templates/rules/session-routine.md § 세션 종료`에 단계 추가:

1. jsonl을 읽어 **cursor 이후(물리 줄 > `processedLines`)** 이벤트를 파싱(관용 — 깨진 줄 스킵). cursor 부재 시 전체를 미보고로 간주(첫 실행/업그레이드 직후 — 의도된 백로그 노출).
2. **마찰 카운트 산정**: `infra-track-entry`(감사 마커, 마찰 아님)·`session-incomplete`(루틴 종료 기록) 제외. (이 단계는 `session-incomplete` append **전에** 평가하거나, 평가 시 해당 event를 제외 — 둘 다 N 카운트에서 빠지게.)
3. **트리거 기준** 평가 — harness-feedback 보고 기준과 **동일**(`critical≥1 OR 동일 event≥2 OR high≥2`)하게, cursor 이후 누적 윈도우에 적용. 트리거↔보고 정합이라 "제안 떴는데 보고할 것 없음" mismatch가 없다. 누적 윈도우라 단일 세션의 dedup 제약(같은 feature+event 1회)을 넘어 high≥2·동일 event≥2가 교차세션·다feature로 달성된다. (critical은 1건도 즉시.)
4. 충족 시 **한 줄 제안만** 출력(자동 실행 안 함, gh 호출 없음):
   ```
   ℹ️ 미보고 마찰 {N}건 (critical {a}·high {b}·medium {c}) — '하네스 피드백 분석해줘'로 보고 권장 (글로벌 컴패니언)
   ```
5. jsonl 부재 → 스킵(에러 아님). cursor 부재 → 전체를 미보고로 평가.

> 보고 후 cursor가 EOF로 전진하므로(§4.3), 다음 세션엔 미보고=0 → 재제안 없음(nagware 방지). 사용자가 거절(n)하면 cursor 미전진 → 다음 세션 재제안(정당 — 여전히 미보고). 영구 거절은 §4.3의 "무시(d)"로 cursor를 전진시켜 침묵.

### 4.3 harness-feedback 변경 (컴패니언 — Public API 아님)

- **§1 읽기**: jsonl 읽은 뒤 cursor를 읽어 **`processedLines` 이후 물리 줄만** 분석 대상으로 한다. cursor 부재 → 전체(처음부터).
- **§4 패턴 분석**: cursor 이후 이벤트에 대해 기존 기준(critical≥1 / 동일 event≥2 / high≥2).
- **§5 직전 경량 dedup 힌트(백스톱)**: cursor가 주 방어이나 cursor 분실·동시 실행 대비, 초안 생성 시 `gh issue list --label friction --state open --json number,body`를 조회해 body fingerprint가 같은 열린 Issue가 있으면 **"⚠️ 유사 열린 Issue #N 존재 — 중복일 수 있음"**을 §6 확인에 함께 표시(하드 스킵 아님 — 사용자 판단). gh 실패 → 힌트 스킵 + 경고(degradation, 기존 동작 유지).
- **fingerprint**: 생성하는 Issue body에 `<!-- harness-friction:fp=event:{event} -->` 주석을 넣는다(§5 힌트가 title 텍스트가 아니라 이 구조적 키로 매칭).
- **§6 확인 — 3분기**:
  - `y` → §7 생성 + **cursor를 EOF로 전진** + `lastReportedAt` 갱신.
  - `d` (무시/dismiss) → 생성 안 함 + **cursor를 EOF로 전진**(검토했고 보고 불필요 — 재제안 침묵).
  - `n` (취소) → 생성 안 함 + **cursor 미전진**(다음에 재포착).
- **§7 생성 직후**: cursor 전진(위). race 대비 `gh issue create` **직전 동일 fingerprint 열린 Issue 재조회**(codex 권고) — 있으면 사용자에게 알리고 생성 보류.
- **§제약사항 갱신**: "동일 패턴 Issue 존재 확인 안 함(수동 관리)" → "cursor로 처리 위치 추적(재분석 방지) + 열린 friction Issue fingerprint 힌트(중복 경고). 닫힘 이슈는 cursor 이후 재발만 보고."

### 4.4 운영 사이클(월간) 보조 라인 (harness-cleanup + CLAUDE.md)

- harness-cleanup 월간 루틴(또는 CLAUDE.md 운영 사이클)에 1줄: "하네스 피드백 분석 — `.harness-friction.jsonl`의 cursor 이후 누적 패턴을 harness-feedback로 검토". cursor 기반이라 재실행이 중복 안 만듦.
- **정직 표기**: 세션 종료 트리거(§4.2)가 주 그물망이고, 월간은 보조. "월간만이 유일한 net"으로 광고하지 않음.

### 4.5 harness-scaffold 생성 규칙 (신규 산출물)

- 셋업 시 `.harness-feedback-cursor`를 `{"processedLines": 0, "lastReportedAt": null}`로 **빈 초기값** 생성(jsonl 빈 파일 생성과 평행 — §5.12.1 인접).
- manifest 카테고리 `data` 등록(§5.13·§10.1 파일별 분류 신규 행).
- 생성 순서에 단계 추가.

## 5. 데이터 흐름

```
[세션 중]   마찰 → jsonl append (기존, 변경 없음)
[세션 종료] cursor 이후 미보고 이벤트 평가 → 기준 충족 시 1줄 제안 (신규 §4.2, gh 호출 없음)
              ↓ 사용자가 원하면
[사용자]    "하네스 피드백 분석해줘"
              → cursor 이후만 분석 → 패턴 → (백스톱) gh fingerprint 힌트
              → §6 확인 [y=생성+cursor전진 / d=무시+cursor전진 / n=취소+미전진]
              → (y) create 직전 race 재조회 → gh issue create
[월간]      운영 사이클 → harness-feedback 재실행 (보조 net) → cursor로 중복 안전
```

## 6. degradation / 엣지 케이스

| 상황 | 처리 |
|------|------|
| jsonl 부재 | 트리거·분석 스킵 (에러 아님) |
| jsonl 빈 파일 | 미보고 0 → 제안 없음 |
| 깨진 JSON 라인 | 해당 라인만 스킵 + 경고(이미 harness-feedback 관용 파서 존재). 물리 줄 수엔 포함(cursor가 영구 스킵) |
| cursor 부재 | 전체를 미보고로 평가(첫 실행/업그레이드 — 의도된 백로그 노출) |
| cursor 분실/desync | harness-feedback이 전체 재분석 → §6 사용자 확인이 대량 초안 백스톱(거절 가능) + fingerprint 힌트 |
| `infra-track-entry`(감사 마커) | 마찰 카운트·트리거 기준에서 **제외** |
| unknown event/severity | 카운트 제외 + 경고 |
| gh 미설치/실패 | dedup 힌트 스킵 + 명확 경고. cursor·트리거는 gh 무의존이라 정상 동작 |
| 동시 harness-feedback 실행(race) | fingerprint 힌트 + `gh issue create` 직전 재조회 |
| 팀 다중 개발자 cursor 머지 충돌 | 작은 `processedLines`로 해소(미보고 재포착 안전 방향) |

## 7. 버전 / 마이그레이션

- 신규 `data` 파일(`.harness-feedback-cursor`) + session-routine(managed) 행동 추가 + harness-feedback(컴패니언) 변경 + 운영 사이클 문서. **MINOR (1.22.0)**.
- **마이그레이션 불필요**: cursor 부재를 graceful 처리(전체=미보고)하므로 기존 하네스는 첫 harness-feedback 보고 시 cursor 자동 생성. 업그레이드 직후 첫 세션 종료엔 누적 백로그가 "미보고 N건"으로 표시됨(의도 — #14의 목적). managed(session-routine) 변경은 §12.6 자동 감지로 전파.

## 8. 검증 계획

- **session-routine 트리거**(픽스처): cursor 이후 critical≥1→제안 / high 1건만→무제안(보고 기준 미달) / high 2건(교차세션 누적)→제안 / 미보고 0→무제안 / cursor 부재 시 전체 평가 / infra-track-entry·session-incomplete 제외 카운트 / jsonl 부재 스킵.
- **harness-feedback cursor**(시나리오): cursor 이후만 분석 / y→EOF 전진·lastReportedAt 갱신 / d→전진 무생성 / n→미전진 / cursor 부재→전체 / desync→전체+확인 백스톱.
- **fingerprint dedup**(시나리오): 동일 fp 열린 Issue 有→힌트 표시 / 無→힌트 없음 / 닫힘→cursor 이후만 / gh 실패→힌트 스킵 폴백.
- **골든 픽스처 회귀** + (선택) 적대적 리뷰 워크플로.

## 9. 미해결 / 잔존 갭(정직)

- 순수 drip이 사용자가 매 세션 거절(n)만 하면 매 세션 재제안(정당하나 성가실 수 있음) → `d`(무시)로 침묵 가능. 문서에 안내.
- cursor 분실 시 일시적 대량 재포착 → §6 확인이 백스톱이나 사용자 1회 부담. data 파일이라 커밋되면 분실 드묾.

---

## 참고
- 멀티모델 자문 원본: `.claude/artifacts/consult/codex-…-2026-06-16T22-54-17.md` · `gemini-…-2026-06-16T22-55-14.md`
- 선행: 이슈 #9/TODO-84 (1.18.0 마찰 자동 기록), `.tracking/specs/2026-06-16-friction-auto-logging-design.md`
- harness-feedback 현행: `companion-skills/harness-feedback/SKILL.md`
- session-routine 현행: `templates/rules/session-routine.md § 세션 종료`·`§ 마찰 로그`
