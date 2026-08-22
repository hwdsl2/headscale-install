#!/bin/bash

set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

# Load the functions without running the installer's top-level entry point.
test_script="$test_dir/headscale-install.sh"
sed -e 's/^hssetup "$@"$/:/' -e 's/^exit 0$/:/' \
  "$repo_dir/headscale-install.sh" >"$test_script"
# shellcheck source=/dev/null
source "$test_script"

mock_bin="$test_dir/bin"
restorecon_log="$test_dir/restorecon.log"
mkdir -p "$mock_bin"

cat >"$mock_bin/getenforce" <<'EOF'
#!/bin/sh
printf '%s\n' "${GETENFORCE_MODE:-}"
EOF

cat >"$mock_bin/restorecon" <<'EOF'
#!/bin/sh
[ "$#" -eq 1 ] || exit 64
printf '%s\n' "$1" >>"$RESTORECON_LOG"
exit "${RESTORECON_RC:-0}"
EOF

chmod 755 "$mock_bin/getenforce" "$mock_bin/restorecon"

PATH="$mock_bin:/usr/bin:/bin"
HS_BIN="$test_dir/headscale"
RESTORECON_LOG="$restorecon_log"
export GETENFORCE_MODE RESTORECON_LOG RESTORECON_RC

GETENFORCE_MODE=Enforcing
RESTORECON_RC=0
restore_hs_selinux_context
[ "$(cat "$restorecon_log")" = "$HS_BIN" ]

: >"$restorecon_log"
GETENFORCE_MODE=Permissive
RESTORECON_RC=1
warning=$(restore_hs_selinux_context 2>&1)
[[ "$warning" == *"Warning: Failed to restore the SELinux context on $HS_BIN."* ]]
[ "$(cat "$restorecon_log")" = "$HS_BIN" ]

GETENFORCE_MODE=Enforcing
RESTORECON_RC=1
set +e
restore_hs_selinux_context
status=$?
set -e
[ "$status" -eq 1 ]

: >"$restorecon_log"
GETENFORCE_MODE=Disabled
RESTORECON_RC=1
restore_hs_selinux_context
[ ! -s "$restorecon_log" ]

rm -f "$mock_bin/restorecon"
hash -r
GETENFORCE_MODE=Enforcing
set +e
restore_hs_selinux_context
status=$?
set -e
[ "$status" -eq 2 ]

rm -f "$mock_bin/getenforce"
hash -r
restore_hs_selinux_context

echo "SELinux context tests passed."
