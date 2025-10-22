#!/usr/bin/env bash
set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m"

printf "🧪 Running contract tests (wrapper)\n"
cd rwa-soberano-evolve || { echo "rwa-soberano-evolve directory not found"; exit 1; }

if command -v forge >/dev/null 2>&1; then
  if forge test -vv; then
    printf "%b✅ All contract tests passed!%b\n" "$GREEN" "$NC"
  else
    printf "%b❌ Some contract tests failed%b\n" "$RED" "$NC"
    exit 1
  fi
else
  printf "%b❌ forge not found in PATH%b\n" "$RED" "$NC"
  exit 1
fi
