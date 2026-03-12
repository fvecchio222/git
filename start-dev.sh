#!/usr/bin/env bash
# ============================================================
#  start-dev.sh — Avvia l'intero ambiente di sviluppo KMS
#  Uso: ./start-dev.sh [--no-crm] [--no-reverb] [--help]
# ============================================================
set -euo pipefail

# ── Colori ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}[DEV]${RESET} $*"; }
ok()   { echo -e "${GREEN}[OK]${RESET}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()  { echo -e "${RED}[ERR]${RESET} $*" >&2; }

# ── Opzioni ─────────────────────────────────────────────────
START_CRM=true
START_REVERB=true

for arg in "$@"; do
  case $arg in
    --no-crm)    START_CRM=false ;;
    --no-reverb) START_REVERB=false ;;
    --help|-h)
      echo "Uso: $0 [--no-crm] [--no-reverb]"
      echo "  --no-crm     Non avvia il frontend CRM (npm)"
      echo "  --no-reverb  Non avvia il container WebSocket Reverb"
      exit 0
      ;;
    *) err "Opzione sconosciuta: $arg"; exit 1 ;;
  esac
done

# ── Paths ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/kms_backend"
REVERB_DIR="$BACKEND_DIR/reverb"
CRM_DIR="$SCRIPT_DIR/CRM"

# ── Dipendenze ───────────────────────────────────────────────
for cmd in docker docker-compose; do
  if ! command -v "$cmd" &>/dev/null; then
    err "'$cmd' non trovato. Installalo prima di continuare."
    exit 1
  fi
done

# Verifica che Docker sia in esecuzione
if ! docker info &>/dev/null; then
  err "Docker Desktop non è in esecuzione. Avvialo e riprova."
  exit 1
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   KMS Dev Environment Startup    ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════╝${RESET}"
echo ""

# ── 1. Rete Docker condivisa ─────────────────────────────────
log "Verifico la rete Docker 'proxy'..."
if ! docker network inspect proxy &>/dev/null; then
  log "Creo la rete 'proxy'..."
  docker network create proxy
  ok "Rete 'proxy' creata."
else
  ok "Rete 'proxy' già esistente."
fi

# ── 2. Reverb WebSocket ──────────────────────────────────────
if $START_REVERB; then
  log "Avvio WebSocket Reverb (service_websocket_local)..."
  if [ ! -d "$REVERB_DIR" ]; then
    err "Directory Reverb non trovata: $REVERB_DIR"
    exit 1
  fi
  docker compose -f "$REVERB_DIR/docker-compose.yml" up -d --remove-orphans
  ok "Reverb avviato → ws://localhost:8080"
else
  warn "Reverb saltato (--no-reverb)"
fi

# ── 3. KMS Backend (API + Worker) ───────────────────────────
log "Avvio KMS Backend API + Worker (kms_service_api_develop)..."
if [ ! -d "$BACKEND_DIR" ]; then
  err "Directory backend non trovata: $BACKEND_DIR"
  exit 1
fi
docker compose -f "$BACKEND_DIR/docker-compose.yml" up -d --remove-orphans
ok "Backend avviato → https://kms-api.local.galileo.test  |  http://10.0.2.2:3001 (emulatore Android)"

# ── 4. CRM Frontend (npm) ────────────────────────────────────
if $START_CRM; then
  if [ ! -d "$CRM_DIR" ]; then
    warn "Directory CRM non trovata: $CRM_DIR — salto."
  else
    log "Avvio CRM frontend (npm start)..."
    # Apre un nuovo tab nel Terminale macOS
    osascript -e "
      tell application \"Terminal\"
        activate
        tell application \"System Events\" to keystroke \"t\" using command down
        delay 0.5
        do script \"cd '$CRM_DIR' && npm start\" in front window
      end tell
    " 2>/dev/null || {
      warn "Impossibile aprire il terminale automaticamente."
      warn "Avvia manualmente: cd '$CRM_DIR' && npm start"
    }
    ok "CRM frontend avviato in un nuovo tab del Terminale."
  fi
else
  warn "CRM saltato (--no-crm)"
fi

# ── Riepilogo ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Riepilogo servizi attivi ─────────────────────────${RESET}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" \
  --filter "name=kms_service_api_develop" \
  --filter "name=kms_service_api_worker" \
  --filter "name=service_websocket_local"
echo ""
echo -e "${GREEN}${BOLD}Ambiente di sviluppo pronto! 🚀${RESET}"
echo ""
echo -e "  ${CYAN}Backend API${RESET}   → https://kms-api.local.galileo.test"
echo -e "  ${CYAN}Android emu${RESET}   → http://10.0.2.2:3001"
echo -e "  ${CYAN}WebSocket  ${RESET}   → ws://localhost:8080"
$START_CRM && echo -e "  ${CYAN}CRM Frontend${RESET}  → http://localhost:4200"
echo ""
