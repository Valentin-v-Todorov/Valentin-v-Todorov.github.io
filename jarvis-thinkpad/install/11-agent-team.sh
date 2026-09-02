#!/usr/bin/env bash
# 11: the agent team. The roster becomes subagent files; the schedules become systemd
# user timers that run the team on their own, as the agent, with the vault.
. "$(dirname "$0")/lib.sh"

run() {
  [ -f "$AGENT_HOME/team.yaml" ] || { cp "$GUIDE_DIR/command-face/team.example.yaml" "$AGENT_HOME/team.yaml"; ok "team.yaml seeded from the example (edit it with $AGENT_NAME any time)"; }
  cp "$GUIDE_DIR/install/team-timers.py" "$AGENT_HOME/bin/team-timers.py" && chmod +x "$AGENT_HOME/bin/team-timers.py"

  log "roster -> team.json and subagent files"
  ( cd "$AGENT_HOME" && uv run --quiet "$AGENT_HOME/bin/team-sync.py" --home "$AGENT_HOME" --agents ) 2>&1 | tail -3
  local n; n="$(find "$AGENT_HOME/.claude/agents" -name '*.md' 2>/dev/null | wc -l)"
  ok "$n agent files in $AGENT_HOME/.claude/agents/"

  if [ "$AGENT_TIMERS" = 1 ]; then
    log "schedules -> systemd user timers"
    mkdir -p "$AGENT_HOME/logs"
    ( cd "$AGENT_HOME" && uv run --quiet "$AGENT_HOME/bin/team-timers.py" --home "$AGENT_HOME" --apply ) 2>&1 | tail -8
    ok "timers: systemctl --user list-timers 'flint-*'"
  fi
}

check() {
  chk "team.yaml valid" bash -c "cd '$AGENT_HOME' && uv run --quiet '$AGENT_HOME/bin/team-sync.py' --home '$AGENT_HOME' --check"
  chk "agent files exist" bash -c "test \"\$(find '$AGENT_HOME/.claude/agents' -name '*.md' | wc -l)\" -ge 5"
  [ "$AGENT_TIMERS" = 1 ] && chk "at least one flint-* timer active" bash -c "systemctl --user list-timers --all --no-legend 'flint-*' | grep -q flint-"
  checks_done
}
stage_main "$@"
