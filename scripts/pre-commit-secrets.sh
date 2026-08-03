#!/usr/bin/env bash
# Pre-commit hook: block commits that contain secrets / credentials.
#
# Scans the *staged* content of each file (git show :path), so a secret must be
# newly staged to be caught. Install with:
#   cp scripts/pre-commit-secrets.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
#
# Bypass on a verified false positive with:  git commit --no-verify
set -euo pipefail

RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

# High-confidence secret patterns (API keys, private keys, tokens, JWTs).
HIGH_CONFIDENCE='AIza[0-9A-Za-z_-]{35}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|(sk|pk)_(live|test)_[0-9A-Za-z]{16,}|ghp_[0-9A-Za-z]{20,}|gho_[0-9A-Za-z]{20,}|ghu_[0-9A-Za-z]{20,}|xox[baprs]-[0-9A-Za-z-]{10,}|-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|sk-[0-9A-Za-z]{20,}'

# Assignment-style patterns (sensitive field names with a quoted value).
ASSIGNMENT='(storePassword|keyPassword|client[_-]secret|secret[_-]key|access[_-]key[_-]?id|api[_-]?key|password|passwd)\s*[=:]\s*["'"'"'][^"'"'"']{6,}'

# Lines that are placeholders / benign (filtered out).
BENIGN='example|change-me|your-|placeholder|xxx|<[^>]+>|String.fromEnvironment|System\.getenv|os\.environ|getenv\(|config\(|fromEnvironment\(|TODO|yourfirebase|your-'

skip_file() {
  case "$1" in
    *.env.example|*.example|*\.env\.example) return 0 ;;
    *) return 1 ;;
  esac
}

FAIL=0

while IFS= read -r file; do
  [ -z "$file" ] && continue
  skip_file "$file" && continue

  staged=$(git show ":$file" 2>/dev/null || true)
  [ -z "$staged" ] && continue

  hits=$(printf '%s\n' "$staged" | grep -E -I "$HIGH_CONFIDENCE" 2>/dev/null | grep -vE "$BENIGN" || true)
  if [ -z "$hits" ]; then
    hits=$(printf '%s\n' "$staged" | grep -E -I "$ASSIGNMENT" 2>/dev/null | grep -vE "$BENIGN" || true)
  fi

  if [ -n "$hits" ]; then
    echo -e "${RED}${BOLD}ERROR: possible secret detected in staged file: $file${NC}"
    printf '%s\n' "$hits" | head -5 | sed 's/^/    /'
    FAIL=1
  fi
done < <(git diff --cached --name-only --diff-filter=ACM)

if [ "$FAIL" = "1" ]; then
  echo -e "${RED}${BOLD}Commit blocked.${NC} Remove the secret, or if it is a confirmed false positive run:"
  echo "  git commit --no-verify"
  exit 1
fi
exit 0
