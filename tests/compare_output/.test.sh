#!/bin/bash

# This script is intended to be symlinked by test script files
#   -> tests/compare_output/**/{1000,1100,...}.sh

set -o errexit
set -o nounset
# set -o xtrace #debug

trap err ERR
function err {
    exit_code=${1:-$?}
    [ "$test" != "" ] && >&2 echo "Test $test couldn't be performed"
    exit $exit_code
}

DRYRUN=${DRYRUN:-0}

cd "$(dirname "$0")"
test="$(basename "$0")"; test="${test%.sh}"
source "${test}.args.sh" # get 'args' variable from individual test
preprocess_prog; ((DRYRUN)) && exit 0
prog_out="$("$PROG" "${args[@]}" < "${test}.in.txt" && echo -n x)"
>/dev/null diff "${test}.out.txt" <(printf "%s" "$prog_out" | head -n-1) || diffcode=$?
[ ${diffcode:-0} -eq 2 ] && err 2
[ ${diffcode:-0} -eq 1 ] && {
    echo "=== ❌ $test ==="
    git --no-pager diff --no-index "${test}.out.txt" <(printf "%s" "$prog_out" | head -n-1) || exit 0
}
echo "=== ✅ $test ==="
