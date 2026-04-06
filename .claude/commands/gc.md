---
description: 변경사항 분석 → 커밋 메시지 생성 → CHANGELOG 업데이트 → git commit
argument-hint: [커밋 메시지 힌트]
allowed-tools: [Read, Edit, Glob, Grep, Bash]
model: sonnet
---

# Git Commit

변경사항을 분석하고, Conventional Commit 메시지를 생성하고, `.tracking/CHANGELOG.md`를 업데이트한 뒤 커밋한다.

사용자 입력: $ARGUMENTS

## 실행 절차

### Step 1: 변경사항 수집

다음 명령을 실행한다:

```bash
git status
git diff --cached --stat
git diff --stat
```

- 커밋할 변경사항이 없으면 "커밋할 변경사항이 없습니다." 출력 후 종료
- staged 변경이 없고 unstaged 변경만 있으면 → 사용자에게 어떤 파일을 stage할지 확인

### Step 2: Diff 분석

staged된 diff를 읽는다:

```bash
git diff --cached
```

변경된 파일을 아래 테이블로 scope 분류:

| 경로 패턴 | Scope |
|-----------|-------|
| `SKILL.md` | `skill` |
| `templates/**` | `templates` |
| `presets/**` | `presets` |
| `.tracking/**` | `tracking` |
| `references/**` | `refs` |
| `CLAUDE.md`, `README.md` | `docs` |
| `.claude/**` | `config` |
| `.gitignore`, 기타 루트 파일 | `repo` |

변경 유형을 type으로 분류:

| 변경 유형 | Type |
|-----------|------|
| 새 파일 추가 | `feat` |
| 기존 파일 구조/로직 변경 | `refactor` |
| 버그 수정 | `fix` |
| 문서만 변경 | `docs` |
| 설정/빌드/도구 | `chore` |

- scope가 여러 개면 지배적인 것 하나를 고르거나, 2개까지 콤마로 연결 (`skill,templates`)
- `$ARGUMENTS`가 있으면 커밋 메시지 설명에 힌트로 활용

### Step 3: 커밋 메시지 생성

형식: `type(scope): 설명`

규칙:
- 첫 줄 72자 이내
- 설명은 한국어
- 필요 시 본문을 빈 줄 뒤에 추가 (상세 변경 내용)

### Step 4: CHANGELOG 엔트리 제안

`.tracking/CHANGELOG.md`를 읽고, `## [미출시]` 섹션 아래 적절한 카테고리에 엔트리를 제안한다.

카테고리 매핑:
- `feat` → `### 추가 (Added)`
- `refactor`, `chore` → `### 수정 (Changed)`
- `fix` → `### 수정됨 (Fixed)`

엔트리 형식: `- 파일명: 변경 설명`

기존 엔트리 스타일을 최대한 따른다.

### Step 5: 사용자 확인

다음을 사용자에게 보여준다:

```
📋 커밋 메시지:
type(scope): 설명

📝 CHANGELOG 엔트리:
- 파일명: 변경 설명

진행할까요? (y/수정사항 입력)
```

사용자가 수정을 요청하면 반영한다.

### Step 6: 커밋 실행

1. `.tracking/CHANGELOG.md` 파일을 수정 (엔트리 추가)
2. `git add .tracking/CHANGELOG.md`
3. `git commit -m "메시지"`
4. `git log --oneline -3` 결과 출력

## 제약 사항

- `git push`는 하지 않는다 (push는 `/gs push` 사용)
- `--force` 옵션 절대 사용 금지
- `.claude/settings.local.json`은 커밋하지 않는다
- `$ARGUMENTS`에 "amend"가 포함되면 `git commit --amend` 사용
