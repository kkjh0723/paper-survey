---
description: 논문 링크를 받아 요약 페이지를 만들고 index.html에 추가한 뒤 git push까지 자동 수행
argument-hint: <논문 링크 (arXiv abs/pdf URL 등)>
allowed-tools: Bash, Read, Write, Edit, WebFetch, WebSearch
---

논문 링크: **$ARGUMENTS**

위 링크의 논문을 요약해 이 사이트(paper-survey)에 추가하고 자동으로 커밋·푸시한다.
반드시 아래 순서를 따른다. 사용자에게 되묻지 말고 스스로 판단해 끝까지 완료한다.

## 0. 준비
- 오늘 날짜 확보: `date +%Y-%m-%d` (data-added 및 커밋용).
- 링크가 arXiv면 abstract 페이지(`https://arxiv.org/abs/<id>`)를 WebFetch 한다.
  필요하면 `https://arxiv.org/pdf/<id>` 또는 HTML 버전(`https://arxiv.org/html/<id>`)도 가져와
  Method·실험 수치 등 본문 세부내용을 충분히 확보한다. arXiv가 아니면 링크 자체를 fetch한다.
- 논문 GitHub/프로젝트 페이지 링크가 있으면 함께 수집한다.

## 1. 메타데이터 결정
- **id**: arXiv면 arXiv 번호(예: `2606.21406`). 아니면 짧은 대표 약칭.
- **short**: 논문 대표 약칭(예: `VLA-JEPA`, `RECAP`). 파일명·제목용.
- **파일명**: `summaries/<id>_<short>.html` (arXiv 아니면 `summaries/<short>.html`).
- **제목 / 저자·소속 / 제출일 / 태그 3~6개**(쉼표구분, 예: `VLA,World Model,JEPA`).

## 2. 요약 HTML 생성
- **기존 파일을 템플릿으로 복사**한다: `summaries/2602.10098_VLA-JEPA.html` 를 열어
  전체 구조(head의 `<style>` 블록, hero 헤더, 섹션 구성)를 그대로 유지하고 내용만 교체한다.
  스타일(CSS)은 절대 새로 짜지 말고 템플릿 것을 그대로 쓴다.
- 본문은 **한국어**로 작성하고 섹션 구성을 지킨다:
  - `<title><short> — 요약</title>`
  - hero: `.tag`(대표 분야 한 단어), `<h1>`(논문 제목), `.authors`(저자·소속),
    `.chips`(arXiv·GitHub 등 링크), `.meta`(제출일·백본·자원 등 한 줄)
  - 섹션: `한 줄 요약(TL;DR)` → `1 배경·문제의식` → `2 핵심 Contribution`(`.contrib` 리스트)
    → `3 Method` → `4 실험 결과`(수치 표, 최고값은 `class="win"`) → `5 Ablation`
    → `6 핵심 Figure/Table` → `7 관련 링크` → `Q 추가 질문 & 답변`
  - 뒤로가기 링크 `<a class="back" href="../index.html">← 논문 리스트로 돌아가기</a>` 유지.
- 수치·주장은 반드시 논문 근거에 기반한다. 모르면 지어내지 말고 해당 항목을 비운다.

## 3. index.html에 행 추가
- `<tbody id="rows">` **맨 위**(첫 `<tr>` 바로 앞)에 새 행을 삽입한다. 최신 논문이 위로 온다.
- 번호(`.no`)는 현재 맨 위 행 번호 + 1.
- 행 형식은 기존 행과 동일하게:
  ```html
  <tr data-id="<id>" data-added="<오늘>" data-tags="<태그들>">
    <td class="no"><번호></td>
    <td class="read-cell"></td>
    <td>
      <div class="ttl"><a href="summaries/<파일명>"><논문 제목></a></div>
      <div class="sub"><저자 외 · 소속 · arXiv:<id></div>
      <div class="sub"><한 줄 핵심 요약(수치 포함)></div>
      <div class="tags"><span class="tag">태그</span> ...</div>
    </td>
    <td class="date"><제출일 YYYY-MM-DD></td>
    <td class="links">
      <a href="<arxiv url>" target="_blank">arXiv</a>
      <a href="<github url>" target="_blank">GitHub</a>
    </td>
  </tr>
  ```
- `data-tags`의 태그 개수/이름은 요약 HTML의 chips와 일치시킨다.

## 4. 검증 후 커밋·푸시
- 새 요약 파일이 브라우저에서 깨지지 않는지 HTML 구조를 점검한다(닫는 태그·따옴표).
- 다음을 실행한다(요약 실패 시 push 하지 말고 원인 보고):
  ```
  git add index.html summaries/<파일명>
  git commit -m "<short> 논문 추가: <한 줄 설명>"
  git push
  ```
- 완료 후 사용자에게: 추가한 제목, 파일 경로, 커밋 해시, GitHub Pages에서 확인 가능하다는 안내를 한국어로 짧게 보고한다.
