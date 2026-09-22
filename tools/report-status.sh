#!/bin/zsh
# 자동화 상태를 data/automation-status.json 에 기록하고, 상태가 바뀔 때만 알림한다.
#   사용: report-status.sh ok
#         report-status.sh auth_expired ["상세 메시지"]
#
# 왜 필요한가: claude CLI 의 OAuth 세션은 4주쯤 지나면 만료되는데, 그러면 매일 추천이
# 조용히 실패만 반복한다(2026-08-07, 2026-09-09 두 번 다 5~12일 뒤에야 발견).
# 만료를 감지하면 (1) macOS 알림을 띄우고 (2) 사이트에 배너가 뜨도록 상태 파일을 커밋한다.
# 상태 파일 커밋은 claude 가 아니라 git 이 직접 하므로, 인증이 죽어 있어도 동작한다.

set -u
REPO="/Users/jinhyung.kim/Claude/Projects/paper_survey"
STATUS="$REPO/data/automation-status.json"
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
cd "$REPO" || exit 1

NEW="${1:-ok}"
DETAIL="${2:-}"
NOW=$(date '+%Y-%m-%d %H:%M:%S')
TODAY=$(date '+%Y-%m-%d')

# 이전 상태 읽기 (파일이 없거나 깨졌으면 ok 로 간주)
PREV=$(python3 -c "
import json
try: print(json.load(open('$STATUS')).get('state','ok'))
except Exception: print('ok')
" 2>/dev/null || echo ok)

# 만료가 이어지는 중이면 최초 감지 시각을 유지한다(며칠째 멈췄는지 보여주기 위함)
PREV_SINCE=$(python3 -c "
import json
try: print(json.load(open('$STATUS')).get('since','') or '')
except Exception: print('')
" 2>/dev/null || echo "")

if [ "$NEW" = "ok" ]; then
  SINCE=""
elif [ "$PREV" = "$NEW" ] && [ -n "$PREV_SINCE" ]; then
  SINCE="$PREV_SINCE"
else
  SINCE="$TODAY"
fi

# 상태(state·since)가 그대로면 파일을 아예 건드리지 않는다.
# checked 시각만 매번 갱신하면 하루 한 번씩 의미 없는 커밋이 쌓이고,
# 워킹트리가 더러워져 다른 스크립트의 git pull 이 매번 autostash 를 만든다.
if [ "$NEW" = "$PREV" ] && [ "$SINCE" = "$PREV_SINCE" ] && [ -f "$STATUS" ]; then
  exit 0
fi

python3 - "$STATUS" "$NEW" "$SINCE" "$NOW" "$DETAIL" <<'PY'
import json, sys
path, state, since, checked, detail = sys.argv[1:6]
json.dump({"state": state, "since": since, "checked": checked, "detail": detail},
          open(path, "w"), ensure_ascii=False, indent=2)
open(path, "a").write("\n")
PY

# 상태가 바뀐 순간에만 알림 (매일/10분마다 반복 알림 방지)
if [ "$NEW" != "$PREV" ]; then
  if [ "$NEW" = "auth_expired" ]; then
    osascript -e 'display notification "claude 로그인이 만료되어 매일 추천이 멈췄습니다. 터미널에서 claude 실행 후 /login 해주세요." with title "논문 서베이 자동화 중단" sound name "Basso"' 2>/dev/null
  else
    osascript -e 'display notification "자동화가 정상 복구되었습니다." with title "논문 서베이" sound name "Glass"' 2>/dev/null
  fi
fi

# 상태 파일이 실제로 바뀐 경우에만 커밋·push (claude 인증과 무관하게 git 으로 직접).
# git diff 는 추적되지 않은 신규 파일을 잡지 못하므로 status --porcelain 으로 판정한다.
if [ -n "$(git status --porcelain -- data/automation-status.json 2>/dev/null)" ]; then
  git add data/automation-status.json
  git commit -q -m "자동화 상태: $NEW" 2>/dev/null
  git pull --rebase --autostash -q 2>/dev/null
  git push -q 2>/dev/null
fi
