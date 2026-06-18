# Phase 2b-3 Increment 2 — PRD 빈 섹션 정적 검사 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `harness-check.sh` ⑩에 `prd_content_hygiene` 함수를 추가해, 작성된 PRD의 필수 `Edge Cases` 섹션이 비어 있으면(헤딩/주석/공백/단독 placeholder만) exit 0 ⚠️ 경고한다.

**Architecture:** 빈 섹션 판정에 필요한 `prd_section_body` awk를 harness-check.sh에 추출 마커로 감싼 **canonical 실행 소스**로 두고(현 intent-distill awk와 byte-identical, 로직 불변), 신규 `prd_content_hygiene`이 그것을 호출한다. CRLF 정규화·placeholder 필터는 awk 밖 bash 로컬 후처리. 기존 2개 awk 사본 중 coverage 픽스처는 canonical을 source하도록 전환(사본 제거), intent-distill SKILL.md의 doc 사본은 drift-guard 테스트로 동기 보장. 신규 managed 파일·플레이스홀더·프로필 필드 0.

**Tech Stack:** bash, awk(POSIX), node(feature_list 불필요 — 내용 검사는 id 대조 없음), 골든 픽스처(추출-source 패턴).

## Global Constraints

- 목표 버전: **v1.29.0** (MINOR, 하위 호환, 마이그레이션 불필요).
- **신규 managed 파일 0, 신규 플레이스홀더 0, 프로필 필드 0, 카테고리 불변.**
- `harness-check.sh` standalone 실행 불변식 유지 (외부 파일 source 의존 금지 — 픽스처만 source).
- ⑩ 전부 **exit 0 경고-전용** — `STRUCT_FAIL`/`QUALITY_FAIL`/exit code 무영향.
- 검사 대상: `docs/product-specs/*.md` 중 `README.md`·`_template.md` 제외. 검사 섹션 = `edge-cases` 단독.
- 결정적·보수적: 모호하면 침묵. `prd_section_body` awk 로직은 **한 글자도 변경 금지**(intent-distill과 byte-identical 유지 — drift-guard가 강제).
- placeholder 단독 줄만 "빈" 취급, 문장형(이유 동반)은 생존.
- 커밋 메시지 한국어, `type(scope): 설명` 형식, scope=`templates`/`skill`/`refs`/`tracking`/`test`. 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## Task 1: `prd_section_body` canonical 실행 소스 + drift-guard

harness-check.sh에 `prd_section_body`를 추출 마커로 추가하고(현 intent-distill awk와 동일), 정규화 동기를 단언하는 drift-guard 테스트를 만든다. 이 태스크의 산출물 = "공유 awk가 canonical 위치에 있고 기계적으로 잠김".

**Files:**
- Modify: `skills/harness-scaffold/templates/harness-check.sh` (⑩ 섹션, 현재 line 192-266 사이 `prd_marker_hygiene` end 마커 직후 = line 263 다음)
- Create: `test/prd-section-body-drift.sh`

**Interfaces:**
- Produces: bash 함수 `prd_section_body(sec, file)` — stdout에 섹션 본문(주석/헤딩/공백 제거) 줄들. 추출 마커 `# --- harness:prd-section-body:start ---` / `# --- harness:prd-section-body:end ---`.

- [ ] **Step 1: drift-guard 테스트 작성 (실패 예정)**

Create `test/prd-section-body-drift.sh`:

```bash
#!/usr/bin/env bash
# prd_section_body drift-guard — Phase 2b-3 Increment 2
# harness-check.sh(canonical 실행 소스)와 intent-distill SKILL.md §4.1 doc 사본의
# prd_section_body awk가 정규화 후 동일한지 단언 (3-way drift 봉쇄).
# coverage 픽스처는 source 전환(Task 3)으로 자동 일치하므로 비교 대상 아님.
# 사용법: bash test/prd-section-body-drift.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HC="$ROOT/skills/harness-scaffold/templates/harness-check.sh"
SK="$ROOT/skills/intent-distill/SKILL.md"
# 함수 본문만 추출 + 선행/내부/후행 공백 정규화 (들여쓰기 차이 무시 — codex brittle 우려 반영)
norm(){ sed -n '/prd_section_body()/,/^[[:space:]]*}/p' "$1" \
        | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g'; }
A="$(norm "$HC")"; B="$(norm "$SK")"
[ -n "$A" ] || { echo "❌ harness-check.sh에서 prd_section_body 추출 실패"; exit 1; }
[ -n "$B" ] || { echo "❌ intent-distill SKILL.md에서 prd_section_body 추출 실패"; exit 1; }
if [ "$A" = "$B" ]; then
  echo "✅ prd_section_body 동기 (harness-check ≡ intent-distill SKILL.md)"; exit 0
else
  echo "❌ prd_section_body drift 발견:"; diff <(printf '%s\n' "$A") <(printf '%s\n' "$B"); exit 1
fi
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `bash test/prd-section-body-drift.sh`
Expected: FAIL — `❌ harness-check.sh에서 prd_section_body 추출 실패` (harness-check에 아직 함수 없음), exit 1.

- [ ] **Step 3: harness-check.sh에 `prd_section_body` 추가**

`skills/harness-scaffold/templates/harness-check.sh`에서 `# --- harness:prd-marker-hygiene:end ---` (현 line 263) 바로 **다음 줄**에 아래를 삽입한다:

