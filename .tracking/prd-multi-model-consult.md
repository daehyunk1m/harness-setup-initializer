# PRD: 멀티모델 합성 자문 스킬 (multi-model-consult)

> 작성일: 2026-04-14 (초안) / 구체화: 2026-06-12
> 상태: **Confirmed** — 미결정 이슈 5건 해소, CLI 실물 검증 완료 (codex 0.134.0 로컬 실측, gemini-cli 문서 확인). M1+M2 구현 진행
> 참고: oh-my-claudecode `/ccg` 스킬 패턴 — 단, 위험 플래그는 자문 용도에 맞게 폐기 (§ 8)
> 배치 결정: `companion-skills/multi-model-consult/` + install.sh 심볼릭 링크 (~/.claude/skills/ 글로벌 로딩). 하네스 비의존 범용 도구 — 하네스 연계(integrations.multiModelConsult + 통합 규약 일반화)는 스킬 안정화 후 별도 진행

---

## 1. 배경 및 문제 정의

### 1.1 문제
- 단일 모델(Claude)에만 의존하면 특정 관점/편향을 놓칠 수 있다
- 아키텍처 결정, 설계 리뷰, 트레이드오프 분석 등 고난도 작업에서 복수 관점이 필요하다
- 사용자가 직접 Codex/Gemini를 별도로 띄워 비교하는 것은 번거롭다

### 1.2 해결 방향
- Claude Code 안에서 Codex CLI와 Gemini CLI를 호출하고
- Claude가 두 응답을 종합(합의/충돌/최종방향)하여 답변한다
- oh-my-claudecode가 검증한 **"MCP 불필요, Bash + SKILL.md만으로 충분"** 패턴을 차용한다

### 1.3 왜 지금인가
- Codex CLI, Gemini CLI가 모두 성숙하고 API 호환성이 안정적이다
- MCP가 과잉 인프라인 반면, 단순 CLI 스폰으로 충분히 가치를 낼 수 있다
- AAIF(Agentic AI Foundation) 표준화로 CLI 간 상호운용 관행이 정착되었다

---

## 2. 목표

### 2.1 핵심 목표
1. `/consult` 스킬 하나로 Codex + Gemini + Claude 3중 합성 자문 실행
2. 외부 인프라(MCP 서버, 프록시) 없이 순수 스킬 + Bash로 동작
3. 결과는 아티팩트 파일로 감사 가능(audit trail)

### 2.2 비목표 (Non-goals)
- 스트리밍 응답
- Codex/Gemini 응답의 구조화된 JSON 출력
- 세 모델 간 직접 대화(debate) — Claude 단방향 합성만 지원
- 자문 모델의 파일 수정 — 자문은 읽기 전용이다 (codex는 read-only 샌드박스, 컨텍스트는 프롬프트에 포함)

> 초안의 "진정한 병렬 실행" 비목표는 폐기 — Claude의 **병렬 도구 호출**(한 메시지에 Bash 2개)로 별도 인프라 없이 달성된다 (F3.1 조기 해소)

---

## 3. 사용자 및 사용 시나리오

### 3.1 타깃 사용자
- 아키텍처/설계 결정을 자주 내리는 시니어 개발자
- 코드 리뷰에서 다른 관점을 원하는 개발자
- 복잡한 트레이드오프를 분석해야 하는 PM/테크리드

### 3.2 사용 시나리오

**시나리오 A — 아키텍처 결정**
```
/consult "이 프로젝트에 PostgreSQL vs MongoDB 중 어느 쪽이 나을까?
          현재 상태: 쓰기 무거움, 스키마 진화 잦음, 팀 경험은 양쪽 절반씩"
```
→ Codex는 DB 엔진 관점, Gemini는 팀/운영 관점에서 분석, Claude가 종합

**시나리오 B — 코드 리뷰**
```
/consult "이 auth 미들웨어 리뷰해줘" @src/middleware/auth.ts
```
→ Codex: 보안/정확성, Gemini: 가독성/대안, Claude: 합의된 이슈 정리

