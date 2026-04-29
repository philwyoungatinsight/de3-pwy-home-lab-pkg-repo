#!/bin/bash

# GOAL
# - Test a Tapo power plug directly
# - Validate IP, user, password, connectivity, etc all function


TAPO_IP="${1:-${TAPO_IP:-}}"
TAPO_EMAIL="${2:-${TAPO_EMAIL:-}}"
TAPO_PASSWORD="${3:-${TAPO_PASSWORD:-}}"
TAPO_DELAY="${4:-${TAPO_DELAY:-5}}"

if [[ -z "$TAPO_IP" || -z "$TAPO_EMAIL" || -z "$TAPO_PASSWORD" ]]; then
    echo ""
    echo -e "  ${CYAN}Usage:${NC} $0 <ip> <email> <password> [delay_seconds]"
    echo ""
    echo -e "  ${CYAN}Or set environment variables:${NC}"
    echo "    export TAPO_IP=192.168.1.50"
    echo "    export TAPO_EMAIL=me@email.com"
    echo "    export TAPO_PASSWORD=mypassword"
    echo "    $0"
    echo ""
    exit 1
fi

# ── Check Python ───────────────────────────────────────────
info "Checking Python 3 ..."
if ! command -v python3 &>/dev/null; then
    warn "Python 3 not found. Installing ..."
    sudo apt-get update -qq && sudo apt-get install -y -qq python3 python3-pip
fi
success "Python $(python3 --version | cut -d' ' -f2) found"

# ── Install plugp100 if needed ─────────────────────────────
info "Checking plugp100 library ..."
if ! python3 -c "import plugp100" &>/dev/null; then
    info "Installing plugp100 ..."
    pip3 install plugp100 --break-system-packages -q
    success "plugp100 installed"
else
    success "plugp100 already installed"
fi

# ── Locate the Python script (same dir as this script) ─────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/tapo_power_cycle.py"

if [[ ! -f "$PY_SCRIPT" ]]; then
    error "Cannot find tapo_power_cycle.py next to this script in: $SCRIPT_DIR"
fi

# ── Run the power cycle ────────────────────────────────────
echo ""
info "Starting power cycle for plug at ${YELLOW}$TAPO_IP${NC} (delay: ${TAPO_DELAY}s) ..."
echo ""

python3 "$PY_SCRIPT" "$TAPO_IP" "$TAPO_EMAIL" "$TAPO_PASSWORD" "$TAPO_DELAY"
