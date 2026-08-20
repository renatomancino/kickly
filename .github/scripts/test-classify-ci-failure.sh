#!/usr/bin/env bash
# Test manuale per classify-ci-failure.sh. Niente framework di test per
# bash nel repo: uno script con asserzioni e output leggibile basta per
# una funzione di ~20 righe che non cambia spesso.
set -euo pipefail
cd "$(dirname "$0")"

fail=0

# $1 = atteso, resto = nomi di job (uno per riga su stdin dello script)
check() {
  local expected="$1"; shift
  local actual
  actual="$(printf '%s\n' "$@" | ./classify-ci-failure.sh)"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: classify-ci-failure.sh <<< '$*' -> atteso '$expected', ottenuto '$actual'"
    fail=1
  else
    echo "OK: classify-ci-failure.sh <<< '$*' -> $actual"
  fi
}

check "TRIVIAL" "Flutter (analyze, test, format)"
check "TRIVIAL" "PWA (lint, typecheck, build)"
check "TRIVIAL" "Titolo PR (conventional commits)"
check "TRIVIAL" "Flutter (analyze, test, format)" "PWA (lint, typecheck, build)"
check "NEEDS_HUMAN" "Android (APK debug)"
check "NEEDS_HUMAN" "iOS (debug, no-codesign)"
check "NEEDS_HUMAN" "Secret scan (gitleaks)"
check "NEEDS_HUMAN" "npm audit"
check "NEEDS_HUMAN" "Dependency review"
check "NEEDS_HUMAN" "Migrazioni immutabili"
check "NEEDS_HUMAN" "Migrazioni Supabase (apply pulito)"
check "NEEDS_HUMAN" "Flutter (analyze, test, format)" "Android (APK debug)"

# Nessun job in input (edge case difensivo)
actual="$(printf '' | ./classify-ci-failure.sh)"
if [ "$actual" != "NEEDS_HUMAN" ]; then
  echo "FAIL: nessun input -> atteso 'NEEDS_HUMAN', ottenuto '$actual'"
  fail=1
else
  echo "OK: nessun input -> $actual"
fi

exit $fail