**시나리오 C — 단일 모델 지정**
```
/consult --to codex "이 SQL 쿼리 최적화 아이디어"
```
→ Codex만 호출, Claude가 응답 요약

---

## 4. 기능 요구사항

### 4.1 MVP (Phase 1)
| ID | 요구사항 | 우선순위 |
|----|---------|---------|
| F1.1 | `/consult <질문>` 스킬 정의 (Codex + Gemini 동시 자문) | P0 |
| F1.2 | Codex CLI 호출 및 아티팩트 저장 | P0 |
| F1.3 | Gemini CLI 호출 및 아티팩트 저장 | P0 |
| F1.4 | Claude가 두 아티팩트를 읽고 합성 답변 생성 | P0 |
| F1.5 | 환경변수 스트립 (Claude 세션 누출 방지) | P0 |
| F1.6 | 한 CLI 부재 시 graceful degradation | P1 |
| F1.7 | 두 CLI 모두 부재 시 Claude 단독 답변 | P1 |

### 4.2 확장 (Phase 2)
| ID | 요구사항 | 우선순위 |
|----|---------|---------|
| F2.1 | 프롬프트 분해 템플릿 (모델 강점별) | P1 |
| F2.2 | 합성 답변 포맷 표준화 (합의/충돌/최종방향/액션) | P1 |
| F2.3 | `--to codex\|gemini\|all` 옵션 | P2 |
| F2.4 | 파일 첨부 지원 (`@path/to/file`) | P2 |
| F2.5 | 외부 LLM 비활성화 스위치 (`disableExternalLLM`) | P1 |

### 4.3 향후 (Phase 3)
| ID | 요구사항 | 우선순위 |
|----|---------|---------|
| F3.1 | 진정한 병렬 실행 (async spawn) | P3 |
| F3.2 | Ollama 등 로컬 모델 지원 | P3 |
| F3.3 | Debate 모드 (모델 간 반복 교환) | P3 |
| F3.4 | 합성 결과 JSON 스키마화 | P3 |

---

## 5. 아키텍처

### 5.1 구성 요소 (구체화 — 2파일로 단순화)

```
companion-skills/multi-model-consult/     # 소스 (harness-setup 저장소)
├── SKILL.md                              # 지시문 + 프롬프트 분해 가이드 + 합성 포맷 (템플릿류는 SKILL.md 섹션으로 통합)
└── scripts/
    └── run-advisor.js                    # CLI 호출 + 환경변수 스트립 + 아티팩트 저장 (핵심)

~/.claude/skills/multi-model-consult → 위 디렉토리 (install.sh 심볼릭 링크)
```

> 초안의 check-cli.js는 SKILL.md의 `!` 전처리 블록(command -v)으로 통합, templates/·references/는 SKILL.md 내 섹션으로 통합 — 파일 수 최소화 (harness-feedback/cleanup 스킬과 동일 스타일)

### 5.2 실행 플로우

```
사용자: /consult "DB 스키마 설계 검토"
  │
  ├─▶ Claude: SKILL.md 읽음
  │
  ├─▶ Claude: 요청 분해
  │     ├─ Codex 프롬프트 (정규화, 인덱싱, 쿼리 패턴)
  │     └─ Gemini 프롬프트 (스키마 진화, 팀 경험, 운영 고려)
  │
  ├─▶ Claude (Bash): node run-advisor.js codex "<prompt>"
  │     └─ 아티팩트: .claude/artifacts/consult/codex-<slug>-<ts>.md
  │
  ├─▶ Claude (Bash): node run-advisor.js gemini "<prompt>"
  │     └─ 아티팩트: .claude/artifacts/consult/gemini-<slug>-<ts>.md
  │
  ├─▶ Claude (Read): 두 아티팩트 읽기
  │
  └─▶ Claude: 종합 답변 생성
        ├─ 합의된 추천
        ├─ 상충하는 관점 (근거 포함)
        ├─ 최종 방향 + 근거
        └─ 액션 체크리스트
```

### 5.3 `run-advisor.js` 핵심 로직 (실물 검증 반영 — codex 0.134.0)

