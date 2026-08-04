#!/usr/bin/env bash
# ==============================================================================
# Hypervisor Host Bootstrap & Audit Script (Target KVM Preparation)
# ==============================================================================
# Idempotently audits or bootstraps a target Ubuntu/Debian hypervisor host for
# Terraform libvirt provisioning.
#
# Flags:
#   --check | --dry-run     Perform a non-destructive read-only audit
#   --help                  Display usage information
#
# Examples:
#   ./scripts/bootstrap-host.sh --check
#   sudo ./scripts/bootstrap-host.sh bjarrett
# ==============================================================================

set -euo pipefail

# Mode flags
DRY_RUN=0
TARGET_USER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check|--dry-run)
      DRY_RUN=1
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [username] [--check|--dry-run]"
      echo ""
      echo "  --check, --dry-run    Read-only audit of host prerequisites (makes ZERO changes)"
      exit 0
      ;;
    *)
      if [[ -z "$TARGET_USER" && "$1" != -* ]]; then
        TARGET_USER="$1"
      else
        echo "Unknown argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

TARGET_USER="${TARGET_USER:-${SUDO_USER:-$(whoami)}}"

# Color helpers for audit reporting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# ==============================================================================
# AUDIT MODE (--check / --dry-run)
# ==============================================================================
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "=============================================================================="
  echo "         HYPERVISOR READ-ONLY PREREQUISITE AUDIT (--check mode)             "
  echo "=============================================================================="
  echo "Target User: $TARGET_USER"
  echo "Timestamp:   $(date)"
  echo "------------------------------------------------------------------------------"

  # 1. Check Required Packages
  echo "--- 1. Required Packages ---"
  PACKAGES=("qemu-kvm" "libvirt-daemon-system" "libvirt-clients" "bridge-utils" "acl" "net-tools")
  for pkg in "${PACKAGES[@]}"; do
    if dpkg -l "$pkg" &>/dev/null; then
      pass "Package '$pkg' is installed."
    else
      warn "Package '$pkg' is MISSING."
    fi
  done

  # 2. Check User Groups
  echo "--- 2. RBAC & Group Access ---"
  if id "$TARGET_USER" &>/dev/null; then
    USER_GROUPS=$(id -Gn "$TARGET_USER")
    if [[ " $USER_GROUPS " =~ " libvirt " ]]; then
      pass "User '$TARGET_USER' is in 'libvirt' group."
    else
      warn "User '$TARGET_USER' is NOT in 'libvirt' group."
    fi

    if [[ " $USER_GROUPS " =~ " kvm " ]]; then
      pass "User '$TARGET_USER' is in 'kvm' group."
    else
      warn "User '$TARGET_USER' is NOT in 'kvm' group."
    fi
  else
    fail "Target user '$TARGET_USER' does not exist."
  fi

  # 3. Check Storage Pool Directory
  echo "--- 3. Storage Pool & Permissions ---"
  STORAGE_PATH="/var/lib/libvirt/images"
  if [[ -d "$STORAGE_PATH" ]]; then
    pass "Storage directory '$STORAGE_PATH' exists."
    DIR_PERMS=$(stat -c "%a %U:%G" "$STORAGE_PATH")
    info "Permissions: $DIR_PERMS (Expected: 2775 libvirt-qemu:kvm)"
  else
    warn "Storage directory '$STORAGE_PATH' does NOT exist."
  fi

  # 4. Check AppArmor Confinement
  echo "--- 4. AppArmor Process Sandboxing ---"
  APPARMOR_LOCAL="/etc/apparmor.d/local/abstractions/libvirt-qemu"
  RULE='/var/lib/libvirt/images/** rwk,'
  if [[ -f "$APPARMOR_LOCAL" ]] && grep -qF "$RULE" "$APPARMOR_LOCAL" 2>/dev/null; then
    pass "AppArmor rule '$RULE' present in $APPARMOR_LOCAL."
  else
    warn "AppArmor local rule '$RULE' is MISSING from $APPARMOR_LOCAL."
  fi

  # 5. Check Libvirtd Service & Pools
  echo "--- 5. Service & Storage Pool Status ---"
  if command -v systemctl &>/dev/null && systemctl is-active --quiet libvirtd; then
    pass "libvirtd service is ACTIVE."
  else
    warn "libvirtd service is NOT active."
  fi

  # 6. Check Networking Status
  echo "--- 6. Networking & Libvirt Networks ---"
  PRIMARY_IF=$(ip -4 route show default 2>/dev/null | awk '{print $5}' | head -n1 || true)
  PRIMARY_IP=$(ip -4 addr show "${PRIMARY_IF:-eth0}" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1 || true)
  if [[ -n "$PRIMARY_IP" ]]; then
    pass "Primary network interface '${PRIMARY_IF:-eth0}' active with IP: $PRIMARY_IP"
  else
    warn "Primary network interface active IP could not be determined."
  fi

  if virsh -c qemu:///system net-info default &>/dev/null; then
    pass "Libvirt network 'default' (NAT virbr0) is active."
  else
    warn "Libvirt network 'default' is inactive or missing."
  fi

  if ip link show br0 &>/dev/null; then
    pass "Linux bridge 'br0' present on host."
    if virsh -c qemu:///system net-info host-bridge &>/dev/null; then
      pass "Libvirt network 'host-bridge' exists and is active."
    else
      warn "Libvirt network 'host-bridge' missing (auto-created when br0 active)."
    fi
  else
    info "Linux bridge 'br0' not present (Host using default NAT networking)."
  fi

  echo "=============================================================================="
  echo " Audit complete. Zero system modifications were made."
  echo "=============================================================================="
  exit 0
