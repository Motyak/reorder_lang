#!/bin/bash

# This script is intended to be symlinked by test script files
#   -> tests/check_proper_io_flow/**/{2000,2100,...}.sh

set -o errexit
set -o nounset
# set -o xtrace #debug

trap err ERR
function err {
    exit_code=${1:-$?}
    [ "$test" != "" ] && >&2 echo "Test $test couldn't be performed"
    [ "$prog_out" != "" ] && >&2 echo -e "STDERR was:\n${prog_out}"
    exit $exit_code
}

exec 3>&1
trap 'exec 3>&-' EXIT

DRYRUN=${DRYRUN:-0}

cd "$(dirname "$0")"
test="$(basename "$0")"; test="${test%.sh}"
source "${test}.args.sh" # get 'args' variable from individual test
preprocess_prog; ((DRYRUN)) && exit 0
# we only want the variable to capture the STDERR, while still allowing STDOUT to flow through the pipeline..
# ,..therefore will use file descriptor swapping => redirector STDERR to STDOUT (for capturing it into the variable)..
# ..and the original STDOUT to FD3 (which was previsouly defined as an alias to STDOUT) so it bypasses variable capture
prog_out=$({ ../ioflow/main.elf ../ioflow/fifo < "${test}.in.txt" | "$PROG" "${args[@]}" > ../ioflow/fifo; } 2>&1 1>&3)
>/dev/null diff "${test}.out.txt" <(echo "$prog_out") || diffcode=$?
[ ${diffcode:-0} -eq 2 ] && err 2
[ ${diffcode:-0} -eq 1 ] && {
    echo "=== ❌ $test ==="
    git --no-pager diff --no-index "${test}.out.txt" <(echo "$prog_out") || exit 1
}
echo "=== ✅ $test ==="
