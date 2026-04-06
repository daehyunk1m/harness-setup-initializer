---
description: Git 동기화 — status, push, branch 생성, 세션 체크포인트
argument-hint: status | push | branch <name> | checkpoint
allowed-tools: [Read, Edit, Glob, Grep, Bash]
model: sonnet
---

# Git Sync

Git 동기화 작업을 처리한다: 상태 확인, push, 브랜치 생성, 세션 종료 체크포인트.

사용자 입력: $ARGUMENTS

## 서브커맨드 분기

`$ARGUMENTS`의 첫 단어로 서브커맨드를 결정한다. 비어 있으면 `status`.

---

### status (기본)

다음을 실행하고 요약 보고한다:

```bash
git status
git log --oneline -5
git branch -a
git rev-list --left-right --count HEAD...@{u} 2>/dev/null || echo "no upstream"
```

보고 형식:
```
🔀 브랜치: main
📊 상태: clean / N개 파일 수정
🔄 Remote: N commits ahead, M behind (또는 동기화됨)
📜 최근 커밋:
  - abc1234 feat(skill): ...
  - def5678 docs(docs): ...
```

---

### push

1. remote tracking 브랜치 확인: `git rev-parse --abbrev-ref @{u} 2>/dev/null`
2. tracking 있으면 → `git push`
3. tracking 없으면 → `git push -u origin $(git branch --show-current)`
4. 결과 보고

---

### branch \<name\>

`$ARGUMENTS`에서 "branch" 다음 단어를 브랜치 이름으로 사용한다.

1. 브랜치 이름 검증:
   - 접두사가 `feature/`, `fix/`, `docs/`, `refactor/`, `chore/` 중 하나인지 확인
   - 접두사가 없으면 변경 유형을 추론하거나 사용자에게 확인
   - 나머지 부분은 kebab-case 여야 함 (소문자, 숫자, 하이픈만)
2. `git checkout -b <name>` 실행
3. 결과 보고: `🌿 브랜치 생성: feature/entropy-management`

---

### checkpoint

세션 종료 시 사용하는 종합 커맨드.

1. `git status`로 미커밋 변경 확인
2. 변경이 있으면:
   a. 모든 변경사항 stage: `git add -A`
   b. `.gitignore` 대상은 자동 제외됨을 확인
   c. 커밋 메시지: `chore(tracking): session checkpoint — YYYY-MM-DD`
   d. `git commit` 실행
3. remote push: `git push` (tracking 없으면 `-u origin`)
4. 최종 상태 보고

```
✅ 세션 체크포인트 완료
  커밋: abc1234 chore(tracking): session checkpoint — 2026-04-06
  Push: origin/main ← main (동기화됨)
```

## 제약 사항

- `--force` 옵션 절대 사용 금지
- `main` 브랜치 삭제 금지
- `checkpoint`은 `.tracking/` 파일이 최신 상태인지 확인하지 않음 — 사용자가 미리 업데이트해야 함