fi

# ==============================================================================
# APPLY MODE (Safely apply host preparation)
# ==============================================================================

if [[ "$EUID" -ne 0 ]]; then
  fail "Apply mode requires root privileges. Please run with sudo:"
  echo "  sudo $0 [username]"
  exit 1
fi

echo "=============================================================================="
echo "          APPLYING HYPERVISOR HOST PREPARATION & SECURITY POSTURE             "
echo "=============================================================================="
echo "Target User: $TARGET_USER"
echo "------------------------------------------------------------------------------"

echo "=== [1/5] Installing KVM & Libvirt Packages ==="
apt-get update
apt-get install -y \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  bridge-utils \
  acl \
  net-tools

echo "=== [2/5] Configuring User Group Access (RBAC) ==="
if id "$TARGET_USER" &>/dev/null; then
  usermod -aG libvirt,kvm "$TARGET_USER"
  pass "User '$TARGET_USER' added to libvirt and kvm groups."
else
  warn "Target user '$TARGET_USER' not found. Skipping group update."
fi

echo "=== [3/5] Setting Storage Pool Permissions ==="
mkdir -p /var/lib/libvirt/images
chown libvirt-qemu:kvm /var/lib/libvirt/images
chmod 2775 /var/lib/libvirt/images
setfacl -m d:u::rw-,d:g::rw-,d:o::r-- /var/lib/libvirt/images 2>/dev/null || true
setfacl -m d:u:libvirt-qemu:rwx,d:g:kvm:rwx /var/lib/libvirt/images 2>/dev/null || true
pass "Storage permissions updated on /var/lib/libvirt/images."

echo "=== [4/5] Configuring AppArmor Sandbox Rules ==="
mkdir -p /etc/apparmor.d/local/abstractions
APPARMOR_LOCAL="/etc/apparmor.d/local/abstractions/libvirt-qemu"
RULE='/var/lib/libvirt/images/** rwk,'

if ! grep -qF "$RULE" "$APPARMOR_LOCAL" 2>/dev/null; then
  echo "$RULE" >> "$APPARMOR_LOCAL"
  pass "AppArmor local rule added to $APPARMOR_LOCAL."
else
  info "AppArmor local rule already present."
fi

if command -v systemctl &>/dev/null && systemctl is-active --quiet apparmor; then
  systemctl reload apparmor
  pass "AppArmor reloaded successfully."
fi

echo "=== [5/5] Ensuring Libvirt Service & Networks Active ==="
systemctl enable --now libvirtd || true

# Ensure default NAT pool / network active
if virsh pool-info default &>/dev/null; then
  virsh pool-autostart default 2>/dev/null || true
  virsh pool-start default 2>/dev/null || true
  pass "Default storage pool autostart enabled."
fi

if virsh net-info default &>/dev/null; then
  virsh net-autostart default 2>/dev/null || true
  virsh net-start default 2>/dev/null || true
  pass "Default NAT network autostart enabled."
fi

# Auto-define and activate host-bridge network if physical br0 exists (Stage 0 hypervisor)
if ip link show br0 &>/dev/null; then
  if ! virsh net-info host-bridge &>/dev/null; then
    TMP_NET_XML=$(mktemp)
    cat <<EOF > "$TMP_NET_XML"
<network>
  <name>host-bridge</name>
  <forward mode='bridge'/>
  <bridge name='br0'/>
</network>
EOF
    virsh net-define "$TMP_NET_XML" >/dev/null
    virsh net-autostart host-bridge >/dev/null
    virsh net-start host-bridge >/dev/null
    rm -f "$TMP_NET_XML"
    pass "Libvirt network 'host-bridge' defined and activated on br0."
  else
    info "Libvirt network 'host-bridge' already active."
  fi
fi

echo ""
echo "=============================================================================="
echo " SUCCESS: Host bootstrap complete! Run '$0 --check' to verify posture."
echo " Note: User '$TARGET_USER' must log out and back in for group membership."
echo "=============================================================================="
