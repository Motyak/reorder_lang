#!/bin/bash
set -o errexit
# set -o xtrace #debug

# sophisticated mlp wrapper

CMD="$0${@:+ }$@"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

function ERR {
    local msg="$1"
    >&2 echo "$msg"
    >&2 echo "  $ $CMD"
    exit 1
}

[ "$1" == diff ] && ERR "Can't use 'diff' in mlp2"
[ "$1" == retro ] && ERR "Can't use 'retro' in mlp2"

if [ "$1" == -o ]; then
    FILEOUT="$2"
    [ "$FILEOUT" == "-" ] && ERR "Can't use output '-' in mlp2"
    FILEIN="$3"
    ARGS="${@:4:$#-1}"
else
    FILEIN="$1"
    FILEOUT="${1%.mlp}.ml"
    ARGS="${@:2:$#-1}"
fi

[ "$FILEIN" == "" ] && ERR "Missing file argument"
[[ "$FILEIN" =~ ".mlp"$ ]] || ERR "Invalid file extension: \`${FILEIN##*.}\`"

function mlp1 {
    "${SCRIPT_DIR}/mlp.sh" "$@" || return $?
}

>/dev/null mlp1 diff -o "$FILEOUT" "$FILEIN" $ARGS || exit_code=$?
if [ ${exit_code:-0} -eq 0 ]; then
    ((DRYRUN)) && { >&2 echo "MLP == ML"; }
    exit 0
elif [ ${exit_code:-0} -ne 1 ]; then
    exit $exit_code
fi

if [ "$FILEOUT" -nt "$FILEIN" ]; then
    # we backpropagate it
    ((DRYRUN)) && { >&2 echo "MLP <= ML"; exit 0; }
    mlp1 retro -o "$FILEOUT" "$FILEIN" $ARGS

# if older or doesn't exist
elif [ "$FILEOUT" -ot "$FILEIN" ]; then
    # we overwrite it
    ((DRYRUN)) && { >&2 echo "MLP => ML"; exit 0; }
    if [ -f "$FILEOUT" ]; then created=0; else created=1; fi
    mlp1 -o "$FILEOUT" "$FILEIN" $ARGS
    ((created)) && chmod +x "$FILEOUT"

else # if same date
    # means some included .mlp has changed
    ((DRYRUN)) && { >&2 echo "MLP => ML"; exit 0; }
    mlp1 -o "$FILEOUT" "$FILEIN" $ARGS

fi
