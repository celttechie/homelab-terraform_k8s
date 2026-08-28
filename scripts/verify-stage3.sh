#!/usr/bin/env bash
# ==============================================================================
# Stage 3 Kubernetes Distribution Bootstrap Verification Runner
# ==============================================================================
# Wrapper script to execute Stage 3 automated health, manifest, security, and
# cluster node checks using python3 scripts/verify_stage3.py.
#
# Flags:
#   --check | --dry-run     Perform a non-destructive read-only audit
#   --skip-live             Skip live SSH & API server network probes
#   --help                  Display usage information
#
# Examples:
#   ./scripts/verify-stage3.sh --check
#   ./scripts/verify-stage3.sh --skip-live
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: $0 [--check|--dry-run] [--skip-live] [--timeout <sec>]"
  echo ""
  echo "Flags:"
  echo "  --check, --dry-run    Run non-destructive audit (default)"
  echo "  --skip-live           Skip live network / SSH probes"
  echo "  --timeout <sec>       Connection timeout in seconds (default: 4)"
  echo "  --help, -h            Show this help message"
  exit 0
fi

python3 "${SCRIPT_DIR}/verify_stage3.py" "$@"
