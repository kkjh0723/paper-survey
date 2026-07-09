#!/bin/zsh
# 매일 아침 launchd가 실행: paper-survey 추천 갱신 후 자동 push
# 로그: tools/recommend.log

set -u
REPO="/Users/jinhyung.kim/Claude/Projects/paper_survey"
CLAUDE="/opt/homebrew/bin/claude"
LOG="$REPO/tools/recommend.log"

# homebrew 등 PATH 확보 (launchd는 최소 환경으로 실행됨)
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

cd "$REPO" || exit 1

echo "===== $(date '+%Y-%m-%d %H:%M:%S') 추천 작업 시작 =====" >> "$LOG"

# 최신 상태 반영 (다른 기기/동기화 커밋 가져오기)
git pull --rebase --autostash >> "$LOG" 2>&1

# Claude 헤드리스로 추천 커맨드 실행.
# 권한 게이트를 전부 끄지 않고(--dangerously-skip-permissions 미사용),
# 이 작업에 실제로 필요한 도구만 허용목록으로 지정한다(그 외 도구 요청 시 실행은 실패).
"$CLAUDE" -p "/recommend-papers" \
  --allowedTools "Read" "Write" "Edit" "WebFetch" "WebSearch" \
                 "Bash(date:*)" "Bash(git add:*)" "Bash(git commit:*)" \
                 "Bash(git push:*)" "Bash(git pull:*)" "Bash(git status:*)" "Bash(git diff:*)" \
  >> "$LOG" 2>&1
RC=$?

echo "----- 종료코드 $RC · $(date '+%H:%M:%S') -----" >> "$LOG"
exit $RC