```bash
# --- harness:prd-section-body:start (canonical 실행 소스 — test/prd-content-hygiene-fixtures.sh·test/intent-prd-coverage-fixtures.sh가 추출·source. intent-distill SKILL.md §4.1은 동일 로직 doc 사본이며 test/prd-section-body-drift.sh가 동기 보장 — 로직 복사 금지) ---
prd_section_body() {
  awk -v sec="$1" '
    /<!--[[:space:]]*harness:section=/ { insec = ($0 ~ ("harness:section=" sec "[[:space:]]")); next }
    !insec { next }
    { l=$0; sub(/^[[:space:]]+/,"",l); sub(/[[:space:]]+$/,"",l) }
    incmt { if (l ~ /-->/) incmt=0; next }
    l ~ /^<!--/ && l !~ /-->/ { incmt=1; next }
    l ~ /^<!--.*-->$/ { next }
    l ~ /^#/ { next }
    l == "" { next }
    { print l }
  ' "$2"
}
# --- harness:prd-section-body:end ---
```

> 주의: awk 본문은 intent-distill SKILL.md §4.1·`test/intent-prd-coverage-fixtures.sh`의 것과 **로직 동일**(들여쓰기는 자유 — drift-guard가 정규화 후 비교). 한 글자도 의미 변경 금지.

- [ ] **Step 4: drift-guard 통과 확인**

Run: `bash test/prd-section-body-drift.sh`
Expected: PASS — `✅ prd_section_body 동기 (harness-check ≡ intent-distill SKILL.md)`, exit 0.

- [ ] **Step 5: 커밋**

```bash
git add skills/harness-scaffold/templates/harness-check.sh test/prd-section-body-drift.sh
git commit -m "$(cat <<'EOF'
feat(templates): harness-check prd_section_body canonical 소스 + drift-guard (이슈 #15 2b-3 Inc2)

빈 섹션 검사용 prd_section_body awk를 harness-check.sh에 추출 마커로
canonical 실행 소스화(intent-distill awk와 byte-identical). drift-guard
테스트가 정규화 후 SKILL.md 사본과 동기 단언.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `prd_content_hygiene` 함수 + ⑩ 배선 + 골든 픽스처

빈 edge-cases 섹션을 검출하는 함수를 추가하고 ⑩에서 호출한다. 16케이스 골든 픽스처로 TDD. 산출물 = "빈 섹션 검사가 동작하고 회귀로 잠김".

**Files:**
- Modify: `skills/harness-scaffold/templates/harness-check.sh` (`prd_section_body:end` 마커 다음 + ⑩ 호출부 현 line 266 다음)
- Create: `test/prd-content-hygiene-fixtures.sh`

**Interfaces:**
- Consumes: `prd_section_body` (Task 1).
- Produces: bash 함수 `prd_content_hygiene()` — `docs/product-specs/` PRD를 순회, 빈 edge-cases면 `⚠️ empty-edge-cases: {basename} — …` 출력, 위반 0이면 `✅ PRD 내용 위생 정상`. substrate/PRD 부재 → `⏸️ … 보류`. 추출 마커 `# --- harness:prd-content-hygiene:start/end ---`.

- [ ] **Step 1: 골든 픽스처 작성 (실패 예정)**

Create `test/prd-content-hygiene-fixtures.sh`:

```bash
#!/usr/bin/env bash
# PRD 내용 위생(빈 edge-cases 섹션) 골든 픽스처 — Phase 2b-3 Increment 2
# 검증: harness-check.sh의 prd_section_body + prd_content_hygiene을 추출·source해
#   빈 섹션 검출 + placeholder 필터 + 앵커 게이트 + 보류 + render-after(exit 0)를 확인한다.
# 사용법: bash test/prd-content-hygiene-fixtures.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HC="$ROOT/skills/harness-scaffold/templates/harness-check.sh"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
no(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# 템플릿에서 두 함수 블록 추출·source (단일 소스 — 로직 복사 없음)
FN="$(mktemp)"
sed -n '/# --- harness:prd-section-body:start/,/# --- harness:prd-section-body:end/p' "$HC" > "$FN"
sed -n '/# --- harness:prd-content-hygiene:start/,/# --- harness:prd-content-hygiene:end/p' "$HC" >> "$FN"
if ! grep -q 'prd_content_hygiene()' "$FN" || ! grep -q 'prd_section_body()' "$FN"; then
  echo "❌ 템플릿에서 함수 추출 실패 (추출 마커/함수 정의 확인)"; rm -f "$FN"; exit 1
fi
# shellcheck disable=SC1090
. "$FN"

TMP="$(mktemp -d)"; trap 'rm -f "$FN"; rm -rf "$TMP"' EXIT
run_in(){ ( cd "$1" && prd_content_hygiene ); }
mkproj(){ mkdir -p "$1/docs/product-specs"
  printf '# README\n' > "$1/docs/product-specs/README.md"
  printf '@feature:F000\n<!-- harness:section=edge-cases -->\n# T\n' > "$1/docs/product-specs/_template.md"; }
# edge-cases 앵커 + 본문 조립 헬퍼
prd(){ printf '@feature:F001\n<!-- harness:section=edge-cases -->\n## ⚠️ Edge Cases\n%b<!-- harness:section=acceptance -->\n## Acceptance\n본문\n' "$2" > "$1"; }

echo "C1: 정상(이유-동반 문장) → 무경고"
D="$TMP/c1"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" 'someday 항목은 집계에서 제외한다\n'
OUT="$(run_in "$D")"; { echo "$OUT" | grep -q "✅ PRD 내용 위생 정상" && ! echo "$OUT" | grep -q "⚠️"; } && ok "정상 무경고" || no "정상인데 경고: $OUT"

echo "C2: 헤딩만(빈 본문) → 경고"
D="$TMP/c2"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" ''
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "헤딩만 검출" || no "헤딩만 미검출"

echo "C3: 공백만 → 경고"
D="$TMP/c3"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '   \n\n'
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "공백만 검출" || no "공백만 미검출"

echo "C4: 주석만(단일+멀티라인) → 경고"
D="$TMP/c4"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '<!-- 한 줄 -->\n<!--\n여러 줄 안내\n-->\n'
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "주석만 검출" || no "주석만 미검출"

echo "C5: bare TBD → 경고"
D="$TMP/c5"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" 'TBD\n'
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "TBD 검출" || no "TBD 미검출"

echo "C6: bare N/A (리스트마커 동반) → 경고"
D="$TMP/c6"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '- N/A\n'
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "N/A 검출" || no "N/A 미검출"

echo "C7: bare 없음 → 경고"
D="$TMP/c7"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '없음\n'
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "없음 검출" || no "없음 미검출"

echo "C8: '명시적 제외 사항 없음'(문장) → 침묵"
D="$TMP/c8"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '명시적 제외 사항 없음\n'
OUT="$(run_in "$D")"; { ! echo "$OUT" | grep -q "⚠️"; } && ok "문장형 침묵" || no "문장형 오탐: $OUT"

echo "C9: '없음 — someday 제외'(이유 동반) → 침묵"
D="$TMP/c9"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '없음 — someday 태스크는 제외\n'
OUT="$(run_in "$D")"; { ! echo "$OUT" | grep -q "⚠️"; } && ok "이유동반 침묵" || no "이유동반 오탐: $OUT"

echo "C10: edge-cases 앵커 부재 → 침묵(게이트)"
D="$TMP/c10"; mkproj "$D"; printf '@feature:F001\n# 앵커 없음\n본문\n' > "$D/docs/product-specs/F001-a.md"
OUT="$(run_in "$D")"; { ! echo "$OUT" | grep -q "⚠️"; } && ok "앵커 부재 침묵" || no "앵커 부재 오탐: $OUT"

echo "C11: 코드펜스 예시만(펜스 구분선 존재) → 침묵"
D="$TMP/c11"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '```html\n<!-- example -->\n```\n'
OUT="$(run_in "$D")"; { ! echo "$OUT" | grep -q "⚠️"; } && ok "코드펜스 침묵" || no "코드펜스 오탐: $OUT"

echo "C12: CRLF 빈 edge-cases → 경고"
D="$TMP/c12"; mkproj "$D"; printf '@feature:F001\r\n<!-- harness:section=edge-cases -->\r\n## Edge\r\n   \r\n<!-- harness:section=acceptance -->\r\n## A\r\n본문\r\n' > "$D/docs/product-specs/F001-a.md"
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "CRLF 빈 검출" || no "CRLF 빈 미검출"

echo "C13: substrate 부재 → 보류"
D="$TMP/c13"; mkdir -p "$D"
echo "$(run_in "$D")" | grep -q "⏸️ product-specs substrate 부재" && ok "substrate 부재 보류" || no "substrate 보류 미동작"

echo "C14: 작성 PRD 0개 → 보류"
D="$TMP/c14"; mkproj "$D"
echo "$(run_in "$D")" | grep -q "⏸️ 작성된 PRD 없음" && ok "PRD 0개 보류" || no "PRD 0개 보류 미동작"

echo "C15: README/_template은 검사 제외 (경고 0)"
D="$TMP/c15"; mkproj "$D"; prd "$D/docs/product-specs/F001-ok.md" '실제 제외 규칙 명시\n'
OUT="$(run_in "$D")"; { ! echo "$OUT" | grep -qE "_template|README" && ! echo "$OUT" | grep -q "⚠️"; } && ok "substrate 파일 제외(경고 0)" || no "substrate 파일 오탐: $OUT"

echo "C16: render-after 와이어링 (전체 스크립트 exit 0 + ⑩ 내용 위생 출력)"
D="$TMP/c16"; mkproj "$D"; prd "$D/docs/product-specs/F001-ok.md" '실제 제외 규칙 명시\n'
printf '[{"id":"F001"}]' > "$D/feature_list.json"
for f in AGENTS.md ARCHITECTURE.md CLAUDE.md claude-progress.txt .harness-friction.jsonl .harness-intent.jsonl init.sh; do printf '# x\n' > "$D/$f"; done
mkdir -p "$D/scripts"; printf '// st\n' > "$D/scripts/structural-test.ts"; printf '// df\n' > "$D/scripts/doc-freshness.ts"
sed -e 's#{{LINT_ARCH_COMMAND}}#true#g' -e 's#{{VALIDATE_COMMAND}}#true#g' \
    -e 's#{{DOC_CHECK_COMMAND}}#true#g' -e 's#{{PATH_ALIAS_LIST}}##g' "$HC" > "$D/hc.sh"
( cd "$D" && bash hc.sh > out.txt 2>&1 ); CODE=$?
{ [ "$CODE" -eq 0 ] && grep -q "⑩ PRD 위생" "$D/out.txt" && grep -q "✅ PRD 내용 위생 정상" "$D/out.txt"; } \
  && ok "전체 실행 exit 0 + ⑩ 내용 위생 출력" || no "render-after 실패 (exit $CODE): $(cat "$D/out.txt")"

echo
echo "결과: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && { echo "✅ 전부 통과"; exit 0; } || { echo "❌ 실패 있음"; exit 1; }
```

