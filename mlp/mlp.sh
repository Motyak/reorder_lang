#!/bin/bash
set -o errexit
# set -o xtrace #debug

# protection against corrupted output file
trap '[ -f "$FILEOUT" ] && rm -f "$FILEOUT"' ERR

CMD="$0${@:+ }$@"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

function ERR {
    local msg="$1"
    >&2 echo "$msg"
    >&2 echo "  $ $CMD"
    exit 1
}

function preprocess {
    perl "${SCRIPT_DIR}/preprocess.pl" "$@" || return $?
}

function retro {
    perl "${SCRIPT_DIR}/retro.pl" "$@" || return $?
}

[ "$1" == diff ] && {
    DIFFMODE=1
    shift
}
[ "$1" == retro ] && {
    RETROMODE=1
    shift
}

if [ "$1" == -o ]; then
    FILEOUT="$2"
    [ "$FILEOUT" == "-" ] && {
        ((RETROMODE)) && ERR "Can't specify '-' as output file in retro mode"
        FILEOUT="/dev/stdout"
    }
    FILEIN="$3"
    ARGS="${@:4:$#-1}"
else
    FILEIN="$1"
    FILEOUT="${1%.mlp}.ml"
    ARGS="${@:2:$#-1}"
fi

[ "$FILEIN" == "" ] && ERR "Missing file argument"
[[ "$FILEIN" =~ ".mlp"$ ]] || ERR "Invalid file extension: \`${FILEIN##*.}\`"

((RETROMODE)) && {
    exit_code=0
    retro "$FILEOUT" "$FILEIN" || exit_code=$?
    exit $exit_code
}

((DIFFMODE)) && {
    # make sure we have no script error before doing the git diff
    >/dev/null preprocess "$FILEIN" $ARGS || exit 2
    [ -f "$FILEOUT" ] || exit 3
    exit_code=0
    git diff --no-index --no-prefix -U1000 <(preprocess "$FILEIN" $ARGS) "$FILEOUT" || {
        exit_code=$?
    }
    exit $exit_code # git diff exit code
}

# for this to work, we put the same timestamp (preprocessing time here, see 'retro')
# ..to both input and output file
[ -f "$FILEOUT" ] && [ "$FILEOUT" -nt "$FILEIN" ] && {
    # protection against losing data
    >&2 echo "Output file has been updated, are you sure you want to overwrite it ?"
    >&2 echo -n "confirm?(Y/n) >"
    read confirm
    [[ "$confirm" =~ n|N ]] && { >&2 echo "aborted"; exit 0; }
}

preprocess "$FILEIN" $ARGS > "$FILEOUT"

[ -f "$FILEOUT" ] && touch -r "$FILEOUT" "$FILEIN"

true