```javascript
// 의사코드 — 정본은 scripts/run-advisor.js
const { spawnSync } = require('child_process');

function buildArgs(provider, prompt, outFile) {
  if (provider === 'codex') {
    // 자문은 읽기 전용: read-only 샌드박스 + 세션 비영속 + 최종 응답 파일 캡처(-o)
    return ['exec', '-s', 'read-only', '--ephemeral', '--skip-git-repo-check',
            '--color', 'never', '-o', outFile, prompt];
  }
  if (provider === 'gemini') {
    return ['-p', prompt];  // 비대화형. --yolo(도구 자동 승인)는 자문에 불필요 — 제거
  }
  throw new Error(`Unknown provider: ${provider}`);
}
```

> **초안 대비 변경**: `--dangerously-bypass-approvals-and-sandbox` **폐기** — codex 도움말 명시 "EXTREMELY DANGEROUS". 자문(읽기 전용)에는 `-s read-only`가 정확한 권한이다. oh-my-claudecode 패턴은 파일 수정 에이전트용이라 과잉 권한이었음. 컨텍스트가 필요한 자문은 Claude가 관련 파일 내용을 프롬프트에 직접 포함한다 (자문 모델에 저장소 쓰기 권한 불필요)

추가 로직 (정본 구현에 포함):
- `stripClaudeEnv`: `CLAUDE*`/`CLAUDECODE` 환경변수 제거 (세션 누출 방지, F1.5)
- `CONSULT_DISABLE_EXTERNAL_LLM=1`이면 즉시 종료 (F2.5 비활성화 스위치)
- 타임아웃: `CONSULT_TIMEOUT_MS` (기본 180000)
- 응답 캡처: codex는 `-o` 파일에서, gemini는 stdout에서 — 아티팩트로 합쳐 저장
- 종료: 성공 시 stdout 마지막 줄 `ARTIFACT: <path>` (Claude가 파싱), 실패 시 exit 1 + 사유

### 5.4 아티팩트 포맷

```markdown
# Consult Artifact — codex

- Timestamp: 2026-04-14T10:23:45Z
- Provider: codex
- Model: (default)
- Exit code: 0

## Original Task
<원본 사용자 요청>

## Final Prompt
<Codex에게 전달된 최종 프롬프트>

## Raw Output
<Codex의 원시 응답>

## Summary (optional)
<Claude가 채우는 요약 — MVP에선 생략 가능>
```

### 5.5 합성 답변 포맷

```markdown
## 합의된 추천
- <두 모델이 모두 지지하는 항목>

## 상충하는 관점
### Codex 관점
- <주장과 근거>

### Gemini 관점
- <주장과 근거>

## 최종 방향
<Claude의 종합 판단 + 근거 — 왜 이 방향을 선택했는지>

## 액션 체크리스트
- [ ] <실행 가능한 항목>
- [ ] ...
```

---

## 6. 사용자 경험 (UX)

### 6.1 호출 방법
```bash
/consult "<질문>"                    # 기본: Codex + Gemini 둘 다
/consult --to codex "<질문>"         # Codex만
/consult --to gemini "<질문>"        # Gemini만
/consult --verbose "<질문>"          # 아티팩트 경로까지 노출
```

### 6.2 에러/경고 메시지
- CLI 미설치: `⚠️ Gemini CLI가 설치되지 않았습니다. Codex와 Claude로만 진행합니다.`
- API 키 없음: `⚠️ OPENAI_API_KEY가 설정되지 않았습니다.`
- 타임아웃: `⚠️ Codex 응답이 180초를 초과했습니다. 부분 결과로 진행합니다.`

### 6.3 진행 표시
- 사용자에게 단계별 진행 상황을 짧게 알림
  - "Codex에게 아키텍처 관점 질의 중..."
  - "Gemini에게 UX 관점 질의 중..."
  - "두 응답을 종합 중..."

---

## 7. 전제조건 및 설치

