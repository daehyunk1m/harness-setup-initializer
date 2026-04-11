---
name: harness-setup
description: "프로젝트에 에이전트 작업 환경(하네스)을 셋업하거나 기존 하네스를 최신 버전으로 업그레이드하는 스킬. 소스 코드를 분석하고, 사용자와 문답을 통해 프로젝트에 맞는 하네스를 구성한다. 기존 소스 코드는 수정하지 않으며, 문서와 설정 파일만 추가한다. 사용자가 하네스 셋업, harness setup, 에이전트 환경 구축, AGENTS.md 생성, 에이전트가 작업할 수 있게 환경 잡아줘, 프로젝트에 하네스 적용, 하네스 업그레이드, harness upgrade 등을 언급할 때 이 스킬을 사용한다."
allowed-tools: Bash(echo *) Bash([ *) Bash(test *)
hooks:
  Stop:
    - type: command
      command: "bash -c 'if [ -f .harness-profile.json ] && ! [ -f .harness-manifest.json ]; then printf \"{\\\"decision\\\":\\\"block\\\",\\\"reason\\\":\\\"scaffold pending\\\",\\\"additionalContext\\\":\\\"프로필이 저장되었지만 스캐폴딩이 미실행 상태다. 지금 즉시 Skill 도구를 호출하라: Skill(skill: harness-scaffold). 다른 출력 없이 바로 호출한다.\\\"}\"; else printf \"{\\\"decision\\\":\\\"allow\\\"}\"; fi'"
---

# Harness Setup Skill

## 0. 현재 상태 감지

```!
echo "=== HARNESS STATE ==="
[ -f .harness-profile.json ] && echo "PROFILE=exists" || echo "PROFILE=missing"
[ -f .harness-manifest.json ] && echo "MANIFEST=exists" || echo "MANIFEST=missing"
echo "=== END STATE ==="
```

위 상태에 따라 분기한다:

| PROFILE | MANIFEST | 행동 |
|---------|----------|------|
| missing | missing  | § 1부터 정상 진행 (Phase 1: 스캔 + Q&A + 프로필 저장) |
| exists  | missing  | "기존 프로필이 발견되었습니다. 이 프로필을 사용할까요?" 안내 → 사용자가 수락하면 바로 `Skill(skill: "harness-scaffold")` 호출, 거부하면 Phase 1을 처음부터 실행 |
| exists  | exists   | "이미 하네스가 셋업되어 있습니다." 안내 → 업그레이드(§ 14) 또는 재생성 옵션 제시 |

---

## 1. 개요

이 스킬은 하네스가 없는 프로젝트를 **분석**하고, 사용자와 **문답**을 통해 **프로젝트 프로필**을 완성한다.

하네스란 에이전트가 프로젝트를 이해하고, 작업하고, 검증하고, 정리할 수 있도록 돕는 **작업 환경 전체**이다.

### 2-스킬 구조

하네스 셋업은 두 단계로 나뉜다:

1. **`/harness-setup` (이 스킬)** — 프로젝트 분석 + Q&A → `.harness-profile.json` 저장
2. **`/harness-scaffold`** — 프로필을 읽어 18개 파일 생성 + 검증 + 보고

이 스킬은 Phase 1(분석)만 담당한다. 파일 생성은 `/harness-scaffold`가 수행한다.

> **설치 방법**: 리포지토리를 클론한 후 `install.sh`를 실행한다.
> ```bash
> git clone <repo> ~/.claude/skills/harness-setup && ~/.claude/skills/harness-setup/install.sh
> ```
> `install.sh`가 `~/.claude/skills/harness-scaffold` 심볼릭 링크를 자동 생성하여 두 스킬이 함께 로딩된다.

### 자동 체이닝

프로필 저장 후 `/harness-scaffold`가 자동으로 실행된다. 이 체이닝은 두 가지 메커니즘으로 보장된다:

1. **Stop hook** (프론트매터) — 프로필이 존재하지만 매니페스트가 없으면 `decision: "block"`으로 턴 종료를 막고, `additionalContext`로 scaffold 호출을 지시한다
2. **프롬프트 지시** (§ 4 Step 5) — 프로필 저장 직후 `Skill(skill: "harness-scaffold")` 호출을 명시적으로 지시한다

두 메커니즘이 이중 안전장치로 작동한다.

### 이 스킬이 하는 일
- 프로젝트 소스 코드와 구조를 분석하여 아키텍처를 파악한다
- 파악이 불확실한 부분은 사용자에게 문답으로 확인한다
- 프로젝트 프로필을 `.harness-profile.json`으로 저장한다

### 이 스킬이 하지 않는 일
- 하네스 파일을 직접 생성하지 않는다 (그것은 `/harness-scaffold`의 역할)
- 기존 소스 코드를 수정하거나 이동하지 않는다
- 기존 폴더 구조를 재배치하지 않는다
- 앱 기능을 구현하지 않는다
- 기존 설정 파일(eslint, tsconfig 등)을 덮어쓰지 않는다

### 지원 범위
- **Node.js / TypeScript 프로젝트** (package.json 필수)
- Python, Go, Rust 등 다른 생태계는 현재 지원하지 않는다

---

## 2. 트리거 조건

다음 상황에서 이 스킬을 실행한다:

**셋업 트리거:**
- "하네스 셋업", "harness setup", "에이전트 환경 구축" 등을 요청할 때
- "이 프로젝트에 AGENTS.md를 만들어줘" 등 하네스 구성 요소를 요청할 때
- "에이전트가 작업할 수 있게 환경을 잡아줘" 등을 요청할 때

**업그레이드 트리거:**
- "하네스 업그레이드", "harness upgrade" 등을 요청할 때
- "하네스를 최신 버전으로 업데이트해줘" 등을 요청할 때
- `/harness-setup upgrade` 형태로 호출할 때

---

## 3. 실행 흐름

```
Step 0: 모드 판별
  ├── 하네스 파일 없음 → Setup 모드 (아래 Phase 1)
  ├── 하네스 파일 있음 + .harness-manifest.json 없음 → Bootstrap (§ 14.5)
  └── 하네스 파일 있음 + .harness-manifest.json 있음 → Upgrade 분석 (§ 14.3 U1~U2)

[Setup 모드]
Phase 1: 스캔 & 분석
  ├── Step 1: 기초 스캔 (자동)
  ├── Step 2: 소스 코드 딥스캔 (자동)
  ├── Step 3: 프리셋 매칭 (자동)
  ├── Step 4: 소크라테스 문답 (대화)
  └── Step 5: 계획 제시 & 승인 (대화)
         ↓
[사용자 승인]
         ↓
.harness-profile.json 저장
         ↓
Skill 도구로 /harness-scaffold 자동 실행 (실패 시 수동 안내)

[Upgrade 모드]
Phase U1~U2 (§ 14.3 참조) → .harness-profile.json 저장 → Skill 도구로 /harness-scaffold 자동 실행
```

### 모드 판별 기준

하네스 파일 존재 여부를 확인한다: `AGENTS.md`, `CLAUDE.md`, `ARCHITECTURE.md`, `agents/` 중 2개 이상 존재하면 "하네스 파일 있음"으로 판별한다.

---

## 4. Phase 1: 스캔 & 분석

### 목표
프로젝트를 분석하고, 사용자와 문답을 통해 하네스 구성에 필요한 **프로젝트 프로필**을 완성한다.

프로젝트 프로필이란 이 프로젝트의 스택, 아키텍처, 의존성 규칙, 네이밍 규칙, 개발/테스트 환경을 기술한 데이터이다. 프리셋이 매칭되면 프리셋이 초기 프로필이 되고, 매칭되지 않으면 스캔 + 문답으로 프로필을 처음부터 구성한다.

---

### Step 1: 기초 스캔 (자동)

프로젝트의 외형적 정보를 수집한다.

#### 1.1 프로젝트 루트 확인
```bash
pwd
ls -la
```
확인 항목:
- package.json 존재 여부 (없으면 중단, 사용자에게 알림)
- 소스 디렉토리 존재 여부 (src/, app/, lib/ 등)
- 기존 하네스 파일 존재 여부 (AGENTS.md, CLAUDE.md, .cursorrules 등)

#### 1.2 스택 감지
```bash
cat package.json
```
감지 항목:
- `dependencies`에서: 주요 프레임워크 및 라이브러리
- `devDependencies`에서: TypeScript, 린트, 포맷터, 테스트 도구
- `scripts`에서: dev, build, test, lint 명령과 그 내용
- 패키지 매니저: package-lock.json / yarn.lock / pnpm-lock.yaml 존재 여부

#### 1.3 디렉토리 구조 매핑
```bash
find . -type d -maxdepth 4 -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/.next/*' -not -path '*/dist/*' -not -path '*/.turbo/*' | sort
```
매핑 항목:
- 소스 루트 위치 (src/, app/ 등)
- 최상위 폴더 이름 목록
- 폴더 깊이와 구조 패턴

#### 1.4 기존 설정 파일 파악
```bash
ls -la .eslintrc* eslint.config.* .prettierrc* tsconfig.json tailwind.config.* vite.config.* vitest.config.* playwright.config.* jest.config.* next.config.* 2>/dev/null
```
확인 항목:
- 어떤 설정이 이미 있는지 (충돌 방지용)
- tsconfig.json의 paths 설정 유무와 alias 형태
- 테스트 프레임워크 종류

#### 1.5 기존 하네스 흔적 확인
```bash
ls -la AGENTS.md CLAUDE.md claude-progress.txt feature_list.json .cursorrules docs/ 2>/dev/null
```
이미 있는 항목은 덮어쓰지 않고 스킵 대상으로 표시한다.

---

### Step 2: 소스 코드 딥스캔 (자동)

소스 코드를 직접 읽어서 **실제 아키텍처 패턴**을 파악한다.

#### 2.1 진입점 파일 확인
프레임워크에 따라 진입점을 찾는다:
```bash
# 가능한 진입점 파일들을 탐색
find . -maxdepth 3 -name "layout.tsx" -o -name "layout.ts" -o -name "_app.tsx" -o -name "main.tsx" -o -name "main.ts" -o -name "index.tsx" -o -name "root.tsx" -o -name "entry.client.tsx" 2>/dev/null | head -10
```
진입점을 찾으면 해당 파일을 읽어 앱의 구조를 파악한다.

#### 2.2 import 패턴 분석
```bash
# 소스 파일들의 import 문을 수집하여 의존성 패턴을 파악한다
# from '...' 패턴으로 검색하여 re-export(export { x } from '...')도 포함한다
grep -rn "from\s\+['\"]" --include="*.ts" --include="*.tsx" src/ 2>/dev/null | head -80
```
분석 항목:
- path alias 형태 (@/, ~/, #/ 등)
- 어떤 폴더끼리 서로 import하는지 (의존성 방향)
- 외부 라이브러리 사용 패턴 (상태관리, API 클라이언트 등)

#### 2.3 폴더별 역할 추론
각 최상위 폴더에서 대표 파일 1~2개를 읽어 역할을 추론한다:
```bash
# 각 폴더의 파일 목록과 대표 파일 내용 확인
for dir in src/*/; do
  echo "=== $dir ==="
  ls "$dir" | head -5
  # 첫 번째 .ts 또는 .tsx 파일 내용 확인
  head -30 "$dir"*.{ts,tsx} 2>/dev/null | head -30
done
```
추론 항목:
- 이 폴더는 어떤 종류의 코드를 담고 있는가 (UI, 로직, 타입, 유틸 등)
- 아키텍처 패턴은 무엇인가 (레이어 기반, FSD, 도메인 기반, 자유 구조 등)

#### 2.4 아키텍처 패턴 분류
딥스캔 결과를 종합하여 아키텍처 패턴을 분류한다:

| 패턴 | type 값 | 판별 기준 |
|------|---------|----------|
| **레이어 기반** | `layer-based` | types/, lib/, services/, hooks/, components/ 등 기능별 폴더 분리 |
| **FSD (Feature-Sliced Design)** | `fsd` | app/, pages/, widgets/, features/, entities/, shared/ 계층 구조 |
| **도메인 기반** | `domain-based` | 도메인명 폴더(users/, products/, orders/) 아래 각각 components, hooks 등 존재 |
| **자유 구조** | `custom` | 위 패턴에 해당하지 않거나 혼합 |

프리셋 매칭 시 `type` 값(영문)으로 비교한다.

---

### Step 3: 프리셋 매칭 (자동)

#### 3.1 프리셋 목록 로드
이 스킬 디렉토리의 `presets/` 폴더에서 모든 JSON 파일을 읽어 매칭을 시도한다.

#### 3.2 매칭 로직
1. package.json의 dependencies에서 각 프리셋의 `detection.required` 키를 대조한다
2. Step 2에서 분류한 아키텍처 패턴과 프리셋의 `architecture.type`을 대조한다
3. 두 조건이 모두 매칭되는 프리셋을 후보로 선택한다

#### 3.3 매칭 결과 분기

| 결과 | 다음 행동 |
|------|----------|
| 프리셋 1개 매칭 | 해당 프리셋을 초기 프로필로 사용 → Step 4에서 미세 조정 |
| 프리셋 여러 개 매칭 | 아래 동점 해소 규칙 적용 후, 여전히 동점이면 사용자에게 선택 요청 |
| 프리셋 0개 매칭 | 스캔 결과를 기반으로 빈 프로필 생성 → Step 4에서 문답으로 구성 |

**동점 해소 규칙** (프리셋 여러 개 매칭 시):
1. `detection.optional` 패키지 매칭 수가 더 많은 프리셋을 우선한다
2. 그래도 동점이면, `detection.required` 패키지 수가 더 많은(더 구체적인) 프리셋을 우선한다
3. 여전히 동점이면 사용자에게 후보 목록과 각 프리셋의 displayName을 제시하여 선택을 요청한다

---

### Step 4: 소크라테스 문답 (대화)

스캔과 딥스캔으로 파악한 내용 중 **확신이 부족한 부분**을 사용자에게 질문한다.
목표는 기계적 설문이 아니라, 에이전트가 "이 프로젝트를 이해하기 위한 대화"를 하는 것이다.

#### 4.1 문답 원칙

- **이미 코드에서 확인된 것은 묻지 않는다.** package.json에 `next`가 있으면 "Next.js를 쓰시나요?" 라고 묻지 않는다.
- **추론한 것은 확인을 구한다.** "폴더 구조를 보니 FSD 아키텍처를 사용하시는 것 같습니다. 맞나요?"
- **한 번에 3개 이내의 질문만 한다.** 긴 설문지를 던지지 않는다.
- **이전 답변에 따라 다음 질문이 달라진다.** 고정된 질문 목록이 아니다.
- **자연어로 대화한다.** JSON이나 특수 형식을 요구하지 않는다.

#### 4.1.1 질문 우선순위

질문 풀에서 질문을 선택할 때 다음 우선순위를 따른다:

| 우선순위 | 조건 | 질문 카테고리 |
|----------|------|-------------|
| 1 (필수) | 아키텍처 분류에 확신 부족 | 아키텍처 관련 |
| 2 (필수) | 프리셋 매칭 실패 또는 미세 조정 필요 | 의존성/레이어 규칙 |
| 3 (권장) | 코드만으로 파악 불가 | 프로젝트 의도 (한 줄 설명, 금지 사항) |
| 4 (선택) | 관련 라이브러리 감지 시 | 상태관리, 백엔드, 라우팅 |
| 5 (선택) | 코드 패턴 불일치 시 | 네이밍, 검증 환경 |

우선순위 1~2에 해당하는 질문이 있으면 반드시 첫 라운드에 포함한다.

#### 4.1.2 문답 종료 조건

다음 조건 중 하나를 만족하면 문답을 종료하고 Step 5(계획 제시)로 진행한다:

1. **프로필 필수 항목이 모두 채워짐** — 4.3의 [기본] 항목이 모두 확정된 상태
2. **최대 3라운드 소진** — 3회 문답 후에도 미확정 항목이 있으면, 스캔 기반 추론값을 기본값으로 사용하고 사용자에게 알린다
3. **사용자가 종료 요청** — "그냥 진행해줘", "기본값으로 해" 등

2번의 경우, 미확정 항목은 계획 제시 시 "추론값 사용" 표시와 함께 보여준다.

#### 4.2 질문 풀 (상황에 따라 선택)

아래는 질문 후보이다. 에이전트는 스캔 결과에 따라 필요한 것만 골라서 묻는다.

**아키텍처 관련** (Step 2에서 확신 부족 시):
- "소스 코드를 보니 {패턴}을 사용하시는 것 같습니다. 맞나요?"
- "폴더 간 의존성 방향이 있나요? 예를 들어 {A}에서 {B}를 import하는 건 허용되지만 반대는 안 되는 식인가요?"
- "{폴더X}와 {폴더Y}의 역할 차이가 무엇인가요?"
- "컴포넌트에서 API를 직접 호출하나요, 아니면 별도 레이어(훅, 서비스 등)를 거치나요?"

**프로젝트 의도 관련** (코드만으로 파악 불가):
- "이 프로젝트의 한 줄 설명을 해주시겠어요?"
- "현재 개발 단계가 어디인가요? (초기 셋업 / 기능 구현 중 / 리팩터링 중)"
- "특별히 지키고 싶은 코딩 규칙이나 컨벤션이 있나요?"
- "에이전트가 작업할 때 절대 하면 안 되는 것이 있나요?"

**검증 관련** (기존 테스트 환경이 불명확할 때):
- "테스트를 실행하는 명령은 무엇인가요?"
- "E2E 테스트를 사용하시나요?"
- "타입 체크 명령이 별도로 있나요?"

**네이밍/컨벤션 관련** (코드에서 일관된 패턴이 안 보일 때):
- "컴포넌트 파일명은 PascalCase, camelCase 중 어떤 걸 쓰시나요?"
- "테스트 파일은 소스 옆에 두나요, 별도 tests/ 폴더에 두나요?"

**상태 관리 관련** (Zustand, Redux 등이 감지된 경우):
- "스토어 파일은 어디에 두나요? (예: 슬라이스별 store.ts / shared/stores/ / 별도 폴더)"
- "스토어에 접근할 때 규칙이 있나요? (예: selector 함수만 사용, 직접 접근 금지 등)"
- "오프라인/로컬 영속성(persist 등)을 쓰고 있나요? 어디서 설정하나요?"

**백엔드/데이터 통합 관련** (Supabase, Firebase 등 BaaS가 감지된 경우):
- "DB 클라이언트(Supabase 등)는 어디서 초기화하나요? (예: shared/api/, shared/lib/)"
- "API 호출은 어디서 하나요? (예: entities/{이름}/api/, shared/api/, services/)"
- "인증(auth) 로직은 어디에 두나요?"
- "실시간 구독(real-time listener)을 사용하나요? 사용한다면 어디서 관리하나요?"

**도메인 모델 관련** (클래스 기반 객체, 복잡한 도메인 로직이 감지된 경우):
- "도메인 객체(모델)를 클래스로 관리하나요, 아니면 plain object + 함수 조합인가요?"
- "상태 전이 규칙이 있나요? (예: 특정 상태에서 특정 상태로만 변경 가능)"
- "도메인 객체를 변경할 때 직접 수정(mutation)하나요, 새 인스턴스를 반환하나요?"
- "이벤트 기록(히스토리, 감사 로그)을 남기나요? 어떤 구조인가요?"

**라우팅 관련** (React Router v7, Next.js App Router 등이 감지된 경우):
- "라우트 정의는 어디에 있나요? (예: app/routes/, routes.ts)"
- "loader/action 패턴을 사용하나요? 사용한다면 데이터 페칭은 loader에서 하나요, 컴포넌트에서 하나요?"

#### 4.3 프로필 완성

문답이 완료되면 수집된 모든 정보를 **프로젝트 프로필**로 통합한다.

프로필에 반드시 포함되어야 하는 항목:
```
[기본]
- 프로젝트명
- 한 줄 설명
- 스택 (프레임워크, 언어, 주요 라이브러리)
- 아키텍처 유형 (레이어 기반 / FSD / 도메인 기반 / 자유 구조)
- 폴더별 역할 (감지된 폴더 → 역할 매핑)
- 의존성 방향 규칙 (어떤 폴더가 어떤 폴더를 import 가능한지)
- 네이밍 규칙
- 개발 서버 명령 + 포트
- 테스트 명령 (유닛 / E2E)
- path alias 형태
- 소스 루트 경로

[해당 시 추가 — 문답에서 확인된 경우만]
- 상태 관리: 도구명, 스토어 위치, 접근 규칙
- 백엔드/DB 통합: 클라이언트 위치, API 호출 패턴, 인증 위치
- 도메인 모델: 객체 관리 방식(클래스/함수), 상태 전이 규칙, 변경 패턴(mutation/immutable)
- 데이터 영속성: 로컬 저장소 전략, 동기화 방식
- 라우팅 패턴: loader/action 사용 여부, 라우트 정의 위치
```

프리셋이 매칭된 경우: 프리셋 값을 기본으로 하되, 문답에서 다르게 확인된 부분을 오버라이드한다.
프리셋이 없는 경우: 스캔 + 문답 결과로 프로필을 직접 구성한다.

#### 4.4 기본값 테이블

사용자가 "몰라", "잘 모르겠어", "기본값으로" 등으로 답하면 아래 기본값을 적용한다.

| 프로필 항목 | 기본값 | 근거 |
|------------|--------|------|
| 프로젝트명 | package.json의 `name` 필드 | 패키지명이 곧 프로젝트명 |
| 한 줄 설명 | package.json의 `description`, 없으면 `"{name} 프로젝트"` | 기존 메타데이터 활용 |
| 아키텍처 유형 | 딥스캔 분류 결과, 분류 불가 시 `custom` (자유 구조) | 코드 기반 추론 우선 |
| 의존성 방향 규칙 | 매칭된 프리셋의 규칙, 프리셋 없으면 "규칙 없음" | 프리셋 참조 |
| 네이밍 규칙 | 컴포넌트 PascalCase, 훅 camelCase+use, 서비스 camelCase, 타입 PascalCase | React 커뮤니티 관행 |
| 개발 서버 명령 | package.json scripts의 `dev` 필드 | 실제 설정 기반 |
| 개발 서버 포트 | scripts.dev에서 추출, 불가 시 Next.js→3000, Vite→5173, 기타→3000 | 프레임워크 기본값 |
| 테스트 명령 | package.json scripts의 `test` 필드, 없으면 생략 | 실제 설정 기반 |
| E2E 프레임워크 | devDependencies에서 감지 (playwright/cypress), 없으면 생략 | 실제 설정 기반 |
| path alias | tsconfig.json `paths`에서 추출, 없으면 상대 경로 | 실제 설정 기반 |
| 소스 루트 | `src/` 존재 시 `src/`, 없으면 `app/` 존재 시 `app/`, 둘 다 없으면 사용자에게 질문 | 디렉토리 탐색 |

**기본값 사용 시 규칙**:
- 기본값을 적용한 항목은 Phase 4 보고에서 "(기본값)" 표시와 함께 나열한다
- 사용자가 나중에 수정할 수 있도록 해당 항목을 보고서에 명시한다

---

### Step 5: 계획 제시 & 승인

프로필이 완성되면 사용자에게 최종 계획을 제시한다.

```
## 🔍 프로젝트 분석 결과

### 프로젝트 프로필
- 프로젝트: {프로젝트명}
- 설명: {한 줄 설명}
- 스택: {프레임워크} + {언어} + {주요 라이브러리}
- 아키텍처: {유형} ({의존성 방향 한 줄 요약})
- 적용 프리셋: {프리셋명 또는 "커스텀 (프리셋 미사용)"}

### 감지된 폴더 구조
{소스루트}/
├── {폴더1}/  → {역할} ✅ 존재
├── {폴더2}/  → {역할} ✅ 존재
└── {폴더3}/  → {역할} (권장, 미존재)

### 의존성 규칙
{방향 도표 또는 테이블}

### 생성 예정 파일
1. CLAUDE.md (Agent Dispatch + 세션 요약)
2. AGENTS.md
3. ARCHITECTURE.md
4. .claude/rules/session-routine.md (TDD 오케스트레이션)
5. .claude/rules/coding-standards.md (코드 규칙)
6. agents/*.md (7개 TDD subagent 정의)
7. claude-progress.txt
8. feature_list.json
9. init.sh
10. docs/QUALITY_SCORE.md
11. docs/TECH_DEBT.md
12. docs/ 하위 디렉토리
13. scripts/structural-test.ts
14. scripts/doc-freshness.ts

### 수정 예정 파일
- package.json: scripts에 lint:arch, validate, doc:check 추가

### 스킵 항목
{이미 존재하는 파일}

---
이 내용으로 진행할까요? (y/n 또는 수정 요청)
```

**중요**: 사용자가 승인하기 전까지 프로필을 저장하지 않는다.

사용자가 승인하면 `.harness-profile.json`을 프로젝트 루트에 저장한다.

프로필 저장 완료 후 다음 단계를 **반드시** 순서대로 실행한다:

1. `.harness-profile.json` 파일이 디스크에 저장되었는지 Read 도구로 확인한다
2. 확인 즉시, Skill 도구를 호출한다: `Skill(skill: "harness-scaffold")`
3. 이 두 단계 사이에 다른 텍스트 출력이나 사용자 질문을 하지 않는다

이것이 Phase 1의 마지막 행동이다. Skill 도구 호출 후 추가 출력을 하지 않는다.

> **이중 안전장치**: 만약 위 지시를 따르지 못해 턴이 종료되더라도, 프론트매터의 Stop hook이 `decision: "block"`으로 턴 종료를 막고 scaffold 호출을 강제한다. 따라서 프로필 저장 후 scaffold 실행은 항상 보장된다.

Skill 도구 호출이 실패하면 다음을 출력한다:

```
✅ 프로필이 저장되었습니다 (.harness-profile.json)
👉 `/harness-scaffold`를 실행하여 하네스 파일을 생성하세요.
```

---

## 5. 프로필 출력 스키마

사용자 승인 후 저장하는 `.harness-profile.json`의 구조. `/harness-scaffold`는 이 스키마를 입력으로 받는다.

```json
{
  "version": "1.0.0",
  "preset": "react-next | custom",
  "projectName": "프로젝트명",
  "description": "한 줄 설명",
  "stack": {
    "framework": "React 19",
    "language": "TypeScript",
    "libraries": ["React Router v7", "Zustand", "Supabase"]
  },
  "architectureType": "layer-based | fsd | domain-based | custom",
  "srcRoot": "src/",
  "pathAlias": "@/",
  "layers": {
    "order": ["types", "config", "lib", "services", "hooks", "components", "pages", "app"],
    "rules": {
      "types": { "allowedImports": [] },
      "config": { "allowedImports": ["types"] }
    },
    "descriptions": {
      "types": "공유 타입, enum, interface",
      "lib": "순수 유틸 함수"
    }
  },
  "folderRoles": {
    "src/types": "공유 타입, enum, interface",
    "src/lib": "순수 유틸 함수"
  },
  "extraArchitectureRules": [
    "컴포넌트에서 API를 직접 호출하지 않는다"
  ],
  "naming": {
    "components": "PascalCase",
    "hooks": "camelCase + use 접두사"
  },
  "devServer": {
    "command": "npm run dev",
    "port": 3000,
    "readyCheck": "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000"
  },
  "scripts": {
    "validate": "npm run validate",
    "test": "npm run test"
  },
  "tdd": {
    "securityCategories": "auth, security, api, payment",
    "maxImplementerAttempts": 3,
    "maxDebuggerAttempts": 2
  },
  "git": {
    "commitScopes": null,
    "commitLang": "ko",
    "branchPrefixes": ["feature/", "fix/", "docs/", "refactor/", "chore/"],
    "mainBranch": "main"
  },
  "docFreshnessDays": 14,
  "extras": {
    "stateManagement": {},
    "backendIntegration": {},
    "domainModel": {},
    "routing": {}
  },
  "existingFiles": ["AGENTS.md"],
  "skipFiles": ["AGENTS.md"],
  "approved": true,
  "approvedAt": "2026-04-08T09:30:00Z"
}
```

### 필드 규칙

| 필드 | 소스 | 설명 |
|------|------|------|
| `version` | 현재 스킬 버전 | 매니페스트 호환 버전 |
| `preset` | Step 3 매칭 결과 | 매칭된 프리셋명 또는 `"custom"` |
| `projectName` | package.json name 또는 문답 | 프로젝트명 |
| `description` | package.json description 또는 문답 | 한 줄 설명 |
| `stack` | Step 1 스캔 | 프레임워크, 언어, 주요 라이브러리 |
| `architectureType` | Step 2 분류 또는 문답 | `layer-based` / `fsd` / `domain-based` / `custom` |
| `srcRoot` ~ `docFreshnessDays` | 스캔 + 프리셋 + 문답 | 프로필 4.3의 [기본] 항목에 대응 |
| `extras` | Step 4 문답에서 확인된 경우만 | 해당 키가 없으면 섹션 생략 |
| `existingFiles` | Step 1.5 스캔 | 이미 존재하는 하네스 파일 목록 |
| `skipFiles` | Step 5 사용자 선택 | 생성을 건너뛸 파일 목록 |
| `approved` | Step 5 | 사용자 승인 여부 |

### 업그레이드 모드 추가 필드

업그레이드 시에는 다음 필드를 추가한다:

```json
{
  "mode": "upgrade",
  "fromVersion": "1.0.0",
  "toVersion": "1.1.0",
  "migrations": [],
  "fileActions": {
    "agents/architect.md": { "action": "overwrite", "reason": "템플릿 변경 감지, 사용자 수정 없음", "source": "auto-detect" },
    "agents/reviewer.md": { "action": "user-choice", "reason": "템플릿 변경 + 사용자 수정 감지", "source": "auto-detect" },
    "agents/test-engineer.md": { "action": "skip", "reason": "변경 없음", "source": "auto-detect" },
    "CLAUDE.md": { "action": "surgical", "changes": [], "source": "migration" },
    "feature_list.json": { "action": "skip", "reason": "data", "source": "category" }
  }
}
```

`source` 필드는 판정 출처를 나타낸다:
- `"auto-detect"` — § 12.6 템플릿 재렌더링 비교
- `"migration"` — 마이그레이션 레지스트리 지시
- `"category"` — 카테고리 규칙 (data 자동 스킵 등)
```

---

## 6. 프리셋 시스템

> **참고**: 이전 §8. 섹션 번호가 재정리되었다.

### 프리셋 파일 위치
이 스킬 디렉토리의 `presets/` 폴더에 위치한다.

```
presets/
├── react-next.json
├── react-router-fsd.json
└── (추가 프리셋)
```

### 프리셋 스키마

```json
{
  "name": "프리셋 식별자",
  "displayName": "사람이 읽을 수 있는 이름",
  "description": "프리셋 설명",

  "detection": {
    "required": ["매칭에 필요한 패키지명"],
    "optional": ["있으면 좋은 패키지명"],
    "versionConstraints": {
      "패키지명": ">=13.0.0"
    }
  },

  "architecture": {
    "type": "layer-based | fsd | domain-based | custom",
    "description": "아키텍처 한 줄 설명",
    "layers": {
      "order": ["의존 방향 순서대로 나열"],
      "rules": {
        "레이어명": { "allowedImports": ["import 가능한 레이어"] }
      },
      "descriptions": {
        "레이어명": "역할 설명"
      }
    },
    "extraRules": [
      "레이어 규칙 외 추가 제약 (자연어)"
    ]
  },

  "naming": {
    "폴더 또는 파일 유형": "네이밍 규칙 설명"
  },

  "scripts": {
    "lint:arch": "아키텍처 검증 명령",
    "doc:check": "문서 검사 명령"
  },

  "devServer": {
    "command": "개발 서버 실행 명령",
    "port": 3000,
    "readyCheck": "서버 준비 확인 명령"
  },

  "pathAlias": "@/",
  "srcRoot": "src/",

  "testFramework": {
    "unit": "유닛 테스트 도구",
    "e2e": "E2E 테스트 도구"
  },

  "docFreshnessDays": 14,

  "git": {
    "mainBranch": "main",
    "branchPrefixes": ["feature/", "fix/", "docs/", "refactor/", "chore/"],
    "commitLang": "ko"
  }
}
```

**타입 참고**: `pathAlias`는 `string` 또는 `string[]` 가능. 단일 alias(`"@/"`)이면 문자열, 복수 alias(`["@/", "~/"]`)이면 배열로 지정한다.

**git 참고**: `git` 필드는 모든 하위 필드에 기본값이 있으므로 프리셋에서 생략 가능하다. `commitLang`은 `"ko"` (한국어) 또는 `"en"` (English)을 지원한다.

### 프리셋 매칭 로직
1. 이 스킬의 `presets/` 디렉토리 내 모든 JSON 파일을 로드한다
2. package.json의 dependencies/devDependencies에서 각 프리셋의 `detection.required` 패키지를 모두 대조한다
3. 모든 required가 매칭되는 프리셋을 1차 후보로 선택한다
3.5. `detection.versionConstraints`가 있으면 해당 패키지의 실제 버전(package.json에 명시된)이 조건을 만족하는지 확인한다. 조건 미충족 시 해당 프리셋을 후보에서 제외한다. (semver 범위 문법 사용: `>=`, `<`, `^`, `~` 등)
4. 남은 후보 중 `architecture.type`이 Step 2 딥스캔 결과와 일치하는 것을 최종 후보로 선택한다
5. 최종 후보가 여러 개면: 각 후보의 `detection.optional` 패키지 매칭 개수를 세어 가장 많이 매칭되는 것을 우선 선택한다
6. 최종 후보가 0개면: 프리셋 없이 진행 (문답으로 프로필 구성)
7. 최종 후보가 1개면: 해당 프리셋 사용
8. 5단계 이후에도 여러 개면: 사용자에게 선택 요청

---

## 7. 절대 규칙

### 파일 보호
- 기존 소스 코드 (.ts, .tsx, .js, .jsx, .css 등)를 수정하지 않는다
- 기존 설정 파일을 덮어쓰지 않는다 (merge만 허용, 그것도 scripts 필드에 한정)
- 이미 존재하는 하네스 파일을 덮어쓰지 않는다 (사용자 확인 없이)
- node_modules, .git, 프레임워크 캐시 디렉토리(.next, dist 등)에 접근하지 않는다

### 문서 품질
- AGENTS.md는 100줄을 넘기지 않는다
- 모든 문서의 경로 참조는 실제 파일/폴더와 일치해야 한다
- 플레이스홀더 텍스트(TODO, TBD, Lorem 등)를 남기지 않는다
- 한국어로 작성한다 (사용자 요청이 없는 한)

### 실행 안전
- 사용자 승인 없이 프로필을 저장하지 않는다
- git commit은 자동으로 하지 않는다 (사용자에게 제안만)
- npm install 등 의존성 설치는 자동으로 하지 않는다

### 문답 안전
- 코드에서 이미 확인된 사실을 다시 묻지 않는다
- 한 번에 3개 이상의 질문을 하지 않는다
- 사용자가 "몰라" 또는 "기본값으로"라고 답하면 합리적 기본값을 적용하고 진행한다

---

## 8. 에러 처리

| 상황 | 대응 |
|------|------|
| package.json이 없다 | "이 디렉토리는 Node.js 프로젝트가 아닌 것 같습니다" 안내 후 중단 |
| 매칭 프리셋이 없다 | 스캔 결과를 보여주고 문답으로 프로필 구성 (에러가 아님) |
| 이미 AGENTS.md가 있다 | "기존 AGENTS.md를 발견했습니다. 덮어쓸까요, 스킵할까요?" 확인 |
| 이미 CLAUDE.md가 있다 | "기존 CLAUDE.md를 발견했습니다. 덮어쓸까요, 스킵할까요?" 확인 |
| src/ 디렉토리가 없다 | 소스 루트를 자동 탐색, 못 찾으면 사용자에게 질문 |
| tsconfig paths가 없다 | pathAlias를 상대 경로로 기록 |
| 아키텍처 패턴을 분류할 수 없다 | "자유 구조"로 분류하고, 사용자에게 규칙이 있는지 질문 |
| 사용자가 문답에 "몰라"로 답변 | 합리적 기본값 적용, 보고에서 기본값 사용 항목을 명시 |
| 사용자가 아키텍처 감지 오류를 지적 | 아래 **재스캔/재생성 플로우** 참조 |

### 재분석 플로우

Phase 1 진행 중 사용자가 아키텍처 감지 또는 프리셋 매칭 오류를 지적하면:

1. **Step 4~5 중**: 사용자의 피드백을 반영하여 프로필을 수정하고 Step 5(계획 제시)를 다시 진행한다.
2. **프로필 저장 후**: `.harness-profile.json`을 수정하여 다시 저장한다. 사용자가 직접 편집할 수도 있다.

---

## 9. 커스텀 프리셋 작성 가이드

새 프리셋을 추가하려면:

1. `presets/` 폴더에 `{name}.json` 파일을 생성한다
2. 프리셋 스키마(섹션 8)의 모든 필수 필드를 채운다
3. `detection.required`에 해당 스택의 **고유 패키지**를 지정한다 (예: Remix → `"@remix-run/react"`)
4. `detection.versionConstraints`로 특정 버전 이상만 매칭되도록 제한한다 (선택)
5. `architecture.layers.rules`에서 각 레이어가 import할 수 있는 레이어를 명시한다
6. 기존 프리셋(`react-next.json`, `react-router-fsd.json`)을 참조 예시로 활용한다

**필수 필드 체크리스트:**
- `name`, `displayName`, `description`
- `detection.required` (최소 1개)
- `architecture.type`, `architecture.layers.order`, `architecture.layers.rules`
- `scripts.lint:arch`
- `devServer.command`, `devServer.port`
- `pathAlias`, `srcRoot`

---

## 10. 향후 확장 포인트

이 SKILL.md는 단일 스킬로 시작하되, 다음 방향으로 확장할 수 있다:

- **새 프리셋 추가**: `presets/react-vite.json`, `presets/express-api.json` 등
- **스캐폴딩 스킬 확장**: `/harness-scaffold`에 새 생성 파일 유형 추가
- **Coding Agent 스킬**: 하네스 위에서 실제 기능을 구현하는 세션 루틴 스킬
- **Cleanup Agent 스킬**: 주기적으로 문서/코드 일관성을 검사하는 정리 스킬
- **품질 대시보드**: QUALITY_SCORE.md를 자동 업데이트하는 스킬
- **피드백 분석 스킬** (`companion-skills/harness-feedback/`): HARNESS_FRICTION.md 마찰 로그를 분석하여 반복 패턴을 식별하고, harness-setup 리포에 GitHub Issue를 자동 생성

> **구현 완료**: 2-스킬 분리 (분석 + 스캐폴딩), 프로필 저장, 업그레이드 시스템

---

## 11. 참고 자료

이 스킬 디렉토리의 `references/` 폴더에 상세 배경 문서가 있다.

### 우선순위 규칙
**SKILL.md가 정규 사양이다.** SKILL.md와 harness-guide.md의 내용이 충돌하면 SKILL.md가 우선한다. harness-guide.md는 배경 지식과 상세 예시를 위한 참조 자료이다.

### 파일 목록
- `references/harness-guide.md` — Anthropic + OpenAI 하네스 엔지니어링 통합 가이드 (P1~P10 프로세스)
- `references/project-context.md` — 이 스킬의 설계 결정 기록, 버전 히스토리, 다음 단계
- `references/upgrade-system-design.md` — 업그레이드 시스템 설계 문서 (매니페스트, 카테고리, 마이그레이션)

---

## 12. 업그레이드 시스템

기존 하네스를 최신 스킬 버전에 맞게 업그레이드한다. 이 스킬은 분석 + 계획(U1~U2)을 담당하고, 실행(U3~U5)은 `/harness-scaffold`가 수행한다.

### 12.1 매니페스트 상세

매니페스트 스키마는 harness-scaffold/SKILL.md § 5.13 (리포 루트의 harness-scaffold/)을 참조한다. 여기서는 업그레이드에 관련된 추가 사항을 기술한다.

#### 설계 결정

| 결정 | 근거 |
|------|------|
| **전체 프로필 저장** | 플레이스홀더가 21개이고 소스가 분산되어 있어, 업그레이드 시 재스캔/재문답 없이 managed 파일을 재생성하려면 전체 프로필이 필요하다 |
| **해시 기반 변경 감지** | 현재 파일 해시와 manifest 해시를 비교하면 사용자 수정 여부를 판별할 수 있다. 소스 템플릿을 재렌더링한 해시와 비교하면 템플릿 변경 여부도 판별할 수 있다 (§ 12.6) |
| **템플릿 자동 감지** | managed 파일의 변경은 마이그레이션 없이 자동 감지한다. 마이그레이션은 custom/new/remove/profile/data 전용으로 역할을 분리하여 유지보수 부담을 줄인다 |
| **단일 JSON 파일** | 파일별 주석 스탬프 대신 하나의 파일로 관리한다. LLM이 한 번에 전체 상태를 파악할 수 있고, 생성 파일에 불필요한 주석을 남기지 않는다 |

### 12.2 파일 카테고리

#### 카테고리 정의

| 카테고리 | 소유권 | 업그레이드 동작 |
|----------|--------|----------------|
| **managed** | 스킬 소유 | 최신 템플릿 + profile 값으로 재생성하여 덮어쓰기 |
| **custom** | 사용자 소유 | 덮어쓰지 않음. 마이그레이션 지시에 따라 외과적 수정 (섹션 추가/변경) |
| **data** | 사용자 소유 | 절대 수정 안 함. 스키마 변경 시에만 필드 추가 (기본값 적용) |

#### 파일별 분류

| # | 파일 | 카테고리 | 근거 |
|---|------|----------|------|
| 1 | `docs/` 하위 디렉토리 (4개) | managed | 구조적 스캐폴딩, 사용자 콘텐츠 없음 |
| 2 | `ARCHITECTURE.md` | custom | 사용자가 도메인별 설명 추가, 의존 규칙 조정 |
| 3 | `AGENTS.md` | custom | 사용자가 프로젝트 맥락 추가, 섹션 수정 |
| 4 | `CLAUDE.md` | custom | 가장 많이 커스터마이징되는 파일 |
| 5 | `.claude/rules/session-routine.md` | managed | 템플릿 기반 TDD 오케스트레이션 |
| 6 | `.claude/rules/coding-standards.md` | managed | 템플릿 기반, 플레이스홀더 값만 다름 |
| 7 | `.claude/rules/git-workflow.md` | managed | 템플릿 기반 |
| 8–14 | `agents/*.md` (7개) | managed | 템플릿 기반 subagent 정의 |
| 15 | `feature_list.json` | data | 런타임 데이터, 기능 항목 축적 |
| 16 | `claude-progress.txt` | data | 세션 상태 누적, 절대 덮어쓰면 안 됨 |
| 17 | `init.sh` | managed | 템플릿 기반 초기화 스크립트 |
| 18 | `scripts/structural-test.ts` | managed | 템플릿 기반 아키텍처 검증 |
| 19 | `scripts/doc-freshness.ts` | managed | 템플릿 기반 문서 최신성 검사 |
| 20 | `docs/QUALITY_SCORE.md` | data | 사용자/에이전트가 점수 기록 |
| 21 | `docs/TECH_DEBT.md` | data | 사용자/에이전트가 부채 항목 축적 |
| 22 | `docs/HARNESS_FRICTION.md` | data | session-routine이 마찰 이벤트 기록 |
| 23 | `package.json` (scripts) | custom | 스킬은 특정 키만 추가, 사용자가 수정했을 수 있음 |

#### managed 파일의 변경 감지 및 대응

managed 파일의 업그레이드 판정은 § 12.6의 자동 감지 알고리즘을 따른다. 소스 템플릿을 재렌더링한 해시(`expectedHash`)와 manifest의 `templateHash`를 비교하여 템플릿 변경 여부를, 현재 파일 해시와 `templateHash`를 비교하여 사용자 수정 여부를 동시에 판정한다.

템플릿이 변경되었고 사용자도 파일을 수정한 경우, 3가지 선택지를 제시한다:

1. **덮어쓰기** — 최신 템플릿으로 교체 (사용자 변경 소실)
2. **스킵** — 현재 파일 유지. manifest에 `"userOverride": true` 표시하여 향후 업그레이드에서도 스킵
3. **병합** — 구조적 변경만 적용하고 사용자 추가분 보존 (best-effort)

### 12.3 업그레이드 Phase U1~U2

```
Phase U1: 분석
  ├── .harness-manifest.json 읽기
  ├── 버전 갭 계산: manifest.harness.version → 현재 스킬 버전
  ├── 적용할 마이그레이션 목록 로드 (레지스트리에서 순서대로)
  ├── managed 파일 템플릿 자동 변경 감지 (§ 12.6):
  │     각 managed 파일에 대해:
  │       1. 소스 템플릿을 manifest.profile로 렌더링 → expectedHash
  │       2. expectedHash vs templateHash → 템플릿 변경 여부
  │       3. 현재 파일 해시 vs templateHash → 사용자 수정 여부
  └── 파일별 상태 판별 (4-상태):
        ├── data → 스킵
        ├── managed + 템플릿 변경 없음 → 스킵 (변경 불필요)
        ├── managed + 템플릿 변경 + 사용자 미수정 → 자동 덮어쓰기 예정
        ├── managed + 템플릿 변경 + 사용자 수정 → 선택 필요
        ├── managed + userOverride: true → 자동 스킵
        └── custom → 마이그레이션 지시에 따라 외과적 수정 예정
         ↓
Phase U2: 계획 제시
  사용자에게 테이블 형태로 보여준다:
  ┌──────────────────────────────────────┬──────────┬──────────────────────────────────┐
  │ 파일                                 │ 작업     │ 이유                             │
  ├──────────────────────────────────────┼──────────┼──────────────────────────────────┤
  │ agents/architect.md                  │ 덮어쓰기 │ 템플릿 변경 감지, 사용자 수정 없음 │
  │ .claude/rules/session-routine.md     │ 덮어쓰기 │ 템플릿 변경 감지, 사용자 수정 없음 │
  │ agents/reviewer.md ⚠️                │ 사용자 선택│ 템플릿 변경 + 사용자 수정 감지    │
  │ agents/test-engineer.md              │ 스킵     │ 템플릿/프로필 변경 없음            │
  │ CLAUDE.md                            │ 부분 수정│ 마이그레이션 지시                  │
  │ feature_list.json                    │ 스킵     │ data                             │
  └──────────────────────────────────────┴──────────┴──────────────────────────────────┘
  → 사용자 승인 대기
         ↓
.harness-profile.json 저장 (mode: "upgrade" + fileActions 포함)
         ↓
사용자에게 /harness-scaffold 실행 안내
  → /harness-scaffold가 Phase U3~U5 (실행, 검증, 보고) 수행
```

Phase U2 승인 후 저장하는 `.harness-profile.json`에는 `mode: "upgrade"`, `fileActions` 등 업그레이드 전용 필드가 포함된다 (§ 5 프로필 출력 스키마 참조). `/harness-scaffold`는 이 필드를 읽어 U3~U5를 실행한다.

마이그레이션 레지스트리, 파일 카테고리, 실행 상세는 harness-scaffold/SKILL.md § 10을 참조한다.

### 12.4 부트스트랩 마이그레이션 (v0 → 1.0.0)

manifest 없이 셋업된 기존 프로젝트를 버전 관리 체계에 편입시키는 절차이다.

#### 부트스트랩 흐름

```
Step 1: 기존 하네스 파일 탐색
  - AGENTS.md, CLAUDE.md, ARCHITECTURE.md, agents/*.md,
    .claude/rules/*.md, scripts/*.ts, docs/*.md, init.sh,
    feature_list.json, claude-progress.txt 존재 여부 확인

Step 2: 프로필 추론
  - coding-standards.md → architectureType
  - structural-test.ts → pathAlias, srcRoot, layers
  - init.sh → devServer (command, port)
  - package.json scripts → validate, test 명령
  - CLAUDE.md → tdd 설정, git 설정
  추론 실패 시 → 사용자에게 포커스드 질문

Step 3: 초기 manifest 생성
  - harness.version = "1.0.0" (semver 시작 버전)
  - 모든 기존 파일의 현재 내용을 해시하여 templateHash로 기록
  - 카테고리는 § 14.2 테이블에 따라 할당

Step 4: 사용자 확인
  "기존 하네스를 감지했습니다. 버전 추적을 위한
   .harness-manifest.json을 생성합니다."
  추론된 프로필 표시 → 사용자 확인/수정

Step 5: manifest 쓰기 → 정상 업그레이드 플로우 (§ 14.3) 진입
```

#### 설계 결정

- **1.0.0 고정**: 현재 상태를 semver 1.0.0으로 선언한다. pre-semver 시절의 모든 기존 프로젝트를 1.0.0으로 편입한다. 상세: `references/versioning-policy.md`
- **해시 = 현재 상태**: 부트스트랩 시 기록되는 templateHash는 "현재 파일 상태"이다. 따라서 첫 업그레이드에서 managed 파일의 해시가 불일치할 수 있고, 이 경우 § 14.2의 3가지 선택지를 제시한다.

### 12.5 엣지 케이스

#### 중단된 업그레이드

**감지**: `harness.upgradeInProgress == true`
**대응**: "이전 업그레이드가 중단된 것 같습니다. 처음부터 다시 진행할까요?" — managed 파일 재생성은 멱등이므로 재실행이 안전하다. custom 파일 외과적 수정도 멱등으로 설계한다 ("이 행이 없으면 추가" 패턴).

#### 새 플레이스홀더 등장

스킬 업데이트로 새 플레이스홀더 `{{NEW_FIELD}}`가 추가된 경우:
- 마이그레이션에 `[profile] add` 항목으로 기술
- 기본값이 있으면 자동 적용, 없으면 Phase U1에서 사용자에게 포커스드 질문
- manifest의 `profile`에 새 필드 추가

#### 프리셋 삭제/변경

사용된 프리셋이 스킬에서 삭제된 경우:
- manifest의 `profile`에 저장된 값으로 폴백 (프리셋 없이도 동작)
- 경고: "프리셋 '{name}'을 찾을 수 없습니다. 매니페스트의 프로필 값을 사용합니다."

#### 파일 삭제 (신규 버전에서 제거)

마이그레이션의 `[remove]` 항목:
- `delete`: 사용자 확인 후 삭제, manifest에서 제거
- `deprecate`: manifest에 `deprecated: true` 표시, 삭제 여부는 사용자 결정
- **자동 삭제하지 않는다** — 항상 사용자 확인

#### 아키텍처 유형 변경

사용자가 셋업 후 아키텍처를 변경한 경우:
- Phase U1에서 확인: "현재 아키텍처 유형이 {manifest value}으로 기록되어 있습니다. 맞나요?"
- 변경 시: profile 갱신 → 아키텍처 의존 파일 재생성 (structural-test.ts, coding-standards.md, ARCHITECTURE.md)

#### 팀 환경

`.harness-manifest.json`을 git에 커밋하는 경우:
- 한 팀원이 업그레이드 → 커밋 → 다른 팀원이 pull하면 업그레이드된 하네스를 받음
- 두 팀원이 동시에 업그레이드하면 manifest에 머지 충돌 발생 → 높은 버전 쪽을 수용
- Phase U5 보고에서 "manifest를 커밋하면 팀 전체에 반영됩니다" 안내

#### 신규 파일 추가

마이그레이션의 `[new]` 항목:
- 초기 셋업과 동일하게 생성 (템플릿 + profile 치환)
- manifest의 `files`에 새 항목 추가
- 이미 같은 경로에 파일이 있으면: "이미 {path}가 존재합니다. 덮어쓸까요?" 확인

### 12.6 managed 파일 자동 변경 감지

managed 파일의 템플릿 변경은 마이그레이션 없이 자동으로 감지한다. 이 메커니즘은 마이그레이션 레지스트리를 **대체하지 않고 보완**한다.

#### 감지 알고리즘

Phase U1에서 각 managed 파일에 대해:

1. manifest.files[path]에서 카테고리가 `managed`인 항목을 추출한다
2. 해당 파일의 소스 템플릿을 스킬 디렉토리에서 읽는다 (§ 12.6.1 매핑 참조)
3. manifest.profile의 값으로 플레이스홀더를 치환하여 **"예상 출력"**을 생성한다
4. "예상 출력"의 SHA-256 해시를 계산한다 (`expectedHash`)
5. 비교:
   - `expectedHash == manifest.files[path].templateHash` → 템플릿 변경 없음
   - `expectedHash != manifest.files[path].templateHash` → 템플릿 변경됨

6. 별도로 현재 배포된 파일의 해시도 계산한다 (`currentFileHash`)
7. 최종 4-상태 판정:

| 템플릿 변경? | 사용자 수정? (`currentFileHash != templateHash`) | 판정 | 이유 |
|---|---|---|---|
| No | No | **스킵** | 템플릿/프로필 변경 없음 |
| No | Yes | **스킵** | 사용자 변경 유지, 템플릿 업데이트 없음 |
| Yes | No | **자동 덮어쓰기** | 템플릿 변경 감지, 사용자 수정 없음 |
| Yes | Yes | **사용자 선택** | 템플릿 변경 + 사용자 수정 감지 → 3가지 선택지 (§ 12.2) |

`userOverride: true`인 파일은 위 판정을 거치지 않고 자동 스킵한다.

#### 12.6.1 파일-템플릿 매핑

| 배포 파일 | 소스 템플릿 |
|-----------|------------|
| `agents/architect.md` | `templates/agents/architect.md` |
| `agents/debugger.md` | `templates/agents/debugger.md` |
| `agents/implementer.md` | `templates/agents/implementer.md` |
| `agents/reviewer.md` | `templates/agents/reviewer.md` |
| `agents/security-reviewer.md` | `templates/agents/security-reviewer.md` |
| `agents/simplifier.md` | `templates/agents/simplifier.md` |
| `agents/test-engineer.md` | `templates/agents/test-engineer.md` |
| `.claude/rules/session-routine.md` | `templates/rules/session-routine.md` |
| `.claude/rules/coding-standards.md` | `templates/rules/coding-standards.md` |
| `.claude/rules/git-workflow.md` | `templates/rules/git-workflow.md` |
| `init.sh` | `templates/init.sh` |
| `scripts/structural-test.ts` | `templates/structural-test-{architectureType}.ts` |
| `scripts/doc-freshness.ts` | `templates/doc-freshness.ts` |

`docs/` 하위 디렉토리 등 매핑에 없는 managed 파일은 이 자동 감지 대상에서 제외하고, 마이그레이션으로만 관리한다.

#### 마이그레이션과의 관계

| 변경 유형 | 담당 메커니즘 |
|-----------|-------------|
| managed 파일 템플릿 변경 | **자동 감지** (마이그레이션 `[managed] overwrite` 불필요) |
| custom 파일 외과적 수정 | 마이그레이션 전담 |
| 신규 파일 추가 `[new]` | 마이그레이션 전담 |
| 파일 삭제 `[remove]` | 마이그레이션 전담 |
| profile 필드 변경 `[profile]` | 마이그레이션 전담 |
| data 스키마 변경 `[data]` | 마이그레이션 전담 |

마이그레이션이 0건이어도 managed 파일은 이 메커니즘으로 자동 갱신된다.
