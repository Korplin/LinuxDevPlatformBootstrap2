#!/usr/bin/env bash
# =============================================================================
# devplatformbootstrap.sh
# Linux Developer Platform Bootstrap — Stage 1
#
# Repository : https://github.com/Korplin/LinuxDevPlatformBootstrap2
# Target OS  : Debian 13 "trixie" amd64
# Usage      : bash devplatformbootstrap.sh
#              (will self-elevate with sudo if not already root)
# =============================================================================

set -euo pipefail

# ── Repository coordinates ────────────────────────────────────────────────────
# These three variables are the ONLY things that need changing when you rename
# or fork the repository. Every URL in this script is derived from them.
GITHUB_USER="Korplin"
GITHUB_REPO="LinuxDevPlatformBootstrap2"
GITHUB_BRANCH="main"

# Derived URLs — do not edit below this line unless you know what you are doing.
RAW_BASE="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"
PLAYBOOK_URL="${RAW_BASE}/devplatform.yml"
PLAYBOOK_DEST="/tmp/devplatform.yml"

# ── Colour codes ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Logging helpers ───────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

# ── Banner ────────────────────────────────────────────────────────────────────
print_banner() {
  echo -e "${CYAN}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║       Linux Developer Platform Bootstrap — Stage 1                 ║"
  echo "║       github.com/${GITHUB_USER}/${GITHUB_REPO}        ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

# ── Self-escalation ───────────────────────────────────────────────────────────
# If not running as root, re-exec the script under sudo.
# sudo sets SUDO_USER automatically; the Ansible playbook reads it to identify
# the real (non-root) user for per-user configurations (nvm, oh-my-zsh, etc.).
if [ "$(id -u)" -ne 0 ]; then
  warn "Not running as root — re-launching with sudo."
  warn "You may be prompted for your sudo password."
  exec sudo bash "$(realpath "$0")" "$@"
fi

print_banner

# ── OS verification: Debian 13 trixie only ────────────────────────────────────
info "Verifying operating system..."

[ -f /etc/os-release ] || die "Cannot detect OS: /etc/os-release not found."

# shellcheck source=/dev/null
. /etc/os-release

[ "${ID:-}" = "debian" ] \
  || die "This script requires Debian. Detected OS: ${ID:-unknown}. Aborting."

[ "${VERSION_CODENAME:-}" = "trixie" ] \
  || die "This script requires Debian 13 (trixie).\n" \
         "       Detected: '${VERSION_CODENAME:-unknown}' (${PRETTY_NAME:-unknown}).\n" \
         "       Please run on a fresh Debian 13 trixie installation."

success "Debian 13 (trixie) confirmed."

# ── Identify the real (non-root) user ─────────────────────────────────────────
# When invoked via sudo (the normal path), SUDO_USER is the original caller.
# If run directly as root (bare-metal server), fall back to logname.
REAL_USER="${SUDO_USER:-}"

if [ -z "$REAL_USER" ]; then
  REAL_USER="$(logname 2>/dev/null || echo "")"
fi

if [ -z "$REAL_USER" ] || [ "$REAL_USER" = "root" ]; then
  die "Could not detect a non-root user. Run this script as your normal desktop user with sudo access, not directly as root."
fi

info "Target user for per-user configuration: ${REAL_USER}"

# ── Refresh apt and install prerequisites ─────────────────────────────────────
info "Updating apt package index..."
apt-get update -qq
success "Package index updated."

PREREQS=(ansible git wget curl python3)
info "Installing prerequisites: ${PREREQS[*]}"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${PREREQS[@]}"
success "Prerequisites installed."

command -v ansible-playbook &>/dev/null \
  || die "ansible-playbook not found after install. Check apt output above."

ANSIBLE_VER="$(ansible --version | head -1)"
info "Using: ${ANSIBLE_VER}"

# ── Download the Ansible playbook ─────────────────────────────────────────────
info "Downloading Ansible playbook from:"
info "  ${PLAYBOOK_URL}"

if ! curl -LfSs --retry 3 --retry-delay 2 -o "${PLAYBOOK_DEST}" "${PLAYBOOK_URL}"; then
  warn "curl failed — retrying with wget..."
  wget -q --tries=3 -O "${PLAYBOOK_DEST}" "${PLAYBOOK_URL}" \
    || die "Failed to download playbook from:\n       ${PLAYBOOK_URL}"
fi

# Sanity-check: confirm the downloaded file looks like YAML with Ansible tasks.
grep -q "^- name:" "${PLAYBOOK_DEST}" 2>/dev/null \
  || die "Downloaded file does not appear to be a valid Ansible playbook.\n" \
         "       URL: ${PLAYBOOK_URL}"

success "Playbook downloaded to ${PLAYBOOK_DEST}."

# ── Run the Ansible playbook ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD} Stage 2: Running Ansible playbook  (10–30 minutes depending on speed)${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Export SUDO_USER so the playbook can resolve the real user's home directory
# even though ansible-playbook itself runs as root.
export SUDO_USER="${REAL_USER}"

# ── Why no -K (--ask-become-pass) here? ──────────────────────────────────────
# This script already re-executes itself under sudo (see self-escalation above),
# so ansible-playbook runs as root. The playbook uses become: true which
# escalates root → root — a no-op that never requires a password. Passing -K
# would prompt for a password unnecessarily and break unattended re-runs.
ansible-playbook "${PLAYBOOK_DEST}"
PLAYBOOK_EXIT=$?

echo ""
if [ ${PLAYBOOK_EXIT} -eq 0 ]; then
  echo -e "${GREEN}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║   ✔  Bootstrap Complete — Stage 1 & 2 finished successfully.       ║"
  echo "║                                                                     ║"
  echo "║   REQUIRED NEXT STEPS:                                              ║"
  echo "║                                                                     ║"
  echo "║   1.  sudo reboot                                                   ║"
  echo "║       — GPU drivers, kernel modules, sddm, and all group           ║"
  echo "║         memberships require a reboot to take effect.               ║"
  echo "║                                                                     ║"
  echo "║   2.  After reboot, KDE Plasma starts via sddm.                    ║"
  echo "║       Log in with your normal user credentials.                     ║"
  echo "║                                                                     ║"
  echo "║   3.  Open Konsole. Your shell is now zsh + oh-my-zsh (agnoster).  ║"
  echo "║       First run: set your git identity:                            ║"
  echo "║         git config --global user.name  'Your Name'                 ║"
  echo "║         git config --global user.email 'you@example.com'           ║"
  echo "║                                                                     ║"
  echo "║   4.  Authenticate the GitHub CLI:                                 ║"
  echo "║         gh auth login                                               ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
else
  echo -e "${RED}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║   ✘  Ansible playbook exited with error code ${PLAYBOOK_EXIT}.               ║"
  echo "║      Scroll up to find the FAILED task.                            ║"
  echo "║      Fix the issue and re-run — the playbook is idempotent.        ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
  exit "${PLAYBOOK_EXIT}"
fi
