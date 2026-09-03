#!/usr/bin/env bash
# 07: the two logins only you can do (a browser opens; you click). Claude Code with your
# Max subscription, and GitHub if you want the agent to push the vault backup.
# Everything after this stage runs without you. Skip for now with ACCOUNTS_LATER=1.
. "$(dirname "$0")/lib.sh"

claude_ok() { claude auth status >/dev/null 2>&1 || timeout 90 claude -p "reply with exactly: ok" --max-turns 1 2>/dev/null | grep -qi '^ok'; }

run() {
  if [ "$ACCOUNTS_LATER" = 1 ]; then warn "ACCOUNTS_LATER=1: skipping the logins. Later: setup.sh --only 07"; return 0; fi
  log "Claude Code login (your Max plan)"
  if claude_ok; then ok "already logged in"; else
    warn "A browser window opens. Log in with the account that has the subscription, allow Claude Code, come back here."
    if have_display; then
      claude auth login || warn "login command exited; checking"
    else
      warn "no display: open the printed URL on another device"; claude auth login || true
    fi
    local i=0
    until claude_ok || [ $i -ge 3 ]; do i=$((i+1)); warn "not logged in yet; trying once more"; claude auth login || true; done
    claude_ok && ok "logged in" || die "Claude Code is not logged in. Run: claude auth login   then: setup.sh"
  fi
  # the account's default: auto mode with the classifier; the deny list lands in stage 10
  if [ "$GITHUB_CLI" = 1 ] && has gh; then
    log "GitHub login (optional but useful: private vault backups, the agent's repos)"
    if gh auth status >/dev/null 2>&1; then ok "already logged in as $(gh api user -q .login 2>/dev/null)"; else
      warn "A browser device-code login follows (copy the code, press Enter, paste it in the browser)."
      # --insecure-storage: the token goes to ~/.config/gh/hosts.yml (mode 600) instead of the GNOME
      # keyring, which stays locked after the automatic login and would block every unattended git push
      gh auth login --hostname github.com --git-protocol https --web --insecure-storage || warn "GitHub login skipped; later: gh auth login --insecure-storage"
      gh auth status >/dev/null 2>&1 && gh auth setup-git >/dev/null 2>&1 && ok "git uses gh for GitHub credentials" || true
    fi
    if [ -z "$(git config --global user.email || true)" ] && gh auth status >/dev/null 2>&1; then
      local em; em="$(gh api user -q '.email // empty' 2>/dev/null || true)"
      [ -n "$em" ] && git config --global user.email "$em" && ok "git email from GitHub: $em" || true
    fi
  fi
  return 0
}

check() {
  if [ "$ACCOUNTS_LATER" = 1 ]; then warn "skipped by ACCOUNTS_LATER=1"; return 0; fi
  chk "claude logged in" claude_ok
  [ "$GITHUB_CLI" = 1 ] && chk_warn "gh logged in" gh auth status
  checks_done
}
stage_main "$@"
