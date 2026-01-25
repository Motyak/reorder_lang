# shellcheck shell=bash
function __doit {
    local SCRIPT_DIR; SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

    export PROG="${SCRIPT_DIR}/src/main.ml"

    eval "
    function preprocess_prog {
        cd \"${SCRIPT_DIR}\"
        mlp/mlp2.sh src/main.mlp -I src
        cd - > /dev/null
    }
    "
    export -f preprocess_prog
}

__doit

unset -f __doit