### 7.1 필수 (실물 검증 — 2026-06-12)
- Node.js 18+
- Codex CLI: `npm install -g @openai/codex` — 인증은 ChatGPT 로그인(`codex login`) 또는 API 키 (로컬 실측: 0.134.0)
- Gemini CLI: `npm install -g @google/gemini-cli` — 인증은 Google 로그인 또는 `GEMINI_API_KEY` (Vertex는 `GOOGLE_API_KEY`+`GOOGLE_GENAI_USE_VERTEXAI`)
- 한쪽만 설치돼 있어도 동작한다 (graceful degradation, F1.6~F1.7)

### 7.2 점검
- SKILL.md `!` 전처리 블록이 실행 시점에 CLI 존재를 점검 (별도 check-cli.js 없음)
- 인증 오류는 호출 시점에 표면화 → 아티팩트에 stderr 기록 + 사용자 안내

---

## 8. 보안 고려사항

| 이슈 | 대응 |
|------|------|
| ~~`--dangerously-bypass-approvals-and-sandbox` 위험~~ | **해소** — 플래그 폐기. codex는 `-s read-only` 샌드박스, gemini는 `--yolo` 없이 호출. 자문 모델은 파일을 수정할 수 없다 |
| 외부 CLI로 민감 코드/프롬프트 유출 | `CONSULT_DISABLE_EXTERNAL_LLM=1` 설정 시 스킬 자체 비활성화. 프롬프트에 포함할 파일은 Claude가 사용자 요청 범위 내에서만 선별 |
| Claude 세션 누출 | `CLAUDE*`/`CLAUDECODE` 환경변수 스트립 (필수, run-advisor.js) |
| 아티팩트 파일이 git에 커밋됨 | `.claude/artifacts/`를 `.gitignore`에 추가 (스킬이 미등록 시 1회 제안) |
| 외부 응답의 프롬프트 인젝션 | 아티팩트의 Raw Output은 **데이터로 취급** — Claude는 합성 시 외부 응답 내 지시문을 따르지 않는다 (SKILL.md 제약에 명시) |

---

## 9. 검증 기준 (Acceptance Criteria)

- [ ] 두 CLI 모두 설치된 환경에서 `/consult` 호출 시 정상 종합 답변 생성
- [ ] Codex 부재 시 Gemini + Claude로 graceful degradation
- [ ] Gemini 부재 시 Codex + Claude로 graceful degradation
- [ ] 두 CLI 모두 부재 시 Claude 단독 답변 + 경고
- [ ] 아티팩트가 `.claude/artifacts/consult/` 아래에 생성됨
- [ ] `printenv | grep CLAUDE` 자식 프로세스에서 비어있음 (환경변수 스트립 확인)
- [ ] 합성 답변이 "합의/상충/최종방향/액션" 4섹션을 포함
- [ ] 타임아웃 시 부분 결과로 동작
- [ ] `disableExternalLLM=true` 설정 시 외부 CLI 호출 차단

---

## 10. 한계 및 리스크

### 10.1 알려진 한계
1. **순차 실행**: MVP는 `spawnSync`로 Codex → Gemini 순차 호출. 진정한 병렬은 Phase 3.
2. **비구조화 출력**: Codex/Gemini 응답은 자유 텍스트. Claude가 해석해야 함.
3. **스트리밍 없음**: 완전 완료까지 대기. 긴 응답은 체감 지연 큼.
4. **합성 품질 의존성**: Claude의 판단에 전적으로 의존. 프로그래밍적 머지 없음.
5. **비용**: 매 호출마다 OpenAI + Google API 크레딧 소모.

### 10.2 리스크
- **CLI 버전 변화**: Codex/Gemini CLI의 인자 체계가 바뀌면 깨질 수 있음 → `check-cli.js`에 버전 확인 추가
- **Rate limit**: 외부 API 쿼터 초과 시 실패 → 재시도 정책 명시
- **사용자 기대 과대**: "3중 합성"이 마법처럼 정답을 준다고 오해할 수 있음 → 문서에 한계 명시

---

## 11. 마일스톤

