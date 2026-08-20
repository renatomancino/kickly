#!/usr/bin/env bash
# Classifica un fallimento CI in TRIVIAL o NEEDS_HUMAN in base al NOME
# VISUALIZZATO dei job falliti, uno per riga su stdin (non argv: i nomi
# contengono spazi e virgole, es. "Flutter (analyze, test, format)").
# Nessuna chiamata esterna: GitHub Models (l'alternativa originariamente
# prevista) e' stato ritirato il 30/07/2026. NEEDS_HUMAN vince: se anche un
# solo job fallito tocca nativo/sicurezza/schema, l'intero fallimento va a
# un umano. Se un nome di job cambia in ci.yml senza aggiornare questa
# lista, il confronto smette di trovare un match e la classificazione
# ripiega su NEEDS_HUMAN — fail-safe per costruzione, non un bug silente.
#
# Limite noto e accettato: guarda quale job e' fallito, non perche' — un
# fallimento raro-ma-profondo dentro un job "banale" verrebbe comunque
# instradato a Copilot. Non e' pericoloso: nulla passa senza CI verde, nel
# caso peggiore Copilot ci prova e fallisce, la PR resta rossa finche' un
# umano non la guarda.
set -euo pipefail

TRIVIAL_JOBS=(
  "Flutter (analyze, test, format)"
  "PWA (lint, typecheck, build)"
  "Titolo PR (conventional commits)"
)

classification="TRIVIAL"
any_job="no"
while IFS= read -r job || [ -n "$job" ]; do
  [ -z "$job" ] && continue
  any_job="yes"
  is_trivial="no"
  for t in "${TRIVIAL_JOBS[@]}"; do
    if [ "$job" = "$t" ]; then
      is_trivial="yes"
      break
    fi
  done
  if [ "$is_trivial" = "no" ]; then
    classification="NEEDS_HUMAN"
    break
  fi
done

if [ "$any_job" = "no" ]; then
  echo "NEEDS_HUMAN"
  exit 0
fi

echo "$classification"
