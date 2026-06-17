#!/usr/bin/env node
// run-advisor.js — 외부 모델 CLI(codex/gemini)를 호출하고 응답을 아티팩트로 저장한다.
//
// 사용법:
//   node run-advisor.js <codex|gemini> "<prompt>"
//   echo "<prompt>" | node run-advisor.js <codex|gemini> -
//
// 환경변수:
//   CONSULT_DISABLE_EXTERNAL_LLM=1  외부 호출 차단 (exit 3)
//   CONSULT_TIMEOUT_MS              타임아웃 (기본 180000)
//
// 종료 코드: 0 성공 / 1 CLI 실패(아티팩트는 저장됨) / 2 CLI 미설치 / 3 외부 호출 비활성화 / 4 사용법 오류
//
// 출력 계약: 성공/실패 모두 마지막 줄에 `ARTIFACT: <경로>` (호출자가 파싱)

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const ARTIFACT_DIR = path.join('.claude', 'artifacts', 'consult');
const PROVIDERS = ['codex', 'gemini'];

// Claude 세션 환경변수 누출 방지 — 자문 CLI는 독립 컨텍스트로 실행한다
function stripClaudeEnv(env) {
  const cleaned = { ...env };
  for (const key of Object.keys(cleaned)) {
    if (key.startsWith('CLAUDE') || key === 'CLAUDECODE') {
      delete cleaned[key];
    }
  }
  return cleaned;
}

// 자문은 읽기 전용이다 — 위험 플래그(--dangerously-*, --yolo)를 쓰지 않는다.
//   codex:  -s read-only (샌드박스)
//   gemini: --approval-mode plan (read-only 모드, codex -s read-only 대응)
//           --skip-trust 는 헤드리스 trusted-directory 게이트를 세션 한정으로 통과시킨다.
//           자문은 파일을 수정하지 않고(plan 모드) 컨텍스트는 프롬프트에 포함되므로 안전하다.
function buildArgs(provider, prompt, outFile) {
  if (provider === 'codex') {
    return ['exec', '-s', 'read-only', '--ephemeral', '--skip-git-repo-check',
            '--color', 'never', '-o', outFile, prompt];
  }
  if (provider === 'gemini') {
    return ['-p', prompt, '--approval-mode', 'plan', '--skip-trust'];
  }
  throw new Error(`unknown provider: ${provider}`);
}

function slugify(text) {
  return text.toLowerCase().replace(/[^a-z0-9가-힣]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'consult';
}

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
}

function writeArtifact({ provider, prompt, response, stderrTail, exitCode, durationMs, note }) {
  fs.mkdirSync(ARTIFACT_DIR, { recursive: true });
  const file = path.join(ARTIFACT_DIR, `${provider}-${slugify(prompt)}-${timestamp()}.md`);
  const body = [
    `# Consult Artifact — ${provider}`,
    '',
    `- Timestamp: ${new Date().toISOString()}`,
    `- Provider: ${provider}`,
    `- Exit code: ${exitCode}`,
    `- Duration: ${Math.round(durationMs / 1000)}s`,
    note ? `- Note: ${note}` : null,
    '',
    '## Prompt',
    '',
    prompt,
    '',
    '## Raw Output',
    '',
    response || '(응답 없음)',
    stderrTail ? `\n## Stderr (tail)\n\n\`\`\`\n${stderrTail}\n\`\`\`` : null,
  ].filter((line) => line !== null).join('\n');
  fs.writeFileSync(file, body + '\n');
  return file;
}

function readPrompt(argv) {
  const arg = argv[3];
  if (arg && arg !== '-') return arg;
  return fs.readFileSync(0, 'utf-8').trim(); // stdin
}

function main() {
  const provider = process.argv[2];
  if (!PROVIDERS.includes(provider)) {
    console.error(`사용법: node run-advisor.js <${PROVIDERS.join('|')}> "<prompt>" (또는 - 로 stdin)`);
    process.exit(4);
  }
  if (process.env.CONSULT_DISABLE_EXTERNAL_LLM === '1') {
    console.error('DISABLED: CONSULT_DISABLE_EXTERNAL_LLM=1 — 외부 LLM 호출이 차단되어 있습니다.');
    process.exit(3);
  }
  const prompt = readPrompt(process.argv);
  if (!prompt) {
    console.error('프롬프트가 비어 있습니다.');
    process.exit(4);
  }

  const timeoutMs = parseInt(process.env.CONSULT_TIMEOUT_MS, 10) || 180_000;
  const outFile = path.join(os.tmpdir(), `consult-${provider}-${process.pid}.md`);
  const started = Date.now();

  const result = spawnSync(provider, buildArgs(provider, prompt, outFile), {
    env: stripClaudeEnv(process.env),
    encoding: 'utf-8',
    timeout: timeoutMs,
    maxBuffer: 16 * 1024 * 1024,
  });
  const durationMs = Date.now() - started;

  if (result.error && result.error.code === 'ENOENT') {
    console.error(`MISSING: ${provider} CLI가 설치되어 있지 않습니다.`);
    process.exit(2);
  }

  const timedOut = result.error && result.error.code === 'ETIMEDOUT';
  let response = '';
  if (provider === 'codex') {
    // codex는 -o 파일에 최종 응답을 쓴다. 타임아웃/실패 시 stdout 이벤트가 부분 결과
    if (fs.existsSync(outFile)) {
      response = fs.readFileSync(outFile, 'utf-8').trim();
      fs.unlinkSync(outFile);
    }
    if (!response) response = (result.stdout || '').trim();
  } else {
    response = (result.stdout || '').trim();
  }

  const exitCode = result.status === null ? 'killed' : result.status;
  const stderrTail = (result.stderr || '').trim().split('\n').slice(-15).join('\n');
  const artifact = writeArtifact({
    provider,
    prompt,
    response,
    stderrTail: exitCode === 0 ? '' : stderrTail,
    exitCode,
    durationMs,
    note: timedOut ? `타임아웃 (${timeoutMs}ms) — 부분 결과` : undefined,
  });

  console.log(`ARTIFACT: ${artifact}`);
  process.exit(exitCode === 0 ? 0 : 1);
}

module.exports = { stripClaudeEnv, buildArgs, slugify };
if (require.main === module) main();
