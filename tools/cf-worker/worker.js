// Cloudflare Worker — paper-survey 좋아요/승인큐/제외 상태 동기화 프록시
// - data/state.json 만 읽고/쓴다 (그 외 경로/작업 불가 → 피해 반경 최소).
// - GitHub 토큰은 Worker 시크릿(env.GITHUB_TOKEN)에만 존재하고 클라이언트에 노출되지 않는다.
// - POST: 들어온 상태를 저장소의 현재 상태와 병합(좋아요 큰 점수 우선, queue·dismissed 합집합) 후 커밋.
// - GET : 현재 저장소 상태를 반환(다른 기기에서 최신본 즉시 읽기용, Pages 캐시 우회).
//
// 배포 후 index.html 의 SYNC_ENDPOINT 에 이 Worker의 URL을 넣으면 자동 동기화가 켜진다.

const OWNER  = 'kkjh0723';
const REPO   = 'paper-survey';
const PATH   = 'data/state.json';
const BRANCH = 'main';
// 필요하면 특정 오리진으로 제한: 예) 'https://kkjh0723.github.io'
const ALLOW_ORIGIN = '*';

function cors(h){
  h.set('Access-Control-Allow-Origin', ALLOW_ORIGIN);
  h.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  h.set('Access-Control-Allow-Headers', 'Content-Type,x-sync-key');
  return h;
}
function json(obj, status){
  const h = new Headers({'Content-Type':'application/json'});
  cors(h);
  return new Response(JSON.stringify(obj), {status: status||200, headers: h});
}

function normState(s){
  s = s || {};
  return {
    likes: (s.likes && typeof s.likes==='object') ? s.likes : {},
    queue: Array.isArray(s.queue) ? s.queue : [],
    dismissed: Array.isArray(s.dismissed) ? s.dismissed : []
  };
}
function mergeStates(base, over){
  base = normState(base); over = normState(over);
  const out = {likes:{}, queue:[], dismissed:[]};
  // 좋아요/점수: 클라이언트(over)가 소스 오브 트루스 → 취소·하향이 반영됨(LWW).
  for(const k in over.likes){ if(over.likes[k]) out.likes[k] = over.likes[k]; }
  // 큐·제외: append-only 성격이라 합집합(동시 사용 시 유실 방지).
  const seen = {};
  base.queue.concat(over.queue).forEach(it => { if(it && it.id && !seen[it.id]){ seen[it.id]=1; out.queue.push(it); } });
  const ds = {};
  base.dismissed.concat(over.dismissed).forEach(x => { if(x) ds[x]=1; });
  out.dismissed = Object.keys(ds);
  return out;
}

const GH_HEADERS = (env) => ({
  'Authorization': `Bearer ${env.GITHUB_TOKEN}`,
  'Accept': 'application/vnd.github+json',
  'User-Agent': 'paper-survey-sync'
});

async function ghGet(env){
  const r = await fetch(`https://api.github.com/repos/${OWNER}/${REPO}/contents/${PATH}?ref=${BRANCH}`, {
    headers: GH_HEADERS(env)
  });
  if(r.status === 404) return { state: {likes:{},queue:[],dismissed:[]}, sha: null };
  if(!r.ok) throw new Error('github GET ' + r.status);
  const d = await r.json();
  const raw = decodeURIComponent(escape(atob(String(d.content||'').replace(/\n/g,''))));
  let content = {};
  try{ content = JSON.parse(raw); }catch(e){ content = {}; }
  return { state: content, sha: d.sha };
}
async function ghPut(env, obj, sha){
  const body = JSON.stringify(obj, null, 2) + '\n';
  const content = btoa(unescape(encodeURIComponent(body)));
  return fetch(`https://api.github.com/repos/${OWNER}/${REPO}/contents/${PATH}`, {
    method: 'PUT',
    headers: { ...GH_HEADERS(env), 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message: 'state: 좋아요/큐 동기화 (worker)',
      content, sha: sha || undefined, branch: BRANCH
    })
  });
}

export default {
  async fetch(req, env){
    if(req.method === 'OPTIONS') return new Response(null, {headers: cors(new Headers())});
    // 선택적 공유키 (index.html의 SYNC_KEY와 동일해야 함). 미설정 시 검사 생략.
    if(env.SYNC_KEY){
      if(req.headers.get('x-sync-key') !== env.SYNC_KEY) return json({error:'unauthorized'}, 401);
    }
    try{
      if(req.method === 'GET'){
        const cur = await ghGet(env);
        return json(normState(cur.state));
      }
      if(req.method === 'POST'){
        const incoming = await req.json();
        for(let i=0; i<2; i++){                 // sha 충돌(409) 시 1회 재시도
          const cur = await ghGet(env);
          const merged = { ...mergeStates(cur.state, incoming), updated: new Date().toISOString().slice(0,10) };
          const r = await ghPut(env, merged, cur.sha);
          if(r.ok) return json(merged);
          if(r.status !== 409) return json({error:'github PUT '+r.status, detail: await r.text()}, 502);
        }
        return json({error:'conflict'}, 409);
      }
      return json({error:'method not allowed'}, 405);
    }catch(e){
      return json({error: String(e && e.message || e)}, 500);
    }
  }
};
