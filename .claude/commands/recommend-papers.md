---
description: paper-survey 컬렉션과 좋아요를 바탕으로 arXiv에서 새 논문·관련 논문을 검색해 추천 JSON 생성 후 자동 push
argument-hint: (선택) 관심 주제 힌트
allowed-tools: Bash, Read, Write, Edit, WebFetch, WebSearch
---

paper-survey 사이트의 "추천 논문" 탭에 쓰일 추천 목록을 갱신한다. 사용자에게 되묻지 말고 끝까지 자동 수행한다.
추가 힌트가 있으면 반영: **$ARGUMENTS**

## 0. 입력 로드
- `date +%Y-%m-%d`로 오늘 날짜 확보.
- `index.html`에서 현재 보유 논문 목록 파악: 각 `<tr>`의 제목, `data-id`, `data-tags`.
- `data/state.json` 로드: `likes`(paper_id→점수), `dismissed`(제외된 추천 id), 그리고 이미 `queue`에 있는 id.
- 기존 `data/recommendations.json` 로드: **이건 누적 pool이다**(덮어쓰지 않음). 이미 들어있는 항목 id들(중복 회피용)과 각 항목의 `rec_date`를 확보.

## 1. 관심 프로필 구성
- 태그별 빈도를 세고, 해당 태그를 가진 논문이 `likes`에서 높은 점수일수록 가중치를 키운다(빈도 × (1+좋아요점수합)).
- 최근 등록(`data-added`)·최근 제출(`date`) 논문의 태그에 소폭 가산.
- 상위 관심 주제 키워드 5~8개를 뽑는다(예: VLA, Cross-Embodiment, World Model, Test-Time Adaptation 등).

## 2. arXiv 검색
arXiv API를 WebFetch로 조회한다(카테고리는 주로 cs.RO, cs.LG, cs.AI):
- **새로 공개된 논문 (그룹 key=new)**: 관심 키워드로 **최근 제출(약 7일 이내)** 신규 논문 검색.
  예) `http://export.arxiv.org/api/query?search_query=cat:cs.RO+AND+(abs:%22vision-language-action%22)&sortBy=submittedDate&sortOrder=descending&max_results=30`
  여러 키워드로 여러 번 조회해 후보를 모은다. WebSearch로 보완 가능.
- **관련 논문 (그룹 key=related)**: 컬렉션과 강하게 관련되지만 아직 안 본(=보유/이전추천/dismissed에 없는) 핵심·기반 논문. 연도 무관, 인용 많은 대표작 우선.

## 3. 선별 규칙
- 각 그룹 **정확히 3편**(총 6편). 후보가 부족하면 가능한 만큼.
- **제외 대상**: 이미 `index.html`에 있는 논문(제목/arXiv id 매칭), `dismissed`에 있는 id, `queue`에 있는 id, **그리고 이미 pool(recommendations.json)에 있는 id**(중복 방지).
- 각 논문의 arXiv id를 그대로 `id`로 쓴다(예: `2504.16054`). 초록을 읽어 한국어 한줄요약과 **추천 이유**(어느 보유 논문과 어떻게 연결되는지 구체적으로)를 작성한다.

## 4. 추천 목록 병합 (누적 — 덮어쓰지 않는다)
`data/recommendations.json`을 **누적**한다. 매일 새 추천을 기존 pool에 얹고, 처리된 것만 정리한다.
1. **기존 항목 유지·정리:** 기존 pool의 각 항목 중 아래는 제거한다 — 이미 `index.html`에 있는 id(추가됨), `state.json.dismissed`의 id(제외됨), `queue`의 id(승인 대기중). 나머지(아직 안 본 추천)는 **그대로 유지**한다.
2. **새 항목 추가:** 이번에 선별한 논문을 각 그룹에 추가하되, pool에 이미 있는 id는 건너뛴다. 각 새 항목에 `"rec_date":"<오늘>"`(추천된 날)을 넣는다. 기존 항목에 `rec_date`가 없으면 파일의 `generated` 값으로 채운다.
3. **상한:** new+related 합산 **최대 40편**. 넘치면 `rec_date`가 가장 오래된 항목부터 제거(가장 오래 노출돼 볼 시간이 많았던 것).
4. **정렬:** 각 그룹 내 항목을 `rec_date` 내림차순(최신 추천이 위)으로 정렬.
5. `generated`는 오늘 날짜로 갱신(마지막 실행일).

스키마(항목에 `rec_date` 추가):
```json
{ "generated": "<오늘>",
  "groups": [
    { "key":"new", "label":"새로 공개된 논문", "items":[
      {"id":"","title":"","authors":"","summary_ko":"","tags":[],"arxiv_url":"","extra_url":"","date":"","reason":"","rec_date":"<오늘>"} ] },
    { "key":"related", "label":"관련 논문", "items":[ ... ] } ] }
```
- `arxiv_url`은 `https://arxiv.org/abs/<id>`. `extra_url`은 프로젝트/GitHub 있으면, 없으면 빈 문자열.
- `date`는 논문 제출일(YYYY-MM-DD), `rec_date`는 추천된 날. `tags`는 3~5개.

## 5. 커밋·푸시
- JSON 문법 검증(파싱 가능 여부) 후:
  ```
  git add data/recommendations.json
  git commit -m "추천 누적 <오늘>: 새 N편 추가 (pool M편)"
  git push
  ```
- 실패 시 push 하지 말고 원인을 로그로 남긴다.
- 완료 후 갱신 편수를 한국어로 짧게 보고한다.