- [ ] **Step 2: 픽스처 실행 → 실패 확인**

Run: `bash test/prd-content-hygiene-fixtures.sh`
Expected: FAIL — `❌ 템플릿에서 함수 추출 실패` (prd_content_hygiene 아직 없음), exit 1.

- [ ] **Step 3: harness-check.sh에 `prd_content_hygiene` 추가**

Task 1에서 넣은 `# --- harness:prd-section-body:end ---` 줄 **다음**에 아래를 삽입한다:

```bash
# --- harness:prd-content-hygiene:start (test/prd-content-hygiene-fixtures.sh가 추출·source — prd_section_body 의존; 로직 복사 금지) ---
prd_content_hygiene() {
  local specs="docs/product-specs"
  if [ ! -f "$specs/README.md" ] || [ ! -f "$specs/_template.md" ]; then
    echo "⏸️ product-specs substrate 부재 — PRD 내용 위생 보류 (① 참조)"; return 0
  fi
  local prds
  prds=$(ls "$specs"/*.md 2>/dev/null | grep -vE '/(README|_template)\.md$')
  if [ -z "$prds" ]; then
    echo "⏸️ 작성된 PRD 없음 — PRD 내용 위생 보류 (온디맨드 작성, 정상)"; return 0
  fi
  local warn=0 prd base tmp line t hasreal
  while IFS= read -r prd; do
    [ -n "$prd" ] || continue
    base=$(basename "$prd")
    # 앵커 게이트: edge-cases 앵커 없으면 침묵 (pre-template/수작성 PRD 미벌)
    grep -qE '^[[:space:]]*<!--[[:space:]]*harness:section=edge-cases([[:space:]]|-->)' "$prd" 2>/dev/null || continue
    # CRLF 정규화 후 섹션 본문 추출
    tmp=$(mktemp); tr -d '\r' < "$prd" > "$tmp"
    hasreal=0
    while IFS= read -r line; do
      # 리스트마커(-,*,>)·따옴표·둘러싼 구두점 트림
      t=$(printf '%s' "$line" | sed -E 's/^[[:space:]>*-]+//; s/^["'"'"']+//; s/[[:space:]"'"'"'.)]+$//')
      [ -z "$t" ] && continue
      # 단독 placeholder 토큰이면 비실질 (ASCII 대소문자 무시 + 한국어; C 로케일로 안전 lowercase)
      case "$(printf '%s' "$t" | LC_ALL=C tr '[:upper:]' '[:lower:]')" in
        tbd|todo|tba|n/a|na|n.a|none|없음|미정|"해당 없음"|해당없음) ;;
        *) hasreal=1; break ;;
      esac
    done < <(prd_section_body edge-cases "$tmp")
    rm -f "$tmp"
    if [ "$hasreal" -eq 0 ]; then
      echo "⚠️ empty-edge-cases: $base — Edge Cases 섹션이 비어있음. 제외할 사항이 없다면 그 이유를 한 문장으로 명시하세요."
      warn=1
    fi
  done <<PRD_LIST
$prds
PRD_LIST
  [ "$warn" -eq 0 ] && echo "✅ PRD 내용 위생 정상"
  return 0
}
# --- harness:prd-content-hygiene:end ---
```

