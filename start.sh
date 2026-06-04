#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✔${NC}  $*"; }
info() { echo -e "  ${CYAN}→${NC}  $*"; }
die()  { echo -e "${RED}  ✘  $*${NC}"; exit 1; }

BACKEND_PID=""
FRONTEND_PID=""
TAIL_PID=""
BACKEND_LOG="$SCRIPT_DIR/backend/log/development.log"

# ── Cleanup on exit ───────────────────────────────────────────────────────────
cleanup() {
  echo
  echo -e "${YELLOW}  Stopping servers…${NC}"
  [ -n "$TAIL_PID" ]     && kill "$TAIL_PID"     2>/dev/null || true
  [ -n "$FRONTEND_PID" ] && kill "$FRONTEND_PID" 2>/dev/null || true
  [ -n "$BACKEND_PID" ]  && kill "$BACKEND_PID"  2>/dev/null || true
  rm -f "$SCRIPT_DIR/backend/tmp/pids/server.pid"
  echo -e "${GREEN}  Stopped. Goodbye.${NC}"
  echo
  exit 0
}
trap cleanup INT TERM

# ── Gem paths (must match install.sh) ────────────────────────────────────────
RUBY_API=$(ruby -e 'puts RUBY_VERSION.split(".")[0..1].join(".")+".0"')
export GEM_HOME="$HOME/.local/share/gem/ruby/$RUBY_API"
export PATH="$GEM_HOME/bin:$PATH"

# ── Preflight checks ─────────────────────────────────────────────────────────
command -v bundle >/dev/null 2>&1 || die "Gems not installed. Run ./install.sh first."
[ -d "$SCRIPT_DIR/frontend/node_modules" ]  || die "Frontend packages missing. Run ./install.sh first."

# Kill anything already on port 3000 or 5173
for PORT in 3000 5173; do
  PID=$(lsof -ti tcp:$PORT 2>/dev/null || true)
  if [ -n "$PID" ]; then
    echo -e "${YELLOW}  ! Port $PORT in use (PID $PID) — killing…${NC}"
    kill "$PID" 2>/dev/null || true
    sleep 1
  fi
done

# Remove stale Rails PID if present
rm -f "$SCRIPT_DIR/backend/tmp/pids/server.pid"

echo
echo -e "${BOLD}SwiftDrop — Exercise 01${NC}"
echo -e "OWASP A01: Broken Access Control"
echo "────────────────────────────────────────"

# ── Start backend ─────────────────────────────────────────────────────────────
info "Starting Rails backend…"
cd "$SCRIPT_DIR/backend"
bundle exec rails server -p 3000 \
  --no-pid \
  2>>"$SCRIPT_DIR/backend/log/server_stderr.log" &
BACKEND_PID=$!

# Wait for Rails to be ready (up to 20 s)
TRIES=0
until curl -s http://localhost:3000/up >/dev/null 2>&1; do
  sleep 1
  TRIES=$((TRIES + 1))
  [ $TRIES -ge 20 ] && die "Rails server did not start in time. Check backend/log/ for details."
done
ok "Backend running  →  http://localhost:3000"

# ── Start frontend ────────────────────────────────────────────────────────────
info "Starting Vue frontend…"
cd "$SCRIPT_DIR/frontend"
npm run dev -- --port 5173 --host 0.0.0.0 2>&1 \
  | grep --line-buffered -v "^$" &
FRONTEND_PID=$!

# Wait for Vite to be ready (up to 15 s)
TRIES=0
until curl -s http://localhost:5173 >/dev/null 2>&1; do
  sleep 1
  TRIES=$((TRIES + 1))
  [ $TRIES -ge 15 ] && die "Vite dev server did not start in time."
done
ok "Frontend running  →  http://localhost:5173"

# ── Ready ─────────────────────────────────────────────────────────────────────
echo "────────────────────────────────────────"
echo -e "${GREEN}${BOLD}  Exercise ready!${NC}"
echo
echo -e "  Open in browser: ${BOLD}http://localhost:5173${NC}"
echo
echo -e "  ${GREEN}${BOLD}Happy Hacking!${NC}"
echo
echo -e "  Backend log: ${CYAN}backend/log/development.log${NC}"
echo -e "  ${YELLOW}Press Ctrl+C to stop all servers.${NC}"
echo "────────────────────────────────────────"
echo

# ── Tail backend log so the terminal stays useful ─────────────────────────────
touch "$BACKEND_LOG"
tail -f "$BACKEND_LOG" &
TAIL_PID=$!

wait "$BACKEND_PID" "$FRONTEND_PID" 2>/dev/null || true
kill "$TAIL_PID" 2>/dev/null || true