### M1 — MVP (목표: 1일)
- [ ] SKILL.md 초안
- [ ] `run-advisor.js` 기본 구현
- [ ] Codex + Gemini 호출 및 아티팩트 저장
- [ ] Claude 합성 답변 (포맷은 자유)
- [ ] 수동 테스트

### M2 — Polish (목표: 0.5일)
- [ ] 프롬프트 분해 템플릿 (모델 강점 반영)
- [ ] 합성 답변 포맷 표준화
- [ ] CLI 설치 여부 점검 스크립트
- [ ] Graceful degradation 3가지 경로 검증
- [ ] 문서화 (README, 사용 예시)

### M3 — Advanced (보류)
- [ ] `--to` 옵션
- [ ] `@file` 첨부
- [ ] 병렬 실행
- [ ] 로컬 모델 지원

---

## 12. 참고 자료

### 12.1 원본 소스
- **oh-my-claudecode**: https://github.com/Yeachan-Heo/oh-my-claudecode
  - `skills/ccg/SKILL.md` — 3중 합성 스킬 정의
  - `scripts/run-provider-advisor.js` — CLI 호출 핵심 로직
  - `src/cli/ask.ts` — CLI 엔트리포인트
  - `src/team/model-contract.ts` — 프로바이더별 launch args

### 12.2 공식 문서
- Claude Code Hooks: https://code.claude.com/docs/en/hooks
- Claude Code MCP: https://code.claude.com/docs/en/mcp
- Codex CLI: `@openai/codex` npm 패키지
- Gemini CLI: `@google/gemini-cli` npm 패키지

### 12.3 관련 선행 리서치
- 이전 세션 대화 — Claude Code 멀티모델 통합 방법 조사 (MCP 서버 브릿지, AAIF 표준화 등)

---

## 13. 결정 기록 (구 미결정 이슈 — 2026-06-12 전부 해소)

| # | 질문 | 결정 | 근거 |
|---|------|------|------|
| 1 | 스킬 배치 위치 | `companion-skills/multi-model-consult/` + install.sh 심볼릭 링크 (~/.claude/skills/ 글로벌 로딩) | 저장소·버전·배포 일원화, 추후 하네스 연계 용이. 범용 도구임은 README/SKILL.md에 명시. (사용자 결정) |
| 2 | 하네스 통합 시점 | 자동 설치 X. `integrations.multiModelConsult` 연계 + 통합 규약 일반화는 **스킬 안정화 후 별도 릴리스** | 연계 가치가 AGENTS.md 보조 스킬 한 줄 수준이라 급하지 않음. superpowers 때 "두 번째 통합 시 규약 일반화" 결정과 합류. (사용자 결정) |
| 3 | 아티팩트 보존 정책 | 사용자 수동 관리 + `.claude/artifacts/`를 .gitignore에 (스킬이 미등록 시 1회 제안). harness-cleanup의 잔존물 스캔 대상 아님 (의도된 산출물) | 자동 만료는 감사 추적(audit trail) 가치와 충돌 |
| 4 | 기본 타임아웃 | 180초, `CONSULT_TIMEOUT_MS` 환경변수로 오버라이드 (provider 공통) | provider별 차등은 실사용 데이터 없이는 추측 설계 |
| 5 | 아티팩트 경로 노출 | **기본 노출** — 합성 답변 하단에 경로 2줄. `--verbose` 플래그 폐기 | 감사 추적이 핵심 가치인데 숨길 이유 없음 |

추가 결정 (실물 검증 기반):
- **위험 플래그 폐기**: codex `--dangerously-bypass-approvals-and-sandbox` → `-s read-only --ephemeral`, gemini `--yolo` 제거 — 자문은 읽기 전용 (§ 5.3, § 8)
- **codex `-o` 활용**: 최종 응답을 파일로 직접 캡처 (stdout 이벤트 스크래핑 불필요)
- **병렬 실행**: Claude의 병렬 도구 호출(한 메시지에 Bash 2개)로 달성 — async 인프라 불필요 (F3.1 조기 해소)
- **check-cli.js·templates/ 폐지**: SKILL.md `!` 전처리 + 본문 섹션으로 통합 (2파일 구조)