- [ ] **Step 4: ⑩ 호출부 배선**

`harness-check.sh`에서 현재 `prd_marker_hygiene` 호출(현 line 266) **다음 줄**에 추가:

```bash
prd_content_hygiene
```

결과적으로 ⑩ 블록은 다음 순서가 된다 (참고):
```bash
echo "── ⑩ PRD 위생 ──"
prd_marker_hygiene
prd_content_hygiene
```

- [ ] **Step 5: 픽스처 통과 확인**

Run: `bash test/prd-content-hygiene-fixtures.sh`
Expected: PASS — `결과: PASS=16 FAIL=0` / `✅ 전부 통과`, exit 0.

- [ ] **Step 6: 마커 픽스처 회귀 확인 (render-after에 내용 위생 추가됐으나 무회귀)**

Run: `bash test/prd-marker-hygiene-fixtures.sh`
Expected: PASS — `✅ 전부 통과` (T12 render-after는 마커 문자열만 grep하므로 영향 없음).

- [ ] **Step 7: drift-guard 재확인 (함수 추가가 추출 경계 안 깸)**

Run: `bash test/prd-section-body-drift.sh`
Expected: PASS — `✅ prd_section_body 동기`.

- [ ] **Step 8: 커밋**

```bash
git add skills/harness-scaffold/templates/harness-check.sh test/prd-content-hygiene-fixtures.sh
git commit -m "$(cat <<'EOF'
feat(templates): harness-check ⑩ PRD 빈 섹션 검사 (이슈 #15 2b-3 Inc2)

prd_content_hygiene — 작성 PRD의 빈 edge-cases 섹션(헤딩/주석/공백/단독
placeholder만) 검출, exit 0 경고. 앵커 게이트(부재→침묵)·CRLF 정규화·
placeholder 필터(TBD/N/A/없음 등 단독만, 문장형 생존). 골든 픽스처 C1~C16.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: coverage 픽스처를 canonical source로 전환 (사본 제거)

`test/intent-prd-coverage-fixtures.sh`의 자체 `prd_section_body` 사본을 제거하고 harness-check.sh에서 추출·source. 산출물 = "실행 awk 사본 2개 → 1개로 수렴".

**Files:**
- Modify: `test/intent-prd-coverage-fixtures.sh` (현 line 11-23 함수 정의 + line 33 trap)

**Interfaces:**
- Consumes: harness-check.sh의 `# --- harness:prd-section-body:start/end ---` 블록 (Task 1).

- [ ] **Step 1: 인라인 awk 정의를 추출·source로 교체**

