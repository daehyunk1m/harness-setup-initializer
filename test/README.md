# test/ — 스킬 자체 검증

생성 프로젝트가 아니라 **harness-setup 스킬의 산출물(템플릿)이 옳은지**를 검증한다.

## 골든 픽스처 (structural-test)

```bash
bash test/run-fixtures.sh
```

`templates/structural-test-{layer,fsd,domain}.ts`를 아키텍처별 픽스처에 대해 렌더·실행하여,
**허용 import만 있는 트리(`src-pass`)는 통과(exit 0)**, **금지 import가 섞인 트리(`src-fail`)는 차단(exit 1)**
하는지 확인한다. 템플릿/렌더 로직을 수정하거나 바탕 모델·스킬 버전이 바뀌었을 때 회귀를 잡는 앵커다.

| 픽스처 | 검증하는 금지 패턴 |
|--------|-------------------|
| `fixtures/layer-based/` | 레이어 의존성 역전 (alias + 상대경로) |
| `fixtures/fsd/` | 레이어 위반 + cross-slice + public-api 우회 |
| `fixtures/domain/` | 도메인 간 직접 import + 공유→도메인 역방향 |

> **한계**: 이 테스트는 *템플릿 자체*의 정확성만 본다. 특정 프로젝트의 규칙 오설정(잘못된
> `LAYER_RULES` 등)은 잡지 못한다 — 그것은 scaffold Phase 4의 의미론적 승인 게이트가 보완한다.
> (배경: 멀티모델 자문 — codex 메타테스트 권고 + gemini negative testing)

**릴리스 전 반드시 실행**: 템플릿 또는 `harness-scaffold/SKILL.md`의 structural-test 생성 규칙(§ 5.4)을 수정하면 이 러너로 회귀를 확인한다.
