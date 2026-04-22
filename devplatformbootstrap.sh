#!/usr/bin/env bash
# =============================================================================
# devplatformbootstrap.sh
# Linux Developer Platform Bootstrap — Stage 1
#
# Repository : https://github.com/Korplin/LinuxDevPlatformBootstrap
# Target OS  : Debian 13 "trixie" amd64
# Usage      : bash devplatformbootstrap.sh
#              (will self-elevate with sudo if not already root)
# =============================================================================

set -euo pipefail

# ── Colour codes ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Banner ────────────────────────────────────────────────────────────────────
print_banner() {
  echo -e "${CYAN}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║       Linux Developer Platform Bootstrap — Stage 1                 ║"
  echo "║       github.com/Korplin/LinuxDevPlatformBootstrap                 ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

# ── Self-escalation ───────────────────────────────────────────────────────────
# If not running as root, re-exec the script under sudo.
# sudo sets SUDO_USER automatically, which the Ansible playbook uses to
# identify the real (non-root) user for per-user configurations.
if [ "$(id -u)" -ne 0 ]; then
  warn "Not running as root — re-launching with sudo."
  warn "You may be prompted for your sudo password."
  exec sudo bash "$(realpath "$0")" "$@"
fi

print_banner

# ── Debian 13 trixie check ────────────────────────────────────────────────────
info "Verifying operating system..."

if [ ! -f /etc/os-release ]; then
  die "Cannot detect OS: /etc/os-release not found."
fi

# shellcheck source=/dev/null
. /etc/os-release

if [ "${ID:-}" != "debian" ]; then
  die "This script requires Debian. Detected OS: ${ID:-unknown}. Aborting."
fi

if [ "${VERSION_CODENAME:-}" != "trixie" ]; then
  die "This script requires Debian 13 (trixie).\n" \
      "       Detected codename: '${VERSION_CODENAME:-unknown}' (${PRETTY_NAME:-unknown}).\n" \
      "       Please run on a fresh Debian 13 trixie installation."
fi

success "Debian 13 (trixie) confirmed."

# ── Ensure SUDO_USER is known ─────────────────────────────────────────────────
# When run via sudo, SUDO_USER is the original caller's username.
# If run directly as root (e.g., on a server), we try logname as a fallback.
REAL_USER="${SUDO_USER:-}"
if [ -z "$REAL_USER" ]; then
  REAL_USER="$(logname 2>/dev/null || echo "")"
fi
if [ -z "$REAL_USER" ] || [ "$REAL_USER" = "root" ]; then
  warn "Could not detect a non-root user. Per-user tools (nvm, oh-my-zsh, etc.)"
  warn "will be configured for root. This is unusual — prefer running as a"
  warn "normal user with sudo access."
fi
info "Target user for per-user configuration: ${REAL_USER:-root}"

# ── Update apt package index ──────────────────────────────────────────────────
info "Updating apt package index..."
apt-get update -qq
success "Package index updated."

# ── Install prerequisites ─────────────────────────────────────────────────────
PREREQS=(ansible git wget curl python3)

info "Installing prerequisites: ${PREREQS[*]}"
# DEBIAN_FRONTEND=noninteractive prevents any interactive prompts during install.
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${PREREQS[@]}"
success "Prerequisites installed."

# Verify ansible is now available.
if ! command -v ansible-playbook &>/dev/null; then
  die "ansible-playbook not found after install. Check apt output above."
fi
ANSIBLE_VER="$(ansible --version | head -1)"
info "Using: ${ANSIBLE_VER}"

# ── Download the Ansible playbook ─────────────────────────────────────────────
PLAYBOOK_URL="https://raw.githubusercontent.com/Korplin/LinuxDevPlatformBootstrap/main/devplatform.yml"
PLAYBOOK_DEST="/tmp/devplatform.yml"

info "Downloading Ansible playbook from:"
info "  ${PLAYBOOK_URL}"

# -L follows redirects, -f fails on HTTP error, -S shows errors, -s silent progress.
if ! curl -LfSs -o "${PLAYBOOK_DEST}" "${PLAYBOOK_URL}"; then
  # Fallback to wget if curl fails (both are installed above).
  warn "curl failed — retrying with wget..."
  wget -q -O "${PLAYBOOK_DEST}" "${PLAYBOOK_URL}" \
    || die "Failed to download playbook from ${PLAYBOOK_URL}"
fi

# Quick sanity check: confirm the downloaded file looks like YAML.
if ! grep -q "^- name:" "${PLAYBOOK_DEST}" 2>/dev/null; then
  die "Downloaded file does not appear to be a valid Ansible playbook.\n" \
      "       Check the URL: ${PLAYBOOK_URL}"
fi
success "Playbook downloaded to ${PLAYBOOK_DEST}."

# ── Run the Ansible playbook ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD} Stage 2: Running Ansible playbook (this will take 10–30 minutes)${RESET}"
echo -e "${BOLD} You will be prompted for your sudo (BECOME) password by Ansible.${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Pass SUDO_USER into the environment so the playbook can identify the real user
# even though ansible-playbook is launched as root.
export SUDO_USER="${REAL_USER}"

# -K = --ask-become-pass: prompts for the privilege-escalation password.
# This is kept even though we are already root because it is an explicit
# requirement and causes no harm when become escalates root → root.
ansible-playbook -K "${PLAYBOOK_DEST}"

PLAYBOOK_EXIT=$?

echo ""
if [ ${PLAYBOOK_EXIT} -eq 0 ]; then
  echo -e "${GREEN}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║   ✔  Bootstrap Complete!  Stage 1 & Stage 2 finished successfully. ║"
  echo "║                                                                     ║"
  echo "║   NEXT STEPS (required):                                            ║"
  echo "║   1.  sudo reboot                                                   ║"
  echo "║       — GPU drivers, kernel modules, and sddm require a reboot.    ║"
  echo "║   2.  After reboot, KDE Plasma will start via sddm.                ║"
  echo "║   3.  Open Konsole — your shell is now zsh + oh-my-zsh (agnoster). ║"
  echo "║   4.  Group changes (docker, libvirt, kvm) are active after reboot. ║"
  echo "║   5.  nvm, Node.js, pipx tools are on PATH in new shell sessions.  ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
else
  echo -e "${RED}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║   ✘  Ansible playbook exited with code ${PLAYBOOK_EXIT}.                      ║"
  echo "║      Review the output above for FAILED tasks.                     ║"
  echo "║      The playbook is idempotent — fix the issue and re-run.        ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
  exit ${PLAYBOOK_EXIT}
fi
