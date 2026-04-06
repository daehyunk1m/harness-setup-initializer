import * as fs from 'fs';

const DOCS_TO_CHECK: string[] = {{DOC_CHECK_TARGETS}};

const STALE_DAYS = {{DOC_FRESHNESS_DAYS}};
const now = Date.now();

console.log('📄 문서 최신성 검사\n');

let staleCount = 0;
let totalCount = 0;

for (const doc of DOCS_TO_CHECK) {
  totalCount++;

  if (!fs.existsSync(doc)) {
    console.log(`❌ ${doc} — 파일 없음`);
    staleCount++;
    continue;
  }

  const stat = fs.statSync(doc);
  const daysSinceModified = Math.floor(
    (now - stat.mtimeMs) / (1000 * 60 * 60 * 24)
  );

  if (daysSinceModified > STALE_DAYS) {
    console.log(`⚠️ ${doc} — ${daysSinceModified}일 전 수정`);
    staleCount++;
  } else {
    console.log(`✅ ${doc} — ${daysSinceModified}일 전 수정`);
  }
}

console.log(`\n결과: ${totalCount}개 문서 중 ${staleCount}개 오래됨`);

// 항상 exit 0 — 경고만 출력하고 validate를 차단하지 않는다
process.exit(0);
