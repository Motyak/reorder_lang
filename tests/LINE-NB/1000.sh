#!/bin/bash
set -o errexit
set -o nounset

args=(-- "2")

&>/dev/null preprocessor diff "${PROG%.ml}.mlp" || {
    preprocessor "${PROG%.ml}.mlp"
    chmod +x "$PROG"
}
cd "$(dirname "${BASH_SOURCE[0]}")"
test="$(basename "${BASH_SOURCE[0]}")"; test="${test%.sh}"
&>/dev/null diff "${test}.out.txt" <("$PROG" "${args[@]}" < "${test}.in.txt") || diffcode=$?
[ ${diffcode:-0} -eq 2 ] && exit 2
[ ${diffcode:-0} -eq 1 ] && {
    echo "=== ❌ $test ==="
    git --no-pager diff --no-index "${test}.out.txt" <(2>/dev/null "$PROG" "${args[@]}" < "${test}.in.txt")
}
echo "=== ✅ $test ==="
