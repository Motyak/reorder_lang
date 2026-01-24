#!/bin/bash

# This script is intended to be symlinked by test script files
#   -> tests/**/{1000,1100,...}.sh

set -o errexit
set -o nounset
# set -o xtrace #debug

function preprocess_prog {
    if [ "$PROG" -nt "${PROG%.ml}.mlp" ]; then
        # we backpropagate it
        preprocessor retro "${PROG%.ml}.mlp"

    # if older or doesn't exist
    elif [ "$PROG" -ot "${PROG%.ml}.mlp" ]; then
        # we overwrite it
        local created; if [ -f "$PROG" ]; then created=0; else created=1; fi
        preprocessor "${PROG%.ml}.mlp"
        ((created)) && chmod +x "$PROG"

    else # if same date
        # IMPORTANT we still want to overwrite the ml file..
        # ..in case we edited one of the mlp included file
        preprocessor "${PROG%.ml}.mlp"

    fi
    :
}
preprocess_prog

cd "$(dirname "${BASH_SOURCE[0]}")"
test="$(basename "${BASH_SOURCE[0]}")"; test="${test%.sh}"
source "${test}.args.sh" # get 'args' variable from individual test
prog_out="$("$PROG" "${args[@]}" < "${test}.in.txt"; echo -n x)"
>/dev/null diff "${test}.out.txt" <(printf "%s" "$prog_out" | head -n-1) || diffcode=$?
[ ${diffcode:-0} -eq 2 ] && exit 2
[ ${diffcode:-0} -eq 1 ] && {
    echo "=== ❌ $test ==="
    git --no-pager diff --no-index "${test}.out.txt" <(printf "%s" "$prog_out" | head -n-1)
}
echo "=== ✅ $test ==="
