# PRD: 멀티모델 합성 자문 스킬 (multi-model-consult)

> 작성일: 2026-04-14
> 상태: Draft — 추후 구현 대기
> 참고: oh-my-claudecode `/ccg` 스킬 패턴

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
- 진정한 병렬 실행 (MVP는 순차)
- 스트리밍 응답
- Codex/Gemini 응답의 구조화된 JSON 출력
- 세 모델 간 직접 대화(debate) — Claude 단방향 합성만 지원

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

### 5.1 구성 요소

```
~/.claude/skills/multi-model-consult/
├── SKILL.md                      # Claude에게 주는 지시문
├── scripts/
│   ├── run-advisor.js            # CLI 호출 + 아티팩트 저장 (핵심)
│   └── check-cli.js              # CLI 설치 여부 확인
├── templates/
│   ├── codex-prompt.md           # Codex용 프롬프트 템플릿
│   ├── gemini-prompt.md          # Gemini용 프롬프트 템플릿
│   └── synthesis-format.md       # 합성 답변 포맷
└── references/
    └── model-strengths.md        # 모델별 강점 가이드
```

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

### 5.3 `run-advisor.js` 핵심 로직

```javascript
// 의사코드
const { spawnSync } = require('child_process');

function buildArgs(provider, prompt) {
  if (provider === 'codex') {
    return ['exec', '--dangerously-bypass-approvals-and-sandbox', prompt];
  }
  if (provider === 'gemini') {
    return ['-p', prompt, '--yolo'];
  }
  throw new Error(`Unknown provider: ${provider}`);
}

function stripClaudeEnv(env) {
  const cleaned = { ...env };
  for (const key of Object.keys(cleaned)) {
    if (key.startsWith('CLAUDE') || key === 'CLAUDECODE') {
      delete cleaned[key];
    }
  }
  return cleaned;
}

function run(provider, prompt) {
  const binary = provider; // 'codex' or 'gemini'
  const args = buildArgs(provider, prompt);
  const result = spawnSync(binary, args, {
    env: stripClaudeEnv(process.env),
    encoding: 'utf-8',
    timeout: 180_000,
  });
  const artifactPath = writeArtifact(provider, prompt, result);
  console.log(artifactPath); // Claude가 stdout에서 경로 파싱
}
```

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

### 7.1 필수
- Node.js 18+
- Codex CLI: `npm install -g @openai/codex` + `OPENAI_API_KEY`
- Gemini CLI: `npm install -g @google/gemini-cli` + `GOOGLE_API_KEY` (또는 `GEMINI_API_KEY`)

### 7.2 선택
- 스킬 설치 시 자동으로 CLI 설치 여부를 점검하고 안내

---

## 8. 보안 고려사항

| 이슈 | 대응 |
|------|------|
| `--dangerously-bypass-approvals-and-sandbox` 플래그 위험 | 문서에 명시 + 옵션으로 비활성화 가능 |
| 외부 CLI로 민감 코드/프롬프트 유출 | `disableExternalLLM=true` 설정 시 스킬 자체 비활성화 |
| Claude 세션 누출 | `CLAUDE*` 환경변수 스트립 (필수) |
| 아티팩트 파일이 git에 커밋됨 | `.claude/artifacts/` 를 `.gitignore`에 추가 |
| 프롬프트 인젝션 | 프롬프트는 사용자 입력 그대로 전달, 변환 없음 (책임은 사용자) |

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

## 13. 미결정 이슈 (Open Questions)

1. **스킬 배치 위치**: harness-setup의 companion-skill로 둘지, 독립 스킬로 둘지?
2. **하네스 통합**: 하네스 셋업 시 이 스킬을 자동으로 설치할지, 옵션으로 둘지?
3. **아티팩트 보존 정책**: 언제 삭제? 사용자가 직접 관리? 자동 만료?
4. **기본 타임아웃**: 180초가 적절한가? 모델별로 다르게?
5. **합성 답변에 원본 응답 링크 포함 여부**: 아티팩트 경로를 사용자에게 노출할지?

이 질문들은 구현 착수 시 사용자와 확인 후 결정한다.
