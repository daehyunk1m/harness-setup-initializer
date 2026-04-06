# Git 워크플로

이 프로젝트에서 에이전트가 git을 사용할 때 따라야 하는 규칙이다.

---

## Conventional Commits

커밋 메시지 형식:

```
type(scope): 설명
```

**Type**: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`
**Scope**: {{COMMIT_SCOPES}}

첫 줄 72자 이내. 설명은 {{COMMIT_LANG_LABEL}}.

---

## 커밋 단위

- 하나의 논리적 변경 = 하나의 커밋 (코드는 항상 빌드 가능 상태)
- TDD 사이클 내 권장 커밋 시점:
  - Red 완료 후: `test({scope}): {description} 실패 테스트 작성 - {featureID}`
  - Green 완료 후: `feat({scope}): {description} 구현 - {featureID}`
  - Refactor 완료 후: `refactor({scope}): {description} 리팩터링 - {featureID}`
- feature_list.json, claude-progress.txt 변경은 코드 변경과 동일 커밋에 포함

---

## 체크포인트 커밋

다음 시점에 반드시 커밋을 제안한다:

1. TDD 사이클의 각 phase 완료 후 (Red / Green / Refactor)
2. 세션 종료 시 (미커밋 변경이 있을 때)
3. 위험한 작업 전 (대규모 리팩터링, 의존성 변경)

체크포인트 커밋 형식: `chore({scope}): checkpoint — {상태 설명}`

---

## 브랜치

### 네이밍

```
{{BRANCH_PREFIX_POLICY_FORMATTED}}
```

`{{MAIN_BRANCH}}`은 유일한 장기 브랜치이다.

### 생성 시점

- 새 feature 시작 시: `feature/{featureID}-{kebab-description}` 생성 (선택)
- 대규모 변경 시 (5+ 파일, 100+ 줄): 반드시 브랜치 분리
- 단순 수정 (1~2 파일, 30줄 이하): {{MAIN_BRANCH}}에서 직접 작업 가능

### 정리

- feature 완료 후 {{MAIN_BRANCH}}에 merge된 브랜치는 삭제를 제안한다
- merge 방식: rebase 후 fast-forward merge 선호 (이력 깔끔)
- rebase 불가 시 (충돌 과다): merge commit 허용

---

## 충돌 해결

### Level 1 — 자동 해결
공백, 포맷팅, import 순서 등 의미 없는 차이 → 에이전트가 직접 해결.

### Level 2 — 에이전트 판단
에이전트가 작성/수정한 파일의 내용 충돌 → 양쪽 변경 맥락을 확인 후 해결.

### Level 3 — 사용자 에스컬레이션
다음 경우 사용자에게 보고하고 판단을 요청한다:
- 에이전트가 작성하지 않은 파일의 충돌
- 3개 이상 파일에 걸친 복합 충돌
- 비즈니스 로직 판단이 필요한 충돌

충돌 해결 후 반드시 `{{VALIDATE_COMMAND}}`를 실행하여 회귀를 확인한다.

---

## 세션 경계

### 세션 시작
1. `git status`로 미커밋 변경 확인 — 있으면 사용자에게 알린다
2. `git log --oneline -10`으로 최근 이력 확인
3. claude-progress.txt의 TDD STATE 블록과 git 이력의 정합성 확인

### 세션 종료
1. 미커밋 변경이 있으면 커밋을 제안한다:
   - TDD 사이클 완료 시: feat 커밋
   - 사이클 미완료 시: checkpoint 커밋
2. 코드는 반드시 빌드 가능한 상태여야 한다
3. `{{VALIDATE_COMMAND}}` 통과 후 커밋 제안

---

## 금지 사항

- `git push --force` 사용 금지
- `git reset --hard` 무단 사용 금지
- `--no-verify` 옵션 사용 금지
- `.claude/settings.local.json` 커밋 금지
- 사용자 확인 없이 git 명령을 실행하지 않는다 (제안만 한다)
