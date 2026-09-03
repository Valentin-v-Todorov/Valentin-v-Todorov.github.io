#!/usr/bin/env bash
# voice/install.sh [agent-home] [-q]: put the wake-phrase + music-ducking hook (flint_voice.py)
# into backtalk's virtualenv. Idempotent and quick; launch.sh runs it before every start so a
# rebuilt virtualenv gets the hook back. Nothing in backtalk's own tree is touched.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
QUIET=0; HOME_DIR="$HOME/my-agent"
for a in "$@"; do case "$a" in -q) QUIET=1 ;; *) HOME_DIR="$a" ;; esac; done
PY="$HOME_DIR/backtalk/.venv/bin/python"
if [ ! -x "$PY" ]; then
  [ "$QUIET" = 1 ] || echo "no backtalk virtualenv in $HOME_DIR/backtalk (run backtalk/install.sh first)" >&2
  exit 1
fi
SP="$("$PY" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
if [ -f "$SP/flint_voice.pth" ] && cmp -s "$HERE/flint_voice.py" "$SP/flint_voice.py"; then
  [ "$QUIET" = 1 ] || echo "flint_voice already installed in $SP"
  exit 0
fi
cp "$HERE/flint_voice.py" "$SP/flint_voice.py"
printf 'import flint_voice\n' > "$SP/flint_voice.pth"
"$PY" -c 'import flint_voice, sys; sys.exit(0 if flint_voice.installed() else 1)' || { echo "flint_voice did not load from $SP" >&2; exit 1; }
[ "$QUIET" = 1 ] || echo "flint_voice $("$PY" -c 'import flint_voice; print(flint_voice.__version__)') installed in $SP (wake phrase + music ducking; takes effect at the next start of the voice line)"
