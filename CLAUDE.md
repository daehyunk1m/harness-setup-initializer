# harness-setup 스킬 개발 지침

이 폴더는 **하네스 셋업 스킬**의 소스이다. 스킬 자체를 개발/개선하는 작업 환경이다.

## 세션 시작

1. `.tracking/HANDOFF.md` 읽기 — 현재 상태, 남은 작업, 설계 결정
2. `.tracking/TODO.md` 훑기 — 미완료 항목 확인
3. `references/project-context.md` § 핵심 원칙 확인

## 파일 맵

| 파일 | 역할 | 수정 빈도 |
|------|------|----------|
| `SKILL.md` | **스킬 본체** — 스킬 실행 시 유일하게 로딩되는 사양 | 높음 |
| `presets/*.json` | 스택별 프리셋 | 가끔 |
| `templates/agents/*.md` | TDD subagent 정의 템플릿 | 가끔 |
| `templates/rules/*.md` | .claude/rules/ 템플릿 (session-routine, coding-standards, git-workflow) | 가끔 |
| `templates/structural-test-*.ts` | 아키텍처 검증 템플릿 | 낮음 |
| `references/harness-guide.md` | 이론적 기반 (Anthropic + OpenAI) — 수정 거의 안 함 | 낮음 |
| `references/project-context.md` | 설계 결정, 버전 히스토리, 다음 단계 | 작업 후 |
| `.tracking/HANDOFF.md` | 세션 간 핸드오프 — 현재 상태 + 남은 작업 | 작업 후 |
| `.tracking/CHANGELOG.md` | 상세 변경 이력 | 작업 후 |
| `.tracking/TODO.md` | 개선 항목 추적 | 작업 후 |

## 개발 규칙

### SKILL.md 수정 시
- SKILL.md가 **정규 사양**이다. harness-guide.md와 충돌하면 SKILL.md가 우선
- 기존 섹션 번호를 변경할 때는 내부 참조(다른 섹션에서 "섹션 X.Y 참조"하는 곳)를 모두 업데이트
- 생성 순서(Phase 2)를 바꾸면 의존 관계가 깨지지 않는지 확인

### 템플릿 수정 시
- 플레이스홀더 패턴: `{{UPPER_SNAKE_CASE}}` — 예: `{{VALIDATE_COMMAND}}`
- 새 플레이스홀더를 추가하면 SKILL.md의 치환 규칙 테이블에도 반드시 추가
- 기존 템플릿의 동작을 바꿀 때는 프리셋과의 정합성 확인

### 프리셋 수정 시
- 스키마를 바꾸면 SKILL.md § 프리셋 스키마 + § 커스텀 프리셋 작성 가이드도 업데이트
- 모든 기존 프리셋이 새 스키마와 호환되는지 확인

## Git 워크플로

### 커밋 규칙
- 형식: `type(scope): 설명`
- 타입: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`
- 스코프: `skill`, `templates`, `presets`, `tracking`, `refs`, `docs`, `config`, `repo`
- 첫 줄 72자 이내, 설명은 한국어

### 커맨드
- `/gc [힌트]` — 변경사항 분석 → 커밋 메시지 생성 → CHANGELOG 업데이트 → 커밋
- `/gs status` — 현재 git 상태 요약
- `/gs push` — 원격에 push
- `/gs branch <name>` — 브랜치 생성 (`feature/`, `fix/`, `docs/` 등 접두사)
- `/gs checkpoint` — 세션 종료 시 트래킹 파일 포함 커밋 + push

### 브랜치 규칙
- `main`: 유일한 장기 브랜치
- 기능 개발: `feature/<name>`, 버그 수정: `fix/<name>`, 문서: `docs/<name>`

## 테스트

```bash
# 실전 테스트 (실제 프로젝트에서 스킬 실행)
cd ~/projects/haja && claude --add-dir ~/.claude/skills/harness-setup
# → "하네스 셋업해줘" 또는 "/harness-setup"

# 정합성 검사 (수동)
# 1. 템플릿의 {{...}} 패턴이 SKILL.md 치환 규칙에 모두 정의되어 있는가
# 2. SKILL.md의 생성 파일 목록과 실제 templates/ 구조가 일치하는가
# 3. 프리셋의 필드가 SKILL.md 프리셋 스키마와 일치하는가
```

## 세션 종료 — 트래킹

작업 완료 후 반드시 다음 파일을 업데이트한다:

1. **`.tracking/HANDOFF.md`** — 현재 상태 반영, P1-P10 커버리지 테이블 갱신, 남은 작업 업데이트
2. **`.tracking/CHANGELOG.md`** — 변경 사항 기록 (Added/Changed/Fixed 분류)
3. **`references/project-context.md`** — 새 설계 결정이 있으면 § 설계 결정 사항에 추가, 버전 히스토리 갱신
4. **`.tracking/TODO.md`** — 완료 항목 체크, 새로 발견한 이슈 추가
5. **`/gs checkpoint`** — 트래킹 파일 포함 커밋 + push

## 핵심 원칙

1. 하네스는 스택에 종속되지 않는다
2. 기존 소스 코드를 수정하지 않는다 (대상 프로젝트의)
3. SKILL.md 한 파일이 스킬의 전체 사양이다
4. 프리셋이 없어도 동작한다
5. 리뷰에서 반복되는 문제는 자동 검사로 승격한다
