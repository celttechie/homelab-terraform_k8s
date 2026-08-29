#!/usr/bin/env bash
# ==============================================================================
# Stage 2 Kubernetes Downstream Cluster Verification Runner
# ==============================================================================
# Wrapper script to execute Stage 2 automated health, network, and workload
# checks using python3 scripts/verify_stage2.py.
#
# Flags:
#   --check | --dry-run     Perform a non-destructive read-only audit
#   --skip-live             Skip live SSH & HTTP network probes
#   --help                  Display usage information
#
# Examples:
#   ./scripts/verify-stage2.sh --check
#   ./scripts/verify-stage2.sh --skip-live
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

python3 "${SCRIPT_DIR}/verify_stage2.py" "$@"
