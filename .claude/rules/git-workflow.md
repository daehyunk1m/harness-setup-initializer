---
paths:
  - ".tracking/**"
  - "CLAUDE.md"
---

# Git 워크플로 규칙

이 프로젝트의 git 사용 규칙이다.

## Conventional Commits

모든 커밋 메시지는 다음 형식을 따른다:

```
type(scope): 설명
```

**Type**: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`
**Scope**: `skill`, `templates`, `presets`, `tracking`, `refs`, `docs`, `config`, `repo`

첫 줄 72자 이내. 설명은 한국어.

## 브랜치 네이밍

```
feature/<kebab-case>    # 새 기능
fix/<kebab-case>        # 버그 수정
docs/<kebab-case>       # 문서 변경
refactor/<kebab-case>   # 구조 개선
chore/<kebab-case>      # 설정/도구
```

`main`은 유일한 장기 브랜치이다.

## 커밋 단위

하나의 논리적 변경 = 하나의 커밋. SKILL.md와 관련 템플릿을 같은 TODO에서 함께 수정했으면 하나의 커밋이다. CHANGELOG.md 업데이트는 코드 변경과 같은 커밋에 포함한다.

## CHANGELOG 정책

`.tracking/CHANGELOG.md`는 반자동으로 관리한다:
- `/gc` 커맨드가 diff 기반으로 엔트리를 제안
- 사용자가 확인/수정 후 코드와 atomic commit
- 기존 형식 유지: `### 추가 (Added)` / `### 수정 (Changed)` / `### 수정됨 (Fixed)`
- git log는 기계적 이력, CHANGELOG는 사람 읽기용 — 상호 보완

## 금지 사항

- `git push --force` 사용 금지
- `main` 브랜치에서 직접 `git reset --hard` 금지
- `.claude/settings.local.json` 커밋 금지 (`.gitignore`에 포함됨)
