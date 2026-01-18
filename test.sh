#!/bin/bash
set -o errexit
set -o nounset
# set -o xtrace #debug

source ${0%.sh}.args.sh # get 'args' variable from individual test

function preprocess_prog {
    if [ "$PROG" -nt "${PROG%.ml}.mlp" ]; then
        # we backpropagate it
        preprocessor retro "${PROG%.ml}.mlp"

    else # if older or same date or doesn't exist
        # we overwrite it
        local created; if [ -f "$PROG" ]; then created=0; else created=1; fi
        preprocessor "${PROG%.ml}.mlp"
        ((created)) && chmod +x "$PROG"

    fi
    :
}
preprocess_prog

cd "$(dirname "${BASH_SOURCE[0]}")"
test="$(basename "${BASH_SOURCE[0]}")"; test="${test%.sh}"
>/dev/null diff "${test}.out.txt" <("$PROG" "${args[@]}" < "${test}.in.txt") || diffcode=$?
[ ${diffcode:-0} -eq 2 ] && exit 2
[ ${diffcode:-0} -eq 1 ] && {
    echo "=== ❌ $test ==="
    git --no-pager diff --no-index "${test}.out.txt" <(2>/dev/null "$PROG" "${args[@]}" < "${test}.in.txt")
}
echo "=== ✅ $test ==="
