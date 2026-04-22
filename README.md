The one-liner to run on a fresh Debian 13 machine

wget -O devplatformbootstrap.sh https://raw.githubusercontent.com/Korplin/LinuxDevPlatformBootstrap/main/devplatformbootstrap.sh && bash devplatformbootstrap.sh

The script self-elevates with sudo if you're not root, so no prefix needed. When Ansible starts, it will prompt BECOME password: — enter your user password there.

File summaries
devplatformbootstrap.sh (171 lines)

Prints a colour banner on launch
Sources /etc/os-release and hard-exits if not debian / trixie
Self-escalates via exec sudo bash … preserving SUDO_USER for Ansible
Installs ansible git wget curl python3 via apt
Downloads the playbook from the same raw GitHub URL into /tmp/
Validates the download is a real playbook (grep for - name:) before running
Runs ansible-playbook -K /tmp/devplatform.yml (password prompted by Ansible, not hardcoded)
Prints a success box with next steps, or a failure box with the exit code

devplatform.yml (1048 lines, ~100 tasks)
Structured in 16 labelled sections, every non-obvious task has a # Reason: comment:
SectionWhat it doesPREassert hard-fails on non-trixieAPTWrites sources.list with contrib non-free non-free-firmware; creates /etc/apt/keyrings/DETECTdmidecode + lspci → boolean facts: is_virtualbox, is_kvm, has_nvidia, has_amd, has_intel_gpuGPUConditional installs: VirtualBox guests, KVM/QEMU guests, NVIDIA (+ nouveau blacklist), AMD, IntelFIRMWAREfirmware-linux*, firmware-iwlwifi/realtek/atheros/brcm80211KDEkde-full, sddm (debconf + conf file), plasma-nm, konsole, fonts-powerlineGITGitHub CLI repo, git git-lfs git-flow tig gitk gh, git lfs install --system, git config --systemKVMqemu-kvm libvirt virt-manager virtinst virt-viewer bridge-utils ovmf; user → libvirt/kvm groupsFLATPAKflatpak plasma-discover-backend-flatpak; Flathub remote (--if-not-exists)BRAVEOfficial S3 GPG key → apt repo → brave-browserVSCODEMicrosoft ASC → dearmor → apt repo → codeCURSORlibfuse2; AppImage to /opt/cursor/; .desktop file in /usr/share/applications/NVMPer-user install under become_user; LTS Node; 6 global npm packagesPYTHONpython3 pip venv dev pipx; pipx installs ansible-lint pre-commit cookiecutter; uv via installerDEVOPSAll utilities + docker.io docker-compose + kubectl (k8s repo) + helm (baltocdn repo)SHELLzsh; chsh via user module; oh-my-zsh unattended; autosuggestions + syntax-highlighting cloned; agnoster theme; nvm + ~/.local/bin blocks in .zshrc

Manual steps required after the playbook finishes

sudo reboot — required for GPU drivers, kernel modules, nouveau blacklist, sddm startup, and all group membership changes (docker, libvirt, kvm) to take effect
Log in via KDE Plasma — sddm starts automatically after reboot
Set your git identity (per-user, not system-wide):

bash   git config --global user.name  "Your Name"
   git config --global user.email "you@example.com"

Authenticate GitHub CLI: gh auth login
Konsole Powerline font — in Konsole → Settings → Edit Current Profile → Appearance → Font — pick a Powerline font (e.g. DejaVu Sans Mono for Powerline) so the agnoster theme renders arrow separators correctly
