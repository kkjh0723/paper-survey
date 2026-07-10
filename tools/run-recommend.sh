#!/bin/zsh
# 매일 아침 launchd가 실행:
#   1) 승인 큐 처리(승인된 논문 요약·리스트 추가·큐 비움)
#   2) 추천 갱신
# 모두 자동 push. 로그: tools/recommend.log

set -u
REPO="/Users/jinhyung.kim/Claude/Projects/paper_survey"
CLAUDE="/opt/homebrew/bin/claude"
LOG="$REPO/tools/recommend.log"

# homebrew 등 PATH 확보 (launchd는 최소 환경으로 실행됨)
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

cd "$REPO" || exit 1

echo "===== $(date '+%Y-%m-%d %H:%M:%S') 작업 시작 =====" >> "$LOG"

# 최신 상태 반영 (다른 기기/동기화 커밋 가져오기)
git pull --rebase --autostash >> "$LOG" 2>&1

# 권한 게이트를 전부 끄지 않고(--dangerously-skip-permissions 미사용),
# 이 작업에 실제로 필요한 도구만 허용목록으로 지정한다(그 외 도구 요청 시 실행은 실패).
ALLOWED=(Read Write Edit WebFetch WebSearch \
  "Bash(date:*)" "Bash(curl:*)" "Bash(mkdir:*)" \
  "Bash(git add:*)" "Bash(git commit:*)" \
  "Bash(git push:*)" "Bash(git pull:*)" "Bash(git status:*)" "Bash(git diff:*)")

# 1) 승인 큐 처리 — 큐에 승인된 논문이 있으면 요약 페이지 생성 + 리스트 추가 + 큐 비움.
QN=$(python3 -c "import json;print(len(json.load(open('data/state.json')).get('queue',[])))" 2>/dev/null || echo 0)
if [ "$QN" -gt 0 ]; then
  echo "----- 승인 큐 $QN편 처리 · $(date '+%H:%M:%S') -----" >> "$LOG"
  "$CLAUDE" -p "/add-paper 승인 큐 처리" --allowedTools "${ALLOWED[@]}" >> "$LOG" 2>&1
else
  echo "----- 승인 큐 비어있음, 건너뜀 -----" >> "$LOG"
fi

# 2) 추천 갱신 (위에서 추가된 논문은 자동 제외됨)
echo "----- 추천 갱신 · $(date '+%H:%M:%S') -----" >> "$LOG"
"$CLAUDE" -p "/recommend-papers" --allowedTools "${ALLOWED[@]}" >> "$LOG" 2>&1
RC=$?

echo "----- 종료코드 $RC · $(date '+%H:%M:%S') -----" >> "$LOG"
exit $RC
