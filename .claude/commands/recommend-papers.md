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
- 직전 `data/recommendations.json` 로드: 지난 추천 id들(중복 회피용).

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
- **제외 대상**: 이미 `index.html`에 있는 논문(제목/arXiv id 매칭), `dismissed`에 있는 id, `queue`에 있는 id, 직전 추천과 중복되는 것.
- 각 논문의 arXiv id를 그대로 `id`로 쓴다(예: `2504.16054`). 초록을 읽어 한국어 한줄요약과 **추천 이유**(어느 보유 논문과 어떻게 연결되는지 구체적으로)를 작성한다.

## 4. JSON 작성
`data/recommendations.json`을 아래 스키마로 **덮어쓴다**(주석 필드 없이):
```json
{ "generated": "<오늘>",
  "groups": [
    { "key":"new", "label":"새로 공개된 논문", "items":[
      {"id":"","title":"","authors":"","summary_ko":"","tags":[],"arxiv_url":"","extra_url":"","date":"","reason":""} ] },
    { "key":"related", "label":"관련 논문", "items":[ ... ] } ] }
```
- `arxiv_url`은 `https://arxiv.org/abs/<id>`. `extra_url`은 프로젝트/GitHub 있으면, 없으면 빈 문자열.
- `date`는 논문 제출일(YYYY-MM-DD). `tags`는 3~5개.

## 5. 커밋·푸시
- JSON 문법 검증(파싱 가능 여부) 후:
  ```
  git add data/recommendations.json
  git commit -m "추천 갱신 <오늘>: 새 논문 N편 + 관련 N편"
  git push
  ```
- 실패 시 push 하지 말고 원인을 로그로 남긴다.
- 완료 후 갱신 편수를 한국어로 짧게 보고한다.