`test/intent-prd-coverage-fixtures.sh`에서 현재 line 11-23 (`prd_section_body() { ... }` 전체)을 아래로 **치환**한다:

```bash
# prd_section_body는 harness-check.sh(canonical 실행 소스)에서 추출·source — 로직 복사 없음
# (동기 보장: test/prd-section-body-drift.sh)
HC="$ROOT/skills/harness-scaffold/templates/harness-check.sh"
FN="$(mktemp)"
sed -n '/# --- harness:prd-section-body:start/,/# --- harness:prd-section-body:end/p' "$HC" > "$FN"
grep -q 'prd_section_body()' "$FN" || { echo "❌ harness-check.sh에서 prd_section_body 추출 실패"; rm -f "$FN"; exit 1; }
# shellcheck disable=SC1090
. "$FN"
```

- [ ] **Step 2: trap에 FN 정리 추가**

현재 line 33 `TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT`을 아래로 **치환**한다(FN도 정리):

```bash
TMP="$(mktemp -d)"; trap 'rm -f "$FN"; rm -rf "$TMP"' EXIT
```

- [ ] **Step 3: coverage 픽스처 통과 확인**

Run: `bash test/intent-prd-coverage-fixtures.sh`
Expected: PASS — `✅ 전부 통과`. (T3 섹션 추출기 테스트가 이제 harness-check의 awk로 동작.)

- [ ] **Step 4: drift-guard 재확인**

Run: `bash test/prd-section-body-drift.sh`
Expected: PASS (coverage는 이제 source라 비교 대상 아님 — harness-check ≡ SKILL.md만 단언).

- [ ] **Step 5: 커밋**

```bash
git add test/intent-prd-coverage-fixtures.sh
git commit -m "$(cat <<'EOF'
refactor(test): coverage 픽스처 prd_section_body를 canonical source로 전환 (이슈 #15 2b-3 Inc2)

자체 awk 사본 제거 → harness-check.sh 추출 마커에서 source. 실행 awk
사본 2→1개 수렴. drift-guard가 SKILL.md doc 사본만 잠금.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: 문서 동기화 (intent-distill 주석 + checklist + scaffold)

doc 사본·SSoT·생성 사양에 Inc2를 반영한다. 산출물 = "계약 문서가 ⑩ 내용 위생과 정합".

**Files:**
- Modify: `skills/intent-distill/SKILL.md` (§4.1 awk 위 doc 노트, 현 line 75 부근)
- Modify: `skills/harness-setup/references/harness-checklist.md` (line 40 부근 §1.1, line 250-251 부근 §8)
- Modify: `skills/harness-scaffold/SKILL.md` (line 1006 부근 §5.14)

**Interfaces:** 없음 (문서).

- [ ] **Step 1: intent-distill SKILL.md에 canonical 노트 추가**

`skills/intent-distill/SKILL.md` §4.1에서 awk 코드펜스 직전 줄(현 line 75 `섹션 본문은 정적 추출기로 얻는다…`)을 아래로 **치환**한다(awk 본문은 불변 — drift-guard 보호):

```markdown
   섹션 본문은 정적 추출기로 얻는다(앵커는 경계로만, HTML 주석·`_template.md`/`README.md`·헤딩 제외). 아래 `prd_section_body`는 **실행 정본이 `scripts/harness-check.sh`의 동명 함수**이며 이 doc 사본과 로직 동일하다 — 스킬 저장소의 `test/prd-section-body-drift.sh`가 동기를 강제한다(수정 시 양쪽 함께):
```

- [ ] **Step 2: drift-guard 재확인 (노트 추가가 추출 경계 안 깸)**

Run: `bash test/prd-section-body-drift.sh`
Expected: PASS — `✅ prd_section_body 동기` (노트는 `prd_section_body()` 시작 줄 위에 있어 추출 범위 밖).

- [ ] **Step 3: checklist §1.1에 내용 위생 추가**

`skills/harness-setup/references/harness-checklist.md` 현 line 40 다음에 한 줄 추가:

```markdown
  > 작성된 PRD의 **내용 위생**(필수 `Edge Cases` 섹션 비어있지 않음 — 헤딩/주석/공백/단독 placeholder만이면 경고)도 harness-check ⑩이 검사한다 — **경고 전용(exit 0)**, 앵커 부재 PRD는 침묵.
