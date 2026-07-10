#!/bin/zsh
# 10분마다 launchd 실행: 승인 큐에 논문이 있으면 자동으로 요약·리스트 추가·push.
# 큐가 비어 있으면 Claude를 띄우지 않고 조용히 종료(비용 0). 로그: tools/queue.log

set -u
REPO="/Users/jinhyung.kim/Claude/Projects/paper_survey"
CLAUDE="/opt/homebrew/bin/claude"
LOG="$REPO/tools/queue.log"

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
cd "$REPO" || exit 1

# 브라우저 승인(Worker→GitHub)이 반영된 최신 상태 가져오기
git pull --rebase --autostash >> "$LOG" 2>&1

QN=$(python3 -c "import json;print(len(json.load(open('data/state.json')).get('queue',[])))" 2>/dev/null || echo 0)
if [ "$QN" -eq 0 ]; then exit 0; fi   # 큐 비면 조용히 종료 (Claude 미실행)

echo "===== $(date '+%Y-%m-%d %H:%M:%S') 승인 큐 $QN편 자동 처리 =====" >> "$LOG"

# 권한은 이 작업에 필요한 도구만 스코프 허용(--dangerously-skip-permissions 미사용)
ALLOWED=(Read Write Edit WebFetch WebSearch \
  "Bash(date:*)" "Bash(curl:*)" "Bash(mkdir:*)" \
  "Bash(git add:*)" "Bash(git commit:*)" \
  "Bash(git push:*)" "Bash(git pull:*)" "Bash(git status:*)" "Bash(git diff:*)")

"$CLAUDE" -p "/add-paper 승인 큐 처리" --allowedTools "${ALLOWED[@]}" >> "$LOG" 2>&1
echo "----- 종료코드 $? · $(date '+%H:%M:%S') -----" >> "$LOG"
