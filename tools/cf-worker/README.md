# 좋아요/큐 자동 동기화 — Cloudflare Worker 배포

브라우저(폰 포함 어느 기기든) → Worker → GitHub(`data/state.json`) 로 좋아요·승인큐·제외를 **붙여넣기 없이 자동** 커밋한다.
GitHub 토큰은 Worker 시크릿에만 두고 클라이언트에는 절대 노출하지 않는다.

## 1. GitHub 토큰 만들기 (fine-grained PAT)
1. https://github.com/settings/personal-access-tokens/new
2. **Repository access** → *Only select repositories* → `kkjh0723/paper-survey`
3. **Permissions** → *Repository permissions* → **Contents: Read and write** (그 외는 전부 No access)
4. 만료일 설정 후 생성 → 토큰 문자열 복사 (한 번만 보임)

## 2. Cloudflare Worker 배포 (대시보드, CLI 불필요)
1. https://dash.cloudflare.com → 무료 가입/로그인 → **Workers & Pages** → **Create** → **Create Worker**
2. 이름 예: `paper-sync` → **Deploy** (기본 코드로 일단 생성)
3. **Edit code** → 좌측 편집기 내용을 지우고 이 폴더의 `worker.js` 전체를 붙여넣기 → **Deploy**
4. **Settings → Variables and Secrets** 에서 시크릿 추가:
   - `GITHUB_TOKEN` = 1단계에서 만든 토큰 (**Encrypt** 체크)
   - (선택) `SYNC_KEY` = 아무 임의 문자열 (index.html의 `SYNC_KEY`와 동일하게)
5. 배포되면 URL 확인: `https://paper-sync.<계정서브도메인>.workers.dev`

## 3. 사이트에 연결
`index.html` 상단 스크립트의 설정을 채운다:
```js
var SYNC_ENDPOINT = 'https://paper-sync.<계정>.workers.dev';
var SYNC_KEY = '';   // 2-4에서 SYNC_KEY를 넣었다면 같은 값
```
저장 후 커밋·push 하면 끝. 이후 ♥/추가/제외를 누르면 자동으로 저장소에 반영되고,
다른 기기는 새로고침 시 Worker에서 최신 상태를 읽어온다.

## 동작/보안 메모
- Worker는 `data/state.json` **하나만** 읽고 쓴다. 최악의 경우 피해는 그 파일뿐이며 git으로 즉시 되돌릴 수 있다.
- 공개 사이트라 `SYNC_KEY`는 클라이언트에 실려 완전한 비밀은 아니다(캐주얼한 남용 차단용). 필요하면
  `worker.js`의 `ALLOW_ORIGIN`을 `'https://kkjh0723.github.io'`로 제한하고, 토큰 권한을 Contents로만 좁혀 위험을 최소화했다.
- `SYNC_ENDPOINT`가 비어 있으면 사이트는 기존 **원클릭 복사→Claude** 방식으로 자동 폴백한다(Worker 장애 시에도 동일).
- 승인 큐의 **요약·목록추가**는 여전히 Claude 몫이다(Worker는 상태만 동기화). "📋 Claude로 처리"는 그대로 사용.
