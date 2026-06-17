# 모델 선택 가이드 — 하네스 환경에서의 Opus vs Sonnet

> 리서치 일자: 2026-04-09

## 요약

Sonnet 4.6이 하네스 환경 일상 작업의 80-90%를 충분히 커버한다. 잘 구성된 하네스(CLAUDE.md, rules, hooks, subagents)는 Sonnet의 효과를 증폭시키지만, 가장 어려운 문제에서 Opus를 완전히 대체하진 못한다. **"바닥을 올려주지, 천장을 올려주진 않는다."**

## 1. 벤치마크 데이터

| 모델 | SWE-bench Verified | 입력 가격 (per 1M) | 출력 가격 (per 1M) |
|---|---|---|---|
| Opus 4.6 | 80.8% | $15 | $75 |
| Sonnet 4.6 | 79.6% | $3 | $15 |

- 격차: 1.2%p, 비용: 5배 차이
- MCP-Atlas(도구 사용 벤치마크)에서는 Sonnet이 Opus보다 앞섬 — 에이전틱 도구 호출에 특화 튜닝된 것으로 추정
- Sonnet 4.6은 개발자 59%가 Opus 4.5보다 선호, 70%가 Sonnet 4.5보다 선호

### 실제 프로젝트 비교 (Tensorlake 테스트)

| | Opus | Sonnet |
|---|---|---|
| 완료 시간 | 20분 | 34분 |
| 비용 | ~$1.00 | ~$0.87 |
| 출력 토큰 | 기준 | 59% 더 많음 |
| 디버깅 효율 | 우수 — 에러 복구 효율적 | 더 많은 시행착오 |

## 2. Anthropic 공식 가이드

> "특별한 이유가 없으면 Sonnet을 기본으로 써라 — 대부분의 엔터프라이즈 사용 사례에 적합하고, 불확실할 때 가장 안전한 출발점이다."

### 모델별 포지셔닝

- **Opus 4.6**: 전문 소프트웨어 엔지니어링, 고급 에이전트, 수시간 리서치 작업
- **Sonnet 4.6**: 코드 생성, 데이터 분석, 콘텐츠 생성, 에이전틱 도구 사용

### Claude Code 기본 모델 배정

- Pro / Team Standard → **Sonnet** (기본)
- Max / Team Premium → **Opus**

### 권장 접근법

가장 강력한 모델로 시작 → 프롬프트 최적화 → 워크플로 최적화가 진행될수록 더 효율적인(저렴한) 모델로 전환

## 3. 하네스가 Sonnet 효과를 높이는 메커니즘

| 하네스 구성요소 | Sonnet에 주는 이점 |
|---|---|
| Rules / CLAUDE.md | 일관된 컨텍스트 제공 → 맥락 유지 능력 보완 |
| Hooks | 오케스트레이션 자동화 → 인지 부하 감소 |
| Subagents | 잘 스코핑된 프롬프트 → 구조화된 작업에서 Sonnet 강점 극대화 |
| AGENTS.md | 아키텍처 가이드 → 약 4% 성과 향상 관측 |

### 근거

- Anthropic 컨텍스트 엔지니어링 블로그: "더 똑똑한 모델은 덜 처방적인 엔지니어링이 필요하다" → 역으로, 더 처방적인 엔지니어링(좋은 하네스)은 덜 똑똑한 모델의 효과를 높인다
- Spark Agents 분석: "Sonnet 4.6은 구조화된 워크플로에서 강하지만, 높은 인지 부하에서 일관성 유지를 위해 더 명시적인 스캐폴딩이 필요할 수 있다"
- 실무 관측: "잘 프롬프팅된 Sonnet이 게으르게 프롬프팅된 Opus를 매번 이긴다"
- Addy Osmani: "스펙이 레버리지다. 모호한 요구사항은 병렬 에이전트 간 에러를 곱하고, 정밀한 스펙은 저렴한 모델로도 우수한 결과를 낸다"

### 한계

- ETH Zurich 연구: 지시사항은 "바닥을 올려주지, 천장을 올려주진 않는다" — 어려운 작업에서 일관성은 높이지만, 작은 모델이 큰 모델을 따라잡게 하진 않는다
- 프론티어 모델은 약 150-200개 지시사항까지 안정적으로 따르며, 그 이상은 성능 저하 — 최적 CLAUDE.md는 60줄 이하 + 온디맨드 스킬 로딩

## 4. `opusplan` — 하이브리드 전략

Anthropic이 Claude Code에 내장한 공식 하이브리드 모드:

- **계획 단계**: Opus로 복잡한 추론과 아키텍처 결정
- **실행 단계**: 자동으로 Sonnet 전환하여 코드 생성과 구현
- 비용 3-4배 절감, 구현 품질은 "구분 불가" 수준

## 5. 실전 모델 라우팅 전략

