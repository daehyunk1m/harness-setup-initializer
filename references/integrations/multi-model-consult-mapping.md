# multi-model-consult 연계 매핑 (정본)

> 하네스의 multi-model-consult 컴패니언 스킬 연계 정본.
> 메커니즘 정본: `_protocol.md`. 이 파일은 *내용*(연계 문구·감지·제외) 정본.
> 검증 기준일: 2026-06-13 (multi-model-consult 1.6.3, codex 0.134.0 + gemini 0.46.0 실측)

---

## 1. 감지 (SKILL.md Step 1.6)

```bash
# 1순위: 글로벌 스킬 심링크 (install.sh가 생성)
ls -d ~/.claude/skills/multi-model-consult 2>/dev/null
# 자문 CLI — 최소 1개 있어야 연계 가치가 있다
command -v codex >/dev/null 2>&1 && echo "codex"
command -v gemini >/dev/null 2>&1 && echo "gemini"
```

- 스킬 심링크 존재 + (codex 또는 gemini 중 1개 이상) → 감지 성공
- `source: "companion"`, `installPath: ~/.claude/skills/multi-model-consult`, `detectedVersion: null` (컴패니언이라 버전 추출 안 함)
- CLI가 0개면 자문이 불가하므로 **감지 실패로 처리** (질문 생략) — 스킬만 있고 CLI 없으면 연계 무의미
- `linkedSkills` 필드 없음 (단일 스킬 통합)

## 2. 연계 (AGENTS.md "보조 스킬" 섹션)

```markdown
- 복잡한 설계 결정/아키텍처 트레이드오프의 교차 자문: `multi-model-consult` (codex·gemini 합성)
```

> 출처 표기는 "(codex·gemini 합성)" — 감지된 CLI에 맞춰 조정 가능 (codex만 있으면 "(codex 합성)")

## 3. session-routine 연계 (`{{INTEGRATION_NOTES}}`)

```
복잡한 설계 결정·트레이드오프 분석이 필요하면 multi-model-consult로 교차 자문할 수 있다 (PRE-RED 정규 경로는 Architect/Plan 모드, 자문은 결정 보조).
```

> superpowers의 writing-plans 연계 문구와 **합산**된다 (둘 다 옵트인 시 `{{INTEGRATION_NOTES}}`에 2줄)

## 4. 제외 / 충돌 회피

- multi-model-consult는 **설계 결정·리뷰 보조**다. 코어의 TDD 사이클·Reviewer·검증 루프를 대체하지 않는다
- 자문은 읽기 전용 — 코드 수정·커밋은 코어 워크플로(TDD)가 수행. 자문 결과는 Claude가 합성하여 *판단 재료*로만 사용
- "모든 결정에 자문"이 아니라 **복잡한 트레이드오프**에만 (매 호출 외부 API 비용)

## 5. 갱신 절차

- codex/gemini CLI의 인자 체계가 바뀌면 `companion-skills/multi-model-consult/scripts/run-advisor.js`의 buildArgs를 갱신 (이 매핑이 아니라 스킬 본체)
- 감지 경로(install.sh 심링크 위치)가 바뀌면 § 1 갱신
