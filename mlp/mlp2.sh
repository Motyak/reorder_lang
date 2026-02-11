#!/bin/bash
set -o errexit
# set -o xtrace #debug

# sophisticated mlp wrapper
# BE CAREFUL WITH THAT

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

[ -f "$FILEOUT" ] || {
    # we create it
    ((DRYRUN)) && { >&2 echo "MLP => ML"; exit 0; }
    mlp1 -o "$FILEOUT" "$FILEIN" $ARGS
    chmod +x "$FILEOUT"
    exit
}

>/dev/null mlp1 diff -o "$FILEOUT" "$FILEIN" $ARGS || exit_code=$?
[ ${exit_code:-0} -eq 0 ] && {
    ((DRYRUN)) && { >&2 echo "MLP == ML"; }
    exit 0
}
[ ${exit_code:-0} -ne 1 ] && exit $exit_code

if [ "$FILEOUT" -nt "$FILEIN" ]; then
    # we backpropagate it
    ((DRYRUN)) && { >&2 echo "MLP <= ML"; exit 0; }
    mlp1 retro -o "$FILEOUT" "$FILEIN" $ARGS

elif [ "$FILEOUT" -ot "$FILEIN" ]; then
    # we overwrite it
    ((DRYRUN)) && { >&2 echo "MLP => ML"; exit 0; }
    mlp1 -o "$FILEOUT" "$FILEIN" $ARGS

else # if same date
    # means some included .mlp has changed
    ((DRYRUN)) && { >&2 echo "MLP => ML"; exit 0; }
    mlp1 -o "$FILEOUT" "$FILEIN" $ARGS

fi