| 작업 유형 | 추천 모델 | 근거 |
|---|---|---|
| 파일 탐색, 단순 조회 | Haiku | 빠르고 저렴, read-only 충분 |
| 기능 구현, 테스트 작성, 버그 수정 | Sonnet | 일상 코딩의 80%, 구조화된 작업에 강함 |
| 대규모 리팩토링 (10+ 파일) | Opus | 파일 간 조율, 전체 아키텍처 일관성 |
| 아키텍처 결정, 보안 감사 | Opus | 경쟁하는 제약조건 간 판단 필요 |
| 모호한/과소명세 작업 | Opus | 더 나은 명확화 질문, 깊은 추론 |
| 계획은 깊게 + 실행은 빠르게 | opusplan | 공식 하이브리드, 최적 비용/성능 |

### Claude Code 서브에이전트 라우팅

- 내장 Explore 에이전트: Haiku로 동작
- 커스텀 서브에이전트: 프론트매터에 `model: haiku` 또는 `model: sonnet` 지정 가능
- `CLAUDE_CODE_SUBAGENT_MODEL` 환경변수로 전체 서브에이전트 모델 일괄 지정
- 권장 패턴: 메인 세션 Opus, 구현 서브에이전트 Sonnet, 탐색 서브에이전트 Haiku

## 6. 커뮤니티 합의

> "모든 작업을 Sonnet으로 시작해라. Sonnet 출력이 부정확하거나, 불완전하거나, 아키텍처 결정에 자신이 없을 때만 Opus로 에스컬레이션하라." — NxCode

> "Opus는 비싼 게 아니라 과다 사용되는 것이다." — Spark Agents

> "Sonnet은 개별 함수 작성, 테스트 생성, 격리된 버그 수정, 인라인 코드 제안, 스캐폴딩에서 Opus와 동등하거나 앞선다 — 이게 일상 업무의 80%다." — 커뮤니티 분석

> "Sonnet 4.6은 Opus 4.6보다 저렴하면서 Opus 수준 지능에 근접하며, 초기 테스트에서 엔지니어들이 Opus 4.5보다 선호하는 경우가 많았다." — Boris Cherny (Anthropic)

## 7. 하네스-셋업 스킬 맥락에서의 시사점

하네스의 ROI는 모델 비용 절감에서도 나타난다:

1. 잘 짜인 하네스일수록 **더 저렴한 모델로도 높은 품질 유지** 가능
2. 하네스 설계/분석 자체는 Opus가 유리 (모호한 입력, 다단계 분석)
3. 하네스로 생성된 파일을 사용하는 일상 작업은 Sonnet으로 충분
4. 서브에이전트 모델 라우팅을 하네스에 내장하면 자동 비용 최적화

## 출처

- [Claude Code 모델 설정 문서](https://code.claude.com/docs/en/model-config)
- [모델 선택 가이드 — Anthropic Docs](https://platform.claude.com/docs/en/about-claude/models/choosing-a-model)
- [Claude Code 서브에이전트 문서](https://code.claude.com/docs/en/sub-agents)
- [효과적인 컨텍스트 엔지니어링 — Anthropic Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Claude Opus vs Sonnet 결정 가이드 2026 — NxCode](https://www.nxcode.io/resources/news/claude-opus-or-sonnet-for-coding-decision-guide-2026)
- [Sonnet vs Opus 비교 2026 — NxCode](https://www.nxcode.io/resources/news/claude-sonnet-4-6-vs-opus-4-6-which-model-to-choose-2026)
- [Claude Sonnet vs Opus — Emergent](https://emergent.sh/learn/claude-sonnet-vs-opus)
- [Claude Sonnet vs Opus — Spark Agents](https://www.sparkagents.com/blog/claude-sonnet-vs-opus)
- [Opus 4.6 vs Sonnet 4.6 코딩 비교 — Tensorlake / DEV](https://dev.to/tensorlake/claude-opus-46-vs-sonnet-46-coding-comparison-55jn)
- [코드 에이전트 오케스트라 — Addy Osmani](https://addyosmani.com/blog/code-agent-orchestra/)
- [Claude Code 2.0 가이드 — Sankalp](https://sankalp.bearblog.dev/my-experience-with-claude-code-20-and-how-to-get-better-at-using-coding-agents/)
- [CLAUDE.md 베스트 프랙티스 — Lakshmi Narasimhan](https://blog.lakshminp.com/p/claude-md-best-practices)
- [모델 개요 — Anthropic Docs](https://platform.claude.com/docs/en/about-claude/models/overview)
- [Boris Cherny — Sonnet 4.6 in Claude Code (Threads)](https://www.threads.com/@boris_cherny/post/DU3vZ8eEevf/)
- [Multi-Agent Routing in Claude Code — BSWEN](https://docs.bswen.com/blog/2026-03-22-claude-code-multi-agent-routing/)
