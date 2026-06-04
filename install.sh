#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✔${NC}  $*"; }
info() { echo -e "${BOLD}  →${NC}  $*"; }
warn() { echo -e "${YELLOW}  !${NC}  $*"; }
die()  { echo -e "${RED}  ✘  $*${NC}"; exit 1; }

echo
echo -e "${BOLD}SwiftDrop — Exercise 01 Installer${NC}"
echo -e "OWASP A01: Broken Access Control"
echo "────────────────────────────────────────"

# ── 1. Prerequisites ─────────────────────────────────────────────────────────
info "Checking prerequisites…"

command -v ruby >/dev/null 2>&1 || die "Ruby not found. Install Ruby 3.x then re-run this script."
RUBY_VERSION=$(ruby -e 'print RUBY_VERSION')
ok "Ruby $RUBY_VERSION"

command -v node >/dev/null 2>&1 || die "Node.js not found. Install Node.js 18+ then re-run this script."
ok "Node $(node --version)"

command -v npm >/dev/null 2>&1 || die "npm not found."
ok "npm $(npm --version)"

# ── 2. Gem home (user-level, no sudo required for gems) ──────────────────────
RUBY_API=$(ruby -e 'puts RUBY_VERSION.split(".")[0..1].join(".")+".0"')
export GEM_HOME="$HOME/.local/share/gem/ruby/$RUBY_API"
export PATH="$GEM_HOME/bin:$PATH"

# ── 3. System library for psych (YAML) ───────────────────────────────────────
if ! dpkg -s libyaml-dev >/dev/null 2>&1; then
  info "Installing libyaml-dev (required for psych gem)…"
  sudo apt-get install -y libyaml-dev >/dev/null 2>&1 \
    && ok "libyaml-dev installed" \
    || warn "Could not install libyaml-dev automatically — bundle install may fail"
else
  ok "libyaml-dev already installed"
fi

# ── 4. Rails gem ─────────────────────────────────────────────────────────────
if ! command -v rails >/dev/null 2>&1; then
  info "Installing Rails gem…"
  gem install rails --no-document 2>&1 | grep -E "^Successfully|error" || true
  ok "Rails $(rails --version) installed"
else
  ok "Rails $(rails --version) already installed"
fi

# ── 5. Backend Ruby gems ──────────────────────────────────────────────────────
info "Installing backend gems (bundle install)…"
cd "$SCRIPT_DIR/backend"
bundle install 2>&1 | grep -E "^Bundle complete|^An error|^Bundler" || true
bundle check >/dev/null 2>&1 && ok "Backend gems ready" || die "bundle install failed"

# Create required directories
mkdir -p storage tmp/pids log
ok "Backend directories created"

# ── 6. Frontend npm packages ──────────────────────────────────────────────────
info "Installing frontend packages (npm install)…"
cd "$SCRIPT_DIR/frontend"
npm install --silent
ok "Frontend packages ready"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo "────────────────────────────────────────"
echo -e "${GREEN}${BOLD}  Installation complete!${NC}"
echo
echo "  Start the exercise with:"
echo -e "  ${BOLD}  ./start.sh${NC}"
echo "────────────────────────────────────────"
echo
