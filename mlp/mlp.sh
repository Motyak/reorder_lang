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

if [ "$1" == diff ]; then
    DIFFMODE=x
    shift
fi

if [ "$1" == -o ]; then
    FILEOUT="$2"
    [ "$FILEOUT" == "-" ] && FILEOUT="/dev/stdout"
    FILEIN="$3"
    ARGS="${@:4:$#-1}"
else
    FILEIN="$1"
    FILEOUT="${1%.mlp}.ml"
    ARGS="${@:2:$#-1}"
fi

[ "$FILEIN" == "" ] && ERR "Missing file argument"
[[ "$FILEIN" =~ ".mlp"$ ]] || ERR "Invalid file extension: \`${FILEIN##*.}\`"

# for this to work, we align output file last modif date
# ..with input file's, at the time of preprocessing
[ -z "$DIFFMODE" ] && [ -f "$FILEOUT" ] && [ "$FILEOUT" -nt "$FILEIN" ] && {
    # protection against losing data
    >&2 echo "Output file has been updated, are you sure you want to overwrite it ?"
    >&2 echo -n "confirm?(Y/n) >"
    read confirm
    [[ "$confirm" =~ n|N ]] && { >&2 echo "aborted"; exit 0; }
}

[ -n "$DIFFMODE" ] && {
    # make sure we have no script error before doing the git diff
    >/dev/null preprocess "$FILEIN" $ARGS || exit 2
    [ -f "$FILEOUT" ] || exit 3
    exit_code=0
    git diff --no-index --no-prefix -U1000 <(preprocess "$FILEIN" $ARGS) "$FILEOUT" || {
        exit_code=$?
    }
    exit $exit_code # git diff exit code
}

preprocess "$FILEIN" $ARGS > "$FILEOUT"

[ -f "$FILEOUT" ] && touch -r "$FILEIN" "$FILEOUT"

true
