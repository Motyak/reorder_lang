#!/bin/bash
set -o errexit

args=(-- "2..4")

cd "$(dirname "${BASH_SOURCE[0]}")"
test="$(basename "${BASH_SOURCE[0]}")"; test="${test%.sh}"
&>/dev/null diff "${test}.out.txt" <("${PROG:-false}" "${args[@]}" < "${test}.in.txt") || diffcode=$?
[ ${diffcode:-0} -eq 2 ] && exit 2
[ ${diffcode:-0} -eq 1 ] && {
    echo "=== ❌ $test ==="
    git diff --no-index "${test}.out.txt" <(2>/dev/null "${PROG:-false}" "${args[@]}" < "${test}.in.txt")
}
echo "=== ✅ $test ==="