```

- [ ] **Step 4: checklist §8의 ⑩ 설명 확장**

현 line 250 `…pre-push(⑨)·PRD 마커 위생(⑩) 포함).`을 `…pre-push(⑨)·PRD 위생(⑩: 마커+내용) 포함).`으로 수정하고, line 251 다음에 한 줄 추가:

```markdown
> ⑩ PRD 내용 위생은 작성 PRD의 필수 `Edge Cases` 섹션이 비어 있으면(`empty-edge-cases`) 경고한다 — edge-cases 앵커 존재 시에만, 단독 placeholder(TBD/N/A/없음 등)는 빈 것으로 취급하되 이유-동반 문장은 침묵. 역시 exit 0 경고-전용.
```

- [ ] **Step 5: scaffold §5.14에 ⑩ 내용 위생 기술**

`skills/harness-scaffold/SKILL.md` 현 line 1006 다음에 한 줄 추가:

```markdown
- 템플릿에는 ⑩ PRD 내용 위생 검사(`prd_content_hygiene` 함수, `prd_section_body` awk 의존, 경고 전용·exit 0)도 포함된다 — substrate 존재 시 작성 PRD의 필수 `Edge Cases` 섹션이 비어 있으면(`empty-edge-cases`) 검출한다. 앵커 부재 PRD는 침묵, 단독 placeholder만 "빈"으로 취급. 신규 플레이스홀더 없음(경로·앵커·placeholder 집합 하드코딩). 판정 기준: `references/harness-checklist.md` § 8.
```

- [ ] **Step 6: 커밋**

```bash
git add skills/intent-distill/SKILL.md skills/harness-setup/references/harness-checklist.md skills/harness-scaffold/SKILL.md
git commit -m "$(cat <<'EOF'
docs(skill): ⑩ PRD 내용 위생 SSoT 동기화 (이슈 #15 2b-3 Inc2)

intent-distill §4.1에 canonical 노트(실행 정본=harness-check, drift-guard
보장), checklist §1.1/§8 + scaffold §5.14에 빈 섹션 검사 기술.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: 렌더-후 실측 + 버전 범프 v1.29.0 + 트래킹

전체 회귀 + 픽스처 프로젝트 실측 후 버전 범프·트래킹. 산출물 = "릴리스 가능 상태".

**Files:**
- Modify: `skills/harness-setup/references/project-context.md` (버전 히스토리·현재 버전)
- Modify: `.tracking/CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json` (version)
- Modify: `README.md` (버전 줄)
- Modify: `.tracking/HANDOFF.md` (현재 상태·다음 작업)
- Modify: `.tracking/TODO.md` (해당 시)

- [ ] **Step 1: 전체 골든 픽스처 회귀**

Run:
```bash
bash test/prd-section-body-drift.sh && \
bash test/prd-content-hygiene-fixtures.sh && \
bash test/prd-marker-hygiene-fixtures.sh && \
bash test/intent-prd-coverage-fixtures.sh && \
bash test/prd-substrate-fixtures.sh && \
bash test/run-fixtures.sh
```
Expected: 전부 exit 0 (`✅ 전부 통과` / `✅ 전체 통과`).

- [ ] **Step 2: 렌더-후 실측 (구조 정상 시 exit 0 유지)**

C16이 이미 자동화하지만, 빈 섹션 PRD에서 ⚠️가 실제로 뜨고 exit 0인지 1회 수동 확인:
```bash
T=$(mktemp -d); mkdir -p "$T/docs/product-specs"
printf '# README\n' > "$T/docs/product-specs/README.md"
printf '@feature:F000\n<!-- harness:section=edge-cases -->\n' > "$T/docs/product-specs/_template.md"
printf '@feature:F001\n<!-- harness:section=edge-cases -->\n## Edge\nTBD\n<!-- harness:section=acceptance -->\n## A\n본문\n' > "$T/docs/product-specs/F001-x.md"
printf '[{"id":"F001"}]' > "$T/feature_list.json"
for f in AGENTS.md ARCHITECTURE.md CLAUDE.md claude-progress.txt .harness-friction.jsonl .harness-intent.jsonl init.sh; do printf '# x\n' > "$T/$f"; done
mkdir -p "$T/scripts"; printf '//\n' > "$T/scripts/structural-test.ts"; printf '//\n' > "$T/scripts/doc-freshness.ts"
sed -e 's#{{LINT_ARCH_COMMAND}}#true#g' -e 's#{{VALIDATE_COMMAND}}#true#g' -e 's#{{DOC_CHECK_COMMAND}}#true#g' -e 's#{{PATH_ALIAS_LIST}}##g' \
  skills/harness-scaffold/templates/harness-check.sh > "$T/hc.sh"
( cd "$T" && bash hc.sh; echo "EXIT=$?" ) | grep -E "empty-edge-cases|EXIT="
rm -rf "$T"
```
Expected: `⚠️ empty-edge-cases: F001-x.md …` 출력 + `EXIT=0`.

- [ ] **Step 3: 버전 범프 v1.28.0 → v1.29.0**

`.claude-plugin/plugin.json`의 `"version"`을 `1.29.0`으로 수정. `README.md` 버전 줄, `skills/harness-setup/references/project-context.md`의 현재 버전·버전 히스토리에 1.29.0 항목 추가(빈 섹션 검사·공유 헬퍼 (c)+(e)·drift-guard 요지). `.tracking/CHANGELOG.md`에 `### 추가 (Added)` 항목.

> 정확한 현재 버전 문자열 위치 확인: `grep -rn "1\.28\.0" .claude-plugin/plugin.json README.md skills/harness-setup/references/project-context.md`

- [ ] **Step 4: HANDOFF·TODO 갱신**

`.tracking/HANDOFF.md`: 현재 버전 1.29.0, Session 항목 추가(Inc2 종결), "다음 작업"을 **2b-4(역방향 미검증 명세 + feature↔PRD 교차)**로 갱신. P7 커버리지 줄에 1.29.0 추가. `.tracking/TODO.md` 해당 항목 갱신.

- [ ] **Step 5: 커밋**

```bash
git add .claude-plugin/plugin.json README.md skills/harness-setup/references/project-context.md .tracking/
git commit -m "$(cat <<'EOF'
chore(tracking): 1.29.0 범프 + 2b-3 Inc2 트래킹 (이슈 #15)

PRD 빈 섹션 검사 종결. 버전 히스토리·CHANGELOG·HANDOFF/TODO 갱신,
다음 작업 2b-4(역방향 미검증 명세 + 교차) 지정.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

> git tag는 stacked-PR 머지 시점에 적용(inc2-handoff §참고 — "태그는 머지 시점"). 이 계획에서는 태그 생성 안 함.

---

## Self-Review

**1. Spec coverage** (설계 §별 → 태스크 매핑):
- §3.1 검사 대상(README/_template 제외, edge-cases 단독) → Task 2 Step 3 (`grep -vE`, 앵커 게이트), C15.
- §4 공유 헬퍼 (c)+(e) → Task 1(canonical+drift-guard) + Task 3(coverage source 전환) + Task 4 Step 1(SKILL.md 노트).
- §4 awk 불변 → Task 1 Step 3 주의문 + drift-guard.
- §5 판정 로직(앵커 게이트/CRLF/placeholder 필터/판정) → Task 2 Step 3, C2~C12.
- §5 placeholder 집합(ASCII+한국어) → Task 2 Step 3 case 목록, C5~C9.
- §5.1 보류(substrate/PRD 0, feature_list 불필요) → Task 2 Step 3, C13·C14.
- §5.2 오탐 가드(멀티라인 주석/코드펜스/앵커부재) → C4·C11·C10.
- §6 동기화 지점 → Task 4 (intent-distill·checklist·scaffold), Task 5(버전).
- §7 검증(16케이스+drift-guard+render-after) → Task 2 픽스처 + Task 1 drift-guard + C16/Task 5 Step 2.
- §8 버전 v1.29.0·마이그레이션 불필요 → Task 5.

갭 없음.

**2. Placeholder scan:** 모든 step에 실제 코드/명령/기대 출력 포함. "적절히 처리" 류 없음. ✅

**3. Type consistency:** `prd_section_body`(Task 1 produces) → Task 2·3에서 동일명 호출. `prd_content_hygiene`(Task 2 produces) → 픽스처에서 동일명. 추출 마커 문자열(`harness:prd-section-body`·`harness:prd-content-hygiene`) Task 1·2·3에서 동일. 경고 문자열 `empty-edge-cases`·`✅ PRD 내용 위생 정상`·`⏸️ … 보류` Task 2 정의 ↔ 픽스처 grep 일치. ✅

> 주의(구현자): Task 3·Task 5 Step 2의 sed/placeholder 치환 경로·줄 번호는 작성 시점 기준이다. 편집 전 해당 파일을 읽어 현재 줄을 확인하고, 줄 번호가 밀렸으면 **문자열 앵커**(`prd_section_body()`·`# --- harness:prd-marker-hygiene:end ---`·`prd_marker_hygiene$`)로 위치를 다시 잡으라.
