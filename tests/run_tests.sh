#!/bin/sh
# Peon - alle Tests ausfuehren (Git Bash unter Windows, Linux, GitHub Actions).
# Aufruf: sh tests/run_tests.sh   (optional: einzelne Testdateien als Argumente)
T="$(cd "$(dirname "$0")" && pwd)"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) LUA="$T/../tools/lua5.1.exe" ;;
  *) LUA="$T/../tools/lua5.1-linux"
     [ -x "$LUA" ] || chmod +x "$LUA" 2>/dev/null
     [ -x "$LUA" ] || { cp "$LUA" "$HOME/lua51" && chmod +x "$HOME/lua51" && LUA="$HOME/lua51"; } ;;
esac
# Addons aus dem Repo (addons/), PEON_ADDONS setzt einen anderen Ordner
A="${PEON_ADDONS:-$T/../addons}"
cd "$A" || exit 1
# Einstellungen fuer test_fish: feste Kopie aus der Beta (tests/fixtures/wtf), unabhaengig vom Spiel
export PEON_WTF="${PEON_WTF:-$T/fixtures/wtf}"
FILES="$*"; [ -n "$FILES" ] || FILES="$(ls "$T"/test*.lua)"
FAIL=0
for f in $FILES; do
  case "$f" in /*) ;; *) f="$T/$f";; esac
  printf '===== %s: ' "$(basename "$f")"
  OUT="$("$LUA" "$f" 2>&1)"
  if echo "$OUT" | tail -1 | grep -q "ALLE TESTS OK"; then echo OK; else echo FEHLER; echo "$OUT" | tail -15; FAIL=1; fi
done
exit $FAIL
